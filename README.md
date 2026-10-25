# PPA-Lite：Lab1–2 当前提交

本次提交范围仅为Lab1、Lab2。Lab3、Lab4仍需调整，暂缓提交。

| 目录 | 已提交内容 | 运行与验收说明 |
| --- | --- | --- |
| lab1 | M1 APB/CSR/IRQ、M2同步SRAM及独立TB | [README](lab1/README.md)、[TESTPLAN](lab1/TESTPLAN.md)、[验收说明](lab1/验收说明.md) |
| lab2 | M3处理核、独立同步数组模型及六个测试类 | [README](lab2/README.md)、[TESTPLAN](lab2/TESTPLAN.md)、[验收说明](lab2/验收说明.md) |

从仓库根目录运行：

    make -C lab1 smoke
    make -C lab1 regress
    make -C lab2 smoke
    make -C lab2 regress

工具为QuestaSim/vlog 2021.1与GNU Make 3.81。两个Lab均可独立编译运行，不依赖暂缓提交的项目或编译缓存。每次run自动编译，日志和WLF按RUN_ID及测试/seed保存；重跑使用自动ID或新ID，不覆盖归档证据。

Lab1完成APB两阶段、CSR默认/读写、八字映射、四RES stub读回、PSLVERR和IRQ/W1C。其独立TB使用处理核状态stub，不将其当作真实M3算法验证。

Lab2完成合法包、长度越界、busy/done保持与重启、type/mask、校验开/旁路以及payload sum/XOR。它使用独立数组模型替代M2，通过公共package/基类及六个独立测试类自动检查。

现有完整回归记录为：Lab1三个seed各389项PASS；Lab2六类、16帧、244项PASS。源码、必要脚本、方法学解释、当前验收说明、日志和代表波形均随目录提交。实验依据为[实验说明v1.03](https://shimo.im/docs/ne4G8wuji0D0NqCJ/)中Lab1/2对应要求；实际结果以各Lab日志及验收说明为准。

后续项目修改完成并复审后再单独更新。本人的代码串讲及课程正式评分仍按验收安排进行。

