`timescale 1ns/1ps

module tb_lab3;
  import lab3_pkg::*;
  logic PCLK = 0;
  logic test_done = 0;
  ppa_if bus(PCLK);
  environment env;
  base_test test;
  string testname;
  int seed;

  // DUT：左侧是 ppa_top 的端口，右侧是 bus 接口实例内的信号。
  ppa_top dut (
    .PCLK(PCLK), .PRESETn(bus.PRESETn), .PSEL(bus.PSEL),
    .PENABLE(bus.PENABLE), .PWRITE(bus.PWRITE), .PADDR(bus.PADDR),
    .PWDATA(bus.PWDATA), .PRDATA(bus.PRDATA), .PREADY(bus.PREADY),
    .PSLVERR(bus.PSLVERR), .irq_o(bus.irq)
  );
  assign bus.start = dut.start;
  assign bus.busy = dut.busy;
  assign bus.done = dut.done;
  assign bus.res_len = dut.res_len;
  assign bus.res_type = dut.res_type;
  assign bus.res_sum = dut.res_sum;
  assign bus.res_xor = dut.res_xor;
  assign bus.format_ok = dut.format_ok;
  assign bus.length_error = dut.length_error;
  assign bus.type_error = dut.type_error;
  assign bus.chk_error = dut.chk_error;

  // 激励与时钟：env 中的 generator/driver 只驱动 APB，M2 和 M3 都是真实 RTL。
  always #5ns PCLK = ~PCLK;
  initial begin
    if (!$value$plusargs("TESTNAME=%s", testname)) testname = "smoke";
    if (!$value$plusargs("SEED=%d", seed)) seed = 1;
    env = new(bus, testname, seed);
    test = create_test(testname, env);
    env.run(test);
    test_done = 1;
    $finish;
  end

  // 监视/检查器在 lab3_pkg 中，通过 virtual interface 观察，mailbox 传递给 scoreboard。
  initial begin
    #1ms;
    $fatal(1, "[GLOBAL_TIMEOUT] test=%s seed=%0d", testname, seed);
  end
endmodule
