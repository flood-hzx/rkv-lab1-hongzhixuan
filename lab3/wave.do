# DUT/interface signals relevant to end-to-end APB and processing.
view wave
delete wave *
add wave -group CLOCK /tb_lab3/PCLK /tb_lab3/bus/PRESETn
add wave -group APB /tb_lab3/bus/PSEL /tb_lab3/bus/PENABLE /tb_lab3/bus/PWRITE
add wave -group APB -radix hexadecimal /tb_lab3/bus/PADDR /tb_lab3/bus/PWDATA /tb_lab3/bus/PRDATA
add wave -group APB /tb_lab3/bus/PREADY /tb_lab3/bus/PSLVERR
add wave -group M3 /tb_lab3/bus/start /tb_lab3/bus/busy /tb_lab3/bus/done
add wave -group M3 /tb_lab3/dut/m3/state /tb_lab3/dut/m3/busy_o /tb_lab3/dut/m3/done_o
add wave -group RESULTS /tb_lab3/bus/format_ok /tb_lab3/bus/length_error /tb_lab3/bus/type_error /tb_lab3/bus/chk_error
add wave -group RESULTS -radix unsigned /tb_lab3/bus/res_len
add wave -group RESULTS -radix hexadecimal /tb_lab3/bus/res_type /tb_lab3/bus/res_sum /tb_lab3/bus/res_xor
add wave -group IRQ /tb_lab3/bus/irq /tb_lab3/dut/m1/done_irq /tb_lab3/dut/m1/err_irq
add wave -group TEST /tb_lab3/test_done
