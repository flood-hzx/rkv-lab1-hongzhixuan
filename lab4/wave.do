# DUT/interface signals relevant to end-to-end APB, FSM, result and IRQ paths.
view wave
delete wave *
add wave -group CLOCK /tb_lab4/PCLK /tb_lab4/bus/PRESETn
add wave -group APB /tb_lab4/bus/PSEL /tb_lab4/bus/PENABLE /tb_lab4/bus/PWRITE
add wave -group APB -radix hexadecimal /tb_lab4/bus/PADDR /tb_lab4/bus/PWDATA /tb_lab4/bus/PRDATA
add wave -group APB /tb_lab4/bus/PREADY /tb_lab4/bus/PSLVERR
add wave -group M3 /tb_lab4/bus/start /tb_lab4/bus/busy /tb_lab4/bus/done
add wave -group M3 /tb_lab4/dut/m3/state /tb_lab4/dut/m3/busy_o /tb_lab4/dut/m3/done_o
add wave -group RESULTS /tb_lab4/bus/format_ok /tb_lab4/bus/length_error /tb_lab4/bus/type_error /tb_lab4/bus/chk_error
add wave -group RESULTS -radix unsigned /tb_lab4/bus/res_len
add wave -group RESULTS -radix hexadecimal /tb_lab4/bus/res_type /tb_lab4/bus/res_sum /tb_lab4/bus/res_xor
add wave -group IRQ /tb_lab4/bus/irq /tb_lab4/dut/m1/done_irq /tb_lab4/dut/m1/err_irq
add wave -group TEST /tb_lab4/test_done
