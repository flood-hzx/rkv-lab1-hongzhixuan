`timescale 1ns/1ps

interface ppa_if(input logic PCLK);
  logic PRESETn = 0;
  logic PSEL = 0, PENABLE = 0, PWRITE = 0;
  logic [11:0] PADDR = 0;
  logic [31:0] PWDATA = 0;
  logic [31:0] PRDATA;
  logic PREADY, PSLVERR, irq;
  // 这些只读观察信号由 TB 连接真实 DUT，driver 不给 busy/done 或结果赋值。
  wire start, busy, done, format_ok, length_error, type_error, chk_error;
  wire [5:0] res_len;
  wire [7:0] res_type, res_sum, res_xor;

  task automatic reset_dut();
    @(negedge PCLK);
    PRESETn = 0;
    PSEL = 0;
    PENABLE = 0;
    PWRITE = 0;
    PADDR = 0;
    PWDATA = 0;
    repeat (3) @(negedge PCLK);
    PRESETn = 1;
  endtask

  // 与 Lab1 相同：下降沿驱动两阶段，上升沿 NBA 前接收 APB 返回值。
  task automatic transfer(input bit write_it, input logic [11:0] address,
                          input logic [31:0] write_value,
                          output logic [31:0] read_value, output logic error);
    @(negedge PCLK);
    PSEL = 1;
    PENABLE = 0;
    PWRITE = write_it;
    PADDR = address;
    PWDATA = write_value;
    @(negedge PCLK);
    PENABLE = 1;
    @(posedge PCLK);
    if (PREADY !== 1'b1) $fatal(1, "[APB_FAIL] PREADY is not one");
    read_value = PRDATA;
    error = PSLVERR;
    @(negedge PCLK);
    PSEL = 0;
    PENABLE = 0;
    PWRITE = 0;
    PADDR = 0;
    PWDATA = 0;
  endtask
endinterface
