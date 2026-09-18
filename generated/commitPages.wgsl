// CUDA WebShader 0.1.0. Generated from kernel commitPages.
@group(0) @binding(0) var<storage, read> b_Req: array<f32>;
@group(0) @binding(1) var<storage, read> b_Queue: array<i32>;
@group(0) @binding(2) var<storage, read> b_P: array<f32>;
@group(0) @binding(3) var<storage, read_write> b_Meta: array<f32>;
@group(0) @binding(4) var<storage, read> b_C: array<f32>;
const cw_block_size: vec3<u32> = vec3<u32>(64u, 1u, 1u);

fn cw_divide_f32(a: f32, b: f32) -> f32 { let q = a / b; if ((bitcast<u32>(q) & 0x7f800000u) == 0x7f800000u || (bitcast<u32>(q) & 0x7fffffffu) == 0u || (bitcast<u32>(b) & 0x7f800000u) == 0x7f800000u) { return q; } let residual = fma(-q, b, a); return q + residual / b; }
fn f_clampf(cw_arg_x: f32, cw_arg_a: f32, cw_arg_b: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_x: f32 = cw_arg_x;
  var v_a: f32 = cw_arg_a;
  var v_b: f32 = cw_arg_b;
  return min(v_b, max(v_a, v_x));
}
fn f_sat(cw_arg_x: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_x: f32 = cw_arg_x;
  return f_clampf(v_x, 0.0f, 1.0f, cw_thread, cw_block, cw_grid);
}
fn f_lerpf(cw_arg_a: f32, cw_arg_b: f32, cw_arg_t: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_a: f32 = cw_arg_a;
  var v_b: f32 = cw_arg_b;
  var v_t: f32 = cw_arg_t;
  return (v_a + ((v_b - v_a) * v_t));
}
fn f_fractf(cw_arg_x: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_x: f32 = cw_arg_x;
  return (v_x - floor(v_x));
}
fn f_smoothf(cw_arg_a: f32, cw_arg_b: f32, cw_arg_x: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_a: f32 = cw_arg_a;
  var v_b: f32 = cw_arg_b;
  var v_x: f32 = cw_arg_x;
  var v_t: f32 = f_sat(cw_divide_f32((v_x - v_a), (v_b - v_a)), cw_thread, cw_block, cw_grid);
  return ((v_t * v_t) * (3.0f - (2.0f * v_t)));
}
fn f_imod(cw_arg_x: i32, cw_arg_n: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> i32 {
  var v_x: i32 = cw_arg_x;
  var v_n: i32 = cw_arg_n;
  var v_r: i32 = (v_x % v_n);
  var cw_tmp_0: i32;
  if ((v_r < 0i)) {
    cw_tmp_0 = (v_r + v_n);
  } else {
    cw_tmp_0 = v_r;
  }
  return cw_tmp_0;
}
fn f_dot3(cw_arg_a: vec3<f32>, cw_arg_b: vec3<f32>, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_a: vec3<f32> = cw_arg_a;
  var v_b: vec3<f32> = cw_arg_b;
  return (((v_a.x * v_b.x) + (v_a.y * v_b.y)) + (v_a.z * v_b.z));
}
fn f_length3(cw_arg_a: vec3<f32>, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_a: vec3<f32> = cw_arg_a;
  return sqrt(f_dot3(v_a, v_a, cw_thread, cw_block, cw_grid));
}
fn f_norm3(cw_arg_a: vec3<f32>, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var v_a: vec3<f32> = cw_arg_a;
  return (v_a / vec3<f32>(max(0.000001f, f_length3(v_a, cw_thread, cw_block, cw_grid))));
}
fn f_cross3(cw_arg_a: vec3<f32>, cw_arg_b: vec3<f32>, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var v_a: vec3<f32> = cw_arg_a;
  var v_b: vec3<f32> = cw_arg_b;
  return vec3<f32>(((v_a.y * v_b.z) - (v_a.z * v_b.y)), ((v_a.z * v_b.x) - (v_a.x * v_b.z)), ((v_a.x * v_b.y) - (v_a.y * v_b.x)));
}
fn f_mix3(cw_arg_a: vec3<f32>, cw_arg_b: vec3<f32>, cw_arg_t: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var v_a: vec3<f32> = cw_arg_a;
  var v_b: vec3<f32> = cw_arg_b;
  var v_t: f32 = cw_arg_t;
  return (v_a + ((v_b - v_a) * vec3<f32>(v_t)));
}
fn f_min3(cw_arg_a: vec3<f32>, cw_arg_b: vec3<f32>, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var v_a: vec3<f32> = cw_arg_a;
  var v_b: vec3<f32> = cw_arg_b;
  return vec3<f32>(min(v_a.x, v_b.x), min(v_a.y, v_b.y), min(v_a.z, v_b.z));
}
fn f_max3(cw_arg_a: vec3<f32>, cw_arg_b: vec3<f32>, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var v_a: vec3<f32> = cw_arg_a;
  var v_b: vec3<f32> = cw_arg_b;
  return vec3<f32>(max(v_a.x, v_b.x), max(v_a.y, v_b.y), max(v_a.z, v_b.z));
}
fn f_abs3(cw_arg_a: vec3<f32>, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var v_a: vec3<f32> = cw_arg_a;
  return vec3<f32>(abs(v_a.x), abs(v_a.y), abs(v_a.z));
}
fn f_hashU(cw_arg_x: u32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> u32 {
  var v_x: u32 = cw_arg_x;
  v_x = (v_x ^ (v_x >> u32(16i)));
  v_x = (v_x * 2146121005u);
  v_x = (v_x ^ (v_x >> u32(15i)));
  v_x = (v_x * 2221713035u);
  v_x = (v_x ^ (v_x >> u32(16i)));
  return v_x;
}
fn f_hash1(cw_arg_x: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_x: i32 = cw_arg_x;
  return cw_divide_f32(f32((f_hashU(u32(v_x), cw_thread, cw_block, cw_grid) & 16777215u)), 16777216.0f);
}
fn f_hash2(cw_arg_x: i32, cw_arg_y: i32, cw_arg_seed: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_x: i32 = cw_arg_x;
  var v_y: i32 = cw_arg_y;
  var v_seed: i32 = cw_arg_seed;
  return cw_divide_f32(f32((f_hashU((((u32(v_x) * 1973u) + (u32(v_y) * 9277u)) + (u32(v_seed) * 26699u)), cw_thread, cw_block, cw_grid) & 16777215u)), 16777216.0f);
}
fn f_noise2(cw_arg_x: f32, cw_arg_y: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_x: f32 = cw_arg_x;
  var v_y: f32 = cw_arg_y;
  var v_ix: i32 = i32(floor(v_x));
  var v_iy: i32 = i32(floor(v_y));
  var v_fx: f32 = f_fractf(v_x, cw_thread, cw_block, cw_grid);
  var v_fy: f32 = f_fractf(v_y, cw_thread, cw_block, cw_grid);
  v_fx = ((v_fx * v_fx) * (3.0f - (2.0f * v_fx)));
  v_fy = ((v_fy * v_fy) * (3.0f - (2.0f * v_fy)));
  return f_lerpf(f_lerpf(f_hash2(v_ix, v_iy, 13i, cw_thread, cw_block, cw_grid), f_hash2((v_ix + 1i), v_iy, 13i, cw_thread, cw_block, cw_grid), v_fx, cw_thread, cw_block, cw_grid), f_lerpf(f_hash2(v_ix, (v_iy + 1i), 13i, cw_thread, cw_block, cw_grid), f_hash2((v_ix + 1i), (v_iy + 1i), 13i, cw_thread, cw_block, cw_grid), v_fx, cw_thread, cw_block, cw_grid), v_fy, cw_thread, cw_block, cw_grid);
}
fn f_fbm2(cw_arg_x: f32, cw_arg_y: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_x: f32 = cw_arg_x;
  var v_y: f32 = cw_arg_y;
  var v_v: f32 = 0.0f;
  var v_a: f32 = 0.5f;
  {
    var v_i: i32 = 0i;
    loop {
      if (!(v_i < 5i)) { break; }
      v_v = (v_v + (f_noise2(v_x, v_y, cw_thread, cw_block, cw_grid) * v_a));
      v_x = ((v_x * 2.07f) + 11.7f);
      v_y = ((v_y * 2.03f) - 8.3f);
      v_a = (v_a * 0.5f);
      continuing {
        v_i += i32(1);
      }
    }
  }
  return v_v;
}
fn f_frequencyWeight(cw_arg_footprint: f32, cw_arg_freq: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_footprint: f32 = cw_arg_footprint;
  var v_freq: f32 = cw_arg_freq;
  return (1.0f - f_smoothf(0.35f, 1.1f, (v_footprint * v_freq), cw_thread, cw_block, cw_grid));
}
fn f_safeInv(cw_arg_d: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_d: f32 = cw_arg_d;
  var cw_tmp_2: f32;
  if ((abs(v_d) > 1e-7f)) {
    cw_tmp_2 = v_d;
  } else {
    var cw_tmp_1: f32;
    if ((v_d < 0.0f)) {
      cw_tmp_1 = (-1e-7f);
    } else {
      cw_tmp_1 = 1e-7f;
    }
    cw_tmp_2 = cw_tmp_1;
  }
  return cw_divide_f32(1.0f, cw_tmp_2);
}
fn f_boxRange(cw_arg_ro: vec3<f32>, cw_arg_rd: vec3<f32>, cw_arg_lo: vec3<f32>, cw_arg_hi: vec3<f32>, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec2<f32> {
  var v_ro: vec3<f32> = cw_arg_ro;
  var v_rd: vec3<f32> = cw_arg_rd;
  var v_lo: vec3<f32> = cw_arg_lo;
  var v_hi: vec3<f32> = cw_arg_hi;
  var v_a: vec3<f32> = vec3<f32>(((v_lo.x - v_ro.x) * f_safeInv(v_rd.x, cw_thread, cw_block, cw_grid)), ((v_lo.y - v_ro.y) * f_safeInv(v_rd.y, cw_thread, cw_block, cw_grid)), ((v_lo.z - v_ro.z) * f_safeInv(v_rd.z, cw_thread, cw_block, cw_grid)));
  var v_b: vec3<f32> = vec3<f32>(((v_hi.x - v_ro.x) * f_safeInv(v_rd.x, cw_thread, cw_block, cw_grid)), ((v_hi.y - v_ro.y) * f_safeInv(v_rd.y, cw_thread, cw_block, cw_grid)), ((v_hi.z - v_ro.z) * f_safeInv(v_rd.z, cw_thread, cw_block, cw_grid)));
  var v_mn: vec3<f32> = f_min3(v_a, v_b, cw_thread, cw_block, cw_grid);
  var v_mx: vec3<f32> = f_max3(v_a, v_b, cw_thread, cw_block, cw_grid);
  return vec2<f32>(max(max(v_mn.x, v_mn.y), v_mn.z), min(min(v_mx.x, v_mx.y), v_mx.z));
}
fn f_worldIndex(cw_arg_cx: i32, cw_arg_cz: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> i32 {
  var v_cx: i32 = cw_arg_cx;
  var v_cz: i32 = cw_arg_cz;
  return ((((v_cz + (64i / 2i)) * 64i) + v_cx) + (64i / 2i));
}
fn f_pageIndex(cw_arg_cx: i32, cw_arg_cz: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> i32 {
  var v_cx: i32 = cw_arg_cx;
  var v_cz: i32 = cw_arg_cz;
  return ((f_imod(v_cz, 16i, cw_thread, cw_block, cw_grid) * 16i) + f_imod(v_cx, 16i, cw_thread, cw_block, cw_grid));
}
fn f_inCity(cw_arg_cx: i32, cw_arg_cz: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> bool {
  var v_cx: i32 = cw_arg_cx;
  var v_cz: i32 = cw_arg_cz;
  return ((((v_cx >= ((-64i) / 2i)) && (v_cx < (64i / 2i))) && (v_cz >= ((-64i) / 2i))) && (v_cz < (64i / 2i)));
}
fn f_masonryUV(cw_arg_p: vec3<f32>, cw_arg_n: vec3<f32>, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec2<f32> {
  var v_p: vec3<f32> = cw_arg_p;
  var v_n: vec3<f32> = cw_arg_n;
  var cw_tmp_4: vec2<f32>;
  if ((abs(v_n.y) > 0.5f)) {
    cw_tmp_4 = vec2<f32>(v_p.x, v_p.z);
  } else {
    var cw_tmp_3: vec2<f32>;
    if ((abs(v_n.x) > 0.5f)) {
      cw_tmp_3 = vec2<f32>(v_p.z, v_p.y);
    } else {
      cw_tmp_3 = vec2<f32>(v_p.x, v_p.y);
    }
    cw_tmp_4 = cw_tmp_3;
  }
  return cw_tmp_4;
}
fn f_masonryHeight(cw_arg_u: f32, cw_arg_v: f32, cw_arg_material: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_u: f32 = cw_arg_u;
  var v_v: f32 = cw_arg_v;
  var v_material: i32 = cw_arg_material;
  var cw_tmp_5: f32;
  if ((v_material == 1i)) {
    cw_tmp_5 = 0.46f;
  } else {
    cw_tmp_5 = 0.92f;
  }
  var v_bw: f32 = cw_tmp_5;
  var cw_tmp_6: f32;
  if ((v_material == 1i)) {
    cw_tmp_6 = 0.215f;
  } else {
    cw_tmp_6 = 0.46f;
  }
  var v_bh: f32 = cw_tmp_6;
  var v_row: i32 = i32(floor(cw_divide_f32(v_v, v_bh)));
  var v_x: f32 = f_fractf((cw_divide_f32(v_u, v_bw) + (f32(f_imod(v_row, 2i, cw_thread, cw_block, cw_grid)) * 0.5f)), cw_thread, cw_block, cw_grid);
  var v_y: f32 = f_fractf(cw_divide_f32(v_v, v_bh), cw_thread, cw_block, cw_grid);
  var v_edge: f32 = min((min(v_x, (1.0f - v_x)) * v_bw), (min(v_y, (1.0f - v_y)) * v_bh));
  var v_grain: f32 = f_noise2((v_u * 24.0f), (v_v * 24.0f), cw_thread, cw_block, cw_grid);
  var v_chippedEdge: f32 = (v_edge - (0.006f * f_smoothf(0.34f, 0.73f, f_noise2((v_u * 117.0f), (v_v * 117.0f), cw_thread, cw_block, cw_grid), cw_thread, cw_block, cw_grid)));
  return (((-0.018f) * (1.0f - f_smoothf(0.008f, 0.023f, v_chippedEdge, cw_thread, cw_block, cw_grid))) + (0.0025f * v_grain));
}
fn f_spread10(cw_arg_x: u32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> u32 {
  var v_x: u32 = cw_arg_x;
  v_x = (v_x & 1023u);
  v_x = ((v_x | (v_x << u32(16i))) & 50331903u);
  v_x = ((v_x | (v_x << u32(8i))) & 50393103u);
  v_x = ((v_x | (v_x << u32(4i))) & 51130563u);
  v_x = ((v_x | (v_x << u32(2i))) & 153391689u);
  return v_x;
}
fn f_morton3(cw_arg_x: f32, cw_arg_y: f32, cw_arg_z: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> u32 {
  var v_x: f32 = cw_arg_x;
  var v_y: f32 = cw_arg_y;
  var v_z: f32 = cw_arg_z;
  var v_a: u32 = u32((f_sat(v_x, cw_thread, cw_block, cw_grid) * 1023.0f));
  var v_b: u32 = u32((f_sat(v_y, cw_thread, cw_block, cw_grid) * 1023.0f));
  var v_c: u32 = u32((f_sat(v_z, cw_thread, cw_block, cw_grid) * 1023.0f));
  return ((f_spread10(v_a, cw_thread, cw_block, cw_grid) | (f_spread10(v_b, cw_thread, cw_block, cw_grid) << u32(1i))) | (f_spread10(v_c, cw_thread, cw_block, cw_grid) << u32(2i)));
}
fn f_packRGBA(cw_arg_c: vec3<f32>, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> u32 {
  var v_c: vec3<f32> = cw_arg_c;
  var v_r: u32 = u32((f_sat(v_c.x, cw_thread, cw_block, cw_grid) * 255.0f));
  var v_g: u32 = u32((f_sat(v_c.y, cw_thread, cw_block, cw_grid) * 255.0f));
  var v_b: u32 = u32((f_sat(v_c.z, cw_thread, cw_block, cw_grid) * 255.0f));
  return (((v_r | (v_g << u32(8i))) | (v_b << u32(16i))) | 4278190080u);
}

@compute @workgroup_size(64, 1, 1)
fn main(
  @builtin(local_invocation_id) cw_thread: vec3<u32>,
  @builtin(workgroup_id) cw_block: vec3<u32>,
  @builtin(num_workgroups) cw_grid: vec3<u32>
) {
  var v_q: i32 = i32(((cw_block.x * cw_block_size.x) + cw_thread.x));
  if ((v_q >= b_Queue[0i])) {
    return;
  }
  var v_s: i32 = b_Queue[(v_q + 1i)];
  var v_m: i32 = (v_s * 12i);
  b_Meta[v_m] = b_Req[(v_s * 8i)];
  b_Meta[(v_m + 1i)] = b_Req[((v_s * 8i) + 1i)];
  b_Meta[(v_m + 2i)] = b_Req[((v_s * 8i) + 2i)];
  b_Meta[(v_m + 3i)] = 1.0f;
  var v_n: i32 = 0i;
  {
    var v_i: i32 = 0i;
    loop {
      if (!(v_i < 2048i)) { break; }
      if ((b_P[((((v_s * 2048i) + v_i) * 16i) + 3i)] >= 0.0f)) {
        v_n += i32(1);
      }
      continuing {
        v_i += i32(1);
      }
    }
  }
  b_Meta[(v_m + 4i)] = f32(v_n);
  b_Meta[(v_m + 5i)] = b_C[6i];
  b_Meta[(v_m + 6i)] = (b_Meta[(v_m + 6i)] + 1.0f);
}
