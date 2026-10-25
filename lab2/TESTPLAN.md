# Lab2 简明测试计划

依据：实验说明§11.3、§12.3「Lab2评分细目」。只覆盖本Lab必做/选做及少量有目的扩展，不穷举所有地址、长度或错误组合。

在本Lab目录的公共入口：`make run TESTNAME=名称 SEED=1`。可加`RUN_ID=lab2_check_20261025`保存本次结果；省略则自动生成。新日志为`logs/RUN_ID/名称_seed/compile.log`与`run.log`，波形为`waves/RUN_ID/名称_seed.wlf`；全部证据来自本交付件当前源码，见验收说明。

| 测试名称 / 类 | 对应检查点 | 输入摘要 | 期望结果 | 已实跑结论 |
| --- | --- | --- | --- | --- |
| normal / normal_test | 必做1，兼顾最小/最大合法包 | len=4/8/32，type=1/2/4，校验正确，payload递增字节 | len/type正确；DONE有效；8B包sum=0A、XOR=04；32B包sum=96、XOR=1C | PASS，3帧 |
| length / length_test | 必做2 | len=3/33，其他头部字段正确 | 两帧length_error=1；正常done，不越界/卡死；摘要为0 | PASS，2帧 |
| timing / timing_test | 必做3，连续两帧 | len=8后len=12，type=1后8 | 首个接收沿busy=1；DONE保持；下一start清done与旧结果；两帧各自正确 | PASS，2帧 |
| type / type_test | 选做4 | type=03；type=01且mask=1110；type=08且mask=1000 | 前两帧type_error=1，第三帧允许，其他错误为0 | PASS，3帧 |
| checksum / checksum_test | 选做5 | 同一个8B包头校验故意改错，mode依次1/0，payload=01/02/03/04 | chk_error依次1/0；两帧sum=0A、XOR=04 | PASS，2帧 |
| extension / extension_test | ABCD C的适量扩展 | len=7、payload=FE/05/03；len=13、payload全AA；len=12但exp=8；len=3/type=03/坏校验 | sum/XOR依次06/F8、FA/AA；length一致性错误；三类头部错误可同时为1 | PASS，4帧 |

每个独立测试复用以下检查：复位输出、start首拍busy/done、旧结果清零、最长12拍内完成、结果/错误自动比较、DONE保持、监视器启动/完成数一致、期望队列为空、关联数组统计总数一致。端口监视器另外检查busy/done不同时有效、PROCESS读使能和DONE结果稳定。

## 批量入口

- `make smoke`：前三个必做类，共7帧。
- `make regress`：全部六个独立类，共16帧；不依赖Lab1RTL。
- 本阶段是定向测试，支持SEED参数与记录，但不使用约束随机，也没有覆盖率百分比要求。

## 扩展选择原因

1. **7B非整字尾部**：未使用字节保留A5，证明尾部填充不参与摘要；FE+05+03还验证8位累加截断。
2. **13B全AA**：中间长度、跨多个word、末字只用一个byte；验证动态数组装载和连续字节处理。
3. **非零期望长度不一致**：验证PKT_LEN_EXP配置实际进入检查，实际合法payload仍处理。
4. **三个头部错误同时成立**：验证§9.2并行判定，不因长度错而漏掉类型/校验错。

实际日志、波形和退出检查记录见[验收说明.md](验收说明.md)。
