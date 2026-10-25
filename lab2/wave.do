view wave
delete wave *
add wave -group CLOCK /tb_lab2/clk /tb_lab2/bus/rst_n
add wave -group CONTROL /tb_lab2/bus/start /tb_lab2/bus/algo_mode /tb_lab2/bus/type_mask /tb_lab2/bus/exp_pkt_len
add wave -group FSM /tb_lab2/m3/state /tb_lab2/bus/busy /tb_lab2/bus/done
add wave -group MEMORY /tb_lab2/bus/mem_rd_en /tb_lab2/bus/mem_rd_addr
# Saved WLFs contain the observed read interface, not the complete TB memory array.
add wave -group MEMORY -radix hexadecimal /tb_lab2/bus/mem_rd_data
add wave -group PIPELINE /tb_lab2/m3/response_valid /tb_lab2/m3/response_index
add wave -group RESULTS -radix hexadecimal /tb_lab2/bus/res_pkt_len /tb_lab2/bus/res_pkt_type /tb_lab2/bus/res_payload_sum /tb_lab2/bus/res_payload_xor
add wave -group ERRORS /tb_lab2/bus/format_ok /tb_lab2/bus/length_error /tb_lab2/bus/type_error /tb_lab2/bus/chk_error
add wave -group CHECKS /tb_lab2/starts /tb_lab2/completions /tb_lab2/test_done
