# RTL Structure Notes

## Common Modules

- `rtl/common/delay_line.v`
- `rtl/common/fir_delay_signed.v`
- `rtl/common/fir_branch_core_symm.v`
- `rtl/common/fir_branch_core_full.v`
- `rtl/common/fir_branch_core_mirror_pair.v`
- `rtl/common/fir_l3_ffa_core.v`
- `rtl/common/preadd_mult.v`
- `rtl/common/round_sat.v`
- `rtl/common/valid_pipe.v`
- `rtl/common/fir_params.vh`
- `rtl/common/fir_coeffs.vh`
- `rtl/common/fir_polyphase_params.vh`
- `rtl/common/fir_polyphase_coeffs.vh`

## Architecture Modules

- `rtl/fir_symm_base/fir_symm_base.v`
- `rtl/fir_pipe_systolic/fir_pipe_systolic.v`
- `rtl/fir_l2_polyphase/fir_l2_polyphase.v`
- `rtl/fir_l3_polyphase/fir_l3_polyphase.v`
- `rtl/fir_l3_pipe/fir_l3_pipe.v`
- `rtl/system/fir_stream_shell.v`
- `rtl/system/fir_zu4ev_shell.v`
- `rtl/system/zu4ev_fir_*_top.v`

## Interface Conventions

- Scalar modules: `clk,rst,in_valid,in_sample,out_valid,out_sample`
- Vector modules: `clk,rst,in_valid,in_vec,out_valid,out_vec`
- `in_vec[WIN-1:0]` is lane0, i.e. the earliest sample in that cycle

## Current Implementation Status

- `fir_symm_base`: symmetry-folded baseline, synthesizable, passed scalar bit-true regression
- `fir_pipe_systolic`: symmetry-folded + systolic accumulation chain, synthesizable, passed scalar bit-true regression
- `fir_l2_polyphase`: true `L=2 polyphase + symmetry` datapath, passed vector bit-true regression and completed ZU4EV Vivado implementation
- `fir_l3_polyphase`: `L=3` datapath with a shared `L3 FFA core`, passed full vector bit-true regression and completed ZU4EV Vivado implementation
- `fir_l3_pipe`: `L=3 + pipeline` datapath with input/output pipeline cuts around the `L3 FFA core`, passed full vector bit-true regression and completed ZU4EV Vivado implementation
- `rtl/system/*`: ZU4EV `PS + PL` system shell that keeps the PS-visible interface as a scalar `Q1.15` stream and performs `L=2 / L=3` packing/unpacking inside PL

## Coefficient Sources

- Scalar coefficients are auto-generated into `rtl/common/fir_params.vh` and `rtl/common/fir_coeffs.vh`
- `L=2 / L=3` polyphase branch coefficients are auto-generated into `rtl/common/fir_polyphase_params.vh` and `rtl/common/fir_polyphase_coeffs.vh`

## Current Conclusions

- The strongest and most reliable board-deployable version is still `fir_pipe_systolic`
- `fir_l2_polyphase` has been upgraded from a placeholder implementation into a truly synthesizable parallel architecture
- `fir_l3_polyphase` / `fir_l3_pipe` have shown that the `FFA` compression direction can become a genuine high-throughput candidate on ZU4EV
- The next optimization round should focus on the ZU4EV system shell, the on-board smoke flow, and comparison against vendor FIR IP, rather than continuing to treat the 7020 as the mainline platform
