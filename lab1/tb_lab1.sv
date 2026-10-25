`timescale 1ns/1ps
typedef logic [11:0] apb_address_t; // 后面的请求需要保存地址；typedef 给 12 位 logic 数据起名 apb_address_t，此处定义格式，还没有创建地址变量。
typedef logic [31:0] apb_data_t; // 同样给 32 位、可含未知值 X 的数据格式起名 apb_data_t，后面用它声明读写数据变量。
typedef enum logic {APB_READ = 0, APB_WRITE = 1} apb_direction_t; // 为请求方向定义 1 位类型：APB_READ 代表 0、APB_WRITE 代表 1；后面赋给 PWRITE 才实际选择读或写。
typedef struct packed { // 把方向、地址、数据规定为一份可整体传递的记录格式；packed 使三字段连成 45 位，结尾将它命名为 apb_transaction_t。
  apb_direction_t direction; // 这份记录中的方向字段；填写为 APB_WRITE 后，transfer 会取其值 1 送给 PWRITE。
  apb_address_t address; // 这份记录中保存目标字节地址的 12 位字段，transfer 会将它送给 PADDR。
  apb_data_t data; // 这份记录中的 32 位数据字段，写时提供实际内容，读时填 0 占位，transfer 将它送给 PWDATA。
} apb_transaction_t;

// 前面只规定请求的数据格式；这里用 interface 定义一组实际总线信号和操作任务，供后面的测试程序统一访问。
// 本文件选择先写类型再写接口；apb_if apb(...) 才创建接口实例，下面 M1 例化中的端口连接才接通电路。
interface apb_if(input logic PCLK, input logic PRESETn); // apb_if 是接口定义的名字；PCLK 和 PRESETn 是接口输入，由后面 tb_lab1 中的时钟、复位传入。
  logic PSEL = 0, PENABLE = 0, PWRITE = 0; // 主机侧请求由本 interface 的 transfer task 驱动，初始不选中从机。
  apb_address_t PADDR = 0; // 测试程序 提供目标地址，SETUP 到 ACCESS 保持。
  apb_data_t PWDATA = 0; // 测试程序 提供写数据，合法写沿由 M1/M2 接收。
  apb_data_t PRDATA; // M1 输出连入 interface；测试程序 读它，不能在 总线驱动任务 中反向赋值。
  logic PREADY, PSLVERR; // M1 给主机的响应，transfer 在 ACCESS 上升沿采样。

  // 调用来源：apb_write/apb_read 各自声明并填好局部 request，再将它作为 apb.transfer(...) 的第一个实参传入。
  // 此处 input request 接收那份记录的副本；automatic 使每次调用各有一份参数，两个 output 则在任务结束时交回调用处。
  task automatic transfer(input apb_transaction_t request,//apb=logic [11:0] address, logic [31:0] data, apb_direction_t direction,
                          output apb_data_t read_data,
                          output logic error_response);
    @(negedge PCLK); // 下一下降沿开始新访问，避免与 被测电路 的上升沿采样竞争。
    PSEL = 1; // 主机选中 M1。
    PENABLE = 0; // 先进入 SETUP，此时不能产生实际寄存器/内存写。
    PWRITE = request.direction; // 取本次传入记录的 direction 字段送到实际方向信号；APB_WRITE 的数值 1 在这里成为写请求。
    PADDR = request.address; // 取传入记录的 address 字段送到地址信号，M1 随后按这个数值选择寄存器或内存位置。
    PWDATA = request.data; // 取传入记录的 data 字段送到写数据线；是否真正写入还取决于 PWRITE、访问阶段和从机许可。
    @(negedge PCLK); // 保持 SETUP 跨过一个上升沿，M2 可在期间同步预读。
    PENABLE = 1; // 进入 ACCESS；其余请求字段不改变，表示同一笔传输。
    @(posedge PCLK); // 到达本笔 ACCESS 完成沿；采样沿前已建立的 PRDATA/PSLVERR。
    if (PREADY !== 1'b1) $fatal(1, "PREADY must be 1, address=%03x", PADDR); // 本实验不支持等待拍；若 PREADY 不是确定的 1，驱动明确失败。
    read_data = PRDATA; // 把 M1 当前返回数据保存到输出参数；transfer 结束时，其值才复制回调用处的第二个实参。
    error_response = PSLVERR; // 保存 M1 本次错误响应；任务结束时交给调用处的第三个实参，供后续比较。
    @(negedge PCLK); // 完成沿后等到下降沿才撤销请求，保证采样时信号稳定。
    PSEL = 0; // 取消选择，回到空闲。
    PENABLE = 0; // 结束 ACCESS，为下一笔请求准备新的 SETUP。
  endtask

endinterface

module tb_lab1;//准备好测试程序的顶层模块；它包含实际接口和 M1/M2，并在 initial 中调用测试对象。
  logic PCLK = 0, PRESETn = 0; // 测试程序 驱动的时钟/低有效复位，供两个设计模块共享。
  apb_if apb(PCLK, PRESETn); // 实际 APB interface 实例；内部请求/响应线通过下面 M1 例化连接。
  typedef enum logic [11:0] { // 测试程序 侧命名地址；匹配的是字节偏移，不是存储数据或自动生成的寄存器。
    CTRL = 12'h000, CFG = 12'h004, STATUS = 12'h008,
    IRQ_EN = 12'h00C, IRQ_STA = 12'h010, PKT_LEN_EXP = 12'h014,
    RES_PKT_LEN = 12'h018, RES_PKT_TYPE = 12'h01C,
    RES_PAYLOAD_SUM = 12'h020, RES_PAYLOAD_XOR = 12'h024, ERR_FLAG = 12'h028
  } csr_address_t;//列举了所有寄存器的地址，便于后续用例调用；12 位字节地址与前面 apb_address_t 类型一致。
  logic pkt_mem_we, pkt_mem_re; // M1 驱动使能，M2 接收；测试程序 另用 监视过程 观察是否出现非法写。
  logic [2:0] pkt_mem_addr; // M1 驱动 word 编号，M2 用它索引八字数组。
  apb_data_t pkt_mem_wdata, pkt_mem_rdata; // wdata 从 M1 到 M2，rdata 从 M2 回 M1，方向相反。
  logic busy_i = 0, done_i = 0, format_ok_i = 0; // 测试程序 暂代 M3 驱动状态；测试 M1 直透，不能据此宣称 M3 算法正确。
  logic length_error_i = 0, type_error_i = 0, chk_error_i = 0; // 测试程序 驱动处理错误输入；它们与主机收到的 APB PSLVERR 是两类错误。
  logic [5:0] res_pkt_len_i = 0; // 测试程序 驱动长度结果，M1 应按字段表返回。
  logic [7:0] res_pkt_type_i = 0, res_payload_sum_i = 0, res_payload_xor_i = 0; // 测试程序 驱动类型和摘要结果，不由 M1 自己计算。
  logic enable_o, start_o, algo_mode_o, done_irq_en_o, err_irq_en_o, irq_o; // M1 输出的配置/启动/IRQ，测试程序 只观察；enable 用于 M1 决定 START 许可。
  logic [3:0] type_mask_o; // M1 保存的类型掩码，后续 M3 在启动时采样。
  logic [5:0] exp_pkt_len_o; // M1 保存的期望长度，后续 M3 使用。
  logic proc_rd_en = 0; // 测试程序 作为 M2 处理核侧的请求方，不是在此实现完整 M3。
  logic [2:0] proc_rd_addr = 0; // 测试程序 提供独立于 APB 的 M2 读地址。
  apb_data_t proc_rd_data; // M2 同步读结果返回 测试程序，供 processor_read 比较。
  string test_name, case_name; // 字符串用于选用例和定位错误，不参与可综合硬件状态。
  int test_seed = 1; // 记录本次 seed；patterns 的随机项可结合运行参数复现。
  int case_begin_checks = 0; // 保存当前用例开始时的检查数，结束时计算该用例增量。
  int checks = 0, memory_writes = 0; // 检查总数与真实内存写次数，分别由检查任务和 监视过程 维护。
  int setup_count = 0, access_count = 0; // 累计观察到的 SETUP/ACCESS，结束时检查配对。
  bit test_done = 0; // 成功路径完成才置 1；脚本不把任意仿真结束都视为 PASS。
  apb_data_t expected_words [0:7]; // 独立预期数组由激励产生，不从 M2 内部 mem 反向复制期望。
  // ==================== 一、DUT：被测电路及端口连接 ====================
  // M1 与 M2 是实际被测模块；前面声明的信号在这里接到模块端口。
  apb_slave_if m1 ( // M1 是待验证设计；点号左边是模块端口名，括号里是测试程序连接信号。
    .PCLK(PCLK), .PRESETn(PRESETn), // 测试程序同时把时钟和复位送给 M1。
    .PSEL(apb.PSEL), .PENABLE(apb.PENABLE), .PWRITE(apb.PWRITE), // interface/主机驱动这三个请求输入，M1 接收。
    .PADDR(apb.PADDR), .PWDATA(apb.PWDATA), // 主机的地址与写数据送到 M1。
    .PRDATA(apb.PRDATA), .PREADY(apb.PREADY), .PSLVERR(apb.PSLVERR), // M1 的返回数据、完成和错误响应送回 interface/主机。
    .pkt_mem_rdata_i(pkt_mem_rdata), // 把 M2 的 APB 读结果接回 M1，形成内存读回路径。
    .pkt_mem_we_o(pkt_mem_we), .pkt_mem_addr_o(pkt_mem_addr), // M1 的写许可和 word 索引接到测试程序同名连线，下面再接 M2。
    .pkt_mem_wdata_o(pkt_mem_wdata), .pkt_mem_re_o(pkt_mem_re), // M1 的写数据和预读请求送 M2。
    .busy_i(busy_i), .done_i(done_i), .format_ok_i(format_ok_i), // 这里括号内信号由 测试程序 模拟处理核输入 驱动，接 M1 的状态输入。
    .length_error_i(length_error_i), .type_error_i(type_error_i), .chk_error_i(chk_error_i), // 测试程序 模拟处理核输入 的三类错误分别进入 M1，不合并成单一错误信号。
    .res_pkt_len_i(res_pkt_len_i), .res_pkt_type_i(res_pkt_type_i), // 测试程序 模拟处理核输入 的长度/类型结果进入 M1 的只读通路。
    .res_payload_sum_i(res_payload_sum_i), .res_payload_xor_i(res_payload_xor_i), // 测试程序 模拟处理核输入 的两个摘要进入 M1，测试 APB 是否返回原值。
    .enable_o(enable_o), .start_o(start_o), .algo_mode_o(algo_mode_o), // M1 的配置/脉冲输出接 测试程序 观察变量，非 测试程序 直接驱动。
    .type_mask_o(type_mask_o), .exp_pkt_len_o(exp_pkt_len_o), // M1 保存的 mask/期望长度输出接 测试程序 观察。
    .done_irq_en_o(done_irq_en_o), .err_irq_en_o(err_irq_en_o), .irq_o(irq_o) // IRQ 配置和中断输出接 测试程序 观察。
  );
  packet_sram m2 ( // M2 是实际存储设计；本 Lab 联合验证 M1→M2 的真实连线。
    .clk(PCLK), .rst_n(PRESETn), // M1、M2 同一时钟域，避免引入跨时钟问题。
    .apb_wr_en(pkt_mem_we), .apb_addr(pkt_mem_addr), .apb_wr_data(pkt_mem_wdata), // M1 发出的写使能/索引/数据实际到达 M2。
    .apb_rd_en(pkt_mem_re), .apb_rd_data(pkt_mem_rdata), // M1 的预读请求送 M2，M2 返回值再送 M1。
    .proc_rd_en(proc_rd_en), .proc_rd_addr(proc_rd_addr), .proc_rd_data(proc_rd_data) // 处理核侧由 测试程序 发独立读请求，M2 将数据返给 测试程序。
  );

  // ==================== 二、simulator：仿真激励与测试流程 ====================
  // 产生时钟、施加复位并调用 APB 任务和用例；比较任务同时核对返回值，接口中的 transfer 负责具体信号驱动。
  always #5 PCLK = ~PCLK; // 仿真时钟发生器，与所有 initial/always/被测电路 同时推进，不先跑完再运行 被测电路。

  // 激励用途：复位 M1/M2，并清零 TB 模拟的 M3 输入，为默认值检查和后续测试准备初始状态；本任务不做比较。
  task automatic reset_dut(); // 复用复位时序；同时负责复位 测试程序 自己模拟的 M3 输入。
    @(negedge PCLK); // 下降沿开始改变输入，避开设计采样点。
    PRESETn = 0; // 低有效复位拉低，M1/M2 的异步复位立即生效。
    busy_i = 0; done_i = 0; format_ok_i = 0; // 状态信号属于 测试程序 模拟处理核输入，M1 无权反向清这些输入。
    length_error_i = 0; type_error_i = 0; chk_error_i = 0; // 清 模拟处理核输入 错误，确保复位后 STATUS.error 来自确定输入。
    res_pkt_len_i = 0; res_pkt_type_i = 0; // 清 模拟处理核输入 长度和类型，不能把这些默认 0 归功于 M1 的存储。
    res_payload_sum_i = 0; res_payload_xor_i = 0; // 清 模拟处理核输入 摘要输入。
    proc_rd_en = 0; // 关闭处理核侧读请求，避免复位后无意读取未写内存。
    repeat (3) @(negedge PCLK); // 复位维持跨三个采样周期。
    PRESETn = 1; // 下降沿撤销复位，为下一采样沿准备正常操作。
  endtask

  function automatic apb_address_t packet_address(input int index); // 输入 word 编号 0～7，返回供 APB 使用的 12 位字节地址，不推进时间。
    return 12'h040 + 12'(index * 4); // 基址 040 加 4×index；12 位转换不是索引合法性检查，调用循环负责范围。
  endfunction

  // 复用自动比较器；actual 来自端口/采样，expected 来自规格或激励。
  // 检查用途：比较实际值 actual 与预期值 expected，发现 X/Z 或不相等就报错停止；本任务不产生激励。
  task automatic check_value(input string item, input apb_data_t actual, input apb_data_t expected);
    checks++; // 记录发生了一次真正的比较。
    if ($isunknown(actual) || $isunknown(expected) || actual !== expected) // isunkown用来表示检查是否有xz，即实际，期望值有xz或者实际不等于期望。未知值也失败；!== 单独使用时 X 与 X 会相等，所以另用 $isunknown。
      $fatal(1, "[FAIL] case=%s item=%s expected=%08x actual=%08x", // 报出用例、检查项、预期和实际，便于反查事务及波形。
             case_name, item, expected, actual);
  endtask

  // 用例调用 apb_write(地址, 数据) 后，先在这里把两个输入和写方向装成一份请求，再交给接口任务按时钟驱动信号。
  // 激励与检查：向 M1 指定地址写入 data，检查返回的 PSLVERR 是否符合预期；数据是否写对由后续读回或输出比较检查。
  task automatic apb_write(input apb_address_t address, input apb_data_t data,input bit expected_error = 0);
    apb_transaction_t request; // 声明本次 apb_write 调用自己的局部请求变量；前面的 typedef 只给出了格式，此句才创建存放字段的地方。
    apb_data_t unused_read; // 写操作也会返回 PRDATA 占位，但该值不属于写操作的检查目标。
    logic error_response; // 捕获本笔实际错误响应。
    request = '{direction:APB_WRITE, address:address, data:data}; // 把写方向 1、本次输入 address 和 data 分别填入三个字段；冒号左边是字段名，右边是要存的值。
    apb.transfer(request, unused_read, error_response); // 调用 apb 实例中的 transfer：第 1 项复制给它的 request，第 2、3 项在任务结束时接收读回值和错误响应。
    check_value(
      //调用在119行这个check任务//
      $sformatf("write address=%03x PSLVERR", address),//item
      //打印日志，显示本次写的地址和错误响应。
                {31'b0, error_response}, //actual
                {31'b0, expected_error}//expected
                );
  endtask

  // 记录用途：保存本组测试的名称和开始时的检查次数，便于定位失败、统计结果；本任务不验证 M1/M2 功能。
  task automatic begin_case(input string name); // 用字符串给一组相关检查命名。
    case_name = name; // 以后 FAIL 日志会带这个名字。
    case_begin_checks = checks; // 保存累计检查数快照，结束时只统计本用例新增部分。
    $display("[CASE_START] case=%s seed=%0d", case_name, test_seed); // 记录用例开始与实际 seed，便于定位多用例日志。
  endtask

  // 记录用途：前面的检查未报错停止时，打印本组测试通过及新增检查次数；本任务不另外判断 DUT 是否正确。
  task automatic end_case(); // 本用例走到这里且没有 fatal，才打印其检查增量。
    $display("[CASE_PASS] case=%s checks=%0d", case_name, checks - case_begin_checks); // 显示本用例实际执行的比较次数。
  endtask

  // 读用例也先在这里创建并填写自己的请求；与写任务相同，它把请求交给 transfer，但接收的数据要经 actual 继续交回调用方。
  // 激励与检查：读取 M1 指定地址，把 PRDATA 交给 actual，并检查 PSLVERR；本任务不比较读回数据的预期值。
  task automatic apb_read
  (input apb_address_t address, output apb_data_t actual, input bit expected_error = 0);//在address上读出数据
    apb_transaction_t request; // 声明本次 apb_read 的局部请求变量；它与 apb_write 的局部变量、transfer 的接收参数各自独立，名字相同不会自动连通。
    logic error_response;
    request = '{direction:APB_READ, address:address, data:32'b0}; // request源自8行所以是0占位 填写读方向 0 和调用方给的地址；data 填 0 只占位，因为 PWRITE=0 不会把它写入目标。
    apb.transfer(request, actual, error_response); // 第 1 项的记录复制到 transfer.request；任务结束后，PRDATA 的采样值交给 actual，PSLVERR 的采样值交给 error_response。
    check_value($sformatf("read address=%03x PSLVERR", address), // 先检查协议响应；正常读与错误读都能复用。
                {31'b0, error_response}, {31'b0, expected_error});
  endtask

  // 正常读比较入口：同时核对错误响应和期望数据。
  // 验证目标：通过 APB 读取指定地址，检查 M1 返回的错误响应和 PRDATA 是否都符合调用者给定的预期。
  task automatic expect_read(input apb_address_t address, input apb_data_t expected,
                             input bit expected_error = 0);
    apb_data_t actual; // 局部变量保存这次读到的数据，不是 被测电路 的寄存器。
    apb_read(address, actual, expected_error); // 先真正运行一笔总线读取。给一个address，在上面的read读出其actual返回到这个task
    check_value($sformatf("read address=%03x PRDATA", address), actual, expected); // 再把读回值与调用方提供的独立期望比较。
    $display("[CHECK] case=%s address=%03x expected=%08x actual=%08x PASS", // 通过后打印地址与数值证据，便于核对波形。
             case_name, address, expected, actual);
  endtask

  // 验证目标：复位后读取各寄存器并观察 M1/M2 输出，检查配置默认值、清零输出和 TB 模拟状态的读回是否正确。
  task automatic defaults_test(); // 检查复位默认值；期望来自字段表及 测试程序 清零的 模拟处理核输入 输入。
    begin_case("defaults"); // 开始一个具名测试段。
    expect_read(CTRL, 0); // CTRL.enable 复位 0，START 始终读 0。
    expect_read(CFG, 32'hF1); // CFG 默认 mask=F、mode=1，组合为 F1。
    expect_read(STATUS, 0); // 测试程序 的忙/完成/错误/格式输入都为 0，故 STATUS 返回 0。
    expect_read(IRQ_EN, 0); // IRQ 两个使能复位均为 0。
    expect_read(IRQ_STA, 0); // 待清除中断状态 复位清零，不应遗留历史中断。
    expect_read(PKT_LEN_EXP, 0); // 期望长度默认 0，表示未配置。
    expect_read(RES_PKT_LEN, 0); // 此时 模拟处理核输入 长度为 0，验证 RO 读通路。
    expect_read(RES_PKT_TYPE, 0); // 模拟处理核输入 类型为 0。
    expect_read(RES_PAYLOAD_SUM, 0); // 模拟处理核输入 sum 为 0。
    expect_read(RES_PAYLOAD_XOR, 0); // 模拟处理核输入 XOR 为 0。
    expect_read(ERR_FLAG, 0); // 三种 模拟处理核输入 错误都为 0。
    check_value("reset enable/start", {30'b0, enable_o, start_o}, 0); // 直接观察 M1 输出，不只依赖 APB 读回，避免读写路径互相掩盖。
    check_value("reset algo_mode", {31'b0, algo_mode_o}, 1);//check(item,actual,expected),再进入check任务进行比对，若不相等则报错
    check_value("reset type_mask", {28'b0, type_mask_o}, 15);
    check_value("reset expected length", {26'b0, exp_pkt_len_o}, 0);
    check_value("reset IRQ enables", {30'b0, err_irq_en_o, done_irq_en_o}, 0);
    check_value("reset IRQ output", {31'b0, irq_o}, 0);
    check_value("reset M2 APB output", pkt_mem_rdata, 0); // M2 的 APB 读输出复位为 0；不代表整个 mem 数组已初始化。
    check_value("reset M2 proc output", proc_rd_data, 0); // M2 的另一个独立读输出也必须清零。
    end_case();
  endtask

  // 验证目标：写 CTRL/CFG/PKT_LEN_EXP 后检查读回和 M1 配置输出，并验证先使能再启动时 start_o 只拉高一拍。
  task automatic control_test(); // 把软件写配置、APB 读回和真实控制输出三者对起来。
    begin_case("control");
    apb_write(CTRL, 1); // 先把 enable 置 1，为稍后的 START 建立许可。00000..01进入pwdata,pwdata[0/1]enable/start
    expect_read(CTRL, 1); // 确认配置在写事务结束后仍保存。
    check_value("enable_o", {31'b0, enable_o}, 1); // 同时检查 M1 输出触发器的实际值。
    apb_write(CFG, 32'hA0); // 实际调用例子：把 CFG 的数值 12'h004 和数据 A0 交给 apb_write，生成 direction=1、address=004、data=A0 的 request。
    expect_read(CFG, 32'hA0); // 读回按字段布局应为 A0。
    check_value("type_mask/algo", {27'b0, type_mask_o, algo_mode_o}, 32'h14); // 直接把 mask/mode 紧凑拼成五位检查，所以这里期望 14h，不是 CSR 布局 A0h。
    apb_write(PKT_LEN_EXP, 31); // 写 31 字节期望长度。
    expect_read(PKT_LEN_EXP, 31); // 读回有效六位值。
    check_value("expected length output", {26'b0, exp_pkt_len_o}, 31); // 核对同一字段实际送到后续模块的输出。
    apb_write(CTRL, 3); // 写 bit1 请求启动，同时 bit0=1 保持 enable；条件使用此前保存的 enable。
    check_value("START high", {31'b0, start_o}, 1); // transfer 返回时在完成沿后的下降沿，START 脉冲仍应为高。
    @(posedge PCLK); // 再等一个采样沿，让 START 的默认清零生效。
    #1ns; // 这次检查的是沿后寄存器值，故等 非阻塞赋值更新 完成；与 APB 返回采样场合不同。
    check_value("START one cycle", {31'b0, start_o}, 0); // 证明 START 只有一拍，不是一直保存为 1。
    expect_read(CTRL, 1); // START 读 0，enable 仍为 1，因此 CTRL 读回 1。
    end_case();
  endtask

  // 验证目标：TB 暂代 M3 请求读取 M2，检查 proc_rd_data 在上升沿前保持旧值、上升沿后返回指定位置的预期数据。
  task automatic processor_read(input int index, input apb_data_t expected); // 测试程序 暂代 M3，从 M2 的独立 proc 读口取一个 word。
    apb_data_t previous_data; // 保存读请求前输出，以检查同步读不会因地址一变就提前输出。
    @(negedge PCLK); // 下降沿准备读使能/地址。
    previous_data = proc_rd_data; // 采集读请求之前的保持值。
    proc_rd_en = 1; // 向 M2 发处理核侧同步读请求。
    proc_rd_addr = 3'(index); // 循环保证 index 为 0～7；尺寸转换只保留三位以匹配端口。
    #1ns; // 仍未到采样上升沿，输出必须保持 previous_data。
    check_value("M2 proc data must not change before clock", proc_rd_data, previous_data); // 若已改变，说明实现成了异步读或有其他时序问题。
    @(posedge PCLK); // M2 在这个沿接受使能与索引。
    #1ns; // 等待 M2 读输出的非阻塞赋值完成。
    check_value($sformatf("M2 proc word%0d", index), proc_rd_data, expected); // 与激励事先记录的 word 比较，不读 被测电路 内部数组作期望。
    @(negedge PCLK); // 采样完成后等下降沿再撤销请求。
    proc_rd_en = 0; // 关闭读使能；M2 应保留最后一次读输出。
  endtask

  // 验证目标：经 M1 写入 M2 八个位置，检查写次数和两条读路的数据，并在 APB 读编号 0 时检查 proc 读编号 7 的结果。
  task automatic memory_test(); // 写全部八字，再经 APB 和 proc 两条路径分别核对。
    int before_writes; // 记录 监视过程 原有写次数，稍后只计算本测试增量。
    begin_case("packet_memory");
    before_writes = memory_writes; // 快照统计值，不操作 被测电路。
    for (int i = 0; i < 8; i++) begin // 每次 apb_write 都等待多个边沿，所以本循环按事务逐个写，不是瞬时写八次。
      expected_words[i] = i == 0 ? 32'h0801_0009 : 32'h1000_0000 + i; // 独立产生预期内容；word0 用一份可辨认包头，其余位置取不同数据。
      apb_write(packet_address(i), expected_words[i]); // i 在 测试程序 里选明确地址；M1 把字节地址再换成 M2 索引，不使用 FIFO 式内部写指针。
    end
    check_value("exactly eight writes", memory_writes - before_writes, 8); // 通过真实接口 监视过程 计数，确认只有八次提交写。
    for (int i = 0; i < 8; i++) begin // 再次遍历八个编号，检查每个写入位置。
      expect_read(packet_address(i), expected_words[i]); // APB 主机路径读回，检验 M1 预读和地址译码。
      processor_read(i, expected_words[i]); // 独立处理核路径读回，检验 M2 的另一个读口。
    end
    @(negedge PCLK); // 下一下降沿准备两读口重叠测试。
    proc_rd_en = 1; // 处理核读口持续使能。
    proc_rd_addr = 7; // 处理核读末字 7；下面 APB 同时读首字 0。
    expect_read(packet_address(0), expected_words[0]); // APB 请求跨过采样沿时，proc 读口仍在独立读取 word7。
    check_value("two independent read ports", proc_rd_data, expected_words[7]); // 证明两读口能同拍返回不同地址，不是只让两个输出看同一地址。
    proc_rd_en = 0; // 关闭 测试程序 的 proc 请求，结束该场景。
    end_case();
  endtask

  // 验证目标：TB 给 M1 的状态/结果输入两组测试值，再读 STATUS/RES_* 检查地址和位映射；不验证 M3 算法。
  task automatic results_test(); // 改变 M3 模拟处理核输入 输入，检查 M1 的地址/字段选择；不检验真正报文算法。
    begin_case("result_stubs");
    for (int i = 0; i < 2; i++) begin // 两组不同输入可发现结果被错误锁存或固定成常数。
      @(negedge PCLK); // 下降沿改变外部结果与状态，避免采样竞争。
      done_i = 1; // 由 测试程序 模拟处理完成电平，M1 将它直透到 STATUS.done。
      format_ok_i = 1; // 由 测试程序 模拟格式正确，不由 M1 算法产生。
      res_pkt_len_i = i == 0 ? 6'd8 : 6'd63; // 两轮分别给 8 和六位最大值 63，检验低六位映射。
      res_pkt_type_i = i == 0 ? 8'h01 : 8'h80; // 第二轮刻意用 80h，M1 只读直透，不应代替 M3 做类型合法性检查。
      res_payload_sum_i = i == 0 ? 8'h5A : 8'hA5; // 两组 sum 不同，可发现错接、截断或固定读值。
      res_payload_xor_i = i == 0 ? 8'hC3 : 8'h3C; // XOR 同样给不同值，并与 sum 区分。
      expect_read(RES_PKT_LEN, {26'b0, res_pkt_len_i}); // 读 018，应返回当前 模拟处理核输入 长度，而不是先前某次保存的值。
      expect_read(RES_PKT_TYPE, {24'b0, res_pkt_type_i}); // 读 01C，应返回当前类型。
      expect_read(RES_PAYLOAD_SUM, {24'b0, res_payload_sum_i}); // 读 020，应返回当前 sum。
      expect_read(RES_PAYLOAD_XOR, {24'b0, res_payload_xor_i}); // 读 024，应返回当前 XOR。
      expect_read(STATUS, 32'hA); // STATUS 的 bit3/bit1 为 1，合成 Ah；busy/error 仍为 0。
    end
    end_case();
  endtask

  // 验证目标：用五种数据写配置，检查有效位保存、保留位读零和 IRQ 使能输出，再检查 M2 首尾位置能分别覆盖写并读回。
  task automatic patterns_test(); // 用少量模式检查保留位、有效字段和边界内存覆盖写。
    apb_data_t pattern; // 当前测试图样，作为激励和预期的共同源数据。
    begin_case("patterns");
    reset_dut(); // 先恢复默认状态，避免上个场景的 模拟处理核输入/使能影响本测试。
    for (int i = 0; i < 5; i++) begin // 五轮依次选择不同数据模式，实际写时序封装在 apb_write 中。
      case (i)
        0: pattern = 0; // 全 0 图样。
        1: pattern = '1; // 全 1 图样；SystemVerilog 的填充值按 pattern 的 32 位扩展。
        2: pattern = 32'hAAAA_AAAA; // 相邻 bit 交替，用于发现字段位错接。
        3: pattern = 32'h5555_5555; // 与上一模式互补。
        default: pattern = $urandom(); // 额外一组伪随机数据，由本次仿真 seed 决定。
      endcase
      apb_write(CFG, pattern); // 把完整图样写进 CFG，保留位也包含在写数据中。
      expect_read(CFG, pattern & 32'hF1); // 只应保存 mask 和 mode，因此与 F1h 掩码后的值比较。
      apb_write(PKT_LEN_EXP, pattern);
      expect_read(PKT_LEN_EXP, pattern & 32'h3F); // 期望长度仅低六位有效，其他位应读 0。
      apb_write(IRQ_EN, pattern);
      expect_read(IRQ_EN, pattern & 32'h03); // IRQ_EN 只有低两位有效。
      check_value("IRQ enable outputs", {30'b0, err_irq_en_o, done_irq_en_o}, pattern & 32'h03); // 再从真实输出确认这两位配置，避免只验证读回选择器。
    end
    apb_write(packet_address(0), 32'hDEAD_BEEF); // 覆盖首字内容。
    apb_write(packet_address(7), 32'h1234_5678); // 覆盖末字内容，检验索引边界。
    expect_read(packet_address(0), 32'hDEAD_BEEF); // 确认首字更新正确且未被末字写覆盖。
    expect_read(packet_address(7), 32'h1234_5678); // 确认末字更新正确。
    end_case();
  endtask

  function automatic apb_data_t reference_ro_read(input apb_address_t address); // 按字段表从 测试程序 模拟处理核输入 构造 RO 期望；不读取 M1 内部变量或实际 PRDATA。
    case (address)
      STATUS: return {28'b0, format_ok_i, // STATUS 预期来自同一组外部状态输入，低位顺序按寄存器定义。
                      (length_error_i | type_error_i | chk_error_i), done_i, busy_i};
      RES_PKT_LEN: return {26'b0, res_pkt_len_i}; // 长度 RO 的预期值来自 模拟处理核输入，不是写入数据。
      RES_PKT_TYPE: return {24'b0, res_pkt_type_i}; // 类型 RO 的预期值来自 模拟处理核输入。
      RES_PAYLOAD_SUM: return {24'b0, res_payload_sum_i}; // sum RO 的预期值来自 模拟处理核输入。
      RES_PAYLOAD_XOR: return {24'b0, res_payload_xor_i}; // XOR RO 的预期值来自 模拟处理核输入。
      ERR_FLAG: return {29'b0, chk_error_i, type_error_i, length_error_i}; // 错误 RO 的预期分别来自三根错误输入。
      default: return 0;
    endcase
  endfunction

  // 验证目标：只读地址写入、非法地址访问和 busy 时写内存应报错且不破坏原值；busy 时合法读取和普通配置读写仍应允许。
  task automatic errors_test(); // 非法请求既要报错，也要证明没有改变原数据或配置。
    apb_data_t ignored_read; // 非法读的 PRDATA 未规定，接收但不额外要求它必须为 0。
    begin_case("errors");
    reset_dut();
    @(negedge PCLK); // 下降沿向 模拟处理核输入 提供非零状态和结果。
    done_i = 1; // done=1，构成可辨认的 RO 非零状态。
    format_ok_i = 1; // format_ok 位也置 1，只测试直透位，不验证 M3 语义组合。
    length_error_i = 1; // 长度错误输入置 1。
    chk_error_i = 1; // 校验错误输入也置 1，测试错误位可同时返回。
    res_pkt_len_i = 8; // 准备已存在的长度值，检验 RO 写被拒后保留此值。
    res_pkt_type_i = 1; // 准备类型值。
    res_payload_sum_i = 8'h5A; // 准备非零 sum。
    res_payload_xor_i = 8'hC3; // 准备不同的非零 XOR。
    apb_write(STATUS, '1, 1);          expect_read(STATUS, reference_ro_read(STATUS)); // 写 RO 预期 PSLVERR=1；随后读应仍是 模拟处理核输入 状态，不能被写数据覆盖。
    apb_write(RES_PKT_LEN, '1, 1);     expect_read(RES_PKT_LEN, reference_ro_read(RES_PKT_LEN)); // 长度结果地址拒写，读回仍为原非零长度。
    apb_write(RES_PKT_TYPE, '1, 1);    expect_read(RES_PKT_TYPE, reference_ro_read(RES_PKT_TYPE)); // 类型结果地址拒写，原值保持。
    apb_write(RES_PAYLOAD_SUM, '1, 1); expect_read(RES_PAYLOAD_SUM, reference_ro_read(RES_PAYLOAD_SUM)); // sum 地址拒写，原值保持。
    apb_write(RES_PAYLOAD_XOR, '1, 1); expect_read(RES_PAYLOAD_XOR, reference_ro_read(RES_PAYLOAD_XOR)); // XOR 地址拒写，原值保持。
    apb_write(ERR_FLAG, '1, 1);        expect_read(ERR_FLAG, reference_ro_read(ERR_FLAG)); // ERR_FLAG 地址拒写，不允许软件通过写 1 伪造错误状态。
    apb_write(12'h02C, '1, 1); apb_read(12'h02C, ignored_read, 1); // 02C 是保留地址，读写都应报错；不比较未规定的错误读数据。
    apb_write(12'h060, '1, 1); apb_read(12'h060, ignored_read, 1); // 060 位于窗口之外，不能因低三位相同而误写 mem[0]。
    apb_write(12'h041, '1, 1); apb_read(12'h041, ignored_read, 1); // 041 虽接近 040，却非 4 字节对齐，必须拒绝。
    apb_write(12'h040, 32'h1122_3344); // 先向合法地址写一个已知值，建立 busy 写保护测试的原始数据。
    @(negedge PCLK);
    busy_i = 1; // 测试程序 模拟 M3 正忙，M1 应禁止接下来的内存写。
    apb_write(12'h040, '1, 1); // 尝试覆盖，预期报错；1 是测试预期，不会直接驱动 PSLVERR。
    expect_read(12'h040, 32'h1122_3344); // busy 下合法内存读仍允许，且原数据必须未被错误写破坏。
    apb_write(CFG, 32'h21); expect_read(CFG, 32'h21); // busy 只保护报文内存，普通 CFG 配置仍允许读写。
    apb_write(PKT_LEN_EXP, 16); expect_read(PKT_LEN_EXP, 16); // 期望长度配置在 busy 时也仍可访问。
    apb_write(IRQ_EN, 3); expect_read(IRQ_EN, 3); // IRQ_EN 配置同理；不把整个 APB 从机锁住。
    expect_read(STATUS, reference_ro_read(STATUS)); // busy_i 应通过 STATUS[0] 被读出，值来自 模拟处理核输入。
    @(negedge PCLK);
    busy_i = 0; // 测试程序 撤销模拟忙状态，为后续场景恢复环境。
    end_case();
  endtask

  // 激励用途：TB 设置三种错误输入并制造 done_i 上升沿，供 IRQ 测试检查 M1 是否按使能记录完成/错误中断。
  task automatic completion_event(input logic [2:0] error_bits); // 测试程序 模拟 M3 的一次完成事件；error_bits 参数按 chk/type/length 排列。
    @(negedge PCLK); // 在下降沿改变 模拟处理核输入，留半周期给 M1 采样。
    done_i = 0; // 先让 done 为 0，并跨过一个上升沿，使 previous_done 真正记录低电平。
    length_error_i = error_bits[0]; // 把参数 bit0 驱动到长度错误输入。
    type_error_i = error_bits[1]; // 把参数 bit1 驱动到类型错误输入。
    chk_error_i = error_bits[2]; // 把参数 bit2 驱动到校验错误输入。
    @(negedge PCLK); // 已跨过记录 done=0 的采样沿，准备制造新完成。
    done_i = 1; // 测试程序 拉高 done；合格新事件立即组合可见，下一上升沿保存。
    @(negedge PCLK); // 等事件捕获后的下降沿再返回，调用者随后可读 待清除中断状态。
  endtask

  // 验证目标：检查 IRQ 使能、完成/错误事件置位、irq_o 或运算、写 1 清除和写 0 保持，以及 done_i 持续为高不重复触发。
  task automatic irq_test(); // 依次检查完成、错误、保持和 W1C，不把读 IRQ_STA 当成清除。
    begin_case("irq");
    reset_dut();
    apb_write(IRQ_EN, 3); expect_read(IRQ_EN, 3); // 打开两个 IRQ 捕获使能，并检查配置读回。
    check_value("IRQ enable outputs", {30'b0, err_irq_en_o, done_irq_en_o}, 3);
    completion_event(0); // 模拟无错误完成，预期只置 done 待清除中断状态。
    expect_read(IRQ_STA, 1); // bit0=1、bit1=0。
    check_value("done IRQ high", {31'b0, irq_o}, 1); // 一类 待清除中断状态 足以让组合 irq_o 拉高。
    apb_write(IRQ_STA, 0); expect_read(IRQ_STA, 1); // W1C 写 0 无效，待清除中断状态 应保持 1。
    apb_write(IRQ_STA, 1); expect_read(IRQ_STA, 0); // 写 bit0=1 清完成 待清除中断状态，随后应读 0。
    check_value("done IRQ cleared", {31'b0, irq_o}, 0); // 待清除中断状态 清除后，组合 IRQ 也应拉低。
    repeat (2) @(negedge PCLK); // 继续保持 done 高电平两个周期。
    expect_read(IRQ_STA, 0); // 高电平不是新上升沿，不能每拍重新置 待清除中断状态。
    completion_event(3'b111); // 三个错误输入都置位，并制造一次新完成事件。
    expect_read(IRQ_STA, 3); // 完成与错误两个 待清除中断状态 都应为 1。
    check_value("both pending flags use OR, not XOR", {31'b0, irq_o}, 1); // 两位同时为 1 时 OR=1；若错误使用 XOR 就会变 0。
    apb_write(IRQ_STA, 1); expect_read(IRQ_STA, 2); // 只清完成位，错误 待清除中断状态 应保留为二进制 10。
    check_value("error IRQ remains", {31'b0, irq_o}, 1); // 仍有错误 待清除中断状态，IRQ 必须继续为高。
    apb_write(IRQ_STA, 2); expect_read(IRQ_STA, 0); // 再清错误位，两个 待清除中断状态 才都为 0。
    check_value("both IRQs cleared", {31'b0, irq_o}, 0); // 两位都清完，IRQ 应为 0。
    completion_event(3'b111); // 重新制造带错完成，给清两位测试建立状态。
    expect_read(IRQ_STA, 3); // 确认清除前两位都为 1。
    apb_write(IRQ_STA, 3); expect_read(IRQ_STA, 0); // 一次写 11 同时清两类 待清除中断状态。
    check_value("W1C clears both flags", {31'b0, irq_o}, 0); // 检查对外中断随之消失。
    apb_write(IRQ_EN, 0); expect_read(IRQ_EN, 0); // 关闭两个捕获使能。
    completion_event(3'b111); expect_read(IRQ_STA, 0); // 即使来了带错完成，也不应产生新的 待清除中断状态。
    apb_write(IRQ_EN, 2); expect_read(IRQ_EN, 2); // 只允许错误 IRQ 捕获。
    for (int i = 0; i < 3; i++) begin // 分别只打开 length/type/chk 三种错误，证明任一错误都足以捕获错误中断。
      completion_event(3'b001 << i); // 001 左移 i 得 001/010/100，分别驱动三种错误。
      expect_read(IRQ_STA, 2); // 只有错误使能开，应只得到 bit1 待清除中断状态。
      apb_write(IRQ_STA, 2); expect_read(IRQ_STA, 0); // 清该位，避免下一轮结果受上一轮 待清除中断状态 影响。
      check_value("error IRQ cleared", {31'b0, irq_o}, 0); // 确保每轮错误 IRQ 已清零。
    end
    apb_write(IRQ_EN, 1); expect_read(IRQ_EN, 1); // 最后只打开完成 IRQ。
    completion_event(3'b111); expect_read(IRQ_STA, 1); // 即使处理有错，也只捕获已使能的完成 待清除中断状态。
    apb_write(IRQ_STA, 1); expect_read(IRQ_STA, 0); // 清最后一次完成 待清除中断状态。
    check_value("final IRQ cleared", {31'b0, irq_o}, 0); // 确认用例结束没有残留中断。
    end_case();
  endtask

  // 检查用途：在指定时刻比较 M1 的两个中断标志和 irq_o 是否符合预期，并打印完成输入和已保存标志供逐拍核对。
  task automatic check_irq_cycle(input string phase, input logic [1:0] expected);
    check_value({phase, " pending"}, {30'b0, m1.err_irq, m1.done_irq}, {30'b0, expected});
    check_value({phase, " irq_o"}, {31'b0, irq_o}, {31'b0, |expected});
    $display("[IRQ_CYCLE] time=%0t phase=%s done=%b previous=%b pending=%b%b saved=%b%b irq=%b",
             $time, phase, done_i, m1.previous_done, m1.err_irq, m1.done_irq,
             m1.err_irq_saved, m1.done_irq_saved, irq_o);
  endtask

  // 验证目标：按指定使能和错误组合发布完成事件，检查中断立即可见、下一拍保存，以及首次捕获时写 1 清除和后续保持行为。
  task automatic cycle_completion(input string name, input logic [1:0] mask,
                                  input logic [2:0] errors, input logic [1:0] expected,
                                  input bit clear_on_capture = 0);
    reset_dut();
    apb_write(IRQ_EN, {30'b0, mask});
    fork
      begin
        if (clear_on_capture) apb_write(IRQ_STA, 3);
        else expect_read(IRQ_STA, {30'b0, expected});
      end
      begin
        // SETUP 沿后发布完成，模拟真实 M3 的非阻塞更新；下一沿才是 ACCESS 和首次保存沿。
        @(posedge PCLK iff (apb.PSEL && !apb.PENABLE));
        done_i <= 1;
        length_error_i <= errors[0];
        type_error_i <= errors[1];
        chk_error_i <= errors[2];
        #1ns;
        check_irq_cycle({name, " immediate"}, expected);
        check_value("not saved yet", {30'b0, m1.err_irq_saved, m1.done_irq_saved}, 0);
        if (!clear_on_capture) check_value("IRQ_STA before next edge", apb.PRDATA, {30'b0, expected});
        @(posedge PCLK);
        #1ns;
        check_irq_cycle({name, " capture"}, clear_on_capture ? 2'b00 : expected);
        check_value("saved after next edge", {30'b0, m1.err_irq_saved, m1.done_irq_saved},
                    clear_on_capture ? 0 : {30'b0, expected});
      end
    join
    apb_write(IRQ_STA, 0);
    expect_read(IRQ_STA, clear_on_capture ? 0 : {30'b0, expected});
    apb_write(IRQ_EN, 0);
    expect_read(IRQ_STA, clear_on_capture ? 0 : {30'b0, expected});
    apb_write(IRQ_STA, 1);
    expect_read(IRQ_STA, clear_on_capture ? 0 : {30'b0, expected & 2'b10});
    apb_write(IRQ_STA, 2);
    repeat (2) @(negedge PCLK);
    expect_read(IRQ_STA, 0);
    check_irq_cycle({name, " held done after W1C"}, 0);
  endtask

  // 验证目标：逐拍检查完成/错误中断、禁止捕获、旧完成后再使能，以及写 1 清除时能区分已到达事件和接收沿后才到达的新事件。
  task automatic irq_cycle_test();
    begin_case("irq_cycle");
    cycle_completion("normal", 3, 0, 1);
    cycle_completion("error", 3, 3'b111, 3);
    cycle_completion("disabled", 0, 3'b111, 0);
    apb_write(IRQ_EN, 3);
    expect_read(IRQ_STA, 0);
    check_irq_cycle("enable after old completion", 0);
    cycle_completion("W1C at first capture", 3, 3'b111, 3, 1);
    reset_dut();
    apb_write(IRQ_EN, 3);
    fork
      apb_write(IRQ_STA, 3);
      begin
        // 与上一例不同：这次完成在 W1C 接收沿之后才出现，不能被当作此前的旧事件清掉。
        @(posedge PCLK iff (apb.PSEL && apb.PENABLE));
        done_i <= 1;
        length_error_i <= 1;
        #1ns;
        check_irq_cycle("new completion at W1C edge", 3);
        check_value("new completion not saved yet", {30'b0, m1.err_irq_saved, m1.done_irq_saved}, 0);
        @(posedge PCLK);
        #1ns;
        check_irq_cycle("new completion saved", 3);
        check_value("new completion saved bits", {30'b0, m1.err_irq_saved, m1.done_irq_saved}, 3);
      end
    join
    expect_read(IRQ_STA, 3);
    apb_write(IRQ_STA, 3);
    expect_read(IRQ_STA, 0);
    check_irq_cycle("new completion cleared", 0);
    end_case();
  endtask

  initial begin // 主测试线程，与时钟和 监视过程 同时运行。
    $timeformat(-9, 0, " ns", 12); // 只格式化日志中的时间单位，不改变仿真时间本身。
    if (!$value$plusargs("TEST=%s", test_name)) test_name = "smoke"; // 读取命令行 +TEST；未给参数才默认 smoke。
    if (!$value$plusargs("SEED=%d", test_seed)) test_seed = 1; // 读取 +SEED；调用日志与运行参数保持一致。
    $display("[RUN] test=%s seed=%0d clock_ns=10 memory_words=8 data_bits=32", test_name, test_seed); // 记录测试名、seed 与固定环境配置，便于复现。
    case_name = "reset"; // 给初始化阶段设置可识别的失败标签。
    reset_dut(); // 先复位，再运行任意选中的测试。
    case (test_name) // 根据实际 TEST 参数选择执行任务。
      "smoke", "regress": begin // smoke/regress 共用必做基础流程，regress 在下面再增加选做/扩展。
        defaults_test(); // 验证默认寄存器和输出。
        control_test(); // 验证 RW 配置与 START。
        memory_test(); // 验证八字内存及两条读路。
        results_test(); // 验证外部状态/结果到 APB 的直透。
        if (test_name == "regress") begin // 只有 TEST=regress 才追加以下测试。
          patterns_test(); // 追加数据模式和边界扩展。
          errors_test(); // 追加错误访问及无副作用测试。
          irq_test(); // 追加完整 IRQ/W1C 测试。
          irq_cycle_test();
        end
      end
      "defaults": defaults_test();
      "control": control_test();
      "memory": memory_test();
      "results": results_test();
      "patterns": patterns_test();
      "errors": errors_test();
      "irq": irq_test();
      "irq_cycle": irq_cycle_test();
      default: $fatal(1, "Unknown TEST=%s", test_name); // 未知名称必须失败，不能打印别的用例 PASS 来掩盖选错入口。
    endcase
    check_value("SETUP/ACCESS count", access_count, setup_count); // 核对真实监视到的每个 SETUP 都有一个 ACCESS 配对。
    test_done = 1; // 仅全部比较完成且未 fatal 后，向外部脚本报告成功完成。
    $display("[PASS] test=%s seed=%0d checks=%0d setup=%0d access=%0d memory_writes=%0d", // 打印实际运行统计，而不是固定输出一个无依据的 PASS。
             test_name, test_seed, checks, setup_count, access_count, memory_writes);
    $finish; // 结束仿真，其他时钟/监视过程/超时过程一起停止。
  end

  // ==================== 三、monitor：独立观察与检查 ====================
  // apb 中的请求由 transfer 任务驱动，PREADY/PSLVERR 由 M1 返回；pkt_mem_* 是 M1 送往 M2 的实际写接口，本区只观察和检查。
  always @(posedge PCLK) begin : monitor // 每个上升沿执行一次，begin : monitor 给这段过程起名；此时检查 M2 本沿将接收的信号，不等 <= 稍后更新。
    static bit setup_seen = 0; // 声明 1 位记号；static 让它跨多次执行保留，=0 只初始化一次，1 表示已看到准备阶段、正在等执行阶段。
    static apb_transaction_t setup_request; // 用前面定义的 45 位请求格式保存准备阶段的方向、地址、数据；static 让下一上升沿还能拿它比较。
    apb_transaction_t sampled; // 声明同格式的当前请求记录，下面每次从总线重新取值；与 setup_request 分开，才能比较前后是否一致。
    bit packet_hit; // 声明 1 位判断结果，1 表示当前地址属于报文内存；下面自己按地址计算，不取 M1 内部的判断结果。
    if (!PRESETn) setup_seen = 0; // 复位有效时清除待配对记号，使复位前未完成的请求作废，复位后必须从新的准备阶段开始。
    else begin // 未复位时，执行下面的响应、阶段和内存写检查。
      if (apb.PREADY !== 1'b1) $fatal(1, "[PROTOCOL] PREADY must be 1"); // 本实验 M1 不插入等待周期，PREADY 必须为确定的 1；否则主机可能无法按约定在执行沿完成访问，立即报错。
      if (!(apb.PSEL && apb.PENABLE) && apb.PSLVERR !== 1'b0) // PSEL 与 PENABLE 没有同时为 1，说明尚未执行访问；此时 PSLVERR 却不是确定的 0 就报错，检查 M1 在空闲或准备阶段是否正确撤销错误响应。
        $fatal(1, "[PROTOCOL] PSLVERR must be 0 outside ACCESS"); // $fatal 打印错误并停止，提示空闲或准备阶段不应带着错误响应。
      sampled = '{direction:apb_direction_t'(apb.PWRITE), address:apb.PADDR, data:apb.PWDATA}; // '{字段:值} 按名字填记录；方向取 PWRITE、地址取 PADDR、数据取 PWDATA，类型名'(...) 把方向转成前面定义的枚举格式。
      packet_hit = apb.PADDR >= 12'h040 && apb.PADDR <= 12'h05C && apb.PADDR[1:0] == 0; // 目标在报文内存窗口内，且地址落在一个完整 32 位字的起点时才命中；例如 044 合法而 041 不合法，后面用它判断是否应写 M2。
      if (apb.PSEL && !apb.PENABLE) begin // 从机已被选中，但还未进入执行阶段，表示主机正在摆好方向、地址和数据；先记录这些内容，下一阶段应保持不变。
        setup_seen = 1; // 记住本笔请求已经完成准备，供下一执行沿确认有前置准备；这是监视用的变量，不控制 M1。
        setup_request = sampled; // 把当前记录的三个字段整体复制到准备记录，供下一上升沿比较；后来 sampled 改变不会带着这份记录一起变。
        setup_count++; // 统计一次实际观察到的准备阶段，结束时与执行次数核对，检查是否有准备后未执行的访问。
        if (pkt_mem_we !== 1'b0) $fatal(1, "[PROTOCOL] write during SETUP"); // 当前只在准备阶段，M2 不应保存数据；若 M1 已给出写使能，M2 就可能在本沿提前写入，因此报错。
      end else if (apb.PSEL && apb.PENABLE) begin // 从机已被选中且进入执行阶段，本实验又无需等待，因此 M1/M2 应在这个上升沿接收本笔访问，同时检查请求是否保持。
        if (!setup_seen || sampled !== setup_request) // 已经进入执行阶段，却没见过前置准备，或方向、地址、数据与准备时不同，就报错，防止电路接收一笔未经准备或中途变更的请求。
          $fatal(1, "[PROTOCOL] missing SETUP or changed direction/address/data"); // 报告缺少准备阶段或方向、地址、写数据被改变，停止仿真。
        setup_seen = 0; // 本次执行已用掉前面的准备记录，清除待配对记号，使下一笔执行不能重复借用同一次准备。
        access_count++; // 统计一次执行完成；本实验 PREADY 固定为 1，所以观察到的这个执行沿就是访问完成沿。
        if (apb.PWRITE && packet_hit && !busy_i) begin // 主机要求写入且目标是报文内存，同时处理核不忙，表示本沿应允许更新 M2；下面检查 M1 是否真的发出正确写接口，busy_i 由测试程序模拟处理核驱动。
          if (pkt_mem_we !== 1'b1 || pkt_mem_addr !== 3'((apb.PADDR - 12'h040) >> 2) || // 应该写入却没有写使能，或 M1 给 M2 的编号不等于(字节地址-040)/4，就报错；每字占 4 字节，例如 04C 应写编号 3，3'(...) 将编号限为 3 位。
              pkt_mem_wdata !== apb.PWDATA) // 写入的数据也必须与主机本次提供的数据一致，否则即使写使能和地址正确，M2 仍会保存错误内容，所以同样报错。
            $fatal(1, "[MEM_FAIL] case=%s address=%03x expected_we=1 actual_we=%b expected_index=%0d actual_index=%0d expected_data=%08x actual_data=%08x", // 打印失败详情并停止；后面变量按顺序填进占位符，%s 字符串、%x 十六进制、%b 二进制、%d 十进制。
                   case_name, apb.PADDR, pkt_mem_we, (apb.PADDR - 12'h040) >> 2, // 依次给出 begin_case 保存的用例名、主机地址、实际写使能，以及按主机地址算出的预期编号。
                   pkt_mem_addr, apb.PWDATA, pkt_mem_wdata); // 再给出 M1 实际输出的编号、主机提供的预期数据，以及 M1 实际送往 M2 的数据。
          memory_writes++; // 使能、地址、数据检查都通过才记一次写请求，供用例核对有没有漏写或多写；这还不能证明存储内容正确，实际内容由后面的读回比较确认。
          $display("[MEM_WRITE] %0t address=%03x we=1 index=%0d data=%08x", // $display 只打印、不停止；记录本次写入的时间、主机地址、M2 位置编号和数据，方便对照波形。
                   $time, apb.PADDR, pkt_mem_addr, pkt_mem_wdata); // $time 取当前仿真时间，其他值取当前主机地址和 M1 到 M2 的实际写接口。
        end else if (pkt_mem_we !== 1'b0) $fatal(1, "[MEM_FAIL] unexpected write"); // 不满足合法且不忙的内存写条件时，M1 就应关闭 M2 写使能；否则读访问、错误地址或处理中的报文都可能意外改写存储器。
      end else begin // 主机没有选中 M1，当前没有要执行的访问，下面检查 M2 不会因残留控制信号而写入。
        setup_seen = 0; // 回到空闲意味着前一准备没有紧接着执行，将记录作废，后续访问需要重新准备。
        if (pkt_mem_we !== 1'b0) $fatal(1, "[MEM_FAIL] write while idle"); // 没有有效访问却仍存在写使能，M2 就可能在本上升沿误写；检测到这种情况立即报错。
      end
    end
  end

  initial begin // initial 从仿真开始独立执行一次，这段超时保护与时钟、激励、monitor 同时运行。
    #100us; // 等仿真时间经过 100us；若正常测试先调用 $finish，仿真已结束，就不会走到下一句。
    $fatal(1, "[TIMEOUT] Lab1 did not finish within 100 us"); // 等完仍未结束就报超时并停止，避免测试一直卡着却没有明确失败结果。
  end
endmodule
