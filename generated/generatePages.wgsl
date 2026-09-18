// CUDA WebShader 0.1.0. Generated from kernel generatePages.
@group(0) @binding(0) var<storage, read> b_World: array<f32>;
@group(0) @binding(1) var<storage, read> b_Req: array<f32>;
@group(0) @binding(2) var<storage, read> b_Queue: array<i32>;
@group(0) @binding(3) var<storage, read_write> b_P: array<f32>;
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
fn f_cw_buffer_helper_0(cw_buffer_arg_0: i32, cw_arg_base: i32, cw_arg_n: i32, cw_arg_p: vec3<f32>, cw_arg_size: vec3<f32>, cw_arg_shape: i32, cw_arg_material: i32, cw_arg_turn: i32, cw_arg_seed: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> i32 {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_base: i32 = cw_arg_base;
  var v_n: i32 = cw_arg_n;
  var v_p: vec3<f32> = cw_arg_p;
  var v_size: vec3<f32> = cw_arg_size;
  var v_shape: i32 = cw_arg_shape;
  var v_material: i32 = cw_arg_material;
  var v_turn: i32 = cw_arg_turn;
  var v_seed: f32 = cw_arg_seed;
  if ((v_n >= 32i)) {
    return v_n;
  }
  var v_b: i32 = ((v_base + v_n) * 16i);
  b_P[(cw_buffer_offset_0 + v_b)] = v_p.x;
  b_P[(cw_buffer_offset_0 + (v_b + 1i))] = v_p.y;
  b_P[(cw_buffer_offset_0 + (v_b + 2i))] = v_p.z;
  b_P[(cw_buffer_offset_0 + (v_b + 3i))] = f32(v_shape);
  b_P[(cw_buffer_offset_0 + (v_b + 4i))] = v_size.x;
  b_P[(cw_buffer_offset_0 + (v_b + 5i))] = v_size.y;
  b_P[(cw_buffer_offset_0 + (v_b + 6i))] = v_size.z;
  b_P[(cw_buffer_offset_0 + (v_b + 7i))] = f32(v_material);
  b_P[(cw_buffer_offset_0 + (v_b + 8i))] = f32(v_turn);
  b_P[(cw_buffer_offset_0 + (v_b + 9i))] = v_seed;
  b_P[(cw_buffer_offset_0 + (v_b + 10i))] = 1.0f;
  b_P[(cw_buffer_offset_0 + (v_b + 11i))] = 0.0f;
  return (v_n + 1i);
}
fn f_cw_buffer_helper_1(cw_buffer_arg_0: i32, cw_arg_base: i32, cw_arg_n: i32, cw_arg_face: i32, cw_arg_cx: f32, cw_arg_cz: f32, cw_arg_w: f32, cw_arg_d: f32, cw_arg_u: f32, cw_arg_y: f32, cw_arg_out: f32, cw_arg_hw: f32, cw_arg_hy: f32, cw_arg_hd: f32, cw_arg_material: i32, cw_arg_seed: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> i32 {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_base: i32 = cw_arg_base;
  var v_n: i32 = cw_arg_n;
  var v_face: i32 = cw_arg_face;
  var v_cx: f32 = cw_arg_cx;
  var v_cz: f32 = cw_arg_cz;
  var v_w: f32 = cw_arg_w;
  var v_d: f32 = cw_arg_d;
  var v_u: f32 = cw_arg_u;
  var v_y: f32 = cw_arg_y;
  var v_out: f32 = cw_arg_out;
  var v_hw: f32 = cw_arg_hw;
  var v_hy: f32 = cw_arg_hy;
  var v_hd: f32 = cw_arg_hd;
  var v_material: i32 = cw_arg_material;
  var v_seed: f32 = cw_arg_seed;
  var v_p: vec3<f32> = vec3<f32>((v_cx + v_u), v_y, ((v_cz + v_d) + v_out));
  var v_h: vec3<f32> = vec3<f32>(v_hw, v_hy, v_hd);
  if ((v_face == 1i)) {
    v_p = vec3<f32>(((v_cx + v_w) + v_out), v_y, (v_cz + v_u));
    v_h = vec3<f32>(v_hd, v_hy, v_hw);
  }
  if ((v_face == 2i)) {
    v_p = vec3<f32>((v_cx + v_u), v_y, ((v_cz - v_d) - v_out));
  }
  if ((v_face == 3i)) {
    v_p = vec3<f32>(((v_cx - v_w) - v_out), v_y, (v_cz + v_u));
    v_h = vec3<f32>(v_hd, v_hy, v_hw);
  }
  return f_cw_buffer_helper_0((cw_buffer_offset_0 + 0i), v_base, v_n, v_p, v_h, 0i, v_material, 0i, v_seed, cw_thread, cw_block, cw_grid);
}

@compute @workgroup_size(64, 1, 1)
fn main(
  @builtin(local_invocation_id) cw_thread: vec3<u32>,
  @builtin(workgroup_id) cw_block: vec3<u32>,
  @builtin(num_workgroups) cw_grid: vec3<u32>
) {
  var v_q: i32 = i32(cw_block.x);
  var v_group: i32 = i32(cw_thread.x);
  if (((v_q >= b_Queue[0i]) || (v_group >= 64i))) {
    return;
  }
  var v_s: i32 = b_Queue[(v_q + 1i)];
  var v_base: i32 = ((v_s * 2048i) + (v_group * 32i));
  {
    var v_j: i32 = 0i;
    loop {
      if (!(v_j < 32i)) { break; }
      {
        var v_k: i32 = 0i;
        loop {
          if (!(v_k < 16i)) { break; }
          b_P[(((v_base + v_j) * 16i) + v_k)] = 0.0f;
          continuing {
            v_k += i32(1);
          }
        }
      }
      b_P[(((v_base + v_j) * 16i) + 3i)] = (-1.0f);
      b_P[(((v_base + v_j) * 16i) + 14i)] = f32(v_group);
      b_P[(((v_base + v_j) * 16i) + 15i)] = f32(v_s);
      continuing {
        v_j += i32(1);
      }
    }
  }
  var v_cx: i32 = i32(b_Req[(v_s * 8i)]);
  var v_cz: i32 = i32(b_Req[((v_s * 8i) + 1i)]);
  var v_lod: i32 = i32(b_Req[((v_s * 8i) + 2i)]);
  var v_wi: i32 = (f_worldIndex(v_cx, v_cz, cw_thread, cw_block, cw_grid) * 8i);
  var v_x: f32 = (f32(v_cx) * 36.0f);
  var v_z: f32 = (f32(v_cz) * 36.0f);
  var v_w: f32 = b_World[v_wi];
  var v_d: f32 = b_World[(v_wi + 1i)];
  var v_h: f32 = b_World[(v_wi + 2i)];
  var v_type: i32 = i32(b_World[(v_wi + 3i)]);
  var v_mat: i32 = i32(b_World[(v_wi + 4i)]);
  var v_floors: i32 = i32(b_World[(v_wi + 5i)]);
  var v_seed: f32 = b_World[(v_wi + 6i)];
  var v_n: i32 = 0i;
  if ((v_type == 4i)) {
    if (((f_imod(v_cz, 4i, cw_thread, cw_block, cw_grid) == 0i) && (v_group == 0i))) {
      v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_x, 0.25f, v_z), vec3<f32>(18.0f, 0.5f, 5.0f), 0i, 0i, 0i, v_seed, cw_thread, cw_block, cw_grid);
      v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_x, 1.25f, (v_z - 5.0f)), vec3<f32>(18.0f, 0.2f, 0.23f), 0i, 0i, 0i, v_seed, cw_thread, cw_block, cw_grid);
      v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_x, 1.25f, (v_z + 5.0f)), vec3<f32>(18.0f, 0.2f, 0.23f), 0i, 0i, 0i, v_seed, cw_thread, cw_block, cw_grid);
      {
        var v_k: i32 = 0i;
        loop {
          if (!(v_k < 12i)) { break; }
          var v_u: f32 = ((-16.5f) + (f32(v_k) * 3.0f));
          v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>((v_x + v_u), 0.8f, (v_z - 5.0f)), vec3<f32>(0.12f, 0.6f, 0.12f), 2i, 6i, 0i, v_seed, cw_thread, cw_block, cw_grid);
          v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>((v_x + v_u), 0.8f, (v_z + 5.0f)), vec3<f32>(0.12f, 0.6f, 0.12f), 2i, 6i, 0i, v_seed, cw_thread, cw_block, cw_grid);
          continuing {
            v_k += i32(1);
          }
        }
      }
    }
    return;
  }
  if ((v_type == 3i)) {
    if ((v_group == 0i)) {
      v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_x, (-0.12f), v_z), vec3<f32>(15.5f, 0.22f, 15.5f), 0i, 11i, 0i, v_seed, cw_thread, cw_block, cw_grid);
    }
    if (((v_group >= 1i) && (v_group <= 8i))) {
      var v_k: i32 = (v_group - 1i);
      var cw_tmp_7: f32;
      if ((v_k < 4i)) {
        cw_tmp_7 = (-10.0f);
      } else {
        cw_tmp_7 = 10.0f;
      }
      var v_tx: f32 = (v_x + cw_tmp_7);
      var v_tz: f32 = (v_z + ((f32((v_k % 4i)) - 1.5f) * 6.7f));
      var v_th: f32 = (5.0f + (f_hash1((i32(v_seed) + v_k), cw_thread, cw_block, cw_grid) * 3.0f));
      v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_tx, (v_th * 0.4f), v_tz), vec3<f32>(0.19f, (v_th * 0.4f), 0.19f), 2i, 15i, 0i, v_seed, cw_thread, cw_block, cw_grid);
      {
        var v_j: i32 = 0i;
        loop {
          if (!(v_j < 28i)) { break; }
          var v_a: f32 = (f32(v_j) * 2.4f);
          var v_yy: f32 = ((f_hash1(((i32(v_seed) + v_j) + 991i), cw_thread, cw_block, cw_grid) * 3.3f) - 0.5f);
          var v_rr: f32 = ((sqrt(f_hash1(((i32(v_seed) + v_j) + 330i), cw_thread, cw_block, cw_grid)) * 2.1f) * (1.0f - (v_yy * 0.12f)));
          var v_size: f32 = (0.48f + (f_hash1(((i32(v_seed) + v_j) + 62i), cw_thread, cw_block, cw_grid) * 0.3f));
          v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>((v_tx + (cos(v_a) * v_rr)), (v_th + v_yy), (v_tz + (sin(v_a) * v_rr))), vec3<f32>(v_size, (v_size * 1.25f), v_size), 1i, 7i, 0i, (v_seed + f32(v_j)), cw_thread, cw_block, cw_grid);
          continuing {
            v_j += i32(1);
          }
        }
      }
    }
    if ((v_group == 9i)) {
      v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_x, 0.8f, v_z), vec3<f32>(3.6f, 0.45f, 3.6f), 2i, 0i, 0i, v_seed, cw_thread, cw_block, cw_grid);
      v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_x, 1.24f, v_z), vec3<f32>(3.3f, 0.04f, 3.3f), 2i, 9i, 0i, v_seed, cw_thread, cw_block, cw_grid);
      v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_x, 2.0f, v_z), vec3<f32>(0.65f, 1.0f, 0.65f), 2i, 0i, 0i, v_seed, cw_thread, cw_block, cw_grid);
      v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_x, 2.85f, v_z), vec3<f32>(1.4f, 0.18f, 1.4f), 2i, 13i, 0i, v_seed, cw_thread, cw_block, cw_grid);
      v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_x, 3.15f, v_z), vec3<f32>(0.5f, 0.5f, 0.5f), 1i, 3i, 0i, v_seed, cw_thread, cw_block, cw_grid);
    }
    return;
  }
  if ((v_group == 0i)) {
    v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_x, 0.15f, v_z), vec3<f32>((v_w + 1.1f), 0.25f, (v_d + 1.1f)), 0i, 0i, 0i, v_seed, cw_thread, cw_block, cw_grid);
    v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_x, ((v_h + 4.0f) * 0.5f), v_z), vec3<f32>(v_w, ((v_h - 4.0f) * 0.5f), v_d), 0i, v_mat, 0i, v_seed, cw_thread, cw_block, cw_grid);
    v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_x, 4.0f, v_z), vec3<f32>((v_w + 0.24f), 0.24f, (v_d + 0.24f)), 0i, 13i, 0i, v_seed, cw_thread, cw_block, cw_grid);
    v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_x, 1.9f, v_z), vec3<f32>((v_w - 3.5f), 1.9f, (v_d - 3.5f)), 0i, 5i, 0i, v_seed, cw_thread, cw_block, cw_grid);
    {
      var v_f: i32 = 0i;
      loop {
        if (!(v_f < 4i)) { break; }
        {
          var v_k: i32 = 0i;
          loop {
            if (!(v_k < 3i)) { break; }
            var cw_tmp_8: f32;
            if (((v_f % 2i) == 0i)) {
              cw_tmp_8 = v_w;
            } else {
              cw_tmp_8 = v_d;
            }
            var v_ext: f32 = (cw_tmp_8 - 0.65f);
            var v_u: f32 = ((f32(v_k) - 1.0f) * v_ext);
            var cw_tmp_10: f32;
            if (((v_f % 2i) == 0i)) {
              cw_tmp_10 = (v_x + v_u);
            } else {
              var cw_tmp_9: f32;
              if ((v_f == 1i)) {
                cw_tmp_9 = (v_w - 0.5f);
              } else {
                cw_tmp_9 = ((-v_w) + 0.5f);
              }
              cw_tmp_10 = (v_x + cw_tmp_9);
            }
            var v_px: f32 = cw_tmp_10;
            var cw_tmp_12: f32;
            if (((v_f % 2i) == 0i)) {
              var cw_tmp_11: f32;
              if ((v_f == 0i)) {
                cw_tmp_11 = (v_d - 0.5f);
              } else {
                cw_tmp_11 = ((-v_d) + 0.5f);
              }
              cw_tmp_12 = (v_z + cw_tmp_11);
            } else {
              cw_tmp_12 = (v_z + v_u);
            }
            var v_pz: f32 = cw_tmp_12;
            v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_px, 2.0f, v_pz), vec3<f32>(0.38f, 1.75f, 0.38f), 2i, 0i, 0i, (v_seed + f32(v_k)), cw_thread, cw_block, cw_grid);
            v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_px, 3.66f, v_pz), vec3<f32>(0.64f, 0.18f, 0.64f), 0i, 13i, 0i, v_seed, cw_thread, cw_block, cw_grid);
            continuing {
              v_k += i32(1);
            }
          }
        }
        continuing {
          v_f += i32(1);
        }
      }
    }
  }
  if ((v_group == 1i)) {
    v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_x, (v_h + 0.25f), v_z), vec3<f32>((v_w + 0.6f), 0.24f, (v_d + 0.6f)), 0i, 13i, 0i, v_seed, cw_thread, cw_block, cw_grid);
    if ((v_type == 0i)) {
      var cw_tmp_13: i32;
      if ((f_hash1(i32(v_seed), cw_thread, cw_block, cw_grid) > 0.5f)) {
        cw_tmp_13 = 14i;
      } else {
        cw_tmp_13 = 2i;
      }
      var v_roofmat: i32 = cw_tmp_13;
      v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_x, (v_h + 0.35f), v_z), vec3<f32>((v_w + 0.45f), 4.4f, (v_d + 0.45f)), 3i, v_roofmat, 0i, v_seed, cw_thread, cw_block, cw_grid);
      v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_x, (v_h + 4.8f), v_z), vec3<f32>(0.12f, 0.14f, (v_d + 0.7f)), 0i, 3i, 0i, v_seed, cw_thread, cw_block, cw_grid);
      {
        var v_k: i32 = 0i;
        loop {
          if (!(v_k < 4i)) { break; }
          var cw_tmp_14: f32;
          if (((v_k % 2i) == 0i)) {
            cw_tmp_14 = ((-v_w) * 0.52f);
          } else {
            cw_tmp_14 = (v_w * 0.52f);
          }
          var v_xx: f32 = (v_x + cw_tmp_14);
          var v_zz: f32 = (v_z + ((f32((v_k / 2i)) - 0.5f) * v_d));
          v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_xx, (v_h + 3.8f), v_zz), vec3<f32>(0.48f, 2.2f, 0.55f), 0i, 1i, 0i, v_seed, cw_thread, cw_block, cw_grid);
          v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_xx, (v_h + 6.0f), v_zz), vec3<f32>(0.66f, 0.17f, 0.72f), 0i, 0i, 0i, v_seed, cw_thread, cw_block, cw_grid);
          if ((v_lod >= 2i)) {
            v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_xx, (v_h + 6.32f), v_zz), vec3<f32>(0.2f, 0.25f, 0.2f), 2i, 14i, 0i, v_seed, cw_thread, cw_block, cw_grid);
          }
          continuing {
            v_k += i32(1);
          }
        }
      }
    } else {
      if ((v_type == 1i)) {
        v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_x, (v_h + 2.2f), v_z), vec3<f32>((v_w * 0.72f), 2.0f, (v_w * 0.72f)), 2i, 0i, 0i, v_seed, cw_thread, cw_block, cw_grid);
        v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_x, (v_h + 3.1f), v_z), vec3<f32>((v_w * 0.79f), 8.4f, (v_w * 0.79f)), 1i, 3i, 0i, v_seed, cw_thread, cw_block, cw_grid);
        v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_x, (v_h + 12.2f), v_z), vec3<f32>(0.24f, 1.45f, 0.24f), 2i, 6i, 0i, v_seed, cw_thread, cw_block, cw_grid);
        v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_x, (v_h + 13.8f), v_z), vec3<f32>(0.6f, 0.6f, 0.6f), 1i, 8i, 0i, v_seed, cw_thread, cw_block, cw_grid);
      } else {
        v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_x, (v_h + 0.4f), v_z), vec3<f32>((v_w * 0.72f), 5.2f, (v_d + 0.2f)), 3i, 2i, 0i, v_seed, cw_thread, cw_block, cw_grid);
        {
          var v_k: i32 = 0i;
          loop {
            if (!(v_k < 2i)) { break; }
            var cw_tmp_15: f32;
            if ((v_k == 0i)) {
              cw_tmp_15 = ((-v_w) * 0.75f);
            } else {
              cw_tmp_15 = (v_w * 0.75f);
            }
            var v_xx: f32 = (v_x + cw_tmp_15);
            var v_zz: f32 = (v_z + (v_d * 0.6f));
            v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_xx, (v_h + 3.5f), v_zz), vec3<f32>(2.3f, 7.2f, 2.3f), 0i, 0i, 0i, v_seed, cw_thread, cw_block, cw_grid);
            v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_xx, (v_h + 10.9f), v_zz), vec3<f32>(2.65f, 0.35f, 2.65f), 0i, 13i, 0i, v_seed, cw_thread, cw_block, cw_grid);
            v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_xx, (v_h + 11.2f), v_zz), vec3<f32>(2.55f, 4.4f, 2.55f), 3i, 3i, 0i, v_seed, cw_thread, cw_block, cw_grid);
            v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_xx, (v_h + 16.0f), v_zz), vec3<f32>(0.17f, 1.2f, 0.17f), 2i, 8i, 0i, v_seed, cw_thread, cw_block, cw_grid);
            {
              var v_j: i32 = 0i;
              loop {
                if (!(v_j < 4i)) { break; }
                var v_a: f32 = ((f32(v_j) * 3.141592653589793f) * 0.5f);
                v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>((v_xx + (cos(v_a) * 2.2f)), (v_h + 12.0f), (v_zz + (sin(v_a) * 2.2f))), vec3<f32>(0.17f, 1.1f, 0.17f), 2i, 0i, 0i, v_seed, cw_thread, cw_block, cw_grid);
                continuing {
                  v_j += i32(1);
                }
              }
            }
            continuing {
              v_k += i32(1);
            }
          }
        }
      }
    }
  }
  if (((v_group >= 2i) && (v_group <= 5i))) {
    var v_face: i32 = (v_group - 2i);
    var cw_tmp_16: f32;
    if (((v_face % 2i) == 0i)) {
      cw_tmp_16 = v_w;
    } else {
      cw_tmp_16 = v_d;
    }
    var v_ext: f32 = cw_tmp_16;
    {
      var v_j: i32 = 0i;
      loop {
        if (!(v_j <= v_floors)) { break; }
        var v_y: f32 = (4.2f + (f32(v_j) * 3.8f));
        v_n = f_cw_buffer_helper_1(0i, v_base, v_n, v_face, v_x, v_z, v_w, v_d, 0.0f, v_y, 0.17f, (v_ext + 0.15f), 0.11f, 0.22f, 13i, v_seed, cw_thread, cw_block, cw_grid);
        if ((v_lod >= 2i)) {
          v_n = f_cw_buffer_helper_1(0i, v_base, v_n, v_face, v_x, v_z, v_w, v_d, 0.0f, (v_y + 0.21f), 0.1f, (v_ext + 0.1f), 0.052f, 0.16f, 0i, v_seed, cw_thread, cw_block, cw_grid);
        }
        continuing {
          v_j += i32(1);
        }
      }
    }
    {
      var v_j: i32 = 0i;
      loop {
        if (!(v_j < 5i)) { break; }
        var v_u: f32 = (((cw_divide_f32(f32(v_j), 4.0f) * 2.0f) - 1.0f) * (v_ext - 0.3f));
        if ((v_lod >= 2i)) {
          v_n = f_cw_buffer_helper_1(0i, v_base, v_n, v_face, v_x, v_z, v_w, v_d, v_u, ((v_h + 4.0f) * 0.5f), 0.16f, 0.19f, ((v_h - 4.0f) * 0.5f), 0.22f, 13i, v_seed, cw_thread, cw_block, cw_grid);
        }
        continuing {
          v_j += i32(1);
        }
      }
    }
    if ((v_lod >= 3i)) {
      {
        var v_j: i32 = 0i;
        loop {
          if (!(v_j < 8i)) { break; }
          var v_u: f32 = ((f32(v_j) - 3.5f) * cw_divide_f32(v_ext, 4.0f));
          v_n = f_cw_buffer_helper_1(0i, v_base, v_n, v_face, v_x, v_z, v_w, v_d, v_u, (v_h - 0.24f), 0.4f, 0.15f, 0.12f, 0.19f, 13i, v_seed, cw_thread, cw_block, cw_grid);
          continuing {
            v_j += i32(1);
          }
        }
      }
    }
  }
  if (((v_group >= 6i) && (v_group < 30i))) {
    var v_face: i32 = ((v_group - 6i) / 6i);
    var v_row: i32 = ((v_group - 6i) % 6i);
    if ((v_row >= v_floors)) {
      return;
    }
    var cw_tmp_17: f32;
    if (((v_face % 2i) == 0i)) {
      cw_tmp_17 = v_w;
    } else {
      cw_tmp_17 = v_d;
    }
    var v_ext: f32 = cw_tmp_17;
    var v_y: f32 = (6.1f + (f32(v_row) * 3.8f));
    {
      var v_j: i32 = 0i;
      loop {
        if (!(v_j < 4i)) { break; }
        var v_u: f32 = ((f32(v_j) - 1.5f) * (v_ext * 0.48f));
        var v_wy: f32 = 1.2f;
        v_n = f_cw_buffer_helper_1(0i, v_base, v_n, v_face, v_x, v_z, v_w, v_d, v_u, v_y, 0.032f, 0.91f, v_wy, 0.045f, 4i, (v_seed + f32((((v_row * 17i) + (v_j * 9i)) + (v_face * 59i)))), cw_thread, cw_block, cw_grid);
        v_n = f_cw_buffer_helper_1(0i, v_base, v_n, v_face, v_x, v_z, v_w, v_d, v_u, ((v_y - v_wy) - 0.13f), 0.22f, 1.13f, 0.14f, 0.29f, 13i, v_seed, cw_thread, cw_block, cw_grid);
        if ((v_lod >= 2i)) {
          v_n = f_cw_buffer_helper_1(0i, v_base, v_n, v_face, v_x, v_z, v_w, v_d, v_u, ((v_y + v_wy) + 0.12f), 0.18f, 1.11f, 0.14f, 0.23f, 13i, v_seed, cw_thread, cw_block, cw_grid);
          v_n = f_cw_buffer_helper_1(0i, v_base, v_n, v_face, v_x, v_z, v_w, v_d, (v_u - 1.02f), v_y, 0.12f, 0.11f, v_wy, 0.17f, 13i, v_seed, cw_thread, cw_block, cw_grid);
          v_n = f_cw_buffer_helper_1(0i, v_base, v_n, v_face, v_x, v_z, v_w, v_d, (v_u + 1.02f), v_y, 0.12f, 0.11f, v_wy, 0.17f, 13i, v_seed, cw_thread, cw_block, cw_grid);
          v_n = f_cw_buffer_helper_1(0i, v_base, v_n, v_face, v_x, v_z, v_w, v_d, v_u, v_y, 0.12f, 0.044f, v_wy, 0.08f, 5i, v_seed, cw_thread, cw_block, cw_grid);
        }
        if ((v_lod >= 3i)) {
          v_n = f_cw_buffer_helper_1(0i, v_base, v_n, v_face, v_x, v_z, v_w, v_d, v_u, (v_y + 0.3f), 0.12f, 0.94f, 0.035f, 0.08f, 5i, v_seed, cw_thread, cw_block, cw_grid);
          v_n = f_cw_buffer_helper_1(0i, v_base, v_n, v_face, v_x, v_z, v_w, v_d, v_u, ((v_y - v_wy) + 0.46f), 0.56f, 1.1f, 0.035f, 0.035f, 6i, v_seed, cw_thread, cw_block, cw_grid);
        }
        continuing {
          v_j += i32(1);
        }
      }
    }
  }
  if (((v_group == 30i) && (v_lod >= 2i))) {
    {
      var v_k: i32 = 0i;
      loop {
        if (!(v_k < 2i)) { break; }
        var cw_tmp_18: f32;
        if ((v_k == 0i)) {
          cw_tmp_18 = (-16.0f);
        } else {
          cw_tmp_18 = 16.0f;
        }
        var v_px: f32 = (v_x + cw_tmp_18);
        var v_pz: f32 = (v_z + 15.9f);
        v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_px, 2.0f, v_pz), vec3<f32>(0.068f, 2.0f, 0.068f), 2i, 6i, 0i, v_seed, cw_thread, cw_block, cw_grid);
        v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_px, 4.0f, v_pz), vec3<f32>(0.29f, 0.38f, 0.29f), 0i, 8i, 0i, v_seed, cw_thread, cw_block, cw_grid);
        v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_px, 4.44f, v_pz), vec3<f32>(0.37f, 0.1f, 0.37f), 3i, 6i, 0i, v_seed, cw_thread, cw_block, cw_grid);
        v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_px, 0.15f, v_pz), vec3<f32>(0.27f, 0.18f, 0.27f), 2i, 0i, 0i, v_seed, cw_thread, cw_block, cw_grid);
        continuing {
          v_k += i32(1);
        }
      }
    }
    {
      var v_k: i32 = 0i;
      loop {
        if (!(v_k < 8i)) { break; }
        v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>((v_x - 14.9f), 0.43f, ((v_z - 12.0f) + (f32(v_k) * 3.3f))), vec3<f32>(0.1f, 0.43f, 0.1f), 2i, 6i, 0i, v_seed, cw_thread, cw_block, cw_grid);
        continuing {
          v_k += i32(1);
        }
      }
    }
    {
      var v_face: i32 = 0i;
      loop {
        if (!(v_face < 4i)) { break; }
        {
          var v_k: i32 = 0i;
          loop {
            if (!(v_k < 2i)) { break; }
            var cw_tmp_19: f32;
            if (((v_face % 2i) == 0i)) {
              cw_tmp_19 = v_w;
            } else {
              cw_tmp_19 = v_d;
            }
            var v_ext: f32 = (cw_tmp_19 - 0.65f);
            var cw_tmp_20: f32;
            if ((v_k == 0i)) {
              cw_tmp_20 = (-0.5f);
            } else {
              cw_tmp_20 = 0.5f;
            }
            var v_u: f32 = (cw_tmp_20 * v_ext);
            var cw_tmp_21: f32;
            if ((v_face == 0i)) {
              cw_tmp_21 = (v_d - 0.5f);
            } else {
              cw_tmp_21 = ((-v_d) + 0.5f);
            }
            var v_centre: vec3<f32> = vec3<f32>((v_x + v_u), 3.16f, (v_z + cw_tmp_21));
            if (((v_face % 2i) == 1i)) {
              var cw_tmp_22: f32;
              if ((v_face == 1i)) {
                cw_tmp_22 = (v_w - 0.5f);
              } else {
                cw_tmp_22 = ((-v_w) + 0.5f);
              }
              v_centre = vec3<f32>((v_x + cw_tmp_22), 3.16f, (v_z + v_u));
            }
            v_n = f_cw_buffer_helper_0(0i, v_base, v_n, v_centre, vec3<f32>((v_ext * 0.5f), 0.88f, 0.49f), 4i, 13i, (v_face % 2i), v_seed, cw_thread, cw_block, cw_grid);
            continuing {
              v_k += i32(1);
            }
          }
        }
        continuing {
          v_face += i32(1);
        }
      }
    }
  }
  if (((v_group == 31i) && (v_lod >= 2i))) {
    if ((v_type == 0i)) {
      {
        var v_k: i32 = 0i;
        loop {
          if (!(v_k < 4i)) { break; }
          var cw_tmp_23: f32;
          if (((v_k % 2i) == 0i)) {
            cw_tmp_23 = ((-v_w) * 0.68f);
          } else {
            cw_tmp_23 = (v_w * 0.68f);
          }
          var v_xx: f32 = (v_x + cw_tmp_23);
          var v_zz: f32 = (v_z + (((f32((v_k / 2i)) - 0.5f) * v_d) * 0.96f));
          v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_xx, (v_h + 2.5f), v_zz), vec3<f32>(1.35f, 1.05f, 1.05f), 0i, 0i, 0i, v_seed, cw_thread, cw_block, cw_grid);
          v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_xx, (v_h + 3.55f), v_zz), vec3<f32>(1.45f, 1.0f, 1.2f), 3i, 2i, 1i, v_seed, cw_thread, cw_block, cw_grid);
          var cw_tmp_24: f32;
          if (((v_k % 2i) == 0i)) {
            cw_tmp_24 = (-1.36f);
          } else {
            cw_tmp_24 = 1.36f;
          }
          v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>((v_xx + cw_tmp_24), (v_h + 2.5f), v_zz), vec3<f32>(0.035f, 0.7f, 0.65f), 0i, 4i, 0i, v_seed, cw_thread, cw_block, cw_grid);
          continuing {
            v_k += i32(1);
          }
        }
      }
    }
    {
      var v_face: i32 = 0i;
      loop {
        if (!(v_face < 4i)) { break; }
        v_n = f_cw_buffer_helper_1(0i, v_base, v_n, v_face, v_x, v_z, (v_w - 3.5f), (v_d - 3.5f), 0.0f, 1.6f, 0.045f, 1.05f, 1.4f, 0.055f, 4i, v_seed, cw_thread, cw_block, cw_grid);
        v_n = f_cw_buffer_helper_1(0i, v_base, v_n, v_face, v_x, v_z, (v_w - 3.5f), (v_d - 3.5f), 0.0f, 3.13f, 0.09f, 1.25f, 0.15f, 0.12f, 13i, v_seed, cw_thread, cw_block, cw_grid);
        v_n = f_cw_buffer_helper_1(0i, v_base, v_n, v_face, v_x, v_z, (v_w - 3.5f), (v_d - 3.5f), 0.0f, 0.18f, 0.18f, 1.25f, 0.1f, 0.35f, 0i, v_seed, cw_thread, cw_block, cw_grid);
        continuing {
          v_face += i32(1);
        }
      }
    }
    {
      var v_k: i32 = 0i;
      loop {
        if (!(v_k < 3i)) { break; }
        var v_xx: f32 = (v_x + ((f32(v_k) - 1.0f) * 7.0f));
        v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_xx, 0.48f, ((v_z + v_d) + 1.5f)), vec3<f32>(0.52f, 0.42f, 0.52f), 2i, 14i, 0i, v_seed, cw_thread, cw_block, cw_grid);
        v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_xx, 1.13f, ((v_z + v_d) + 1.5f)), vec3<f32>(0.7f, 0.8f, 0.7f), 1i, 7i, 0i, (v_seed + f32(v_k)), cw_thread, cw_block, cw_grid);
        continuing {
          v_k += i32(1);
        }
      }
    }
  }
  if ((((v_group >= 32i) && (v_group < 56i)) && (v_lod >= 2i))) {
    var v_face: i32 = ((v_group - 32i) / 6i);
    var v_row: i32 = ((v_group - 32i) % 6i);
    if ((v_row >= v_floors)) {
      return;
    }
    var cw_tmp_25: f32;
    if (((v_face % 2i) == 0i)) {
      cw_tmp_25 = v_w;
    } else {
      cw_tmp_25 = v_d;
    }
    var v_ext: f32 = cw_tmp_25;
    var v_y: f32 = (6.1f + (f32(v_row) * 3.8f));
    {
      var v_j: i32 = 0i;
      loop {
        if (!(v_j < 4i)) { break; }
        var v_u: f32 = ((f32(v_j) - 1.5f) * (v_ext * 0.48f));
        v_n = f_cw_buffer_helper_1(0i, v_base, v_n, v_face, v_x, v_z, v_w, v_d, v_u, (v_y - 1.18f), 0.56f, 1.16f, 0.085f, 0.65f, 13i, v_seed, cw_thread, cw_block, cw_grid);
        v_n = f_cw_buffer_helper_1(0i, v_base, v_n, v_face, v_x, v_z, v_w, v_d, v_u, (v_y - 0.28f), 1.12f, 1.15f, 0.035f, 0.035f, 6i, v_seed, cw_thread, cw_block, cw_grid);
        if ((v_lod >= 3i)) {
          v_n = f_cw_buffer_helper_1(0i, v_base, v_n, v_face, v_x, v_z, v_w, v_d, v_u, (v_y - 1.0f), 1.12f, 1.15f, 0.026f, 0.026f, 6i, v_seed, cw_thread, cw_block, cw_grid);
          {
            var v_k: i32 = 0i;
            loop {
              if (!(v_k < 5i)) { break; }
              v_n = f_cw_buffer_helper_1(0i, v_base, v_n, v_face, v_x, v_z, v_w, v_d, (v_u + ((f32(v_k) - 2.0f) * 0.53f)), (v_y - 0.64f), 1.12f, 0.025f, 0.37f, 0.026f, 6i, v_seed, cw_thread, cw_block, cw_grid);
              continuing {
                v_k += i32(1);
              }
            }
          }
        }
        continuing {
          v_j += i32(1);
        }
      }
    }
  }
  if ((((v_group >= 56i) && (v_group < 60i)) && (v_lod >= 2i))) {
    var v_face: i32 = (v_group - 56i);
    var cw_tmp_26: f32;
    if (((v_face % 2i) == 0i)) {
      cw_tmp_26 = v_w;
    } else {
      cw_tmp_26 = v_d;
    }
    var v_ext: f32 = cw_tmp_26;
    {
      var v_k: i32 = 0i;
      loop {
        if (!(v_k < 14i)) { break; }
        var v_yy: f32 = (4.45f + cw_divide_f32((f32(v_k) * (v_h - 4.0f)), 14.0f));
        var cw_tmp_27: f32;
        if (((v_k % 2i) == 0i)) {
          cw_tmp_27 = 0.52f;
        } else {
          cw_tmp_27 = 0.3f;
        }
        var v_width: f32 = cw_tmp_27;
        v_n = f_cw_buffer_helper_1(0i, v_base, v_n, v_face, v_x, v_z, v_w, v_d, ((-v_ext) + v_width), v_yy, 0.12f, v_width, 0.16f, 0.16f, 0i, v_seed, cw_thread, cw_block, cw_grid);
        v_n = f_cw_buffer_helper_1(0i, v_base, v_n, v_face, v_x, v_z, v_w, v_d, (v_ext - v_width), v_yy, 0.12f, v_width, 0.16f, 0.16f, 0i, v_seed, cw_thread, cw_block, cw_grid);
        continuing {
          v_k += i32(1);
        }
      }
    }
    if ((v_type == 2i)) {
      var cw_tmp_28: f32;
      if ((v_face == 0i)) {
        cw_tmp_28 = (v_d + 0.21f);
      } else {
        cw_tmp_28 = ((-v_d) - 0.21f);
      }
      var v_centre: vec3<f32> = vec3<f32>(v_x, (v_h - 2.3f), (v_z + cw_tmp_28));
      if (((v_face % 2i) == 1i)) {
        var cw_tmp_29: f32;
        if ((v_face == 1i)) {
          cw_tmp_29 = (v_w + 0.21f);
        } else {
          cw_tmp_29 = ((-v_w) - 0.21f);
        }
        v_centre = vec3<f32>((v_x + cw_tmp_29), (v_h - 2.3f), v_z);
      }
      v_n = f_cw_buffer_helper_0(0i, v_base, v_n, v_centre, vec3<f32>(2.35f, 2.35f, 0.26f), 7i, 13i, (v_face % 2i), v_seed, cw_thread, cw_block, cw_grid);
      v_n = f_cw_buffer_helper_0(0i, v_base, v_n, v_centre, vec3<f32>(1.85f, 1.85f, 0.032f), 1i, 17i, (v_face % 2i), v_seed, cw_thread, cw_block, cw_grid);
    }
  }
  if (((((v_group == 60i) || (v_group == 61i)) && (v_lod >= 3i)) && (v_type == 0i))) {
    var v_side: i32 = (v_group - 60i);
    var cw_tmp_30: i32;
    if ((f_hash1(i32(v_seed), cw_thread, cw_block, cw_grid) > 0.5f)) {
      cw_tmp_30 = 14i;
    } else {
      cw_tmp_30 = 2i;
    }
    var v_roofmat: i32 = cw_tmp_30;
    {
      var v_j: i32 = 0i;
      loop {
        if (!(v_j < 32i)) { break; }
        var v_zz: f32 = ((v_z - v_d) + cw_divide_f32(((f32((v_j + (v_side * 32i))) + 0.5f) * v_d), 32.0f));
        v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>(v_x, (v_h + 0.395f), v_zz), vec3<f32>((v_w + 0.46f), 4.42f, 0.023f), 3i, v_roofmat, 0i, v_seed, cw_thread, cw_block, cw_grid);
        continuing {
          v_j += i32(1);
        }
      }
    }
  }
  if (((v_group == 62i) && (v_lod >= 2i))) {
    {
      var v_side: i32 = 0i;
      loop {
        if (!(v_side < 2i)) { break; }
        {
          var v_k: i32 = 0i;
          loop {
            if (!(v_k < 16i)) { break; }
            var v_u: f32 = ((-15.5f) + (f32(v_k) * 2.0f));
            var cw_tmp_31: f32;
            if ((v_side == 0i)) {
              cw_tmp_31 = (-16.3f);
            } else {
              cw_tmp_31 = 16.3f;
            }
            v_n = f_cw_buffer_helper_0(0i, v_base, v_n, vec3<f32>((v_x + v_u), 0.16f, (v_z + cw_tmp_31)), vec3<f32>(0.98f, 0.19f, 0.19f), 0i, 0i, 0i, v_seed, cw_thread, cw_block, cw_grid);
            continuing {
              v_k += i32(1);
            }
          }
        }
        continuing {
          v_side += i32(1);
        }
      }
    }
  }
  if (((v_group == 63i) && (v_lod >= 3i))) {
    {
      var v_face: i32 = 0i;
      loop {
        if (!(v_face < 4i)) { break; }
        {
          var v_k: i32 = 0i;
          loop {
            if (!(v_k < 8i)) { break; }
            var cw_tmp_32: f32;
            if (((v_face % 2i) == 0i)) {
              cw_tmp_32 = v_w;
            } else {
              cw_tmp_32 = v_d;
            }
            var v_ext: f32 = cw_tmp_32;
            var v_u: f32 = (((f32(v_k) - 3.5f) * v_ext) * 0.25f);
            v_n = f_cw_buffer_helper_1(0i, v_base, v_n, v_face, v_x, v_z, v_w, v_d, v_u, (v_h - 0.36f), 0.48f, 0.12f, 0.24f, 0.24f, 13i, v_seed, cw_thread, cw_block, cw_grid);
            continuing {
              v_k += i32(1);
            }
          }
        }
        continuing {
          v_face += i32(1);
        }
      }
    }
  }
}
