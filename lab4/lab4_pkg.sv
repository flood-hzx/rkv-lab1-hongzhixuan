`timescale 1ns/1ps

package lab4_pkg;
  import lab3_pkg::*;

  // 功能覆盖只接收 scoreboard 已确认正确的实际观察，不在这里重算/代替检查结果。
  class coverage_collector extends coverage_sink;
    int unsigned frame_samples;
    int unsigned access_samples;
    int unsigned previous_frame_index;
    bit have_previous_frame;

    covergroup frame_cg with function sample(
      input int unsigned pkt_length,
      input bit [7:0] pkt_kind,
      input bit pkt_mode,
      input bit [3:0] pkt_mask,
      input bit [5:0] expected_length,
      input bit [1:0] irq_enable,
      input int unsigned permission_class,
      input int unsigned expected_class,
      input int unsigned outcome_class,
      input int unsigned errors_class,
      input int unsigned sequence_class
    );
      cp_length: coverpoint pkt_length {
        bins below4 = {[0:3]};
        bins min4 = {4};
        bins middle = {[5:31]};
        bins max32 = {32};
        bins above32 = {[33:255]};
      }
      cp_kind: coverpoint pkt_kind {
        bins type_01 = {8'h01};
        bins type_02 = {8'h02};
        bins type_04 = {8'h04};
        bins type_08 = {8'h08};
        bins invalid = {8'h00, 8'h03, [8'h05:8'h07], [8'h09:8'hff]};
      }
      cp_mode: coverpoint pkt_mode {
        bins checksum_enabled = {1'b1};
        bins checksum_bypassed = {1'b0};
      }
      cp_mask: coverpoint pkt_mask {
        bins all_types_allowed = {4'hf};
        bins no_types_allowed = {4'h0};
        bins partial_mask = {[4'h1:4'he]};
      }
      cp_permission: coverpoint permission_class {
        bins invalid_type = {0};
        bins allowed_by_mask = {1};
        bins rejected_by_mask = {2};
      }
      cp_expected_length: coverpoint expected_class {
        bins not_configured = {0};
        bins matches_packet = {1};
        bins differs_from_packet = {2};
      }
      cp_irq_enable: coverpoint irq_enable {
        bins disabled = {2'b00};
        bins done_only = {2'b01};
        bins error_only = {2'b10};
        bins done_and_error = {2'b11};
      }
      cp_outcome: coverpoint outcome_class {
        bins pass = {0};
        bins error = {1};
      }
      cp_error_combination: coverpoint errors_class {
        bins pass = {0};
        bins length_only = {1};
        bins type_only = {2};
        bins checksum_only = {3};
        bins multiple_errors = {4};
        illegal_bins inconsistent_result = {5};
      }
      cp_sequence: coverpoint sequence_class {
        bins first_frame = {0};
        bins consecutive_frame = {1};
        illegal_bins index_gap = {2};
      }
      length_by_outcome: cross cp_length, cp_outcome {
        // 越界长度的正常通过不符合规格，不要求覆盖这两个不可达组合。
        ignore_bins below4_pass = binsof(cp_length) intersect {[0:3]} &&
                                  binsof(cp_outcome) intersect {0};
        ignore_bins above32_pass = binsof(cp_length) intersect {[33:255]} &&
                                   binsof(cp_outcome) intersect {0};
      }
    endgroup

    covergroup access_cg with function sample(
      input int unsigned target_class,
      input bit is_write,
      input bit response_error,
      input int unsigned busy_protection_class,
      input int unsigned irq_operation_class,
      input int unsigned irq_after_clear_class
    );
      cp_target: coverpoint target_class {
        bins ctrl = {0};
        bins cfg_register = {1};
        bins irq_enable = {2};
        bins irq_status = {3};
        bins expected_length = {4};
        bins packet_memory = {5};
        bins result_or_status = {6};
        bins other = {7};
      }
      cp_direction: coverpoint is_write {
        bins read = {0};
        bins write = {1};
      }
      cp_response: coverpoint response_error {
        bins accepted = {0};
        bins rejected = {1};
      }
      cp_busy_protection: coverpoint busy_protection_class {
        bins not_a_memory_write = {0};
        bins idle_memory_write = {1};
        bins busy_write_rejected = {2};
        illegal_bins busy_write_accepted_unexpectedly = {3};
      }
      cp_irq_operation: coverpoint irq_operation_class {
        bins unrelated_access = {0};
        bins enable_none = {1};
        bins enable_done = {2};
        bins enable_error = {3};
        bins enable_both = {4};
        bins clear_none = {5};
        bins clear_done = {6};
        bins clear_error = {7};
        bins clear_both = {8};
      }
      cp_irq_after_clear: coverpoint irq_after_clear_class {
        bins not_a_clear = {0};
        bins irq_deasserted = {1};
        bins another_irq_remains = {2};
      }
    endgroup

    function new();
      frame_cg = new();
      access_cg = new();
      frame_samples = 0;
      access_samples = 0;
      have_previous_frame = 0;
    endfunction

    function automatic int unsigned classify_type_permission(
      input bit [7:0] pkt_kind, input bit [3:0] pkt_mask
    );
      case (pkt_kind)
        8'h01: return pkt_mask[0] ? 1 : 2;
        8'h02: return pkt_mask[1] ? 1 : 2;
        8'h04: return pkt_mask[2] ? 1 : 2;
        8'h08: return pkt_mask[3] ? 1 : 2;
        default: return 0;
      endcase
    endfunction

    function automatic int unsigned classify_errors(input result_t actual);
      case ({actual.length_error, actual.type_error, actual.chk_error})
        3'b000: return actual.format_ok ? 0 : 5;
        3'b100: return 1;
        3'b010: return 2;
        3'b001: return 3;
        default: return actual.format_ok ? 5 : 4;
      endcase
    endfunction

    virtual function void sample_frame(input frame_observation frame);
      bit [7:0] pkt_kind;
      bit [3:0] pkt_mask;
      int unsigned permission_class;
      int unsigned expected_class;
      int unsigned outcome_class;
      int unsigned errors_class;
      int unsigned sequence_class;

      pkt_kind = frame.kind;
      pkt_mask = frame.mask;
      permission_class = classify_type_permission(pkt_kind, pkt_mask);
      if (frame.expected_length == 0)
        expected_class = 0;
      else if (frame.expected_length == frame.length)
        expected_class = 1;
      else
        expected_class = 2;

      outcome_class = frame.actual.format_ok ? 0 : 1;
      errors_class = classify_errors(frame.actual);
      if (!have_previous_frame || frame.first_after_reset)
        sequence_class = 0;
      else if (frame.index == previous_frame_index + 1)
        sequence_class = 1;
      else
        sequence_class = 2;

      frame_cg.sample(frame.length, pkt_kind, frame.mode, pkt_mask,
                      frame.expected_length, frame.irq_enable,
                      permission_class, expected_class, outcome_class,
                      errors_class, sequence_class);
      frame_samples++;
      previous_frame_index = frame.index;
      have_previous_frame = 1;

    endfunction

    virtual function void sample_access(input apb_observation tr);
      bit [11:0] address;
      bit [31:0] write_data;
      int unsigned target_class;
      int unsigned protection_class;
      int unsigned irq_operation_class;
      int unsigned irq_clear_result;

      address = tr.address;
      write_data = tr.wdata;
      if (address == 12'h000)
        target_class = 0;
      else if (address == 12'h004)
        target_class = 1;
      else if (address == 12'h00c)
        target_class = 2;
      else if (address == 12'h010)
        target_class = 3;
      else if (address == 12'h014)
        target_class = 4;
      else if (address >= 12'h040 && address <= 12'h05c && address[1:0] == 0)
        target_class = 5;
      else if (address inside {STATUS, RES_PKT_LEN, RES_PKT_TYPE,
                              RES_PAYLOAD_SUM, RES_PAYLOAD_XOR, ERR_FLAG})
        target_class = 6;
      else
        target_class = 7;

      protection_class = 0;
      if (target_class == 5 && tr.write)
        protection_class = tr.busy_before ? (tr.error ? 2 : 3) : 1;

      irq_operation_class = 0;
      irq_clear_result = 0;
      if (tr.write && address == 12'h00c) begin
        case (write_data[1:0])
          2'b00: irq_operation_class = 1;
          2'b01: irq_operation_class = 2;
          2'b10: irq_operation_class = 3;
          2'b11: irq_operation_class = 4;
        endcase
      end else if (tr.write && address == 12'h010) begin
        case (write_data[1:0])
          2'b00: irq_operation_class = 5;
          2'b01: irq_operation_class = 6;
          2'b10: irq_operation_class = 7;
          2'b11: irq_operation_class = 8;
        endcase
        if (write_data[1:0] != 0) irq_clear_result = tr.irq ? 2 : 1;
      end

      access_cg.sample(target_class, tr.write, tr.error, protection_class,
                       irq_operation_class, irq_clear_result);
      access_samples++;
    endfunction

    function void report_point(input string group_name, input string point_name,
                               input real percent);
      $display("[COV_POINT] group=%s point=%s coverage=%0.2f%%", group_name, point_name, percent);
      if (percent < 100.0)
        $display("[COV_GAP] group=%s point=%s coverage=%0.2f%%", group_name, point_name, percent);
    endfunction

    virtual function void report();
      real frame_percent;
      real access_percent;

      frame_percent = frame_cg.get_coverage();
      access_percent = access_cg.get_coverage();
      $display("[FUNCTIONAL_COVERAGE] frame_cg=%0.2f%% access_cg=%0.2f%% total_mean=%0.2f%% frames=%0d accesses=%0d",
               frame_percent, access_percent, (frame_percent + access_percent) / 2.0,
               frame_samples, access_samples);
      report_point("frame", "length", frame_cg.cp_length.get_coverage());
      report_point("frame", "kind", frame_cg.cp_kind.get_coverage());
      report_point("frame", "mode", frame_cg.cp_mode.get_coverage());
      report_point("frame", "mask", frame_cg.cp_mask.get_coverage());
      report_point("frame", "type_permission", frame_cg.cp_permission.get_coverage());
      report_point("frame", "expected_length", frame_cg.cp_expected_length.get_coverage());
      report_point("frame", "irq_enable", frame_cg.cp_irq_enable.get_coverage());
      report_point("frame", "outcome", frame_cg.cp_outcome.get_coverage());
      report_point("frame", "error_combination", frame_cg.cp_error_combination.get_coverage());
      report_point("frame", "sequence", frame_cg.cp_sequence.get_coverage());
      report_point("frame", "length_by_outcome", frame_cg.length_by_outcome.get_coverage());
      report_point("access", "address_target", access_cg.cp_target.get_coverage());
      report_point("access", "direction", access_cg.cp_direction.get_coverage());
      report_point("access", "response", access_cg.cp_response.get_coverage());
      report_point("access", "busy_protection", access_cg.cp_busy_protection.get_coverage());
      report_point("access", "irq_operation", access_cg.cp_irq_operation.get_coverage());
      report_point("access", "irq_after_clear", access_cg.cp_irq_after_clear.get_coverage());
      if (frame_samples == 0) $display("[COV_GAP] group=frame no checked frame observations sampled");
      if (access_samples == 0) $display("[COV_GAP] group=access no checked APB ACCESS observations sampled");
      $display("[COV_NOTE] length_outcome ignores below-4/pass and above-32/pass: these outcomes violate the specified length-error rule and are unreachable.");
      $display("[COV_NOTE] inconsistent result, frame index gap and accepted busy memory write are illegal bins; the scoreboard would fail them before coverage sampling.");
    endfunction
  endclass

  // 这组少量定向帧用于证明功能 bin 可由“提交→驱动→检查后观察”实际命中。
  class coverage_test extends base_test;
    function new(input environment env);
      super.new(env);
    endfunction

    task automatic send_case(
      input int unsigned requested_length,
      input bit [7:0] requested_kind,
      input bit requested_mode,
      input bit [3:0] requested_mask,
      input bit [5:0] requested_expected_length,
      input bit [1:0] requested_irq_enable,
      input bit requested_bad_checksum = 0,
      input bit requested_busy_probe = 0,
      input bit requested_partial_clear = 0
    );
      packet_item pkt;
      pkt = new();
      if (requested_length < 4 || requested_length > 32)
        pkt.legal_length.constraint_mode(0);
      if (!(requested_kind inside {8'h01, 8'h02, 8'h04, 8'h08}))
        pkt.legal_kind.constraint_mode(0);
      if (requested_bad_checksum)
        pkt.legal_checksum.constraint_mode(0);
      if (!pkt.randomize() with {
            length == local::requested_length;
            kind == local::requested_kind;
            mode == local::requested_mode;
            mask == local::requested_mask;
            expected_length == local::requested_expected_length;
            irq_enable == local::requested_irq_enable;
            bad_checksum == local::requested_bad_checksum;
          })
        $fatal(1, "[RANDOMIZE_FAIL] coverage_test len=%0d kind=%02x", requested_length, requested_kind);
      pkt.busy_probe = requested_busy_probe;
      pkt.partial_clear = requested_partial_clear;
      submit(pkt);
    endtask

    virtual task build_packets();
      send_case(4,  8'h01, 1, 4'hf, 6'd4,  2'b01); // 最小合法包、校验开启、期望长度匹配。
      send_case(4,  8'h02, 0, 4'hf, 6'd8,  2'b11); // 最小包以期望长度不符产生可达错误交叉。
      send_case(16, 8'h02, 0, 4'hf, 6'd16, 2'b10); // 中间长度、校验旁路、类型 02 合法。
      send_case(32, 8'h04, 1, 4'hf, 6'd32, 2'b11, 0, 1, 1); // 最大包，开启 busy 写保护探测及 IRQ 清除观察。
      send_case(32, 8'h04, 1, 4'hf, 6'd0,  2'b10, 1); // 最大包坏校验，命中 max32/error 合法交叉。
      send_case(3,  8'h08, 1, 4'hf, 6'd0,  2'b01); // 下溢长度；关闭长度约束后仍由 payload_size 约束产生零负载。
      send_case(33, 8'h01, 1, 4'hf, 6'd0,  2'b10); // 上溢长度，验证不可能被归为通过。
      send_case(8,  8'h03, 1, 4'hf, 6'd8,  2'b00); // 非法类型，关闭类型合法约束。
      send_case(8,  8'h01, 0, 4'he, 6'd8,  2'b01, 0, 0, 1); // type01 被 mask 屏蔽，配置为部分允许。
      send_case(12, 8'h02, 1, 4'h0, 6'd12, 2'b10); // 全屏蔽配置，type02 被拒绝。
      send_case(12, 8'h02, 0, 4'hf, 6'd8,  2'b11); // 合法范围但期望长度不一致，单独命中长度错误。
      send_case(8,  8'h02, 1, 4'hf, 6'd8,  2'b01, 1); // 坏校验、校验开启，命中校验错误。
      send_case(8,  8'h04, 0, 4'hf, 6'd8,  2'b00, 1); // 同类坏校验在旁路模式下不产生校验错误。
      send_case(8,  8'h03, 1, 4'h0, 6'd12, 2'b11, 1, 0, 1); // 长度、类型、校验多错并存，仍由 scoreboard 检查。
    endtask
  endclass

  // 原始报告缺口：复位转移、头字段高位、APB同步读数据的下降跳变。
  class closure_test extends base_test;
    function new(input environment env); super.new(env); endfunction
    virtual task build_packets();
      packet_item pkt;
      word_t data;
      env.driver.write(PKT_MEM, '1);
      env.driver.read(PKT_MEM, data);
      env.driver.write(PKT_MEM, 0);
      env.driver.read(PKT_MEM, data);
      pkt = new(); pkt.configure(255, 255);
      pkt.mask = 0; pkt.expected_length = 63; pkt.irq_enable = 2;
      submit(pkt);
      pkt = new(); pkt.configure(0, 1); pkt.irq_enable = 0; submit(pkt);
      pkt = new(); pkt.configure(32, 8); pkt.expected_length = 32;
      pkt.busy_probe = 1; submit(pkt);
      pkt = new(); pkt.configure(8, 1); pkt.mode = 0;
      foreach (pkt.payload[i]) pkt.payload[i] = 'hFF;
      submit(pkt);
      while (env.driver.completed < 4) @(negedge env.vif.PCLK);
      env.vif.reset_dut();
      env.driver.read(STATUS, data);
      env.driver.read(CFG, data);
      pkt = new(); pkt.configure(32, 4); pkt.reset_during_busy = 1;
      submit(pkt);
    endtask
  endclass
endpackage
