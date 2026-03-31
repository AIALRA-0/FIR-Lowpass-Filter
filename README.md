# FIR Lowpass Filter Project

This repository contains the complete reproducible engineering workflow, results, and documentation for the FIR low-pass filter course project; please read [Report.md](Report.md) or [Report.pdf](Report.pdf) for the full report

## Main Contributions

- First, it explicitly clarified and resolved the semantic ambiguity between 100 taps and `order = 100` in the problem statement; by simultaneously constructing two baselines and conducting systematic design space scanning, that is, analyzing frequency response performance under different orders, it proved that under the current specification constraints of a narrow transition band + high stopband attenuation, a 100 taps level design cannot satisfy the 80 dB stopband requirement, thereby providing a quantitative basis for subsequently increasing the order
- Second, it constructed a complete engineering closed loop from algorithm to hardware; this closed loop covers all key stages including MATLAB floating-point design, fixed-point quantization, golden vector generation, RTL implementation, Vivado synthesis, and FPGA board-level validation, and unifies bit width, test data, and validation rules across all stages, thereby ensuring that every implementation layer can undergo strict bit-true validation aligned on every binary bit rather than relying only on local simulation results
- Third, it completed a fair comparison between self-developed architectures and industrial IP under unified experimental conditions; under the same bit width, the same input data, and the same board-level test flow, it systematically compared self-developed FIR architectures with Xilinx FIR Compiler, thereby drawing engineering-meaningful conclusions at both the kernel scope and board-shell scope levels, evaluating not only architecture design capability but also reflecting actual system integration performance

## Directory Layout

```text
.
├── spec/                   Specification definitions
├── config/                 Toolchain and environment configuration
├── matlab/                 MATLAB algorithm design and data generation
│   ├── design/             Floating-point design and design space exploration
│   ├── fixed/              Fixed-point quantization and word-length exploration
│   ├── vectors/            Golden vector generation entry
│   └── utils/              MATLAB common utility functions
├── coeffs/                 Exported filter coefficients
├── vectors/                Golden input and output vectors
│   ├── impulse/            Impulse response verification test
│   ├── step/               Step response and DC gain test
│   ├── random_short/       Fast random regression test
│   ├── passband_edge/      Passband edge sinusoidal test
│   ├── transition/         Transition band sinusoidal test
│   ├── stopband/           Stopband sinusoidal test
│   ├── multitone/          Multi-tone spectrum test
│   ├── overflow_corner/    Overflow boundary test
│   ├── lane_alignment_l2/  L2 split data channel parallel alignment verification
│   └── lane_alignment_l3/  L3 split data channel parallel alignment verification
├── rtl/                    Verilog RTL implementation
│   ├── common/             Common modules
│   ├── fir_symm_base/      Symmetric folding baseline structure
│   ├── fir_pipe_systolic/  Pipelined systolic architecture
│   ├── fir_l2_polyphase/   L2 parallel structure
│   ├── fir_l3_polyphase/   L3 parallel and FFA structure
│   ├── fir_l3_pipe/        L3 pipelined version
│   ├── fir_vendor_ip_core/ Xilinx FIR Compiler wrapper
│   └── system/             ZU4EV system-level structure
├── tb/                     Simulation testbench
│   └── cases/              Test cases and input data
├── vivado/                 Vivado build flow
│   ├── tcl/                Build scripts
│   └── build/              Build entry and artifacts
├── vitis/                  Embedded software
│   └── zu4ev_baremetal/    Board-level test program
├── data/                   Result data storage
│   ├── analysis/           Analysis result data
│   ├── board_runs/         Board test run records
│   └── hardware/           Hardware probing information
├── docs/                   Documentation and visualization resources
│   ├── assets/             Charts and images
│   └── literature/         Literature and notes
├── report/                 Report source files
│   └── latex/              LaTeX main manuscript
├── scripts/                Automation scripts
└── reports/                Analysis and conclusion documents
```
