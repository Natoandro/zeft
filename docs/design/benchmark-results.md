# Compiler and renderer benchmark

Measured with Zig 0.16.0 on Linux 6.12.63+deb13-amd64, x86_64:

```sh
ZIG_LOCAL_CACHE_DIR=/tmp/zeft-zig-cache \
ZIG_GLOBAL_CACHE_DIR=/tmp/zeft-zig-global-cache \
zig build -Doptimize=ReleaseFast bench
```

The rendering harness compiles each case once and averages 1,000 renders.
Compile allocation counts count successful allocator `alloc` requests;
requested bytes also include successful growth through `resize` and `remap`.
Each render uses `renderWithOptions` with the counting allocator. Render
allocation counts and requested bytes accumulate across all 1,000 renders.
The allocation count excludes separate `resize` and `remap` calls.

Write calls and output bytes describe one render. The writer counts and
discards output; it does not measure output copying or actual I/O. Compiled
size is the logical finalized IR size, including stored instruction records
and unique string payloads, excluding allocator and arena bookkeeping.
Timings vary with the host and are observations, not pass/fail thresholds.

## Rendering workloads

The large static case contains 250 repeated list items (10,509 source bytes).
The other cases exercise interpolation, escaping, and a conditional with a
three-item loop. Source construction happens outside the measured intervals.

| Case | Compile time | Mean render time | Compile allocs / bytes | Render allocs / bytes (1,000 renders) | Writes / render | Output bytes | Compiled bytes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Small | 60,863 ns | 6,725 ns | 5 / 11,020 | 1,000 / 632,000 | 5 | 26 | 317 |
| Large static | 394,298 ns | 6,914 ns | 10 / 627,432 | 1,000 / 328,000 | 1 | 10,509 | 10,591 |
| Dynamic | 40,756 ns | 6,971 ns | 5 / 12,592 | 1,000 / 1,240,000 | 13 | 54 | 684 |
| Control flow | 63,519 ns | 7,113 ns | 5 / 11,704 | 1,000 / 1,696,000 | 11 | 47 | 851 |

Static-write coalescing emits the large static workload in one writer call.
Every workload makes one allocator request per render. These short rendering
measurements include scratch allocation and context adaptation overhead.

## Compilation scaling

The compile-only harness generates two families: `{{ v0 }}{{ v1 }}...` uses
one distinct root symbol per entry; `s0{{ x }}s1{{ x }}...` uses one repeated
symbol and a distinct static fragment per entry. Source construction and
template deinitialization are outside the timed interval. Each entry count
reports the median of five separate compilations using the page allocator.
These cases exercise symbol lookup and persistent string interning without
requiring a render context.

| Entries | Distinct symbols: source bytes | Median compile time | Distinct static fragments: source bytes | Median compile time |
| ---: | ---: | ---: | ---: | ---: |
| 500 | 4,890 | 563,424 ns | 5,390 | 671,345 ns |
| 1,000 | 9,890 | 1,018,534 ns | 10,890 | 1,286,998 ns |
| 2,000 | 20,890 | 2,099,166 ns | 22,890 | 2,719,337 ns |
| 4,000 | 42,890 | 4,628,396 ns | 46,890 | 5,562,713 ns |
| 8,000 | 86,890 | 9,740,227 ns | 94,890 | 13,143,592 ns |

Compilation scales approximately with input size in these workloads. Analysis,
lowering, and finalization use hash lookup for larger symbol/string sets;
small sets retain bounded linear scans. The lexer borrows static source text
during compilation. Finalization retains owned payloads and IR, releases its
temporary lookup structures, and stores the logical compiled size for constant
cost size queries.

## Python build modes

The native benchmark above uses `ReleaseFast`. Python wheels default to
`ReleaseSafe`; their context conversion and output buffering add work that the
native counting-sink benchmark does not measure. See the
[Python build-mode comparison and default policy](../../bindings/python/README.md#releasefast-performance-and-the-releasesafe-default)
for ReleaseSafe/ReleaseFast rendering observations, measurement limitations,
the confirmed expression-stack initialization cost, and the validation reasons
for retaining safety checks in the default binding build.
