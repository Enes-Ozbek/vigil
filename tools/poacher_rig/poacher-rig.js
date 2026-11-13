/* The Poacher — a wood-wraith hunter for Vigil (v3: more detail, more malice).
 * Procedural pixel rig. Poses are authored in an 80-unit design space and
 * rasterised at 1.35x into 108x108 cells (the Vessel's pixel density at scale 0.6),
 * so bark grain, teeth, claws and trophies get single-pixel detail.
 * Output matches the engine's sprite contract: one animation per ROW. */
(function () {
  'use strict';
  var K = 1.35, W = 108, H = 108, PIVOT = [54, 100], SCALE = 0.6, TAU = Math.PI * 2;

  var OUT = '#0a0707', OUTR = [OUT];
  var R = {
    bark: ['#151011', '#221a16', '#30251e', '#413329', '#574536', '#6f5944'],
    far: ['#110d0c', '#1b1513', '#271f1a', '#342a22', '#42352b', '#504134'],
    dead: ['#1a1513', '#2a221d', '#3b312a', '#504439', '#685a4c', '#827260'],
    moss: ['#181e0d', '#253013', '#344119', '#4a5a24', '#647532'],
    leaf: ['#3a120b', '#5e1c0f', '#862f15', '#ac481e', '#cc672b'],
    bone: ['#5c564a', '#8e8673', '#bcb29b', '#e3dac4'],
    relic: ['#3f3a31', '#69624f', '#8f8670', '#b3a98f'],
    cord: ['#36170e', '#5a2a17', '#7e3e1e'],
    lichen: ['#3c4231', '#5a6147'],
    glow: ['#2a0b07', '#6e1f0e', '#b84a14', '#f08f26', '#ffd36a', '#fff4bf']
  };
  var EYE_SPILL = '#8a3c14', STRING_C = ['#7a705c'];
  var G = { FARLEG: 1, FARARM: 2, BOW: 3, BSTRING: 4, BODY: 5, NEARLEG: 6, SKIRT: 7, TROPHY: 8, NEARARM: 9, MANE: 10, CROWN: 11, HEAD: 12, ARROW: 13, STRING: 14, NEARARM2: 15, FX: 16 };

  var LX = -0.5, LY = -0.74, LZ = 0.46;
  (function () { var l = Math.sqrt(LX * LX + LY * LY + LZ * LZ); LX /= l; LY /= l; LZ /= l; })();

  function rad(d) { return d * Math.PI / 180; }
  function lerp(a, b, t) { return a + (b - a) * t; }
  function clamp(v, a, b) { return v < a ? a : v > b ? b : v; }
  function smooth(a, b, t) { var x = clamp((t - a) / (b - a), 0, 1); return x * x * (3 - 2 * x); }
  function ease(t) { return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2; }
  function add(a, b) { return [a[0] + b[0], a[1] + b[1]]; }
  function sub(a, b) { return [a[0] - b[0], a[1] - b[1]]; }
  function mul(a, k) { return [a[0] * k, a[1] * k]; }
  function len(a) { return Math.sqrt(a[0] * a[0] + a[1] * a[1]); }
  function norm(a) { var l = len(a) || 1; return [a[0] / l, a[1] / l]; }
  function dirv(d) { return [Math.cos(rad(d)), Math.sin(rad(d))]; }
  function rot(v, d) { var a = rad(d), c = Math.cos(a), s = Math.sin(a); return [v[0] * c - v[1] * s, v[0] * s + v[1] * c]; }
  function mix(a, b, t) { return [lerp(a[0], b[0], t), lerp(a[1], b[1], t)]; }
  function frac(x) { return x - Math.floor(x); }
  function hash(a, b) { var h = Math.sin(a * 127.1 + b * 311.7 + 17.3) * 43758.5453; return h - Math.floor(h); }
  function px(q) { return [q[0] * K, q[1] * K]; }

  var rgbCache = {};
  function rgb(hex) {
    if (!rgbCache[hex]) rgbCache[hex] = [parseInt(hex.slice(1, 3), 16), parseInt(hex.slice(3, 5), 16), parseInt(hex.slice(5, 7), 16)];
    return rgbCache[hex];
  }
  function mixHex(a, b, t) {
    var x = rgb(a), y = rgb(b), o = '#';
    for (var i = 0; i < 3; i++) { var v = Math.round(lerp(x[i], y[i], t)); o += (v < 16 ? '0' : '') + v.toString(16); }
    return o;
  }

  // ---- pixel buffer (pixel space) ------------------------------------------------
  function Buf() {
    this.c = new Array(W * H).fill(null);
    this.g = new Int8Array(W * H);
    this.r = new Array(W * H).fill(null);
    this.i = new Int8Array(W * H);
  }
  Buf.prototype.put = function (x, y, ramp, idx, grp) {
    x = Math.floor(x); y = Math.floor(y);
    if (x < 0 || y < 0 || x >= W || y >= H) return;
    var k = y * W + x;
    idx = clamp(Math.round(idx), 0, ramp.length - 1);
    this.c[k] = ramp[idx]; this.g[k] = grp; this.r[k] = ramp; this.i[k] = idx;
  };

  var TH = { 6: [-0.42, -0.08, 0.24, 0.52, 0.8], 5: [-0.34, 0.08, 0.44, 0.74], 4: [-0.24, 0.22, 0.6], 3: [-0.1, 0.5] };
  function shadeIdx(s, n) {
    var th = TH[n] || [0], i = 0;
    while (i < th.length && s > th[i]) i++;
    return i;
  }

  // ---- primitives: take design units, draw pixels -----------------------------------
  // A swept, tapering tube along a polyline, lit as a cylinder. tex() sees design units.
  function tube(B, ptsD, radsD, ramp, grp, o) {
    o = o || {};
    var n = ptsD.length, i, x, y, pts = [], rads = [], minx = 1e9, miny = 1e9, maxx = -1e9, maxy = -1e9, rmax = 0;
    for (i = 0; i < n; i++) {
      pts.push([ptsD[i][0] * K, ptsD[i][1] * K]); rads.push(radsD[i] * K);
      minx = Math.min(minx, pts[i][0]); maxx = Math.max(maxx, pts[i][0]);
      miny = Math.min(miny, pts[i][1]); maxy = Math.max(maxy, pts[i][1]);
      rmax = Math.max(rmax, rads[i]);
    }
    var cum = [0];
    for (i = 1; i < n; i++) cum.push(cum[i - 1] + len(sub(pts[i], pts[i - 1])));
    var x0 = Math.max(0, Math.floor(minx - rmax - 1)), x1 = Math.min(W - 1, Math.ceil(maxx + rmax + 1));
    var y0 = Math.max(0, Math.floor(miny - rmax - 1)), y1 = Math.min(H - 1, Math.ceil(maxy + rmax + 1));
    for (y = y0; y <= y1; y++) for (x = x0; x <= x1; x++) {
      var qx = x + 0.5, qy = y + 0.5, best = null;
      for (i = 0; i < Math.max(1, n - 1); i++) {
        var j = Math.min(i + 1, n - 1);
        var ax = pts[i][0], ay = pts[i][1], dx = pts[j][0] - ax, dy = pts[j][1] - ay;
        var L2 = dx * dx + dy * dy;
        var t = L2 > 1e-9 ? ((qx - ax) * dx + (qy - ay) * dy) / L2 : 0;
        t = t < 0 ? 0 : t > 1 ? 1 : t;
        var r = rads[i] + (rads[j] - rads[i]) * t;
        var ex = qx - (ax + dx * t), ey = qy - (ay + dy * t), d = Math.sqrt(ex * ex + ey * ey), q = d / r;
        if (q <= 1 && (!best || q < best.q)) best = { q: q, ex: ex, ey: ey, d: d, i: i, t: t, r: r, L: Math.sqrt(L2), dx: dx, dy: dy };
      }
      if (!best) continue;
      var nx = best.d > 1e-6 ? best.ex / best.d : 0, ny = best.d > 1e-6 ? best.ey / best.d : 0;
      var qq = best.q, nz = Math.sqrt(Math.max(0, 1 - qq * qq));
      var s = nx * qq * LX + ny * qq * LY + nz * LZ + (o.bias || 0);
      var idx = shadeIdx(s, ramp.length), useRamp = ramp;
      if (o.tex) {
        var res = o.tex({
          idx: idx, s: s, q: qq, nx: nx, ny: ny, r: best.r / K, seg: best.i,
          along: (cum[best.i] + best.t * best.L) / K,
          across: best.L > 1e-6 ? (best.dx * best.ey - best.dy * best.ex) / best.L / best.r : 0,
          total: cum[n - 1] / K
        });
        if (res === null) continue;
        if (Array.isArray(res)) { useRamp = res[0]; idx = res[1]; } else idx = res;
      }
      B.put(x, y, useRamp, idx, grp);
    }
  }
  function disc(B, c, r, ramp, grp, o) { tube(B, [c, c], [r, r], ramp, grp, o); }
  function line(B, a, b, ramp, idx, grp) {
    var x0 = Math.floor(a[0] * K), y0 = Math.floor(a[1] * K), x1 = Math.floor(b[0] * K), y1 = Math.floor(b[1] * K);
    var dx = Math.abs(x1 - x0), sx = x0 < x1 ? 1 : -1, dy = -Math.abs(y1 - y0), sy = y0 < y1 ? 1 : -1, err = dx + dy;
    for (var guard = 0; guard < 300; guard++) {
      B.put(x0, y0, ramp, idx, grp);
      if (x0 === x1 && y0 === y1) break;
      var e2 = 2 * err;
      if (e2 >= dy) { err += dy; x0 += sx; }
      if (e2 <= dx) { err += dx; y0 += sy; }
    }
  }
  function dot(B, p, ramp, idx, grp) { B.put(p[0] * K, p[1] * K, ramp, idx, grp); }
  // pixel stamps: digits index the ramp, 'k' is outline black; anchored top-centre at p
  function stamp(B, p, rows, ramp, grp, flip) {
    var bx = Math.floor(p[0] * K), by = Math.floor(p[1] * K), w = rows[0].length, ox = Math.floor(w / 2);
    for (var r = 0; r < rows.length; r++) for (var c = 0; c < w; c++) {
      var ch = rows[r][flip ? w - 1 - c : c];
      if (ch === '.') continue;
      if (ch === 'k') B.put(bx + c - ox, by + r, OUTR, 0, grp);
      else B.put(bx + c - ox, by + r, ramp, +ch, grp);
    }
  }
  function inside(pts, x, y) {
    var c = false;
    for (var i = 0, j = pts.length - 1; i < pts.length; j = i++) {
      var xi = pts[i][0], yi = pts[i][1], xj = pts[j][0], yj = pts[j][1];
      if (((yi > y) !== (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) c = !c;
    }
    return c;
  }
  function frame(o, deg, sc) {
    var a = rad(deg), c = Math.cos(a), s = Math.sin(a);
    sc = sc || 1;
    return {
      o: o, deg: deg,
      w: function (u, v) { u *= sc; v *= sc; return [o[0] + u * c - v * s, o[1] + u * s + v * c]; },
      l: function (x, y) { var dx = x - o[0], dy = y - o[1]; return [(dx * c + dy * s) / sc, (-dx * s + dy * c) / sc]; },
      rotN: function (nu, nv) { return [nu * c - nv * s, nu * s + nv * c]; }
    };
  }
  // visit every pixel under a local box; fn gets pixel x,y and local u,v
  function eachPixel(T, box, fn) {
    var cs = [[box[0], box[1]], [box[2], box[1]], [box[2], box[3]], [box[0], box[3]]].map(function (c) { return px(T.w(c[0], c[1])); });
    var xs = cs.map(function (c) { return c[0]; }), ys = cs.map(function (c) { return c[1]; });
    var x0 = Math.max(0, Math.floor(Math.min.apply(null, xs))), x1 = Math.min(W - 1, Math.ceil(Math.max.apply(null, xs)));
    var y0 = Math.max(0, Math.floor(Math.min.apply(null, ys))), y1 = Math.min(H - 1, Math.ceil(Math.max.apply(null, ys)));
    for (var y = y0; y <= y1; y++) for (var x = x0; x <= x1; x++) { var L = T.l((x + 0.5) / K, (y + 0.5) / K); fn(x, y, L[0], L[1]); }
  }
  function ik2(A, C, l1, l2, bend) {
    var dx = C[0] - A[0], dy = C[1] - A[1], d = Math.sqrt(dx * dx + dy * dy);
    if (d < 1e-6) { dx = 0; dy = 1; d = 1; }
    var dd = clamp(d, Math.abs(l1 - l2) + 0.01, l1 + l2 - 0.01);
    var ux = dx / d, uy = dy / d;
    var a = (l1 * l1 - l2 * l2 + dd * dd) / (2 * dd);
    var h = Math.sqrt(Math.max(0, l1 * l1 - a * a));
    return [A[0] + ux * a - uy * h * bend, A[1] + uy * a + ux * h * bend];
  }

  // ---- small pieces -------------------------------------------------------------
  var LEAVES = [
    ['.3..', '332.', '.321', '..10'],
    ['..3.', '.33.', '323.', '.21.', '.0..'],
    ['3.3.', '232.', '.21.', '..0.'],
    ['.33', '322', '21.', '0..']
  ];
  function leaf(B, p, v, grp, flip) { stamp(B, p, LEAVES[((v % 4) + 4) % 4], R.leaf, grp, flip); }
  var SKULL = ['.121.', '23332', '3k3k3', '23332', '.3k3.', '.2.2.'];
  var BIRD = ['.22.', '2332', '2k32', '.33.', '.2..', '.2..', '.1..'];

  // a curved, tapering thorn
  function thorn(B, base, dir, l, ramp, grp, curl) {
    var d = norm(dir), mid = add(base, mul(d, l * 0.55)), tip = add(mid, mul(curl ? rot(d, curl) : d, l * 0.45)), top = ramp.length - 1;
    tube(B, [base, mid], [0.32 + 0.13 * l, 0.42], ramp, grp, { bias: 0.12 });
    line(B, mid, tip, ramp, top - 2, grp);
    dot(B, tip, ramp, top - 1, grp);
  }
  // fissures, ridges, knots and lichen, all pinned to the limb so they move with it
  function barkTex(o) {
    if (o.r < 1.3) return o.idx;
    var f = Math.sin(o.across * 5.2 + Math.sin(o.along * 0.7 + o.across * 1.3) * 1.8);
    if (f > 0.88) return Math.max(0, o.idx - 2);
    if (f > 0.7) return o.idx - 1;
    if (f < -0.9 && o.s > 0.2) return o.idx + 1;
    if (o.r > 2.2 && hash(Math.floor(o.along * 0.55), Math.floor(o.across * 2.5 + 7)) > 0.95) return 0;
    if (o.s > 0.3 && hash(Math.floor(o.along * 1.9) + 3, Math.floor(o.across * 4 + 11)) > 0.965) return [R.lichen, 1];
    return o.idx;
  }

  // ---- legs ---------------------------------------------------------------------
  var THIGH = 11.6, SHIN = 11.2, UPPER = 10.2, FORE = 11.6;
  function legChain(hip, ank) { return { hip: hip, knee: ik2(hip, ank, THIGH, SHIN, -1), ank: ank }; }
  function legTex(o) {
    if (o.ny < -0.45 && o.q > 0.3 && hash(Math.floor(o.along * 1.1), 21) > 0.55) return [R.moss, clamp(o.idx - 1, 0, 4)];
    return barkTex(o);
  }
  function drawLeg(B, L, ramp, grp, foot, near) {
    var fa = (foot && foot.ang) || 0, a = L.ank;
    [
      { pts: [[0, 0], [3.4, 2.5], [8.2, 3.6]], r: [2.4, 1.4, 0.5], twig: [0.4, [0.8, 1.2]] },
      { pts: [[0, 0], [1.3, 3.0], [3.4, 3.9]], r: [2.0, 1.15, 0.5] },
      { pts: [[0, 0], [-2.8, 2.6], [-6.2, 3.6]], r: [2.1, 1.15, 0.45], twig: [0.7, [-1.4, 0.6]] }
    ].forEach(function (rt) {
      var pts = rt.pts.map(function (q) { return add(a, rot(q, fa)); });
      tube(B, pts, rt.r, ramp, grp, { tex: barkTex });
      line(B, pts[1], pts[2], ramp, 2, grp);
      if (rt.twig) { var b = mix(pts[1], pts[2], rt.twig[0]); line(B, b, add(b, rot(rt.twig[1], fa)), ramp, 1, grp); }
    });
    tube(B, [L.hip, L.knee, L.ank], [4.5, 3.1, 2.4], ramp, grp, { tex: legTex });
    disc(B, L.knee, 3.5, ramp, grp, { bias: 0.1, tex: barkTex });
    var out = norm(add(sub(L.knee, L.hip), sub(L.knee, L.ank)));
    thorn(B, add(L.knee, mul(out, 2.8)), add(out, [0, -0.9]), 3.4, ramp, grp, -24);
    var shin = norm(sub(L.ank, L.knee)), back = [-shin[1], shin[0]];
    if (back[0] > 0) back = mul(back, -1);
    thorn(B, add(mix(L.knee, L.ank, 0.45), mul(back, 2.4)), add(back, [0, -0.6]), 2.6, ramp, grp, 20);
    thorn(B, add(mix(L.knee, L.ank, 0.75), mul(back, 2.0)), add(back, [0, -0.4]), 1.8, ramp, grp, 16);
    if (near) {
      var th = norm(sub(L.knee, L.hip)), fr = [-th[1], th[0]];
      if (fr[0] < 0) fr = mul(fr, -1);
      thorn(B, add(mix(L.hip, L.knee, 0.55), mul(fr, 3.8)), add(fr, [0, -1]), 2.4, ramp, grp, -18);
    }
  }

  // ---- hips: a moss belt bound with cord, bark strips and trophies hanging off it ----
  function drawSkirt(B, p) {
    var up = norm(sub(p.W, p.P)), side = [-up[1], up[0]];
    if (side[0] < 0) side = mul(side, -1);
    var T = frame(add(p.P, mul(up, 0.4)), Math.atan2(side[1], side[0]) * 180 / Math.PI, 1);
    eachPixel(T, [-9, -5, 9, 6], function (x, y, u, v) {
      var edge = 2.4 + 1.9 * hash(Math.floor(u * 1.1 + 20), 5);
      if (Math.abs(u) > 7.4 - 0.6 * Math.max(0, -v) || v < -2.6 || v > edge) return;
      if (Math.abs(v + 0.7) < 0.42) { B.put(x, y, R.cord, frac(u * 0.8) < 0.5 ? 2 : 1, G.SKIRT); return; }
      var idx = v < -1.4 ? 3 : v < 0.6 ? 2 : 1, h = hash(Math.floor(u * 1.5) + 9, Math.floor(v * 0.8));
      if (h > 0.72) idx -= 1; else if (h < 0.12) idx += 1;
      B.put(x, y, R.moss, idx, G.SKIRT);
    });
    var sw = p.skirt || 0;
    [[-6.2, 7, 0], [-3.8, 11.5, 1], [-1.2, 8.5, 0], [1.4, 13, 1], [3.6, 9.5, 0], [5.8, 11, 1]].forEach(function (st, n) {
      var top = T.w(st[0], 2.2), L = st[1], isLeaf = st[2] === 1, ramp = isLeaf ? R.leaf : R.moss;
      var bot = add(top, [sw * (0.8 + 0.12 * L) + (n % 2 ? 0.4 : -0.3), L]);
      var mid = add(mix(top, bot, 0.5), [sw * 0.5, 0]);
      tube(B, [top, mid, bot], [1.3, 1.0, 0.45], ramp, G.SKIRT, {
        tex: function (o) {
          var i = isLeaf ? clamp(o.idx - 2, 0, 2) : clamp(o.idx - 1, 0, 2);
          return Math.abs(o.across) < 0.22 && o.along > 1 ? Math.max(0, i - 1) : i;
        }
      });
      line(B, mid, bot, ramp, isLeaf ? 0 : 1, G.SKIRT);
    });
    return T;
  }
  function drawTrophies(B, T, p) {
    var sw = p.skirt || 0;
    [[5.0, 3.2, SKULL], [2.4, 6.0, BIRD], [-4.4, 4.4, null]].forEach(function (t, n) {
      var a = T.w(t[0], -0.6), L = t[1], e = add(a, [sw * 0.2 * L + (n === 1 ? 0.3 : 0), L]);
      line(B, a, e, R.cord, 1, G.TROPHY);
      if (t[2]) stamp(B, e, t[2], R.relic, G.TROPHY);
      else [0.45, 0.72, 1].forEach(function (k) { var q = mix(a, e, k); dot(B, q, R.relic, 2, G.TROPHY); dot(B, add(q, [0, 0.75]), R.relic, 1, G.TROPHY); });
    });
  }

  // ---- torso: a narrow waist, a hollow chest with an ember caged in roots ------------
  var SPINE_R = [4.4, 3.2, 5.6, 4.6], HEART = { along: 8.6, across: 0.36, ra: 2.7, rc: 0.5 };
  function drawTorso(B, p) {
    tube(B, [p.P, p.W, p.C, p.N], SPINE_R, R.bark, G.BODY, {
      tex: function (o) {
        var da = (o.along - HEART.along) / HEART.ra, dc = (o.across - HEART.across) / HEART.rc, rho = Math.sqrt(da * da + dc * dc);
        if (rho < 1) {
          if (frac((o.along * 0.85 + o.across * 2.4) / 2.1) < 0.3) return rho < 0.5 ? 0 : 1;
          return [R.glow, rho < 0.24 ? 5 : rho < 0.42 ? 4 : rho < 0.6 ? 3 : rho < 0.78 ? 2 : rho < 0.9 ? 1 : 0];
        }
        if (rho < 1.25) return Math.max(0, o.idx - 2);
        if (o.along > 4.5 && o.along < 14 && o.across > -0.8 && o.across < 0.85 && (o.along * 0.92 + Math.abs(o.across) * 1.4) % 2.5 < 0.7) return Math.min(o.idx, 3) - 1;
        return barkTex(o);
      }
    });
  }
  function heartPoint(p) {
    var pts = [p.P, p.W, p.C, p.N], left = HEART.along;
    for (var i = 0; i < 3; i++) {
      var d = sub(pts[i + 1], pts[i]), L = len(d);
      if (left <= L || i === 2) {
        var t = clamp(left / L, 0, 1), r = lerp(SPINE_R[i], SPINE_R[i + 1], t);
        return add(mix(pts[i], pts[i + 1], t), mul([-d[1] / L, d[0] / L], HEART.across * r));
      }
      left -= L;
    }
  }

  // ---- arms: thorned forearms, hooked claws ------------------------------------------
  function drawHand(B, wr, h, ramp, grp) {
    if (!h || h.grip) return;
    disc(B, wr, 1.8, ramp, grp, { bias: 0.1 });
    var spread = 12 + 20 * (h.open || 0), curl = h.curl || 0, top = ramp.length - 1;
    var L1 = [2.6, 3.3, 3.1, 2.4], L2 = [2.2, 2.8, 2.6, 2.0], L3 = [1.6, 2.0, 1.9, 1.4];
    for (var j = 0; j < 4; j++) {
      var a = h.ang + (j - 1.5) * spread;
      var p1 = add(wr, mul(dirv(a), L1[j]));
      var p2 = add(p1, mul(dirv(a + curl * 0.6), L2[j]));
      var p3 = add(p2, mul(dirv(a + curl * 1.25), L3[j]));
      tube(B, [wr, p1, p2], [0.95, 0.7, 0.55], ramp, grp, { bias: 0.05 });
      line(B, p2, p3, ramp, top - 1, grp);
      dot(B, p3, ramp, top, grp);
    }
  }
  function drawArm(B, A, ramp, grp, hand, bias) {
    tube(B, [A.sh, A.el, A.wr], [3.1, 2.4, 1.9], ramp, grp, { tex: barkTex, bias: bias || 0 });
    disc(B, A.el, 2.7, ramp, grp, { bias: (bias || 0) + 0.08, tex: barkTex });
    var out = norm(add(sub(A.el, A.sh), sub(A.el, A.wr)));
    thorn(B, add(A.el, mul(out, 2.1)), out, 3.8, ramp, grp, -18);
    var fore = norm(sub(A.wr, A.el)), side = [-fore[1], fore[0]];
    if (side[1] > 0) side = mul(side, -1);
    [0.3, 0.55, 0.8].forEach(function (t, n) {
      thorn(B, add(mix(A.el, A.wr, t), mul(side, 1.9 - 0.4 * t)), add(side, mul(fore, 0.7)), 2.6 - 0.4 * n, ramp, grp, 14);
    });
    var upper = norm(sub(A.el, A.sh)), us = [-upper[1], upper[0]];
    if (us[1] > 0) us = mul(us, -1);
    thorn(B, add(mix(A.sh, A.el, 0.5), mul(us, 2.5)), add(us, mul(upper, 0.5)), 2.2, ramp, grp, 12);
    drawHand(B, A.wr, hand, ramp, grp);
  }

  // ---- the moss mane: ragged, bristling, thorns breaking through ------------------------
  function maneFrame(p) {
    var d = norm(sub(p.N, p.C)), ang = Math.atan2(d[1], d[0]) * 180 / Math.PI + 90;
    return frame(add(mix(p.N, p.C, 0.08), [-2.6, -1.8]), ang, 1);
  }
  function drawMane(B, p) {
    var T = maneFrame(p), RX = 10.2, RY = 6.8, sw = p.mane || 0, br = p.bristle || 0;
    eachPixel(T, [-15, -13, 15, 16], function (x, y, u, v) {
      var uu = u - (v > 2 ? sw * (v - 2) * 0.24 : 0);
      var th = Math.atan2(v / RY, uu / RX), q = Math.sqrt((uu / RX) * (uu / RX) + (v / RY) * (v / RY));
      var st = Math.sin(th), hb = hash(Math.floor((th + 4) * 15), 2), bump;
      if (st > 0.1) bump = 1 + (0.7 + 0.25 * br) * hb * st * (uu > 1 ? 0.3 : 1);
      else bump = 1 + (0.32 + 0.3 * br) * hash(Math.floor((th + 4) * 13), 9);
      if (q > bump) return;
      var nn = norm([uu / RX, v / RY]), wn = T.rotN(nn[0], nn[1]), qq = Math.min(1, q);
      var s = wn[0] * qq * LX + wn[1] * qq * LY + Math.sqrt(Math.max(0, 1 - qq * qq)) * LZ;
      var idx = shadeIdx(s, 5) - 1, h = hash(Math.floor(uu * 0.75) + 31, Math.floor(v * 0.4 + uu * 0.1) + 7);
      if (h > 0.66) idx -= 1; else if (h < 0.14) idx += 1;
      if (q > 1.02) idx = hb > 0.8 ? 0 : Math.min(idx, 1);
      if (h > 0.93 && q < 0.85) { B.put(x, y, R.bark, 2, G.MANE); return; }
      B.put(x, y, R.moss, idx, G.MANE);
    });
    [[-165, 5.6, -14], [-145, 6.8, -10], [-122, 5.4, 12], [-98, 4.4, -8], [-72, 5.0, 14], [-46, 4.0, 10], [-20, 3.2, 8]].forEach(function (s) {
      var base = T.w(Math.cos(rad(s[0])) * RX * 0.9, Math.sin(rad(s[0])) * RY * 0.9);
      thorn(B, base, T.rotN(Math.cos(rad(s[0] - 14)), Math.sin(rad(s[0] - 14))), s[1] * (1 + 0.18 * br), R.bark, G.MANE, s[2]);
    });
    var lf = p.leaf || 0;
    [[-6.8, -3.4, 1], [3.6, -5.4, 0], [-8.6, 2.4, 2]].forEach(function (L, n) {
      leaf(B, T.w(L[0] + (n === lf % 3 ? 0.6 : 0), L[1]), L[2], G.MANE, n % 2 === 1);
    });
    [[-7.2, 0], [-3.0, 1], [5.6, 2]].forEach(function (s) {
      var a = T.w(s[0], RY * 0.95), e = add(a, [sw * 0.9 + (s[1] - 1) * 0.3, 5 + s[1] * 1.4]);
      line(B, a, e, R.moss, 1, G.MANE);
      dot(B, e, R.moss, 0, G.MANE);
    });
  }

  // ---- head: a long carved mask, a grin full of splinters, crowned with antlers --------
  var FACE = [[-5.2, -5.0], [-2.8, -7.2], [1.4, -7.8], [5.0, -6.8], [7.0, -4.4], [7.6, -1.4], [6.6, 0.8], [7.0, 2.4], [5.6, 4.4], [4.6, 7.0], [3.4, 10.0], [2.2, 12.2], [1.2, 9.6], [-0.4, 7.4], [-2.4, 5.2], [-3.4, 3.4], [-4.8, 2.6], [-6.0, -1.2]];
  var ANTLERS = [
    { root: [-1.8, -6.2], ang: -118, len: 17, bend: -20, r: 2.0, tines: [[0.3, 50, 5.0, 10], [0.55, -44, 5.2, -12], [0.78, 38, 3.6, 8], [0.92, -30, 2.4, 0]], leaf: 0.34 },
    { root: [2.6, -7.1], ang: -66, len: 13.5, bend: 20, r: 1.75, tines: [[0.4, -42, 4.4, -10], [0.7, 36, 3.8, 10], [0.88, -26, 2.2, 0]] },
    { root: [-4.9, -3.4], ang: -160, len: 8.5, bend: -14, r: 1.35, tines: [[0.55, 42, 2.8, 8]] },
    { root: [6.0, -4.8], ang: -26, len: 6, bend: 16, r: 1.1, tines: [[0.6, -40, 2.0, 0]] },
    { root: [0.4, -7.4], ang: -94, len: 7.5, bend: -8, r: 1.25, tines: [] }
  ];
  var HEAD_SC = 0.92;
  function drawCrown(B, T, sway) {
    ANTLERS.forEach(function (d, j) {
      var wa = T.deg + d.ang + sway * (5 + j * 2.5), r0 = T.w(d.root[0], d.root[1]);
      var k1 = add(r0, mul(dirv(wa), d.len * 0.38));
      var k2 = add(k1, mul(dirv(wa + d.bend * 0.6), d.len * 0.34));
      var tip = add(k2, mul(dirv(wa + d.bend * 1.4), d.len * 0.28));
      var path = [r0, k1, k2, tip], angs = [wa, wa + d.bend * 0.6, wa + d.bend * 1.4];
      tube(B, path, [d.r, d.r * 0.74, d.r * 0.5, 0.42], R.bark, G.CROWN, { bias: 0.14, tex: barkTex });
      dot(B, tip, R.bark, 5, G.CROWN);
      d.tines.forEach(function (tn) {
        var seg = tn[0] < 0.38 ? 0 : tn[0] < 0.72 ? 1 : 2;
        var segT = seg === 0 ? tn[0] / 0.38 : seg === 1 ? (tn[0] - 0.38) / 0.34 : (tn[0] - 0.72) / 0.28;
        thorn(B, mix(path[seg], path[seg + 1], segT), dirv(angs[seg] + tn[1]), tn[2], R.bark, G.CROWN, tn[3]);
      });
    });
  }
  function drawHead(B, p) {
    var T = frame(p.H, p.ha, HEAD_SC), jaw = p.jaw || 0;
    drawCrown(B, T, p.crown || 0);
    eachPixel(T, [-8, -9, 9, 13], function (x, y, u, v) {
      if (!inside(FACE, u, v)) return;
      var uc = 2.4 + 0.08 * v, idx;
      if (u < uc) idx = u < -4.2 ? 3 : 4; else idx = u > 6.0 ? 1 : 2;
      if (v > 4.6) idx -= 1;
      if (v > 8.0) idx -= 1;
      if (v < -5.8) idx += 1;
      var ck = (u + 3.4) * 0.62 - (v - 1.6) * 0.78;
      if (u < uc && v > 0.8 && v < 5.0 && Math.abs(ck) < 0.55) idx -= 2;
      else if (u < uc && v > -0.4 && v < 1.4 && u > -4.6 && u < 0.4) idx += 1;
      if (u > uc && v > 1.0 && v < 5.6 && Math.abs((u - 5.6) + (v - 3) * 0.3) < 0.5) idx -= 1;
      if (Math.sin(u * 2.9 + v * 0.35 + Math.sin(v * 0.6) * 1.2) > 0.9 && v > -5.4) idx -= 1;
      B.put(x, y, R.bark, idx, G.HEAD);
    });
    // a heavy brow pinched into a V, frown furrows above it
    tube(B, [T.w(-3.4, -4.6), T.w(2.6, -2.5), T.w(7.2, -4.5)], [1.4 * HEAD_SC, 1.15 * HEAD_SC, 0.95 * HEAD_SC], R.bark, G.HEAD, { bias: 0.42 });
    line(B, T.w(-1.6, -6.1), T.w(2.4, -4.4), R.bark, 1, G.HEAD);
    line(B, T.w(2.8, -4.4), T.w(5.6, -5.9), R.bark, 1, G.HEAD);
    [[0.0, -1.5, 3.0, 1.55, 18], [5.4, -1.7, 1.9, 1.15, -20]].forEach(function (e) {
      var c = Math.cos(rad(e[4])), s = Math.sin(rad(e[4]));
      eachPixel(T, [e[0] - e[2] - 1, e[1] - e[2] - 1, e[0] + e[2] + 1, e[1] + e[2] + 1], function (x, y, u, v) {
        var du = u - e[0], dv = v - e[1], a = (du * c + dv * s) / e[2], b = (-du * s + dv * c) / e[3];
        if (a * a + b * b <= 1) B.put(x, y, R.bark, 0, G.HEAD);
      });
    });
    line(B, T.w(2.6, -2.2), T.w(3.7, 1.0), R.bark, 5, G.HEAD);
    line(B, T.w(3.1, -2.0), T.w(4.2, 1.0), R.bark, 2, G.HEAD);
    dot(B, T.w(4.3, 1.4), R.bark, 0, G.HEAD);
    // the grin: wide, upturned at the corners, crowded with splinter teeth; it gapes on the shot
    var u0 = -2.8, u1 = 6.6;
    eachPixel(T, [u0 - 1, 0, u1 + 1, 9], function (x, y, u, v) {
      if (u < u0 || u > u1 || !inside(FACE, u, v)) return;
      var t = (u - u0) / (u1 - u0), mid = 3.3 - 1.1 * Math.pow((t - 0.45) / 0.55, 2), bell = Math.sin(Math.PI * t);
      var top = mid - (0.35 + 0.35 * bell), bot = mid + (0.35 + 0.35 * bell) + jaw * 2.6 * bell;
      if (v < top || v > bot) return;
      var col = [R.bark, 0];
      if (frac(u * 0.614 + 0.2) < 0.5 && v < top + 0.75 + 0.85 * bell) col = [R.bone, v < top + 0.5 ? 2 : 1];
      else if (frac(u * 0.614 + 0.7) < 0.45 && v > bot - (0.55 + 0.6 * bell)) col = [R.bone, 1];
      else if (jaw > 0.5 && bell > 0.7 && v > top + 1.0 && v < bot - 0.8) col = [R.glow, jaw > 0.75 && bell > 0.9 ? 3 : 1];
      else if (bell > 0.75 && v > top + 0.5) col = [R.glow, 0];
      B.put(x, y, col[0], col[1], G.HEAD);
    });
    thorn(B, T.w(6.0, 4.4), T.rotN(0.8, 0.6), 2.0, R.bark, G.HEAD, 10);
    thorn(B, T.w(2.4, 11.2), T.rotN(-0.2, 1), 1.8, R.bark, G.HEAD, 0);
    return { T: T, eyes: [{ a: [-2.2, -2.6], b: [2.0, -1.2], w: 0.95 }, { a: [4.5, -1.3], b: [6.5, -2.45], w: 0.75 }] };
  }

  // ---- bow: two branches braided together, antlered toward both tips ------------------
  var BOW_HALF = 18;
  function bowGeom(bw) {
    var a = rad(bw.ba), up = [Math.sin(a), -Math.cos(a)], fw = [Math.cos(a), Math.sin(a)];
    var Lh = BOW_HALF * (bw.pull ? 0.95 : 1), k = bw.k;
    function at(t, sg) {
      var al = Lh * t, back = k * t * t, fl = 2.6 * smooth(0.74, 1.0, t);
      return [bw.G[0] + up[0] * al * sg + fw[0] * (fl - back), bw.G[1] + up[1] * al * sg + fw[1] * (fl - back)];
    }
    return { at: at, up: up, fw: fw, tipU: at(1, 1), tipD: at(1, -1) };
  }
  function drawBow(B, bw) {
    var g = bowGeom(bw), N = 16;
    [1, -1].forEach(function (sg) {
      var strands = [0, 1].map(function (j) {
        var pts = [], rads = [];
        for (var i = 0; i <= N; i++) {
          var t = i / N;
          pts.push(add(g.at(t, sg), mul(g.fw, 0.8 * Math.sin(t * 13 + j * Math.PI) * (1 - 0.65 * t))));
          rads.push(lerp(1.45, 0.42, Math.pow(t, 0.8)));
        }
        return { pts: pts, rads: rads };
      });
      tube(B, strands[1].pts, strands[1].rads, R.dead, G.BOW, { bias: -0.12, tex: barkTex });
      tube(B, strands[0].pts, strands[0].rads, R.dead, G.BOW, { bias: 0.06, tex: barkTex });
      for (var i = 0; i < N; i++) {
        if (Math.floor((((i + 0.5) / N) * 13) / Math.PI) % 2 === 1) tube(B, strands[1].pts.slice(i, i + 2), strands[1].rads.slice(i, i + 2), R.dead, G.BOW, { bias: -0.04 });
      }
      [[0.36, 4.2, 0.9, 10], [0.56, 6.2, 0.8, 14], [0.76, 4.8, 0.7, 10], [0.9, 3.2, 0.6, 0]].forEach(function (f, n) {
        var b = g.at(f[0], sg), dir = norm(add(mul(g.fw, f[2]), mul(g.up, sg)));
        thorn(B, b, dir, f[1], R.dead, G.BOW, f[3] * sg);
        if (n === 1) thorn(B, add(b, mul(dir, f[1] * 0.5)), norm(add(dir, mul(g.fw, -0.9))), 2.4, R.dead, G.BOW, 0);
      });
      [0.22, 0.46, 0.66].forEach(function (t) {
        thorn(B, add(g.at(t, sg), mul(g.fw, -1.2 + 0.5 * t)), add(mul(g.fw, -1), mul(g.up, 0.8 * sg)), 1.7, R.dead, G.BOW, 0);
      });
    });
    [-1.8, -0.4, 1.0].forEach(function (o, n) {
      var c = add(bw.G, mul(g.up, o));
      line(B, add(c, mul(g.fw, -2.4)), add(c, mul(g.fw, 2.4)), R.cord, n === 1 ? 2 : 1, G.BOW);
    });
    leaf(B, add(g.at(0.2, -1), mul(g.fw, 2.8)), 0, G.BOW);
    leaf(B, add(g.at(0.28, 1), mul(g.fw, 2.6)), 2, G.BOW, true);
  }
  function drawString(B, bw, grp) {
    var g = bowGeom(bw), mid = bw.pull || add(mul(add(g.tipU, g.tipD), 0.5), mul(g.fw, bw.vib || 0));
    line(B, g.tipU, mid, STRING_C, 0, grp);
    line(B, mid, g.tipD, STRING_C, 0, grp);
  }
  function drawGrip(B, bw) {
    var g = bowGeom(bw), gp = bw.G;
    [[1.3, 3], [0.1, 4], [-1.1, 3], [-2.2, 2]].forEach(function (f) {
      line(B, add(gp, add(mul(g.fw, -2.6), mul(g.up, f[0]))), add(gp, add(mul(g.fw, 2.0), mul(g.up, f[0]))), R.far, f[1], G.FARARM);
    });
  }

  var ARROW_LEN = 22;
  function drawArrow(B, ar, grp) {
    var d = dirv(ar.ang), n = [-d[1], d[0]], nk = ar.nock;
    function P(a, b) { return add(add(nk, mul(d, a)), mul(n, b)); }
    line(B, P(0.3, 0), P(ARROW_LEN - 4.2, 0), R.bone, 1, grp);
    line(B, P(ARROW_LEN - 4.2, 0), P(ARROW_LEN, 0), R.bone, 3, grp);
    line(B, P(ARROW_LEN - 4.0, -1.1), P(ARROW_LEN - 1.6, 0), R.bone, 2, grp);
    line(B, P(ARROW_LEN - 4.0, 1.1), P(ARROW_LEN - 1.6, 0), R.bone, 2, grp);
    [1.0, 2.0, 3.0, 4.0].forEach(function (k, i) {
      dot(B, P(k, -0.9 - 0.25 * (i % 2)), R.leaf, 3 - (i % 2), grp);
      dot(B, P(k, 0.9 + 0.25 * (i % 2)), R.leaf, 2 - (i % 2), grp);
    });
  }

  // ---- post passes (pixel space) --------------------------------------------------------
  function pairOK(back, front) {
    if (front === G.STRING || front === G.BSTRING || front === G.FX || back === G.FX) return false;
    if ((back === G.CROWN && front === G.HEAD) || (back === G.HEAD && front === G.CROWN)) return false;
    return true;
  }
  var NB = [[1, 0], [-1, 0], [0, 1], [0, -1]];
  function innerLines(B) {
    var mark = [];
    for (var y = 0; y < H; y++) for (var x = 0; x < W; x++) {
      var k = y * W + x, g = B.g[k];
      if (!g || g === G.STRING || g === G.BSTRING || g === G.FX) continue;
      for (var j = 0; j < 4; j++) {
        var xx = x + NB[j][0], yy = y + NB[j][1];
        if (xx < 0 || yy < 0 || xx >= W || yy >= H) continue;
        var gq = B.g[yy * W + xx];
        if (gq > g && pairOK(g, gq)) { mark.push(k); break; }
      }
    }
    mark.forEach(function (k) { if (B.i[k] > 0) { B.i[k] = 0; B.c[k] = B.r[k][0]; } else B.c[k] = OUT; });
  }
  function outerLine(B) {
    var addk = [];
    for (var y = 0; y < H; y++) for (var x = 0; x < W; x++) {
      var k = y * W + x;
      if (B.g[k]) continue;
      for (var j = 0; j < 4; j++) {
        var xx = x + NB[j][0], yy = y + NB[j][1];
        if (xx < 0 || yy < 0 || xx >= W || yy >= H) continue;
        var gq = B.g[yy * W + xx];
        if (gq && gq !== G.FX && gq !== 99) { addk.push(k); break; }
      }
    }
    addk.forEach(function (k) { B.c[k] = OUT; B.g[k] = 99; });
  }
  // slanted slit eyes: white-hot cores, a rim of orange, light spilling onto the wood
  function lightEyes(B, hd) {
    var T = hd.T, list = hd.eyes;
    eachPixel(T, [-5, -6, 9, 2], function (x, y, u, v) {
      var k = y * W + x;
      if (B.g[k] !== G.HEAD) return;
      var qmin = 9, gap = 9;
      list.forEach(function (e) {
        var ab = sub(e.b, e.a), t = clamp(((u - e.a[0]) * ab[0] + (v - e.a[1]) * ab[1]) / (ab[0] * ab[0] + ab[1] * ab[1]), 0, 1);
        var d = Math.hypot(u - (e.a[0] + ab[0] * t), v - (e.a[1] + ab[1] * t));
        var w = e.w * Math.pow(Math.sin(Math.PI * (0.06 + 0.88 * t)), 0.6);
        qmin = Math.min(qmin, d / Math.max(w, 0.2));
        gap = Math.min(gap, d - w);
      });
      if (qmin <= 1) B.c[k] = qmin < 0.45 ? R.glow[5] : qmin < 0.8 ? R.glow[4] : R.glow[3];
      else if (gap < 1.4) B.c[k] = mixHex(B.c[k], EYE_SPILL, 0.55 * (1 - gap / 1.4));
    });
    var e0 = list[0];
    return px(T.w((e0.a[0] + e0.b[0]) / 2, (e0.a[1] + e0.b[1]) / 2));
  }

  // ---- poses (design units; ground at y 73.7) ------------------------------------------
  function idlePose(i, n) {
    var ph = i / n;
    var br = Math.sin(TAU * ph), brL = Math.sin(TAU * (ph - 0.12)), sway = Math.sin(TAU * (ph - 0.3));
    var tw = ({ 7: 0.5, 8: 1, 9: 0.6, 10: 0.2 })[i] || 0;
    var P = [37.0, 52.2], N = [42.6, 35.0 - 0.6 * br];
    return {
      P: P, W: [37.6, 46.6 - 0.15 * br], C: [39.8, 40.2 - 0.5 * br], N: N,
      H: [48.6 + 0.7 * tw, 29.8 - 0.5 * brL - 0.5 * tw], ha: 8 - 2 * brL - 12 * tw,
      jaw: 0.08 + 0.4 * tw, crown: 0.8 * sway + 0.8 * tw, mane: Math.sin(TAU * (ph - 0.25)), bristle: 0.25 * tw,
      skirt: Math.sin(TAU * (ph - 0.4)), leaf: Math.floor(i / 3),
      hipN: [P[0] - 1.2, P[1] + 0.4], hipF: [P[0] + 1.6, P[1]],
      ankN: [24.0, 69.8], ankF: [50.8, 69.8], footN: { ang: 0 }, footF: { ang: 0 },
      shN: [N[0] - 6.6, N[1] + 1.8], shF: [N[0] + 4.4, N[1] + 1.4],
      wrN: [30.2 + 0.4 * brL, 55.0 - 0.3 * br], bendN: 1,
      wrF: [57.4, 49.2 - 0.3 * br], bendF: 1,
      handN: { ang: 100, open: (i === 4 || i === 5) ? 0.9 : 0.15, curl: 34 },
      handF: { grip: true },
      bow: { G: [58.6, 49.6 - 0.3 * br], ba: 58 + 1.5 * brL, k: 4.5, pull: null, vib: 0 },
      arrow: null, smear: 0, armOverMane: false
    };
  }
  function walkPose(i, n) {
    var ph = i / n;
    var bob = Math.cos(2 * TAU * ph), bobL = Math.cos(2 * TAU * (ph - 0.1)), sw = Math.cos(TAU * ph);
    var P = [37.6, 51.6 + 0.9 * bob], N = [43.4, 34.8 + 0.7 * bobL];
    function foot(fp) {
      fp = ((fp % 1) + 1) % 1;
      if (fp < 0.5) { var s = fp / 0.5; return { ank: [P[0] + lerp(10, -10, s), 69.8], ang: lerp(-4, 8, s) }; }
      var s2 = (fp - 0.5) / 0.5, e = ease(s2);
      return { ank: [P[0] + lerp(-10, 10, e), 69.8 - 6.4 * Math.sin(Math.PI * s2)], ang: 26 * Math.sin(Math.PI * s2) };
    }
    var fN = foot(ph), fF = foot(ph + 0.5);
    var shN = [N[0] - 6.6, N[1] + 1.8], shF = [N[0] + 4.4, N[1] + 1.4];
    return {
      P: P, W: [38.4, 46.0 + 0.8 * bob], C: [40.6, 39.8 + 0.6 * bobL], N: N,
      H: [49.4, 29.6 + 0.8 * Math.cos(2 * TAU * (ph - 0.16))], ha: 6 + 3 * Math.cos(2 * TAU * (ph - 0.2)),
      jaw: 0.1, crown: Math.sin(2 * TAU * (ph - 0.22)) * 0.9, mane: Math.sin(2 * TAU * (ph - 0.3)), bristle: 0,
      skirt: -sw * 0.9, leaf: i,
      hipN: [P[0] - 1.2, P[1] + 0.4], hipF: [P[0] + 1.6, P[1]],
      ankN: fN.ank, ankF: fF.ank, footN: { ang: fN.ang }, footF: { ang: fF.ang },
      shN: shN, shF: shF,
      wrN: [shN[0] - 3 - 5.4 * sw, shN[1] + 17.4 - 1.4 * Math.abs(sw)], bendN: 1,
      wrF: [shF[0] + 9.0 + 2.2 * sw, shF[1] + 13.0], bendF: 1,
      handN: { ang: 100 + 22 * sw, open: 0.25, curl: 32 + 10 * sw }, handF: { grip: true },
      bow: { G: [shF[0] + 10.2 + 2.2 * sw, shF[1] + 13.4], ba: 56 + 5 * sw, k: 4.5, pull: null, vib: 0 },
      arrow: null, smear: 0, armOverMane: false
    };
  }
  function aimPose() {
    var P = [37.8, 51.8], N = [43.0, 34.4];
    return {
      P: P, W: [38.4, 46.2], C: [40.4, 39.6], N: N,
      H: [47.6, 27.4], ha: 0, jaw: 0.3, crown: -1.1, mane: -1, bristle: 0.4, skirt: -0.6, leaf: 0,
      hipN: [P[0] - 1.2, P[1] + 0.4], hipF: [P[0] + 1.6, P[1]],
      ankN: [23.4, 69.8], ankF: [51.6, 69.8], footN: { ang: 0 }, footF: { ang: 0 },
      shN: [N[0] - 6.6, N[1] + 1.6], shF: [N[0] + 4.4, N[1] + 1.2],
      wrF: [64.2, 33.6], bendF: 1, handF: { grip: true },
      wrN: [49.6, 33.6], elN: [36.4, 24.6], bendN: -1, handN: { ang: 4, open: 0, curl: 92 },
      bow: { G: [65.4, 33.6], ba: 0, k: 10, pull: [50.2, 33.6], vib: 0 },
      arrow: { nock: [50.2, 33.6], ang: 0 }, smear: 0, armOverMane: true
    };
  }
  function merge(a, b) {
    var o = {}, k;
    for (k in a) o[k] = a[k];
    for (k in b) {
      if (b[k] && a[k] && typeof b[k] === 'object' && !Array.isArray(b[k]) && typeof a[k] === 'object' && !Array.isArray(a[k])) o[k] = merge(a[k], b[k]);
      else o[k] = b[k];
    }
    return o;
  }
  function blend(a, b, t, key) {
    if (key && (key.indexOf('bend') === 0 || key === 'armOverMane')) return t < 0.5 ? a : b;
    if (typeof a === 'number' && typeof b === 'number') return lerp(a, b, t);
    if (Array.isArray(a) && Array.isArray(b)) return a.map(function (v, i) { return blend(v, b[i], t); });
    if (a && b && typeof a === 'object' && typeof b === 'object') {
      var o = {}, k;
      for (k in a) o[k] = (k in b) ? blend(a[k], b[k], t, k) : a[k];
      for (k in b) if (!(k in a)) o[k] = b[k];
      return o;
    }
    return t < 0.5 ? a : b;
  }
  var CAST = [
    {},
    { H: [47.2, 27.6], ha: -2, jaw: 1, bristle: 1, crown: 0.5, wrF: [65.0, 33.8], bow: { G: [66.2, 33.8], ba: 4, k: 4.5, pull: null, vib: 2.0 }, arrow: null, smear: 1,
      wrN: [42.6, 30.0], elN: [34.2, 25.2], handN: { ang: -150, open: 1, curl: 8 } },
    { H: [47.4, 27.7], ha: -1, jaw: 0.85, bristle: 0.8, crown: 1.3, wrF: [64.8, 34.2], bow: { G: [66.0, 34.2], ba: 6, k: 4.5, pull: null, vib: -1.4 }, arrow: null, smear: 2,
      wrN: [40.2, 29.0], elN: [32.6, 25.8], handN: { ang: -165, open: 0.9, curl: 14 } },
    { H: [47.6, 27.8], ha: 1, jaw: 0.55, bristle: 0.5, crown: 0.8, wrF: [64.6, 34.6], bow: { G: [65.8, 34.6], ba: 7, k: 4.5, pull: null, vib: 0.6 }, arrow: null, smear: 0,
      wrN: [39.6, 30.0], elN: [32.2, 26.8], handN: { ang: -175, open: 0.6, curl: 24 } },
    { H: [48.2, 28.4], ha: 4, jaw: 0.3, bristle: 0.25, crown: 0.3, wrF: [62.4, 37.6], bow: { G: [63.6, 38.0], ba: 18, k: 4.5, pull: null, vib: 0 }, arrow: null, smear: 0,
      wrN: [33.2, 46.0], bendN: 1, handN: { ang: 120, open: 0.3, curl: 30 }, armOverMane: false }
  ];
  function castPose(i) {
    if (i <= 4) { var p = merge(aimPose(), CAST[i]); if (i === 4) delete p.elN; return p; }
    var f4 = merge(aimPose(), CAST[4]); delete f4.elN;
    return blend(f4, idlePose(0, 12), [0.34, 0.68, 0.9][i - 5]);
  }

  // ---- render ----------------------------------------------------------------------
  function render(p) {
    var B = new Buf();
    var legN = legChain(p.hipN, p.ankN), legF = legChain(p.hipF, p.ankF);
    var armN = { sh: p.shN, el: p.elN || ik2(p.shN, p.wrN, UPPER, FORE, p.bendN), wr: p.wrN };
    var armF = { sh: p.shF, el: p.elF || ik2(p.shF, p.wrF, UPPER, FORE, p.bendF), wr: p.wrF };
    drawLeg(B, legF, R.far, G.FARLEG, p.footF, false);
    drawArm(B, armF, R.far, G.FARARM, p.handF, 0);
    drawBow(B, p.bow);
    drawGrip(B, p.bow);
    if (!p.bow.pull) drawString(B, p.bow, G.BSTRING);
    drawTorso(B, p);
    drawLeg(B, legN, R.bark, G.NEARLEG, p.footN, true);
    drawTrophies(B, drawSkirt(B, p), p);
    if (!p.armOverMane) drawArm(B, armN, R.bark, G.NEARARM, p.handN, 0.16);
    drawMane(B, p);
    var hd = drawHead(B, p);
    if (p.arrow) drawArrow(B, p.arrow, G.ARROW);
    if (p.bow.pull) drawString(B, p.bow, G.STRING);
    if (p.armOverMane) drawArm(B, armN, R.bark, G.NEARARM2, p.handN, 0.16);
    if (p.smear) {
      var sy = p.bow.G[1], sx = p.bow.G[0] + (p.smear === 1 ? 3 : 9), cnt = p.smear === 1 ? 14 : 8;
      for (var k = 0; k < cnt; k++) { if (k % 3 === 2) continue; dot(B, [sx + k / K, sy], R.bone, p.smear === 1 ? (k > 8 ? 2 : 3) : 1, G.FX); }
    }
    innerLines(B);
    outerLine(B);
    var eye = lightEyes(B, hd), bg = bowGeom(p.bow), mt = maneFrame(p);
    return {
      buf: B, eye: eye, grip: px(p.bow.G), hump: px(mt.w(-1, -7.6)), heart: px(heartPoint(p)),
      arrowTip: p.arrow ? px(add(p.arrow.nock, mul(dirv(p.arrow.ang), ARROW_LEN))) : null, bowTips: [px(bg.tipU), px(bg.tipD)]
    };
  }
  function toCanvas(B, w, h) {
    w = w || W; h = h || H;
    var cv = document.createElement('canvas'); cv.width = w; cv.height = h;
    var ctx = cv.getContext('2d'), im = ctx.createImageData(w, h);
    for (var y = 0; y < h; y++) for (var x = 0; x < w; x++) {
      var c = B.c[y * W + x];
      if (!c) continue;
      var v = rgb(c), k = (y * w + x) * 4;
      im.data[k] = v[0]; im.data[k + 1] = v[1]; im.data[k + 2] = v[2]; im.data[k + 3] = 255;
    }
    ctx.putImageData(im, 0, 0);
    return cv;
  }

  var ANIMS = [
    { key: 'idle', label: 'Idle', frames: 12, fps: 8, row: 0, note: 'the ember breathes under the moss; on frames 7–10 the head snaps up and the jaw parts' },
    { key: 'walk', label: 'Walk', frames: 8, fps: 12, row: 1, note: 'a wide, rooted stride; bark strips and trophies swing behind it' },
    { key: 'cast', label: 'Cast — Bone Arrow', frames: 8, fps: 20, row: 2, note: 'frame 0 is full draw; on frame 1 the arrow leaves and the jaw gapes' }
  ];
  var byKey = {}; ANIMS.forEach(function (a) { byKey[a.key] = a; });
  var COLS = Math.max.apply(null, ANIMS.map(function (a) { return a.frames; }));

  var cache = {};
  function frameData(key, i) {
    var id = key + i;
    if (!cache[id]) {
      var r = render(key === 'idle' ? idlePose(i, 12) : key === 'walk' ? walkPose(i, 8) : castPose(i));
      cache[id] = { canvas: toCanvas(r.buf), eye: r.eye, grip: r.grip, hump: r.hump, heart: r.heart, arrowTip: r.arrowTip, bowTips: r.bowTips, urls: {} };
    }
    return cache[id];
  }
  function scaled(src, s) {
    var cv = document.createElement('canvas'); cv.width = src.width * s; cv.height = src.height * s;
    var ctx = cv.getContext('2d'); ctx.imageSmoothingEnabled = false;
    ctx.drawImage(src, 0, 0, cv.width, cv.height);
    return cv;
  }
  function frameURL(key, i, s) {
    var f = frameData(key, i); s = s || 1;
    if (!f.urls[s]) f.urls[s] = scaled(f.canvas, s).toDataURL('image/png');
    return f.urls[s];
  }
  function sheetCanvas(s) {
    s = s || 1;
    var cv = document.createElement('canvas'); cv.width = COLS * W * s; cv.height = ANIMS.length * H * s;
    var ctx = cv.getContext('2d'); ctx.imageSmoothingEnabled = false;
    ANIMS.forEach(function (a) {
      for (var i = 0; i < a.frames; i++) ctx.drawImage(frameData(a.key, i).canvas, i * W * s, a.row * H * s, W * s, H * s);
    });
    return cv;
  }
  var sheetURLs = {};
  function sheetURL(s) { s = s || 1; if (!sheetURLs[s]) sheetURLs[s] = sheetCanvas(s).toDataURL('image/png'); return sheetURLs[s]; }

  var AW = Math.ceil((ARROW_LEN + 4) * K), AH = 9, ANOCK_D = [2, AH / 2 / K];
  var arrowURLs = {};
  function arrowURL(s) {
    s = s || 1;
    if (!arrowURLs[s]) {
      var B = new Buf();
      drawArrow(B, { nock: ANOCK_D, ang: 0 }, G.ARROW);
      outerLine(B);
      arrowURLs[s] = scaled(toCanvas(B, AW, AH), s).toDataURL('image/png');
    }
    return arrowURLs[s];
  }
  function muzzlePx() { var tip = frameData('cast', 0).arrowTip; return [tip[0] - PIVOT[0], tip[1] - PIVOT[1]]; }
  function muzzle() { var m = muzzlePx(); return [Math.round(m[0] * SCALE), Math.round(m[1] * SCALE)]; }

  function snippet() {
    var m = muzzle();
    return [
      'const POACHER := "res://assets/poacher.png"',
      '',
      '\t\t"frame": Vector2i(' + W + ', ' + H + '),',
      '\t\t"pivot": Vector2(' + PIVOT[0].toFixed(1) + ', ' + PIVOT[1].toFixed(1) + '),',
      '\t\t"scale": ' + SCALE.toFixed(1) + ',',
      '\t\t"art_holds_weapon": true,',
      '\t\t# Where the nocked arrow\'s head sits at full draw (cast frame 0), in world units.',
      '\t\t"body_offset": Vector2(' + m[0].toFixed(1) + ', ' + m[1].toFixed(1) + '),',
      '\t\t...',
      '\t\t"anims": {',
      ANIMS.map(function (a) { return '\t\t\t"' + a.key + '": [POACHER, ' + a.row + ', ' + a.frames + ', ' + a.fps.toFixed(1) + '],'; }).join('\n'),
      '\t\t},'
    ].join('\n');
  }

  window.PoacherRig = {
    W: W, H: H, PIVOT: PIVOT, SCALE: SCALE, ANIMS: ANIMS, byKey: byKey, COLS: COLS,
    frame: frameData, frameURL: frameURL, sheetCanvas: sheetCanvas, sheetURL: sheetURL,
    arrowURL: arrowURL, arrowSize: [AW, AH], arrowNock: [ANOCK_D[0] * K, AH / 2], arrowLen: ARROW_LEN * K,
    muzzle: muzzle, muzzlePx: muzzlePx, snippet: snippet,
    colors: { eye: R.glow[5], eyeMid: R.glow[4] }
  };
})();
