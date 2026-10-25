# 配置显示项不改变设计；run.do 另用 log 保存波形历史。
view wave
delete wave *
add wave -group CLOCK /tb_lab1/PCLK /tb_lab1/PRESETn
add wave -group APB /tb_lab1/apb/PSEL /tb_lab1/apb/PENABLE /tb_lab1/apb/PWRITE
add wave -group APB -radix hexadecimal /tb_lab1/apb/PADDR /tb_lab1/apb/PWDATA /tb_lab1/apb/PRDATA
add wave -group APB /tb_lab1/apb/PREADY /tb_lab1/apb/PSLVERR
add wave -group CONTROL /tb_lab1/enable_o /tb_lab1/start_o /tb_lab1/algo_mode_o
add wave -group CONTROL -radix unsigned /tb_lab1/type_mask_o /tb_lab1/exp_pkt_len_o
add wave -group M2_WRITE /tb_lab1/pkt_mem_we /tb_lab1/pkt_mem_re
add wave -group M2_WRITE -radix unsigned /tb_lab1/pkt_mem_addr
add wave -group M2_WRITE -radix hexadecimal /tb_lab1/pkt_mem_wdata
add wave -group M2_READ /tb_lab1/proc_rd_en
add wave -group M2_READ -radix unsigned /tb_lab1/proc_rd_addr
add wave -group M2_READ -radix hexadecimal /tb_lab1/proc_rd_data /tb_lab1/pkt_mem_rdata
add wave -group RESULTS -radix unsigned /tb_lab1/res_pkt_len_i
add wave -group RESULTS -radix hexadecimal /tb_lab1/res_pkt_type_i /tb_lab1/res_payload_sum_i /tb_lab1/res_payload_xor_i
add wave -group IRQ /tb_lab1/done_i /tb_lab1/done_irq_en_o /tb_lab1/err_irq_en_o
add wave -group IRQ /tb_lab1/length_error_i /tb_lab1/type_error_i /tb_lab1/chk_error_i
add wave -group IRQ /tb_lab1/m1/done_irq /tb_lab1/m1/err_irq /tb_lab1/irq_o
add wave -group IRQ_SAVED /tb_lab1/m1/previous_done /tb_lab1/m1/done_irq_saved /tb_lab1/m1/err_irq_saved
add wave -group CHECK /tb_lab1/test_done
