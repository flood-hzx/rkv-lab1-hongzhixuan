`timescale 1ns/1ps

 // M2 需要在主机写完后保留报文，并分别响应主机和处理核的读取，因此使用一个八字存储数组和两个独立读输出。
 // 各读写使能和地址在上升沿被接收；<= 先计算沿前数据、稍后更新目标，所以同沿读写同一地址时读到旧值。
module packet_sram (
  input  logic        clk, // 来自系统/测试程序；与 M1 使用同一时钟域。
  input  logic        rst_n, // 低有效复位；本实现异步清读输出，不清整个数组。
  input  logic        apb_wr_en, // 来自 M1.pkt_mem_we_o；1 允许在上升沿保存一字。
  input  logic [2:0]  apb_addr, // 来自 M1.pkt_mem_addr_o；APB 读写共享索引 0~7。
  input  logic [31:0] apb_wr_data, // 来自 M1.pkt_mem_wdata_o；要保存的 32 位数据。
  input  logic        proc_rd_en, // 来自未来 M3；Lab1 由测试程序模拟，1 发起同步读。
  input  logic [2:0]  proc_rd_addr, // 来自未来 M3/测试程序；这个读地址独立于 APB 地址。
  input  logic        apb_rd_en, // 来自 M1.pkt_mem_re_o；APB SETUP 就提前给出。
  output logic [31:0] proc_rd_data, // 送未来 M3/测试程序；接收上升沿后更新，使能为 0 时保持。
  output logic [31:0] apb_rd_data // 送 M1.pkt_mem_rdata_i；供 APB 读回。
);
  logic [31:0] mem [0:7]; // 声明 8 个位置，每个位置存 32 位；mem[3] 就是第 3 号位置，编号范围为 0～7。

  always_ff @(posedge clk or negedge rst_n) begin // 上升沿读写，复位降到 0 时立即复位；<= 的右边先取旧值，左边在本沿稍后更新。
    if (!rst_n) begin // rst_n=0 时复位，只清下面两个读输出，不清整个 mem 数组。
      proc_rd_data <= 0; // 复位使处理核读输出确定为 0，不代表 mem 数组已被清零。
      apb_rd_data <= 0; // 复位使 APB 读输出确定为 0；未写的数组位置仍不可假定为 0。
    end else begin
      if (apb_wr_en) mem[apb_addr] <= apb_wr_data; // 写使能为 1 时，把 apb_wr_data 保存到 apb_addr 指定的位置，其他位置保持。
      if (proc_rd_en) proc_rd_data <= mem[proc_rd_addr]; // 处理核读使能为 1 时，把指定位置的沿前数据送到处理核读输出；同沿写同一位置时读到旧数据。
      if (apb_rd_en) apb_rd_data <= mem[apb_addr]; // 主机读使能为 1 时，把指定位置的沿前数据送回 M1；它与处理核读口可在同一沿分别读取。
    end
  end
endmodule
