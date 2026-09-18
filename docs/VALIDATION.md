# STRATUM validation record

The checks below were performed against the shipped source. They do not establish physical-GPU frame rate, complete browser compatibility, or photorealistic image quality.

## What was executed

### CUDA-to-WGSL translation and source/runtime checks

`npm run build` translated all **18 CUDA entry points** using the bundled CUDA WebShader compiler. `npm test` passed **four test groups**:

1. Recompile every entry point and compare its WGSL byte-for-byte with the generated files; check the storage-buffer and workgroup-storage limits used by this project.
2. Check the host's buffer dimensions and dispatch widths against the CUDA constants and manifest.
3. Exercise the real JavaScript engine/runtime allocation, binding, dispatch, resize, reset and image-presentation API path with an explicitly labelled **device double**. It checks API contracts; it does not execute WGSL or emulate a GPU.
4. Check source-level camera/cache bounds and the intended scoring/training partition and gate.

The largest cooperative kernel uses 256 threads and 16 KiB of workgroup storage. Translation is not the same as the browser driver's shader validation. The latter must be run on a real WebGPU implementation.

### Native CPU reference checks

Compiled with:

```sh
g++ -std=c++17 -O2 -fopenmp tests/native_harness.cpp -o stratum-native
./stratum-native
```

The harness includes `Stratum.cu` and runs the authored generation, hierarchy building, intersection, material, lighting and neural math on CPU. Its Morton sort is an **independent scalar CPU reference** based on `std::sort`, not the GPU's cooperative shared-memory implementation. The native run is neither an NVCC CUDA run nor native GPU validation.

Results:

| Check | Result |
|---|---|
| Ten-bit Morton interleaving | Passed |
| Generation creates real resident geometry | Passed |
| Stationary settled view reuses its cache without generation | Passed |
| Central landmark page residency and live BVH leaf count | Passed |
| BVH nearest hits vs exhaustive primitive intersection | Passed, 200 rays, tolerance 0.001 m |
| Procedural shading output remains finite | Passed |
| Every neural parameter gradient vs finite differences | Passed, all 291 parameters |
| Maximum absolute gradient discrepancy | 0.0000284016 |
| Real optimizer updates and excluded-batch scoring | Passed |
| Freezing training preserves weights | Passed |
| Camera travel keeps cache residency bounded | Passed |
| Regenerated geometry values remain finite | Passed |

One deterministic inspection-surface training fixture ran 500 optimizer steps with 4,000 scored observations. Its final running RGB MSE was **0.0000137933**, versus **0.00441985** for the material-mean baseline, and the gate opened. This result applies to that particular CPU fixture. It does not establish generalization across the city, perceptual quality, browser GPU parity, or an inference speed-up. Scored entries are excluded from the same update's gradient; the online sampler can revisit surface locations later.

## Preview provenance

The included preview files are generated renderer output, not AI image generation or mock screenshots. They use the native CPU reference path described above.

| View | Internal dimensions | Stationary samples | Resident pages | Resident analytic primitives |
|---|---|---:|---:|---:|
| Skyline | 1440 × 900 | 8 | 101 | 89,153 |
| Street | 1440 × 900 | 4 | 98 | 88,933 |
| Masonry | 1000 × 750 | 8 | 98 | 82,574 |
| Grain | 1000 × 750 | 8 | 97 | 82,574 |

Those are counts of actual cached primitives, not triangles. Procedural leaves evaluated inside foliage envelopes and fine material signals are not inflated into an equivalent polygon count.

Reproduce a preview:

```sh
./stratum-native render skyline.ppm 1 1440 900 8
./stratum-native render street.ppm 2 1440 900 4
./stratum-native render masonry.ppm 3 1000 750 8
./stratum-native render grain.ppm 6 1000 750 8
```

The preview path holds the camera still and accumulates the requested number of samples. Normal motion resets accumulation.

## What was not verified here

Attempted Chromium navigation to the local app failed with `net::ERR_BLOCKED_BY_ADMINISTRATOR`. Therefore **browser GPU execution and hardware GPU frame rate are unverified in this build environment**. No enterprise browser restriction was bypassed, and no CPU output was presented as an actual browser GPU result.

Run the included hardware check yourself:

```text
http://localhost:8089/tests/browser.html
```

Its **Run GPU checks** button asks the real browser adapter to validate and execute the kernels, exercise page generation, test sort index validity and BVH counts, render nonblank output, update weights and freeze learning. It prints its own errors and actual measurements. The regular application does not silently fall back to CPU rendering.

Also not established: parity against native NVCC CUDA, long-run stability on every driver, mobile playability, production-engine speed-ups, complete geometric error bounds, or perceptual equivalence of neural substitution. The current shadows/reflections and geometric LOD transitions have the approximations described in the README.

## Logs

`compile.log`, `node-tests.log` and `native-tests.log` are copies of the performed build/test output. `validation.json` provides a compact machine-readable record and the combined-source SHA-256.
