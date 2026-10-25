`timescale 1ns/1ps

 // M1 把主机给出的地址、方向和数据转换成配置寄存器操作或 M2 存储访问，并把处理核状态按地址返回给主机。
 // 以下 input/output 均相对于 M1；Lab1 中主机和处理核状态由测试程序提供，报文存储则连接实际 M2。
module apb_slave_if (
  input  logic        PCLK, // 来自系统/测试程序；M1 在上升沿接收 ACCESS 请求。
  input  logic        PRESETn, // 来自系统/测试程序；低有效复位，本实现采用异步复位。
  input  logic        PSEL, // 来自 APB 访问方；1 表示选中 M1。
  input  logic        PENABLE, // 来自访问方；PSEL=1 时，0 为 SETUP，1 为 ACCESS。
  input  logic        PWRITE, // 来自访问方；0 读、1 写，同一笔访问中方向不能改变。
  input  logic [11:0] PADDR, // 来自访问方；12 位字节地址，SETUP 到 ACCESS 保持稳定。
  input  logic [31:0] PWDATA, // 来自访问方；32 位写数据，写访问期间保持稳定。
  output logic [31:0] PRDATA, // 送给访问方；读 ACCESS 的接收边沿采样，保留位读 0。
  output logic        PREADY, // 送给访问方；固定 1，不增加等待周期。
  output logic        PSLVERR, // 送给访问方；仅 ACCESS 报告错误，错误写不能修改目标。
  input  logic [31:0] pkt_mem_rdata_i, // 来自 M2.apb_rd_data；这是读出的数据，不是指令。
  output logic        pkt_mem_we_o, // 送 M2.apb_wr_en；合法内存写才允许保存数据。
  output logic [2:0]  pkt_mem_addr_o, // 送 M2.apb_addr；3 位 word 索引，范围 0~7。
  output logic [31:0] pkt_mem_wdata_o, // 送 M2.apb_wr_data；来自本笔 APB 的 PWDATA。
  output logic        pkt_mem_re_o, // 送 M2.apb_rd_en；SETUP 提前读，ACCESS 才能及时返回。
  input  logic        busy_i, // STATUS[0]：处理忙；禁止此时覆盖报文内存。
  input  logic        done_i, // STATUS[1]：处理完成电平；其上升沿可产生中断。
  input  logic        format_ok_i, // STATUS[3]：格式正确标志，只读直透。
  input  logic        length_error_i, // ERR_FLAG[0]：长度错误，参与总错误判断。
  input  logic        type_error_i, // ERR_FLAG[1]：类型错误，可与其他错误同时成立。
  input  logic        chk_error_i, // ERR_FLAG[2]：校验错误，可与其他错误同时成立。
  input  logic [5:0]  res_pkt_len_i, // RES_PKT_LEN[5:0]：长度结果，只读直透。
  input  logic [7:0]  res_pkt_type_i, // RES_PKT_TYPE[7:0]：类型结果，只读直透。
  input  logic [7:0]  res_payload_sum_i, // RES_PAYLOAD_SUM[7:0]：累加和结果，只读直透。
  input  logic [7:0]  res_payload_xor_i, // RES_PAYLOAD_XOR[7:0]：异或结果，只读直透。
  output logic        enable_o, // 保存 CTRL[0]；M1 用它决定是否允许 START，当前 M3 本身没有 enable_i 端口。
  output logic        start_o, // 送 M3.start_i 的单周期命令；1 表示启动一次，不能当作长期保存的开关。
  output logic        algo_mode_o, // 保存 CFG[0]，送 M3.algo_mode_i；M3 启动时采样，控制包头校验是否启用。
  output logic [3:0]  type_mask_o, // 保存 CFG[7:4]，送 M3.type_mask_i；四位分别允许类型 01/02/04/08。
  output logic [5:0]  exp_pkt_len_o, // 保存期望总字节数，送 M3.exp_pkt_len_i；当前 M3 中 0 表示不启用一致性检查。
  output logic        done_irq_en_o, // IRQ_EN[0]，RW，复位 0；允许捕获完成中断。
  output logic        err_irq_en_o, // IRQ_EN[1]，RW，复位 0；允许捕获带错完成中断。
  output logic        irq_o // 送外部中断接收方；两个待清除中断状态标志的 OR。
);
  localparam logic [11:0] CTRL            = 12'h000;
  localparam logic [11:0] CFG             = 12'h004;
  localparam logic [11:0] STATUS          = 12'h008;
  localparam logic [11:0] IRQ_EN          = 12'h00C;
  localparam logic [11:0] IRQ_STA         = 12'h010;
  localparam logic [11:0] PKT_LEN_EXP     = 12'h014;
  localparam logic [11:0] RES_PKT_LEN     = 12'h018;
  localparam logic [11:0] RES_PKT_TYPE    = 12'h01C;
  localparam logic [11:0] RES_PAYLOAD_SUM = 12'h020;
  localparam logic [11:0] RES_PAYLOAD_XOR = 12'h024;
  localparam logic [11:0] ERR_FLAG        = 12'h028;
  logic access_phase; // 由当前总线输入组合算出 ACCESS 是否有效，不保存到下一拍。
  logic write_access; // 当前是写 ACCESS；它只是请求，还需要地址、权限和复位检查才可执行。
  logic memory_address; // 1 位命中标志，不是实际内存地址；真正的 word 索引是 pkt_mem_addr_o。
  logic error_any; // 三种处理错误的 OR，供 STATUS[2] 与错误 IRQ 使用。
  logic previous_done; // 上一拍 done_i；区别上升沿事件和持续高电平。
  logic done_irq; // IRQ_STA[0] 对外可见值：已保存的完成中断，或本周期满足使能的新完成。
  logic err_irq; // IRQ_STA[1] 对外可见值：已保存的错误中断，或本周期满足使能的带错完成。
  logic done_irq_saved, err_irq_saved; // 两个保存位，记住尚未被软件清除的中断，不随 done 回落或关闭使能而清零。

 // 主机只给出数值地址，因此先定义可复用的地址判断函数；输入 address 来自后面的 PADDR 调用，返回 1 位合法性结果。
  function automatic bit is_csr_address(input logic [11:0] address); // 接收 PADDR 的数值，判断是否属于下面列出的寄存器地址，是则返回 1，否则返回 0；每次调用的参数独立。
    case (address) // case 按 address 的数值匹配下面列出的地址；命中哪一项就执行那一项。
      CTRL, CFG, STATUS, IRQ_EN, IRQ_STA, PKT_LEN_EXP,
      RES_PKT_LEN, RES_PKT_TYPE, RES_PAYLOAD_SUM, RES_PAYLOAD_XOR, ERR_FLAG:
        return 1; // 命中任意一个列出的 CSR，证明该寄存器地址存在。
      default: return 0; // 其他地址不属于 CSR；它仍可能是合法 PKT_MEM，调用方需另判断。
    endcase
  endfunction

 // 合法地址还要区分能否写入；这个函数只识别只读地址，后面的错误判定使用其返回值拒绝对应写请求。
  function automatic bit is_read_only(input logic [11:0] address); // 接收地址并判断是否只读，是则返回 1；IRQ_STA 可以写 1 清除，所以不列在只读地址中。
    case (address) // case 按 address 的数值匹配下面列出的地址；命中哪一项就执行那一项。
      STATUS, RES_PKT_LEN, RES_PKT_TYPE, RES_PAYLOAD_SUM, RES_PAYLOAD_XOR, ERR_FLAG:
        return 1; // 这些地址仅返回外部状态/结果，APB 写不能改变它们。
      default: return 0; // 返回 0 仅表示不是 RO；不等于任意地址都合法、可写。
    endcase
  endfunction

  assign access_phase = PSEL && PENABLE; // && 表示同时满足；PSEL=1 且 PENABLE=1 时，才表示本次访问到了执行阶段。
  assign write_access = access_phase && PWRITE; // 执行阶段有效且 PWRITE=1 时，write_access 才为 1，表示本次要写数据。
  assign memory_address = (PADDR >= 12'h040) && (PADDR <= 12'h05C) && (PADDR[1:0] == 2'b00); // 地址在 040～05C 内且低两位为 00 时置 1，即只接受 040、044、048 等按 4 字节对齐的地址。
  assign error_any = length_error_i | type_error_i | chk_error_i; // | 表示按位或；三种处理错误只要有一种为 1，总错误标志就为 1。
  assign PREADY = 1'b1; // 固定返回 1，表示本实验不需要主机多等几个周期；访问仍须经过准备和执行两个阶段。
  assign irq_o = done_irq | err_irq; // 完成中断或错误中断有一个被记录为 1，就向外部输出中断信号 1。

  always_comb begin // always_comb 表示按当前输入计算结果，相关输入改变就重新计算，不等时钟。
    PSLVERR = 0; // 先给所有路径默认无错；只有下面命中的本次 ACCESS 才报错。
    if (access_phase) begin // 只在 ACCESS 报告 PSLVERR；空闲和 SETUP 保持默认 0。
      if (!is_csr_address(PADDR) && !memory_address) PSLVERR = 1; // ! 表示取反、&& 表示并且；地址既不是寄存器地址，也不是合法内存地址时，报访问错误。
      else if (PWRITE && is_read_only(PADDR)) PSLVERR = 1; // PWRITE=1 表示写，is_read_only 返回 1 表示只读；尝试写只读地址时，报访问错误。
      else if (PWRITE && memory_address && busy_i) PSLVERR = 1; // 正在写内存且处理核忙时，报访问错误，防止处理到一半的报文被覆盖。
    end
  end
  assign pkt_mem_addr_o = PADDR[4:2]; // 取地址第 4～2 位作为 M2 的位置编号；例如字节地址 04C 对应编号 3，每个位置存 32 位。
  assign pkt_mem_wdata_o = PWDATA; // 把主机给的写数据送到 M2；是否保存还要看 pkt_mem_we_o 是否为 1。
  assign pkt_mem_we_o = PRESETn && write_access && memory_address && !PSLVERR; // 未复位、处于写执行阶段、地址属于内存且没有报错，这四项同时满足才允许 M2 在上升沿写入。
  assign pkt_mem_re_o = PRESETn && PSEL && !PWRITE && memory_address; // 未复位、选中本模块、方向是读且地址属于内存时，就提前让 M2 读取，供下一执行阶段返回数据。

  always_comb begin // 按当前地址选择要返回的数据；这是读数据选择逻辑，不会写入寄存器。
    PRDATA = 0; // 先把返回数据设为 0；下面有匹配地址才替换，未选中、写操作或无匹配时都返回 0。
    if (PSEL && !PWRITE) begin // 选中本模块且 PWRITE=0，也就是主机在读时，才按地址把内容放到 PRDATA 返回。
      case (PADDR) // PADDR 选择返回来源；地址是 12 位，返回数据是 32 位，两者不是同一类数据。
        CTRL:            PRDATA = {31'b0, enable_o}; // { } 把各部分从高位到低位拼在一起：高 31 位为 0，最低位放保存的 enable，启动位始终读到 0。
        CFG:             PRDATA = {24'b0, type_mask_o, 3'b0, algo_mode_o}; // 把保存的 type_mask 放第 7～4 位、algo_mode 放第 0 位，其余补 0，例如 mask=A、mode=0 时读到 A0。
        STATUS:          PRDATA = {28'b0, format_ok_i, error_any, done_i, busy_i}; // 把外部状态放低四位：第 3 位格式正确、第 2 位有错、第 1 位完成、第 0 位忙，高 28 位补 0。
        IRQ_EN:          PRDATA = {30'b0, err_irq_en_o, done_irq_en_o}; // 低两位返回保存的中断使能：第 1 位允许错误中断，第 0 位允许完成中断。
        IRQ_STA:         PRDATA = {30'b0, err_irq, done_irq}; // 低两位返回当前可见的中断：第 1 位错误、第 0 位完成；读这里只查看，不清除。
        PKT_LEN_EXP:     PRDATA = {26'b0, exp_pkt_len_o}; // 把保存的六位期望长度送回主机，高 26 位不保存，直接补 0。
        RES_PKT_LEN:     PRDATA = {26'b0, res_pkt_len_i}; // 长度来自 M3/测试程序，M1 只选通和补零，不解析报文得到长度。
        RES_PKT_TYPE:    PRDATA = {24'b0, res_pkt_type_i}; // 类型来自 M3/测试程序，送到 APB 读回低八位。
        RES_PAYLOAD_SUM: PRDATA = {24'b0, res_payload_sum_i}; // sum 来自 M3/测试程序，M1 不做 payload 加法；高 24 位补零。
        RES_PAYLOAD_XOR: PRDATA = {24'b0, res_payload_xor_i}; // XOR 来自 M3/测试程序，M1 不做 payload 异或；高 24 位补零。
        ERR_FLAG:        PRDATA = {29'b0, chk_error_i, type_error_i, length_error_i}; // 三类外部错误分别接低三位，允许多个错误同时为 1。
        default: if (memory_address) PRDATA = pkt_mem_rdata_i; // CSR 均不匹配后，合法内存地址选择 M2 返回的数据；否则保留默认 0。
      endcase
    end
  end

  always_ff @(posedge PCLK or negedge PRESETn) begin // 配置需要记忆：PCLK 沿接受合法写，PRESETn 下降沿可立即恢复默认值。
    if (!PRESETn) begin // !PRESETn 表示复位输入为 0；此时执行下面的复位赋值。
      enable_o <= 0; // 复位后默认禁止启动，等待软件写 CTRL.enable。
      start_o <= 0; // 复位期间不向 M3 发启动命令。
      algo_mode_o <= 1; // 默认启用头校验；与下面四位 mask 合成 CFG=F1。
      type_mask_o <= 4'b1111; // 默认允许四种合法类型；这些是四个保存位，不是地址位。
      exp_pkt_len_o <= 0; // 复位后不做配置长度一致性检查；M3 仍检查实际长度范围。
      done_irq_en_o <= 0; // 复位后禁止捕获完成 IRQ。
      err_irq_en_o <= 0; // 复位后禁止捕获错误 IRQ，待清除中断状态另由下方时序块复位。
    end else begin
      start_o <= 0; // 本拍先安排 start_o 清零；下面若满足合法启动条件会改为置 1，因此启动信号只保持一拍。
      if (write_access && !PSLVERR) begin // 处于写执行阶段且没有报错时，才按 PADDR 更新对应配置。
        case (PADDR) // 写地址选择要更新的那组保存字段，不会把数据同时广播写进所有 CSR。
          CTRL: begin
            enable_o <= PWDATA[0]; // 取写数据最低位保存为 enable，供以后判断是否允许启动。
            if (PWDATA[1] && enable_o && !busy_i) start_o <= 1; // 写数据第 1 位为 1、之前保存的 enable=1 且处理核不忙时，启动输出拉高一拍；这里读的仍是本沿更新前的 enable。
          end
          CFG: begin
            algo_mode_o <= PWDATA[0]; // 取写数据最低位保存为校验开关，处理核在下一次启动时读取。
            type_mask_o <= PWDATA[7:4]; // 取写数据第 7～4 位保存为四种类型的许可，其他数据位忽略。
          end
          IRQ_EN: begin
            done_irq_en_o <= PWDATA[0]; // 保存写数据第 0 位，决定以后新完成事件能否置中断；关闭使能不会清除已有中断。
            err_irq_en_o <= PWDATA[1]; // 保存写数据第 1 位，决定以后带错完成事件能否置错误中断。
          end
          PKT_LEN_EXP: exp_pkt_len_o <= PWDATA[5:0]; // 仅保存有效六位；写数据的其他位被忽略，读回时补 0。
          default: begin end // 这组时序块不处理其他地址；IRQ_STA 在下面处理，内存写由 M2 完成。
        endcase
      end
    end
  end

  // M3 在同一 PCLK 沿后更新 done 和错误，并保持到下一采样沿；新事件先组合可见，下一沿再保存。
  assign done_irq = PRESETn && (done_irq_saved || (done_i && !previous_done && done_irq_en_o));
  assign err_irq = PRESETn && (err_irq_saved || (done_i && !previous_done && err_irq_en_o && error_any));

  always_ff @(posedge PCLK or negedge PRESETn) begin // 保存 IRQ 历史，previous_done 仍只由 PCLK 采样，不把 done 当时钟。
    if (!PRESETn) begin
      previous_done <= 0;
      done_irq_saved <= 0;
      err_irq_saved <= 0;
    end else begin
      previous_done <= done_i;
      // W1C 清除此前已可见的事件，不能再被本沿保存回来；本沿后新出现的完成仍经上方组合路径响应。
      if (write_access && !PSLVERR && PADDR == IRQ_STA) begin
        done_irq_saved <= done_irq && !PWDATA[0];
        err_irq_saved <= err_irq && !PWDATA[1];
      end else begin
        done_irq_saved <= done_irq;
        err_irq_saved <= err_irq;
      end
    end
  end
endmodule
