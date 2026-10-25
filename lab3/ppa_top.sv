`timescale 1ns/1ps

// §2.3、§11.4：顶层只连接三个已有模块，不保存第二份配置、报文或结果。
module ppa_top (
  input  logic        PCLK,
  input  logic        PRESETn,
  input  logic        PSEL,
  input  logic        PENABLE,
  input  logic        PWRITE,
  input  logic [11:0] PADDR,
  input  logic [31:0] PWDATA,
  output logic [31:0] PRDATA,
  output logic        PREADY,
  output logic        PSLVERR,
  output logic        irq_o
);
  logic mem_we, mem_re, proc_rd_en;
  logic [2:0] mem_addr, proc_addr;
  logic [31:0] mem_wdata, apb_data, proc_data;
  logic enable, start, mode, busy, done, format_ok;
  logic length_error, type_error, chk_error, done_irq_en, err_irq_en;
  logic [3:0] type_mask;
  logic [5:0] exp_len, res_len;
  logic [7:0] res_type, res_sum, res_xor;

  apb_slave_if m1 (
    .PCLK(PCLK), .PRESETn(PRESETn), .PSEL(PSEL), .PENABLE(PENABLE),
    .PWRITE(PWRITE), .PADDR(PADDR), .PWDATA(PWDATA), .PRDATA(PRDATA),
    .PREADY(PREADY), .PSLVERR(PSLVERR), .pkt_mem_rdata_i(apb_data),
    .pkt_mem_we_o(mem_we), .pkt_mem_addr_o(mem_addr),
    .pkt_mem_wdata_o(mem_wdata), .pkt_mem_re_o(mem_re),
    .busy_i(busy), .done_i(done), .format_ok_i(format_ok),
    .length_error_i(length_error), .type_error_i(type_error),
    .chk_error_i(chk_error), .res_pkt_len_i(res_len),
    .res_pkt_type_i(res_type), .res_payload_sum_i(res_sum),
    .res_payload_xor_i(res_xor), .enable_o(enable), .start_o(start),
    .algo_mode_o(mode), .type_mask_o(type_mask), .exp_pkt_len_o(exp_len),
    .done_irq_en_o(done_irq_en), .err_irq_en_o(err_irq_en), .irq_o(irq_o)
  );

  packet_sram m2 (
    .clk(PCLK), .rst_n(PRESETn), .apb_wr_en(mem_we), .apb_addr(mem_addr),
    .apb_wr_data(mem_wdata), .proc_rd_en(proc_rd_en), .proc_rd_addr(proc_addr),
    .apb_rd_en(mem_re), .proc_rd_data(proc_data), .apb_rd_data(apb_data)
  );

  packet_proc_core m3 (
    .clk(PCLK), .rst_n(PRESETn), .start_i(start), .algo_mode_i(mode),
    .type_mask_i(type_mask), .exp_pkt_len_i(exp_len), .mem_rd_en_o(proc_rd_en),
    .mem_rd_addr_o(proc_addr), .mem_rd_data_i(proc_data), .busy_o(busy),
    .done_o(done), .res_pkt_len_o(res_len), .res_pkt_type_o(res_type),
    .res_payload_sum_o(res_sum), .res_payload_xor_o(res_xor),
    .format_ok_o(format_ok), .length_error_o(length_error),
    .type_error_o(type_error), .chk_error_o(chk_error)
  );
endmodule
