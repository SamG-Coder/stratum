// CUDA WebShader 0.1.0. Generated from kernel tracePrimary.
@group(0) @binding(0) var<storage, read> b_World: array<f32>;
@group(0) @binding(1) var<storage, read> b_Meta: array<f32>;
@group(0) @binding(2) var<storage, read> b_P: array<f32>;
@group(0) @binding(3) var<storage, read> b_Nodes: array<f32>;
@group(0) @binding(4) var<storage, read> b_Order: array<i32>;
@group(0) @binding(5) var<storage, read> b_C: array<f32>;
@group(0) @binding(6) var<storage, read_write> b_Hit: array<f32>;
struct CWParams {
  p_width: i32,
  p_height: i32,
  cw_pad_8: u32,
  cw_pad_12: u32,
}
@group(0) @binding(7) var<uniform> cw_params: CWParams;
const cw_block_size: vec3<u32> = vec3<u32>(8u, 8u, 1u);

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
fn f_localPoint(cw_arg_p: vec3<f32>, cw_arg_turn: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var v_p: vec3<f32> = cw_arg_p;
  var v_turn: i32 = cw_arg_turn;
  if (((v_turn % 2i) == 1i)) {
    return vec3<f32>(v_p.z, v_p.y, (-v_p.x));
  }
  return v_p;
}
fn f_worldNormal(cw_arg_p: vec3<f32>, cw_arg_turn: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var v_p: vec3<f32> = cw_arg_p;
  var v_turn: i32 = cw_arg_turn;
  if (((v_turn % 2i) == 1i)) {
    return vec3<f32>((-v_p.z), v_p.y, v_p.x);
  }
  return v_p;
}
fn f_leafNormal(cw_arg_x: i32, cw_arg_y: i32, cw_arg_z: i32, cw_arg_seed: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var v_x: i32 = cw_arg_x;
  var v_y: i32 = cw_arg_y;
  var v_z: i32 = cw_arg_z;
  var v_seed: i32 = cw_arg_seed;
  return f_norm3(vec3<f32>((f_hash2((v_x + (v_y * 19i)), v_z, v_seed, cw_thread, cw_block, cw_grid) - 0.5f), (0.25f + (f_hash2((v_x - v_y), (v_z + 91i), v_seed, cw_thread, cw_block, cw_grid) * 0.7f)), (f_hash2((v_z + (v_y * 31i)), v_x, (v_seed + 17i), cw_thread, cw_block, cw_grid) - 0.5f)), cw_thread, cw_block, cw_grid);
}
fn f_foliageHit(cw_arg_ro: vec3<f32>, cw_arg_rd: vec3<f32>, cw_arg_centre: vec3<f32>, cw_arg_radius: vec3<f32>, cw_arg_seed: i32, cw_arg_begin: f32, cw_arg_end: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_ro: vec3<f32> = cw_arg_ro;
  var v_rd: vec3<f32> = cw_arg_rd;
  var v_centre: vec3<f32> = cw_arg_centre;
  var v_radius: vec3<f32> = cw_arg_radius;
  var v_seed: i32 = cw_arg_seed;
  var v_begin: f32 = cw_arg_begin;
  var v_end: f32 = cw_arg_end;
  let v_step: f32 = 0.18f;
  var v_t: f32 = (max(0.001f, v_begin) + 0.0001f);
  var v_pos: vec3<f32> = (v_ro + (v_rd * vec3<f32>(v_t)));
  var v_ix: i32 = i32(floor(cw_divide_f32(v_pos.x, v_step)));
  var v_iy: i32 = i32(floor(cw_divide_f32(v_pos.y, v_step)));
  var v_iz: i32 = i32(floor(cw_divide_f32(v_pos.z, v_step)));
  var cw_tmp_7: i32;
  if ((v_rd.x > 0.0f)) {
    cw_tmp_7 = 1i;
  } else {
    cw_tmp_7 = (-1i);
  }
  var v_sx: i32 = cw_tmp_7;
  var cw_tmp_8: i32;
  if ((v_rd.y > 0.0f)) {
    cw_tmp_8 = 1i;
  } else {
    cw_tmp_8 = (-1i);
  }
  var v_sy: i32 = cw_tmp_8;
  var cw_tmp_9: i32;
  if ((v_rd.z > 0.0f)) {
    cw_tmp_9 = 1i;
  } else {
    cw_tmp_9 = (-1i);
  }
  var v_sz: i32 = cw_tmp_9;
  var cw_tmp_10: i32;
  if ((v_sx > 0i)) {
    cw_tmp_10 = 1i;
  } else {
    cw_tmp_10 = 0i;
  }
  var v_tx: f32 = (((f32((v_ix + cw_tmp_10)) * v_step) - v_ro.x) * f_safeInv(v_rd.x, cw_thread, cw_block, cw_grid));
  var cw_tmp_11: i32;
  if ((v_sy > 0i)) {
    cw_tmp_11 = 1i;
  } else {
    cw_tmp_11 = 0i;
  }
  var v_ty: f32 = (((f32((v_iy + cw_tmp_11)) * v_step) - v_ro.y) * f_safeInv(v_rd.y, cw_thread, cw_block, cw_grid));
  var cw_tmp_12: i32;
  if ((v_sz > 0i)) {
    cw_tmp_12 = 1i;
  } else {
    cw_tmp_12 = 0i;
  }
  var v_tz: f32 = (((f32((v_iz + cw_tmp_12)) * v_step) - v_ro.z) * f_safeInv(v_rd.z, cw_thread, cw_block, cw_grid));
  var v_dx: f32 = (v_step * abs(f_safeInv(v_rd.x, cw_thread, cw_block, cw_grid)));
  var v_dy: f32 = (v_step * abs(f_safeInv(v_rd.y, cw_thread, cw_block, cw_grid)));
  var v_dz: f32 = (v_step * abs(f_safeInv(v_rd.z, cw_thread, cw_block, cw_grid)));
  {
    var v_k: i32 = 0i;
    loop {
      if (!(v_k < 48i)) { break; }
      if ((v_t > v_end)) {
        break;
      }
      var v_exit: f32 = min(v_tx, min(v_ty, v_tz));
      var v_c: vec3<f32> = vec3<f32>(((f32(v_ix) + 0.5f) * v_step), ((f32(v_iy) + 0.5f) * v_step), ((f32(v_iz) + 0.5f) * v_step));
      var v_q: vec3<f32> = (v_c - v_centre);
      var v_ell: f32 = ((cw_divide_f32((v_q.x * v_q.x), (v_radius.x * v_radius.x)) + cw_divide_f32((v_q.y * v_q.y), (v_radius.y * v_radius.y))) + cw_divide_f32((v_q.z * v_q.z), (v_radius.z * v_radius.z)));
      if (((v_ell < 1.0f) && (f_hash2((v_ix + (v_iy * 113i)), v_iz, v_seed, cw_thread, cw_block, cw_grid) > 0.2f))) {
        var v_n: vec3<f32> = f_leafNormal(v_ix, v_iy, v_iz, v_seed, cw_thread, cw_block, cw_grid);
        var v_den: f32 = f_dot3(v_rd, v_n, cw_thread, cw_block, cw_grid);
        if ((abs(v_den) > 0.00001f)) {
          var v_u: f32 = cw_divide_f32(f_dot3((v_c - v_ro), v_n, cw_thread, cw_block, cw_grid), v_den);
          if (((v_u >= v_t) && (v_u <= v_exit))) {
            var v_pp: vec3<f32> = ((v_ro + (v_rd * vec3<f32>(v_u))) - v_c);
            var v_tangent: vec3<f32> = f_norm3(f_cross3(v_n, vec3<f32>(0.0f, 0.0f, 1.0f), cw_thread, cw_block, cw_grid), cw_thread, cw_block, cw_grid);
            var v_bitangent: vec3<f32> = f_cross3(v_n, v_tangent, cw_thread, cw_block, cw_grid);
            var v_a: f32 = cw_divide_f32(f_dot3(v_pp, v_tangent, cw_thread, cw_block, cw_grid), 0.125f);
            var v_b: f32 = cw_divide_f32(f_dot3(v_pp, v_bitangent, cw_thread, cw_block, cw_grid), 0.062f);
            if ((((v_a * v_a) + (v_b * v_b)) < 1.0f)) {
              return v_u;
            }
          }
        }
      }
      if (((v_tx < v_ty) && (v_tx < v_tz))) {
        v_t = v_tx;
        v_tx = (v_tx + v_dx);
        v_ix = (v_ix + v_sx);
      } else {
        if ((v_ty < v_tz)) {
          v_t = v_ty;
          v_ty = (v_ty + v_dy);
          v_iy = (v_iy + v_sy);
        } else {
          v_t = v_tz;
          v_tz = (v_tz + v_dz);
          v_iz = (v_iz + v_sz);
        }
      }
      continuing {
        v_k += i32(1);
      }
    }
  }
  return 30000.0f;
}
fn f_cw_buffer_helper_0(cw_buffer_arg_0: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  let cw_argument_index_13 = (cw_buffer_offset_0 + 0i);
  let cw_argument_index_14 = (cw_buffer_offset_0 + 1i);
  let cw_argument_index_15 = (cw_buffer_offset_0 + 2i);
  return vec3<f32>(b_C[cw_argument_index_13], b_C[cw_argument_index_14], b_C[cw_argument_index_15]);
}
fn f_cw_buffer_helper_1(cw_buffer_arg_0: i32, cw_arg_x: i32, cw_arg_y: i32, cw_arg_width: i32, cw_arg_height: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_x: i32 = cw_arg_x;
  var v_y: i32 = cw_arg_y;
  var v_width: i32 = cw_arg_width;
  var v_height: i32 = cw_arg_height;
  var v_jitterX: f32 = 0.0f;
  var v_jitterY: f32 = 0.0f;
  if ((b_C[(cw_buffer_offset_0 + 15i)] < 0.5f)) {
    v_jitterX = (f_fractf((b_C[(cw_buffer_offset_0 + 6i)] * 0.754877666f), cw_thread, cw_block, cw_grid) - 0.5f);
    v_jitterY = (f_fractf((b_C[(cw_buffer_offset_0 + 6i)] * 0.569840296f), cw_thread, cw_block, cw_grid) - 0.5f);
  }
  var v_sx: f32 = (cw_divide_f32((((f32(v_x) + 0.5f) + v_jitterX) - (f32(v_width) * 0.5f)), f32(v_height)) * 1.08f);
  var v_sy: f32 = (cw_divide_f32((-(((f32(v_y) + 0.5f) + v_jitterY) - (f32(v_height) * 0.5f))), f32(v_height)) * 1.08f);
  var v_f: vec3<f32> = f_cw_buffer_helper_3((cw_buffer_offset_0 + 0i), cw_thread, cw_block, cw_grid);
  var v_r: vec3<f32> = f_cw_buffer_helper_4((cw_buffer_offset_0 + 0i), cw_thread, cw_block, cw_grid);
  var v_u: vec3<f32> = f_cross3(v_f, v_r, cw_thread, cw_block, cw_grid);
  return f_norm3(((v_f + (v_r * vec3<f32>(v_sx))) + (v_u * vec3<f32>(v_sy))), cw_thread, cw_block, cw_grid);
}
fn f_cw_buffer_helper_2(cw_buffer_arg_0: i32, cw_buffer_arg_1: i32, cw_buffer_arg_2: i32, cw_buffer_arg_3: i32, cw_buffer_arg_4: i32, cw_arg_ro: vec3<f32>, cw_arg_rd: vec3<f32>, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec2<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var cw_buffer_offset_1: i32 = cw_buffer_arg_1;
  var cw_buffer_offset_2: i32 = cw_buffer_arg_2;
  var cw_buffer_offset_3: i32 = cw_buffer_arg_3;
  var cw_buffer_offset_4: i32 = cw_buffer_arg_4;
  var v_ro: vec3<f32> = cw_arg_ro;
  var v_rd: vec3<f32> = cw_arg_rd;
  var v_best: f32 = 30000.0f;
  var v_found: i32 = (-10000i);
  if ((v_rd.y < (-0.000001f))) {
    v_best = cw_divide_f32((-v_ro.y), v_rd.y);
    v_found = (-1i);
    if ((v_best > 30000.0f)) {
      v_best = 30000.0f;
      v_found = (-10000i);
    }
  }
  var v_bounds: vec2<f32> = f_boxRange(v_ro, v_rd, vec3<f32>(((-1152.0f) - 18.0f), (-0.01f), ((-1152.0f) - 18.0f)), vec3<f32>((1152.0f - 18.0f), 90.0f, (1152.0f - 18.0f)), cw_thread, cw_block, cw_grid);
  if (((v_bounds.y < max(v_bounds.x, 0.0f)) || (v_bounds.x > v_best))) {
    return vec2<f32>(v_best, f32(v_found));
  }
  var v_t: f32 = (max(v_bounds.x, 0.001f) + 0.001f);
  var v_start: vec3<f32> = (v_ro + (v_rd * vec3<f32>(v_t)));
  var v_cx: i32 = i32(floor(cw_divide_f32((v_start.x + (36.0f * 0.5f)), 36.0f)));
  var v_cz: i32 = i32(floor(cw_divide_f32((v_start.z + (36.0f * 0.5f)), 36.0f)));
  var cw_tmp_16: i32;
  if ((v_rd.x > 0.0f)) {
    cw_tmp_16 = 1i;
  } else {
    cw_tmp_16 = (-1i);
  }
  var v_sx: i32 = cw_tmp_16;
  var cw_tmp_17: i32;
  if ((v_rd.z > 0.0f)) {
    cw_tmp_17 = 1i;
  } else {
    cw_tmp_17 = (-1i);
  }
  var v_sz: i32 = cw_tmp_17;
  var cw_tmp_18: f32;
  if ((v_sx > 0i)) {
    cw_tmp_18 = (36.0f * 0.5f);
  } else {
    cw_tmp_18 = ((-36.0f) * 0.5f);
  }
  var v_tx: f32 = ((((f32(v_cx) * 36.0f) + cw_tmp_18) - v_ro.x) * f_safeInv(v_rd.x, cw_thread, cw_block, cw_grid));
  var cw_tmp_19: f32;
  if ((v_sz > 0i)) {
    cw_tmp_19 = (36.0f * 0.5f);
  } else {
    cw_tmp_19 = ((-36.0f) * 0.5f);
  }
  var v_tz: f32 = ((((f32(v_cz) * 36.0f) + cw_tmp_19) - v_ro.z) * f_safeInv(v_rd.z, cw_thread, cw_block, cw_grid));
  var v_dx: f32 = (36.0f * abs(f_safeInv(v_rd.x, cw_thread, cw_block, cw_grid)));
  var v_dz: f32 = (36.0f * abs(f_safeInv(v_rd.z, cw_thread, cw_block, cw_grid)));
  {
    var v_step: i32 = 0i;
    loop {
      if (!(v_step < 140i)) { break; }
      if ((((!f_inCity(v_cx, v_cz, cw_thread, cw_block, cw_grid)) || (v_t > v_best)) || (v_t > v_bounds.y))) {
        break;
      }
      var v_wi: i32 = f_worldIndex(v_cx, v_cz, cw_thread, cw_block, cw_grid);
      var v_slot: i32 = f_pageIndex(v_cx, v_cz, cw_thread, cw_block, cw_grid);
      var v_m: i32 = (v_slot * 12i);
      var v_cached: bool = (((b_Meta[(cw_buffer_offset_1 + (v_m + 3i))] > 0.5f) && (i32(b_Meta[(cw_buffer_offset_1 + v_m)]) == v_cx)) && (i32(b_Meta[(cw_buffer_offset_1 + (v_m + 1i))]) == v_cz));
      var cw_tmp_20: vec2<f32>;
      if (v_cached) {
        cw_tmp_20 = f_cw_buffer_helper_5((cw_buffer_offset_2 + 0i), (cw_buffer_offset_3 + 0i), (cw_buffer_offset_4 + 0i), v_slot, v_ro, v_rd, v_best, cw_thread, cw_block, cw_grid);
      } else {
        cw_tmp_20 = f_cw_buffer_helper_6((cw_buffer_offset_0 + 0i), v_wi, v_ro, v_rd, v_best, cw_thread, cw_block, cw_grid);
      }
      var v_hit: vec2<f32> = cw_tmp_20;
      if ((v_hit.x < v_best)) {
        v_best = v_hit.x;
        v_found = i32(v_hit.y);
      }
      if ((v_tx < v_tz)) {
        v_t = v_tx;
        v_tx = (v_tx + v_dx);
        v_cx = (v_cx + v_sx);
      } else {
        v_t = v_tz;
        v_tz = (v_tz + v_dz);
        v_cz = (v_cz + v_sz);
      }
      continuing {
        v_step += i32(1);
      }
    }
  }
  return vec2<f32>(v_best, f32(v_found));
}
fn f_cw_buffer_helper_3(cw_buffer_arg_0: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  let cw_argument_index_21 = (cw_buffer_offset_0 + 3i);
  let cw_argument_index_22 = (cw_buffer_offset_0 + 4i);
  let cw_argument_index_23 = (cw_buffer_offset_0 + 4i);
  let cw_argument_index_24 = (cw_buffer_offset_0 + 3i);
  let cw_argument_index_25 = (cw_buffer_offset_0 + 4i);
  return vec3<f32>((sin(b_C[cw_argument_index_21]) * cos(b_C[cw_argument_index_22])), sin(b_C[cw_argument_index_23]), (cos(b_C[cw_argument_index_24]) * cos(b_C[cw_argument_index_25])));
}
fn f_cw_buffer_helper_4(cw_buffer_arg_0: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  let cw_argument_index_26 = (cw_buffer_offset_0 + 3i);
  let cw_argument_index_29 = (cw_buffer_offset_0 + 3i);
  return vec3<f32>(cos(b_C[cw_argument_index_26]), 0.0f, (-sin(b_C[cw_argument_index_29])));
}
fn f_cw_buffer_helper_5(cw_buffer_arg_0: i32, cw_buffer_arg_1: i32, cw_buffer_arg_2: i32, cw_arg_slot: i32, cw_arg_ro: vec3<f32>, cw_arg_rd: vec3<f32>, cw_arg_best: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec2<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var cw_buffer_offset_1: i32 = cw_buffer_arg_1;
  var cw_buffer_offset_2: i32 = cw_buffer_arg_2;
  var v_slot: i32 = cw_arg_slot;
  var v_ro: vec3<f32> = cw_arg_ro;
  var v_rd: vec3<f32> = cw_arg_rd;
  var v_best: f32 = cw_arg_best;
  var v_stack: array<i32, 24>;
  var v_top: i32 = 0i;
  var v_node: i32 = 1i;
  var v_found: i32 = (-10000i);
  var v_visits: i32 = 0i;
  {
    loop {
      if (!((v_node > 0i) && (v_visits < 4096i))) { break; }
      v_visits += i32(1);
      var v_b: i32 = (((v_slot * 4096i) + v_node) * 8i);
      let cw_argument_index_30 = (cw_buffer_offset_1 + v_b);
      let cw_argument_index_31 = (cw_buffer_offset_1 + (v_b + 1i));
      let cw_argument_index_32 = (cw_buffer_offset_1 + (v_b + 2i));
      let cw_argument_index_33 = (cw_buffer_offset_1 + (v_b + 4i));
      let cw_argument_index_34 = (cw_buffer_offset_1 + (v_b + 5i));
      let cw_argument_index_35 = (cw_buffer_offset_1 + (v_b + 6i));
      var v_span: vec2<f32> = f_boxRange(v_ro, v_rd, vec3<f32>(b_Nodes[cw_argument_index_30], b_Nodes[cw_argument_index_31], b_Nodes[cw_argument_index_32]), vec3<f32>(b_Nodes[cw_argument_index_33], b_Nodes[cw_argument_index_34], b_Nodes[cw_argument_index_35]), cw_thread, cw_block, cw_grid);
      var v_hit: bool = (((b_Nodes[(cw_buffer_offset_1 + (v_b + 3i))] > 0.0f) && (v_span.y >= max(0.001f, v_span.x))) && (v_span.x < v_best));
      if ((v_hit && (v_node < 2048i))) {
        var v_left: i32 = (v_node * 2i);
        var v_right: i32 = (v_left + 1i);
        var v_lb: i32 = (((v_slot * 4096i) + v_left) * 8i);
        var v_rb: i32 = (v_lb + 8i);
        let cw_argument_index_36 = (cw_buffer_offset_1 + v_lb);
        let cw_argument_index_37 = (cw_buffer_offset_1 + (v_lb + 1i));
        let cw_argument_index_38 = (cw_buffer_offset_1 + (v_lb + 2i));
        let cw_argument_index_39 = (cw_buffer_offset_1 + (v_lb + 4i));
        let cw_argument_index_40 = (cw_buffer_offset_1 + (v_lb + 5i));
        let cw_argument_index_41 = (cw_buffer_offset_1 + (v_lb + 6i));
        var v_ls: vec2<f32> = f_boxRange(v_ro, v_rd, vec3<f32>(b_Nodes[cw_argument_index_36], b_Nodes[cw_argument_index_37], b_Nodes[cw_argument_index_38]), vec3<f32>(b_Nodes[cw_argument_index_39], b_Nodes[cw_argument_index_40], b_Nodes[cw_argument_index_41]), cw_thread, cw_block, cw_grid);
        let cw_argument_index_42 = (cw_buffer_offset_1 + v_rb);
        let cw_argument_index_43 = (cw_buffer_offset_1 + (v_rb + 1i));
        let cw_argument_index_44 = (cw_buffer_offset_1 + (v_rb + 2i));
        let cw_argument_index_45 = (cw_buffer_offset_1 + (v_rb + 4i));
        let cw_argument_index_46 = (cw_buffer_offset_1 + (v_rb + 5i));
        let cw_argument_index_47 = (cw_buffer_offset_1 + (v_rb + 6i));
        var v_rs: vec2<f32> = f_boxRange(v_ro, v_rd, vec3<f32>(b_Nodes[cw_argument_index_42], b_Nodes[cw_argument_index_43], b_Nodes[cw_argument_index_44]), vec3<f32>(b_Nodes[cw_argument_index_45], b_Nodes[cw_argument_index_46], b_Nodes[cw_argument_index_47]), cw_thread, cw_block, cw_grid);
        var v_lh: bool = (((b_Nodes[(cw_buffer_offset_1 + (v_lb + 3i))] > 0.0f) && (v_ls.y >= max(0.001f, v_ls.x))) && (v_ls.x < v_best));
        var v_rh: bool = (((b_Nodes[(cw_buffer_offset_1 + (v_rb + 3i))] > 0.0f) && (v_rs.y >= max(0.001f, v_rs.x))) && (v_rs.x < v_best));
        if ((v_lh && v_rh)) {
          var cw_tmp_48: i32;
          if ((v_ls.x < v_rs.x)) {
            cw_tmp_48 = v_left;
          } else {
            cw_tmp_48 = v_right;
          }
          var v_near: i32 = cw_tmp_48;
          var cw_tmp_49: i32;
          if ((v_ls.x < v_rs.x)) {
            cw_tmp_49 = v_right;
          } else {
            cw_tmp_49 = v_left;
          }
          var v_far: i32 = cw_tmp_49;
          if ((v_top < 24i)) {
            v_stack[v_top] = v_far;
            v_top += i32(1);
          }
          v_node = v_near;
        } else {
          if (v_lh) {
            v_node = v_left;
          } else {
            if (v_rh) {
              v_node = v_right;
            } else {
              v_node = 0i;
              if ((v_top > 0i)) {
                v_top -= i32(1);
                v_node = v_stack[v_top];
              }
            }
          }
        }
      } else {
        if (v_hit) {
          var v_id: i32 = b_Order[(cw_buffer_offset_2 + (((v_slot * 2048i) + v_node) - 2048i))];
          var v_t: f32 = f_cw_buffer_helper_7((cw_buffer_offset_0 + 0i), v_id, v_ro, v_rd, cw_thread, cw_block, cw_grid);
          if ((v_t < v_best)) {
            v_best = v_t;
            v_found = v_id;
          }
        }
        v_node = 0i;
        if ((v_top > 0i)) {
          v_top -= i32(1);
          v_node = v_stack[v_top];
        }
      }
    }
  }
  return vec2<f32>(v_best, f32(v_found));
}
fn f_cw_buffer_helper_6(cw_buffer_arg_0: i32, cw_arg_wi: i32, cw_arg_ro: vec3<f32>, cw_arg_rd: vec3<f32>, cw_arg_best: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec2<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_wi: i32 = cw_arg_wi;
  var v_ro: vec3<f32> = cw_arg_ro;
  var v_rd: vec3<f32> = cw_arg_rd;
  var v_best: f32 = cw_arg_best;
  var v_b: i32 = (v_wi * 8i);
  var v_type: i32 = i32(b_World[(cw_buffer_offset_0 + (v_b + 3i))]);
  if (((v_type == 3i) || (v_type == 4i))) {
    return vec2<f32>(v_best, (-10000.0f));
  }
  var v_cx: i32 = ((v_wi % 64i) - (64i / 2i));
  var v_cz: i32 = ((v_wi / 64i) - (64i / 2i));
  var v_x: f32 = (f32(v_cx) * 36.0f);
  var v_z: f32 = (f32(v_cz) * 36.0f);
  var v_h: f32 = b_World[(cw_buffer_offset_0 + (v_b + 2i))];
  var v_span: vec2<f32> = f_boxRange(v_ro, v_rd, vec3<f32>((v_x - b_World[(cw_buffer_offset_0 + v_b)]), 0.0f, (v_z - b_World[(cw_buffer_offset_0 + (v_b + 1i))])), vec3<f32>((v_x + b_World[(cw_buffer_offset_0 + v_b)]), (v_h + 4.5f), (v_z + b_World[(cw_buffer_offset_0 + (v_b + 1i))])), cw_thread, cw_block, cw_grid);
  if ((v_span.y >= max(0.001f, v_span.x))) {
    var cw_tmp_50: f32;
    if ((v_span.x > 0.001f)) {
      cw_tmp_50 = v_span.x;
    } else {
      cw_tmp_50 = v_span.y;
    }
    var v_t: f32 = cw_tmp_50;
    if ((v_t < v_best)) {
      return vec2<f32>(v_t, f32(((-v_wi) - 2i)));
    }
  }
  return vec2<f32>(v_best, (-10000.0f));
}
fn f_cw_buffer_helper_7(cw_buffer_arg_0: i32, cw_arg_id: i32, cw_arg_ro: vec3<f32>, cw_arg_rd: vec3<f32>, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_id: i32 = cw_arg_id;
  var v_ro: vec3<f32> = cw_arg_ro;
  var v_rd: vec3<f32> = cw_arg_rd;
  var v_b: i32 = (v_id * 16i);
  var v_shape: i32 = i32(b_P[(cw_buffer_offset_0 + (v_b + 3i))]);
  if ((v_shape < 0i)) {
    return 30000.0f;
  }
  let cw_argument_index_51 = (cw_buffer_offset_0 + v_b);
  let cw_argument_index_52 = (cw_buffer_offset_0 + (v_b + 1i));
  let cw_argument_index_53 = (cw_buffer_offset_0 + (v_b + 2i));
  var v_cp: vec3<f32> = vec3<f32>(b_P[cw_argument_index_51], b_P[cw_argument_index_52], b_P[cw_argument_index_53]);
  let cw_argument_index_54 = (cw_buffer_offset_0 + (v_b + 4i));
  let cw_argument_index_55 = (cw_buffer_offset_0 + (v_b + 5i));
  let cw_argument_index_56 = (cw_buffer_offset_0 + (v_b + 6i));
  var v_h: vec3<f32> = vec3<f32>(b_P[cw_argument_index_54], b_P[cw_argument_index_55], b_P[cw_argument_index_56]);
  var v_turn: i32 = i32(b_P[(cw_buffer_offset_0 + (v_b + 8i))]);
  var v_p: vec3<f32> = f_localPoint((v_ro - v_cp), v_turn, cw_thread, cw_block, cw_grid);
  var v_d: vec3<f32> = f_localPoint(v_rd, v_turn, cw_thread, cw_block, cw_grid);
  var v_range: vec2<f32> = f_boxRange(v_p, v_d, (v_h * vec3<f32>((-1.0f))), v_h, cw_thread, cw_block, cw_grid);
  if (((v_shape == 3i) || (v_shape == 4i))) {
    v_range = f_boxRange(v_p, v_d, vec3<f32>((-v_h.x), 0.0f, (-v_h.z)), v_h, cw_thread, cw_block, cw_grid);
  }
  if ((v_range.y < max(0.001f, v_range.x))) {
    return 30000.0f;
  }
  var cw_tmp_57: f32;
  if ((v_range.x > 0.001f)) {
    cw_tmp_57 = v_range.x;
  } else {
    cw_tmp_57 = v_range.y;
  }
  var v_t: f32 = cw_tmp_57;
  if ((v_shape == 1i)) {
    var v_a: vec3<f32> = vec3<f32>(cw_divide_f32(v_p.x, v_h.x), cw_divide_f32(v_p.y, v_h.y), cw_divide_f32(v_p.z, v_h.z));
    var v_v: vec3<f32> = vec3<f32>(cw_divide_f32(v_d.x, v_h.x), cw_divide_f32(v_d.y, v_h.y), cw_divide_f32(v_d.z, v_h.z));
    var v_aa: f32 = f_dot3(v_v, v_v, cw_thread, cw_block, cw_grid);
    var v_bb: f32 = f_dot3(v_a, v_v, cw_thread, cw_block, cw_grid);
    var v_cc: f32 = (f_dot3(v_a, v_a, cw_thread, cw_block, cw_grid) - 1.0f);
    var v_disc: f32 = ((v_bb * v_bb) - (v_aa * v_cc));
    if ((v_disc < 0.0f)) {
      return 30000.0f;
    }
    v_t = cw_divide_f32(((-v_bb) - sqrt(v_disc)), v_aa);
    if ((v_t <= 0.001f)) {
      v_t = cw_divide_f32(((-v_bb) + sqrt(v_disc)), v_aa);
    }
  }
  if ((v_shape == 2i)) {
    var v_a: f32 = (cw_divide_f32((v_d.x * v_d.x), (v_h.x * v_h.x)) + cw_divide_f32((v_d.z * v_d.z), (v_h.z * v_h.z)));
    var v_bb: f32 = (cw_divide_f32((v_p.x * v_d.x), (v_h.x * v_h.x)) + cw_divide_f32((v_p.z * v_d.z), (v_h.z * v_h.z)));
    var v_cc: f32 = ((cw_divide_f32((v_p.x * v_p.x), (v_h.x * v_h.x)) + cw_divide_f32((v_p.z * v_p.z), (v_h.z * v_h.z))) - 1.0f);
    var v_best: f32 = 30000.0f;
    var v_disc: f32 = ((v_bb * v_bb) - (v_a * v_cc));
    if (((v_disc >= 0.0f) && (v_a > 1e-7f))) {
      var v_u: f32 = cw_divide_f32(((-v_bb) - sqrt(v_disc)), v_a);
      var v_v: f32 = cw_divide_f32(((-v_bb) + sqrt(v_disc)), v_a);
      if (((v_u > 0.001f) && (abs((v_p.y + (v_d.y * v_u))) <= v_h.y))) {
        v_best = v_u;
      }
      if (((v_v > 0.001f) && (abs((v_p.y + (v_d.y * v_v))) <= v_h.y))) {
        v_best = min(v_best, v_v);
      }
    }
    {
      var v_k: i32 = 0i;
      loop {
        if (!(v_k < 2i)) { break; }
        if ((abs(v_d.y) > 0.000001f)) {
          var cw_tmp_58: f32;
          if ((v_k == 0i)) {
            cw_tmp_58 = (-v_h.y);
          } else {
            cw_tmp_58 = v_h.y;
          }
          var v_cy: f32 = cw_tmp_58;
          var v_u: f32 = cw_divide_f32((v_cy - v_p.y), v_d.y);
          var v_xx: f32 = cw_divide_f32((v_p.x + (v_d.x * v_u)), v_h.x);
          var v_zz: f32 = cw_divide_f32((v_p.z + (v_d.z * v_u)), v_h.z);
          if (((v_u > 0.001f) && (((v_xx * v_xx) + (v_zz * v_zz)) <= 1.0f))) {
            v_best = min(v_best, v_u);
          }
        }
        continuing {
          v_k += i32(1);
        }
      }
    }
    v_t = v_best;
  }
  if ((v_shape == 3i)) {
    var v_near: f32 = max(0.001f, v_range.x);
    var v_far: f32 = v_range.y;
    {
      var v_k: i32 = 0i;
      loop {
        if (!(v_k < 2i)) { break; }
        var cw_tmp_59: f32;
        if ((v_k == 0i)) {
          cw_tmp_59 = 1.0f;
        } else {
          cw_tmp_59 = (-1.0f);
        }
        var v_sign: f32 = cw_tmp_59;
        var v_numer: f32 = (v_h.y - (v_p.y + cw_divide_f32(((v_sign * v_p.x) * v_h.y), v_h.x)));
        var v_denom: f32 = (v_d.y + cw_divide_f32(((v_sign * v_d.x) * v_h.y), v_h.x));
        if ((abs(v_denom) < 0.000001f)) {
          if ((v_numer < 0.0f)) {
            return 30000.0f;
          }
        } else {
          var v_u: f32 = cw_divide_f32(v_numer, v_denom);
          if ((v_denom > 0.0f)) {
            v_far = min(v_far, v_u);
          } else {
            v_near = max(v_near, v_u);
          }
        }
        continuing {
          v_k += i32(1);
        }
      }
    }
    if ((v_far < v_near)) {
      return 30000.0f;
    }
    v_t = v_near;
  }
  if (((v_shape == 4i) || (v_shape == 7i))) {
    var v_best: f32 = 30000.0f;
    var v_a: f32 = (cw_divide_f32((v_d.x * v_d.x), (v_h.x * v_h.x)) + cw_divide_f32((v_d.y * v_d.y), (v_h.y * v_h.y)));
    var v_bb: f32 = (cw_divide_f32((v_p.x * v_d.x), (v_h.x * v_h.x)) + cw_divide_f32((v_p.y * v_d.y), (v_h.y * v_h.y)));
    {
      var v_ring: i32 = 0i;
      loop {
        if (!(v_ring < 2i)) { break; }
        var cw_tmp_60: f32;
        if ((v_ring == 0i)) {
          cw_tmp_60 = 1.0f;
        } else {
          cw_tmp_60 = 0.77f;
        }
        var v_rad: f32 = cw_tmp_60;
        var v_cc: f32 = ((cw_divide_f32((v_p.x * v_p.x), (v_h.x * v_h.x)) + cw_divide_f32((v_p.y * v_p.y), (v_h.y * v_h.y))) - (v_rad * v_rad));
        var v_disc: f32 = ((v_bb * v_bb) - (v_a * v_cc));
        if (((v_disc >= 0.0f) && (v_a > 0.000001f))) {
          {
            var v_k: i32 = 0i;
            loop {
              if (!(v_k < 2i)) { break; }
              var cw_tmp_61: f32;
              if ((v_k == 0i)) {
                cw_tmp_61 = (-sqrt(v_disc));
              } else {
                cw_tmp_61 = sqrt(v_disc);
              }
              var v_u: f32 = cw_divide_f32(((-v_bb) + cw_tmp_61), v_a);
              if ((((v_u > 0.001f) && (abs((v_p.z + (v_d.z * v_u))) <= v_h.z)) && ((v_shape == 7i) || ((v_p.y + (v_d.y * v_u)) >= 0.0f)))) {
                v_best = min(v_best, v_u);
              }
              continuing {
                v_k += i32(1);
              }
            }
          }
        }
        continuing {
          v_ring += i32(1);
        }
      }
    }
    if ((abs(v_d.z) > 0.000001f)) {
      {
        var v_k: i32 = 0i;
        loop {
          if (!(v_k < 2i)) { break; }
          var cw_tmp_62: f32;
          if ((v_k == 0i)) {
            cw_tmp_62 = (-v_h.z);
          } else {
            cw_tmp_62 = v_h.z;
          }
          var v_u: f32 = cw_divide_f32((cw_tmp_62 - v_p.z), v_d.z);
          var v_xx: f32 = cw_divide_f32((v_p.x + (v_d.x * v_u)), v_h.x);
          var v_yy: f32 = cw_divide_f32((v_p.y + (v_d.y * v_u)), v_h.y);
          var v_rr: f32 = ((v_xx * v_xx) + (v_yy * v_yy));
          if (((((v_u > 0.001f) && (v_rr <= 1.0f)) && (v_rr >= (0.77f * 0.77f))) && ((v_shape == 7i) || (v_yy >= 0.0f)))) {
            v_best = min(v_best, v_u);
          }
          continuing {
            v_k += i32(1);
          }
        }
      }
    }
    v_t = v_best;
  }
  if ((((v_shape == 1i) && (i32(b_P[(cw_buffer_offset_0 + (v_b + 7i))]) == 7i)) && (v_t < 30000.0f))) {
    v_t = f_foliageHit(v_ro, v_rd, v_cp, v_h, i32(b_P[(cw_buffer_offset_0 + (v_b + 9i))]), v_range.x, v_range.y, cw_thread, cw_block, cw_grid);
  }
  if ((v_t <= 0.001f)) {
    return 30000.0f;
  }
  if (((((v_shape == 0i) && (v_t < 18.0f)) && ((i32(b_P[(cw_buffer_offset_0 + (v_b + 7i))]) == 0i) || (i32(b_P[(cw_buffer_offset_0 + (v_b + 7i))]) == 1i))) && (v_h.y > 1.0f))) {
    var v_hit: vec3<f32> = (v_p + (v_d * vec3<f32>(v_t)));
    var v_ex: f32 = abs((abs(v_hit.x) - v_h.x));
    var v_ez: f32 = abs((abs(v_hit.z) - v_h.z));
    if ((abs((abs(v_hit.y) - v_h.y)) > 0.01f)) {
      var cw_tmp_65: vec3<f32>;
      if ((v_ex < v_ez)) {
        var cw_tmp_63: f32;
        if ((v_hit.x < 0.0f)) {
          cw_tmp_63 = (-1.0f);
        } else {
          cw_tmp_63 = 1.0f;
        }
        cw_tmp_65 = vec3<f32>(cw_tmp_63, 0.0f, 0.0f);
      } else {
        var cw_tmp_64: f32;
        if ((v_hit.z < 0.0f)) {
          cw_tmp_64 = (-1.0f);
        } else {
          cw_tmp_64 = 1.0f;
        }
        cw_tmp_65 = vec3<f32>(0.0f, 0.0f, cw_tmp_64);
      }
      var v_n: vec3<f32> = cw_tmp_65;
      var v_denom: f32 = f_dot3(v_n, v_d, cw_thread, cw_block, cw_grid);
      if ((v_denom < (-0.08f))) {
        var v_initial: f32 = v_t;
        {
          var v_k: i32 = 0i;
          loop {
            if (!(v_k < 4i)) { break; }
            var v_wp: vec3<f32> = (v_ro + (v_rd * vec3<f32>(v_t)));
            var v_wn: vec3<f32> = f_worldNormal(v_n, v_turn, cw_thread, cw_block, cw_grid);
            var v_uv: vec2<f32> = f_masonryUV(v_wp, v_wn, cw_thread, cw_block, cw_grid);
            var v_displacement: f32 = f_masonryHeight(v_uv.x, v_uv.y, i32(b_P[(cw_buffer_offset_0 + (v_b + 7i))]), cw_thread, cw_block, cw_grid);
            v_t = (v_initial + cw_divide_f32(v_displacement, v_denom));
            continuing {
              v_k += i32(1);
            }
          }
        }
      }
    }
  }
  return v_t;
}

@compute @workgroup_size(8, 8, 1)
fn main(
  @builtin(local_invocation_id) cw_thread: vec3<u32>,
  @builtin(workgroup_id) cw_block: vec3<u32>,
  @builtin(num_workgroups) cw_grid: vec3<u32>
) {
  var v_x: i32 = i32(((cw_block.x * cw_block_size.x) + cw_thread.x));
  var v_y: i32 = i32(((cw_block.y * cw_block_size.y) + cw_thread.y));
  if (((v_x >= cw_params.p_width) || (v_y >= cw_params.p_height))) {
    return;
  }
  var v_ro: vec3<f32> = f_cw_buffer_helper_0(0i, cw_thread, cw_block, cw_grid);
  var v_rd: vec3<f32> = f_cw_buffer_helper_1(0i, v_x, v_y, cw_params.p_width, cw_params.p_height, cw_thread, cw_block, cw_grid);
  var v_result: vec2<f32> = f_cw_buffer_helper_2(0i, 0i, 0i, 0i, 0i, v_ro, v_rd, cw_thread, cw_block, cw_grid);
  var v_b: i32 = (((v_y * cw_params.p_width) + v_x) * 4i);
  b_Hit[v_b] = v_result.x;
  b_Hit[(v_b + 1i)] = v_result.y;
  b_Hit[(v_b + 2i)] = 0.0f;
  b_Hit[(v_b + 3i)] = 1.0f;
}
