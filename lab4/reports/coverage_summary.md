# 当前版本覆盖率结果

所有数据库由本交付件相同源码与覆盖模型重新采集、合并；功能覆盖与代码覆盖分别报告。

| 指标 | baseline raw | final raw | final filtered |
| --- | --- | --- | --- |
| Statements | 160/161，99.38% | 160/161，99.38% | 160/160，100.00% |
| Branches | 94/95，98.95% | 94/95，98.95% | 94/94，100.00% |
| Conditions | 27/27，100.00% | 27/27，100.00% | 27/27，100.00% |
| FSM States | 3/3，100.00% | 3/3，100.00% | 3/3，100.00% |
| FSM Transitions | 3/5，60.00% | 5/5，100.00% | 5/5，100.00% |
| Toggles | 1272/1409，90.28% | 1405/1409，99.72% | 1405/1405，100.00% |

| 功能组 | baseline | final |
| --- | --- | --- |
| frame_cg | 86.43% | 100.00% |
| access_cg | 100.00% | 100.00% |

最终17个功能点/交叉、69/69有效bin全部命中。百分比按分子分母四舍五入；工具文本截断显示的末位差异不表示结果不同。

过滤仅采用[exclusions.do](../exclusions.do)与[Excel登记](../覆盖率过滤登记表.xlsx)列明对象。过滤后的100%是技术登记口径，仍需助教确认。

[baseline原始报告](baseline/current_20261025/raw/text/overall/)、[final原始报告](final/current_20261025/raw/text/overall/)、[final过滤报告](final/current_20261025/filtered/text/overall/)。
