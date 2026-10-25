# Lab3 Testplan

规格：v1.03 §11.4、§12.3 Lab3栏。默认用例均有自动检查，不能仅由波形看起来合理判PASS。实际结果及命令归档见[验收说明](验收说明.md)。

| testcase | 对应检查点/动机 | 输入摘要 | 期望输出与检查 | 验收项 |
| --- | --- | --- | --- | --- |
| smoke | 真实端到端链路，排除接口连错 | 8B/type02，payload 01/02/03/04 | RES长度8/类型02，sum0A/XOR04；真实APB读值与模型一致；IRQ闭环 | 必做1，兼顾必做3、选做5 |
| frames | 连续两帧不能混用旧结果 | 同次仿真8B/type01、13B/type08 | 两次结果各自正确；第二次接受start清done和旧结果 | 必做2 |
| status | 状态经M1总线读回不能错拍 | 32B/type04，处理中和完成后读STATUS | ACCESS时busy对应01，done对应10；两类读次数均非0 | 必做3 |
| busy | 错误响应不能仍修改数据 | 32B/type02，忙时写word7=DEADBEEF | ACCESS沿busy确为1；PSLVERR=1；两次读word7保留原值且摘要正确 | 选做4 |
| irq | EN→事件→保存→W1C，分位清除 | EN=00正常包、EN=01正常包、EN=11坏校验包 | 禁用不置位；正常完成置done；错误完成置两位；写0保持，分位W1C不误清另一位，最后IRQ为0 | 选做5及有目的扩展 |
| random | 字段变化和时序间隔，不靠固定向量 | 每seed12帧，长度4–32、四类合法type、随机payload/mode，mask=F | 每次randomize成功；每帧真实结果、全部RES读回及IRQ正确；同seed可复现 | A/C扩展 |
| extension | 尾部过滤、累加溢出、期望长度与多错独立性 | 7B FE/05/03；13B九个AA；12B期望8；受控3B/type03/坏校验 | 前两帧sum/XOR=06/F8、FA/AA；后两帧分别长度错、三错并存且正常完成 | C扩展 |

`csr`、`memory`、`errors`也由同一环境提供，供Lab4复用：分别覆盖CSR默认/字段属性，八字写读和首末覆盖写，非法地址/RO写及Lab2长度/type/mask/checksum/旁路。它们不改变Lab3的必做范围。

## 对“测到了”的约束

- 所有期望从monitor接收的APB写及规格计算；从M3实际完成输出与APB实际读返回分别检查结果。
- 提交数、实际接受start数、实际完成数、driver完成数必须相等；最后没有未完成帧或未消费消息。
- smoke/frames/status必须各发生真实busy与done状态读；busy必须实际命中忙期拒写。
- 检查拒绝X/Z；未知测试、超时和提前finish均为失败。seed传递到实际随机流，不只写在文件名里。
- 不穷举所有包长、类型mask组合或全部同拍碰撞；Lab4再由真实覆盖率缺口指导少量补测。
