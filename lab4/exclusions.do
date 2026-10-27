# Apply only to a filtered UCDB copy; course approval is not implied.
coverage exclude -scope /tb_lab4/dut/m3 -linerange 174 -code {bs} -reason EOTH -comment {C01: unreachable illegal-state recovery}
coverage exclude -togglenode PREADY -scope /tb_lab4/dut -reason EOTH -comment {C02: PREADY is tied to one}
coverage exclude -togglenode PREADY -scope /tb_lab4/dut/m1 -reason EOTH -comment {C03: PREADY is tied to one}
