# Architecture Math

以下统计用于 DFG/SFG 展示和 RTL 预算；最终资源与频率以 Vivado 报告为准。

| Architecture | #mult | #add | #reg | samples/cycle | latency | Critical path |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| direct_form | 261 | 260 | 260 | 1 | 1 | adder chain across full tap set |
| symmetry_folded | 131 | 260 | 260 | 1 | 1 | pre-add plus folded accumulation |
| pipelined_systolic | 131 | 260 | 391 | 1 | 132 | single pre-add, multiply, accumulate stage |
| l2_polyphase | 131 | 260 | 392 | 2 | 68 | subfilter accumulation per phase |
| l3_polyphase_ffa | 132 | 261 | 393 | 3 | 47 | phase branch plus recombination |
| l3_pipeline | 132 | 261 | 525 | 3 | 50 | single pipelined substage |
