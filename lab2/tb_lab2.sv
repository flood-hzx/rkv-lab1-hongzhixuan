`timescale 1ns/1ps

 // 顶层先创建实际接口和 M3 并连接端口，再根据运行参数创建测试对象；对象通过接口改变输入，监视过程独立检查输出。
module tb_lab2;
  import lab2_pkg::*; // import 将 lab2_pkg 中的类型和类名引入当前模块，后面才能直接用 packet、base_test 等名字。
  logic clk = 0; // 测试程序的时钟变量，下面每 5ns 翻转一次。
  proc_if bus(clk); // 按 proc_if 定义创建实际接口 bus，并传入时钟；测试对象和 M3 都访问它里面的同一组信号。
  base_test test; // 先声明能引用具体测试对象的变量 test，下面 new 后才有对象，再通过 test.run() 执行所选测试。
  string test_name; // 保存外部 TESTNAME，用来选择实际创建哪一个测试类。
  int test_seed = 1; // 记录运行 seed；本 Lab 报文为定向内容，seed 不自动改变它们。
  int starts = 0, completions = 0, read_requests = 0; // 独立端口监视统计：实际接受启动数、完成数、内存读请求数。
  bit test_done = 0; // 只有用例和全部检查均成功才置 1，供脚本判断运行确实完成。
 // ==================== 一、DUT：被测电路及端口连接 ====================
 // 实际被测模块是 M3；它通过 bus 连接 proc_if 中的同步存储模型，模型用于提供测试环境。
  packet_proc_core m3 ( // 唯一的被测电路；M3 不读取测试类，全部交互都经过下列端口连线。
    .clk(clk), .rst_n(bus.rst_n), .start_i(bus.start), // 测试程序/interface 提供时钟复位与 start；M3 在上升沿接受启动。
    .algo_mode_i(bus.algo_mode), .type_mask_i(bus.type_mask), .exp_pkt_len_i(bus.exp_pkt_len), // interface 中的三种配置送入 M3，由 M3 启动时保存。
    .mem_rd_en_o(bus.mem_rd_en), .mem_rd_addr_o(bus.mem_rd_addr), .mem_rd_data_i(bus.mem_rd_data), // M3 请求→接口内存模型，模型返回→M3；方向与配置/结果路径不同。
    .busy_o(bus.busy), .done_o(bus.done), // M3 的处理阶段状态送接口，测试类和监视过程从这里观察。
    .res_pkt_len_o(bus.res_pkt_len), .res_pkt_type_o(bus.res_pkt_type), // M3 解析出的长度/类型送测试程序，不由测试程序驱动。
    .res_payload_sum_o(bus.res_payload_sum), .res_payload_xor_o(bus.res_payload_xor), // M3 计算的两种摘要送测试程序，稍后与 packet.predict 结果比较。
    .format_ok_o(bus.format_ok), .length_error_o(bus.length_error), // M3 格式及部分错误输出，进入接口供统一采样。
    .type_error_o(bus.type_error), .chk_error_o(bus.chk_error) // 同样把类型/校验错误接到接口，不是测试程序在这里设置错误。
  );

 // ==================== 二、simulator：仿真激励与测试流程 ====================
 // 产生时钟并选择、运行测试对象；报文构造和结果比较在 lab2_pkg，复位与启动操作在 proc_if。
  always #5 clk = ~clk; // 产生完整周期 10ns 的时钟；这是仿真激励，不能作为被测电路中的可综合时钟发生器。

  initial begin // 一次性测试控制线程，与时钟发生和监视过程同时运行。
    normal_test normal; // 声明各派生类句柄；只是引用变量，new 之前没有实际测试对象。
    length_test length; // 长度测试句柄。
    timing_test timing; // 时序测试句柄。
    type_test type_case; // 类型测试句柄，名字避开 type 等语言语法。
    checksum_test checksum; // 校验测试句柄。
    extension_test extension; // 扩展测试句柄。
    $timeformat(-9, 0, " ns", 12); // 控制日志时间按 ns 显示；不改变实际时钟或被测电路时序。
    if (!$value$plusargs("TESTNAME=%s", test_name)) test_name = "normal"; // 读取运行参数 +TESTNAME=...；没读到就把用例名设为 normal，%s 表示读取字符串。
    if (!$value$plusargs("SEED=%d", test_seed)) test_seed = 1; // 读取运行参数 +SEED=...；没读到就用 1，%d 表示读取十进制整数。
    case (test_name) // 同一套环境创建选中的具体测试，不能只换日志名字而运行同一个用例。
      "normal": begin normal = new(bus, test_seed); test = normal; end // 创建 normal_test 对象，把实际接口 bus 和 seed 交给它，再让公共变量 test 指向同一个对象。
      "length": begin length = new(bus, test_seed); test = length; end // 创建长度测试对象并交给 test，后面的 test.run() 就会执行长度用例。
      "timing": begin timing = new(bus, test_seed); test = timing; end // 创建时序测试对象并交给 test，后面的 test.run() 就会连续测试两帧。
      "type": begin type_case = new(bus, test_seed); test = type_case; end // 创建类型测试对象并交给 test，后面的 test.run() 就会执行类型用例。
      "checksum": begin checksum = new(bus, test_seed); test = checksum; end // 创建校验测试对象并交给 test，后面的 test.run() 就会比较开启和关闭校验。
      "extension": begin extension = new(bus, test_seed); test = extension; end // 创建扩展测试对象并交给 test，后面的 test.run() 就会执行尾部、溢出等场景。
      default: $fatal(1, "[UNKNOWN_TEST] TESTNAME=%s", test_name); // 名称未知必须失败，不偷偷回退 normal 掩盖选例配置错误。
    endcase
    $display("[RUN] test=%s class=%s_test seed=%0d clock_ns=10 memory_words=8 sync_read=1 payload_pattern=directed", // 打印实际对象身份和运行参数，日志应与外部选择一致。
             test.name, test.name, test_seed);
    test.initialize(); // 公共基类负责复位并检查确定的初始状态。
    test.run(); // 执行 test 当前引用对象中的 run；所选类不同，运行的用例也不同。
    test.check_value("monitor starts", starts, test.frames); // 用独立监视过程的启动计数核对类提交帧数，避免只在模型里记账。
    test.check_value("monitor completions", completions, test.frames); // 每帧都必须观察到真实处理完成，不能漏帧或重复完成。
    test.finish_checks(); // 核对期望队列清空、非空测试、统计一致后才打印类级 PASS。
    test_done = 1; // 明确标记整个测试成功结束；脚本据此区分通过与异常提前停止。
    $finish; // 结束仿真，同时终止其他监视过程/超时线程。
  end

 // ==================== 三、monitor：独立观察与检查 ====================
 // 下面的监视过程随时钟观察实际端口并检查行为，后面的超时保护防止测试无限等待；本区不负责产生正常请求。
  always @(posedge clk) begin : monitor // 在每个采样沿观察真实端口；本过程不发 start，也不改测试 packet。
    bit active, accepted_start, was_busy, was_done; // 保存本沿更新前的控制条件，#1 后仍可用这些快照判断发生了什么。
    result_t previous_result, current_result; // 结果快照用于验证 DONE 期间没有被无故覆盖。
    active = bus.rst_n; // 记下沿前复位是否已撤销；后面延时检查仍按这份记录决定本沿是否需要检查。
    accepted_start = bus.start && !bus.busy; // 沿前 start=1 且 busy=0 时，本沿应该接受启动；把这个条件先记下来供沿后检查。
    was_busy = bus.busy; // 沿前 busy，用于沿后发现 PROCESS→DONE 的变化。
    was_done = bus.done; // 沿前 done，用于判断无新启动时结果是否必须保持。
    previous_result = {bus.res_pkt_len, bus.res_pkt_type, bus.res_payload_sum, bus.res_payload_xor, // 把沿前结果字段按 result_t 定义顺序拼成快照，低位还接下一行四个标志。
                       bus.length_error, bus.type_error, bus.chk_error, bus.format_ok};
    if (active && bus.mem_rd_en) begin // 没有复位且 M3 读使能为 1，表示本沿发出真实读请求，记录其地址并累计次数。
      if ($isunknown(bus.mem_rd_addr)) $fatal(1, "[MON_FAIL] unknown SRAM address"); // 地址中只要有任意一位 X/Z，就报错并停止，不能使用一个不确定的存储位置。
      read_requests++; // 统计请求次数；末字排空时可能有重复请求，不等同于有效消费 word 数。
      $display("[MEM_READ] time=%0t address=%0d", $time, bus.mem_rd_addr); // 日志记录本次请求时间和 word 索引，便于与波形对齐。
    end
    #1ns; // 等 1ns，让 M3 本上升沿的 <= 更新完成，再检查沿后的新状态和结果。
    if (active) begin // 使用沿前复位快照，避免把复位期间的状态误记为正常完成。
      if ($isunknown({bus.busy, bus.done, bus.mem_rd_en}) || (bus.busy && bus.done)) // 先用 { } 拼起忙、完成、读使能；其中有 X/Z，或者 busy 和 done 同时为 1，都报错。
        $fatal(1, "[MON_FAIL] invalid busy/done/read_enable"); // 控制关系失效立即报错，补充最终数据比较无法发现的时序问题。
      if (bus.mem_rd_en !== bus.busy) $fatal(1, "[MON_FAIL] PROCESS read enable"); // 读使能与 busy 不完全一致时就报错；!== 将 X、Z 也算入比较。
      if (accepted_start) begin // 沿前满足启动接收条件，沿后必须已经开始处理。
        starts++; // 记实际接受的启动，而不是仅记录测试程序设置了多少次 start。
        if (bus.busy !== 1'b1 || bus.done !== 1'b0) // 已接受启动后，busy 不是确定的 1，或者 done 不是确定的 0，任一成立都报错。
          $fatal(1, "[MON_FAIL] start must set busy and clear done on first edge"); // 若仍停留 DONE/IDLE，启动时序检查失败。
      end
      if (was_busy && !bus.busy) begin // 沿前忙=1、沿后忙=0，表示处理刚结束，此时还要检查完成信号是否为 1。
        completions++; // 记录一次真实完成，最后与测试帧数对账。
        if (bus.done !== 1'b1) $fatal(1, "[MON_FAIL] PROCESS must finish in DONE"); // 不能仅把 busy 拉低就算结束，还必须进入 done 有效状态。
        $display("[DONE] time=%0t completion=%0d", $time, completions); // 打印完成的实际发生时刻。
      end
      if (was_done && !accepted_start) begin // 上一拍已经完成且本沿没有接收新启动，完成信号和结果都应继续保持。
        current_result = {bus.res_pkt_len, bus.res_pkt_type, bus.res_payload_sum, bus.res_payload_xor, // 重新采集赋值更新后的结果，与上升沿前快照比较。
                          bus.length_error, bus.type_error, bus.chk_error, bus.format_ok};
        if (bus.done !== 1'b1 || current_result !== previous_result) // 完成信号不是 1，或者现在的整份结果与沿前记录不同，都说明保持失败。
          $fatal(1, "[MON_FAIL] DONE/result must hold until next start"); // 明确报告 DONE 保持契约被破坏。
      end
    end
  end

  initial begin // 独立超时线程，与激励和监视过程并行；正常 $finish 会提前结束它。
    #100us; // 仿真时间到 100us 还没完成才继续下一行，不是给被测电路加延时。
    $fatal(1, "[TIMEOUT] Lab2 did not finish within 100 us"); // 超时必须失败，不能无限等待一个从未到来的 done。
  end
endmodule
