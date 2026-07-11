# Architecture

## Network mapping

The target network contains two fully connected layers separated by normalization and ReLU:

```text
X -> FC1 -> arithmetic-shift normalization -> ReLU -> FC2 -> Y
```

Both fully connected layers use the same 4x4 systolic array. The feature width is eight, so each output tile requires two K tiles. The first partial product initializes the accumulation buffer and the second is added through `cla16`.

## Weight-stationary array

`sa8_4x4` instantiates sixteen `se8` processing elements. A weight tile is loaded before computation and remains local while activation values move horizontally. Partial sums move vertically, with timing delays used to align the wavefront across the array.

Each `se8` contains a four-cycle `mad8` datapath. The multiplier decomposes an 8-bit signed multiplication into 4-bit partial products and selects signed-signed, signed-unsigned, or unsigned-unsigned handling for each term.

## Controller

The controller uses the following major states:

| State | Responsibility |
| --- | --- |
| `IDLE` | Wait for a start pulse and capture batch mode. |
| `LOAD_X` | Read input activations into the local buffer. |
| `LOAD_W1`, `LOAD_W2` | Load both 8x8 weight matrices. |
| `CLEAR_TILE` | Select the current layer and prepare A/B tile buffers. |
| `WHT_LOAD` | Prefill one 4x4 weight tile into the array. |
| `COMP` | Stream skewed activation data and capture array outputs. |
| `ACCUM` | Combine the two K-tile partial results. |
| `STORE_TILE` | Store FC1 activations internally or write FC2 outputs. |
| `DONE_ST` | Signal completion after all rows and layers finish. |

Base mode processes eight input rows; extra mode processes sixteen. The same datapath and weights are reused, while the controller changes row-tile bounds and address ranges.

## Activation path

FC1 accumulation results are signed 16-bit values. Normalization divides by 32 using an arithmetic right shift, preserving the sign. The result is reduced to eight bits and ReLU replaces negative values with zero before storing the intermediate activation in `x3_buf`.

## Improvement opportunities

The implementation schedules loading, prefill, compute, accumulation, and storage mostly sequentially. Double buffering, overlapped states, parallel accumulation, and a more deeply pipelined MAC datapath could reduce bubbles and improve array utilization.
