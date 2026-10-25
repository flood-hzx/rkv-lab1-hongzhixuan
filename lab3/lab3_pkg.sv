`timescale 1ns/1ps

package lab3_pkg;
  localparam logic [11:0] CTRL = 'h000, CFG = 'h004, STATUS = 'h008,
    IRQ_EN = 'h00C, IRQ_STA = 'h010, PKT_LEN_EXP = 'h014,
    RES_PKT_LEN = 'h018, RES_PKT_TYPE = 'h01C, RES_PAYLOAD_SUM = 'h020,
    RES_PAYLOAD_XOR = 'h024, ERR_FLAG = 'h028, PKT_MEM = 'h040;
  typedef bit [7:0] byte_t;
  typedef logic [31:0] word_t;
  typedef word_t words_t [0:7];
  typedef struct packed {
    logic [5:0] length;
    logic [7:0] kind, sum, xor_value;
    logic length_error, type_error, chk_error, format_ok;
  } result_t;

  class packet_item;
    rand byte_t length, kind;
    rand byte_t payload [];
    rand bit mode;
    rand bit [3:0] mask;
    rand bit [5:0] expected_length;
    rand bit [1:0] irq_enable;
    rand bit bad_checksum;
    bit busy_probe = 0, partial_clear = 0;
    bit reset_during_busy = 0;
    constraint legal_length { length inside {[4:32]}; }
    constraint legal_kind { kind inside {1, 2, 4, 8}; }
    constraint legal_checksum { bad_checksum == 0; }
    constraint payload_size {
      if (length inside {[4:32]}) payload.size() == int'(length) - 4;
      else payload.size() == 0;
    }

    function new();
      configure();
    endfunction

    function void configure(input int length = 8, input int kind = 1);
      this.length = byte_t'(length);
      this.kind = byte_t'(kind);
      payload = new[(length >= 4 && length <= 32) ? length - 4 : 0];
      foreach (payload[i]) payload[i] = byte_t'(i + 1);
      mode = 1;
      mask = 'hF;
      expected_length = 0;
      irq_enable = 3;
      bad_checksum = 0;
    endfunction

    function void pack_words(output words_t words);
      foreach (words[i]) words[i] = 'hA5A5_A5A5;
      words[0] = {length, kind, 8'h00,
                  byte_t'(length ^ kind ^ (bad_checksum ? 8'h01 : 8'h00))};
      foreach (payload[i]) begin
        if (i >= 28) $fatal(1, "[PACK_FAIL] payload exceeds SRAM");
        words[1 + i / 4][31 - 8 * (i % 4) -: 8] = payload[i];
      end
    endfunction
  endclass

  class apb_observation;
    bit reset_n, access, write;
    logic [11:0] address;
    word_t wdata, rdata;
    logic ready, error;
    logic busy_before, done_before, start_before;
    logic busy, done, start, irq;
    result_t actual;
  endclass

  class frame_observation;
    int index;
    bit first_after_reset;
    int unsigned length;
    byte_t kind;
    bit mode;
    bit [3:0] mask;
    bit [5:0] expected_length;
    bit [1:0] irq_enable;
    result_t actual;
  endclass

  virtual class coverage_sink;
    pure virtual function void sample_frame(input frame_observation frame);
    pure virtual function void sample_access(input apb_observation tr);
    pure virtual function void report();
  endclass

  // 参考模型只接收 monitor 重建的输入，不读取 DUT 内部存储器或算法中间量。
  class reference_model;
    static function result_t predict(input words_t words, input bit mode,
                                    input bit [3:0] mask, input bit [5:0] exp_len);
      result_t value;
      byte_t length, kind, flags, check_byte, data_byte;
      bit allowed;
      value = '0;
      {length, kind, flags, check_byte} = words[0];
      value.length = length[5:0];
      value.kind = kind;
      value.length_error = length < 4 || length > 32 ||
                           (exp_len != 0 && length != exp_len);
      case (kind)
        1: allowed = mask[0];
        2: allowed = mask[1];
        4: allowed = mask[2];
        8: allowed = mask[3];
        default: allowed = 0;
      endcase
      value.type_error = !allowed;
      value.chk_error = mode && check_byte != (length ^ kind ^ flags);
      if (length >= 4 && length <= 32)
        for (int position = 4; position < int'(length); position++) begin
          data_byte = words[position / 4][31 - 8 * (position % 4) -: 8];
          value.sum += data_byte;
          value.xor_value ^= data_byte;
        end
      value.format_ok = !(value.length_error || value.type_error || value.chk_error);
      return value;
    endfunction
  endclass

  class apb_monitor;
    virtual ppa_if vif;
    mailbox #(apb_observation) observed;
    bit stop_requested = 0;
    bit setup_seen = 0;
    logic [44:0] setup_request;

    function new(input virtual ppa_if vif, input mailbox #(apb_observation) observed);
      this.vif = vif;
      this.observed = observed;
    endfunction

    task run();
      apb_observation tr;
      while (!stop_requested) begin
        @(posedge vif.PCLK);
        tr = new();
        tr.reset_n = vif.PRESETn;
        tr.access = vif.PSEL && vif.PENABLE;
        tr.write = vif.PWRITE;
        tr.address = vif.PADDR;
        tr.wdata = vif.PWDATA;
        tr.rdata = vif.PRDATA;
        tr.ready = vif.PREADY;
        tr.error = vif.PSLVERR;
        tr.start_before = vif.start;
        tr.busy_before = vif.busy;
        tr.done_before = vif.done;
        if (!vif.PRESETn) setup_seen = 0;
        else begin
          if (vif.PSEL && !vif.PENABLE) begin
            setup_request = {vif.PWRITE, vif.PADDR, vif.PWDATA};
            setup_seen = 1;
          end
          if (tr.access) begin
            if (!setup_seen || setup_request !== {vif.PWRITE, vif.PADDR, vif.PWDATA})
              $fatal(1, "[PROTOCOL_FAIL] ACCESS without stable SETUP");
            setup_seen = 0;
          end
          if (!tr.access && vif.PSLVERR !== 1'b0)
            $fatal(1, "[PROTOCOL_FAIL] PSLVERR outside ACCESS");
        end
        // APB 返回在沿前接收；状态/结果在本沿 NBA 更新之后观察，不能混成同一个采样点。
        #1ns;
        tr.start = vif.start;
        tr.busy = vif.busy;
        tr.done = vif.done;
        tr.irq = vif.irq;
        tr.actual = '{length:vif.res_len, kind:vif.res_type,
          sum:vif.res_sum, xor_value:vif.res_xor, length_error:vif.length_error,
          type_error:vif.type_error, chk_error:vif.chk_error, format_ok:vif.format_ok};
        observed.put(tr);
      end
      observed.put(null);
    endtask
  endclass

  class scoreboard;
    mailbox #(apb_observation) observed;
    coverage_sink coverage;
    string name;
    int seed, checks = 0, accesses = 0, starts = 0, frames = 0, aborted = 0;
    bit first_after_reset = 1;
    int busy_reads = 0, done_reads = 0, busy_rejects = 0;
    bit stopped = 0, active = 0, completed_state = 0;
    bit busy_before_expected, done_before_expected;
    words_t memory;
    bit memory_valid [0:7];
    bit enable, mode;
    bit [3:0] mask;
    bit [5:0] exp_len;
    bit [1:0] irq_enable, pending;
    result_t last_result, expected;
    frame_observation frame;

    function new(input mailbox #(apb_observation) observed,
                 input string name, input int seed);
      this.observed = observed;
      this.name = name;
      this.seed = seed;
      reset_model();
    endfunction

    function void check_value(input string item, input word_t actual, input word_t wanted);
      checks++;
      if ($isunknown(actual) || $isunknown(wanted) || actual !== wanted)
        $fatal(1, "[FAIL] test=%s seed=%0d frame=%0d item=%s expected=%08h actual=%08h",
               name, seed, frames, item, wanted, actual);
    endfunction

    function void reset_model();
      if (active) aborted++;
      first_after_reset = 1;
      enable = 0;
      mode = 1;
      mask = 'hF;
      exp_len = 0;
      irq_enable = 0;
      pending = 0;
      last_result = '0;
      active = 0;
      completed_state = 0;
      foreach (memory_valid[i]) memory_valid[i] = 0;
    endfunction

    function bit is_memory(input logic [11:0] address);
      return address >= PKT_MEM && address <= PKT_MEM + 28 && address[1:0] == 0;
    endfunction

    function bit is_csr(input logic [11:0] address);
      return address inside {CTRL, CFG, STATUS, IRQ_EN, IRQ_STA, PKT_LEN_EXP,
        RES_PKT_LEN, RES_PKT_TYPE, RES_PAYLOAD_SUM, RES_PAYLOAD_XOR, ERR_FLAG};
    endfunction

    function bit is_ro(input logic [11:0] address);
      return address inside {STATUS, RES_PKT_LEN, RES_PKT_TYPE,
                            RES_PAYLOAD_SUM, RES_PAYLOAD_XOR, ERR_FLAG};
    endfunction

    function word_t read_expected(input apb_observation tr);
      case (tr.address)
        CTRL: return word_t'(enable);
        CFG: return {24'b0, mask, 3'b0, mode};
        STATUS: return {28'b0, last_result.format_ok,
          (last_result.length_error | last_result.type_error | last_result.chk_error),
          done_before_expected, busy_before_expected};
        IRQ_EN: return word_t'(irq_enable);
        IRQ_STA: return word_t'(pending);
        PKT_LEN_EXP: return word_t'(exp_len);
        RES_PKT_LEN: return word_t'(last_result.length);
        RES_PKT_TYPE: return word_t'(last_result.kind);
        RES_PAYLOAD_SUM: return word_t'(last_result.sum);
        RES_PAYLOAD_XOR: return word_t'(last_result.xor_value);
        ERR_FLAG: return {29'b0, last_result.chk_error,
                         last_result.type_error, last_result.length_error};
        default: begin
          if (!memory_valid[tr.address[4:2]])
            $fatal(1, "[MODEL_FAIL] read of unwritten SRAM addr=%03h", tr.address);
          return memory[tr.address[4:2]];
        end
      endcase
    endfunction

    function void check_cycle(input apb_observation tr);
      bit error_expected, start_expected;
      if (!tr.reset_n) begin
        reset_model();
        check_value("reset state", {29'b0, tr.busy, tr.done, tr.start}, 0);
        check_value("reset IRQ", word_t'(tr.irq), 0);
        check_value("reset result low", word_t'(tr.actual), 0);
        check_value("reset length", word_t'(tr.actual.length), 0);
        return;
      end
      busy_before_expected = active;
      done_before_expected = completed_state;
      start_expected = tr.access && tr.write && tr.address == CTRL &&
                       tr.wdata[1] && enable && !busy_before_expected;
      // M3 在本沿消费的是沿前 start 和配置；不是本沿刚写入 M1 的新值。
      if (tr.start_before && !tr.busy_before) begin
        if (active) $fatal(1, "[MODEL_FAIL] a frame is already active");
        foreach (memory_valid[i])
          if (!memory_valid[i]) $fatal(1, "[MODEL_FAIL] packet word %0d not loaded", i);
        expected = reference_model::predict(memory, mode, mask, exp_len);
        frame = new();
        starts++;
        frame.index = frames + 1;
        frame.first_after_reset = first_after_reset;
        first_after_reset = 0;
        frame.length = int'(memory[0][31:24]);
        frame.kind = memory[0][23:16];
        frame.mode = mode;
        frame.mask = mask;
        frame.expected_length = exp_len;
        frame.irq_enable = irq_enable;
        active = 1;
        completed_state = 0;
        check_value("accepted start busy/done", {30'b0, tr.busy, tr.done}, 2);
        check_value("start clears results", word_t'(tr.actual), 0);
        check_value("start clears length", word_t'(tr.actual.length), 0);
      end
      if (tr.access) begin
        accesses++;
        error_expected = (!is_csr(tr.address) && !is_memory(tr.address)) ||
          (tr.write && is_ro(tr.address)) ||
          (tr.write && is_memory(tr.address) && tr.busy_before);
        check_value("PREADY", word_t'(tr.ready), 1);
        check_value("PSLVERR", word_t'(tr.error), word_t'(error_expected));
        if (!tr.write && !error_expected)
          check_value($sformatf("APB read %03h", tr.address), tr.rdata, read_expected(tr));
        if (!tr.write && tr.address == STATUS) begin
          if (busy_before_expected) begin
            check_value("STATUS while busy", {30'b0, tr.rdata[1:0]}, 1);
            busy_reads++;
          end
          if (done_before_expected) begin
            check_value("STATUS while done", {30'b0, tr.rdata[1:0]}, 2);
            done_reads++;
          end
        end
        if (tr.write && is_memory(tr.address) && tr.busy_before) busy_rejects++;
        if (tr.write && !error_expected) begin
          case (tr.address)
            CTRL: enable = tr.wdata[0];
            CFG: begin mode = tr.wdata[0]; mask = tr.wdata[7:4]; end
            IRQ_EN: irq_enable = tr.wdata[1:0];
            IRQ_STA: pending &= ~tr.wdata[1:0];
            PKT_LEN_EXP: exp_len = tr.wdata[5:0];
            default: if (is_memory(tr.address)) begin
              memory[tr.address[4:2]] = tr.wdata;
              memory_valid[tr.address[4:2]] = 1;
            end
          endcase
        end
      end
      check_value("START W1P", word_t'(tr.start), word_t'(start_expected));
      if (tr.busy && tr.done) $fatal(1, "[STATE_FAIL] busy and done are both one");
      if (tr.done && !tr.done_before) begin
        if (!active) $fatal(1, "[MODEL_FAIL] completion without an accepted packet");
        check_value("result length", word_t'(tr.actual.length), word_t'(expected.length));
        check_value("result type", word_t'(tr.actual.kind), word_t'(expected.kind));
        check_value("payload sum", word_t'(tr.actual.sum), word_t'(expected.sum));
        check_value("payload XOR", word_t'(tr.actual.xor_value), word_t'(expected.xor_value));
        check_value("format/error flags", {28'b0, tr.actual.format_ok,
          tr.actual.chk_error, tr.actual.type_error, tr.actual.length_error},
          {28'b0, expected.format_ok, expected.chk_error, expected.type_error, expected.length_error});
        frames++;
        active = 0;
        completed_state = 1;
        frame.actual = tr.actual;
        if (coverage != null) coverage.sample_frame(frame);
        $display("[FRAME_PASS] test=%s seed=%0d frame=%0d len=%0d type=%02h mode=%0b mask=%h sum=%02h xor=%02h errors=%b",
          name, seed, frames, frame.length, frame.kind, frame.mode, frame.mask,
          tr.actual.sum, tr.actual.xor_value,
          {tr.actual.chk_error, tr.actual.type_error, tr.actual.length_error});
        if (irq_enable[0]) pending[0] = 1;
        if (irq_enable[1] && !expected.format_ok) pending[1] = 1;
      end
      if (tr.done && tr.done_before) begin
        check_value("DONE keeps results low", word_t'(tr.actual), word_t'(last_result));
        check_value("DONE keeps length", word_t'(tr.actual.length), word_t'(last_result.length));
      end
      check_value("BUSY holds until completion", word_t'(tr.busy), word_t'(active));
      check_value("DONE holds until next START", word_t'(tr.done), word_t'(completed_state));
      check_value("IRQ visible/preserved/W1C", word_t'(tr.irq), word_t'(|pending));
      if (tr.access && coverage != null) coverage.sample_access(tr);
      last_result = tr.actual;
    endfunction

    task run();
      apb_observation tr;
      forever begin
        observed.get(tr);
        if (tr == null) break;
        check_cycle(tr);
      end
      stopped = 1;
    endtask
  endclass

  class packet_driver;
    virtual ppa_if vif;
    mailbox #(packet_item) requests;
    int completed = 0, aborted = 0;

    function new(input virtual ppa_if vif, input mailbox #(packet_item) requests);
      this.vif = vif;
      this.requests = requests;
    endfunction

    task access(input bit write_it, input logic [11:0] address, input word_t value = 0,
                input bit expected_error = 0);
      word_t data;
      logic error;
      vif.transfer(write_it, address, value, data, error);
      if (error !== expected_error)
        $fatal(1, "[DRIVER_FAIL] addr=%03h expected_error=%b actual=%b", address, expected_error, error);
    endtask

    task read(input logic [11:0] address, output word_t data);
      logic error;
      vif.transfer(0, address, 0, data, error);
      if (error !== 0) $fatal(1, "[DRIVER_FAIL] unexpected read error addr=%03h", address);
    endtask

    task write(input logic [11:0] address, input word_t value);
      access(1, address, value);
    endtask

    task wait_completion();
      bit completed_poll;
      word_t value;
      completed_poll = 0;
      // 隔离竞争线程的归属，disable fork 只回收这次轮询的超时分支。
      fork
        begin
          fork
            begin
              while (!completed_poll) begin
                read(STATUS, value);
                completed_poll = value[1] === 1'b1;
              end
            end
            begin
              repeat (80) @(posedge vif.PCLK);
              $fatal(1, "[TIMEOUT] STATUS.done was not observed");
            end
          join_any
          disable fork;
        end
      join
    endtask

    task drive_packet(input packet_item pkt);
      words_t words;
      word_t data;
      int idle_cycles;
      pkt.pack_words(words);
      if (!std::randomize(idle_cycles) with { idle_cycles inside {[0:3]}; })
        $fatal(1, "[RANDOM_FAIL] inter-frame idle");
      repeat (idle_cycles) @(negedge vif.PCLK);
      write(CFG, {24'b0, pkt.mask, 3'b0, pkt.mode});
      write(PKT_LEN_EXP, word_t'(pkt.expected_length));
      write(IRQ_EN, word_t'(pkt.irq_enable));
      write(IRQ_STA, 3);
      foreach (words[i]) write(PKT_MEM + 12'(4 * i), words[i]);
      write(CTRL, 1);
      write(CTRL, 3);
      @(posedge vif.PCLK);
      #2ns;
      if (vif.busy !== 1 || vif.done !== 0)
        $fatal(1, "[DRIVER_FAIL] real M3 did not accept START");
      if (pkt.reset_during_busy) begin
        vif.reset_dut();
        read(STATUS, data);
        read(CFG, data);
        aborted++;
        completed++;
        $display("[FRAME_ABORT] reset accepted during PROCESS");
        return;
      end
      if (pkt.busy_probe) begin
        if (pkt.length != 32) $fatal(1, "[TEST_FAIL] busy probe needs the longest packet");
        access(1, PKT_MEM + 28, 'hDEAD_BEEF, 1);
        write(CTRL, 3);
        read(PKT_MEM + 28, data);
        if (data !== words[7]) $fatal(1, "[BUSY_FAIL] rejected write changed SRAM");
      end else begin
        read(STATUS, data);
        if (data[1:0] !== 1) $fatal(1, "[STATUS_FAIL] busy STATUS was not 01");
      end
      wait_completion();
      read(STATUS, data);
      read(RES_PKT_LEN, data);
      read(RES_PKT_TYPE, data);
      read(RES_PAYLOAD_SUM, data);
      read(RES_PAYLOAD_XOR, data);
      read(ERR_FLAG, data);
      read(IRQ_STA, data);
      write(IRQ_STA, 0);
      read(IRQ_STA, data);
      if (pkt.partial_clear) begin
        write(IRQ_STA, 1);
        read(IRQ_STA, data);
        if (data[1] && vif.irq !== 1) $fatal(1, "[IRQ_FAIL] error pending lost");
        write(IRQ_STA, 2);
      end else write(IRQ_STA, 3);
      read(IRQ_STA, data);
      if (data !== 0 || vif.irq !== 0) $fatal(1, "[IRQ_FAIL] W1C did not clear IRQ");
      repeat (2) @(negedge vif.PCLK);
      if (pkt.busy_probe) read(PKT_MEM + 28, data);
      completed++;
    endtask

    task run();
      packet_item pkt;
      forever begin
        requests.get(pkt);
        if (pkt == null) break;
        drive_packet(pkt);
      end
    endtask
  endclass

  typedef class base_test;
  class environment;
    virtual ppa_if vif;
    mailbox #(packet_item) requests;
    mailbox #(apb_observation) observed;
    packet_driver driver;
    apb_monitor monitor;
    scoreboard scb;
    coverage_sink coverage;
    string name;
    int seed;

    function new(input virtual ppa_if vif, input string name, input int seed);
      this.vif = vif;
      this.name = name;
      this.seed = seed;
      requests = new(2);
      observed = new();
      driver = new(vif, requests);
      monitor = new(vif, observed);
      scb = new(observed, name, seed);
    endfunction
    extern task run(input base_test test);
  endclass

  class base_test;
    environment env;
    int expected_frames = 0;
    function new(input environment env);
      this.env = env;
    endfunction
    task submit(input packet_item pkt);
      expected_frames++;
      env.requests.put(pkt);
    endtask
    virtual task build_packets();
      packet_item pkt = new();
      pkt.configure(8, 2);
      submit(pkt);
    endtask
  endclass

  class frames_test extends base_test;
    function new(input environment env); super.new(env); endfunction
    virtual task build_packets();
      packet_item pkt;
      pkt = new(); pkt.configure(8, 1); submit(pkt);
      pkt = new(); pkt.configure(13, 8); submit(pkt);
    endtask
  endclass

  class status_test extends base_test;
    function new(input environment env); super.new(env); endfunction
    virtual task build_packets();
      packet_item pkt = new();
      pkt.configure(32, 4);
      submit(pkt);
    endtask
  endclass

  class busy_test extends base_test;
    function new(input environment env); super.new(env); endfunction
    virtual task build_packets();
      packet_item pkt = new();
      pkt.configure(32, 2);
      pkt.busy_probe = 1;
      submit(pkt);
    endtask
  endclass

  class irq_test extends base_test;
    function new(input environment env); super.new(env); endfunction
    virtual task build_packets();
      packet_item pkt;
      pkt = new(); pkt.configure(8, 1); pkt.irq_enable = 0; submit(pkt);
      pkt = new(); pkt.configure(12, 2); pkt.irq_enable = 1; submit(pkt);
      pkt = new(); pkt.configure(8, 4); pkt.bad_checksum = 1;
      pkt.partial_clear = 1; submit(pkt);
    endtask
  endclass

  class random_test extends base_test;
    function new(input environment env); super.new(env); endfunction
    virtual task build_packets();
      packet_item pkt;
      repeat (12) begin
        pkt = new();
        if (!pkt.randomize() with { mask == 15; expected_length == 0; irq_enable == 3; })
          $fatal(1, "[RANDOM_FAIL] packet constraints");
        $display("[RANDOM_PACKET] seed=%0d length=%0d kind=%02h mode=%0b first_payload=%02h",
          env.seed, pkt.length, pkt.kind, pkt.mode, pkt.payload.size() ? pkt.payload[0] : 0);
        submit(pkt);
      end
    endtask
  endclass

  class extension_test extends base_test;
    function new(input environment env); super.new(env); endfunction
    virtual task build_packets();
      packet_item pkt;
      pkt = new(); pkt.configure(7, 4); pkt.payload = '{8'hFE, 8'h05, 8'h03}; submit(pkt);
      pkt = new(); pkt.configure(13, 8);
      foreach (pkt.payload[i]) pkt.payload[i] = 'hAA;
      submit(pkt);
      pkt = new(); pkt.configure(12, 2); pkt.expected_length = 8; submit(pkt);
      pkt = new();
      pkt.legal_length.constraint_mode(0);
      pkt.legal_kind.constraint_mode(0);
      pkt.legal_checksum.constraint_mode(0);
      if (!pkt.randomize() with { length == 3; kind == 3; bad_checksum == 1;
        mode == 1; mask == 15; expected_length == 0; irq_enable == 3; })
        $fatal(1, "[RANDOM_FAIL] explicitly relaxed negative constraints");
      submit(pkt);
    endtask
  endclass

  class csr_test extends base_test;
    function new(input environment env); super.new(env); endfunction
    virtual task build_packets();
      word_t data, pattern;
      env.driver.read(CTRL, data);
      env.driver.read(CFG, data);
      env.driver.read(IRQ_EN, data);
      env.driver.read(IRQ_STA, data);
      env.driver.read(PKT_LEN_EXP, data);
      env.driver.read(STATUS, data);
      env.driver.read(ERR_FLAG, data);
      env.driver.read(RES_PKT_LEN, data);
      env.driver.read(RES_PKT_TYPE, data);
      env.driver.read(RES_PAYLOAD_SUM, data);
      env.driver.read(RES_PAYLOAD_XOR, data);
      for (int i = 0; i < 4; i++) begin
        case (i)
          0: pattern = 0;
          1: pattern = '1;
          2: pattern = 'hAAAA_AAAA;
          default: pattern = $urandom();
        endcase
        env.driver.write(CFG, pattern); env.driver.read(CFG, data);
        env.driver.write(PKT_LEN_EXP, pattern); env.driver.read(PKT_LEN_EXP, data);
        env.driver.write(IRQ_EN, pattern); env.driver.read(IRQ_EN, data);
      end
      env.driver.write(CTRL, 2);
      env.driver.read(CTRL, data);
      env.driver.write(CTRL, 1);
      env.driver.read(CTRL, data);
      env.driver.write(CTRL, 0);
      env.driver.read(CTRL, data);
    endtask
  endclass

  class memory_test extends base_test;
    function new(input environment env); super.new(env); endfunction
    virtual task build_packets();
      word_t data;
      for (int i = 0; i < 8; i++)
        env.driver.write(PKT_MEM + 12'(4 * i), 'h1020_3040 ^ word_t'(i));
      for (int i = 0; i < 8; i++) env.driver.read(PKT_MEM + 12'(4 * i), data);
      env.driver.write(PKT_MEM, 0);
      env.driver.write(PKT_MEM + 28, '1);
      env.driver.read(PKT_MEM, data);
      env.driver.read(PKT_MEM + 28, data);
    endtask
  endclass

  class errors_test extends base_test;
    function new(input environment env); super.new(env); endfunction
    task reject_write(input logic [11:0] address);
      word_t data;
      env.driver.access(1, address, '1, 1);
      env.driver.read(CTRL, data);
      env.driver.read(CFG, data);
      env.driver.read(IRQ_EN, data);
      env.driver.read(PKT_LEN_EXP, data);
      env.driver.read(STATUS, data);
      env.driver.read(PKT_MEM, data);
    endtask
    virtual task build_packets();
      packet_item pkt;
      env.driver.write(PKT_MEM, 'h1122_3344);
      env.driver.access(0, 'h02C, 0, 1);
      reject_write('h060);
      env.driver.access(0, 'h041, 0, 1);
      env.driver.access(0, 'hFFF, 0, 1);
      reject_write('hFFF);
      reject_write(STATUS);
      reject_write(RES_PKT_LEN);
      reject_write(RES_PKT_TYPE);
      reject_write(RES_PAYLOAD_SUM);
      reject_write(RES_PAYLOAD_XOR);
      reject_write(ERR_FLAG);
      pkt = new(); pkt.configure(3, 1); submit(pkt);
      pkt = new(); pkt.configure(33, 1); submit(pkt);
      pkt = new(); pkt.configure(8, 3); submit(pkt);
      pkt = new(); pkt.configure(8, 1); pkt.mask = 'hE; submit(pkt);
      pkt = new(); pkt.configure(8, 2); pkt.bad_checksum = 1; submit(pkt);
      pkt = new(); pkt.configure(8, 2); pkt.bad_checksum = 1; pkt.mode = 0; submit(pkt);
    endtask
  endclass

  function automatic base_test create_test(input string name, input environment env);
    base_test test;
    frames_test frames_case;
    status_test status_case;
    busy_test busy_case;
    irq_test irq_case;
    random_test random_case;
    extension_test extension_case;
    csr_test csr_case;
    memory_test memory_case;
    errors_test errors_case;
    case (name)
      "smoke": begin test = new(env); end
      "frames": begin frames_case = new(env); test = frames_case; end
      "status": begin status_case = new(env); test = status_case; end
      "busy": begin busy_case = new(env); test = busy_case; end
      "irq": begin irq_case = new(env); test = irq_case; end
      "random": begin random_case = new(env); test = random_case; end
      "extension": begin extension_case = new(env); test = extension_case; end
      "csr": begin csr_case = new(env); test = csr_case; end
      "memory": begin memory_case = new(env); test = memory_case; end
      "errors": begin errors_case = new(env); test = errors_case; end
      default: $fatal(1, "[UNKNOWN_TEST] TESTNAME=%s", name);
    endcase
    return test;
  endfunction

  task environment::run(input base_test test);
    scb.coverage = coverage;
    $display("[BEGIN] test=%s seed=%0d branch=SV", name, seed);
    fork
      monitor.run();
      scb.run();
    join_none
    vif.reset_dut();
    fork
      begin test.build_packets(); requests.put(null); end
      driver.run();
    join
    repeat (2) @(negedge vif.PCLK);
    monitor.stop_requested = 1;
    wait fork;
    scb.check_value("accepted frame count", scb.starts, test.expected_frames);
    scb.check_value("checked or reset-aborted frame count", scb.frames + scb.aborted, test.expected_frames);
    scb.check_value("reset-aborted frame count", scb.aborted, driver.aborted);
    scb.check_value("driver frame count", driver.completed, test.expected_frames);
    scb.check_value("mailbox drained", observed.num() + requests.num(), 0);
    scb.check_value("no unfinished frame", word_t'(scb.active), 0);
    if (!scb.stopped || scb.accesses == 0)
      $fatal(1, "[END_FAIL] scb not drained or no accepted APB access");
    if (name == "busy" && scb.busy_rejects == 0)
      $fatal(1, "[VACUOUS_FAIL] busy write did not occur while busy");
    if ((name == "smoke" || name == "frames" || name == "status") &&
        (scb.busy_reads == 0 || scb.done_reads == 0))
      $fatal(1, "[VACUOUS_FAIL] STATUS was not checked in both phases");
    if (coverage != null) coverage.report();
    $display("[PASS] test=%s seed=%0d frames=%0d aborted=%0d checks=%0d accesses=%0d busy_reads=%0d done_reads=%0d busy_rejects=%0d",
      name, seed, scb.frames, scb.aborted, scb.checks, scb.accesses,
      scb.busy_reads, scb.done_reads, scb.busy_rejects);
  endtask
endpackage
