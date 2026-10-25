`timescale 1ns/1ps

 // 测试程序需要统一的报文格式、结果格式和多组测试流程，因此把这些定义集中到包中，供顶层 import 后使用。
package lab2_pkg; // 公共类型和测试类集中在此；tb_lab2 用 import 引入名称，不例化 package。
  typedef bit [7:0] byte_t; // 给 8 位、只能存 0/1 的数据格式起名 byte_t，用来保存测试报文的一个字节。
  typedef logic [31:0] word_t; // 给 32 位 logic 数据格式起名 word_t，它可以保存 X/Z，便于发现未知读数据。
  typedef word_t words_t [0:7]; // 给“8 个位置、每个位置 32 位”的数组格式起名 words_t，后面用它声明整份报文数组。
  typedef struct packed { // 把下面的结果字段组成一份 34 位记录格式，结尾命名 result_t，供声明预期和实际结果使用。
    logic [5:0] length; // 结果长度的有效六位，与 M3.res_pkt_len_o 位宽一致。
    logic [7:0] kind, sum, xor_value; // 类型、sum、XOR 各 8 位，与 M3 的三个结果端口一一对应。
    logic length_error, type_error, chk_error, format_ok; // 三种独立错误和格式总判定，与四个结果标志端口对应。
  } result_t;

 // 报文内容需要随测试变化，因此 class 定义一份“包含哪些数据、能做哪些操作”的方案；后面 pkt = new(...) 才创建一帧实际仿真报文。
  class packet; // class 定义报文应有哪些数据和操作，packet 是这个类的名字；后面执行 new 才会创建具体报文。
    byte_t length, kind, flags, hdr_chk; // 四个头部 byte：总长度、类型、保留字段、头校验。
    byte_t payload []; // 声明只保存负载字节的数组，[] 表示大小暂不固定，下面用 new[...] 按包长分配。

    function new(input byte_t length = 8, input byte_t kind = 1); // new 创建报文时自动执行这里；未传参数就用长度 8、类型 1，并生成后面的头部和负载内容。
      this.length = length; // 把本次传入的 length 保存到报文成员；this.length 指当前报文中的长度，右边是同名输入参数。
      this.kind = kind; // 把本次传入的类型保存到当前报文成员 kind。
      flags = 0; // 本版本合法报文的保留 flags 固定为 0。
      hdr_chk = length ^ kind ^ flags; // ^ 表示逐位异或；把头部前三个字节异或，得到第四个字节的头校验值。
      payload = new[(length >= 4 && length <= 32) ? int'(length) - 4 : 0]; // ? : 表示二选一；长度在 4～32 内就分配“总长度-4”个负载字节，否则分配 0 个。
      foreach (payload[i]) payload[i] = byte_t'(i + 1); // foreach 逐个访问已分配的位置，填入 1、2、3……；byte_t' 将每个值转成 8 位字节。
    endfunction

    function void pack_words(output words_t words); // 把当前报文打包成八个 32 位字；output words 把数组交回调用处，void 表示不另返回函数值。
      foreach (words[i]) words[i] = 32'hA5A5_A5A5; // 先把八个位置都填成 A5；下面再覆盖有效字节，未使用位置故意留非零，方便发现多算尾部的错误。
      words[0] = {length, kind, flags, hdr_chk}; // { } 按从高到低拼接四个头字节：长度放 [31:24]，类型放 [23:16]，再放保留字段和校验。
      foreach (payload[i]) begin // 逐个 payload byte 放入对应的 word 和 byte lane；此函数不推进时间。
        if (i >= 28) $fatal(1, "[PACK_FAIL] payload exceeds SRAM"); // 负载最多 28 字节；i 到 28 就表示出现第 29 个负载字节，报错并停止，防止越过容量。
        words[1 + i / 4][31 - (i % 4) * 8 -: 8] = payload[i]; // 第 i 个负载字节放在第 1+i/4 个字，i%4 选择字内位置；-:8 表示从指定高位向下取 8 位。
      end
    endfunction

    function result_t predict(input bit mode, input bit [3:0] mask, input bit [5:0] expected_length); // 根据报文内容和传入配置算预期结果，返回一份 result_t 记录，不读取被测电路结果。
      result_t value; // 本次参考计算的局部结果记录，各字段在下面填入。
      value = '0; // '0 将整份记录的所有位清零，然后下面逐项填写；没有负载时总和和异或自然为 0。
      value.length = length[5:0]; // 结果接口只有六位；参考值也按相同端口宽度保留。
      value.kind = kind; // 预期类型直接来自该测试 packet 的头部。
      value.length_error = length < 4 || length > 32 || (expected_length != 0 && length != expected_length); // 长度小于 4、大于 32，或者已配置非零期望长度却不相等，任一成立就将长度错误设为 1。
      case (kind) // 参考模型用表解释类型，不把任意 one-hot 的第 4～7 位误当合法类型。
        1: value.type_error = !mask[0]; // type01 被 mask[0]=0 屏蔽时应报错。
        2: value.type_error = !mask[1]; // type02 对应 mask[1]。
        4: value.type_error = !mask[2]; // type04 对应 mask[2]。
        8: value.type_error = !mask[3]; // type08 对应 mask[3]。
        default: value.type_error = 1; // 除 01/02/04/08 外均为类型错误。
      endcase
      value.chk_error = mode && hdr_chk != (length ^ kind ^ flags); // 开启校验且头校验与前三字节异或结果不一致时置 1；关闭校验则为 0。
      foreach (payload[i]) begin // 参考模型直接遍历真实 payload 长度，不依赖被测电路的 word/返回标签逻辑。
        value.sum += payload[i]; // += 相当于“原值+本字节后再保存”，结果字段只有 8 位，超过 FF 的高位丢弃。
        value.xor_value ^= payload[i]; // ^= 相当于“原值与本字节逐位异或后再保存”，逐字节累积得到预期异或结果。
      end
      value.format_ok = !(value.length_error || value.type_error || value.chk_error); // || 表示或者，! 表示取反；有任一错误就为 0，三种错误都为 0 才表示格式正确。
      return value; // 把填好的整份结果记录交回调用处，例如后面的 pkt.predict(...) 就得到这份值。
    endfunction

  endclass

  virtual class base_test; // 定义各测试共用的基类；不直接用它创建对象，后面的具体测试继承公共操作并补上 run 的内容。
    virtual proc_if vif; // 声明能指向实际接口的变量 vif；构造时接收顶层 bus，保存后就能通过 vif 访问同一组信号。
    string name; // 当前测试的可读名称，用于日志和失败定位。
    int seed; // 记录外部指定 seed；当前测试报文是定向数据，不因换 seed 自动随机化。
    int frames = 0, checks = 0; // frames 统计提交帧数，checks 统计比较次数；均是测试程序账本，不驱动被测电路。
    result_t expected_results [$]; // [$] 表示可增减长度的队列；按提交顺序保存预期，完成后从队首取出比较。
    int checks_by_item [string]; // [string] 表示用检查名字作下标，例如 checks_by_item["payload sum"] 保存这个项目检查过几次。

    function new(input virtual proc_if vif, input string name, input int seed); // 构造公共部分；接收实际接口句柄和测试身份，供派生类 super.new 调用。
      this.vif = vif; // 把传进来的实际接口引用保存到当前测试对象，后续用 this.vif 就能访问顶层 bus 中的信号。
      this.name = name; // 保存派生测试的名字。
      this.seed = seed; // 保存本次运行 seed，确保日志能追溯运行参数。
    endfunction

    function void check_value(input string item, input word_t actual, input word_t expected); // 无时间消耗的自动比较工具；actual 从被测电路接口来，expected 从参考模型来。
      checks++; // 每次调用均计入总检查数。
      if (!checks_by_item.exists(item)) checks_by_item[item] = 0; // exists 检查这个名字是否已存在，! 表示不存在；首次遇到该检查项时，先把次数设为 0。
      checks_by_item[item]++; // 把当前名字对应的检查次数加 1，记录这一类检查执行过几次。
      if ($isunknown(actual) || $isunknown(expected) || actual !== expected) // $isunknown 检查是否有 X/Z；|| 表示或者，即实际值有 X/Z、期望值有 X/Z，或者实际值不等于期望值，都判失败。
        $fatal(1, "[FAIL] test=%s seed=%0d frame=%0d item=%s expected=%08x actual=%08x", // 打印失败信息并停止仿真；%s 填名字，%0d 填十进制次数，%08x 填至少八位十六进制数据。
               name, seed, frames, item, expected, actual);
    endfunction

    task initialize(); // 公共初始化：复位被测电路和模型，再检查复位后应有的可观察状态。
      vif.reset_dut(); // 调用 interface 中会等待边沿的复位任务，实际驱动 rst_n/start/配置。
      check_value("reset busy/done", {30'b0, vif.busy, vif.done}, 0); // {busy,done}=00：复位后不忙也未完成。
      check_value("reset result", {2'b0, vif.res_pkt_len, vif.res_pkt_type, vif.res_payload_sum, vif.res_payload_xor}, 0); // 把四个结果字段拼成 32 位统一比较，补 2 个零只为对齐宽度。
      check_value("reset flags", {28'b0, vif.format_ok, vif.chk_error, vif.type_error, vif.length_error}, 0); // 复位后格式/三类错误全为 0，尚无一帧有效结果。
    endtask

 // 派生用例先用 pkt = new(...) 创建报文，再调用 run_packet(pkt,...)；这里的输入 pkt 接收同一报文对象的引用，配置参数则接收数值。
    task run_packet(input packet pkt, input bit mode = 1, input bit [3:0] mask = 4'hF,
                    input bit [5:0] expected_length = 0);
      words_t words; // 本帧打包后的八字数组，用于同步存储器模型。
      result_t expected, actual; // 两份独立记录：expected 是软件参考，actual 是被测电路端口采样。
      int cycles; // 等待完成的时钟计数，防止处理核永不结束。
      frames++; // 先记住这是第几帧；稍后监视过程还会核对实际接受的 start 数量。
      expected_results.push_back(pkt.predict(mode, mask, expected_length)); // 先用 pkt.predict 算出预期，再用 push_back 放到队尾，等待本帧完成后比较。
      pkt.pack_words(words); // 调用当前报文的打包函数，把得到的八字数组保存到本任务的 words 变量。
      foreach (words[i]) vif.load_word(i, words[i]); // foreach 遍历八个字，将 i 和 words[i] 交给接口的 load_word，逐个装入存储模型；每次调用会等待下降沿。
      $display("[FRAME_START] test=%s frame=%0d len=%0d type=%02x mode=%0d mask=%x exp_len=%0d payload_bytes=%0d", // 打印真实帧参数，失败时能定位到具体长度/类型/配置。
               name, frames, pkt.length, pkt.kind, mode, mask, expected_length, pkt.payload.size());
      vif.assert_start(mode, mask, expected_length); // 把模式、类型许可、期望长度传给接口任务，由它改变实际信号并拉高启动，等电路接受后再返回。
      check_value("first cycle busy/done", {30'b0, vif.busy, vif.done}, 2); // {busy,done}=10，即十进制 2；确认启动第一沿已经进入 PROCESS。
      check_value("start clears result", {2'b0, vif.res_pkt_len, vif.res_pkt_type, vif.res_payload_sum, vif.res_payload_xor}, 0); // 新 start 必须清旧结果，避免下游误读上一帧摘要。
      check_value("start clears flags", {28'b0, vif.format_ok, vif.chk_error, vif.type_error, vif.length_error}, 0); // 新帧开始时清上一帧的错误/正确标志。
      vif.release_start(); // 下一下降沿撤销 start；M3 内部状态机会继续处理，不依赖 start 一直高。
      cycles = 0; // 从启动后开始累计等待拍数。
      while (vif.done !== 1'b1 && cycles < 12) begin // while 表示条件成立就继续；完成不是确定的 1 且已等拍数小于 12 时，就再等一拍。
        @(posedge vif.clk); // 每次只等一个真实处理时钟沿。
        #1ns; // 等该沿寄存器更新完成后检查新的 done，避免读沿前旧值。
        cycles++; // 每次等过一个上升沿后把已等拍数加 1，用于限制等待时间。
      end
      if (vif.done !== 1'b1) // 等完后 done 仍不是确定的 1，说明超时或状态异常，执行下一句报错。
        $fatal(1, "[TIMEOUT] test=%s frame=%0d len=%0d cycles=%0d", name, frames, pkt.length, cycles); // 超时消息保留测试名、帧号、长度和实际等待拍数。
      if (expected_results.size() == 0) $fatal(1, "[QUEUE_FAIL] no expected result"); // size() 取队列中的条目数；完成时没有待比较的预期，就报错，防止漏掉比较。
      expected = expected_results.pop_front(); // pop_front 从队首取出并删除最早一份预期，保存到 expected，与本次完成结果配对。
      actual = '{length:vif.res_pkt_len, kind:vif.res_pkt_type, // 按字段把接口上的实际结果装入 actual 记录，后面逐项与 expected 比较。
                 sum:vif.res_payload_sum, xor_value:vif.res_payload_xor,
                 length_error:vif.length_error, type_error:vif.type_error,
                 chk_error:vif.chk_error, format_ok:vif.format_ok};
      check_value("result length", {26'b0, actual.length}, {26'b0, expected.length}); // 核对解析总长度；高位补零只是适配 check_value 的 32 位参数。
      check_value("result type", {24'b0, actual.kind}, {24'b0, expected.kind}); // 核对包头类型字段。
      check_value("payload sum", {24'b0, actual.sum}, {24'b0, expected.sum}); // 核对 payload sum，可发现漏 word、字节顺序或尾部填充被算入等错误。
      check_value("payload xor", {24'b0, actual.xor_value}, {24'b0, expected.xor_value}); // 核对 payload XOR。
      check_value("error flags", {29'b0, actual.chk_error, actual.type_error, actual.length_error}, // 三位按 chk/type/length 排列，actual 与 expected 必须采用相同顺序。
                  {29'b0, expected.chk_error, expected.type_error, expected.length_error});
      check_value("format_ok", {31'b0, actual.format_ok}, {31'b0, expected.format_ok}); // 核对错误汇总后的 format_ok，不只检查各错误位。
      check_value("completion busy/done", {30'b0, vif.busy, vif.done}, 1); // {busy,done}=01：处理结束后不忙且完成有效。
      repeat (3) begin // 重复下面的等待和检查三次，确认完成信号持续保持，而不是只高一拍。
        @(posedge vif.clk); // 等一个后续采样沿，此时没有新 start。
        #1ns; // 在沿后读取稳定的新状态。
        check_value("DONE holds", {30'b0, vif.busy, vif.done}, 1); // 这三拍都应维持 done=1、busy=0；结果保持另有顶层监视过程核对。
      end
      $display("[FRAME_PASS] test=%s frame=%0d cycles=%0d len=%0d type=%02x sum=%02x xor=%02x errors=%b format_ok=%b queue_left=%0d", // 记录本帧结果及等待拍数；日志里队列剩余数应回到 0。
               name, frames, cycles, actual.length, actual.kind, actual.sum, actual.xor_value,
               {actual.chk_error, actual.type_error, actual.length_error}, actual.format_ok, expected_results.size());
    endtask

    function void finish_checks(); // 测试结束统一对账，防止空测试或遗留期望也打印 PASS。
      int total; // 局部累计值，用于核对关联数组统计是否完整。
      check_value("expected queue empty", expected_results.size(), 0); // 所有已提交帧都应完成比较，没有遗留期望。
      if (frames == 0) $fatal(1, "[EMPTY_TEST] test=%s", name); // 帧数为 0 表示没有真正测过报文，直接报错，不能让空测试显示通过。
      total = 0; // 准备累计每个检查名的次数。
      foreach (checks_by_item[item]) begin // 逐个访问已经出现的检查名字，item 每次取一个名字，用来累计和打印对应次数。
        total += checks_by_item[item]; // 把当前检查项的次数加到 total，最后与总检查次数对账。
        $display("[CHECK_COUNT] test=%s item=%s count=%0d", name, item, checks_by_item[item]); // 输出分项统计，表明哪些检查真正运行过。
      end
      if (total != checks) $fatal(1, "[STATS_FAIL] total=%0d checks=%0d", total, checks); // 各项目次数相加不等于检查总数，说明统计漏记或记错，报错并停止。
      $display("[PASS] test=%s seed=%0d frames=%0d checks=%0d expected_queue=%0d", name, seed, frames, checks, expected_results.size()); // 只有此前均未 fatal，才报告此测试的帧数/检查数及空队列。
    endfunction

    pure virtual task run(); // 这里只规定“具体测试必须有 run”，不写执行内容；后面调用 test.run() 时执行所选测试自己的 run。
  endclass

  class normal_test extends base_test; // extends 表示继承 base_test 的公共操作；normal_test 自己的 run 选择正常报文和边界长度。

    function new(input virtual proc_if vif, input int seed);
      super.new(vif, "normal", seed); // super.new 调用基类的构造函数，把接口、当前测试名和 seed 保存到公共成员，供后续驱动和日志使用。
    endfunction

    task run();
      packet pkt; // 先声明保存报文对象引用的变量 pkt，随后 pkt=new(...) 才创建具体报文。
      pkt = new(4, 1);  run_packet(pkt); // 最小合法 4B：仅头部，无 payload，两个摘要应为 0。
      pkt = new(8, 2);  run_packet(pkt); // 8B/type02：一字头加一字 payload，便于手算结果。
      pkt = new(32, 4); run_packet(pkt); // 最大合法 32B：验证八字地址与全部 payload 都被消费。
    endtask

  endclass

  class length_test extends base_test; // 继承公共操作，run 用长度 3 和 33 检查越界报文能报错并结束。

    function new(input virtual proc_if vif, input int seed);
      super.new(vif, "length", seed); // super.new 调用基类的构造函数，把接口、当前测试名和 seed 保存到公共成员，供后续驱动和日志使用。
    endfunction

    task run();
      packet pkt; // 先声明保存报文对象引用的变量 pkt，随后 pkt=new(...) 才创建具体报文。
      pkt = new(3, 1);  run_packet(pkt); // 3B 小于头长，必须报长度错并能结束，不能卡死。
      pkt = new(33, 1); run_packet(pkt); // 33B 超过 32B 容量，不能生成越界 SRAM 读。
    endtask

  endclass

  class timing_test extends base_test; // 继承公共操作，run 不在两帧之间复位，检查完成后能否再次启动。

    function new(input virtual proc_if vif, input int seed);
      super.new(vif, "timing", seed); // super.new 调用基类的构造函数，把接口、当前测试名和 seed 保存到公共成员，供后续驱动和日志使用。
    endfunction

    task run();
      packet pkt; // 先声明保存报文对象引用的变量 pkt，随后 pkt=new(...) 才创建具体报文。
      pkt = new(8, 1);  run_packet(pkt); // 第一帧完成后 run_packet 已检查 DONE 保持。
      pkt = new(12, 8); run_packet(pkt); // 再次 start；公共检查要求旧 done/结果清除，新帧能重新完成。
    endtask

  endclass

  class type_test extends base_test; // 继承公共操作，run 分别测试非法类型和被类型许可位禁止的报文。

    function new(input virtual proc_if vif, input int seed);
      super.new(vif, "type", seed); // super.new 调用基类的构造函数，把接口、当前测试名和 seed 保存到公共成员，供后续驱动和日志使用。
    endfunction

    task run();
      packet pkt; // 先声明保存报文对象引用的变量 pkt，随后 pkt=new(...) 才创建具体报文。
      pkt = new(8, 3); run_packet(pkt); // type03 有两个 bit 为 1，不属于四个合法类型。
      pkt = new(8, 1); run_packet(pkt, 1, 4'b1110); // type01 本身合法，但 mask[0]=0 应报类型错。
      pkt = new(8, 8); run_packet(pkt, 1, 4'b1000); // type08 且仅 mask[3]=1，证明映射关系正确且合法访问可通过。
    endtask

  endclass

  class checksum_test extends base_test; // 继承公共操作，run 用同一份坏头校验报文，比较校验开启和关闭的结果。

    function new(input virtual proc_if vif, input int seed);
      super.new(vif, "checksum", seed); // super.new 调用基类的构造函数，把接口、当前测试名和 seed 保存到公共成员，供后续驱动和日志使用。
    endfunction

    task run();
      packet pkt; // 先声明保存报文对象引用的变量 pkt，随后 pkt=new(...) 才创建具体报文。
      pkt = new(8, 2); // 先生成长度 8/type02 的合法头及相同 payload。
      pkt.hdr_chk ^= 8'h01; // 把校验值与 01 异或，即翻转最低位，人为制造一个错误头校验值。
      run_packet(pkt, 1); // mode=1：应报告 chk_error，同时 payload 摘要仍正确。
      run_packet(pkt, 0); // mode=0：同一份坏校验被旁路，摘要不应因此改变。
    endtask

  endclass

  class extension_test extends base_test; // 继承公共操作，run 增加不满四字节的结尾、累加溢出和多种错误并存等场景。

    function new(input virtual proc_if vif, input int seed);
      super.new(vif, "extension", seed); // super.new 调用基类的构造函数，把接口、当前测试名和 seed 保存到公共成员，供后续驱动和日志使用。
    endfunction

    task run();
      packet pkt; // 先声明保存报文对象引用的变量 pkt，随后 pkt=new(...) 才创建具体报文。
      pkt = new(7, 4); // 7B 报文有 3 个 payload byte，测试最后 word 不满四字节。
      pkt.payload = '{8'hFE, 8'h05, 8'h03}; // FE+05+03=106→8位06，XOR=F8；未用 lane 的 A5 不应被累计。
      run_packet(pkt); // 公共参考与被测电路比较，检验尾过滤和 8 位溢出。
      pkt = new(13, 8); // 13B 报文有 9 个 payload byte，覆盖跨 word 和只用末字第一个 byte。
      foreach (pkt.payload[i]) pkt.payload[i] = 8'hAA; // 把报文中的每个负载字节都改为 AA；9 个 AA 的低 8 位和为 FA，异或为 AA。
      run_packet(pkt); // 运行第二个扩展报文。
      pkt = new(12, 2); // 实际 12B 仍在合法容量范围，payload 应完整处理。
      run_packet(pkt, 1, 4'hF, 8); // 配置期望 8B、实际 12B：报 length_error，但不能误按 8B 提前结束摘要。
      pkt = new(3, 3); // 3B/type03 同时违反长度与类型规则。
      pkt.hdr_chk ^= 8'h01; // 把校验值与 01 异或，即翻转最低位，人为制造一个错误头校验值。
      run_packet(pkt); // 检查三错并存时仍能完成，不能因第一种错误跳过后续检查。
    endtask

  endclass

endpackage
