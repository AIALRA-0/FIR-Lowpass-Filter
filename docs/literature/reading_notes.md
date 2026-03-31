# Reading Notes

## MathWorks FIR Filter Design

- `firpm` is a good main design path because it is centered on minimax/equiripple optimization
- Symmetric coefficients in a linear-phase FIR can be converted directly into folded hardware multipliers
- With a fixed coefficient count, the transition band and stopband attenuation must trade off against each other

## MathWorks Fixed-Point Filter Design

- Even with full-precision internal MACs, coefficient quantization still changes the frequency response
- Overflow, rounding noise, and final output width must be modeled separately
- bit-true vectors are the key bridge between MATLAB and RTL

## AMD FIR Compiler / DSP48E1

- Symmetric coefficients and the pre-adder are very well matched to low-pass linear-phase FIR
- Systolic/pipelined direct form maps more naturally onto DSP-slice cascading
- Transpose can offer lower latency, but it is not the mainline path of this project

## Polyphase / Parallel Literature

- Parallelism is not simply replicating multiple FIR filters; it is restructuring the dataflow and subfilters
- The value of `L=2` and `L=3` is to raise throughput while preserving symmetry as much as possible
- Whether `L=3 + pipeline` ultimately wins must be decided by synthesis results
