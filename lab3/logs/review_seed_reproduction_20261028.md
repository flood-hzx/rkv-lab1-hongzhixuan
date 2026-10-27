# 当前源码随机seed复现

实际命令使用make run TESTNAME=random；123连续运行两次、2026运行一次。输入和完成记录按行比较：同seed一致，不同seed变化。

- seed=123，RUN_ID=repro_a：[完整输出](review_repro_a_20261028_console.log)；[对应波形](../waves/review_seed_20261028/repro_a/random_123.wlf)。
- seed=123，RUN_ID=repro_b：[完整输出](review_repro_b_20261028_console.log)；[对应波形](../waves/review_seed_20261028/repro_b/random_123.wlf)。
- seed=2026，RUN_ID=repro_other：[完整输出](review_repro_other_20261028_console.log)；[对应波形](../waves/review_seed_20261028/repro_other/random_2026.wlf)。
