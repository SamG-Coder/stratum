# Renderer architecture and buffer contract

All dimensions are shared by `kernels/common.cu` and the `ABI` object in `src/engine.js`. `npm test` checks their agreement. Float buffers use four-byte f32 elements. `Queue` and `Order` are i32; final pixels are packed u32 RGBA8.

## Persistent GPU allocations

| Buffer | Elements | Purpose |
|---|---:|---|
| World | 64 × 64 × 8 f32 | Width/depth/height, type, material, floors, seed, variant |
| Meta | 256 × 12 f32 | World-cell tags, LOD, ready flag, primitive count, generation frame/history |
| C | 64 f32 | CUDA-owned camera, exposure, flags and frame counters |
| I | 32 f32 | Browser input only |
| Req | 256 × 8 f32 | Desired world cell, LOD, priority and projected scale |
| Queue | 7 i32 | Count plus up to six selected page slots |
| P | 256 × 2048 × 16 f32 | Analytic primitive records |
| Order | 256 × 2048 i32 | Sorted primitive indices |
| Nodes | 256 × 4096 × 8 f32 | Binary BVH bounds and live-leaf counts |
| Stats | 32 f32 | Actual cache counters |
| W, M, V, Grad | 291 f32 each | Trainable parameters, Adam moments, gradients |
| Brain | 32 f32 | Updates, running errors and quality gate |
| Work | 64 × 64 f32 | Batch inputs, targets, hidden activations, predictions and validity |

Per-pixel `Hit`, `Linear` and `History` use four f32 values each. `Pixels` is one u32 per pixel. This is 52 bytes per internal render pixel, excluding the canvas texture, query buffers, uniform arena and implementation overhead. The UI's buffer total covers application buffers and is not a claim of total driver memory use.

A primitive record stores centre xyz, shape code, half-extents xyz, material, orientation, seed and spare fields. Invalid slots have a negative shape code. Primitive indices remain stable within a generated page until it is replaced.

## Ordered work

The browser submits ordered compute batches; it does not read the request queue to decide which pages to build.

1. `stepCamera`, `selectPages`, `schedulePages`.
2. `generatePages`: six workgroups maximum, each with 64 cluster-generator lanes. Lanes have disjoint 32-slot primitive ranges.
3. `sortPages`: six workgroups maximum, 256 threads each. Two shared arrays total 16 KiB. Every lane reaches the sorting barriers, including workgroups with no valid queue entry. Invalid page groups do not write the output arrays.
4. `buildBVH` repeats with `first = 1024, 512, ... , 1`. Each dispatch consumes the completed previous level. `commitPages` publishes metadata only afterwards, followed by `summarise`.
5. `tracePrimary`: 8 × 8 workgroups. World-cell traversal is followed by near-first BVH traversal. Leaf intersection uses analytic geometry and optional close masonry relief. Foliage envelopes perform a bounded local leaf-cell traversal.
6. `prepareMaterialBatch`, `materialForward`, `scoreMaterial`, `materialGradient`, `materialAdam`, with per-kernel training gates. Scoring entries 56–63 are not gradient entries 0–55. Training operates on the procedural substrate, never on the model's own output.
7. `shadePixels`: direct/ambient approximation and optional neural substrate; world/material geometry is still authoritative.
8. `resolveFrame`: screen-space contact occlusion, modest bloom, stationary accumulation, tone map and RGBA packing. The final buffer is copied to the WebGPU canvas texture.

No weight writes run concurrently with the subsequent shading pass. This establishes a dispatch boundary for updated weights, not a claim that the running validation score covers every post-update pixel.

## Cache semantics

`pageIndex` is a positive modulo of world cell x/z by 16. `selectPages` maps each slot to one cell in the camera-centred 16 × 16 window. Current tags decide reuse. Cells outside the window may remain resident until the same slot is needed by another cell. Nearest-hit traversal accepts a cached page only when its world-cell tags match.

Requests use view tests and projected scale, with hysteresis around detail thresholds. There is no occlusion-query/Hi-Z page culling. The DDA/BVH performs actual visibility rejection at render time. A fixed priority selection chooses at most six requests. A page replacement is an entire analytic lot, not streamed triangle clusters.

The fine-material filtering is independent of the three geometric LOD levels. Leaf cells and small surface signals can be evaluated at ray time without being individually stored in the primitive cache.

## Measurement semantics

A timestamp-enabled frame uses five compute passes/batches: generation/BVH, visibility, learning, materials/lighting and resolve. Timestamps are sampled every twelve frames when the staging buffer is available. The reported values are GPU elapsed time for those passes, not CPU wall time, not a benchmark promise, and not a sum that includes presentation/driver scheduling overhead.

Cache counts are GPU-written. The field-notes panel periodically reads compact stats. Screenshot/export commands request explicit readbacks. The normal scene does not round-trip geometry or pixels through JavaScript.

## Important approximations

The cached scene is not a triangle engine or a full neural field. Small bevels are primarily normal changes. Mortar relief is bounded local ray correction, not a general displacement-mapped mesh. Fine cracks and pores are shading. Most coarse shadows and reflections are not resolved against the fine BVHs. The neutral procedural teacher remains available regardless of the optional neural gate.
