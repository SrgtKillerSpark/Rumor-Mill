// gen_assets.js — generates SPA-712 art assets for Rumor Mill
// Run with: node tools/gen_assets.js
// Outputs to: rumor_mill/assets/textures/

'use strict';
const zlib = require('zlib');
const fs   = require('fs');
const path = require('path');

// ── PNG encoder ──────────────────────────────────────────────────────────────

const _crcTable = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
    t[n] = c;
  }
  return t;
})();

function crc32(buf) {
  let crc = 0xFFFFFFFF;
  for (const b of buf) crc = _crcTable[(crc ^ b) & 0xFF] ^ (crc >>> 8);
  return (crc ^ 0xFFFFFFFF) >>> 0;
}

function pngChunk(type, data) {
  const t = Buffer.from(type, 'ascii');
  const d = Buffer.isBuffer(data) ? data : Buffer.from(data);
  const l = Buffer.alloc(4); l.writeUInt32BE(d.length);
  const c = Buffer.alloc(4); c.writeUInt32BE(crc32(Buffer.concat([t, d])));
  return Buffer.concat([l, t, d, c]);
}

function savePNG(outPath, w, h, rgba) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; ihdr[9] = 6; // 8-bit RGBA

  // Raw scanlines: filter byte 0 (None) + RGBA rows
  const raw = Buffer.alloc(h * (1 + w * 4));
  for (let y = 0; y < h; y++) {
    raw[y * (1 + w * 4)] = 0;
    for (let x = 0; x < w; x++) {
      const s = (y * w + x) * 4;
      const d = y * (1 + w * 4) + 1 + x * 4;
      raw[d] = rgba[s]; raw[d+1] = rgba[s+1]; raw[d+2] = rgba[s+2]; raw[d+3] = rgba[s+3];
    }
  }

  const idat = zlib.deflateSync(raw, { level: 9 });
  const png = Buffer.concat([
    Buffer.from([0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A]),
    pngChunk('IHDR', ihdr),
    pngChunk('IDAT', idat),
    pngChunk('IEND', Buffer.alloc(0))
  ]);
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, png);
  console.log(`  Wrote ${outPath} (${w}x${h})`);
}

// ── Canvas helper ─────────────────────────────────────────────────────────────

function makeCanvas(w, h) {
  const px = new Uint8Array(w * h * 4); // all transparent
  function idx(x, y) { return (y * w + x) * 4; }
  function inBounds(x, y) { return x >= 0 && x < w && y >= 0 && y < h; }

  const c = {
    w, h, px,
    set(x, y, col) {
      if (!inBounds(x, y)) return;
      const i = idx(x, y);
      px[i]=col[0]; px[i+1]=col[1]; px[i+2]=col[2]; px[i+3]=col[3];
    },
    get(x, y) {
      const i = idx(x, y);
      return [px[i], px[i+1], px[i+2], px[i+3]];
    },
    fill(col) {
      for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) c.set(x, y, col);
    },
    rect(x, y, rw, rh, col) {
      for (let dy = 0; dy < rh; dy++) for (let dx = 0; dx < rw; dx++) c.set(x+dx, y+dy, col);
    },
    // Filled circle
    circle(cx, cy, r, col) {
      for (let y = cy-r; y <= cy+r; y++)
        for (let x = cx-r; x <= cx+r; x++)
          if ((x-cx)**2 + (y-cy)**2 <= r*r) c.set(x, y, col);
    },
    // Ring outline
    ring(cx, cy, r, t, col) {
      for (let y = cy-r; y <= cy+r; y++)
        for (let x = cx-r; x <= cx+r; x++) {
          const d2 = (x-cx)**2 + (y-cy)**2;
          if (d2 <= r*r && d2 >= (r-t)**2) c.set(x, y, col);
        }
    },
    // Bresenham line
    line(x0, y0, x1, y1, col) {
      let dx = Math.abs(x1-x0), sx = x0<x1?1:-1;
      let dy = -Math.abs(y1-y0), sy = y0<y1?1:-1;
      let err = dx+dy;
      for (;;) {
        c.set(x0, y0, col);
        if (x0===x1 && y0===y1) break;
        const e2 = 2*err;
        if (e2 >= dy) { err += dy; x0 += sx; }
        if (e2 <= dx) { err += dx; y0 += sy; }
      }
    },
    // Ellipse fill
    ellipse(cx, cy, rx, ry, col) {
      for (let y = cy-ry; y <= cy+ry; y++)
        for (let x = cx-rx; x <= cx+rx; x++)
          if (((x-cx)/rx)**2 + ((y-cy)/ry)**2 <= 1) c.set(x, y, col);
    },
    // Polygon fill (scanline)
    poly(pts, col) {
      let minY = Infinity, maxY = -Infinity;
      for (const [,y] of pts) { minY = Math.min(minY,y); maxY = Math.max(maxY,y); }
      for (let y = Math.floor(minY); y <= Math.ceil(maxY); y++) {
        const xs = [];
        for (let i = 0; i < pts.length; i++) {
          const [x0,y0] = pts[i], [x1,y1] = pts[(i+1)%pts.length];
          if ((y0<=y && y1>y) || (y1<=y && y0>y)) {
            xs.push(x0 + (y-y0)/(y1-y0)*(x1-x0));
          }
        }
        xs.sort((a,b)=>a-b);
        for (let i = 0; i < xs.length-1; i+=2)
          for (let x = Math.round(xs[i]); x <= Math.round(xs[i+1]); x++)
            c.set(x, y, col);
      }
    },
    // Draw a pixel character (3x5 or similar) at position
    save(outPath) { savePNG(outPath, w, h, px); }
  };
  return c;
}

// ── Color palette (matches illuminated manuscript style) ─────────────────────

const T  = [  0,   0,   0,   0]; // transparent
const K  = [ 26,  16,   8, 255]; // near-black ink
const PL = [212, 184, 120, 255]; // parchment light
const PM = [180, 148,  80, 255]; // parchment mid
const PD = [136, 104,  48, 255]; // parchment dark
const GL = [240, 200,  40, 255]; // gold light
const GM = [200, 160,  24, 255]; // gold mid
const GD = [152, 112,  12, 255]; // gold dark
const CR = [244, 236, 208, 255]; // cream
const RD = [160,  32,  16, 255]; // red wax
const NV = [ 28,  40,  92, 255]; // navy blue
const GN = [ 48, 160,  64, 255]; // green (progress)
const BR = [148,  88,  32, 255]; // brown mid
const WH = [255, 248, 228, 255]; // near-white

// ── Output directory ──────────────────────────────────────────────────────────

const OUT = path.join(__dirname, '..', 'rumor_mill', 'assets', 'textures');

// ═══════════════════════════════════════════════════════════════════════════════
// 1.  MILESTONE POPUP CARD  (300 × 200)
// ═══════════════════════════════════════════════════════════════════════════════

function genMilestonePopup() {
  const W = 300, H = 200;
  const cv = makeCanvas(W, H);

  // Base parchment fill with slight warm texture
  cv.fill(PL);

  // Subtle texture variation: darken every 3rd row/col slightly
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const noise = ((x * 7 + y * 13) & 0x1F);
      if (noise < 4) {
        const c = cv.get(x, y);
        cv.set(x, y, [c[0]-8, c[1]-6, c[2]-4, 255]);
      } else if (noise > 28) {
        const c = cv.get(x, y);
        cv.set(x, y, [Math.min(255,c[0]+8), Math.min(255,c[1]+6), Math.min(255,c[2]+3), 255]);
      }
    }
  }

  // Outer dark border (4px)
  for (let i = 0; i < 4; i++) {
    cv.line(i, i, W-1-i, i, K);         // top
    cv.line(i, H-1-i, W-1-i, H-1-i, K); // bottom
    cv.line(i, i, i, H-1-i, K);         // left
    cv.line(W-1-i, i, W-1-i, H-1-i, K); // right
  }

  // Gold inner border (2px) at offset 6
  for (let i = 0; i < 2; i++) {
    cv.line(6+i, 6+i, W-7-i, 6+i, GL);
    cv.line(6+i, H-7-i, W-7-i, H-7-i, GL);
    cv.line(6+i, 6+i, 6+i, H-7-i, GL);
    cv.line(W-7-i, 6+i, W-7-i, H-7-i, GL);
  }

  // ── Corner ornaments: small cross/star at each corner ────────────────────
  function cornerStar(cx, cy) {
    // Plus shape in gold
    cv.rect(cx-1, cy-4, 3, 9, GL);
    cv.rect(cx-4, cy-1, 9, 3, GL);
    // Darker center
    cv.set(cx, cy, GD);
    // Dot accents at tips
    cv.set(cx, cy-5, GD);
    cv.set(cx, cy+5, GD);
    cv.set(cx-5, cy, GD);
    cv.set(cx+5, cy, GD);
    // Diagonal dots
    cv.set(cx-3, cy-3, GM);
    cv.set(cx+3, cy-3, GM);
    cv.set(cx-3, cy+3, GM);
    cv.set(cx+3, cy+3, GM);
  }

  cornerStar(14, 14);
  cornerStar(W-15, 14);
  cornerStar(14, H-15);
  cornerStar(W-15, H-15);

  // ── Top banner area: darker parchment strip for title ────────────────────
  cv.rect(10, 10, W-20, 32, PM);
  for (let i = 0; i < 2; i++) {
    cv.line(10+i, 10+i, W-11-i, 10+i, GD);
    cv.line(10+i, 41-i, W-11-i, 41-i, GD);
    cv.line(10+i, 10+i, 10+i, 41-i, GD);
    cv.line(W-11-i, 10+i, W-11-i, 41-i, GD);
  }

  // ── Wax seal circle (bottom center) ──────────────────────────────────────
  cv.circle(W/2, H-28, 18, RD);
  cv.ring(W/2, H-28, 18, 2, [100, 16, 8, 255]);
  // Cross in seal
  cv.rect(W/2-1, H-28-10, 3, 21, [200, 80, 60, 255]);
  cv.rect(W/2-10, H-28-1, 21, 3, [200, 80, 60, 255]);
  cv.circle(W/2, H-28, 3, [220, 100, 70, 255]);

  // ── Decorative vine lines flanking the seal ───────────────────────────────
  cv.line(20, H-28, W/2-22, H-28, PD);
  cv.line(W/2+22, H-28, W-21, H-28, PD);
  // Small leaf dots
  for (let x = 24; x < W/2-24; x += 8) {
    cv.circle(x, H-28, 2, PM);
    cv.set(x, H-31, GD);
  }
  for (let x = W/2+26; x < W-22; x += 8) {
    cv.circle(x, H-28, 2, PM);
    cv.set(x, H-31, GD);
  }

  cv.save(path.join(OUT, 'ui_milestone_popup.png'));
}

// ═══════════════════════════════════════════════════════════════════════════════
// 2.  MILESTONE ICONS  (160 × 32 — five 32×32 icons)
//     [0] Shield/Reputation  [1] Bubbles/Rumor  [2] Banner/Faction
//     [3] Scroll/Intel       [4] Coin/Resource
// ═══════════════════════════════════════════════════════════════════════════════

function genMilestoneIcons() {
  const cv = makeCanvas(160, 32);
  const ox = [0, 32, 64, 96, 128]; // x offsets for each icon

  // ── [0] Shield (Reputation) ───────────────────────────────────────────────
  {
    const dx = ox[0], cx = dx + 16;
    // Heater shield shape
    // Top straight section y=5..14, width narrows toward point at y=27
    function shieldFill(col, margin) {
      for (let y = 5; y <= 27; y++) {
        let hw;
        if (y <= 14) hw = 10 - margin;
        else hw = Math.round((10 - margin) * (1 - (y-14)/13));
        if (hw <= 0) { cv.set(cx, y, col); continue; }
        for (let x = cx-hw; x <= cx+hw; x++) cv.set(x, y, col);
      }
    }
    // Shadow/outline first (slightly larger)
    shieldFill(K, -1);
    // Parchment fill
    shieldFill(PL, 1);
    // Gold chevron (inverted V) inside shield
    cv.line(cx, 10, cx-6, 18, GL);
    cv.line(cx, 10, cx+6, 18, GL);
    cv.line(cx-6, 18, cx-6, 22, GL);
    cv.line(cx+6, 18, cx+6, 22, GL);
    cv.line(cx-6, 22, cx, 26, GL);
    cv.line(cx+6, 22, cx, 26, GL);
  }

  // ── [1] Speech Bubbles (Rumor Chain) ─────────────────────────────────────
  {
    const dx = ox[1];
    // Large bubble (left)
    cv.ellipse(dx+12, 13, 9, 7, K);
    cv.ellipse(dx+12, 13, 8, 6, PL);
    // Tail for large bubble
    cv.poly([[dx+7,19],[dx+5,25],[dx+12,20]], K);
    cv.poly([[dx+7,19],[dx+6,23],[dx+11,20]], PL);
    // Dots inside large bubble
    cv.circle(dx+9, 13, 1, K);
    cv.circle(dx+12, 13, 1, K);
    cv.circle(dx+15, 13, 1, K);
    // Small bubble (right)
    cv.ellipse(dx+22, 9, 7, 5, K);
    cv.ellipse(dx+22, 9, 6, 4, CR);
    // Tail for small bubble
    cv.poly([[dx+17,13],[dx+15,18],[dx+20,14]], K);
    cv.poly([[dx+17,13],[dx+16,17],[dx+19,14]], CR);
    // Dots inside small bubble
    cv.circle(dx+20, 9, 1, K);
    cv.circle(dx+23, 9, 1, K);
    // Chain link between bubbles
    cv.circle(dx+16, 19, 2, K);
    cv.circle(dx+16, 19, 1, GM);
  }

  // ── [2] Banner / Flag (Faction Influence) ────────────────────────────────
  {
    const dx = ox[2];
    // Pole
    cv.rect(dx+7, 3, 3, 27, K);
    cv.rect(dx+8, 4, 1, 25, BR);
    // Gold finial at top
    cv.circle(dx+8, 4, 3, GL);
    cv.set(dx+8, 4, GD);
    // Flag body (rectangle, slight wave: offset every 3rd row)
    for (let y = 6; y <= 20; y++) {
      const wave = Math.round(Math.sin((y-6)/3) * 1.5);
      const x0 = dx+10+wave, x1 = dx+27+wave;
      cv.line(x0, y, x1, y, (y < 10 || y > 17) ? PL : GL);
      cv.set(x0, y, K); cv.set(x1, y, K);
    }
    cv.line(dx+10, 6, dx+27, 6, K);
    cv.line(dx+10, 20, dx+27, 20, K);
    // Stripe dividers
    cv.line(dx+10, 10, dx+27, 10, K);
    cv.line(dx+10, 14, dx+27, 14, K);
    // Heraldic cross on center stripe
    cv.rect(dx+17, 11, 3, 7, GM);
    cv.rect(dx+14, 14, 9, 3, GM);
  }

  // ── [3] Scroll (Intel) ────────────────────────────────────────────────────
  {
    const dx = ox[3];
    // Main scroll body
    cv.rect(dx+8, 8, 16, 18, K);
    cv.rect(dx+9, 9, 14, 16, CR);
    // Text lines on scroll
    cv.rect(dx+11, 12, 10, 1, PD);
    cv.rect(dx+11, 15, 10, 1, PD);
    cv.rect(dx+11, 18, 8, 1, PD);
    cv.rect(dx+11, 21, 6, 1, PD);
    // Top roller
    cv.rect(dx+6, 6, 20, 4, K);
    cv.rect(dx+7, 7, 18, 2, PM);
    cv.circle(dx+6, 8, 3, K); cv.circle(dx+6, 8, 2, PD);
    cv.circle(dx+26, 8, 3, K); cv.circle(dx+26, 8, 2, PD);
    // Bottom roller
    cv.rect(dx+6, 24, 20, 4, K);
    cv.rect(dx+7, 25, 18, 2, PM);
    cv.circle(dx+6, 26, 3, K); cv.circle(dx+6, 26, 2, PD);
    cv.circle(dx+26, 26, 3, K); cv.circle(dx+26, 26, 2, PD);
    // Red seal ribbon
    cv.rect(dx+13, 4, 6, 6, RD);
    cv.set(dx+16, 5, [200, 60, 40, 255]);
  }

  // ── [4] Coin (Resource) ───────────────────────────────────────────────────
  {
    const dx = ox[4];
    cv.circle(dx+16, 16, 12, K);
    cv.circle(dx+16, 16, 11, GL);
    cv.circle(dx+16, 16, 9, GM);
    // Crown embossed in center
    // Crown base
    cv.rect(dx+11, 17, 10, 3, GD);
    // Crown points (3 spires)
    cv.rect(dx+11, 13, 2, 5, GD);
    cv.rect(dx+15, 12, 2, 6, GD);
    cv.rect(dx+19, 13, 2, 5, GD);
    // Cross-hatch sheen on coin edge
    for (let a = 0; a < 360; a += 30) {
      const rad = a * Math.PI / 180;
      const ex = Math.round(dx+16 + 10.5 * Math.cos(rad));
      const ey = Math.round(16 + 10.5 * Math.sin(rad));
      cv.set(ex, ey, WH);
    }
  }

  cv.save(path.join(OUT, 'ui_milestone_icons.png'));
}

// ═══════════════════════════════════════════════════════════════════════════════
// 3.  DAILY PRIORITY ICONS  (192 × 32 — six 32×32 icons)
//     [0] Spread Rumors   [1] Gather Intel   [2] Build Alliances
//     [3] Sabotage        [4] Lay Low        [5] Investigate
// ═══════════════════════════════════════════════════════════════════════════════

function genDailyIcons() {
  const cv = makeCanvas(192, 32);
  const ox = [0, 32, 64, 96, 128, 160];

  // ── [0] Spread Rumors — speech bubble with wavy text ─────────────────────
  {
    const dx = ox[0];
    cv.ellipse(dx+16, 14, 11, 9, K);
    cv.ellipse(dx+16, 14, 10, 8, PL);
    // Tail
    cv.poly([[dx+10,21],[dx+7,28],[dx+15,22]], K);
    cv.poly([[dx+10,21],[dx+8,26],[dx+14,22]], PL);
    // Wavy text lines
    for (let row = 0; row < 3; row++) {
      const y = 11 + row*3;
      for (let x = dx+7; x <= dx+25; x++) {
        const wy = y + (((x-dx) & 3) < 2 ? 0 : 1);
        cv.set(x, wy, K);
      }
    }
  }

  // ── [1] Gather Intel — magnifying glass ──────────────────────────────────
  {
    const dx = ox[1];
    // Lens
    cv.ring(dx+14, 14, 9, 2, K);
    cv.circle(dx+14, 14, 7, [180, 220, 255, 180]);
    cv.ring(dx+14, 14, 7, 1, K);
    // Cross-hair inside lens
    cv.line(dx+14, 7, dx+14, 21, K);
    cv.line(dx+7, 14, dx+21, 14, K);
    // Handle
    cv.line(dx+21, 21, dx+27, 27, K);
    cv.line(dx+22, 21, dx+28, 27, K);
    cv.line(dx+21, 21, dx+28, 27, BR);
  }

  // ── [2] Build Alliances — two overlapping shields ─────────────────────────
  {
    const dx = ox[2];
    // Left shield (parchment)
    function miniShield(sx, col1, col2) {
      for (let y = 8; y <= 24; y++) {
        let hw;
        if (y <= 14) hw = 6;
        else hw = Math.round(6 * (1-(y-14)/10));
        if (hw <= 0) { cv.set(sx, y, col1); continue; }
        for (let x = sx-hw; x <= sx+hw; x++) cv.set(x, y, col1);
      }
      // Outline
      for (let y = 7; y <= 25; y++) {
        let hw;
        if (y <= 14) hw = 7;
        else hw = Math.round(7 * (1-(y-14)/11));
        if (hw <= 0) { cv.set(sx, y, col2); continue; }
        cv.set(sx-hw, y, col2); cv.set(sx+hw, y, col2);
      }
      cv.line(sx-7, 7, sx+7, 7, col2);
      // Diagonal stripe device
      cv.line(sx-3, 10, sx+3, 18, col2);
    }
    miniShield(dx+12, PL, K);
    miniShield(dx+20, CR, K);
    // Clasping hands symbol in overlap area
    cv.rect(dx+14, 15, 4, 3, GL);
    cv.rect(dx+15, 13, 2, 7, GL);
  }

  // ── [3] Sabotage — lit torch ──────────────────────────────────────────────
  {
    const dx = ox[3];
    // Torch handle
    cv.rect(dx+14, 18, 4, 12, K);
    cv.rect(dx+15, 19, 2, 10, BR);
    // Torch head (wider)
    cv.rect(dx+12, 13, 8, 7, K);
    cv.rect(dx+13, 14, 6, 5, [180, 120, 60, 255]);
    // Binding tape
    cv.rect(dx+12, 17, 8, 2, PD);
    // Flame
    // Outer flame (orange)
    cv.poly([[dx+16,3],[dx+11,14],[dx+21,14]], [240, 140, 20, 255]);
    // Inner flame (yellow)
    cv.poly([[dx+16,6],[dx+13,14],[dx+19,14]], [255, 220, 60, 255]);
    // Core white
    cv.poly([[dx+16,9],[dx+14,14],[dx+18,14]], [255, 255, 200, 255]);
    // Sparkle dots
    cv.set(dx+11, 6, GL);
    cv.set(dx+21, 7, GL);
    cv.set(dx+10, 10, [255,180,40,200]);
    cv.set(dx+22, 11, [255,180,40,200]);
  }

  // ── [4] Lay Low — hooded cloaked figure ──────────────────────────────────
  {
    const dx = ox[4];
    // Cloak outline (wide, floor-length)
    cv.poly([
      [dx+16,3],[dx+22,8],[dx+26,16],[dx+27,28],
      [dx+5,28],[dx+6,16],[dx+10,8]
    ], K);
    cv.poly([
      [dx+16,4],[dx+21,8],[dx+25,16],[dx+26,27],
      [dx+6,27],[dx+7,16],[dx+11,8]
    ], PD);
    // Hood shadow (darker interior)
    cv.poly([[dx+16,4],[dx+21,8],[dx+11,8]], PM);
    cv.ellipse(dx+16, 8, 5, 4, PD);
    cv.ellipse(dx+16, 8, 4, 3, K);
    // Dark face recess
    cv.ellipse(dx+16, 8, 3, 2, [16, 10, 6, 255]);
    // Eye glint
    cv.set(dx+15, 8, [255, 240, 180, 200]);
    cv.set(dx+17, 8, [255, 240, 180, 200]);
    // Clasp
    cv.circle(dx+16, 13, 2, GL);
    cv.set(dx+16, 13, GD);
  }

  // ── [5] Investigate — open eye ────────────────────────────────────────────
  {
    const dx = ox[5];
    // Eyelid curves (almond shape)
    const ex = dx+16, ey = 16;
    cv.ellipse(ex, ey, 13, 7, K);
    cv.ellipse(ex, ey, 12, 6, CR);
    // Iris
    cv.circle(ex, ey, 5, NV);
    cv.circle(ex, ey, 5, K); // ring
    cv.circle(ex, ey, 4, NV);
    // Pupil
    cv.circle(ex, ey, 2, K);
    // Eye-shine
    cv.set(ex-1, ey-1, WH);
    // Upper lash hint
    cv.line(ex-8, ey-3, ex-5, ey-5, K);
    cv.line(ex+5, ey-5, ex+8, ey-3, K);
    cv.line(ex-2, ey-6, ex-1, ey-7, K);
    cv.line(ex+1, ey-6, ex+2, ey-7, K);
    // Brow
    cv.line(ex-10, ey-9, ex+10, ey-9, PD);
    cv.line(ex-9, ey-10, ex+9, ey-10, PD);
  }

  cv.save(path.join(OUT, 'ui_daily_icons.png'));
}

// ═══════════════════════════════════════════════════════════════════════════════
// 4.  CELEBRATION PARTICLES  (64 × 64)
//     Gold sparkles + small stars scattered on transparent bg
// ═══════════════════════════════════════════════════════════════════════════════

function genCelebrationParticles() {
  const cv = makeCanvas(64, 64);
  // Transparent base — we just draw sparkles

  // Draw a 4-point star sparkle at (cx,cy) with given arm length and color
  function sparkle(cx, cy, r, col, col2) {
    // Long axes
    cv.line(cx-r, cy, cx+r, cy, col);
    cv.line(cx, cy-r, cx, cy+r, col);
    // Short diagonal axes (half length)
    const d = Math.round(r * 0.55);
    cv.line(cx-d, cy-d, cx+d, cy+d, col2);
    cv.line(cx-d, cy+d, cx+d, cy-d, col2);
    cv.set(cx, cy, WH); // bright center
  }

  function dot(cx, cy, col) {
    cv.circle(cx, cy, 2, col);
    cv.set(cx, cy, WH);
  }

  // Large sparkles
  sparkle(10, 10, 6, GL, GM);
  sparkle(54, 8,  5, GL, GM);
  sparkle(8,  54, 5, GL, GM);
  sparkle(56, 52, 6, GL, GM);
  sparkle(32, 32, 7, GL, GM); // center
  sparkle(18, 46, 4, GL, GD);
  sparkle(46, 18, 4, GL, GD);

  // Small dots scattered
  const dotPositions = [
    [24,8],[40,14],[14,24],[50,30],[22,52],[42,56],[6,36],[58,40],
    [30,18],[36,44],[16,14],[48,48],[28,56],[52,22]
  ];
  for (const [x,y] of dotPositions) {
    dot(x, y, (x+y)%3===0 ? WH : GL);
  }

  // Confetti rectangles (tilted via individual pixels)
  const confettiColors = [GL, RD, NV, GN, CR, GM];
  const confettiDots = [
    [20,20],[44,12],[12,40],[52,44],[36,28],[28,40],[16,56],[48,6]
  ];
  confettiDots.forEach(([cx,cy], i) => {
    const col = confettiColors[i % confettiColors.length];
    cv.rect(cx-2, cy-1, 4, 2, col);
    cv.set(cx-2, cy-1, K); cv.set(cx+1, cy, K);
  });

  cv.save(path.join(OUT, 'ui_celebration_particles.png'));
}

// ═══════════════════════════════════════════════════════════════════════════════
// 5.  RUN ALL
// ═══════════════════════════════════════════════════════════════════════════════

console.log('Generating Rumor Mill art assets (SPA-712)...');
genMilestonePopup();
genMilestoneIcons();
genDailyIcons();
genCelebrationParticles();
console.log('Done.');
