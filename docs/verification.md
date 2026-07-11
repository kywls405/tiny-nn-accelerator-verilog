# Verification

## Original simulation

The private project environment used a self-checking Verilog testbench with synchronous behavioral memories. It performed the following sequence for both supported batch modes:

1. Load input, W1, W2, and reference-output vectors.
2. Reset the accelerator and issue a one-cycle `run` pulse.
3. Wait for `done` with a timeout guard.
4. Capture every output write by address.
5. Check for missing writes, unknown values, and mismatches.

The base case matched all 64 outputs in 1,387 cycles. The extra case matched all 128 outputs in 2,643 cycles.

## Public CI

The authored self-checking testbench is included with relative file paths and a public replacement for the course memory model. The course-provided testbench scaffold, original memory model, and reference vectors are not redistributed. Public CI therefore checks that:

- the RTL compiles with Icarus Verilog in SystemVerilog-2012 mode;
- `top` elaborates with the complete internal hierarchy;
- the self-checking testbench and public file-memory model elaborate together;
- all expected arithmetic, processing-element, array, and controller modules remain present;
- excluded course markers and absolute local paths do not enter the public source.

The reported functional results refer to the original vector-backed simulation. Public CI provides syntax and elaboration regression coverage; running the full comparison requires the excluded vector files in the documented `vectors/` paths.
