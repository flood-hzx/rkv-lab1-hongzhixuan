`timescale 1ns/1ps

 // 测试类需要同时操作启动、配置并观察结果，所以这里集中定义信号和操作任务；接口实例由 tb_lab2 创建，再连接到 M3。
 // 本接口还包含同步存储模型：测试任务装入报文，模型按 M3 请求返回数据，供单独验证处理核。
interface proc_if(input logic clk); // 把相关仿真信号和操作放在一起；clk 由 tb_lab2 产生。
  logic rst_n = 0; // 测试程序驱动到 M3.rst_n，初始处于低有效复位。
  logic start = 0, algo_mode = 1; // 测试程序驱动到 M3.start_i/algo_mode_i；start 是命令，mode 是配置。
  logic [3:0] type_mask = 4'hF; // 测试程序配置四种类型的许可，送 M3.type_mask_i。
  logic [5:0] exp_pkt_len = 0; // 测试程序提供期望总长度，送 M3.exp_pkt_len_i；0 表示未配置。
  logic mem_rd_en; // 由 M3.mem_rd_en_o 驱动，内存模型只观察这个请求。
  logic [2:0] mem_rd_addr; // 由 M3.mem_rd_addr_o 驱动，选择模型的八个 word 之一。
  logic [31:0] mem_rd_data; // 由下面同步内存模型驱动，送回 M3.mem_rd_data_i。
  logic busy, done, format_ok, length_error, type_error, chk_error; // 均由 M3 输出，测试程序的类与监视过程只读取、比较这些状态。
  logic [5:0] res_pkt_len; // 由 M3 输出长度结果，测试程序在完成后采集。
  logic [7:0] res_pkt_type, res_payload_sum, res_payload_xor; // 由 M3 输出类型和两种摘要，供参考模型比较。
  logic [31:0] memory [0:7]; // 仿真中的八字数组模型；由 load_word 直接装载，替代 Lab1 的 M2。

  always_ff @(posedge clk or negedge rst_n) begin // 与 M3 同时被上升沿触发，但 <= 沿后才更新，M3 本沿读到的仍是旧返回。
    if (!rst_n) mem_rd_data <= 0; // !rst_n 表示复位为 0；此时只清读输出，不清数组内存。
    else if (mem_rd_en) mem_rd_data <= memory[mem_rd_addr]; // 未复位且读使能为 1，就在上升沿取指定位置的数据，本沿稍后更新输出；没有请求则保持。
  end

  task automatic reset_dut(); // 供测试类复用的有时间操作；task 可等待边沿，function 不可做这种等待。
    @(negedge clk); // 避开 M3 的上升沿采样点，在下降沿改变驱动值。
    rst_n = 0; // 向 M3 和内存模型发复位。
    start = 0; // 复位时不保留启动命令。
    algo_mode = 1; // 恢复测试默认的校验开启配置。
    type_mask = 4'hF; // 恢复默认全类型许可。
    exp_pkt_len = 0; // 恢复默认不做期望长度比较。
    repeat (3) @(negedge clk); // 重复三次“等下降沿”，让复位保持足够的时钟周期。
    rst_n = 1; // 下降沿撤销复位，下一上升沿开始正常采样。
  endtask

  task automatic load_word(input int index, input logic [31:0] data); // run_packet 遍历打包数组时传入下标 i 和 words[i]；本任务用 input index/data 接收这两个值，随后装入模型。
    if (index < 0 || index > 7 || busy !== 1'b0) // || 表示或者；编号小于 0、大于 7，或者 busy 不是确定的 0，任一成立就拒绝装载。
      $fatal(1, "[MODEL_FAIL] index=%0d busy=%b", index, busy); // 模型误用直接 FAIL，避免越界或边处理边装载掩盖设计问题。
    @(negedge clk); // 在下降沿更新模型内容，让后续上升沿读请求看到稳定数据。
    memory[index] = data; // 将调用方传来的 data 保存到第 index 号位置，供 M3 以后读取。
  endtask

  task automatic assert_start(input bit mode, input bit [3:0] mask, input bit [5:0] expected_length); // run_packet 将 mode/mask/expected_length 配置值传入；此任务先接收参数，再赋给接口信号，让 M3 在下一上升沿采样。
    @(negedge clk); // 下降沿准备控制信号，留半周期给 M3 建立输入。
    algo_mode = mode; // 把任务收到的 mode 值写到接口信号，信号再通过端口接到 M3.algo_mode_i。
    type_mask = mask; // 把任务收到的四位 mask 写到接口信号，再送到 M3.type_mask_i。
    exp_pkt_len = expected_length; // 把任务收到的期望长度写到接口信号，再送到 M3.exp_pkt_len_i。
    start = 1; // 上游/测试程序请求开始处理；M3 在下一个上升沿接受。
    @(posedge clk); // 等到 M3 真正接收 start 的时钟沿，而不是拉高 start 就立即检查。
    #1ns; // 等 1ns，让本上升沿的 <= 更新完成后再返回，调用方就能看到新的 busy、done 和结果。
  endtask

  task automatic release_start(); // 与 assert_start 配对，撤销上游的启动请求。
    @(negedge clk); // 保证 start 先保持跨过一个上升沿，再在下降沿撤销。
    start = 0; // 不再请求启动；已经开始的 M3 会依照内部状态机继续处理。
  endtask

endinterface
