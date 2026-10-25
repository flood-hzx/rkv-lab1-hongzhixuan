# PPA-Lite当前交付版本

四个正式目录为lab1、lab2、lab3、lab4。它们只保留当前源码、配套脚本、当前说明和该版本重新生成的验收证据，按相邻目录结构使用。

| 目录 | 当前职责 | 说明入口 |
| --- | --- | --- |
| lab1 | M1 APB/CSR/IRQ、M2同步SRAM、基础独立TB | [README](lab1/README.md)、[验收说明](lab1/验收说明.md) |
| lab2 | M3处理核、独立数组模型与六个测试类 | [README](lab2/README.md)、[验收说明](lab2/验收说明.md) |
| lab3 | 纯连线Top、真实端到端分层SV验证 | [README](lab3/README.md)、[验收说明](lab3/验收说明.md) |
| lab4 | 全系统回归、功能与代码覆盖率闭环 | [README](lab4/README.md)、[验收说明](lab4/验收说明.md) |

从四个目录共同上级运行：

    make -C lab1 smoke
    make -C lab1 regress
    make -C lab2 regress
    make -C lab3 regress
    make -C lab4 regress

Lab3/4直接引用同级Lab1/2的正式RTL，Lab4另引用Lab3环境。四个目录一起交付即可保留这些依赖；Lab1和Lab2也能分别独立验证。工具为QuestaSim/vlog/vcover 2021.1与GNU Make 3.81，选择实验文档v1.03允许的纯SV分支。

Lab4覆盖率入口：

    make -C lab4 cov COVSET=baseline
    make -C lab4 mergecov COVSET=baseline
    make -C lab4 cov COVSET=final
    make -C lab4 mergecov COVSET=final
    make -C lab4 verdicov COVSET=final

baseline和final是同一当前源码的初始测试集与补测后测试集，用于展示覆盖率闭环，不是两套RTL版本。原始与过滤数据库、文本/HTML、完整日志及Excel登记均在Lab4目录内。过滤后的技术覆盖率仍须助教确认。

各Lab验收说明和TESTPLAN列出当前实际命令、test/seed、结果、方法学和扩展目的。重跑请使用自动RUN_ID/MERGE_ID或新ID；不能覆盖归档证据。缓存可重建，交付版.gitignore只忽略缓存和临时文件，必要结果不会因默认规则漏交。

RTL、接口、测试类和TB保持原有功能。现场代码串讲、分工与正式评分不能由工具结果替代。
