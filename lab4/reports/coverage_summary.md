## 当前源码重新采集的覆盖率

同一套源码在本目录实际执行：

```sh
make cov COVSET=baseline RUN_ID=review_cov_20261028
make mergecov COVSET=baseline MERGE_ID=review_20261028
make cov COVSET=final RUN_ID=review_cov_20261028
make mergecov COVSET=final MERGE_ID=review_20261028
```

只对真实M1/M2/M3/Top收集代码覆盖，不包括验证包、TB、interface或UVM库。Questa statement作为line等效；各指标单列：

| 指标 | baseline raw | final raw | final登记过滤后 |
| --- | --- | --- | --- |
| statement/line | 160/161 | 160/161（99.37%） | 160/160，100% |
| branch | 94/95 | 94/95（98.94%） | 94/94，100% |
| condition | 27/27 | 27/27，100% | 27/27，100% |
| FSM state | 3/3 | 3/3，100% | 3/3，100% |
| FSM transition | 3/5 | 5/5，100% | 5/5，100% |
| toggle | 1272/1409 | 1405/1409（99.71%） | 1405/1405，100% |

baseline功能62/69有效bin，frame_cg=86.43%、access_cg=100%；final为17个点/交叉、69/69有效bin命中。功能组均值仅作功能概览，不当作代码覆盖率。

coverage的14帧补min4、mask全关、exp匹配、IRQ error-only及长度×结果缺口；closure用4完成+1复位中止补FSM合法复位转移、头字段高位和同步读双向toggle。每个新增场景仍经过同一scoreboard检查。

- [baseline原始报告](baseline/review_20261028/raw/text/overall/)
- [final原始报告](final/review_20261028/raw/text/overall/)与[登记过滤后报告](final/review_20261028/filtered/text/overall/)
- [final功能bin细目](final/review_20261028/raw/text/overall/functional_bins.txt)
- [final原始UCDB](../coverage/merged_final_review_20261028/merged_raw.ucdb)与[过滤副本UCDB](../coverage/merged_final_review_20261028/merged_filtered.ucdb)
- [基线采集](../logs/review_cov_baseline_20261028_console.log)、[基线合并](../logs/review_merge_baseline_20261028_console.log)、[最终采集](../logs/review_cov_final_20261028_console.log)、[最终合并](../logs/review_merge_final_20261028_console.log)

Lab1默认值/字段属性/八字SRAM/结果通路，Lab2合法/越界/重启及type/mask/checksum旁路，以及Lab3端到端/连续帧/状态/访问保护/IRQ均由本系统回归内的实际testcase对应，见[TESTPLAN](../TESTPLAN.md)。不是只引用独立Lab的PASS来证明集成。

仅过滤M3第174行不可达default的1个statement和1个branch，以及Top/M1恒定PREADY的4个toggle方向bin；功能模型排除两个越界长度却pass的非法组合。原始DB未就地过滤，[Excel](../覆盖率过滤登记表.xlsx)与exclusions.do对应，助教过滤口径确认仍待进行。原始代码各类已在优良档，技术过滤值不等于教师已批准。

