# Compiler and renderer benchmark

Measured with Zig 0.16.0 on Linux 6.12.63, x86_64, with 12 online CPUs:

```sh
ZIG_LOCAL_CACHE_DIR=/tmp/zeft-zig-cache \
ZIG_GLOBAL_CACHE_DIR=/tmp/zeft-zig-global-cache \
zig build -Doptimize=ReleaseFast bench
```

The harness compiles each case once and averages 1,000 renders. Compile
allocation counts count successful allocator `alloc` requests; requested bytes
also include successful growth through `resize` and `remap`. Each render uses
`renderWithOptions` with the counting allocator; render counts and requested
bytes are accumulated across all 1,000 renders. The allocation count does not
include `resize` or `remap` calls as separate allocations.
Write calls and output bytes are reported for one render. Compiled size is the
logical finalized IR size, including stored instruction records and string
payloads; it excludes allocator and arena bookkeeping. Timings vary with the
host and are observations, not pass/fail thresholds.

## Measured optimization

The large static case contains 250 repeated list items (10,509 source bytes).
Before changing static-write coalescing, the optimizer repeatedly allocated
and recopied an expanding prefix. Accumulating each adjacent run once produced
the following measurements:

| Large static case | Before | After |
| --- | ---: | ---: |
| Compile time | 2,252,492 ns | 408,255 ns |
| Compile allocations | 16 | 11 |
| Requested compile bytes | 6,887,590 | 651,440 |
| Mean render time | 6,383 ns | 6,207 ns |
| Write calls per render | 1 | 1 |
| Compiled size | 10,591 bytes | 10,591 bytes |

Compile time fell by about 82% and requested compile bytes by about 91% in these
runs. Rendering stayed in the same range, with the single static write
preserved. The source size, output, and compiled size were unchanged.

## Final harness run

| Case | Compile time | Mean render time | Compile allocs / bytes | Render allocs / bytes (1,000 renders) | Writes / render | Output bytes | Compiled bytes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Small | 62,548 ns | 6,646 ns | 5 / 11,236 | 1,000 / 632,000 | 5 | 26 | 317 |
| Large static | 483,426 ns | 6,804 ns | 11 / 651,440 | 1,000 / 328,000 | 1 | 10,509 | 10,591 |
| Dynamic | 40,576 ns | 6,377 ns | 5 / 12,904 | 1,000 / 1,240,000 | 13 | 54 | 684 |
| Control flow | 34,555 ns | 6,284 ns | 5 / 11,366 | 1,000 / 1,696,000 | 11 | 47 | 851 |

The existing adjacent-write merge already reduces the large static workload to
one writer call. The measured improvement was in compile-time copying, so the
optimizer now accumulates each run in a growable buffer and emits it once.
