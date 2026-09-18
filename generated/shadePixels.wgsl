// CUDA WebShader 0.1.0. Generated from kernel shadePixels.
@group(0) @binding(0) var<storage, read> b_World: array<f32>;
@group(0) @binding(1) var<storage, read> b_P: array<f32>;
@group(0) @binding(2) var<storage, read> b_C: array<f32>;
@group(0) @binding(3) var<storage, read> b_Hit: array<f32>;
@group(0) @binding(4) var<storage, read> b_W: array<f32>;
@group(0) @binding(5) var<storage, read> b_Brain: array<f32>;
@group(0) @binding(6) var<storage, read_write> b_Linear: array<f32>;
struct CWParams {
  p_width: i32,
  p_height: i32,
  cw_pad_8: u32,
  cw_pad_12: u32,
}
@group(0) @binding(7) var<uniform> cw_params: CWParams;
const cw_block_size: vec3<u32> = vec3<u32>(8u, 8u, 1u);

fn cw_divide_f32(a: f32, b: f32) -> f32 { let q = a / b; if ((bitcast<u32>(q) & 0x7f800000u) == 0x7f800000u || (bitcast<u32>(q) & 0x7fffffffu) == 0u || (bitcast<u32>(b) & 0x7f800000u) == 0x7f800000u) { return q; } let residual = fma(-q, b, a); return q + residual / b; }

alias cw_f64 = vec2<u32>;
fn cw_d_shl(a: vec2<u32>, n: u32) -> vec2<u32> {
  if(n == 0u) { return a; }
  if(n >= 64u) { return vec2<u32>(0u); }
  if(n >= 32u) { return vec2<u32>(0u, a.x << (n - 32u)); }
  return vec2<u32>(a.x << n, (a.y << n) | (a.x >> (32u - n)));
}
fn cw_d_shr(a: vec2<u32>, n: u32) -> vec2<u32> {
  if(n == 0u) { return a; }
  if(n >= 64u) { return vec2<u32>(0u); }
  if(n >= 32u) { return vec2<u32>(a.y >> (n - 32u), 0u); }
  return vec2<u32>((a.x >> n) | (a.y << (32u - n)), a.y >> n);
}
fn cw_d_jam(a: vec2<u32>, n: u32) -> vec2<u32> {
  let shifted = cw_d_shr(a, n);
  return shifted | vec2<u32>(select(0u, 1u, any(cw_d_shl(shifted, n) != a)), 0u);
}
fn cw_d_uadd(a: vec2<u32>, b: vec2<u32>) -> vec2<u32> {
  let low = a.x + b.x;
  return vec2<u32>(low, a.y + b.y + select(0u, 1u, low < a.x));
}
fn cw_d_usub(a: vec2<u32>, b: vec2<u32>) -> vec2<u32> {
  return vec2<u32>(a.x - b.x, a.y - b.y - select(0u, 1u, a.x < b.x));
}
fn cw_d_uless(a: vec2<u32>, b: vec2<u32>) -> bool {
  return a.y < b.y || (a.y == b.y && a.x < b.x);
}
fn cw_d_nan(a: cw_f64) -> bool { return (a.y & 2147483647u) > 2146435072u || ((a.y & 2147483647u) == 2146435072u && a.x != 0u); }
fn cw_d_inf(a: cw_f64) -> bool { return (a.y & 2147483647u) == 2146435072u && a.x == 0u; }
fn cw_d_zero(a: cw_f64) -> bool { return (a.y & 2147483647u) == 0u && a.x == 0u; }
fn cw_d_neg(a: cw_f64) -> cw_f64 { return a ^ vec2<u32>(0u, 2147483648u); }
struct CWDoubleParts { significand: vec2<u32>, exponent: i32, }
fn cw_d_parts(a: cw_f64) -> CWDoubleParts {
  let raw = (a.y >> 20u) & 2047u;
  var s = vec2<u32>(a.x, a.y & 1048575u);
  var e = i32(raw) - 1023i;
  if(raw != 0u) { s.y |= 1048576u; }
  else {
    e = -1022i;
    if(any(s != vec2<u32>(0u))) {
      loop { if((s.y & 1048576u) != 0u) { break; } s = cw_d_shl(s, 1u); e--; }
    }
  }
  return CWDoubleParts(s,e);
}
// Input has its leading bit at bit 55 and three guard/round/sticky bits.
fn cw_d_pack(sign: u32, exponent: i32, value: vec2<u32>) -> cw_f64 {
  var e = exponent; var v = value;
  if(e < -1022i) { v = cw_d_jam(v, u32(-1022i-e)); e = -1022i; }
  let tail = v.x & 7u;
  var s = cw_d_shr(v, 3u);
  if(tail > 4u || (tail == 4u && (s.x & 1u) != 0u)) { s = cw_d_uadd(s,vec2<u32>(1u,0u)); }
  if((s.y & 2097152u) != 0u) { s = cw_d_shr(s,1u); e++; }
  if(e > 1023i) { return vec2<u32>(0u,sign | 2146435072u); }
  let field = select(0u, u32(e+1023i), (s.y & 1048576u) != 0u);
  return vec2<u32>(s.x, sign | (field << 20u) | (s.y & 1048575u));
}
fn cw_d_from_f32(a: f32) -> cw_f64 {
  let bits = bitcast<u32>(a); let sign = bits & 2147483648u;
  let field = (bits >> 23u) & 255u; var mantissa = bits & 8388607u;
  if(field == 255u) { return vec2<u32>(0u,sign | 2146435072u | select(0u,524288u,mantissa != 0u)); }
  if(field == 0u && mantissa == 0u) { return vec2<u32>(0u,sign); }
  var e = i32(field)-127i;
  if(field == 0u) { e = -126i; loop { if((mantissa & 8388608u) != 0u) { break; } mantissa <<= 1u; e--; } }
  let s = cw_d_shl(vec2<u32>(mantissa & 8388607u,0u),29u);
  return vec2<u32>(s.x,sign | (u32(e+1023i) << 20u) | s.y);
}
fn cw_d_from_u32(a: u32) -> cw_f64 {
  if(a == 0u) { return vec2<u32>(0u); }
  let e = 31u-countLeadingZeros(a); let s = cw_d_shl(vec2<u32>(a,0u),52u-e);
  return vec2<u32>(s.x,((e+1023u) << 20u) | (s.y & 1048575u));
}
fn cw_d_from_i32(a: i32) -> cw_f64 {
  if(a < 0i) { return cw_d_neg(cw_d_from_u32(0u-u32(a))); }
  return cw_d_from_u32(u32(a));
}
fn cw_d_to_f32(a: cw_f64) -> f32 {
  let sign = a.y & 2147483648u;
  if(cw_d_nan(a)) { return bitcast<f32>(sign | 2143289344u); }
  if(cw_d_inf(a)) { return bitcast<f32>(sign | 2139095040u); }
  if(cw_d_zero(a)) { return bitcast<f32>(sign); }
  let p = cw_d_parts(a); var e = p.exponent;
  let shift = 29u + u32(max(-126i-e,0i));
  // Keep three rounding bits while reducing the 53-bit significand to 24 bits.
  let v = cw_d_jam(p.significand,shift-3u); let tail = v.x & 7u;
  var s = cw_d_shr(v,3u).x;
  if(tail > 4u || (tail == 4u && (s & 1u) != 0u)) { s++; }
  e = max(e,-126i);
  if(s >= 16777216u) { s >>= 1u; e++; }
  if(e > 127i) { return bitcast<f32>(sign | 2139095040u); }
  let field = select(0u,u32(e+127i),s >= 8388608u);
  return bitcast<f32>(sign | (field << 23u) | (s & 8388607u));
}
fn cw_d_u64_to_f32(a: vec2<u32>) -> f32 {
  if(all(a == vec2<u32>(0u))) { return 0.0f; }
  var e = select(31u-countLeadingZeros(a.x),63u-countLeadingZeros(a.y),a.y != 0u);
  var v: vec2<u32>;
  if(e > 26u) { v = cw_d_jam(a,e-26u); } else { v = cw_d_shl(a,26u-e); }
  let tail = v.x & 7u; var s = v.x >> 3u;
  if(tail > 4u || (tail == 4u && (s & 1u) != 0u)) { s++; }
  if(s >= 16777216u) { s >>= 1u; e++; }
  return bitcast<f32>(((e+127u) << 23u) | (s & 8388607u));
}
fn cw_d_eq(a: cw_f64,b: cw_f64) -> bool { return !cw_d_nan(a) && !cw_d_nan(b) && (all(a == b) || (cw_d_zero(a) && cw_d_zero(b))); }
fn cw_d_lt(a: cw_f64,b: cw_f64) -> bool {
  if(cw_d_nan(a) || cw_d_nan(b) || cw_d_eq(a,b)) { return false; }
  let sa = a.y >> 31u; let sb = b.y >> 31u;
  if(sa != sb) { return sa != 0u; }
  return select(cw_d_uless(a,b),cw_d_uless(b,a),sa != 0u);
}
fn cw_d_le(a: cw_f64,b: cw_f64) -> bool { return cw_d_lt(a,b) || cw_d_eq(a,b); }
fn cw_d_add(a: cw_f64,b: cw_f64) -> cw_f64 {
  if(cw_d_nan(a) || cw_d_nan(b) || (cw_d_inf(a) && cw_d_inf(b) && ((a.y ^ b.y) >> 31u) != 0u)) { return vec2<u32>(0u,2146959360u); }
  if(cw_d_inf(a)) { return a; } if(cw_d_inf(b)) { return b; }
  if(cw_d_zero(a) && cw_d_zero(b)) { return vec2<u32>(0u,(a.y & b.y) & 2147483648u); }
  if(cw_d_zero(a)) { return b; } if(cw_d_zero(b)) { return a; }
  let pa = cw_d_parts(a); let pb = cw_d_parts(b);
  var x = cw_d_shl(pa.significand,3u); var y = cw_d_shl(pb.significand,3u);
  var e = max(pa.exponent,pb.exponent); var sign = a.y & 2147483648u;
  x = cw_d_jam(x,u32(e-pa.exponent)); y = cw_d_jam(y,u32(e-pb.exponent));
  var sum: vec2<u32>;
  if(((a.y ^ b.y) >> 31u) == 0u) {
    sum = cw_d_uadd(x,y);
    if((sum.y & 16777216u) != 0u) { sum = cw_d_jam(sum,1u); e++; }
  } else {
    if(cw_d_uless(x,y)) { sum = cw_d_usub(y,x); sign = b.y & 2147483648u; }
    else { sum = cw_d_usub(x,y); }
    if(all(sum == vec2<u32>(0u))) { return vec2<u32>(0u); }
    loop { if((sum.y & 8388608u) != 0u) { break; } sum = cw_d_shl(sum,1u); e--; }
  }
  return cw_d_pack(sign,e,sum);
}
fn cw_d_sub(a: cw_f64,b: cw_f64) -> cw_f64 { return cw_d_add(a,cw_d_neg(b)); }
fn cw_d_mul(a: cw_f64,b: cw_f64) -> cw_f64 {
  let sign = (a.y ^ b.y) & 2147483648u;
  if(cw_d_nan(a) || cw_d_nan(b) || (cw_d_inf(a) && cw_d_zero(b)) || (cw_d_inf(b) && cw_d_zero(a))) { return vec2<u32>(0u,2146959360u); }
  if(cw_d_inf(a) || cw_d_inf(b)) { return vec2<u32>(0u,sign | 2146435072u); }
  if(cw_d_zero(a) || cw_d_zero(b)) { return vec2<u32>(0u,sign); }
  let pa = cw_d_parts(a); let pb = cw_d_parts(b);
  if(all(pa.significand == vec2<u32>(0u,1048576u))) { return cw_d_pack(sign,pa.exponent+pb.exponent,cw_d_shl(pb.significand,3u)); }
  if(all(pb.significand == vec2<u32>(0u,1048576u))) { return cw_d_pack(sign,pa.exponent+pb.exponent,cw_d_shl(pa.significand,3u)); }
  var product = vec4<u32>(0u); var term = vec4<u32>(pa.significand,0u,0u); var multiplier = pb.significand;
  for(var i = 0u; i < 53u; i++) {
    if((multiplier.x & 1u) != 0u) {
      var carry = 0u;
      for(var j = 0u; j < 4u; j++) {
        let p = product[j]; let s = p + term[j]; let t = s + carry;
        carry = select(0u,1u,s < p || t < s); product[j] = t;
      }
    }
    term = vec4<u32>(term.x << 1u,(term.y << 1u) | (term.x >> 31u),(term.z << 1u) | (term.y >> 31u),(term.w << 1u) | (term.z >> 31u));
    multiplier = cw_d_shr(multiplier,1u);
  }
  let extra = select(0u,1u,(product.w & 512u) != 0u);
  for(var i = 0u; i < 49u+extra; i++) {
    product = vec4<u32>((product.x >> 1u) | (product.y << 31u) | (product.x & 1u),(product.y >> 1u) | (product.z << 31u),(product.z >> 1u) | (product.w << 31u),product.w >> 1u);
  }
  return cw_d_pack(sign,pa.exponent+pb.exponent+i32(extra),product.xy);
}
fn cw_d_div(a: cw_f64,b: cw_f64) -> cw_f64 {
  let sign = (a.y ^ b.y) & 2147483648u;
  if(cw_d_nan(a) || cw_d_nan(b) || (cw_d_inf(a) && cw_d_inf(b)) || (cw_d_zero(a) && cw_d_zero(b))) { return vec2<u32>(0u,2146959360u); }
  if(cw_d_inf(a) || cw_d_zero(b)) { return vec2<u32>(0u,sign | 2146435072u); }
  if(cw_d_zero(a) || cw_d_inf(b)) { return vec2<u32>(0u,sign); }
  let pa = cw_d_parts(a); let pb = cw_d_parts(b); var e = pa.exponent-pb.exponent;
  var remainder = pa.significand; var q = vec2<u32>(0u);
  if(cw_d_uless(remainder,pb.significand)) { remainder = cw_d_shl(remainder,1u); e--; }
  for(var i = 0u; i < 56u; i++) {
    q = cw_d_shl(q,1u);
    if(!cw_d_uless(remainder,pb.significand)) { remainder = cw_d_usub(remainder,pb.significand); q.x |= 1u; }
    if(i < 55u) { remainder = cw_d_shl(remainder,1u); }
  }
  if(any(remainder != vec2<u32>(0u))) { q.x |= 1u; }
  return cw_d_pack(sign,e,q);
}

// Restoring square root: 56 root bits include guard/round/sticky for binary64.
fn cw_d_sqrt(a: cw_f64) -> cw_f64 {
  if(cw_d_nan(a)) { return vec2<u32>(0u,2146959360u); }
  if(cw_d_zero(a)) { return a; }
  if((a.y & 2147483648u) != 0u) { return vec2<u32>(0u,2146959360u); }
  if(cw_d_inf(a)) { return a; }
  let p = cw_d_parts(a);
  let odd = p.exponent & 1i;
  let shift = 58i + odd;
  var root = vec2<u32>(0u);
  var remainder = vec2<u32>(0u);
  for(var i=55i; i>=0i; i--) {
    var pair=0u;
    for(var j=0i; j<2i; j++) {
      let bit=2i*i+j-shift;
      if(bit>=0i && bit<53i) { pair |= ((p.significand[u32(bit)/32u] >> (u32(bit)%32u)) & 1u) << u32(j); }
    }
    remainder=cw_d_shl(remainder,2u); remainder.x |= pair;
    var trial=cw_d_shl(root,2u); trial.x |= 1u;
    root=cw_d_shl(root,1u);
    if(!cw_d_uless(remainder,trial)) { remainder=cw_d_usub(remainder,trial); root.x |= 1u; }
  }
  if(any(remainder!=vec2<u32>(0u))) { root.x |= 1u; }
  return cw_d_pack(0u,(p.exponent-odd)/2i,root);
}
fn cw_d_fmin(a: cw_f64,b: cw_f64) -> cw_f64 {
  if(cw_d_nan(a)) { return b; } if(cw_d_nan(b)) { return a; }
  if(cw_d_zero(a) && cw_d_zero(b)) { return vec2<u32>(0u,(a.y | b.y) & 2147483648u); }
  return select(b,a,cw_d_lt(a,b));
}
fn cw_d_fmax(a: cw_f64,b: cw_f64) -> cw_f64 {
  if(cw_d_nan(a)) { return b; } if(cw_d_nan(b)) { return a; }
  if(cw_d_zero(a) && cw_d_zero(b)) { return vec2<u32>(0u,(a.y & b.y) & 2147483648u); }
  return select(a,b,cw_d_lt(a,b));
}

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
fn f_substrateMean(cw_arg_material: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var v_material: i32 = cw_arg_material;
  var cw_tmp_13: vec3<f32>;
  if ((v_material == 1i)) {
    cw_tmp_13 = vec3<f32>(0.37f, 0.185f, 0.105f);
  } else {
    cw_tmp_13 = vec3<f32>(0.55f, 0.485f, 0.365f);
  }
  return cw_tmp_13;
}
fn f_substrate(cw_arg_u: f32, cw_arg_v: f32, cw_arg_seed: f32, cw_arg_material: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var v_u: f32 = cw_arg_u;
  var v_v: f32 = cw_arg_v;
  var v_seed: f32 = cw_arg_seed;
  var v_material: i32 = cw_arg_material;
  var v_large: f32 = f_fbm2(((v_u * 0.31f) + (v_seed * 0.013f)), (v_v * 0.31f), cw_thread, cw_block, cw_grid);
  var v_run: f32 = f_fbm2(((v_u * 0.42f) + (v_seed * 0.01f)), ((v_v * 0.038f) + 1.7f), cw_thread, cw_block, cw_grid);
  var v_base: vec3<f32> = f_substrateMean(v_material, cw_thread, cw_block, cw_grid);
  var v_age: f32 = (0.61f + (0.52f * v_large));
  var v_damp: f32 = (f_smoothf(0.49f, 0.76f, v_run, cw_thread, cw_block, cw_grid) * 0.31f);
  return ((v_base * vec3<f32>((v_age - v_damp))) + (vec3<f32>(0.017f, 0.024f, 0.014f) * vec3<f32>(v_damp)));
}
fn f_feature(cw_arg_i: i32, cw_arg_u: f32, cw_arg_v: f32, cw_arg_seed: f32, cw_arg_mat: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_i: i32 = cw_arg_i;
  var v_u: f32 = cw_arg_u;
  var v_v: f32 = cw_arg_v;
  var v_seed: f32 = cw_arg_seed;
  var v_mat: i32 = cw_arg_mat;
  if ((v_i == 0i)) {
    return sin((v_u * 0.13f));
  }
  if ((v_i == 1i)) {
    return cos((v_u * 0.13f));
  }
  if ((v_i == 2i)) {
    return sin((v_v * 0.13f));
  }
  if ((v_i == 3i)) {
    return cos((v_v * 0.13f));
  }
  if ((v_i == 4i)) {
    return ((f_noise2(((v_u * 0.31f) + (v_seed * 0.013f)), (v_v * 0.31f), cw_thread, cw_block, cw_grid) * 2.0f) - 1.0f);
  }
  if ((v_i == 5i)) {
    return ((f_noise2(((v_u * 0.42f) + (v_seed * 0.01f)), ((v_v * 0.038f) + 1.7f), cw_thread, cw_block, cw_grid) * 2.0f) - 1.0f);
  }
  if ((v_i == 6i)) {
    return ((f32(v_mat) * 2.0f) - 1.0f);
  }
  return sin((v_seed * 0.03f));
}
fn f_activate(cw_arg_x: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_x: f32 = cw_arg_x;
  v_x = f_clampf(v_x, (-8.0f), 8.0f, cw_thread, cw_block, cw_grid);
  return (cw_divide_f32(2.0f, (1.0f + exp(((-2.0f) * v_x)))) - 1.0f);
}
fn f_sky(cw_arg_rd: vec3<f32>, cw_arg_sun: vec3<f32>, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var v_rd: vec3<f32> = cw_arg_rd;
  var v_sun: vec3<f32> = cw_arg_sun;
  var v_elev: f32 = f_sat(v_rd.y, cw_thread, cw_block, cw_grid);
  var v_c: vec3<f32> = f_mix3(vec3<f32>(0.62f, 0.69f, 0.72f), vec3<f32>(0.13f, 0.3f, 0.52f), cw_pow_f32(v_elev, 0.45f), cw_thread, cw_block, cw_grid);
  var v_sd: f32 = max(0.0f, f_dot3(v_rd, v_sun, cw_thread, cw_block, cw_grid));
  v_c = ((v_c + (vec3<f32>(1.1f, 0.62f, 0.22f) * vec3<f32>(cw_pow_f32(v_sd, 18.0f)))) + (vec3<f32>(9.0f, 6.0f, 3.2f) * vec3<f32>(cw_pow_f32(v_sd, 2600.0f))));
  if ((v_rd.y > 0.025f)) {
    var v_cloud: f32 = f_fbm2(((cw_divide_f32(v_rd.x, (v_rd.y + 0.2f)) * 1.8f) + 16.0f), (cw_divide_f32(v_rd.z, (v_rd.y + 0.2f)) * 1.8f), cw_thread, cw_block, cw_grid);
    var v_veil: f32 = ((f_smoothf(0.46f, 0.7f, v_cloud, cw_thread, cw_block, cw_grid) * f_smoothf(0.02f, 0.2f, v_rd.y, cw_thread, cw_block, cw_grid)) * 0.55f);
    v_c = f_mix3(v_c, vec3<f32>(0.86f, 0.85f, 0.8f), v_veil, cw_thread, cw_block, cw_grid);
  }
  return v_c;
}
fn f_mineralCell(cw_arg_u: f32, cw_arg_v: f32, cw_arg_seed: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var v_u: f32 = cw_arg_u;
  var v_v: f32 = cw_arg_v;
  var v_seed: i32 = cw_arg_seed;
  var v_ix: i32 = i32(floor(v_u));
  var v_iy: i32 = i32(floor(v_v));
  var v_x: f32 = f_fractf(v_u, cw_thread, cw_block, cw_grid);
  var v_y: f32 = f_fractf(v_v, cw_thread, cw_block, cw_grid);
  var v_nearest: f32 = 10.0f;
  var v_second: f32 = 10.0f;
  var v_value: f32 = 0.0f;
  {
    var v_j: i32 = (-1i);
    loop {
      if (!(v_j <= 1i)) { break; }
      {
        var v_i: i32 = (-1i);
        loop {
          if (!(v_i <= 1i)) { break; }
          var v_dx: f32 = (((f32(v_i) + 0.18f) + (0.64f * f_hash2((v_ix + v_i), (v_iy + v_j), v_seed, cw_thread, cw_block, cw_grid))) - v_x);
          var v_dy: f32 = (((f32(v_j) + 0.18f) + (0.64f * f_hash2((v_ix + v_i), (v_iy + v_j), (v_seed + 47i), cw_thread, cw_block, cw_grid))) - v_y);
          var v_d: f32 = ((v_dx * v_dx) + (v_dy * v_dy));
          if ((v_d < v_nearest)) {
            v_second = v_nearest;
            v_nearest = v_d;
            v_value = f_hash2((v_ix + v_i), (v_iy + v_j), (v_seed + 83i), cw_thread, cw_block, cw_grid);
          } else {
            v_second = min(v_second, v_d);
          }
          continuing {
            v_i += i32(1);
          }
        }
      }
      continuing {
        v_j += i32(1);
      }
    }
  }
  return vec3<f32>(sqrt(v_nearest), v_value, (sqrt(v_second) - sqrt(v_nearest)));
}
fn f_microRelief(cw_arg_u: f32, cw_arg_v: f32, cw_arg_footprint: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_u: f32 = cw_arg_u;
  var v_v: f32 = cw_arg_v;
  var v_footprint: f32 = cw_arg_footprint;
  var v_value: f32 = (((f_noise2((v_u * 83.0f), (v_v * 83.0f), cw_thread, cw_block, cw_grid) - 0.5f) * 0.0016f) * f_frequencyWeight(v_footprint, 83.0f, cw_thread, cw_block, cw_grid));
  v_value = (v_value + (((f_noise2(((v_u * 277.0f) + 8.7f), (v_v * 277.0f), cw_thread, cw_block, cw_grid) - 0.5f) * 0.00048f) * f_frequencyWeight(v_footprint, 277.0f, cw_thread, cw_block, cw_grid)));
  v_value = (v_value + (((f_noise2((v_u * 911.0f), ((v_v * 911.0f) - 13.9f), cw_thread, cw_block, cw_grid) - 0.5f) * 0.00013f) * f_frequencyWeight(v_footprint, 911.0f, cw_thread, cw_block, cw_grid)));
  return v_value;
}
fn f_surfaceColor(cw_arg_p: vec3<f32>, cw_arg_n: vec3<f32>, cw_arg_mat: i32, cw_arg_seed: f32, cw_arg_footprint: f32, cw_arg_foundation: vec3<f32>, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var v_p: vec3<f32> = cw_arg_p;
  var v_n: vec3<f32> = cw_arg_n;
  var v_mat: i32 = cw_arg_mat;
  var v_seed: f32 = cw_arg_seed;
  var v_footprint: f32 = cw_arg_footprint;
  var v_foundation: vec3<f32> = cw_arg_foundation;
  var v_uv: vec2<f32> = f_masonryUV(v_p, v_n, cw_thread, cw_block, cw_grid);
  var v_u: f32 = v_uv.x;
  var v_v: f32 = v_uv.y;
  var v_fine: f32 = f_frequencyWeight(v_footprint, 34.0f, cw_thread, cw_block, cw_grid);
  var v_c: vec3<f32> = v_foundation;
  if (((v_mat == 0i) || (v_mat == 1i))) {
    var cw_tmp_14: f32;
    if ((v_mat == 1i)) {
      cw_tmp_14 = 0.46f;
    } else {
      cw_tmp_14 = 0.92f;
    }
    var v_bw: f32 = cw_tmp_14;
    var cw_tmp_15: f32;
    if ((v_mat == 1i)) {
      cw_tmp_15 = 0.215f;
    } else {
      cw_tmp_15 = 0.46f;
    }
    var v_bh: f32 = cw_tmp_15;
    var v_row: i32 = i32(floor(cw_divide_f32(v_v, v_bh)));
    var v_brick: i32 = i32(floor((cw_divide_f32(v_u, v_bw) + (f32(f_imod(v_row, 2i, cw_thread, cw_block, cw_grid)) * 0.5f))));
    var v_xx: f32 = f_fractf((cw_divide_f32(v_u, v_bw) + (f32(f_imod(v_row, 2i, cw_thread, cw_block, cw_grid)) * 0.5f)), cw_thread, cw_block, cw_grid);
    var v_yy: f32 = f_fractf(cw_divide_f32(v_v, v_bh), cw_thread, cw_block, cw_grid);
    var v_edge: f32 = min((min(v_xx, (1.0f - v_xx)) * v_bw), (min(v_yy, (1.0f - v_yy)) * v_bh));
    var v_joint: f32 = ((1.0f - f_smoothf(0.005f, (0.021f + (v_footprint * 0.4f)), v_edge, cw_thread, cw_block, cw_grid)) * f_frequencyWeight(v_footprint, cw_divide_f32(1.0f, v_bh), cw_thread, cw_block, cw_grid));
    var v_variation: f32 = (((f_hash2(v_brick, v_row, i32(v_seed), cw_thread, cw_block, cw_grid) - 0.5f) * 0.19f) * f_frequencyWeight(v_footprint, cw_divide_f32(1.0f, v_bh), cw_thread, cw_block, cw_grid));
    v_c = (v_c * vec3<f32>((1.0f + v_variation)));
    v_c = f_mix3(v_c, vec3<f32>(0.25f, 0.245f, 0.21f), (v_joint * 0.84f), cw_thread, cw_block, cw_grid);
    var v_pores: f32 = f_fbm2(((v_u * 52.0f) + v_seed), (v_v * 52.0f), cw_thread, cw_block, cw_grid);
    v_c = (v_c * vec3<f32>((1.0f + (((v_pores - 0.5f) * 0.38f) * v_fine))));
    var v_deposits: f32 = f_smoothf(0.45f, 0.76f, f_fbm2(((v_u * 5.1f) + (v_seed * 0.3f)), (v_v * 6.2f), cw_thread, cw_block, cw_grid), cw_thread, cw_block, cw_grid);
    v_c = f_mix3(v_c, vec3<f32>(0.52f, 0.49f, 0.39f), ((v_deposits * 0.23f) * (1.0f - v_joint)), cw_thread, cw_block, cw_grid);
    if ((v_footprint < 0.007f)) {
      var v_mineral: vec3<f32> = f_mineralCell((v_u * 190.0f), (v_v * 190.0f), i32(v_seed), cw_thread, cw_block, cw_grid);
      var v_detail: f32 = f_frequencyWeight(v_footprint, 190.0f, cw_thread, cw_block, cw_grid);
      var v_pit: f32 = (((1.0f - f_smoothf(0.075f, 0.23f, v_mineral.x, cw_thread, cw_block, cw_grid)) * f_smoothf(0.52f, 0.76f, v_mineral.y, cw_thread, cw_block, cw_grid)) * v_detail);
      var v_grit: f32 = ((1.0f - f_smoothf(0.018f, 0.072f, v_mineral.z, cw_thread, cw_block, cw_grid)) * v_detail);
      v_c = (v_c * vec3<f32>(((1.0f - (v_pit * 0.66f)) - (v_grit * 0.075f))));
      var v_fleck: f32 = (((1.0f - f_smoothf(0.04f, 0.17f, v_mineral.x, cw_thread, cw_block, cw_grid)) * (1.0f - f_smoothf(0.07f, 0.18f, v_mineral.y, cw_thread, cw_block, cw_grid))) * v_detail);
      v_c = f_mix3(v_c, vec3<f32>(0.62f, 0.56f, 0.44f), (v_fleck * 0.78f), cw_thread, cw_block, cw_grid);
      var v_powder: f32 = ((f_noise2((v_u * 740.0f), (v_v * 740.0f), cw_thread, cw_block, cw_grid) - 0.5f) * f_frequencyWeight(v_footprint, 740.0f, cw_thread, cw_block, cw_grid));
      var cw_tmp_16: f32;
      if ((v_joint > 0.5f)) {
        cw_tmp_16 = 0.5f;
      } else {
        cw_tmp_16 = 0.24f;
      }
      v_c = (v_c * vec3<f32>((1.0f + (v_powder * cw_tmp_16))));
    }
    var v_crack: f32 = abs(sin((((v_u * 8.4f) + (f_fbm2((v_u * 2.4f), (v_v * 2.4f), cw_thread, cw_block, cw_grid) * 5.0f)) + (v_v * 1.3f))));
    var v_fracture: f32 = ((1.0f - f_smoothf(0.012f, (0.042f + (v_footprint * 4.0f)), v_crack, cw_thread, cw_block, cw_grid)) * f_smoothf(0.48f, 0.72f, f_noise2((v_u * 1.4f), (v_v * 1.4f), cw_thread, cw_block, cw_grid), cw_thread, cw_block, cw_grid));
    v_c = (v_c * vec3<f32>((1.0f - ((v_fracture * 0.45f) * f_frequencyWeight(v_footprint, 15.0f, cw_thread, cw_block, cw_grid)))));
    var v_moss: f32 = ((1.0f - f_smoothf(0.1f, 3.1f, v_p.y, cw_thread, cw_block, cw_grid)) * f_smoothf(0.44f, 0.69f, f_noise2((v_u * 1.3f), (v_v * 0.3f), cw_thread, cw_block, cw_grid), cw_thread, cw_block, cw_grid));
    v_c = f_mix3(v_c, vec3<f32>(0.095f, 0.125f, 0.046f), (v_moss * 0.7f), cw_thread, cw_block, cw_grid);
  } else {
    if (((v_mat == 2i) || (v_mat == 14i))) {
      var cw_tmp_17: vec3<f32>;
      if ((v_mat == 2i)) {
        cw_tmp_17 = vec3<f32>(0.14f, 0.19f, 0.22f);
      } else {
        cw_tmp_17 = vec3<f32>(0.38f, 0.125f, 0.048f);
      }
      v_c = cw_tmp_17;
      var v_tile: f32 = f_fractf((v_u * 3.7f), cw_thread, cw_block, cw_grid);
      var v_row: f32 = f_fractf((v_v * 4.4f), cw_thread, cw_block, cw_grid);
      var v_seam: f32 = ((1.0f - f_smoothf(0.01f, 0.07f, v_tile, cw_thread, cw_block, cw_grid)) + (1.0f - f_smoothf(0.02f, 0.11f, v_row, cw_thread, cw_block, cw_grid)));
      v_c = (v_c * vec3<f32>(((0.78f + (0.26f * f_noise2((v_u * 7.2f), (v_v * 7.2f), cw_thread, cw_block, cw_grid))) - ((f_sat(v_seam, cw_thread, cw_block, cw_grid) * 0.25f) * f_frequencyWeight(v_footprint, 4.4f, cw_thread, cw_block, cw_grid)))));
    } else {
      if ((v_mat == 3i)) {
        var v_patina: f32 = f_smoothf(0.28f, 0.64f, f_fbm2((v_u * 2.1f), (v_v * 2.1f), cw_thread, cw_block, cw_grid), cw_thread, cw_block, cw_grid);
        v_c = f_mix3(vec3<f32>(0.27f, 0.145f, 0.072f), vec3<f32>(0.085f, 0.24f, 0.18f), v_patina, cw_thread, cw_block, cw_grid);
        var v_seam: f32 = (1.0f - f_smoothf(0.015f, 0.07f, f_fractf((v_u * 1.8f), cw_thread, cw_block, cw_grid), cw_thread, cw_block, cw_grid));
        v_c = (v_c * vec3<f32>((1.0f - ((v_seam * 0.4f) * f_frequencyWeight(v_footprint, 1.8f, cw_thread, cw_block, cw_grid)))));
      } else {
        if ((v_mat == 4i)) {
          v_c = vec3<f32>(0.045f, 0.084f, 0.093f);
        } else {
          if ((v_mat == 5i)) {
            var v_grain: f32 = sin(((v_u * 49.0f) + (f_fbm2((v_u * 2.0f), (v_v * 0.5f), cw_thread, cw_block, cw_grid) * 8.0f)));
            v_c = (vec3<f32>(0.12f, 0.07f, 0.039f) * vec3<f32>((1.0f + ((v_grain * 0.12f) * v_fine))));
          } else {
            if ((v_mat == 6i)) {
              v_c = (vec3<f32>(0.075f, 0.091f, 0.087f) * vec3<f32>((0.8f + (f_noise2((v_u * 30.0f), (v_v * 30.0f), cw_thread, cw_block, cw_grid) * 0.3f))));
            } else {
              if ((v_mat == 7i)) {
                var v_leaves: f32 = f_fbm2(((v_p.x * 8.0f) + (v_p.y * 6.0f)), (v_p.z * 8.0f), cw_thread, cw_block, cw_grid);
                v_c = f_mix3(vec3<f32>(0.055f, 0.095f, 0.02f), vec3<f32>(0.18f, 0.25f, 0.055f), v_leaves, cw_thread, cw_block, cw_grid);
              } else {
                if ((v_mat == 8i)) {
                  v_c = vec3<f32>(0.7f, 0.43f, 0.13f);
                } else {
                  if ((v_mat == 9i)) {
                    v_c = vec3<f32>(0.035f, 0.115f, 0.12f);
                  } else {
                    if ((v_mat == 10i)) {
                      var v_grit: f32 = f_fbm2((v_u * 45.0f), (v_v * 45.0f), cw_thread, cw_block, cw_grid);
                      v_c = (vec3<f32>(0.16f, 0.17f, 0.16f) * vec3<f32>((0.72f + (v_grit * 0.4f))));
                    } else {
                      if ((v_mat == 11i)) {
                        var v_row: i32 = i32(floor(cw_divide_f32(v_v, 0.45f)));
                        var v_a: f32 = f_fractf((cw_divide_f32(v_u, 0.9f) + (f32(f_imod(v_row, 2i, cw_thread, cw_block, cw_grid)) * 0.5f)), cw_thread, cw_block, cw_grid);
                        var v_b: f32 = f_fractf(cw_divide_f32(v_v, 0.45f), cw_thread, cw_block, cw_grid);
                        var v_joint: f32 = (1.0f - f_smoothf(0.02f, (0.07f + v_footprint), min(min(v_a, (1.0f - v_a)), min(v_b, (1.0f - v_b))), cw_thread, cw_block, cw_grid));
                        v_c = (vec3<f32>(0.43f, 0.415f, 0.36f) * vec3<f32>((0.78f + (f_fbm2((v_u * 18.0f), (v_v * 18.0f), cw_thread, cw_block, cw_grid) * 0.3f))));
                        v_c = (v_c * vec3<f32>((1.0f - ((v_joint * 0.3f) * f_frequencyWeight(v_footprint, 2.0f, cw_thread, cw_block, cw_grid)))));
                      } else {
                        if ((v_mat == 13i)) {
                          v_c = (vec3<f32>(0.54f, 0.475f, 0.35f) * vec3<f32>((0.82f + (f_fbm2((v_u * 1.6f), (v_v * 1.6f), cw_thread, cw_block, cw_grid) * 0.24f))));
                        } else {
                          if ((v_mat == 15i)) {
                            v_c = (vec3<f32>(0.17f, 0.12f, 0.065f) * vec3<f32>((0.65f + (0.6f * f_fbm2((v_u * 31.0f), (v_v * 3.0f), cw_thread, cw_block, cw_grid)))));
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
  if ((v_mat == 18i)) {
    var v_panel: f32 = f_fractf(cw_divide_f32(v_u, 1.6f), cw_thread, cw_block, cw_grid);
    var v_frame: f32 = ((1.0f - f_smoothf(0.02f, 0.06f, v_panel, cw_thread, cw_block, cw_grid)) + (1.0f - f_smoothf(0.02f, 0.06f, (1.0f - v_panel), cw_thread, cw_block, cw_grid)));
    var v_band: f32 = (1.0f - f_smoothf(0.03f, 0.07f, abs((v_v - 2.65f)), cw_thread, cw_block, cw_grid));
    v_c = f_mix3(vec3<f32>(0.058f, 0.092f, 0.105f), vec3<f32>(0.1f, 0.059f, 0.027f), f_sat((v_frame + v_band), cw_thread, cw_block, cw_grid), cw_thread, cw_block, cw_grid);
  }
  if ((v_mat == 17i)) {
    var v_a: f32 = atan2(((v_v - (floor(cw_divide_f32(v_v, 30.0f)) * 30.0f)) - 28.5f), v_u);
    var v_glass: f32 = (0.5f + (0.5f * sin(((v_a * 12.0f) + v_seed))));
    v_c = f_mix3(vec3<f32>(0.08f, 0.18f, 0.32f), vec3<f32>(0.5f, 0.12f, 0.04f), v_glass, cw_thread, cw_block, cw_grid);
  }
  return v_c;
}
fn f_aces(cw_arg_x: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_x: f32 = cw_arg_x;
  return f_sat(cw_divide_f32((v_x * ((2.51f * v_x) + 0.03f)), ((v_x * ((2.43f * v_x) + 0.59f)) + 0.14f)), cw_thread, cw_block, cw_grid);
}
fn f_cw_buffer_helper_0(cw_buffer_arg_0: i32, cw_arg_x: i32, cw_arg_y: i32, cw_arg_width: i32, cw_arg_height: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
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
  var v_f: vec3<f32> = f_cw_buffer_helper_7((cw_buffer_offset_0 + 0i), cw_thread, cw_block, cw_grid);
  var v_r: vec3<f32> = f_cw_buffer_helper_8((cw_buffer_offset_0 + 0i), cw_thread, cw_block, cw_grid);
  var v_u: vec3<f32> = f_cross3(v_f, v_r, cw_thread, cw_block, cw_grid);
  return f_norm3(((v_f + (v_r * vec3<f32>(v_sx))) + (v_u * vec3<f32>(v_sy))), cw_thread, cw_block, cw_grid);
}
fn f_cw_buffer_helper_1(cw_buffer_arg_0: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  let cw_argument_index_29 = (cw_buffer_offset_0 + 0i);
  let cw_argument_index_30 = (cw_buffer_offset_0 + 1i);
  let cw_argument_index_31 = (cw_buffer_offset_0 + 2i);
  return vec3<f32>(b_C[cw_argument_index_29], b_C[cw_argument_index_30], b_C[cw_argument_index_31]);
}
fn f_cw_buffer_helper_2(cw_buffer_arg_0: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  let cw_argument_index_32 = (cw_buffer_offset_0 + 7i);
  let cw_argument_index_33 = (cw_buffer_offset_0 + 8i);
  let cw_argument_index_34 = (cw_buffer_offset_0 + 8i);
  let cw_argument_index_35 = (cw_buffer_offset_0 + 7i);
  let cw_argument_index_36 = (cw_buffer_offset_0 + 8i);
  return f_norm3(vec3<f32>((cos(b_C[cw_argument_index_32]) * cos(b_C[cw_argument_index_33])), sin(b_C[cw_argument_index_34]), (sin(b_C[cw_argument_index_35]) * cos(b_C[cw_argument_index_36]))), cw_thread, cw_block, cw_grid);
}
fn f_cw_buffer_helper_3(cw_buffer_arg_0: i32, cw_arg_id: i32, cw_arg_point: vec3<f32>, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_id: i32 = cw_arg_id;
  var v_point: vec3<f32> = cw_arg_point;
  var v_b: i32 = (v_id * 16i);
  var v_shape: i32 = i32(b_P[(cw_buffer_offset_0 + (v_b + 3i))]);
  var v_turn: i32 = i32(b_P[(cw_buffer_offset_0 + (v_b + 8i))]);
  let cw_argument_index_37 = (cw_buffer_offset_0 + v_b);
  let cw_argument_index_38 = (cw_buffer_offset_0 + (v_b + 1i));
  let cw_argument_index_39 = (cw_buffer_offset_0 + (v_b + 2i));
  var v_p: vec3<f32> = f_localPoint((v_point - vec3<f32>(b_P[cw_argument_index_37], b_P[cw_argument_index_38], b_P[cw_argument_index_39])), v_turn, cw_thread, cw_block, cw_grid);
  let cw_argument_index_40 = (cw_buffer_offset_0 + (v_b + 4i));
  let cw_argument_index_41 = (cw_buffer_offset_0 + (v_b + 5i));
  let cw_argument_index_42 = (cw_buffer_offset_0 + (v_b + 6i));
  var v_h: vec3<f32> = vec3<f32>(b_P[cw_argument_index_40], b_P[cw_argument_index_41], b_P[cw_argument_index_42]);
  var v_n: vec3<f32> = vec3<f32>(0.0f, 1.0f, 0.0f);
  if ((v_shape == 1i)) {
    v_n = f_norm3(vec3<f32>(cw_divide_f32(v_p.x, (v_h.x * v_h.x)), cw_divide_f32(v_p.y, (v_h.y * v_h.y)), cw_divide_f32(v_p.z, (v_h.z * v_h.z))), cw_thread, cw_block, cw_grid);
  } else {
    if ((v_shape == 2i)) {
      if ((abs((abs(v_p.y) - v_h.y)) < 0.01f)) {
        var cw_tmp_43: f32;
        if ((v_p.y < 0.0f)) {
          cw_tmp_43 = (-1.0f);
        } else {
          cw_tmp_43 = 1.0f;
        }
        v_n = vec3<f32>(0.0f, cw_tmp_43, 0.0f);
      } else {
        v_n = f_norm3(vec3<f32>(cw_divide_f32(v_p.x, (v_h.x * v_h.x)), 0.0f, cw_divide_f32(v_p.z, (v_h.z * v_h.z))), cw_thread, cw_block, cw_grid);
      }
    } else {
      if (((v_shape == 4i) || (v_shape == 7i))) {
        if ((abs((abs(v_p.z) - v_h.z)) < 0.008f)) {
          var cw_tmp_44: f32;
          if ((v_p.z < 0.0f)) {
            cw_tmp_44 = (-1.0f);
          } else {
            cw_tmp_44 = 1.0f;
          }
          v_n = vec3<f32>(0.0f, 0.0f, cw_tmp_44);
        } else {
          var v_rr: f32 = (cw_divide_f32((v_p.x * v_p.x), (v_h.x * v_h.x)) + cw_divide_f32((v_p.y * v_p.y), (v_h.y * v_h.y)));
          var cw_tmp_45: f32;
          if ((v_rr < 0.8f)) {
            cw_tmp_45 = (-1.0f);
          } else {
            cw_tmp_45 = 1.0f;
          }
          v_n = (f_norm3(vec3<f32>(cw_divide_f32(v_p.x, (v_h.x * v_h.x)), cw_divide_f32(v_p.y, (v_h.y * v_h.y)), 0.0f), cw_thread, cw_block, cw_grid) * vec3<f32>(cw_tmp_45));
        }
      } else {
        if ((v_shape == 3i)) {
          if ((abs((abs(v_p.z) - v_h.z)) < 0.006f)) {
            var cw_tmp_46: f32;
            if ((v_p.z < 0.0f)) {
              cw_tmp_46 = (-1.0f);
            } else {
              cw_tmp_46 = 1.0f;
            }
            v_n = vec3<f32>(0.0f, 0.0f, cw_tmp_46);
          } else {
            if ((v_p.y < 0.003f)) {
              v_n = vec3<f32>(0.0f, (-1.0f), 0.0f);
            } else {
              var cw_tmp_47: f32;
              if ((v_p.x < 0.0f)) {
                cw_tmp_47 = cw_divide_f32((-v_h.y), v_h.x);
              } else {
                cw_tmp_47 = cw_divide_f32(v_h.y, v_h.x);
              }
              v_n = f_norm3(vec3<f32>(cw_tmp_47, 1.0f, 0.0f), cw_thread, cw_block, cw_grid);
            }
          }
        } else {
          var v_a: vec3<f32> = vec3<f32>(abs((abs(v_p.x) - v_h.x)), abs((abs(v_p.y) - v_h.y)), abs((abs(v_p.z) - v_h.z)));
          var cw_tmp_52: vec3<f32>;
          if (((v_a.x < v_a.y) && (v_a.x < v_a.z))) {
            var cw_tmp_48: f32;
            if ((v_p.x < 0.0f)) {
              cw_tmp_48 = (-1.0f);
            } else {
              cw_tmp_48 = 1.0f;
            }
            cw_tmp_52 = vec3<f32>(cw_tmp_48, 0.0f, 0.0f);
          } else {
            var cw_tmp_51: vec3<f32>;
            if ((v_a.y < v_a.z)) {
              var cw_tmp_49: f32;
              if ((v_p.y < 0.0f)) {
                cw_tmp_49 = (-1.0f);
              } else {
                cw_tmp_49 = 1.0f;
              }
              cw_tmp_51 = vec3<f32>(0.0f, cw_tmp_49, 0.0f);
            } else {
              var cw_tmp_50: f32;
              if ((v_p.z < 0.0f)) {
                cw_tmp_50 = (-1.0f);
              } else {
                cw_tmp_50 = 1.0f;
              }
              cw_tmp_51 = vec3<f32>(0.0f, 0.0f, cw_tmp_50);
            }
            cw_tmp_52 = cw_tmp_51;
          }
          v_n = cw_tmp_52;
          var v_bevel: f32 = min(0.035f, (min(min(v_h.x, v_h.y), v_h.z) * 0.18f));
          var cw_tmp_53: f32;
          if ((v_p.x < 0.0f)) {
            cw_tmp_53 = (-1.0f);
          } else {
            cw_tmp_53 = 1.0f;
          }
          var cw_tmp_54: f32;
          if ((v_p.y < 0.0f)) {
            cw_tmp_54 = (-1.0f);
          } else {
            cw_tmp_54 = 1.0f;
          }
          var cw_tmp_55: f32;
          if ((v_p.z < 0.0f)) {
            cw_tmp_55 = (-1.0f);
          } else {
            cw_tmp_55 = 1.0f;
          }
          var v_q: vec3<f32> = vec3<f32>((max(((abs(v_p.x) - v_h.x) + v_bevel), 0.0f) * cw_tmp_53), (max(((abs(v_p.y) - v_h.y) + v_bevel), 0.0f) * cw_tmp_54), (max(((abs(v_p.z) - v_h.z) + v_bevel), 0.0f) * cw_tmp_55));
          if ((f_dot3(v_q, v_q, cw_thread, cw_block, cw_grid) > 0.000001f)) {
            v_n = f_norm3(v_q, cw_thread, cw_block, cw_grid);
          }
        }
      }
    }
  }
  if (((v_shape == 1i) && (i32(b_P[(cw_buffer_offset_0 + (v_b + 7i))]) == 7i))) {
    return f_leafNormal(i32(floor(cw_divide_f32(v_point.x, 0.18f))), i32(floor(cw_divide_f32(v_point.y, 0.18f))), i32(floor(cw_divide_f32(v_point.z, 0.18f))), i32(b_P[(cw_buffer_offset_0 + (v_b + 9i))]), cw_thread, cw_block, cw_grid);
  }
  return f_worldNormal(v_n, v_turn, cw_thread, cw_block, cw_grid);
}
fn f_cw_buffer_helper_4(cw_buffer_arg_0: i32, cw_arg_u: f32, cw_arg_v: f32, cw_arg_seed: f32, cw_arg_mat: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_u: f32 = cw_arg_u;
  var v_v: f32 = cw_arg_v;
  var v_seed: f32 = cw_arg_seed;
  var v_mat: i32 = cw_arg_mat;
  var v_hidden: array<f32, 24>;
  {
    var v_h: i32 = 0i;
    loop {
      if (!(v_h < 24i)) { break; }
      var v_z: f32 = b_W[(cw_buffer_offset_0 + (192i + v_h))];
      {
        var v_j: i32 = 0i;
        loop {
          if (!(v_j < 8i)) { break; }
          v_z = (v_z + (b_W[(cw_buffer_offset_0 + ((v_h * 8i) + v_j))] * f_feature(v_j, v_u, v_v, v_seed, v_mat, cw_thread, cw_block, cw_grid)));
          continuing {
            v_j += i32(1);
          }
        }
      }
      v_hidden[v_h] = f_activate(v_z, cw_thread, cw_block, cw_grid);
      continuing {
        v_h += i32(1);
      }
    }
  }
  let cw_argument_index_56 = (cw_buffer_offset_0 + 288i);
  let cw_argument_index_57 = (cw_buffer_offset_0 + 289i);
  let cw_argument_index_58 = (cw_buffer_offset_0 + 290i);
  var v_out: vec3<f32> = vec3<f32>(b_W[cw_argument_index_56], b_W[cw_argument_index_57], b_W[cw_argument_index_58]);
  {
    var v_h: i32 = 0i;
    loop {
      if (!(v_h < 24i)) { break; }
      v_out.x = (v_out.x + (b_W[(cw_buffer_offset_0 + (216i + v_h))] * v_hidden[v_h]));
      v_out.y = (v_out.y + (b_W[(cw_buffer_offset_0 + (240i + v_h))] * v_hidden[v_h]));
      v_out.z = (v_out.z + (b_W[(cw_buffer_offset_0 + (264i + v_h))] * v_hidden[v_h]));
      continuing {
        v_h += i32(1);
      }
    }
  }
  return vec3<f32>(f_sat(v_out.x, cw_thread, cw_block, cw_grid), f_sat(v_out.y, cw_thread, cw_block, cw_grid), f_sat(v_out.z, cw_thread, cw_block, cw_grid));
}
fn f_cw_buffer_helper_5(cw_buffer_arg_0: i32, cw_arg_p: vec3<f32>, cw_arg_light: vec3<f32>, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_p: vec3<f32> = cw_arg_p;
  var v_light: vec3<f32> = cw_arg_light;
  if ((v_light.y < 0.005f)) {
    return 0.0f;
  }
  var v_maxT: f32 = cw_divide_f32((90.0f - v_p.y), v_light.y);
  if ((v_maxT < 0.0f)) {
    return 1.0f;
  }
  v_maxT = min(v_maxT, 800.0f);
  var v_ro: vec3<f32> = (v_p + (v_light * vec3<f32>(0.08f)));
  var v_cx: i32 = i32(floor(cw_divide_f32((v_ro.x + 18.0f), 36.0f)));
  var v_cz: i32 = i32(floor(cw_divide_f32((v_ro.z + 18.0f), 36.0f)));
  var cw_tmp_59: i32;
  if ((v_light.x > 0.0f)) {
    cw_tmp_59 = 1i;
  } else {
    cw_tmp_59 = (-1i);
  }
  var v_sx: i32 = cw_tmp_59;
  var cw_tmp_60: i32;
  if ((v_light.z > 0.0f)) {
    cw_tmp_60 = 1i;
  } else {
    cw_tmp_60 = (-1i);
  }
  var v_sz: i32 = cw_tmp_60;
  var cw_tmp_61: f32;
  if ((v_sx > 0i)) {
    cw_tmp_61 = 18.0f;
  } else {
    cw_tmp_61 = (-18.0f);
  }
  var v_tx: f32 = ((((f32(v_cx) * 36.0f) + cw_tmp_61) - v_ro.x) * f_safeInv(v_light.x, cw_thread, cw_block, cw_grid));
  var cw_tmp_62: f32;
  if ((v_sz > 0i)) {
    cw_tmp_62 = 18.0f;
  } else {
    cw_tmp_62 = (-18.0f);
  }
  var v_tz: f32 = ((((f32(v_cz) * 36.0f) + cw_tmp_62) - v_ro.z) * f_safeInv(v_light.z, cw_thread, cw_block, cw_grid));
  var v_dx: f32 = (36.0f * abs(f_safeInv(v_light.x, cw_thread, cw_block, cw_grid)));
  var v_dz: f32 = (36.0f * abs(f_safeInv(v_light.z, cw_thread, cw_block, cw_grid)));
  var v_t: f32 = 0.0f;
  {
    var v_step: i32 = 0i;
    loop {
      if (!(v_step < 40i)) { break; }
      if (((!f_inCity(v_cx, v_cz, cw_thread, cw_block, cw_grid)) || (v_t > v_maxT))) {
        break;
      }
      var v_b: i32 = (f_worldIndex(v_cx, v_cz, cw_thread, cw_block, cw_grid) * 8i);
      var v_type: i32 = i32(b_World[(cw_buffer_offset_0 + (v_b + 3i))]);
      if (((v_type != 3i) && (v_type != 4i))) {
        var v_w: f32 = b_World[(cw_buffer_offset_0 + v_b)];
        var v_d: f32 = b_World[(cw_buffer_offset_0 + (v_b + 1i))];
        var v_h: f32 = b_World[(cw_buffer_offset_0 + (v_b + 2i))];
        var v_lo: vec3<f32> = vec3<f32>((((f32(v_cx) * 36.0f) - v_w) + 0.05f), 4.1f, (((f32(v_cz) * 36.0f) - v_d) + 0.05f));
        var v_hi: vec3<f32> = vec3<f32>((((f32(v_cx) * 36.0f) + v_w) - 0.05f), v_h, (((f32(v_cz) * 36.0f) + v_d) - 0.05f));
        var v_span: vec2<f32> = f_boxRange(v_ro, v_light, v_lo, v_hi, cw_thread, cw_block, cw_grid);
        if (((v_span.y > max(0.06f, v_span.x)) && (v_span.x < v_maxT))) {
          return 0.04f;
        }
      }
      if ((v_type == 3i)) {
        {
          var v_k: i32 = 0i;
          loop {
            if (!(v_k < 8i)) { break; }
            var v_th: f32 = (5.0f + (f_hash1((i32(b_World[(cw_buffer_offset_0 + (v_b + 6i))]) + v_k), cw_thread, cw_block, cw_grid) * 3.0f));
            var cw_tmp_63: f32;
            if ((v_k < 4i)) {
              cw_tmp_63 = (-10.0f);
            } else {
              cw_tmp_63 = 10.0f;
            }
            var v_txc: f32 = ((f32(v_cx) * 36.0f) + cw_tmp_63);
            var v_tzc: f32 = ((f32(v_cz) * 36.0f) + ((f32((v_k % 4i)) - 1.5f) * 6.7f));
            var v_a: vec3<f32> = vec3<f32>(cw_divide_f32((v_ro.x - v_txc), 2.5f), cw_divide_f32(((v_ro.y - v_th) - 1.0f), 2.7f), cw_divide_f32((v_ro.z - v_tzc), 2.5f));
            var v_v: vec3<f32> = vec3<f32>(cw_divide_f32(v_light.x, 2.5f), cw_divide_f32(v_light.y, 2.7f), cw_divide_f32(v_light.z, 2.5f));
            var v_aa: f32 = f_dot3(v_v, v_v, cw_thread, cw_block, cw_grid);
            var v_bb: f32 = f_dot3(v_a, v_v, cw_thread, cw_block, cw_grid);
            var v_disc: f32 = ((v_bb * v_bb) - (v_aa * (f_dot3(v_a, v_a, cw_thread, cw_block, cw_grid) - 1.0f)));
            if ((v_disc > 0.0f)) {
              var v_u: f32 = cw_divide_f32(((-v_bb) - sqrt(v_disc)), v_aa);
              if (((v_u > 0.05f) && (v_u < v_maxT))) {
                return (0.22f + (0.42f * f_noise2((v_p.x * 8.2f), (v_p.z * 8.2f), cw_thread, cw_block, cw_grid)));
              }
            }
            continuing {
              v_k += i32(1);
            }
          }
        }
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
  return 1.0f;
}
fn f_cw_buffer_helper_6(cw_buffer_arg_0: i32, cw_arg_p: vec3<f32>, cw_arg_n: vec3<f32>, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_p: vec3<f32> = cw_arg_p;
  var v_n: vec3<f32> = cw_arg_n;
  var v_cx: i32 = i32(floor(cw_divide_f32((v_p.x + 18.0f), 36.0f)));
  var v_cz: i32 = i32(floor(cw_divide_f32((v_p.z + 18.0f), 36.0f)));
  var v_occ: f32 = 0.0f;
  {
    var v_z: i32 = (-1i);
    loop {
      if (!(v_z <= 1i)) { break; }
      {
        var v_x: i32 = (-1i);
        loop {
          if (!(v_x <= 1i)) { break; }
          if (f_inCity((v_cx + v_x), (v_cz + v_z), cw_thread, cw_block, cw_grid)) {
            var v_b: i32 = (f_worldIndex((v_cx + v_x), (v_cz + v_z), cw_thread, cw_block, cw_grid) * 8i);
            var v_type: i32 = i32(b_World[(cw_buffer_offset_0 + (v_b + 3i))]);
            if (((v_type != 3i) && (v_type != 4i))) {
              var v_xx: f32 = (abs((v_p.x - (f32((v_cx + v_x)) * 36.0f))) - b_World[(cw_buffer_offset_0 + v_b)]);
              var v_zz: f32 = (abs((v_p.z - (f32((v_cz + v_z)) * 36.0f))) - b_World[(cw_buffer_offset_0 + (v_b + 1i))]);
              var v_dist: f32 = sqrt(((max(0.0f, v_xx) * max(0.0f, v_xx)) + (max(0.0f, v_zz) * max(0.0f, v_zz))));
              if ((v_dist > 0.06f)) {
                v_occ = (v_occ + ((f_sat(cw_divide_f32((b_World[(cw_buffer_offset_0 + (v_b + 2i))] - v_p.y), ((v_dist + b_World[(cw_buffer_offset_0 + (v_b + 2i))]) + 1.0f)), cw_thread, cw_block, cw_grid) * exp(((-v_dist) * 0.12f))) * 0.48f));
              }
            }
          }
          continuing {
            v_x += i32(1);
          }
        }
      }
      continuing {
        v_z += i32(1);
      }
    }
  }
  return f_clampf((1.0f - v_occ), 0.35f, 1.0f, cw_thread, cw_block, cw_grid);
}
fn f_cw_buffer_helper_7(cw_buffer_arg_0: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  let cw_argument_index_64 = (cw_buffer_offset_0 + 3i);
  let cw_argument_index_65 = (cw_buffer_offset_0 + 4i);
  let cw_argument_index_66 = (cw_buffer_offset_0 + 4i);
  let cw_argument_index_67 = (cw_buffer_offset_0 + 3i);
  let cw_argument_index_68 = (cw_buffer_offset_0 + 4i);
  return vec3<f32>((sin(b_C[cw_argument_index_64]) * cos(b_C[cw_argument_index_65])), sin(b_C[cw_argument_index_66]), (cos(b_C[cw_argument_index_67]) * cos(b_C[cw_argument_index_68])));
}
fn f_cw_buffer_helper_8(cw_buffer_arg_0: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  let cw_argument_index_69 = (cw_buffer_offset_0 + 3i);
  let cw_argument_index_72 = (cw_buffer_offset_0 + 3i);
  return vec3<f32>(cos(b_C[cw_argument_index_69]), 0.0f, (-sin(b_C[cw_argument_index_72])));
}

fn cw_pow_f32(base: f32, exponent: f32) -> f32 {
  if(exponent >= -64.0f && exponent <= 64.0f && exponent == trunc(exponent)) {
    var count=u32(abs(exponent));
    var value=cw_d_from_f32(base);var product=cw_d_from_u32(1u);
    loop {
      if(count == 0u) { break; }
      if((count & 1u) != 0u) { product=cw_d_mul(product,value); }
      count >>= 1u;
      if(count != 0u) { value=cw_d_mul(value,value); }
    }
    if(exponent < 0.0f) { product=cw_d_div(cw_d_from_u32(1u),product); }
    return cw_d_to_f32(product);
  }
  return pow(base,exponent);
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
  var v_b: i32 = (((v_y * cw_params.p_width) + v_x) * 4i);
  var v_t: f32 = b_Hit[v_b];
  var v_id: i32 = i32(b_Hit[(v_b + 1i)]);
  var v_rd: vec3<f32> = f_cw_buffer_helper_0(0i, v_x, v_y, cw_params.p_width, cw_params.p_height, cw_thread, cw_block, cw_grid);
  var v_ro: vec3<f32> = f_cw_buffer_helper_1(0i, cw_thread, cw_block, cw_grid);
  var v_sun: vec3<f32> = f_cw_buffer_helper_2(0i, cw_thread, cw_block, cw_grid);
  var v_result: vec3<f32> = f_sky(v_rd, v_sun, cw_thread, cw_block, cw_grid);
  if ((v_id != (-10000i))) {
    var v_p: vec3<f32> = (v_ro + (v_rd * vec3<f32>(v_t)));
    var v_n: vec3<f32> = vec3<f32>(0.0f, 1.0f, 0.0f);
    var v_mat: i32 = 10i;
    var v_seed: f32 = 0.0f;
    if ((v_id >= 0i)) {
      v_n = f_cw_buffer_helper_3(0i, v_id, v_p, cw_thread, cw_block, cw_grid);
      v_mat = i32(b_P[((v_id * 16i) + 7i)]);
      v_seed = b_P[((v_id * 16i) + 9i)];
    } else {
      if ((v_id <= (-2i))) {
        var v_wi: i32 = ((-v_id) - 2i);
        var v_wi8: i32 = (v_wi * 8i);
        var v_c: vec3<f32> = vec3<f32>((f32(((v_wi % 64i) - (64i / 2i))) * 36.0f), ((b_World[(v_wi8 + 2i)] + 4.5f) * 0.5f), (f32(((v_wi / 64i) - (64i / 2i))) * 36.0f));
        let cw_argument_index_18 = v_wi8;
        let cw_argument_index_19 = (v_wi8 + 1i);
        var v_h: vec3<f32> = vec3<f32>(b_World[cw_argument_index_18], v_c.y, b_World[cw_argument_index_19]);
        var v_q: vec3<f32> = f_abs3((v_p - v_c), cw_thread, cw_block, cw_grid);
        var v_e: vec3<f32> = vec3<f32>(abs((v_q.x - v_h.x)), abs((v_q.y - v_h.y)), abs((v_q.z - v_h.z)));
        var cw_tmp_23: vec3<f32>;
        if (((v_e.y < v_e.x) && (v_e.y < v_e.z))) {
          cw_tmp_23 = vec3<f32>(0.0f, 1.0f, 0.0f);
        } else {
          var cw_tmp_22: vec3<f32>;
          if ((v_e.x < v_e.z)) {
            var cw_tmp_20: f32;
            if ((v_p.x < v_c.x)) {
              cw_tmp_20 = (-1.0f);
            } else {
              cw_tmp_20 = 1.0f;
            }
            cw_tmp_22 = vec3<f32>(cw_tmp_20, 0.0f, 0.0f);
          } else {
            var cw_tmp_21: f32;
            if ((v_p.z < v_c.z)) {
              cw_tmp_21 = (-1.0f);
            } else {
              cw_tmp_21 = 1.0f;
            }
            cw_tmp_22 = vec3<f32>(0.0f, 0.0f, cw_tmp_21);
          }
          cw_tmp_23 = cw_tmp_22;
        }
        v_n = cw_tmp_23;
        var cw_tmp_24: i32;
        if ((v_n.y > 0.5f)) {
          cw_tmp_24 = 2i;
        } else {
          cw_tmp_24 = i32(b_World[(v_wi8 + 4i)]);
        }
        v_mat = cw_tmp_24;
        v_seed = b_World[(v_wi8 + 6i)];
      } else {
        var v_cx: i32 = i32(floor(cw_divide_f32((v_p.x + 18.0f), 36.0f)));
        var v_cz: i32 = i32(floor(cw_divide_f32((v_p.z + 18.0f), 36.0f)));
        var v_xx: f32 = abs((v_p.x - (f32(v_cx) * 36.0f)));
        var v_zz: f32 = abs((v_p.z - (f32(v_cz) * 36.0f)));
        if (((v_xx < 16.5f) && (v_zz < 16.5f))) {
          v_mat = 11i;
        }
        if ((((v_cx == (-4i)) && f_inCity(v_cx, v_cz, cw_thread, cw_block, cw_grid)) && (f_imod(v_cz, 4i, cw_thread, cw_block, cw_grid) != 0i))) {
          v_mat = 9i;
        }
        if ((!f_inCity(v_cx, v_cz, cw_thread, cw_block, cw_grid))) {
          v_mat = 7i;
        }
      }
    }
    if (((((v_id >= 0i) && (v_mat == 5i)) && (b_P[((v_id * 16i) + 4i)] > 4.0f)) && (b_P[((v_id * 16i) + 5i)] > 1.0f))) {
      v_mat = 18i;
    }
    if (((v_mat == 7i) && (f_dot3(v_n, v_rd, cw_thread, cw_block, cw_grid) > 0.0f))) {
      v_n = (v_n * vec3<f32>((-1.0f)));
    }
    var v_footprint: f32 = max(0.00005f, cw_divide_f32((v_t * 1.08f), f32(cw_params.p_height)));
    var v_uv: vec2<f32> = f_masonryUV(v_p, v_n, cw_thread, cw_block, cw_grid);
    var v_base: vec3<f32> = f_substrateMean(v_mat, cw_thread, cw_block, cw_grid);
    if (((v_mat == 0i) || (v_mat == 1i))) {
      if (((b_C[16i] > 0.5f) && (b_Brain[4i] > 0.5f))) {
        v_base = f_cw_buffer_helper_4(0i, v_uv.x, v_uv.y, v_seed, v_mat, cw_thread, cw_block, cw_grid);
      } else {
        v_base = f_substrate(v_uv.x, v_uv.y, v_seed, v_mat, cw_thread, cw_block, cw_grid);
      }
    }
    var v_albedo: vec3<f32> = f_surfaceColor(v_p, v_n, v_mat, v_seed, v_footprint, v_base, cw_thread, cw_block, cw_grid);
    var v_originalN: vec3<f32> = v_n;
    if ((((v_mat == 0i) || (v_mat == 1i)) && (abs(v_n.y) < 0.5f))) {
      var v_eps: f32 = max(0.002f, (v_footprint * 0.6f));
      var v_du: f32 = cw_divide_f32((f_masonryHeight((v_uv.x + v_eps), v_uv.y, v_mat, cw_thread, cw_block, cw_grid) - f_masonryHeight((v_uv.x - v_eps), v_uv.y, v_mat, cw_thread, cw_block, cw_grid)), (2.0f * v_eps));
      var v_dv: f32 = cw_divide_f32((f_masonryHeight(v_uv.x, (v_uv.y + v_eps), v_mat, cw_thread, cw_block, cw_grid) - f_masonryHeight(v_uv.x, (v_uv.y - v_eps), v_mat, cw_thread, cw_block, cw_grid)), (2.0f * v_eps));
      if ((v_footprint < 0.005f)) {
        var v_me: f32 = max(0.00016f, (v_footprint * 0.8f));
        v_du = (v_du + cw_divide_f32((f_microRelief((v_uv.x + v_me), v_uv.y, v_footprint, cw_thread, cw_block, cw_grid) - f_microRelief((v_uv.x - v_me), v_uv.y, v_footprint, cw_thread, cw_block, cw_grid)), (2.0f * v_me)));
        v_dv = (v_dv + cw_divide_f32((f_microRelief(v_uv.x, (v_uv.y + v_me), v_footprint, cw_thread, cw_block, cw_grid) - f_microRelief(v_uv.x, (v_uv.y - v_me), v_footprint, cw_thread, cw_block, cw_grid)), (2.0f * v_me)));
      }
      var cw_tmp_25: vec3<f32>;
      if ((abs(v_n.x) > 0.5f)) {
        cw_tmp_25 = vec3<f32>(0.0f, 0.0f, 1.0f);
      } else {
        cw_tmp_25 = vec3<f32>(1.0f, 0.0f, 0.0f);
      }
      var v_tangent: vec3<f32> = cw_tmp_25;
      var v_fade: f32 = f_frequencyWeight(v_footprint, 5.0f, cw_thread, cw_block, cw_grid);
      v_n = f_norm3(((v_n - (v_tangent * vec3<f32>((v_du * v_fade)))) - vec3<f32>(0.0f, (v_dv * v_fade), 0.0f)), cw_thread, cw_block, cw_grid);
    }
    if ((v_mat == 9i)) {
      var v_wave: f32 = (cos(((v_p.x * 3.7f) + (v_p.z * 1.1f))) * 0.06f);
      var v_wave2: f32 = (sin(((v_p.z * 4.4f) - (v_p.x * 0.9f))) * 0.08f);
      v_n = f_norm3((v_n + vec3<f32>(v_wave, 0.0f, v_wave2)), cw_thread, cw_block, cw_grid);
    }
    var v_nl: f32 = max(0.0f, f_dot3(v_n, v_sun, cw_thread, cw_block, cw_grid));
    var v_nv: f32 = max(0.03f, (-f_dot3(v_n, v_rd, cw_thread, cw_block, cw_grid)));
    var cw_tmp_26: f32;
    if ((b_C[18i] > 0.5f)) {
      cw_tmp_26 = 1.0f;
    } else {
      cw_tmp_26 = f_cw_buffer_helper_5(0i, (v_p + (v_originalN * vec3<f32>(0.035f))), v_sun, cw_thread, cw_block, cw_grid);
    }
    var v_shadow: f32 = cw_tmp_26;
    var v_ao: f32 = f_cw_buffer_helper_6(0i, v_p, v_originalN, cw_thread, cw_block, cw_grid);
    var v_rough: f32 = 0.75f;
    if (((v_mat == 3i) || (v_mat == 6i))) {
      v_rough = 0.38f;
    }
    if (((v_mat == 4i) || (v_mat == 18i))) {
      v_rough = 0.15f;
    }
    if ((v_mat == 9i)) {
      v_rough = 0.12f;
    }
    if ((v_mat == 8i)) {
      v_rough = 0.3f;
    }
    if (((v_id == (-1i)) && (v_mat != 9i))) {
      v_rough = f_lerpf(v_rough, 0.33f, (b_C[10i] * f_smoothf(0.43f, 0.68f, f_fbm2((v_p.x * 0.19f), (v_p.z * 0.19f), cw_thread, cw_block, cw_grid), cw_thread, cw_block, cw_grid)), cw_thread, cw_block, cw_grid);
    }
    var v_halfv: vec3<f32> = f_norm3((v_sun - v_rd), cw_thread, cw_block, cw_grid);
    var v_nh: f32 = max(0.0f, f_dot3(v_n, v_halfv, cw_thread, cw_block, cw_grid));
    var v_vh: f32 = max(0.0f, (-f_dot3(v_rd, v_halfv, cw_thread, cw_block, cw_grid)));
    var v_a: f32 = (v_rough * v_rough);
    var v_denom: f32 = (((v_nh * v_nh) * ((v_a * v_a) - 1.0f)) + 1.0f);
    var v_distribution: f32 = cw_divide_f32((v_a * v_a), (((3.141592653589793f * v_denom) * v_denom) + 0.000001f));
    var v_k: f32 = cw_divide_f32(((v_rough + 1.0f) * (v_rough + 1.0f)), 8.0f);
    var v_geometry: f32 = cw_divide_f32((cw_divide_f32(v_nv, ((v_nv * (1.0f - v_k)) + v_k)) * v_nl), (((v_nl * (1.0f - v_k)) + v_k) + 0.00001f));
    var cw_tmp_27: f32;
    if ((((v_mat == 3i) || (v_mat == 6i)) || (v_mat == 8i))) {
      cw_tmp_27 = 0.35f;
    } else {
      cw_tmp_27 = 0.045f;
    }
    var v_f0: f32 = cw_tmp_27;
    var v_fresnel: f32 = (v_f0 + ((1.0f - v_f0) * cw_pow_f32((1.0f - v_vh), 5.0f)));
    var v_spec: f32 = cw_divide_f32(((v_distribution * v_geometry) * v_fresnel), (((4.0f * v_nv) * v_nl) + 0.0001f));
    var v_direct: vec3<f32> = (vec3<f32>(2.25f, 1.63f, 0.99f) * vec3<f32>((v_nl * v_shadow)));
    var v_skyWeight: f32 = (0.22f + (0.29f * f_sat(((v_n.y * 0.5f) + 0.5f), cw_thread, cw_block, cw_grid)));
    var v_ambient: vec3<f32> = (vec3<f32>(0.25f, 0.34f, 0.44f) * vec3<f32>((v_skyWeight * v_ao)));
    var v_bounce: f32 = ((1.0f - f_sat(v_n.y, cw_thread, cw_block, cw_grid)) * 0.1f);
    v_ambient = (v_ambient + ((vec3<f32>(0.65f, 0.43f, 0.25f) * vec3<f32>(v_bounce)) * vec3<f32>(v_ao)));
    v_result = ((v_albedo * (v_direct + v_ambient)) + (vec3<f32>(1.0f, 0.87f, 0.63f) * vec3<f32>((((v_spec * v_nl) * v_shadow) * 2.1f))));
    if ((((v_mat == 4i) || (v_mat == 9i)) || (v_mat == 18i))) {
      var v_reflection: vec3<f32> = (v_rd - (v_n * vec3<f32>((2.0f * f_dot3(v_rd, v_n, cw_thread, cw_block, cw_grid)))));
      var v_fr: f32 = (0.1f + (0.72f * cw_pow_f32((1.0f - v_nv), 4.0f)));
      v_result = f_mix3(v_result, (f_sky(v_reflection, v_sun, cw_thread, cw_block, cw_grid) * vec3<f32>(0.6f)), v_fr, cw_thread, cw_block, cw_grid);
      if (((v_mat == 4i) || (v_mat == 18i))) {
        var v_room: f32 = f_hash1(i32(v_seed), cw_thread, cw_block, cw_grid);
        var v_shade: f32 = (0.2f + (f_noise2((v_uv.x * 3.0f), (v_uv.y * 2.0f), cw_thread, cw_block, cw_grid) * 0.15f));
        var cw_tmp_28: f32;
        if ((v_room > 0.78f)) {
          cw_tmp_28 = v_shade;
        } else {
          cw_tmp_28 = 0.03f;
        }
        v_result = ((v_result * vec3<f32>(0.73f)) + (vec3<f32>(0.13f, 0.075f, 0.028f) * vec3<f32>(cw_tmp_28)));
      }
    }
    if ((v_mat == 8i)) {
      v_result = (v_result + (vec3<f32>(1.1f, 0.62f, 0.19f) * vec3<f32>(0.8f)));
    }
    if ((v_mat == 7i)) {
      v_result = (v_result + (v_albedo * vec3<f32>((cw_pow_f32(max(0.0f, f_dot3(v_rd, v_sun, cw_thread, cw_block, cw_grid)), 4.0f) * 0.35f))));
    }
    if (((v_id <= (-2i)) && (abs(v_originalN.y) < 0.5f))) {
      var v_uu: f32 = f_fractf(cw_divide_f32(v_uv.x, 5.6f), cw_thread, cw_block, cw_grid);
      var v_vv: f32 = f_fractf(cw_divide_f32((v_p.y - 4.2f), 3.8f), cw_thread, cw_block, cw_grid);
      var v_pane: f32 = (((f_smoothf(0.2f, 0.26f, v_uu, cw_thread, cw_block, cw_grid) * (1.0f - f_smoothf(0.65f, 0.71f, v_uu, cw_thread, cw_block, cw_grid))) * f_smoothf(0.2f, 0.26f, v_vv, cw_thread, cw_block, cw_grid)) * (1.0f - f_smoothf(0.75f, 0.81f, v_vv, cw_thread, cw_block, cw_grid)));
      v_result = f_mix3(v_result, vec3<f32>(0.095f, 0.135f, 0.15f), (v_pane * 0.8f), cw_thread, cw_block, cw_grid);
    }
    var v_fog: f32 = (1.0f - exp(((-v_t) * 0.00062f)));
    var v_haze: vec3<f32> = f_sky(f_norm3(vec3<f32>(v_rd.x, 0.004f, v_rd.z), cw_thread, cw_block, cw_grid), v_sun, cw_thread, cw_block, cw_grid);
    v_result = f_mix3(v_result, v_haze, v_fog, cw_thread, cw_block, cw_grid);
    if ((b_C[11i] == 1.0f)) {
      if ((v_id >= 0i)) {
        var v_slot: i32 = (v_id / 2048i);
        var v_h: f32 = f_hash1(v_slot, cw_thread, cw_block, cw_grid);
        v_result = vec3<f32>((0.2f + (0.7f * v_h)), (0.2f + (0.7f * f_hash1((v_slot + 31i), cw_thread, cw_block, cw_grid))), (0.2f + (0.7f * f_hash1((v_slot + 78i), cw_thread, cw_block, cw_grid))));
      } else {
        v_result = vec3<f32>(0.1f, 0.13f, 0.16f);
      }
    }
    if ((b_C[11i] == 2.0f)) {
      if ((v_id >= 0i)) {
        var v_cluster: i32 = (v_id / 32i);
        v_result = vec3<f32>((0.15f + (0.75f * f_hash1(v_cluster, cw_thread, cw_block, cw_grid))), (0.15f + (0.75f * f_hash1((v_cluster + 31i), cw_thread, cw_block, cw_grid))), (0.15f + (0.75f * f_hash1((v_cluster + 98i), cw_thread, cw_block, cw_grid))));
      } else {
        v_result = vec3<f32>(0.09f, 0.12f, 0.14f);
      }
    }
    if ((b_C[11i] == 3.0f)) {
      v_result = ((v_n + vec3<f32>(1.0f, 1.0f, 1.0f)) * vec3<f32>(0.5f));
    }
  }
  b_Linear[v_b] = v_result.x;
  b_Linear[(v_b + 1i)] = v_result.y;
  b_Linear[(v_b + 2i)] = v_result.z;
  b_Linear[(v_b + 3i)] = 1.0f;
}
