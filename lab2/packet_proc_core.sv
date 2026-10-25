`timescale 1ns/1ps

 // M3 接收启动命令后从同步存储器读取报文，解析包头并逐字累计有效负载，最后保存结果供外部读取。
 // 同步读的返回比请求晚，因此下面分别保存请求进度和返回标签，避免把旧数据当作当前字使用。
module packet_proc_core (
  input  logic        clk, // 系统/测试程序时钟；所有状态、请求标签和结果在上升沿更新。
  input  logic        rst_n, // 系统/测试程序的低有效复位；下降沿立即清工作状态和输出结果。
  input  logic        start_i, // 来自 M1.start_o/测试程序；仅 IDLE 或 DONE 的上升沿接受一次启动。
  input  logic        algo_mode_i, // 来自 M1/测试程序；启动时锁存，1 检查包头 XOR 校验，0 旁路该项。
  input  logic [3:0]  type_mask_i, // 来自 M1/测试程序；启动时锁存，四位允许类型 01/02/04/08。
  input  logic [5:0]  exp_pkt_len_i, // 来自 M1/测试程序的期望总字节数；0 表示不做期望值一致性检查。
  output logic        mem_rd_en_o, // 送 M2/proc_if：1 表示当前有同步读请求；与 PROCESS 状态一致。
  output logic [2:0]  mem_rd_addr_o, // 送 M2/proc_if 的 word 索引 0～7，不是 APB 的 12 位字节地址。
  input  logic [31:0] mem_rd_data_i, // 来自 M2/proc_if 的寄存读输出；本沿新请求的数据要在沿后才返回。
  output logic        busy_o, // 送 M1/测试程序：正在 PROCESS，可用于禁止软件覆盖报文内存。
  output logic        done_o, // 送 M1/测试程序：DONE 时持续为 1，新启动或复位才清除。
  output logic [5:0]  res_pkt_len_o, // 完成时送 M1/测试程序的总包长结果；端口仅 6 位，保留原始长度低 6 位。
  output logic [7:0]  res_pkt_type_o, // 完成时送 M1/测试程序的报文类型，来自包头 Byte1。
  output logic [7:0]  res_payload_sum_o, // 完成时送 M1/测试程序的 payload 字节和，保留低 8 位，不含四字节包头。
  output logic [7:0]  res_payload_xor_o, // 完成时送 M1/测试程序的 payload 字节逐位 XOR，不含包头。
  output logic        format_ok_o, // 送 M1/测试程序：三类错误全为 0 才为 1；是检查结果，不是 APB ready。
  output logic        length_error_o, // 送 M1/测试程序：实际长度越界，或与已配置的期望长度不符。
  output logic        type_error_o, // 送 M1/测试程序：类型不是四个允许值之一，或被 mask 屏蔽。
  output logic        chk_error_o // 送 M1/测试程序：开启校验时 hdr_chk 不符；mode=0 时此错为 0。
);
  typedef enum logic [1:0] {IDLE, PROCESS, DONE} state_t; // 定义 2 位状态类型 state_t，三个名字依次代表 0、1、2；这里只规定格式，下一句 state_t state 才声明状态变量。
  state_t state; // 声明保存当前阶段的状态变量，后面在时钟沿更新它，再根据它输出忙、完成和读请求。
  logic mode; // 保存启动时的校验开关，处理过程中使用这份保存值，外部开关变化不会改变当前帧规则。
  logic [3:0] mask; // 保存启动时的四位类型许可，处理过程中一直用这份规则。
  logic [5:0] expected_length; // 保存启动时的期望长度；为 0 表示不做期望值比较。
  logic [7:0] packet_length, packet_type; // 保存包头解析值，后续 payload 处理和 DONE 输出仍要用到它们。
  logic length_error, type_error, chk_error; // 工作错误寄存器；先记住头部判定，完成时统一交付到输出端口。
  logic [7:0] payload_sum, payload_xor; // 已经消费过的 payload 摘要；跨多个上升沿保存累计进度。
  logic [2:0] read_index, last_index, last_index_now, response_index; // 四个 3 位编号分别记录下一请求、保存的末字、当前组合算出的末字和当前返回数据所属字，均限制在 0～7。
  logic response_valid; // 返回有效标签：启动后先等一次同步读，不能把内存旧输出当本帧包头。
  logic [7:0] header_length, header_type, header_flags, header_chk; // 把当前 32 位返回线分成四个 byte；只有 response_index=0 时才按包头解释。
  logic header_length_error, header_type_error, header_chk_error; // 包头检查的组合结果；消费 word0 的沿才写入内部错误寄存器。
  logic [7:0] next_sum, next_xor; // 本 word 加入后的组合摘要；没有触发器记忆，下一沿再保存。
  assign busy_o = state == PROCESS; // == 表示判断是否相等；当前状态是 PROCESS 就输出忙=1，否则为 0。
  assign done_o = state == DONE; // 当前状态是 DONE 就输出完成=1，并保持到下一次启动或复位。
  assign mem_rd_en_o = busy_o; // 忙=1 时向存储器发读请求；最后一份数据返回的这一拍也可能重复发出末地址请求，但不会再次处理它。
  assign {header_length, header_type, header_flags, header_chk} = mem_rd_data_i; // 把 32 位读数据从高到低分成四份 8 位：长度、类型、保留字段、头校验，{ } 表示按位拼接关系。

  function automatic logic type_allowed(input logic [7:0] kind, input logic [3:0] allowed); // 输入 kind 和四位 allowed，立即返回此类型是否允许；不等待时钟。
    case (kind)
      8'h01: return allowed[0]; // 类型 01 对应 mask 的 bit0；不是用 kind 直接作为数组下标。
      8'h02: return allowed[1]; // 类型 02 对应 mask 的 bit1。
      8'h04: return allowed[2]; // 类型 04 对应 mask 的 bit2。
      8'h08: return allowed[3]; // 类型 08 对应 mask 的 bit3。
      default: return 0; // 其他类型即使 mask 全开也不允许，例如 03 或 10。
    endcase
  endfunction

  function automatic logic [2:0] final_word(input logic [7:0] length); // 根据总字节数计算末 word 编号；用于限制内存访问和判断完成。
    if (length < 4 || length > 32) return 0; // || 表示或者；长度小于 4 或大于 32 就返回末字编号 0，只处理包头后结束，避免越界读。
    return 3'((int'(length) - 1) / 4); // (总长度-1)/4 算出最后一个 32 位字的编号，例如 8 字节得 1、32 字节得 7；int' 转整数计算，3' 将结果限为 3 位。
  endfunction

  assign header_length_error = header_length < 4 || header_length > 32 || // 长度小于 4 或大于 32，或者下面的“已配置期望长度但不相等”成立，就表示长度错误。
                               (expected_length != 0 && header_length != {2'b0, expected_length}); // && 表示并且；期望长度不为 0 且实际长度不等于期望时才报错，{2'b0,...} 在高位补两个 0。
  assign header_type_error = !type_allowed(header_type, mask); // 调用函数判断类型是否允许，前面的 ! 将结果取反：不允许就报类型错误。
  assign header_chk_error = mode && (header_chk != (header_length ^ header_type ^ header_flags)); // 开启校验且头校验值不等于长度、类型、保留字段三者的异或时，才报校验错误；^ 表示逐位异或。

 // 内存返回的包头可能刚出现、尚未存入寄存器；先用当前返回值计算地址上限，后续请求才能及时停止递增。
  always_comb begin // 组合选择下一请求地址；不等新时钟，也不增加一个状态机状态。
    last_index_now = last_index; // 默认用已经保存的末字索引，给组合路径完整赋值。
    if (response_valid && response_index == 0) // 返回有效且返回编号为 0 时，这份数据才是包头，用它计算本帧最后一个字的编号。
      last_index_now = final_word(header_length); // 立即由返回包头算末字，让下一请求不必再等 last_index 寄存器更新。
    mem_rd_addr_o = read_index < last_index_now ? read_index : last_index_now; // ? : 表示二选一；请求编号小于末字编号就用请求编号，否则用末字编号，防止地址超过报文末尾。
  end

 // 一个返回字包含四个字节；先用组合计算得到加入本字后的摘要，再由后面的时钟过程决定何时保存和交付结果。
  always_comb begin // 本 word 内的字节选择、加法和 XOR 网络；for 中没有时钟等待。
    next_sum = payload_sum; // 从此前保存的总和起算，不能每读一个 word 都重新从 0 累加。
    next_xor = payload_xor; // 从此前保存的 XOR 起算，保留前面 payload word 的贡献。
    for (int lane = 0; lane < 4; lane++) begin // lane 从 0 到 3 依次选四个字节，计算之间没有等时钟，所以这不是等待四拍。
      if (int'(response_index) * 4 + lane < int'(packet_length)) begin // 字编号×4+字节编号得到整帧内的位置，只有小于总长度才参与计算；例如长 7 字节时，位置 7 的填充数据跳过。
        next_sum = next_sum + mem_rd_data_i[31 - lane * 8 -: 8]; // 从第 31-lane×8 位开始向下取 8 位相加；lane=0 取 [31:24]，lane=1 取 [23:16]，结果只留 8 位。
        next_xor = next_xor ^ mem_rd_data_i[31 - lane * 8 -: 8]; // 把同一个有效字节异或进结果；= 立即更新临时值，下一次循环接着这个结果算。
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin // 在时钟沿保存状态与进度；<= 的右侧均取该沿更新前的值。
    if (!rst_n) begin // rst_n=0 时复位，清工作进度和结果，状态回到等待。
      state <= IDLE; // 复位回等待阶段，组合译码使 busy=0、done=0、读使能=0。
      mode <= 1; // 配置快照的确定初值；下一次合法启动再从输入采样真实模式。
      mask <= 4'hF; // 默认类型快照全允许，下一次启动可覆盖。
      expected_length <= 0; // 清期望长度快照，0 表示未配置。
      packet_length <= 0; // 清本帧解析长度，防止旧工作数据混入复位后计算。
      packet_type <= 0; // 清本帧解析类型。
      length_error <= 0; // 清工作区的长度错误。
      type_error <= 0; // 清工作区的类型错误。
      chk_error <= 0; // 清工作区的校验错误。
      payload_sum <= 0; // 清已累计总和，复位后没有有效 payload 贡献。
      payload_xor <= 0; // 清已累计 XOR。
      read_index <= 0; // 下一帧从 word0 请求包头。
      last_index <= 0; // 清末字记录，等真实包头返回后再确定。
      response_index <= 0; // 清返回编号；是否可消费还由 response_valid 决定。
      response_valid <= 0; // 丢弃所有旧返回，不会把复位前的数据当成新包头。
      res_pkt_len_o <= 0; // 清软件/外部能观察到的长度结果。
      res_pkt_type_o <= 0; // 清外部类型结果。
      res_payload_sum_o <= 0; // 清外部 sum 结果。
      res_payload_xor_o <= 0; // 清外部 XOR 结果。
      format_ok_o <= 0; // 复位没有完成的正确报文，因此 format_ok=0。
      length_error_o <= 0; // 清外部长度错误标志。
      type_error_o <= 0; // 清外部类型错误标志。
      chk_error_o <= 0; // 清外部校验错误标志。
    end else begin
      case (state) // 按本沿更新前的 state 选择一个分支执行，不是按顺序执行所有分支。
        IDLE, DONE: begin // 状态为等待或完成时都走这里；有新 start 就开始新帧，没有则保持当前状态和结果。
          response_valid <= 0; // 非处理阶段不消费内存旧返回，为下一帧重新建立有效标签。
          if (start_i) begin // 本上升沿采到 start_i=1 时开始新帧，先保存配置并清旧结果。
            state <= PROCESS; // 沿后 busy 拉高、done 拉低；内存读请求随后由状态译码拉高。
            mode <= algo_mode_i; // 保存启动时模式，后续头部检查用 mode 而不是实时输入。
            mask <= type_mask_i; // 保存启动时四位类型掩码。
            expected_length <= exp_pkt_len_i; // 保存启动时期望总长度。
            read_index <= 0; // 新帧的第一笔读请求必须指向 word0。
            last_index <= 0; // 先设末字为 0，头部返回后才知道真实末字。
            response_index <= 0; // 重置返回标签，配合 response_valid=0 排除旧返回。
            payload_sum <= 0; // 新帧 sum 从 0 开始，不能继续上一帧。
            payload_xor <= 0; // 新帧 XOR 从 0 开始。
            length_error <= 0; // 清本帧工作长度错误。
            type_error <= 0; // 清本帧工作类型错误。
            chk_error <= 0; // 清本帧工作校验错误。
            res_pkt_len_o <= 0; // 接受新 start 就清旧长度结果，外部不能继续把上帧结果当本帧结果。
            res_pkt_type_o <= 0; // 清旧类型结果，等待本帧完成。
            res_payload_sum_o <= 0; // 清旧 sum，纯头包或非法长度时保持为 0。
            res_payload_xor_o <= 0; // 清旧 XOR。
            format_ok_o <= 0; // 本帧未完成，先不报告格式正确。
            length_error_o <= 0; // 清对外长度错误，完成时再统一发布本帧判定。
            type_error_o <= 0; // 清对外类型错误。
            chk_error_o <= 0; // 清对外校验错误。
          end
        end
        PROCESS: begin // 处理阶段一边发出读请求，一边在返回有效时处理上一次请求的数据。
          response_valid <= 1; // 记住本沿发过请求，下一上升沿才可以处理这次返回；本沿判断仍用更新前的 response_valid。
          response_index <= mem_rd_addr_o; // 记下本沿实际请求的字编号；下一沿用这个编号识别返回的是包头还是负载。
          if (read_index != 7) read_index <= read_index + 3'd1; // 请求编号不等于 7 时加 1，到了 7 就保持；!= 表示不等于。
          if (response_valid) begin // 只有上一次请求已产生有效返回才处理数据；首次发请求的这一沿还不能处理。
            if (response_index == 0) begin // 返回字编号为 0，按包头解释，保存长度、类型和各项错误。
              packet_length <= header_length; // 把包头 Byte0 保存下来，后续用于尾字节过滤。
              packet_type <= header_type; // 保存包头 Byte1，完成时交付类型结果。
              last_index <= final_word(header_length); // 确定这帧最后一个有效 word，后续据此结束。
              length_error <= header_length_error; // 记住长度判定，后面消费 payload 时不重新解析头部。
              type_error <= header_type_error; // 记住类型判定。
              chk_error <= header_chk_error; // 记住头校验判定。
              if (final_word(header_length) == 0) begin // 最后一个字就是第 0 字时，说明只有包头或长度非法，发布头部结果并结束。
                state <= DONE; // 沿后进入完成态，停止读使能并保持 done。
                res_pkt_len_o <= header_length[5:0]; // 取当前包头长度低 6 位输出；这里不能取刚赋值的 packet_length，因为本沿读到它仍是旧值。
                res_pkt_type_o <= header_type; // 直接发布当前头部类型，避免读取 packet_type 的旧值。
                length_error_o <= header_length_error; // 头部即结束时，直接发布本拍组合判定。
                type_error_o <= header_type_error; // 独立发布类型错误，不被长度错误屏蔽。
                chk_error_o <= header_chk_error; // 独立发布校验错误。
                format_ok_o <= !(header_length_error || header_type_error || header_chk_error); // 三种头部错误只要有一种为 1，括号内就为 1，! 取反后格式正确标志为 0。
              end
            end else begin // 返回编号非零时按 payload 处理；头部四字节不进入摘要。
              payload_sum <= next_sum; // 沿后保存包含本 word 有效 byte 的新总和。
              payload_xor <= next_xor; // 沿后保存本 word 处理后的新 XOR。
              if (response_index == last_index) begin // 当前返回字编号等于最后一个字编号，说明本帧处理完了，现在发布结果。
                state <= DONE; // 最后一份返回已处理，沿后 DONE；末拍可能发出的重复读不再消费。
                res_pkt_len_o <= packet_length[5:0]; // 发布此前保存的包头长度，而不是把 payload 的高 byte 当长度。
                res_pkt_type_o <= packet_type; // 发布此前保存的包头类型。
                res_payload_sum_o <= next_sum; // 输出已经算入最后一个字的新总和；若取 payload_sum，本沿读到旧值就会漏算末字。
                res_payload_xor_o <= next_xor; // 输出已经算入最后一个字的新异或结果，避免使用尚未更新的 payload_xor。
                length_error_o <= length_error; // 发布包头阶段记住的长度错误。
                type_error_o <= type_error; // 发布包头阶段记住的类型错误。
                chk_error_o <= chk_error; // 发布包头阶段记住的校验错误。
                format_ok_o <= !(length_error || type_error || chk_error); // 长度、类型、校验都没错时才输出格式正确=1；|| 是或者，! 是取反。
              end
            end
          end
        end
        default: state <= IDLE; // 未识别状态时恢复等待态；正常流程只走上面三个 enum 状态。
      endcase
    end
  end
endmodule
