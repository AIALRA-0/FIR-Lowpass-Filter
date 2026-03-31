# Architecture Math

The statistics below are used for DFG/SFG presentation and RTL budgeting; final resource and frequency numbers must follow the Vivado reports.

| Architecture | #mult | #add | #reg | samples/cycle | latency | Critical path |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| direct_form | 261 | 260 | 260 | 1 | 1 | tap multiply plus full-width adder tree |
| symmetry_folded | 131 | 260 | 260 | 1 | 1 | pre-add plus folded adder tree |
| pipelined_systolic | 131 | 260 | 391 | 1 | 132 | single DSP48-friendly MAC stage |
| l2_polyphase | 131 | 260 | 392 | 2 | 68 | single phase branch plus lane recombine |
| l3_polyphase_ffa | 132 | 261 | 393 | 3 | 47 | polyphase branch plus FFA recombine |
| l3_pipeline | 132 | 261 | 525 | 3 | 50 | single pipelined branch / recombine stage |
