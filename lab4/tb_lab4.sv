`timescale 1ns/1ps

module tb_lab4;
  import lab3_pkg::*;
  import lab4_pkg::*;

  logic PCLK = 0;
  ppa_if bus(PCLK);
  environment env;
  coverage_collector cov;
  base_test test;
  string test_name;
  int test_seed = 1;
  bit test_done = 0;

  always #5 PCLK = ~PCLK;

  ppa_top dut (
    .PCLK(PCLK), .PRESETn(bus.PRESETn),
    .PSEL(bus.PSEL), .PENABLE(bus.PENABLE), .PWRITE(bus.PWRITE),
    .PADDR(bus.PADDR), .PWDATA(bus.PWDATA), .PRDATA(bus.PRDATA),
    .PREADY(bus.PREADY), .PSLVERR(bus.PSLVERR), .irq_o(bus.irq)
  );

  // DUT 内部状态/结果通过只读观察连接给 interface；它们不是 APB driver 的输出。
  assign bus.start = dut.start;
  assign bus.busy = dut.busy;
  assign bus.done = dut.done;
  assign bus.format_ok = dut.format_ok;
  assign bus.length_error = dut.length_error;
  assign bus.type_error = dut.type_error;
  assign bus.chk_error = dut.chk_error;
  assign bus.res_len = dut.res_len;
  assign bus.res_type = dut.res_type;
  assign bus.res_sum = dut.res_sum;
  assign bus.res_xor = dut.res_xor;

  initial begin
    $timeformat(-9, 0, " ns", 12);
    if (!$value$plusargs("TESTNAME=%s", test_name)) test_name = "smoke";
    if (!$value$plusargs("SEED=%d", test_seed)) test_seed = 1;

    env = new(bus, test_name, test_seed);
    cov = new();
    env.coverage = cov;

    if (test_name == "coverage") begin
      coverage_test selected_coverage_test;
      selected_coverage_test = new(env);
      test = selected_coverage_test;
    end else if (test_name == "closure") begin
      closure_test selected_closure_test;
      selected_closure_test = new(env);
      test = selected_closure_test;
    end else begin
      test = create_test(test_name, env);
      if (test == null) $fatal(1, "[UNKNOWN_TEST] TESTNAME=%s", test_name);
    end

    $display("[RUN] test=%s seed=%0d", test_name, test_seed);
    env.run(test);
    test_done = 1;
    $display("[TEST_DONE] test=%s seed=%0d", test_name, test_seed);
    $finish;
  end

  initial begin
    #1ms;
    if (!test_done) $fatal(1, "[TIMEOUT] Lab4 did not finish within 1 ms");
  end
endmodule
