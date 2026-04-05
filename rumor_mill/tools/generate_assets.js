#!/usr/bin/env node
/**
 * generate_assets.js — Art Pass 9 pixel-art generator for Rumor Mill (SPA-507)
 *
 * Produces all textures needed:
 *   assets/textures/tiles_ground.png      (768×32 — 12 ground variants: void, grass_base, grass_dark, grass_sparse, grass_dense, grass_floral, dirt_muddy, dirt_packed, grass_dirt_blend, stone_smooth, stone_cracked, stone_cobble)
 *   assets/textures/tiles_road_dirt.png   (64×32)
 *   assets/textures/tiles_road_stone.png  (64×32)
 *   assets/textures/tiles_buildings.png   (640×64 — 10 building types)
 *   assets/textures/npc_sprites.png       (960×864 — 15 frames × 9 archetypes, 64×96 per frame)  SPA-585
 *                                           row 0 = merchant, 1 = noble, 2 = clergy
 *                                           row 3 = guard,    4 = commoner
 *                                           row 5 = tavern_staff (apron/kerchief)
 *                                           row 6 = scholar     (ink-blue robe/scroll)
 *                                           row 7 = elder       (grey robe/staff)
 *                                           row 8 = spy         (dark hooded cloak)
 *                                           cols 0-1=idle_S, 2-4=walk_S, 5-6=idle_N, 7-9=walk_N,
 *                                           10-11=idle_E, 12-14=walk_E  (W=flip_h of E)
 *   assets/textures/ui_parchment.png      (48×48 — 9-slice parchment border tile)
 *   assets/textures/ui_faction_badges.png (72×24 — 3 × 24px faction badges)
 *   assets/textures/ui_claim_icons.png    (160×32 — 5 × 32px claim-type icons)  ← SPA-523
 *   assets/textures/ui_npc_portraits.png  (320×240 — 5 cols × 3 rows of 64×80 portraits)
 *                                           col 0=merchant, 1=noble, 2=clergy, 3=guard, 4=commoner
 *                                           row 0=male base, 1=female base, 2=elder/leader
 *   assets/textures/ui_state_icons.png    (144×16 — 9 × 16px rumor-state icons)
 *                                           col 0=UNAWARE, 1=EVALUATING, 2=BELIEVE, 3=REJECTING,
 *                                               4=SPREAD, 5=ACT, 6=CONTRADICTED, 7=EXPIRED, 8=DEFENDING
 *
 * Run from project root:  node tools/generate_assets.js
 */

'use strict';
const zlib = require('zlib');
const fs   = require('fs');
const path = require('path');

// ─── CRC32 ────────────────────────────────────────────────────────────────────
const crcTable = new Uint32Array(256);
for (let n = 0; n < 256; n++) {
  let c = n;
  for (let k = 0; k < 8; k++) c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
  crcTable[n] = c;
}
function crc32(buf) {
  let c = 0xFFFFFFFF;
  for (let i = 0; i < buf.length; i++) c = crcTable[(c ^ buf[i]) & 0xFF] ^ (c >>> 8);
  return (c ^ 0xFFFFFFFF) >>> 0;
}

// ─── PNG encoder ──────────────────────────────────────────────────────────────
function makePNG(w, h, rgba) {
  function chunk(type, data) {
    const tb  = Buffer.from(type, 'ascii');
    const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
    const cr  = Buffer.alloc(4); cr.writeUInt32BE(crc32(Buffer.concat([tb, data])));
    return Buffer.concat([len, tb, data, cr]);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; ihdr[9] = 6;                          // 8-bit RGBA

  const rowBytes = w * 4 + 1;
  const raw = Buffer.alloc(rowBytes * h);
  for (let y = 0; y < h; y++) {
    raw[y * rowBytes] = 0;                            // filter-none per row
    for (let x = 0; x < w; x++) {
      const s = (y * w + x) * 4, d = y * rowBytes + 1 + x * 4;
      raw[d] = rgba[s]; raw[d+1] = rgba[s+1]; raw[d+2] = rgba[s+2]; raw[d+3] = rgba[s+3];
    }
  }
  return Buffer.concat([
    Buffer.from([137,80,78,71,13,10,26,10]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 6 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

// ─── Canvas ───────────────────────────────────────────────────────────────────
function createCanvas(w, h) {
  const data = new Uint8Array(w * h * 4);   // RGBA, all transparent

  const sp = (x, y, r, g, b, a = 255) => {
    if (x < 0 || x >= w || y < 0 || y >= h) return;
    const i = (Math.round(y) * w + Math.round(x)) * 4;
    if (a === 255) { data[i]=r; data[i+1]=g; data[i+2]=b; data[i+3]=255; return; }
    const sa = a/255, da = data[i+3]/255, oa = sa + da*(1-sa);
    if (oa < 0.001) return;
    data[i]   = ((r*sa + data[i]  *da*(1-sa))/oa)|0;
    data[i+1] = ((g*sa + data[i+1]*da*(1-sa))/oa)|0;
    data[i+2] = ((b*sa + data[i+2]*da*(1-sa))/oa)|0;
    data[i+3] = (oa*255)|0;
  };

  const fillRect = (x0, y0, rw, rh, r, g, b, a=255) => {
    for (let y=y0; y<y0+rh; y++) for (let x=x0; x<x0+rw; x++) sp(x,y,r,g,b,a);
  };

  // Scanline fill of a polygon (pts = [[x,y], ...])
  const fillPoly = (pts, r, g, b, a=255) => {
    const ys = pts.map(p=>p[1]);
    let minY = Math.max(0, Math.floor(Math.min(...ys)));
    let maxY = Math.min(h-1, Math.ceil(Math.max(...ys)));
    const n = pts.length;
    for (let y=minY; y<=maxY; y++) {
      const xs = [];
      for (let i=0; i<n; i++) {
        const [x0,y0]=pts[i], [x1,y1]=pts[(i+1)%n];
        if ((y0<=y && y1>y)||(y1<=y && y0>y))
          xs.push(x0 + (y-y0)*(x1-x0)/(y1-y0));
      }
      xs.sort((a,b)=>a-b);
      for (let k=0; k<xs.length-1; k+=2)
        for (let x=Math.ceil(xs[k]); x<=Math.floor(xs[k+1]); x++) sp(x,y,r,g,b,a);
    }
  };

  // Bresenham line
  const line = (x0,y0,x1,y1,r,g,b,a=255) => {
    let dx=Math.abs(x1-x0), dy=Math.abs(y1-y0), sx=x0<x1?1:-1, sy=y0<y1?1:-1, err=dx-dy;
    x0=Math.round(x0); y0=Math.round(y0); x1=Math.round(x1); y1=Math.round(y1);
    while(true){ sp(x0,y0,r,g,b,a); if(x0===x1&&y0===y1) break;
      const e2=2*err; if(e2>-dy){err-=dy;x0+=sx;} if(e2<dx){err+=dx;y0+=sy;} }
  };

  // Dither noise inside a diamond (isometric tile)
  const isoNoise = (cx,cy,hw,hh,r,g,b,variance=14,density=0.18) => {
    for (let y=cy-hh; y<=cy+hh; y++) for (let x=cx-hw; x<=cx+hw; x++) {
      if (Math.abs(x-cx)/hw + Math.abs(y-cy)/hh > 1.0) continue;
      if (Math.random() < density) {
        const v = ((Math.random()-0.5)*variance)|0;
        sp(x,y, Math.min(255,Math.max(0,r+v)), Math.min(255,Math.max(0,g+v)), Math.min(255,Math.max(0,b+v)));
      }
    }
  };

  return { data, w, h, sp, fillRect, fillPoly, line, isoNoise, toPNG: ()=>makePNG(w,h,data) };
}

// ─── Nearest-neighbour upscale ───────────────────────────────────────────────
// Scales raw RGBA data from (srcW×srcH) to (dstW×dstH) using nearest-neighbour
// sampling.  Handles non-integer ratios (e.g. 1.5×, 2.67×).
function nearestNeighborScale(srcData, srcW, srcH, dstW, dstH) {
  const dst = new Uint8Array(dstW * dstH * 4);
  for (let dy = 0; dy < dstH; dy++) {
    const sy = Math.floor(dy * srcH / dstH);
    for (let dx = 0; dx < dstW; dx++) {
      const sx = Math.floor(dx * srcW / dstW);
      const si = (sy * srcW + sx) * 4;
      const di = (dy * dstW + dx) * 4;
      dst[di]   = srcData[si];
      dst[di+1] = srcData[si+1];
      dst[di+2] = srcData[si+2];
      dst[di+3] = srcData[si+3];
    }
  }
  return dst;
}

// ─── Palette ──────��───────────────────────────────────────────────────────────
//  Pentiment × Dwarf-Fortress: desaturated naturals, deep faction primaries.
const P = {
  VOID:         [12, 10, 20],
  GRASS_L:      [76,114, 60],
  GRASS_M:      [58, 92, 44],
  GRASS_D:      [42, 68, 30],
  DIRT_L:       [172,134, 76],
  DIRT_M:       [138,104, 54],
  DIRT_D:       [104, 76, 38],
  STONE_L:      [162,156,140],
  STONE_M:      [116,110, 96],
  STONE_D:      [ 80, 74, 62],
  WOOD_L:       [186,140, 82],
  WOOD_M:       [142, 98, 50],
  WOOD_D:       [ 96, 62, 26],
  THATCH_L:     [190,162, 90],
  THATCH_D:     [ 96, 76, 40],
  ROOF_TILE:    [152, 72, 50],
  ROOF_SLATE:   [ 76, 76, 90],
  PLASTER:      [222,202,162],
  MANOR_STONE:  [198,186,162],
  CHAPEL_STONE: [206,202,196],
  WATER_L:      [ 88,148,196],
  WATER_D:      [ 52, 98,150],
  FORGE:        [240,130, 44],
  CANVAS:       [200,150, 58],
  OUTLINE:      [ 28, 24, 20],
  SKIN:         [222,184,150],
  HAIR:         [ 60, 42, 28],
  MERCH_B:      [ 26, 62,118],
  MERCH_T:      [200,162, 46],
  NOBLE_B:      [108, 22, 42],
  NOBLE_T:      [180,180,194],
  CLERGY_B:     [228,222,204],
  CLERGY_T:     [ 30, 26, 30],
  FLAG_R:       [178, 38, 38],
  PARCH_L:      [228,210,168],
  PARCH_M:      [200,178,128],
  PARCH_D:      [152,124, 78],
  INK:          [ 44, 34, 22],
  SKIN_SH:      [196,156,122],   // skin shadow / nose tone
  SKIN_HI:      [240,210,180],   // skin highlight (cheek/brow catch-light)
};
const c = P; // shorthand

// ─── Isometric helpers ────────────────────────────────────────────────────────
// Fill an isometric diamond, optionally offset into a canvas tile column.
function fillIso(cv, r, g, b, a=255, cx=32, cy=16, hw=31, hh=15) {
  for (let y=cy-hh; y<=cy+hh; y++) {
    for (let x=cx-hw; x<=cx+hw; x++) {
      if (Math.abs(x-cx)/hw + Math.abs(y-cy)/hh <= 1.02)
        cv.sp(x, y, r, g, b, a);
    }
  }
}

function outlineIso(cv, r, g, b, cx=32, cy=16, hw=31, hh=15) {
  cv.line(cx-hw, cy, cx, cy-hh, r, g, b);
  cv.line(cx, cy-hh, cx+hw, cy, r, g, b);
  cv.line(cx+hw, cy, cx, cy+hh, r, g, b);
  cv.line(cx, cy+hh, cx-hw, cy, r, g, b);
}

// ═══════════════════════════════════════════════════════════════════════════════
// GROUND TILES  (tiles_ground.png — 768×32, twelve 64×32 isometric tiles)
//   col 0 = void           col 1 = grass           col 2 = grass_dark
//   col 3 = grass_sparse   col 4 = grass_dense      col 5 = grass_floral
//   col 6 = dirt_muddy     col 7 = dirt_packed      col 8 = grass_dirt_blend
//   col 9 = stone_smooth   col 10 = stone_cracked   col 11 = stone_cobble (SPA-551)
// ═══════════════════════════════════════════════════════════════════════════════
function makeGroundTiles() {
  const cv = createCanvas(768, 32);

  // ── tile 0: void — very dark, just a subtle diamond outline ──────────────
  // (left transparent so Godot shows nothing)

  // ── tile 1: grass ──────────────────────────────────────────────────────────
  {
    const ox = 64, cx = ox+32, cy = 16;
    fillIso(cv, ...c.GRASS_M, 255, cx, cy);
    cv.isoNoise(cx, cy, 31, 15, ...c.GRASS_L, 10, 0.20);
    cv.isoNoise(cx, cy, 31, 15, ...c.GRASS_D, 8,  0.12);
    // additional fine-grain noise pass for depth
    cv.isoNoise(cx, cy, 31, 15, ...c.GRASS_L, 5, 0.09);
    cv.isoNoise(cx, cy, 31, 15, ...c.GRASS_M, 4, 0.07);
    // primary crosshatch-pattern (Pentiment look, NW–SE diagonal)
    for (let y=2; y<30; y+=4) {
      for (let x=ox+2; x<ox+62; x+=4) {
        if (Math.abs(x-cx)/31 + Math.abs(y-cy)/15 < 0.90) {
          cv.sp(x, y, ...c.GRASS_D, 80);
        }
      }
    }
    // secondary perpendicular crosshatch (NE–SW, offset by half-step)
    for (let y=4; y<30; y+=4) {
      for (let x=ox+4; x<ox+62; x+=4) {
        if (Math.abs(x-cx)/31 + Math.abs(y-cy)/15 < 0.86) {
          cv.sp(x, y, ...c.GRASS_L, 45);
        }
      }
    }
    outlineIso(cv, ...c.GRASS_D, cx, cy);
  }

  // ── tile 2: dark grass (shadow variant used for building footprints) ────────
  {
    const ox = 128, cx = ox+32, cy = 16;
    fillIso(cv, ...c.GRASS_D, 255, cx, cy);
    cv.isoNoise(cx, cy, 31, 15, ...c.GRASS_M, 6, 0.12);
    outlineIso(cv, 28, 48, 18, cx, cy);
  }

  // ── tile 3: grass_sparse (lighter, fewer noise dots, pale patches) ───────────
  {
    const ox = 192, cx = ox+32, cy = 16;
    fillIso(cv, ...c.GRASS_L, 255, cx, cy);
    cv.isoNoise(cx, cy, 31, 15, ...c.GRASS_M, 8, 0.10);
    cv.isoNoise(cx, cy, 31, 15, ...c.GRASS_D, 6, 0.05);
    for (let y=3; y<30; y+=6) {
      for (let x=ox+3; x<ox+62; x+=6) {
        if (Math.abs(x-cx)/31 + Math.abs(y-cy)/15 < 0.88) {
          cv.sp(x, y, ...c.GRASS_M, 60);
        }
      }
    }
    outlineIso(cv, ...c.GRASS_M, cx, cy);
  }

  // ── tile 4: grass_dense (darker, denser crosshatch) ──────────────────────────
  {
    const ox = 256, cx = ox+32, cy = 16;
    fillIso(cv, ...c.GRASS_D, 255, cx, cy);
    cv.isoNoise(cx, cy, 31, 15, ...c.GRASS_M, 12, 0.28);
    cv.isoNoise(cx, cy, 31, 15, ...c.GRASS_D, 10, 0.20);
    cv.isoNoise(cx, cy, 31, 15, ...c.GRASS_L,  6, 0.08);
    for (let y=2; y<30; y+=3) {
      for (let x=ox+2; x<ox+62; x+=3) {
        if (Math.abs(x-cx)/31 + Math.abs(y-cy)/15 < 0.90) {
          cv.sp(x, y, ...c.GRASS_D, 90);
        }
      }
    }
    outlineIso(cv, 28, 48, 18, cx, cy);
  }

  // ── tile 5: grass_floral (GRASS_M base + tiny coloured flower specks) ────────
  {
    const ox = 320, cx = ox+32, cy = 16;
    fillIso(cv, ...c.GRASS_M, 255, cx, cy);
    cv.isoNoise(cx, cy, 31, 15, ...c.GRASS_L, 10, 0.18);
    cv.isoNoise(cx, cy, 31, 15, ...c.GRASS_D,  8, 0.10);
    const floralPositions = [
      [cx-14, cy-1], [cx-8, cy+4], [cx+2, cy-5],
      [cx+12, cy+1], [cx-2, cy+6], [cx+8, cy-3],
      [cx-18, cy+2], [cx+16, cy-2],
    ];
    const floralColors = [
      c.FLAG_R, c.CANVAS, c.FLAG_R, c.CANVAS,
      [220,180,240], c.FLAG_R, c.CANVAS, [220,180,240],
    ];
    for (let fi=0; fi<floralPositions.length; fi++) {
      const [fx, fy] = floralPositions[fi];
      if (Math.abs(fx-cx)/31 + Math.abs(fy-cy)/15 > 0.88) continue;
      cv.sp(fx,   fy, ...floralColors[fi], 220);
      cv.sp(fx-1, fy, ...floralColors[fi], 130);
      cv.sp(fx, fy-1, ...floralColors[fi], 130);
    }
    outlineIso(cv, ...c.GRASS_D, cx, cy);
  }

  // ── tile 6: dirt_muddy (DIRT_D base, puddle-like wet look) ───────────────────
  {
    const ox = 384, cx = ox+32, cy = 16;
    fillIso(cv, ...c.DIRT_D, 255, cx, cy);
    cv.isoNoise(cx, cy, 31, 15, ...c.DIRT_M, 10, 0.14);
    const puddles = [[cx-10, cy-2, 8, 3], [cx+8, cy+3, 6, 2], [cx-2, cy+5, 5, 2]];
    for (const [px, py, phw, phh] of puddles) {
      for (let py2=py-phh; py2<=py+phh; py2++) {
        for (let px2=px-phw; px2<=px+phw; px2++) {
          if (Math.abs(px2-px)/phw + Math.abs(py2-py)/phh <= 1.0 &&
              Math.abs(px2-cx)/31  + Math.abs(py2-cy)/15  <= 0.95) {
            cv.sp(px2, py2, ...c.WATER_D, 160);
          }
        }
      }
      cv.sp(px, py-1, ...c.WATER_L, 100);
    }
    cv.line(cx-6, cy-6, cx-2, cy-3, ...c.DIRT_D, 180);
    cv.line(cx+4, cy+1,  cx+8, cy+5, ...c.DIRT_D, 180);
    // hoof-print impressions near building entrances (SPA-595)
    for (const [hx, hy] of [[cx-8, cy+3], [cx-3, cy-7], [cx+12, cy-2]]) {
      if (Math.abs(hx-cx)/31 + Math.abs(hy-cy)/15 > 0.88) continue;
      cv.sp(hx,   hy,   ...c.DIRT_D, 140);
      cv.sp(hx+1, hy,   ...c.DIRT_D, 100);
      cv.sp(hx,   hy+1, ...c.DIRT_D, 80);
    }
    // shimmer catch-lights on puddle surfaces
    cv.sp(cx-10, cy-3, ...c.WATER_L, 130);
    cv.sp(cx+7,  cy+2, ...c.WATER_L, 100);
    cv.sp(cx-3,  cy+4, ...c.WATER_L, 80);
    outlineIso(cv, ...c.DIRT_D, cx, cy);
  }

  // ── tile 7: dirt_packed (DIRT_L base, smooth compressed texture) ─────────────
  {
    const ox = 448, cx = ox+32, cy = 16;
    fillIso(cv, ...c.DIRT_L, 255, cx, cy);
    cv.isoNoise(cx, cy, 31, 15, ...c.DIRT_M, 8, 0.07);
    cv.isoNoise(cx, cy, 31, 15, ...c.DIRT_L, 5, 0.05);
    for (let y=cy-10; y<=cy+10; y+=3) {
      for (let x=cx-28; x<=cx+28; x++) {
        if (Math.abs(x-cx)/31 + Math.abs(y-cy)/15 < 0.85) {
          cv.sp(x, y, ...c.DIRT_M, 25);
        }
      }
    }
    // worn path: parallel compression grooves along walking line (SPA-595)
    cv.line(cx-20, cy-3, cx+18, cy+3, ...c.DIRT_M, 45);
    cv.line(cx-20, cy+1, cx+18, cy+7, ...c.DIRT_M, 35);
    // scattered pebbles kicked to path edges
    for (const [px, py] of [[cx-14, cy-6], [cx+8, cy-8], [cx+18, cy+2], [cx-4, cy+7]]) {
      if (Math.abs(px-cx)/31 + Math.abs(py-cy)/15 > 0.90) continue;
      cv.sp(px, py, ...c.STONE_M, 170);
      cv.sp(px+1, py+1, ...c.STONE_D, 70);
    }
    // foot-compression impressions (oval depressions)
    cv.sp(cx+4, cy-4, ...c.DIRT_M, 110);
    cv.sp(cx+5, cy-4, ...c.DIRT_M, 75);
    cv.sp(cx-12, cy+4, ...c.DIRT_M, 90);
    cv.sp(cx-11, cy+4, ...c.DIRT_M, 60);
    outlineIso(cv, ...c.DIRT_M, cx, cy);
  }

  // ── tile 8: grass_dirt_blend (organic jagged edge: grass left, dirt right) ────
  {
    const ox = 512, cx = ox+32, cy = 16;
    // Build a per-row boundary that wanders ±6px around centre for organic look.
    // Uses a deterministic pseudo-random walk seeded by row index.
    const boundary = [];
    let bx = cx;
    for (let y=0; y<32; y++) {
      // hash-based nudge: deterministic but irregular
      bx += ((y*17+13) % 7) - 3;
      bx = Math.max(cx-10, Math.min(cx+10, bx));
      boundary[y] = bx;
    }
    for (let y=0; y<32; y++) {
      for (let x=ox; x<ox+64; x++) {
        const lx = x - cx, ly = y - cy;
        if (Math.abs(lx)/31 + Math.abs(ly)/15 > 1.0) continue;
        if (x < boundary[y]) {
          cv.sp(x, y, ...c.GRASS_M);
        } else {
          cv.sp(x, y, ...c.DIRT_M);
        }
      }
    }
    // Soft blend strip — 3px feather around the boundary edge
    for (let y=0; y<32; y++) {
      for (let d=-2; d<=2; d++) {
        const bx2 = boundary[y] + d;
        const ly = y - cy;
        if (Math.abs(bx2-cx)/31 + Math.abs(ly)/15 > 0.98) continue;
        if (d === 0) {
          // blend pixel — average of the two
          const r = (c.GRASS_M[0] + c.DIRT_M[0]) >> 1;
          const g2 = (c.GRASS_M[1] + c.DIRT_M[1]) >> 1;
          const b2 = (c.GRASS_M[2] + c.DIRT_M[2]) >> 1;
          cv.sp(bx2, y, r, g2, b2);
        } else if (d < 0) {
          cv.sp(bx2, y, ...c.GRASS_M);
          if (d === -1) cv.sp(bx2, y, ...c.DIRT_M, 60);  // slight dirt bleed
        } else {
          cv.sp(bx2, y, ...c.DIRT_M);
          if (d ===  1) cv.sp(bx2, y, ...c.GRASS_M, 55);  // slight grass bleed
        }
      }
    }
    cv.isoNoise(cx, cy, 31, 15, ...c.GRASS_L, 10, 0.12);
    cv.isoNoise(cx, cy, 31, 15, ...c.DIRT_L,  10, 0.10);
    // micro grass tufts on grass side; erosion pits on dirt side (SPA-595)
    for (const [tx, ty] of [[cx-22, cy-1], [cx-16, cy+4], [cx-9, cy-5]]) {
      if (Math.abs(tx-cx)/31 + Math.abs(ty-cy)/15 > 0.88) continue;
      cv.sp(tx,   ty-1, ...c.GRASS_L, 200);
      cv.sp(tx-1, ty,   ...c.GRASS_D, 120);
    }
    cv.sp(cx+6,  cy-3, ...c.DIRT_D, 120);
    cv.sp(cx+14, cy+2, ...c.DIRT_D, 90);
    outlineIso(cv, ...c.GRASS_D, cx, cy);
  }

  // ── tile 9: stone_smooth (SPA-551) — dressed stone slabs, courtyard feel ────
  {
    const ox = 576, cx = ox+32, cy = 16;
    fillIso(cv, ...c.STONE_M, 255, cx, cy);
    cv.isoNoise(cx, cy, 31, 15, ...c.STONE_L, 10, 0.18);
    cv.isoNoise(cx, cy, 31, 15, ...c.STONE_D,  6, 0.10);
    // horizontal slab seam
    cv.line(cx-18, cy-6, cx+18, cy+6, ...c.STONE_D, 60);
    // vertical seams suggesting individual blocks
    cv.line(cx-8,  cy-12, cx-8,  cy+4, ...c.STONE_D, 40);
    cv.line(cx+10, cy-11, cx+10, cy+4, ...c.STONE_D, 40);
    // chip highlights near seam intersections
    cv.sp(cx-14, cy-4, ...c.STONE_L, 70);
    cv.sp(cx+6,  cy-7, ...c.STONE_L, 60);
    cv.sp(cx+12, cy+2, ...c.STONE_L, 50);
    // additional slab-edge catch-lights and polish glint (SPA-595)
    cv.sp(cx+4,  cy-9, ...c.STONE_L, 80);
    cv.sp(cx-16, cy-2, ...c.STONE_L, 60);
    cv.sp(cx+18, cy+1, ...c.STONE_L, 55);
    cv.line(cx-6, cy-8, cx+6, cy-2, ...c.STONE_L, 28);
    outlineIso(cv, ...c.STONE_D, cx, cy);
  }

  // ── tile 10: stone_cracked (SPA-551) — weathered stone, diagonal crack network
  {
    const ox = 640, cx = ox+32, cy = 16;
    fillIso(cv, ...c.STONE_M, 255, cx, cy);
    cv.isoNoise(cx, cy, 31, 15, ...c.STONE_L, 8, 0.12);
    cv.isoNoise(cx, cy, 31, 15, ...c.STONE_D, 8, 0.14);
    // main diagonal crack + branch
    cv.line(cx+2,  cy-13, cx-9,  cy+2,  ...c.STONE_D, 210);
    cv.line(cx-9,  cy+2,  cx-15, cy+8,  ...c.STONE_D, 170);
    cv.line(cx+2,  cy-13, cx+8,  cy-5,  ...c.STONE_D, 185);
    cv.line(cx+13, cy-1,  cx+6,  cy+9,  ...c.STONE_D, 155);
    // highlight edge of each crack (one-pixel offset, lighter)
    cv.line(cx+3,  cy-13, cx-8,  cy+2,  ...c.STONE_L, 80);
    cv.line(cx+14, cy-1,  cx+7,  cy+9,  ...c.STONE_L, 60);
    // weathering chips
    cv.sp(cx-5, cy-8, ...c.STONE_L, 130);
    cv.sp(cx+9, cy-4, ...c.STONE_D, 110);
    // additional crack branches + spall chips (SPA-595)
    cv.line(cx-2, cy-3,  cx-8, cy+1,  ...c.STONE_D, 155);
    cv.line(cx+6, cy-3,  cx+10, cy+3, ...c.STONE_D, 125);
    cv.sp(cx-10, cy+3, ...c.STONE_D, 150);
    cv.sp(cx-7,  cy-4, ...c.STONE_D, 120);
    cv.sp(cx+4,  cy+6, ...c.STONE_D, 110);
    outlineIso(cv, ...c.STONE_D, cx, cy);
  }

  // ── tile 11: stone_cobble (SPA-551) — cobblestone paving, STONE_D mortar gaps
  {
    const ox = 704, cx = ox+32, cy = 16;
    fillIso(cv, ...c.STONE_D, 255, cx, cy);   // mortar/gap base
    // individual cobblestones as small iso diamonds
    const cobbleDefs = [
      [-20, -6], [-8, -10], [4, -8], [17, -5],
      [-24,  0], [-12, -3], [0,  -1], [13, 1],
      [-17,  6], [-5,  4],  [7,  5], [19, 3],
    ];
    for (const [dx, dy] of cobbleDefs) {
      const ccx = cx+dx, ccy = cy+dy;
      if (Math.abs(ccx-cx)/31 + Math.abs(ccy-cy)/15 > 0.90) continue;
      for (let y2=ccy-3; y2<=ccy+3; y2++) {
        for (let x2=ccx-7; x2<=ccx+7; x2++) {
          if (Math.abs(x2-ccx)/7 + Math.abs(y2-ccy)/3 <= 0.95 &&
              Math.abs(x2-cx)/31 + Math.abs(y2-cy)/15 <= 0.96)
            cv.sp(x2, y2, ...c.STONE_M);
        }
      }
      // top-left catch-light on each cobble
      cv.sp(ccx-4, ccy-1, ...c.STONE_L, 160);
      cv.sp(ccx-2, ccy-2, ...c.STONE_L, 100);
    }
    // moss patches in mortar gaps — market cobblestone shows age (SPA-595)
    for (const [mx, my] of [[cx-19, cy-1], [cx-14, cy+3], [cx+4, cy+1], [cx+16, cy-3]]) {
      if (Math.abs(mx-cx)/31 + Math.abs(my-cy)/15 > 0.88) continue;
      cv.sp(mx, my, 58, 78, 38, 110);  // desaturated moss green in mortar
    }
    // deeper mortar shadow at cobble bases
    cv.sp(cx-6, cy-5, ...c.STONE_D, 175);
    cv.sp(cx+8, cy+1, ...c.STONE_D, 155);
    cv.sp(cx-2, cy+4, ...c.STONE_D, 140);
    outlineIso(cv, ...c.STONE_D, cx, cy);
  }

  return cv.toPNG();
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROAD DIRT (64×32)
// ═══════════════════════════════════════════════════════════════════════════════
function makeRoadDirt() {
  const cv = createCanvas(64, 32);
  fillIso(cv, ...c.DIRT_M, 255, 32, 16);
  cv.isoNoise(32, 16, 31, 15, ...c.DIRT_L, 14, 0.20);
  cv.isoNoise(32, 16, 31, 15, ...c.DIRT_D, 10, 0.14);

  // deep wheel-rut pair — shadow + highlight edge for 3D groove
  cv.line(18, 10, 42, 22, ...c.DIRT_D, 200);
  cv.line(19, 10, 43, 22, ...c.DIRT_D, 140);
  cv.line(20, 10, 44, 22, ...c.DIRT_L, 80);  // highlight rim
  cv.line(24, 13, 48, 25, ...c.DIRT_D, 180);
  cv.line(25, 13, 49, 25, ...c.DIRT_D, 110);
  cv.line(26, 13, 50, 25, ...c.DIRT_L, 60);  // highlight rim

  // dried mud crack network (thin DIRT_D lines radiating from rut centre)
  cv.line(28, 14, 24, 12, ...c.DIRT_D, 100);
  cv.line(32, 16, 30, 12, ...c.DIRT_D, 80);
  cv.line(36, 18, 38, 15, ...c.DIRT_D, 90);
  cv.line(28, 14, 29, 17, ...c.DIRT_D, 70);
  cv.line(34, 17, 33, 20, ...c.DIRT_D, 75);

  // scattered pebbles (STONE_M single pixels with STONE_D shadow)
  const pebbles = [[15,12],[39,9],[44,18],[22,20],[37,22],[12,17],[50,14]];
  for (const [px, py] of pebbles) {
    if (Math.abs(px-32)/31 + Math.abs(py-16)/15 > 0.90) continue;
    cv.sp(px, py, ...c.STONE_M);
    cv.sp(px+1, py+1, ...c.STONE_D, 80);
  }

  // footprint impressions — shallow oval depressions
  cv.sp(22, 17, ...c.DIRT_D, 120);
  cv.sp(23, 17, ...c.DIRT_D, 80);
  cv.sp(38, 12, ...c.DIRT_D, 100);
  cv.sp(39, 12, ...c.DIRT_D, 70);

  outlineIso(cv, ...c.DIRT_D, 32, 16);
  return cv.toPNG();
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROAD STONE (64×32)
// ═══════════════════════════════════════════════════════════════════════════════
function makeRoadStone() {
  const cv = createCanvas(64, 32);
  fillIso(cv, ...c.STONE_M, 255, 32, 16);
  // cobblestone grid pattern
  for (let y=2; y<30; y+=5) {
    for (let x=2; x<62; x+=8) {
      const jx = (y%10 < 5) ? x : x+4;
      if (Math.abs(jx-32)/31 + Math.abs(y-16)/15 < 0.88) {
        cv.fillRect(jx, y, 7, 4, ...c.STONE_L);
        cv.line(jx, y, jx+6, y, ...c.STONE_D);
        cv.line(jx, y, jx, y+3, ...c.STONE_D);
      }
    }
  }
  // per-cobble subtle tint variation (natural aged stone look)
  for (let y=2; y<30; y+=5) {
    for (let x=2; x<62; x+=8) {
      const jx = (y%10 < 5) ? x : x+4;
      if (Math.abs(jx-32)/31 + Math.abs(y-16)/15 < 0.85) {
        const v = ((jx*7 + y*13) % 3) - 1;
        if (v > 0) cv.fillRect(jx+1, y+1, 5, 2, ...c.STONE_L, 28);
        else if (v < 0) cv.fillRect(jx+1, y+1, 5, 2, ...c.STONE_D, 22);
      }
    }
  }
  cv.isoNoise(32, 16, 31, 15, ...c.STONE_L, 8, 0.08);

  // moss in mortar joints — GRASS_D dots at low alpha along mortar lines
  const mossSpots = [
    [14,7],[22,12],[36,7],[44,12],[20,17],[32,12],[28,22],[38,17],
    [16,22],[48,12],[10,17],[50,17],
  ];
  for (const [mx, my] of mossSpots) {
    if (Math.abs(mx-32)/31 + Math.abs(my-16)/15 > 0.82) continue;
    cv.sp(mx, my, ...c.GRASS_D, 90);
    cv.sp(mx+1, my, ...c.GRASS_D, 55);
  }

  // worn low-spot puddle (small WATER_D ellipse near centre)
  for (let py=-2; py<=2; py++) {
    for (let px=-4; px<=4; px++) {
      if (px*px/16 + py*py/4 <= 1.0)
        cv.sp(32+px, 18+py, ...c.WATER_D, 110);
    }
  }
  cv.sp(30, 17, ...c.WATER_L, 70);  // reflection catch-light

  // hairline crack on one cobble
  cv.line(38, 8, 41, 10, ...c.STONE_D, 140);
  cv.sp(40, 9, ...c.STONE_D, 100);

  outlineIso(cv, ...c.STONE_D, 32, 16);
  return cv.toPNG();
}

// ═══════════════════════════════════════════════════════════════════════════════
// BUILDING TILES (tiles_buildings.png — 1280×128, ten 128×128 tiles)
//
// Base art drawn at 64×64 per-tile, then upscaled 2× via nearest-neighbour.
// Unique silhouettes for Mill, Guard Post, Well, and Storage are drawn at
// full 128px resolution on top of the upscaled base.
// Each tile: bottom half (y64-127) = iso ground face; top (y0-63) = building.
// Tile indices match ATLAS_* constants in world.gd:
//   0=manor  1=tavern  2=chapel  3=market  4=well
//   5=blacksmith  6=mill  7=storage  8=guardpost  9=town_hall
// ═══════════════════════════════════════════════════════════════════════════════
function makeBuildingTiles(nightMode = false) {
  const cv = createCanvas(640, 64);

  // ── shared: paint iso ground face in bottom half of a tile column ──────────
  const groundFace = (col, r, g, b) => {
    const cx = col*64+32, cy = 48;
    fillIso(cv, r, g, b, 255, cx, cy, 31, 15);
    outlineIso(cv, ...c.STONE_D, cx, cy);
  };

  // ── shared: draw front wall (parallelogram on left face, isometric) ────────
  // left-face vertices (seen from south-east viewpoint):
  //   top-left=(cx-hw, cy-wallH), top-right=(cx, cy-wallH-hh),
  //   bot-right=(cx, cy-hh),      bot-left=(cx-hw, cy)
  const leftFace = (col, wallH, r, g, b) => {
    const cx=col*64+32, cy=32, hw=31, hh=15;
    cv.fillPoly([
      [cx-hw, cy-wallH], [cx, cy-wallH-hh],
      [cx,    cy-hh],    [cx-hw, cy],
    ], r, g, b);
  };

  // right-face vertices
  const rightFace = (col, wallH, r, g, b) => {
    const cx=col*64+32, cy=32, hw=31, hh=15;
    cv.fillPoly([
      [cx, cy-wallH-hh], [cx+hw, cy-wallH],
      [cx+hw, cy],        [cx, cy-hh],
    ], r, g, b);
  };

  // roof top face (flat iso diamond shifted up by wallH)
  const roofFace = (col, wallH, r, g, b) => {
    const cx=col*64+32, cy=32-wallH, hw=31, hh=15;
    fillIso(cv, r, g, b, 255, cx, cy, hw, hh);
    outlineIso(cv, ...c.OUTLINE, cx, cy, hw, hh);
  };

  // ── outline all wall edges ─────────────────────────────────────────────────
  const outlineWalls = (col, wallH) => {
    const cx=col*64+32, cy=32, hw=31, hh=15;
    const ol = c.OUTLINE;
    // left-face edges
    cv.line(cx-hw, cy-wallH, cx, cy-wallH-hh, ...ol);
    cv.line(cx, cy-wallH-hh, cx, cy-hh, ...ol);
    cv.line(cx-hw, cy-wallH, cx-hw, cy, ...ol);
    // right-face edges
    cv.line(cx, cy-wallH-hh, cx+hw, cy-wallH, ...ol);
    cv.line(cx+hw, cy-wallH, cx+hw, cy, ...ol);
    cv.line(cx+hw, cy, cx, cy-hh, ...ol);
    // bottom iso outline
    cv.line(cx-hw, cy, cx, cy+hh, ...ol);
    cv.line(cx, cy+hh, cx+hw, cy, ...ol);
  };

  // ────────────────────────────────────────────────────────────────────────────
  // 0: MANOR — limestone walls, slate roof, tallest noble residence (wallH=24)
  // ────────────────────────────────────────────────────────────────────────────
  {
    const col=0, wH=24;
    groundFace(col, ...c.MANOR_STONE);
    leftFace (col, wH, ...c.MANOR_STONE);
    rightFace(col, wH, 170,158,136);          // slightly darker right face
    roofFace (col, wH, ...c.ROOF_SLATE);
    outlineWalls(col, wH);
    const ox0=col*64;
    // arched window on left face (larger, with shutters)
    cv.fillRect(ox0+7, 32-wH+4, 7, 9, 80, 100, 140);
    cv.sp(ox0+10, 32-wH+4, 80, 100, 140);                 // arch cap pixel
    cv.line(ox0+7, 32-wH+4, ox0+13, 32-wH+4, ...c.MANOR_STONE);
    cv.line(ox0+7, 32-wH+4, ox0+7,  32-wH+12,...c.MANOR_STONE);
    cv.line(ox0+13,32-wH+4, ox0+13, 32-wH+12,...c.MANOR_STONE);
    cv.line(ox0+7, 32-wH+12,ox0+13, 32-wH+12,...c.MANOR_STONE);
    // shutter panels
    cv.fillRect(ox0+5, 32-wH+4, 2, 8, ...c.WOOD_M);
    cv.fillRect(ox0+15,32-wH+4, 2, 8, ...c.WOOD_M);
    // second smaller window higher up
    cv.fillRect(ox0+19, 32-wH+2, 5, 6, 80, 100, 140);
    cv.line(ox0+19, 32-wH+2, ox0+23, 32-wH+2, ...c.MANOR_STONE);
    // right face: arched entry door
    cv.fillRect(ox0+40, 32-wH+10, 8, 12, 50, 44, 60);
    cv.sp(ox0+44, 32-wH+10, 50, 44, 60);                  // arch cap
    cv.line(ox0+40, 32-wH+10, ox0+47, 32-wH+10, ...c.STONE_D);
    // ivy texture on left face lower section (scattered dark-green dots)
    for (let iy=32-wH+14; iy<32; iy+=3)
      for (let ix=ox0+2; ix<ox0+25; ix+=4)
        cv.sp(ix, iy, ...c.GRASS_D, 120);
    // stone course horizontal lines (masonry detail)
    for (let cy2=32-wH+5; cy2<32; cy2+=4)
      cv.line(ox0+1, cy2, ox0+30, cy2, ...c.STONE_D, 45);
    // stone course lines on right face
    for (let cy2=32-wH+5; cy2<32; cy2+=4)
      cv.line(ox0+33, cy2, ox0+62, cy2, ...c.STONE_D, 35);
    // corbel detail above arched window (small stone bracket)
    cv.fillRect(ox0+5, 32-wH+3, 3, 2, ...c.MANOR_STONE);
    cv.line(ox0+5, 32-wH+3, ox0+7, 32-wH+3, ...c.STONE_D);
    // flag on right face (taller pole, larger banner)
    cv.line(ox0+57, 32-wH-15, ox0+57, 32-wH, ...c.WOOD_M);
    cv.fillRect(ox0+48, 32-wH-15, 10, 7, ...c.FLAG_R);
    cv.line(ox0+48, 32-wH-15, ox0+57, 32-wH-15, ...c.OUTLINE);
    cv.line(ox0+48, 32-wH-8, ox0+57, 32-wH-8, ...c.OUTLINE);  // flag bottom edge
    // night: lit windows — warm amber glow replacing cold blue (SPA-523)
    // SPA-602: widened halos (r²≤16), wall shadow pass for depth
    if (nightMode) {
      // darken left-face wall at night (unlit stone reads darker)
      for (let ny = 32-wH+1; ny < 32; ny++)
        for (let nx = ox0+1; nx < ox0+30; nx++)
          cv.sp(nx, ny, 0, 0, 0, 22);
      // darken right-face wall
      for (let ny = 32-wH+1; ny < 32; ny++)
        for (let nx = ox0+33; nx < ox0+62; nx++)
          cv.sp(nx, ny, 0, 0, 0, 18);
      // arched window: bright amber fill + wide halo
      cv.fillRect(ox0+7,  32-wH+4, 7, 9, 235, 185, 70);
      for (let dy=-4; dy<=4; dy++) for (let dx=-4; dx<=4; dx++)
        if (dx*dx+dy*dy<=16)
          cv.sp(ox0+10+dx, 32-wH+8+dy, 255, 210, 80, Math.max(0, 55-(dx*dx+dy*dy)*3));
      // second window: amber fill + halo
      cv.fillRect(ox0+19, 32-wH+2, 5, 6, 235, 185, 70);
      for (let dy=-3; dy<=3; dy++) for (let dx=-3; dx<=3; dx++)
        if (dx*dx+dy*dy<=9)
          cv.sp(ox0+21+dx, 32-wH+5+dy, 255, 210, 80, Math.max(0, 42-(dx*dx+dy*dy)*5));
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 1: TAVERN — timber-frame plaster, thatch roof (wallH=18)
  // ────────────────────────────────────────────────────────────────────────────
  {
    const col=1, wH=18;
    groundFace(col, ...c.DIRT_M);
    leftFace (col, wH, ...c.PLASTER);
    rightFace(col, wH, 196,176,136);
    roofFace (col, wH, ...c.THATCH_L);
    // thatch texture lines on roof face
    const ox=col*64;
    for (let ty=2; ty<=8; ty+=2)
      cv.line(ox+32-2+ty, 32-wH-15+ty, ox+32+2+ty, 32-wH-13+ty, ...c.THATCH_D, 80);
    outlineWalls(col, wH);
    // timber beams on left face
    cv.line(ox+1,  32-wH, ox+1,  32,   ...c.WOOD_D);
    cv.line(ox+10, 32-wH, ox+10, 32,   ...c.WOOD_D);
    cv.line(ox+20, 32-wH, ox+20, 32,   ...c.WOOD_D);
    cv.line(ox+1,  32-wH+6, ox+20, 32-wH+6, ...c.WOOD_D);
    cv.line(ox+1,  32-wH+13, ox+20, 32-wH+13, ...c.WOOD_D);
    // window with shutter effect
    cv.fillRect(ox+12, 32-wH+2, 6, 5, 80, 100, 130);     // window pane
    cv.line(ox+12, 32-wH+2, ox+17, 32-wH+2, ...c.WOOD_D);
    cv.line(ox+12, 32-wH+7, ox+17, 32-wH+7, ...c.WOOD_D);
    cv.line(ox+12, 32-wH+2, ox+12, 32-wH+7, ...c.WOOD_D);
    cv.line(ox+17, 32-wH+2, ox+17, 32-wH+7, ...c.WOOD_D);
    cv.sp(ox+14, 32-wH+4, ...c.FORGE, 80);                // warm glow inside
    // arched door
    cv.fillRect(ox+4, 32-8, 6, 8, ...c.WOOD_D);
    cv.sp(ox+7, 32-8, ...c.WOOD_D);                       // arch cap
    // door handle
    cv.sp(ox+8, 32-4, ...c.STONE_L);
    // hanging tavern sign (bracket + board on right face)
    cv.line(ox+48, 32-wH+2, ox+54, 32-wH+2, ...c.WOOD_D); // bracket
    cv.line(ox+54, 32-wH+2, ox+54, 32-wH+8, ...c.WOOD_D); // chain
    cv.fillRect(ox+48, 32-wH+8, 10, 5, ...c.WOOD_M);      // sign board
    cv.sp(ox+50, 32-wH+10, ...c.MERCH_T, 160);            // mug icon on sign
    cv.sp(ox+52, 32-wH+10, ...c.MERCH_T, 120);
    cv.line(ox+48, 32-wH+8, ox+57, 32-wH+8, ...c.OUTLINE);
    cv.line(ox+48, 32-wH+13,ox+57, 32-wH+13,...c.OUTLINE);
    // lantern glow (brighter)
    cv.sp(ox+22, 32-wH+2, ...c.FORGE, 220);
    cv.sp(ox+21, 32-wH+2, ...c.FORGE, 130);
    cv.sp(ox+23, 32-wH+2, ...c.FORGE, 130);
    cv.sp(ox+22, 32-wH+1, 255,230,120, 100);
    // chimney stack on roof (left side, above thatch)
    cv.fillRect(ox+6, 32-wH-8, 5, 8, ...c.STONE_M);
    cv.line(ox+5, 32-wH-8, ox+11, 32-wH-8, ...c.OUTLINE);
    cv.line(ox+5, 32-wH-8, ox+5,  32-wH,   ...c.OUTLINE);
    cv.line(ox+11, 32-wH-8, ox+11, 32-wH,  ...c.OUTLINE);
    // smoke wisp from chimney
    cv.sp(ox+8, 32-wH-9,  ...c.STONE_L, 100);
    cv.sp(ox+7, 32-wH-11, ...c.STONE_L, 60);
    cv.sp(ox+9, 32-wH-12, ...c.STONE_L, 40);
    // X-brace diagonal beams on left face (cross the vertical timbers)
    cv.line(ox+1, 32-wH+6, ox+20, 32,     ...c.WOOD_D, 60);
    cv.line(ox+20, 32-wH+6, ox+1, 32,     ...c.WOOD_D, 60);
    // candlelight silhouette inside window (seated patron)
    cv.sp(ox+14, 32-wH+5, 30, 20, 10, 60);
    // night: warm tavern window glow — brighter amber, wider halo (SPA-523)
    // SPA-602: widened halos, wall shadow pass, chimney smoke lit by forge glow
    if (nightMode) {
      // darken timber-frame wall at night
      for (let ny = 32-wH+1; ny < 32; ny++)
        for (let nx = ox+1; nx < ox+30; nx++)
          cv.sp(nx, ny, 0, 0, 0, 20);
      for (let ny = 32-wH+1; ny < 32; ny++)
        for (let nx = ox+33; nx < ox+62; nx++)
          cv.sp(nx, ny, 0, 0, 0, 16);
      // window: bright amber fill + wide warm halo (r²≤18)
      cv.fillRect(ox+12, 32-wH+2, 6, 5, 245, 195, 75);
      for (let dy=-4; dy<=4; dy++) for (let dx=-4; dx<=4; dx++)
        if (dx*dx+dy*dy<=18)
          cv.sp(ox+15+dx, 32-wH+4+dy, 255, 200, 80, Math.max(0, 62-(dx*dx+dy*dy)*3));
      // lantern at night: brighter forge bloom
      for (let dy=-3; dy<=3; dy++) for (let dx=-3; dx<=3; dx++)
        if (dx*dx+dy*dy<=9)
          cv.sp(ox+22+dx, 32-wH+2+dy, ...c.FORGE, Math.max(0, 50-(dx*dx+dy*dy)*6));
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 2: CHAPEL — pale stone, pointed spire, cross (wallH=20)
  // ────────────────────────────────────────────────────────────────────────────
  {
    const col=2, wH=20;
    groundFace(col, ...c.CHAPEL_STONE);
    leftFace (col, wH, ...c.CHAPEL_STONE);
    rightFace(col, wH, 178,174,168);
    roofFace (col, wH, ...c.ROOF_SLATE);
    outlineWalls(col, wH);
    const ox=col*64;
    // spire (vertical protrusion)
    cv.fillPoly([
      [ox+30, 32-wH-14], [ox+34, 32-wH-14],
      [ox+36, 32-wH-2],  [ox+28, 32-wH-2],
    ], ...c.ROOF_SLATE);
    cv.line(ox+28, 32-wH-2, ox+30, 32-wH-14, ...c.OUTLINE);
    cv.line(ox+34, 32-wH-14, ox+36, 32-wH-2, ...c.OUTLINE);
    // cross on spire
    cv.line(ox+32, 32-wH-14, ox+32, 32-wH-8, ...c.CHAPEL_STONE);
    cv.line(ox+29, 32-wH-11, ox+35, 32-wH-11, ...c.CHAPEL_STONE);
    // gothic window with stained glass color sections
    cv.fillRect(ox+6, 32-wH+4, 5, 9, 80, 108, 160);      // base blue
    cv.sp(ox+7, 32-wH+5, ...c.MERCH_T, 200);              // gold pane top
    cv.sp(ox+8, 32-wH+7, ...c.FLAG_R, 160);               // red pane mid
    cv.sp(ox+9, 32-wH+9, 80, 148, 100, 180);              // green pane bottom
    cv.sp(ox+8, 32-wH+4, 80, 108, 160);                   // arch cap
    // window outline
    cv.line(ox+6, 32-wH+4, ox+10, 32-wH+4, ...c.STONE_D);
    cv.line(ox+6, 32-wH+4, ox+6,  32-wH+12,...c.STONE_D);
    cv.line(ox+10,32-wH+4, ox+10, 32-wH+12,...c.STONE_D);
    cv.line(ox+6, 32-wH+12,ox+10, 32-wH+12,...c.STONE_D);
    // right face: second narrow window with tracery
    cv.fillRect(ox+44, 32-wH+3, 4, 8, 80, 108, 160);
    cv.sp(ox+45, 32-wH+5, ...c.MERCH_T, 180);
    cv.sp(ox+46, 32-wH+7, ...c.FLAG_R, 140);
    cv.line(ox+46, 32-wH+3, ox+46, 32-wH+11, ...c.STONE_D, 80);  // tracery
    // stone arch over front door (left face, lower centre)
    cv.line(ox+2, 32-5, ox+14, 32-5, ...c.CHAPEL_STONE);
    // stone coursing lines
    for (let cy2=32-wH+5; cy2<32; cy2+=4)
      cv.line(ox+1, cy2, ox+30, cy2, ...c.STONE_D, 35);
    // bell silhouette at spire base (tiny bell shape inside spire)
    cv.fillRect(ox+30, 32-wH-5, 4, 3, ...c.STONE_M);
    cv.line(ox+30, 32-wH-5, ox+33, 32-wH-5, ...c.STONE_D);
    // finial on spire top (small diamond gem tip)
    cv.sp(ox+32, 32-wH-15, ...c.CHAPEL_STONE);
    cv.sp(ox+31, 32-wH-14, ...c.CHAPEL_STONE);
    cv.sp(ox+33, 32-wH-14, ...c.CHAPEL_STONE);
    // window tracery divider on left face (adds Gothic feel)
    cv.line(ox+8, 32-wH+4, ox+8, 32-wH+12, ...c.STONE_D, 90);
    // night: candlelight behind stained glass — warm halo on both windows (SPA-523)
    // SPA-602: widened halos, wall shadow pass for chapel depth
    if (nightMode) {
      // darken chapel stone walls at night
      for (let ny = 32-wH+1; ny < 32; ny++)
        for (let nx = ox+1; nx < ox+30; nx++)
          cv.sp(nx, ny, 0, 0, 0, 24);
      for (let ny = 32-wH+1; ny < 32; ny++)
        for (let nx = ox+33; nx < ox+62; nx++)
          cv.sp(nx, ny, 0, 0, 0, 20);
      // left stained glass window: wider warm halo (r²≤16)
      for (let dy=-4; dy<=4; dy++) for (let dx=-4; dx<=4; dx++)
        if (dx*dx+dy*dy<=16)
          cv.sp(ox+8+dx, 32-wH+8+dy, 255, 190, 60, Math.max(0, 40-(dx*dx+dy*dy)*2));
      // right narrow window: wider warm halo (r²≤12)
      for (let dy=-3; dy<=3; dy++) for (let dx=-3; dx<=3; dx++)
        if (dx*dx+dy*dy<=12)
          cv.sp(ox+46+dx, 32-wH+7+dy, 255, 190, 60, Math.max(0, 32-(dx*dx+dy*dy)*2));
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 3: MARKET — open stall, canvas awning, wood posts (wallH=12)
  // ────────────────────────────────────────────────────────────────────────────
  {
    const col=3, wH=12;
    groundFace(col, ...c.DIRT_M);
    // canvas awning instead of solid walls
    cv.fillPoly([
      [col*64+1,  32-wH], [col*64+32, 32-wH-15],
      [col*64+32, 32-4],  [col*64+1,  32-4],
    ], ...c.CANVAS);
    cv.fillPoly([
      [col*64+32, 32-wH-15], [col*64+63, 32-wH],
      [col*64+63, 32-4],     [col*64+32, 32-4],
    ], 176, 128, 46);                 // slightly shadowed right side
    outlineWalls(col, wH);
    const ox=col*64;
    // vertical posts
    cv.line(ox+2,  32-wH, ox+2,  48, ...c.WOOD_D);
    cv.line(ox+31, 32-wH-14, ox+31, 48, ...c.WOOD_D);
    cv.line(ox+62, 32-wH, ox+62, 48, ...c.WOOD_D);
    // diagonal stripes on awning left face (give canvas a striped look)
    for (let sy = 32-wH+1; sy < 32-5; sy += 3)
      cv.line(ox+1, sy, ox+31, sy, ...c.THATCH_D, 45);
    // goods on counter: pots, sacks, produce
    cv.fillRect(ox+8,  32-4, 5, 3, ...c.DIRT_L);   // grain sack
    cv.fillRect(ox+15, 32-5, 4, 4, ...c.ROOF_TILE); // clay pot
    cv.fillRect(ox+21, 32-4, 5, 3, ...c.GRASS_M);   // produce (greens)
    // merchant pennant (small flag on center post)
    cv.fillRect(ox+28, 32-wH-14, 7, 5, ...c.MERCH_T);
    cv.line(ox+28, 32-wH-14, ox+34, 32-wH-14, ...c.OUTLINE);
    // scales/balance hanging from awning crossbar (icon of trade)
    cv.line(ox+46, 32-wH+2, ox+54, 32-wH+2, ...c.WOOD_D);       // balance beam
    cv.line(ox+50, 32-wH+1, ox+50, 32-wH+4, ...c.WOOD_D);       // pivot
    cv.sp(ox+46, 32-wH+3, ...c.STONE_L);                          // left pan
    cv.sp(ox+54, 32-wH+3, ...c.STONE_L);                          // right pan
    cv.line(ox+45, 32-wH+2, ox+47, 32-wH+4, ...c.STONE_M, 120); // left chain
    cv.line(ox+53, 32-wH+2, ox+55, 32-wH+4, ...c.STONE_M, 120); // right chain
    // bread loaf on counter (rounded ochre)
    cv.fillRect(ox+26, 32-4, 4, 3, ...c.THATCH_L);
    cv.sp(ox+27, 32-5, ...c.DIRT_L);
    cv.line(ox+26, 32-4, ox+29, 32-4, ...c.WOOD_D, 80);
    // cloth bolt (rolled fabric in market colours)
    cv.fillRect(ox+32, 32-6, 3, 5, ...c.CANVAS);
    cv.sp(ox+33, 32-6, ...c.MERCH_T, 120);
    // price board hanging from left post
    cv.fillRect(ox+4, 32-wH+4, 6, 4, ...c.PARCH_L);
    cv.line(ox+4, 32-wH+4, ox+9, 32-wH+4, ...c.INK, 160);
    cv.line(ox+4, 32-wH+6, ox+9, 32-wH+6, ...c.INK, 100);
    cv.line(ox+3, 32-wH+3, ox+10, 32-wH+3, ...c.OUTLINE);
    cv.line(ox+3, 32-wH+7, ox+10, 32-wH+7, ...c.OUTLINE);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 4: WELL — stone rim, wooden frame, rope bucket (wallH=14)
  // ────────────────────────────────────────────────────────────────────────────
  {
    const col=4, wH=14;
    groundFace(col, ...c.STONE_M);
    const ox=col*64;
    // stone cylindrical rim (approximated with rectangles)
    cv.fillPoly([
      [ox+16, 32-wH], [ox+48, 32-wH],
      [ox+48, 32-4],  [ox+16, 32-4],
    ], ...c.STONE_M);
    // water inside
    cv.fillRect(ox+18, 32-wH+2, 28, wH-6, ...c.WATER_D);
    cv.fillRect(ox+18, 32-wH+2, 28, 3, ...c.WATER_L);
    // wooden crossbar
    cv.line(ox+14, 32-wH-4, ox+50, 32-wH-4, ...c.WOOD_M);
    cv.line(ox+32, 32-wH-4, ox+32, 32-wH+2, ...c.WOOD_D); // rope
    // stone outline
    cv.line(ox+16, 32-wH, ox+48, 32-wH, ...c.STONE_D);
    cv.line(ox+16, 32-4,  ox+48, 32-4,  ...c.STONE_D);
    cv.line(ox+16, 32-wH, ox+16, 32-4,  ...c.STONE_D);
    cv.line(ox+48, 32-wH, ox+48, 32-4,  ...c.STONE_D);
    // vertical supports
    cv.line(ox+14, 32-wH-6, ox+14, 32-4, ...c.WOOD_D);
    cv.line(ox+50, 32-wH-6, ox+50, 32-4, ...c.WOOD_D);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 5: BLACKSMITH — dark stone, orange forge glow (wallH=16)
  // ────────────────────────────────────────────────────────────────────────────
  {
    const col=5, wH=16;
    groundFace(col, ...c.STONE_D);
    leftFace (col, wH, ...c.STONE_M);
    rightFace(col, wH, 64, 60, 52);
    roofFace (col, wH, 58, 56, 60);
    outlineWalls(col, wH);
    const ox=col*64;
    // forge glow opening (deeper cavity)
    cv.fillRect(ox+4, 32-wH+6, 8, 8, 40, 22, 10);
    cv.fillRect(ox+5, 32-wH+7, 6, 6, ...c.FORGE);
    cv.fillRect(ox+6, 32-wH+8, 4, 3, 255, 200, 80);
    cv.fillRect(ox+7, 32-wH+9, 2, 1, 255, 240, 160);  // hottest core pixel
    // glow halo — wider radius for more dramatic warmth
    for (let _dy=-3; _dy<=3; _dy++) for (let _dx=-3; _dx<=3; _dx++)
      if (_dx*_dx+_dy*_dy<=9)
        cv.sp(ox+8+_dx, 32-wH+10+_dy, ...c.FORGE, Math.max(0, 65 - (_dx*_dx+_dy*_dy)*8));
    // forge spark particles (static — 5 random-ish bright dots above mouth)
    cv.sp(ox+6,  32-wH+4, 255, 220, 80, 200);
    cv.sp(ox+9,  32-wH+3, 255, 180, 60, 160);
    cv.sp(ox+11, 32-wH+5, 255, 200, 80, 140);
    cv.sp(ox+7,  32-wH+2, 255, 240, 120, 120);
    cv.sp(ox+5,  32-wH+5, ...c.FORGE, 100);
    // chimney stack on roof (smoke outlet above forge)
    cv.fillRect(ox+5, 32-wH-7, 5, 7, ...c.STONE_D);
    cv.line(ox+4,  32-wH-7, ox+10, 32-wH-7, ...c.OUTLINE);
    cv.line(ox+4,  32-wH-7, ox+4,  32-wH,   ...c.OUTLINE);
    cv.line(ox+10, 32-wH-7, ox+10, 32-wH,   ...c.OUTLINE);
    // smoke wisps
    cv.sp(ox+7,  32-wH-8,  ...c.STONE_M, 110);
    cv.sp(ox+6,  32-wH-10, ...c.STONE_L, 70);
    cv.sp(ox+8,  32-wH-11, ...c.STONE_L, 50);
    // anvil on right face — improved silhouette
    cv.fillRect(ox+44, 32-6,  12, 3, ...c.STONE_D);   // anvil body
    cv.fillRect(ox+46, 32-9,   8, 3, ...c.STONE_M);   // anvil horn/face
    cv.fillRect(ox+47, 32-10,  6, 2, ...c.STONE_L);   // top face highlight
    cv.line(ox+44, 32-6, ox+55, 32-6, ...c.OUTLINE);
    // hammer hanging on right wall
    cv.fillRect(ox+57, 32-wH+3, 2, 7, ...c.WOOD_D);   // handle
    cv.fillRect(ox+55, 32-wH+3, 4, 3, ...c.STONE_M);  // head
    cv.line(ox+55, 32-wH+3, ox+58, 32-wH+3, ...c.OUTLINE);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 6: MILL — cream walls, large brown wheel visible (wallH=18)
  // ────────────────────────────────────────────────────────────────────────────
  {
    const col=6, wH=18;
    groundFace(col, ...c.DIRT_L);
    leftFace (col, wH, ...c.PLASTER);
    rightFace(col, wH, 194, 174, 132);
    roofFace (col, wH, ...c.THATCH_D);
    outlineWalls(col, wH);
    const ox=col*64;
    // mill-wheel on right side (circle approximation)
    const wox=ox+50, woy=32-8;
    for (let a=0; a<Math.PI*2; a+=0.3) {
      cv.sp(wox+Math.round(9*Math.cos(a)), woy+Math.round(9*Math.sin(a)), ...c.WOOD_D);
      cv.sp(wox+Math.round(7*Math.cos(a)), woy+Math.round(7*Math.sin(a)), ...c.WOOD_M);
    }
    // spokes
    for (let a=0; a<Math.PI*2; a+=Math.PI/4)
      cv.line(wox, woy, wox+Math.round(8*Math.cos(a)), woy+Math.round(8*Math.sin(a)), ...c.WOOD_D, 180);
    // small door
    cv.fillRect(ox+4, 32-7, 6, 7, ...c.WOOD_D);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 7: STORAGE — dark timber warehouse, wide & low (wallH=14)
  // ────────────────────────────────────────────────────────────────────────────
  {
    const col=7, wH=14;
    groundFace(col, ...c.DIRT_D);
    leftFace (col, wH, ...c.WOOD_M);
    rightFace(col, wH, 112, 74, 36);
    roofFace (col, wH, ...c.THATCH_D);
    outlineWalls(col, wH);
    const ox=col*64;
    // plank lines on left face
    for (let y=32-wH+2; y<32; y+=3)
      cv.line(ox+1, y, ox+30, y, ...c.WOOD_D, 80);
    // double door
    cv.fillRect(ox+8, 32-10, 8, 10, ...c.WOOD_D);
    cv.line(ox+12, 32-10, ox+12, 32, ...c.WOOD_L, 120);
    cv.sp(ox+11, 32-5, ...c.STONE_L);
    cv.sp(ox+13, 32-5, ...c.STONE_L);
    // chain and padlock across door seam
    cv.line(ox+9, 32-7, ox+15, 32-7, ...c.STONE_M);
    cv.fillRect(ox+11, 32-8, 3, 3, ...c.STONE_D);       // padlock body
    cv.sp(ox+12, 32-8, ...c.STONE_L);                   // keyhole highlight
    cv.line(ox+11, 32-8, ox+13, 32-8, ...c.OUTLINE);
    // barred window on left face (upper section)
    cv.fillRect(ox+19, 32-wH+3, 7, 6, 40, 36, 44);     // dark interior
    cv.line(ox+19, 32-wH+3, ox+25, 32-wH+3, ...c.WOOD_D);
    cv.line(ox+19, 32-wH+8, ox+25, 32-wH+8, ...c.WOOD_D);
    cv.line(ox+19, 32-wH+3, ox+19, 32-wH+8, ...c.WOOD_D);
    cv.line(ox+25, 32-wH+3, ox+25, 32-wH+8, ...c.WOOD_D);
    // vertical bars (iron grating)
    cv.line(ox+21, 32-wH+3, ox+21, 32-wH+8, ...c.STONE_L, 160);
    cv.line(ox+23, 32-wH+3, ox+23, 32-wH+8, ...c.STONE_L, 160);
    // loading hook / pulley on right face roof edge (warehouse feel)
    cv.line(ox+50, 32-wH-3, ox+50, 32-wH+2, ...c.STONE_M);  // mount post
    cv.sp(ox+49, 32-wH-3, ...c.STONE_L);
    cv.sp(ox+51, 32-wH-3, ...c.STONE_L);
    cv.sp(ox+50, 32-wH-4, ...c.STONE_L);                     // pulley wheel
    cv.line(ox+50, 32-wH-4, ox+57, 32-wH+1, ...c.WOOD_D, 120); // hanging rope
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 8: GUARD POST — grey tower, battlements (wallH=24)
  // ────────────────────────────────────────────────────────────────────────────
  {
    const col=8, wH=24;
    groundFace(col, ...c.STONE_D);
    leftFace (col, wH, ...c.STONE_L);
    rightFace(col, wH, 130, 124, 110);
    roofFace (col, wH, ...c.STONE_M);
    outlineWalls(col, wH);
    const ox=col*64;
    // battlements (merlons) along roof edge
    for (let bx=ox+4; bx<ox+30; bx+=6)
      cv.fillRect(bx, 32-wH-4, 4, 4, ...c.STONE_L);
    for (let bx=ox+35; bx<ox+62; bx+=6)
      cv.fillRect(bx, 32-wH-4, 4, 4, ...c.STONE_L);
    // arrow slit
    cv.fillRect(ox+12, 32-wH+5, 3, 8, 40, 36, 44);
    // torch
    cv.sp(ox+24, 32-wH+2, ...c.FORGE, 200);
    cv.sp(ox+24, 32-wH+1, 255, 230, 120, 160);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 9: TOWN HALL — grandest, stone + wood, flag (wallH=26)
  // ────────────────────────────────────────────────────────────────────────────
  {
    const col=9, wH=26;
    groundFace(col, ...c.STONE_M);
    leftFace (col, wH, ...c.MANOR_STONE);
    rightFace(col, wH, 168, 156, 132);
    roofFace (col, wH, ...c.ROOF_TILE);
    outlineWalls(col, wH);
    const ox=col*64;
    // columns on left face
    cv.line(ox+6,  32-wH, ox+6,  32, ...c.CHAPEL_STONE);
    cv.line(ox+12, 32-wH, ox+12, 32, ...c.CHAPEL_STONE);
    cv.line(ox+18, 32-wH, ox+18, 32, ...c.CHAPEL_STONE);
    // arched door
    cv.fillRect(ox+8, 32-9, 7, 9, 50, 44, 60);
    cv.sp(ox+11, 32-9, 50, 44, 60);
    // flag on roof
    cv.line(ox+58, 32-wH-10, ox+58, 32-wH, ...c.WOOD_M);
    cv.fillRect(ox+50, 32-wH-10, 9, 6, ...c.FLAG_R);
    cv.line(ox+50, 32-wH-10, ox+58, 32-wH-10, ...c.OUTLINE);
  }

  // ── ambient-occlusion shadow: darkens ground face near all building bases ───
  // Applied after all buildings so it composites over any coloured ground faces.
  for (let _col = 0; _col < 10; _col++) {
    const _cx = _col*64+32, _cy = 32, _hw = 31, _hh = 15;
    cv.line(_cx-_hw+1, _cy+1, _cx,       _cy+_hh-1, ...c.OUTLINE, 38);
    cv.line(_cx,       _cy+_hh-1, _cx+_hw-1, _cy+1, ...c.OUTLINE, 28);
    cv.line(_cx-_hw+2, _cy+2, _cx,       _cy+_hh-2, ...c.OUTLINE, 18);
    cv.line(_cx,       _cy+_hh-2, _cx+_hw-2, _cy+2, ...c.OUTLINE, 12);
  }

  // ── Upscale 2× via nearest-neighbour (640×64 → 1280×128) ──────────────────
  const _sc = nearestNeighborScale(cv.data, 640, 64, 1280, 128);
  const cv2 = createCanvas(1280, 128);
  for (let _i = 0; _i < _sc.length; _i++) cv2.data[_i] = _sc[_i];

  // ── UNIQUE SILHOUETTES at 128px resolution ─────────────────────────────────
  // Drawn on top of the NN-scaled base. All coordinates in 1280×128 space.
  // Mapping: original pixel (x,y) → scaled pixel (x*2, y*2).

  // 4: WELL — conical thatched roof over wooden frame ─────────────────────────
  // Scaled geometry: crossbar at y=28, frame supports at x=540, x=612.
  {
    const ox4 = 4*128;                      // 512
    const peakX = ox4+64, peakY = 8;        // cone peak above frame
    const bL = ox4+24,  bR = ox4+104, baseY = 28;
    // Cone fill
    cv2.fillPoly([[peakX-2,peakY],[peakX+2,peakY],[bR,baseY],[bL,baseY]], ...c.THATCH_D);
    // Shingle texture lines
    for (let ry=peakY+4; ry<baseY; ry+=4) {
      const t = (ry-peakY)/(baseY-peakY);
      cv2.line(Math.round(peakX+(bL-peakX)*t), ry, Math.round(peakX+(bR-peakX)*t), ry, ...c.THATCH_L, 80);
    }
    // Outline edges
    cv2.line(peakX, peakY, bL, baseY, ...c.OUTLINE);
    cv2.line(peakX, peakY, bR, baseY, ...c.OUTLINE);
    // Finial cap
    cv2.fillRect(peakX-1, peakY-3, 3, 4, ...c.STONE_L);
    cv2.sp(peakX, peakY-4, ...c.STONE_M);
  }

  // 6: MILL — large waterwheel on left face, breaks roofline above ────────────
  // Scaled: roofline at y=28 (64-36), left face left-edge at x=769.
  {
    const ox6 = 6*128;                      // 768
    const wwcx = ox6+22, wwcy = 42;         // wheel center: (790, 42)
    const wwr = 18;                          // wheel radius
    // Outer rim
    for (let a=0; a<Math.PI*2; a+=0.05)
      cv2.sp(wwcx+Math.round(wwr*Math.cos(a)), wwcy+Math.round(wwr*Math.sin(a)), ...c.WOOD_D);
    // Inner rim
    for (let a=0; a<Math.PI*2; a+=0.07)
      cv2.sp(wwcx+Math.round((wwr-3)*Math.cos(a)), wwcy+Math.round((wwr-3)*Math.sin(a)), ...c.WOOD_M);
    // 8 spokes
    for (let a=0; a<Math.PI*2; a+=Math.PI/4)
      cv2.line(wwcx, wwcy, wwcx+Math.round((wwr-2)*Math.cos(a)), wwcy+Math.round((wwr-2)*Math.sin(a)), ...c.WOOD_D);
    // Hub
    cv2.fillRect(wwcx-3, wwcy-3, 6, 6, ...c.WOOD_D);
    cv2.fillRect(wwcx-1, wwcy-1, 2, 2, ...c.STONE_L);
    // 8 paddle boards on rim
    for (let a=0; a<Math.PI*2; a+=Math.PI/4) {
      const px=wwcx+Math.round(wwr*Math.cos(a)), py=wwcy+Math.round(wwr*Math.sin(a));
      cv2.fillRect(px-3, py-2, 6, 4, ...c.WOOD_M);
    }
    // Axle beam from hub to wall
    cv2.fillRect(wwcx, wwcy-1, ox6+38-wwcx, 2, ...c.WOOD_M);
    // Millrace (water channel beneath wheel at ground level)
    cv2.fillRect(ox6, 62, wwcx-ox6+8, 2, ...c.WATER_D);
    cv2.line(ox6, 62, wwcx+6, 62, ...c.WATER_L, 140);
  }

  // 7: STORAGE — loading crane arm breaking right-face roof edge ──────────────
  // Scaled: roof top at y=36 (64-28), right edge at x=1023.
  {
    const ox7 = 7*128;                      // 896
    const topY7 = 36;                        // roof top
    const cpx = ox7+106;                     // crane post x: 1002
    // Vertical post
    cv2.fillRect(cpx, topY7-22, 3, 24, ...c.WOOD_D);
    cv2.line(cpx-1, topY7-22, cpx-1, topY7+2, ...c.OUTLINE, 120);
    cv2.line(cpx+3, topY7-22, cpx+3, topY7+2, ...c.OUTLINE, 80);
    // Diagonal crane arm (slopes up-right, breaking upper silhouette)
    const aTipX = ox7+122, aTipY = topY7-30;  // arm tip: (1018, 6)
    cv2.line(cpx+1, topY7-22, aTipX, aTipY, ...c.WOOD_M);
    cv2.line(cpx+2, topY7-21, aTipX+1, aTipY+1, ...c.WOOD_D);
    // Diagonal brace
    cv2.line(cpx+1, topY7-4, aTipX-4, aTipY+6, ...c.WOOD_D, 160);
    // Pulley housing at arm tip
    cv2.fillRect(aTipX-2, aTipY-3, 5, 4, ...c.STONE_M);
    cv2.sp(aTipX, aTipY-2, ...c.STONE_L);
    // Hanging rope
    cv2.line(aTipX, aTipY, aTipX, aTipY+24, ...c.WOOD_D, 160);
    // Cargo block on rope
    cv2.fillRect(aTipX-4, aTipY+20, 8, 7, ...c.WOOD_M);
    cv2.line(aTipX-4, aTipY+20, aTipX+3, aTipY+20, ...c.OUTLINE);
    cv2.line(aTipX-4, aTipY+26, aTipX+3, aTipY+26, ...c.OUTLINE);
    cv2.line(aTipX-4, aTipY+20, aTipX-4, aTipY+26, ...c.OUTLINE);
    cv2.line(aTipX+3, aTipY+20, aTipX+3, aTipY+26, ...c.OUTLINE);
  }

  // 8: GUARD POST — narrower upper tower section with proper crenellations ────
  // Scaled: roof top at y=16 (64-48). Upper section adds 12px height, narrows.
  {
    const ox8 = 8*128, cx8 = ox8+64;        // 1024, 1088
    const topY8 = 16;                        // existing roof top
    const extH = 12, tHw = 42, tHh = 21;    // extension height, narrower iso dims
    // Upper tower left face
    cv2.fillPoly([
      [cx8-tHw, topY8-extH], [cx8, topY8-extH-tHh],
      [cx8, topY8-tHh],      [cx8-tHw, topY8],
    ], ...c.STONE_L);
    // Upper tower right face
    cv2.fillPoly([
      [cx8, topY8-extH-tHh], [cx8+tHw, topY8-extH],
      [cx8+tHw, topY8],      [cx8, topY8-tHh],
    ], 136, 130, 116);
    // Upper roof
    cv2.fillPoly([
      [cx8-tHw, topY8-extH], [cx8, topY8-extH-tHh],
      [cx8+tHw, topY8-extH], [cx8, topY8-extH+tHh],
    ], ...c.STONE_M);
    // Outlines
    cv2.line(cx8-tHw, topY8-extH, cx8, topY8-extH-tHh, ...c.OUTLINE);
    cv2.line(cx8, topY8-extH-tHh, cx8+tHw, topY8-extH, ...c.OUTLINE);
    cv2.line(cx8+tHw, topY8-extH, cx8+tHw, topY8, ...c.OUTLINE);
    cv2.line(cx8-tHw, topY8-extH, cx8-tHw, topY8, ...c.OUTLINE);
    // Crenellations — left face of upper tower
    for (let bx=cx8-tHw+4; bx<cx8-6; bx+=12) {
      cv2.fillRect(bx, topY8-extH-4, 7, 6, ...c.STONE_L);
      cv2.line(bx-1, topY8-extH-5, bx+7, topY8-extH-5, ...c.OUTLINE);
      cv2.line(bx-1, topY8-extH-5, bx-1, topY8-extH+2, ...c.OUTLINE);
      cv2.line(bx+7, topY8-extH-5, bx+7, topY8-extH+2, ...c.OUTLINE);
      cv2.line(bx-1, topY8-extH+2, bx+7, topY8-extH+2, ...c.OUTLINE);
    }
    // Crenellations — right face of upper tower
    for (let bx=cx8+6; bx<cx8+tHw-4; bx+=12) {
      cv2.fillRect(bx, topY8-extH-4, 7, 6, 142, 136, 122);
      cv2.line(bx-1, topY8-extH-5, bx+7, topY8-extH-5, ...c.OUTLINE);
      cv2.line(bx+7, topY8-extH-5, bx+7, topY8-extH+2, ...c.OUTLINE);
      cv2.line(bx-1, topY8-extH+2, bx+7, topY8-extH+2, ...c.OUTLINE);
    }
    // Arrow slit in upper left face
    cv2.fillRect(cx8-30, topY8-extH+2, 6, 10, 40, 36, 44);
    cv2.line(cx8-31, topY8-extH+1, cx8-24, topY8-extH+1, ...c.STONE_D);
    cv2.line(cx8-31, topY8-extH+12, cx8-24, topY8-extH+12, ...c.STONE_D);
    // Stone coursing on upper sections
    for (let ey=topY8-extH+5; ey<topY8; ey+=8) {
      cv2.line(cx8-tHw+2, ey, cx8-2, ey, ...c.STONE_D, 35);
      cv2.line(cx8+2, ey, cx8+tHw-2, ey, ...c.STONE_D, 25);
    }
    // Watch torch on upper tower (above battlement, clearly visible)
    cv2.sp(cx8-14, topY8-extH+6, ...c.FORGE, 200);
    cv2.sp(cx8-13, topY8-extH+6, ...c.FORGE, 180);
    cv2.sp(cx8-15, topY8-extH+5, ...c.FORGE, 110);
    cv2.sp(cx8-14, topY8-extH+5, 255, 230, 120, 90);
  }

  // 0: MANOR — weathervane (rooster silhouette on thin post above roofline) ───
  // Scaled: manor roof top at y=16 (64-48), right face peak at ~(64, 1).
  {
    const ox0 = 0*128, cx0 = ox0+64;
    const vaneTopY = 4;        // weathervane post tip
    const vaneBaseY = 16;      // roof line y in 128px space
    // Post
    cv2.fillRect(cx0+20, vaneTopY+6, 2, vaneBaseY-vaneTopY-4, ...c.STONE_M);
    cv2.line(cx0+19, vaneTopY+6, cx0+22, vaneTopY+6, ...c.OUTLINE);
    // Cardinal direction arms (N/S/E/W crossbar)
    cv2.line(cx0+12, vaneTopY+8, cx0+30, vaneTopY+8, ...c.STONE_M);
    cv2.sp(cx0+12, vaneTopY+8, ...c.STONE_L); cv2.sp(cx0+30, vaneTopY+8, ...c.STONE_L);
    // Rooster body (simplified profile facing right)
    cv2.fillPoly([
      [cx0+22, vaneTopY+4], [cx0+30, vaneTopY+5], [cx0+30, vaneTopY+9],
      [cx0+24, vaneTopY+10],[cx0+22, vaneTopY+8],
    ], ...c.STONE_D);
    // Rooster head
    cv2.fillRect(cx0+29, vaneTopY+2, 4, 4, ...c.STONE_D);
    cv2.sp(cx0+32, vaneTopY+2, ...c.STONE_M);   // beak
    cv2.sp(cx0+30, vaneTopY+2, ...c.STONE_L);   // comb
    cv2.sp(cx0+31, vaneTopY+1, ...c.STONE_M);
    // Tail feathers
    cv2.fillPoly([
      [cx0+22, vaneTopY+4], [cx0+18, vaneTopY+2],
      [cx0+17, vaneTopY+6], [cx0+22, vaneTopY+7],
    ], ...c.STONE_D, 200);
    // Base ball joint
    cv2.fillRect(cx0+19, vaneTopY+13, 4, 4, ...c.STONE_L);
    cv2.sp(cx0+20, vaneTopY+14, ...c.STONE_M);
    cv2.line(cx0+19, vaneTopY+13, cx0+22, vaneTopY+13, ...c.OUTLINE);
  }

  // 9: TOWN HALL — central clock tower / bell tower breaking the ridgeline ───
  // Scaled: town hall roof top at y=12 (64-52).
  {
    const ox9 = 9*128, cx9 = ox9+64;
    const thTopY = 12;  // roof top in 128px space
    const twr_w = 20;   // tower half-width
    // Tower shaft (centred on building peak)
    cv2.fillPoly([
      [cx9-twr_w, thTopY-8],  [cx9, thTopY-8-10],
      [cx9+twr_w, thTopY-8],  [cx9, thTopY-8+10],
    ], ...c.MANOR_STONE);                // tower top face (flat iso diamond)
    cv2.fillPoly([
      [cx9-twr_w, thTopY-8], [cx9, thTopY-8+10],
      [cx9, thTopY+10],      [cx9-twr_w, thTopY],
    ], ...c.MANOR_STONE);                // tower left face
    cv2.fillPoly([
      [cx9, thTopY-8+10], [cx9+twr_w, thTopY-8],
      [cx9+twr_w, thTopY], [cx9, thTopY+10],
    ], 168, 158, 138);                   // tower right face (slightly darker)
    // Tower outline
    cv2.line(cx9-twr_w, thTopY-8,  cx9, thTopY-8-10, ...c.OUTLINE);
    cv2.line(cx9, thTopY-8-10, cx9+twr_w, thTopY-8, ...c.OUTLINE);
    cv2.line(cx9-twr_w, thTopY-8,  cx9-twr_w, thTopY, ...c.OUTLINE);
    cv2.line(cx9+twr_w, thTopY-8,  cx9+twr_w, thTopY, ...c.OUTLINE);
    // Clock face on left-face of tower (round frame + hands)
    const clkX = cx9-10, clkY = thTopY-2;
    cv2.fillRect(clkX-5, clkY-5, 10, 10, ...c.CHAPEL_STONE);
    cv2.line(clkX-6, clkY-5, clkX+4, clkY-5, ...c.OUTLINE);   // clock frame
    cv2.line(clkX-6, clkY+4, clkX+4, clkY+4, ...c.OUTLINE);
    cv2.line(clkX-6, clkY-5, clkX-6, clkY+4, ...c.OUTLINE);
    cv2.line(clkX+4, clkY-5, clkX+4, clkY+4, ...c.OUTLINE);
    cv2.sp(clkX-1, clkY, ...c.INK, 140);  // clock center
    cv2.line(clkX-1, clkY, clkX-1, clkY-3, ...c.INK, 120);  // 12 o'clock hand
    cv2.line(clkX-1, clkY, clkX+2, clkY+1, ...c.INK, 90);   // 3 o'clock hand
    // Bell arch at top of tower
    cv2.fillRect(cx9-6, thTopY-8-8, 12, 6, ...c.ROOF_SLATE);
    cv2.sp(cx9, thTopY-8-8, ...c.STONE_L);  // arch highlight
    cv2.line(cx9-7, thTopY-8-9, cx9+6, thTopY-8-9, ...c.OUTLINE);
    // Flag / civic banner on tower peak
    cv2.line(cx9, thTopY-8-10, cx9, thTopY-8-20, ...c.WOOD_M);
    cv2.fillRect(cx9, thTopY-8-20, 10, 7, ...c.FLAG_R);
    cv2.sp(cx9+4, thTopY-8-17, ...c.PARCH_L, 160);  // heraldic detail
    cv2.line(cx9, thTopY-8-20, cx9+9, thTopY-8-20, ...c.OUTLINE);
    cv2.line(cx9, thTopY-8-13, cx9+9, thTopY-8-13, ...c.OUTLINE);
  }

  // 3: MARKET — tall pennant poles with colored flags ────────────────────────
  // Adds two pennant poles at the market stall corners at 128px resolution.
  {
    const ox3 = 3*128;
    // Left pole (raised above the canvas awning)
    const lp = ox3+4, rp = ox3+124;
    const poleTop = 2;
    // Left pole
    cv2.fillRect(lp, poleTop, 2, 30, ...c.WOOD_D);
    cv2.fillRect(lp-1, poleTop+28, 4, 3, ...c.WOOD_D);  // pole cap
    // Left pennant (triangular flag)
    cv2.fillPoly([
      [lp+2, poleTop+2], [lp+2, poleTop+12], [lp+14, poleTop+7],
    ], ...c.MERCH_T);
    cv2.line(lp+2, poleTop+2, lp+13, poleTop+7, ...c.OUTLINE, 100);
    cv2.line(lp+2, poleTop+12, lp+13, poleTop+7, ...c.OUTLINE, 100);
    // Right pole
    cv2.fillRect(rp, poleTop, 2, 30, ...c.WOOD_D);
    cv2.fillRect(rp-1, poleTop+28, 4, 3, ...c.WOOD_D);
    // Right pennant (inverted direction)
    cv2.fillPoly([
      [rp, poleTop+2], [rp, poleTop+12], [rp-12, poleTop+7],
    ], ...c.CANVAS);
    cv2.line(rp, poleTop+2, rp-11, poleTop+7, ...c.OUTLINE, 100);
    cv2.line(rp, poleTop+12, rp-11, poleTop+7, ...c.OUTLINE, 100);
    // Bunting (string of small flags between poles)
    for (let bx = lp+16; bx < rp-12; bx += 16) {
      const flagColor = (bx % 32 === 0) ? c.FLAG_R : c.CANVAS;
      cv2.fillPoly([[bx, poleTop+8],[bx+7, poleTop+8],[bx+4, poleTop+14]], ...flagColor);
    }
    // String line connecting poles
    cv2.line(lp+2, poleTop+8, rp, poleTop+8, ...c.WOOD_D, 80);
  }

  return cv2.toPNG();
}

// ═══════════════════════════════════════════════════════════════════════════════
// NPC SPRITES (npc_sprites.png — 960×864, upscaled 2× from 480×432 base)  SPA-585
// Layout: 15 frames wide (64px each) × 9 archetype rows (96px each)
//   row 0 = merchant    (deep blue/gold)
//   row 1 = noble       (burgundy/silver)
//   row 2 = clergy      (cream/black)
//   row 3 = guard       (stone tabard/helmet)
//   row 4 = commoner    (drab linen)
//   row 5 = tavern_staff (apron/kerchief, warm amber)
//   row 6 = scholar     (ink-blue robe/scroll)
//   row 7 = elder       (grey robe/staff)
//   row 8 = spy         (dark hooded cloak)
// Columns per row (base 32px each, 15 total):
//   0-1:   idle_south (2 frames)   2-4:   walk_south (3 frames)
//   5-6:   idle_north (2 frames)   7-9:   walk_north (3 frames)
//  10-11:  idle_east  (2 frames)  12-14:  walk_east  (3 frames)
//   west = flip_h of east (handled in code)
// ═══════════════════════════════════════════════════════════════════════════════
function makeNPCSprites() {
  // 9 archetype rows × 48px = 432px height; 15 cols × 32px = 480px wide (SPA-585)
  // row 0=merchant, 1=noble, 2=clergy, 3=guard, 4=commoner, 5=tavern_staff
  // row 6=scholar,  7=elder, 8=spy
  const cv = createCanvas(480, 432);

  const FACTIONS = [
    { body: c.MERCH_B,  trim: c.MERCH_T,  hat: c.MERCH_B,  hatrim: c.MERCH_T,  hatStyle: 'wide'    },
    { body: c.NOBLE_B,  trim: c.NOBLE_T,  hat: c.NOBLE_B,  hatrim: c.NOBLE_T,  hatStyle: 'coronet' },
    { body: c.CLERGY_B, trim: c.CLERGY_T, hat: c.CLERGY_B, hatrim: c.CLERGY_T, hatStyle: 'hood'    },
  ];

  // Draw one NPC frame at pixel offset (ox, oy), 32×48 canvas region.
  // dy  = vertical body-bob offset
  // lx/rx = left/right foot X offsets (walk stride)
  // laY/raY = left/right arm Y offsets (arm swing: negative = raised/forward)
  const drawNPC = (ox, oy, fac, dy=0, lx=0, rx=0, laY=0, raY=0) => {
    const { body, trim, hat, hatrim, hatStyle = 'default' } = fac;

    // ── head (8×8, centred at x=16) ──
    const hx = ox+12, hy = oy+2+dy;
    cv.fillRect(hx, hy, 8, 8, ...c.SKIN);
    // cheek highlight (top-left catch-light)
    cv.sp(hx+1, hy+1, ...c.SKIN_HI);
    // eyebrows
    cv.sp(hx+2, hy+2, ...c.HAIR, 180);
    cv.sp(hx+5, hy+2, ...c.HAIR, 180);
    // eyes
    cv.sp(hx+2, hy+3, ...c.HAIR);
    cv.sp(hx+5, hy+3, ...c.HAIR);
    // eye whites (1px each side of iris gives depth)
    cv.sp(hx+1, hy+3, ...c.SKIN_HI, 120);
    cv.sp(hx+4, hy+3, ...c.SKIN_HI, 80);
    // nose (subtle shadow at centre-lower face)
    cv.sp(hx+3, hy+5, ...c.SKIN_SH);
    // mouth (2-pixel line with slight curve)
    cv.sp(hx+2, hy+6, ...c.SKIN_SH, 160);
    cv.sp(hx+3, hy+7, ...c.OUTLINE, 100);
    cv.sp(hx+4, hy+7, ...c.OUTLINE, 100);
    cv.sp(hx+5, hy+6, ...c.SKIN_SH, 160);
    // outline
    cv.line(hx,   hy,   hx+7, hy,   ...c.OUTLINE);
    cv.line(hx,   hy,   hx,   hy+7, ...c.OUTLINE);
    cv.line(hx+7, hy,   hx+7, hy+7, ...c.OUTLINE);
    cv.line(hx,   hy+7, hx+7, hy+7, ...c.OUTLINE);

    // ── hat (faction-specific silhouette) ─────────────────────────────────────
    if (hatStyle === 'wide') {
      // Merchant: extra-wide felt hat with feather quill — distinctive wide silhouette
      cv.fillRect(hx-3, hy-1, 14, 3, ...hat);           // wide brim (14px vs base 10px)
      cv.line(hx-3, hy-1, hx+10, hy-1, ...c.OUTLINE);
      cv.fillRect(hx+1, hy-5, 6, 5, ...hat);             // crown
      cv.fillRect(hx+2, hy-6, 4, 2, ...hatrim);          // hat band
      cv.line(hx+1, hy-5, hx+6, hy-5, ...c.OUTLINE);
      // feather quill on right side of crown
      cv.sp(hx+7, hy-5, ...c.CANVAS, 200);
      cv.sp(hx+8, hy-6, ...c.CANVAS, 180);
      cv.sp(hx+8, hy-7, ...c.PARCH_L, 130);
    } else if (hatStyle === 'coronet') {
      // Noble: 3-spike coronet — narrow band base, vertical spikes, gem tips
      cv.fillRect(hx, hy-2, 8, 3, ...hat);               // base crown band
      cv.line(hx, hy-2, hx+7, hy-2, ...c.OUTLINE);
      // left spike
      cv.fillRect(hx+1, hy-5, 2, 4, ...hat);
      cv.line(hx+1, hy-5, hx+2, hy-5, ...c.OUTLINE);
      // center spike (tallest — distinctive vertical presence)
      cv.fillRect(hx+3, hy-7, 2, 6, ...hat);
      cv.line(hx+3, hy-7, hx+4, hy-7, ...c.OUTLINE);
      // right spike
      cv.fillRect(hx+5, hy-5, 2, 4, ...hat);
      cv.line(hx+5, hy-5, hx+6, hy-5, ...c.OUTLINE);
      // gem at each spike tip (hatrim = NOBLE_T silver)
      cv.sp(hx+1, hy-5, ...hatrim);
      cv.sp(hx+3, hy-7, ...hatrim);
      cv.sp(hx+6, hy-5, ...hatrim);
    } else if (hatStyle === 'hood') {
      // Clergy: wide draped hood — soft crown extends past head width, side drapes to shoulders
      cv.fillRect(hx-2, hy-3, 12, 5, ...hat);            // hood crown (wider than head)
      cv.fillRect(hx-2, hy+2, 3, 7, ...hat);             // left side drape
      cv.fillRect(hx+7, hy+2, 3, 7, ...hat);             // right side drape
      cv.line(hx-2, hy-3, hx+9, hy-3, ...c.OUTLINE);
      cv.line(hx-2, hy-3, hx-2, hy+8, ...c.OUTLINE);
      cv.line(hx+9, hy-3, hx+9, hy+8, ...c.OUTLINE);
    } else {
      // Default hat (generic fallback)
      cv.fillRect(hx-1, hy-1, 10, 3, ...hat);
      cv.line(hx-1, hy-1, hx+8, hy-1, ...c.OUTLINE);
      cv.fillRect(hx+1, hy-4, 6, 4, ...hat);
      cv.fillRect(hx+2, hy-5, 4, 2, ...hatrim);
      cv.line(hx+1, hy-4, hx+6, hy-4, ...c.OUTLINE);
    }

    // ── body / torso (10×14) ─────────────────────────────────────────────────
    const bx = ox+11, by = oy+10+dy;
    cv.fillRect(bx, by, 10, 14, ...body);
    // belt / trim stripe
    cv.fillRect(bx, by+6, 10, 2, ...trim);
    // right-side body shadow (3D volume — receding face)
    cv.fillRect(bx+8, by+1, 2, 12, ...c.OUTLINE, 55);
    // left shoulder highlight (catch-light)
    cv.sp(bx+1, by+1, 255, 255, 255, 18);
    cv.sp(bx+1, by+2, 255, 255, 255, 10);
    // outline
    cv.line(bx,    by,    bx+9,  by,    ...c.OUTLINE);
    cv.line(bx,    by,    bx,    by+13, ...c.OUTLINE);
    cv.line(bx+9,  by,    bx+9,  by+13, ...c.OUTLINE);
    cv.line(bx,    by+13, bx+9,  by+13, ...c.OUTLINE);

    // ── arms (laY/raY: negative = arm raised forward, positive = arm back) ────
    const laLen = 10 - Math.abs(laY);
    const raLen = 10 - Math.abs(raY);
    cv.fillRect(bx-2, by+1+laY, 3, laLen, ...body);
    cv.fillRect(bx+9, by+1+raY, 3, raLen, ...body);
    // hands
    cv.fillRect(bx-2, by+1+laY+laLen-2, 3, 3, ...c.SKIN);
    cv.fillRect(bx+9, by+1+raY+raLen-2, 3, 3, ...c.SKIN);
    // forward arm slightly lighter (closer to viewer)
    if (laY < 0) cv.fillRect(bx-2, by+1+laY, 3, laLen, ...c.SKIN_HI, 40);
    if (raY < 0) cv.fillRect(bx+9, by+1+raY, 3, raLen, ...c.SKIN_HI, 40);

    // ── legs / robe ───────────────────────────────────────────────────────────
    if (hatStyle === 'hood') {
      // Clergy: flowing cassock robe — bell-shaped trapezoid hides legs entirely
      cv.fillPoly([
        [bx-1, by+8], [bx+10, by+8],
        [bx+13, oy+46], [bx-4, oy+46],
      ], ...body);
      cv.line(bx-4, oy+46, bx+13, oy+46, ...c.OUTLINE);  // hem
      // Boot tips barely visible at hem (shift with walk animation lx/rx)
      cv.fillRect(bx+1+lx, oy+44, 4, 2, ...c.HAIR);
      cv.fillRect(bx+5+rx, oy+44, 4, 2, ...c.HAIR);
    } else {
      const ly = by+13;
      cv.fillRect(bx+1+lx,   ly,  4, 10, ...body);
      cv.fillRect(bx+5+rx,   ly,  4, 10, ...body);
      // feet
      cv.fillRect(bx+0+lx,   ly+8, 5, 3, ...c.HAIR);
      cv.fillRect(bx+4+rx,   ly+8, 5, 3, ...c.HAIR);
      // leg outline
      cv.line(bx+1+lx, ly, bx+1+lx, ly+9, ...c.OUTLINE);
      cv.line(bx+4+lx, ly, bx+4+lx, ly+9, ...c.OUTLINE);
      cv.line(bx+5+rx, ly, bx+5+rx, ly+9, ...c.OUTLINE);
      cv.line(bx+8+rx, ly, bx+8+rx, ly+9, ...c.OUTLINE);
    }

    // ground cast shadow (grounds the NPC visually)
    {
      const _sy = (hatStyle === 'hood') ? oy+47 : oy+37+dy;
      for (let _sx = -6; _sx <= 6; _sx++) {
        cv.sp(ox+16+_sx, _sy, ...c.OUTLINE, Math.max(0, 20-Math.abs(_sx)*3));
      }
    }
    // faction badge (tiny 3×3 diamond on belt)
    const bdx=bx+4, bdy=by+5;
    cv.sp(bdx+1, bdy,   ...trim);
    cv.sp(bdx,   bdy+1, ...trim);
    cv.sp(bdx+2, bdy+1, ...trim);
    cv.sp(bdx+1, bdy+2, ...trim);

    // faction-specific prop / accessory
    const propFi = FACTIONS.indexOf(fac);
    if (propFi === 0) {
      // Merchant: coin pouch at left hip (below belt)
      cv.fillRect(bx-1, by+10, 4, 4, ...c.WOOD_M);
      cv.sp(bx,    by+11, ...c.MERCH_T, 180);
      cv.line(bx-1, by+10, bx+2, by+10, ...c.OUTLINE);
      cv.line(bx-1, by+10, bx-1, by+13, ...c.OUTLINE);
      cv.line(bx+2, by+10, bx+2, by+13, ...c.OUTLINE);
    } else if (propFi === 1) {
      // Noble: sword hilt at right hip
      cv.fillRect(bx+9, by+9, 2, 5, ...c.STONE_L);   // blade tip visible
      cv.fillRect(bx+8, by+8, 4, 2, ...c.WOOD_M);    // crossguard
      cv.line(bx+8, by+8, bx+11, by+8, ...c.OUTLINE);
    } else if (propFi === 2) {
      // Clergy: small cross on chest
      cv.fillRect(bx+4, by+1, 2, 6, ...c.PARCH_M);
      cv.fillRect(bx+2, by+3, 6, 2, ...c.PARCH_M);
    }
  };

  // ── Generic north-facing (back view) for faction archetypes ─────────────────
  const drawNPC_north = (ox, oy, fac, dy=0, lx=0, rx=0) => {
    const { body, trim, hat, hatrim, hatStyle = 'default' } = fac;
    const hx = ox+12, hy = oy+2+dy;
    // Back of head: hair fills top half, no face, ear hints on sides
    cv.fillRect(hx, hy, 8, 8, ...c.SKIN);
    cv.fillRect(hx, hy, 8, 4, ...c.HAIR);
    cv.sp(hx,   hy+3, ...c.SKIN);
    cv.sp(hx+7, hy+3, ...c.SKIN);
    cv.line(hx,   hy,   hx,   hy+7, ...c.OUTLINE);
    cv.line(hx+7, hy,   hx+7, hy+7, ...c.OUTLINE);
    cv.line(hx,   hy+7, hx+7, hy+7, ...c.OUTLINE);
    // Hat from behind
    if (hatStyle === 'wide') {
      cv.fillRect(hx-3, hy-1, 14, 3, ...hat);
      cv.fillRect(hx+1, hy-5, 6, 5, ...hat);
      cv.line(hx-3, hy-1, hx+10, hy-1, ...c.OUTLINE);
      cv.line(hx+1, hy-5, hx+6, hy-5, ...c.OUTLINE);
    } else if (hatStyle === 'coronet') {
      cv.fillRect(hx, hy-2, 8, 3, ...hat);
      cv.fillRect(hx+3, hy-6, 2, 5, ...hat);
      cv.line(hx, hy-2, hx+7, hy-2, ...c.OUTLINE);
    } else if (hatStyle === 'hood') {
      cv.fillRect(hx-2, hy-3, 12, 5, ...hat);
      cv.fillRect(hx-2, hy+2, 3, 7, ...hat);
      cv.fillRect(hx+7, hy+2, 3, 7, ...hat);
      cv.line(hx+4, hy-3, hx+4, hy+8, ...hat, 130);
      cv.line(hx-2, hy-3, hx+9, hy-3, ...c.OUTLINE);
    } else {
      cv.fillRect(hx-1, hy-1, 10, 3, ...hat);
      cv.fillRect(hx+1, hy-4, 6, 4, ...hat);
      cv.line(hx-1, hy-1, hx+8, hy-1, ...c.OUTLINE);
      cv.line(hx+1, hy-4, hx+6, hy-4, ...c.OUTLINE);
    }
    // Body from behind
    const bx = ox+11, by = oy+10+dy;
    cv.fillRect(bx, by, 10, 14, ...body);
    cv.line(bx+5, by, bx+5, by+13, ...body, 180);
    cv.line(bx, by+8, bx+9, by+8, ...trim, 80);
    cv.line(bx, by, bx+9, by, ...c.OUTLINE);
    cv.line(bx, by, bx, by+13, ...c.OUTLINE);
    cv.line(bx+9, by, bx+9, by+13, ...c.OUTLINE);
    cv.line(bx, by+13, bx+9, by+13, ...c.OUTLINE);
    cv.fillRect(bx, by+1, 2, 12, ...c.OUTLINE, 40);
    // Arms
    cv.fillRect(bx-2, by+1, 3, 10, ...body);
    cv.fillRect(bx+9, by+1, 3, 10, ...body);
    cv.fillRect(bx-2, by+9, 3, 3, ...c.SKIN);
    cv.fillRect(bx+9, by+9, 3, 3, ...c.SKIN);
    // Legs
    if (hatStyle === 'hood') {
      cv.fillPoly([[bx-1, by+8],[bx+10, by+8],[bx+13, oy+46],[bx-4, oy+46]], ...body);
      cv.line(bx-4, oy+46, bx+13, oy+46, ...c.OUTLINE);
      cv.fillRect(bx+1+lx, oy+44, 4, 2, ...c.HAIR);
      cv.fillRect(bx+5+rx, oy+44, 4, 2, ...c.HAIR);
    } else {
      const ly = by+13;
      cv.fillRect(bx+1+lx, ly, 4, 10, ...body);
      cv.fillRect(bx+5+rx, ly, 4, 10, ...body);
      cv.fillRect(bx+0+lx, ly+8, 5, 3, ...c.HAIR);
      cv.fillRect(bx+4+rx, ly+8, 5, 3, ...c.HAIR);
      cv.line(bx+1+lx, ly, bx+1+lx, ly+9, ...c.OUTLINE);
      cv.line(bx+4+lx, ly, bx+4+lx, ly+9, ...c.OUTLINE);
      cv.line(bx+5+rx, ly, bx+5+rx, ly+9, ...c.OUTLINE);
      cv.line(bx+8+rx, ly, bx+8+rx, ly+9, ...c.OUTLINE);
    }
    for (let _sx=-6; _sx<=6; _sx++)
      cv.sp(ox+16+_sx, oy+37+dy, ...c.OUTLINE, Math.max(0, 20-Math.abs(_sx)*3));
  };

  // ── Generic east-facing (side profile) for faction archetypes ────────────────
  const drawNPC_east = (ox, oy, fac, dy=0, legOff=0) => {
    const { body, trim, hat, hatrim, hatStyle = 'default' } = fac;
    const hx = ox+14, hy = oy+2+dy;
    cv.fillRect(hx, hy, 7, 8, ...c.SKIN);
    cv.sp(hx+1, hy+1, ...c.SKIN_HI);
    cv.sp(hx+4, hy+3, ...c.HAIR);
    cv.sp(hx+4, hy+2, ...c.HAIR, 140);
    cv.sp(hx+6, hy+4, ...c.SKIN_SH);
    cv.sp(hx+5, hy+6, ...c.SKIN_SH, 160);
    cv.fillRect(hx-1, hy+3, 2, 3, ...c.SKIN);
    cv.sp(hx-1, hy+4, ...c.SKIN_SH);
    cv.line(hx,   hy,   hx+6, hy,   ...c.OUTLINE);
    cv.line(hx,   hy,   hx,   hy+7, ...c.OUTLINE);
    cv.line(hx+6, hy,   hx+6, hy+7, ...c.OUTLINE);
    cv.line(hx,   hy+7, hx+6, hy+7, ...c.OUTLINE);
    // Hat side view
    if (hatStyle === 'wide') {
      cv.fillRect(hx-3, hy-1, 11, 3, ...hat);
      cv.fillRect(hx+1, hy-5, 5, 5, ...hat);
      cv.line(hx-3, hy-1, hx+7, hy-1, ...c.OUTLINE);
      cv.line(hx+1, hy-5, hx+5, hy-5, ...c.OUTLINE);
    } else if (hatStyle === 'coronet') {
      cv.fillRect(hx+1, hy-2, 5, 3, ...hat);
      cv.fillRect(hx+3, hy-6, 2, 5, ...hat);
      cv.sp(hx+3, hy-6, ...hatrim);
      cv.line(hx+1, hy-2, hx+5, hy-2, ...c.OUTLINE);
    } else if (hatStyle === 'hood') {
      cv.fillRect(hx-1, hy-3, 9, 5, ...hat);
      cv.fillRect(hx-1, hy+2, 2, 7, ...hat);
      cv.line(hx-1, hy-3, hx+7, hy-3, ...c.OUTLINE);
    } else {
      cv.fillRect(hx, hy-1, 7, 3, ...hat);
      cv.fillRect(hx+1, hy-4, 5, 4, ...hat);
      cv.line(hx, hy-1, hx+6, hy-1, ...c.OUTLINE);
      cv.line(hx+1, hy-4, hx+5, hy-4, ...c.OUTLINE);
    }
    // Body side view (narrower: 8px wide)
    const bx = ox+13, by = oy+10+dy;
    cv.fillRect(bx, by, 8, 14, ...body);
    cv.fillRect(bx, by+6, 8, 2, ...trim);
    cv.fillRect(bx, by+1, 2, 12, ...c.OUTLINE, 50);
    cv.line(bx, by, bx+7, by, ...c.OUTLINE);
    cv.line(bx, by, bx, by+13, ...c.OUTLINE);
    cv.line(bx+7, by, bx+7, by+13, ...c.OUTLINE);
    cv.line(bx, by+13, bx+7, by+13, ...c.OUTLINE);
    // Near arm (front/right)
    cv.fillRect(bx+7, by+1, 3, 10, ...body);
    cv.fillRect(bx+7, by+9, 3, 3, ...c.SKIN);
    // Far arm (partially visible)
    cv.fillRect(bx-2, by+2, 2, 8, ...body, 160);
    // Faction prop side view
    const propFi = FACTIONS.indexOf(fac);
    if (propFi === 0) {
      cv.fillRect(bx-2, by+9, 3, 4, ...c.WOOD_M);
    } else if (propFi === 1) {
      cv.fillRect(bx+7, by+9, 2, 5, ...c.STONE_L);
    }
    // Legs side view
    if (hatStyle === 'hood') {
      cv.fillPoly([[bx+1, by+8],[bx+8, by+8],[bx+10, oy+46],[bx-1, oy+46]], ...body);
      cv.line(bx-1, oy+46, bx+10, oy+46, ...c.OUTLINE);
      cv.fillRect(bx+3+legOff, oy+44, 5, 2, ...c.HAIR);
    } else {
      const ly = by+13;
      cv.fillRect(bx+2+legOff, ly, 4, 10, ...body);
      cv.fillRect(bx+1+legOff, ly+8, 5, 3, ...c.HAIR);
      cv.fillRect(bx+3-legOff, ly+1, 3, 9, ...body, 155);
      cv.fillRect(bx+2-legOff, ly+8, 4, 2, ...c.HAIR, 130);
      cv.line(bx+2+legOff, ly, bx+2+legOff, ly+9, ...c.OUTLINE);
      cv.line(bx+5+legOff, ly, bx+5+legOff, ly+9, ...c.OUTLINE);
    }
    for (let _sx=-6; _sx<=6; _sx++)
      cv.sp(ox+16+_sx, oy+37+dy, ...c.OUTLINE, Math.max(0, 20-Math.abs(_sx)*3));
  };

  for (let fi=0; fi<3; fi++) {
    const oy = fi*48;
    const fac = FACTIONS[fi];

    // ── South idle (cols 0-1) ──
    drawNPC(0*32, oy, fac, 0, 0, 0);
    drawNPC(1*32, oy, fac, -1, 0, 0, 1, 1);
    // ── South walk (cols 2-4) ──
    drawNPC(2*32, oy, fac, 0, -2, 2, -2, 2);
    drawNPC(3*32, oy, fac, -1, 0, 0, 0, 0);
    drawNPC(4*32, oy, fac, 0, 2, -2, 2, -2);
    // ── North idle (cols 5-6) ──
    drawNPC_north(5*32, oy, fac, 0, 0, 0);
    drawNPC_north(6*32, oy, fac, -1, 0, 0);
    // ── North walk (cols 7-9) ──
    drawNPC_north(7*32, oy, fac, 0, 2, -2);
    drawNPC_north(8*32, oy, fac, -1, 0, 0);
    drawNPC_north(9*32, oy, fac, 0, -2, 2);
    // ── East idle (cols 10-11) ──
    drawNPC_east(10*32, oy, fac, 0, 0);
    drawNPC_east(11*32, oy, fac, -1, 0);
    // ── East walk (cols 12-14) ──
    drawNPC_east(12*32, oy, fac, 0, -3);
    drawNPC_east(13*32, oy, fac, -1, 0);
    drawNPC_east(14*32, oy, fac, 0, 3);
  }

  // ── Row 3: GUARD archetype ─────────────────────────────────────────────────
  // Stone tabard, round nasal helmet, armored arms — clearly military silhouette.
  const drawGuard = (ox, oy, dy=0, lx=0, rx=0) => {
    // head
    const hx = ox+12, hy = oy+2+dy;
    cv.fillRect(hx, hy, 8, 8, ...c.SKIN);
    // facial features (same improvements as drawNPC)
    cv.sp(hx+1, hy+1, ...c.SKIN_HI);
    cv.sp(hx+3, hy+5, ...c.SKIN_SH);
    cv.sp(hx+3, hy+7, ...c.OUTLINE, 80);
    cv.sp(hx+4, hy+7, ...c.OUTLINE, 80);
    cv.sp(hx+2, hy+3, ...c.HAIR);
    cv.sp(hx+5, hy+3, ...c.HAIR);
    cv.line(hx,   hy,   hx+7, hy,   ...c.OUTLINE);
    cv.line(hx,   hy,   hx,   hy+7, ...c.OUTLINE);
    cv.line(hx+7, hy,   hx+7, hy+7, ...c.OUTLINE);
    cv.line(hx,   hy+7, hx+7, hy+7, ...c.OUTLINE);

    // nasal helmet: crown + brim + nose-guard stripe
    cv.fillRect(hx-1, hy-3, 10, 5, ...c.STONE_M);  // helm crown
    cv.fillRect(hx-2, hy,   12, 2, ...c.STONE_D);  // helm brim
    cv.line(hx+4, hy-3, hx+4, hy+5, ...c.STONE_D); // nasal guard
    cv.line(hx-2, hy,   hx+9, hy,   ...c.OUTLINE);
    cv.line(hx-1, hy-3, hx+8, hy-3, ...c.OUTLINE);
    cv.line(hx-1, hy-3, hx-2, hy,   ...c.OUTLINE);
    cv.line(hx+8, hy-3, hx+9, hy,   ...c.OUTLINE);

    // stone tabard body (wider silhouette than civilian, 12px)
    const bx = ox+10, by = oy+10+dy;
    cv.fillRect(bx,   by,    12, 14, ...c.STONE_M);
    // shadow on right half
    cv.fillRect(bx+7, by+1,   4, 12, ...c.STONE_D);
    // tabard cross emblem
    cv.fillRect(bx+4, by+2,   3,  9, ...c.STONE_L);
    cv.fillRect(bx+2, by+5,   7,  3, ...c.STONE_L);
    // belt line
    cv.line(bx, by+9, bx+11, by+9, ...c.STONE_D);
    cv.line(bx,    by,    bx+11, by,    ...c.OUTLINE);
    cv.line(bx,    by,    bx,    by+13, ...c.OUTLINE);
    cv.line(bx+11, by,    bx+11, by+13, ...c.OUTLINE);
    cv.line(bx,    by+13, bx+11, by+13, ...c.OUTLINE);
    // additional right-face shadow (armor depth)
    cv.fillRect(bx+10, by+1, 2, 12, ...c.OUTLINE, 40);

    // armored pauldrons (slightly wider than faction arms)
    cv.fillRect(bx-2, by,    3, 11, ...c.STONE_M);
    cv.fillRect(bx+11,by,    3, 11, ...c.STONE_M);
    // gauntlets
    cv.fillRect(bx-2, by+8,  3,  4, ...c.STONE_D);
    cv.fillRect(bx+11,by+8,  3,  4, ...c.STONE_D);

    // legs in dark hose + heavier boots
    const ly = by+13;
    cv.fillRect(bx+1+lx, ly, 4, 10, ...c.STONE_D);
    cv.fillRect(bx+6+rx, ly, 4, 10, ...c.STONE_D);
    cv.fillRect(bx+0+lx, ly+8, 5, 3, ...c.HAIR);
    cv.fillRect(bx+5+rx, ly+8, 5, 3, ...c.HAIR);
    cv.line(bx+1+lx, ly, bx+1+lx, ly+9, ...c.OUTLINE);
    cv.line(bx+4+lx, ly, bx+4+lx, ly+9, ...c.OUTLINE);
    cv.line(bx+6+rx, ly, bx+6+rx, ly+9, ...c.OUTLINE);
    cv.line(bx+9+rx, ly, bx+9+rx, ly+9, ...c.OUTLINE);

    // ground cast shadow
    for (let _sx = -6; _sx <= 6; _sx++) {
      cv.sp(ox+16+_sx, oy+37+dy, ...c.OUTLINE, Math.max(0, 20-Math.abs(_sx)*3));
    }
    // spear (tall weapon on right side: shaft from ground to above head)
    const sx = ox+27;
    cv.line(sx, oy+2+dy-8, sx, oy+48, ...c.WOOD_M);        // shaft
    cv.line(sx, oy+2+dy-8, sx, oy+48, ...c.OUTLINE, 60);   // shadow edge
    // spearhead (small 3-pixel triangle)
    cv.sp(sx-1, oy+2+dy-8,  ...c.STONE_L);
    cv.sp(sx,   oy+2+dy-10, ...c.STONE_L);
    cv.sp(sx+1, oy+2+dy-8,  ...c.STONE_L);
    cv.line(sx-1, oy+2+dy-8, sx+1, oy+2+dy-8, ...c.OUTLINE);
  };

  const drawGuard_north = (ox, oy, dy=0, lx=0, rx=0) => {
    const hx = ox+12, hy = oy+2+dy;
    cv.fillRect(hx, hy, 8, 8, ...c.SKIN);
    cv.fillRect(hx, hy, 8, 4, ...c.HAIR);
    cv.sp(hx, hy+3, ...c.SKIN); cv.sp(hx+7, hy+3, ...c.SKIN);
    cv.line(hx, hy, hx, hy+7, ...c.OUTLINE);
    cv.line(hx+7, hy, hx+7, hy+7, ...c.OUTLINE);
    cv.line(hx, hy+7, hx+7, hy+7, ...c.OUTLINE);
    // Helmet back
    cv.fillRect(hx-1, hy-3, 10, 6, ...c.STONE_M);
    cv.fillRect(hx-2, hy,   12, 2, ...c.STONE_D);
    cv.line(hx-2, hy,   hx+9, hy,   ...c.OUTLINE);
    cv.line(hx-1, hy-3, hx+8, hy-3, ...c.OUTLINE);
    // Body back
    const bx = ox+10, by = oy+10+dy;
    cv.fillRect(bx, by, 12, 14, ...c.STONE_M);
    cv.fillRect(bx+7, by+1, 4, 12, ...c.STONE_D);
    cv.line(bx+6, by, bx+6, by+13, ...c.STONE_L, 60);
    cv.line(bx, by, bx+11, by, ...c.OUTLINE); cv.line(bx, by, bx, by+13, ...c.OUTLINE);
    cv.line(bx+11, by, bx+11, by+13, ...c.OUTLINE); cv.line(bx, by+13, bx+11, by+13, ...c.OUTLINE);
    cv.fillRect(bx-2, by, 3, 11, ...c.STONE_M); cv.fillRect(bx+11, by, 3, 11, ...c.STONE_M);
    cv.fillRect(bx-2, by+8, 3, 4, ...c.STONE_D); cv.fillRect(bx+11, by+8, 3, 4, ...c.STONE_D);
    const ly = by+13;
    cv.fillRect(bx+1+lx, ly, 4, 10, ...c.STONE_D); cv.fillRect(bx+6+rx, ly, 4, 10, ...c.STONE_D);
    cv.fillRect(bx+0+lx, ly+8, 5, 3, ...c.HAIR); cv.fillRect(bx+5+rx, ly+8, 5, 3, ...c.HAIR);
    cv.line(bx+1+lx, ly, bx+1+lx, ly+9, ...c.OUTLINE); cv.line(bx+4+lx, ly, bx+4+lx, ly+9, ...c.OUTLINE);
    cv.line(bx+6+rx, ly, bx+6+rx, ly+9, ...c.OUTLINE); cv.line(bx+9+rx, ly, bx+9+rx, ly+9, ...c.OUTLINE);
    for (let _sx=-6; _sx<=6; _sx++)
      cv.sp(ox+16+_sx, oy+37+dy, ...c.OUTLINE, Math.max(0, 20-Math.abs(_sx)*3));
  };

  const drawGuard_east = (ox, oy, dy=0, legOff=0) => {
    const hx = ox+14, hy = oy+2+dy;
    cv.fillRect(hx, hy, 7, 8, ...c.SKIN);
    cv.sp(hx+4, hy+3, ...c.HAIR); cv.sp(hx+4, hy+2, ...c.HAIR, 130);
    cv.sp(hx+6, hy+4, ...c.SKIN_SH);
    cv.fillRect(hx-1, hy+3, 2, 3, ...c.SKIN);
    cv.line(hx, hy, hx+6, hy, ...c.OUTLINE); cv.line(hx, hy, hx, hy+7, ...c.OUTLINE);
    cv.line(hx+6, hy, hx+6, hy+7, ...c.OUTLINE); cv.line(hx, hy+7, hx+6, hy+7, ...c.OUTLINE);
    // Helmet side
    cv.fillRect(hx-2, hy-3, 10, 5, ...c.STONE_M);
    cv.fillRect(hx-3, hy,   11, 2, ...c.STONE_D);
    cv.line(hx-3, hy, hx+7, hy, ...c.OUTLINE);
    cv.line(hx+4, hy-3, hx+4, hy+5, ...c.STONE_D);
    // Body side
    const bx = ox+13, by = oy+10+dy;
    cv.fillRect(bx, by, 8, 14, ...c.STONE_M);
    cv.fillRect(bx, by+1, 2, 12, ...c.STONE_D);
    cv.line(bx, by, bx+7, by, ...c.OUTLINE); cv.line(bx, by, bx, by+13, ...c.OUTLINE);
    cv.line(bx+7, by, bx+7, by+13, ...c.OUTLINE); cv.line(bx, by+13, bx+7, by+13, ...c.OUTLINE);
    cv.fillRect(bx+7, by, 3, 11, ...c.STONE_M); cv.fillRect(bx+7, by+8, 3, 4, ...c.STONE_D);
    // Spear in front
    const sx = bx+10;
    cv.line(sx, hy-10, sx, oy+47, ...c.WOOD_M);
    cv.sp(sx-1, hy-10, ...c.STONE_L); cv.sp(sx, hy-12, ...c.STONE_L); cv.sp(sx+1, hy-10, ...c.STONE_L);
    // Legs
    const ly = by+13;
    cv.fillRect(bx+2+legOff, ly, 4, 10, ...c.STONE_D);
    cv.fillRect(bx+1+legOff, ly+8, 5, 3, ...c.HAIR);
    cv.fillRect(bx+3-legOff, ly+1, 3, 9, ...c.STONE_D, 155);
    cv.fillRect(bx+2-legOff, ly+8, 4, 2, ...c.HAIR, 130);
    cv.line(bx+2+legOff, ly, bx+2+legOff, ly+9, ...c.OUTLINE);
    cv.line(bx+5+legOff, ly, bx+5+legOff, ly+9, ...c.OUTLINE);
    for (let _sx=-6; _sx<=6; _sx++)
      cv.sp(ox+16+_sx, oy+37+dy, ...c.OUTLINE, Math.max(0, 20-Math.abs(_sx)*3));
  };

  {
    const oy3 = 3*48;
    drawGuard(0*32, oy3, 0,  0,  0);
    drawGuard(1*32, oy3, -1, 0,  0);
    drawGuard(2*32, oy3, 0,  -2, 2);
    drawGuard(3*32, oy3, -1, 0,  0);
    drawGuard(4*32, oy3, 0,  2,  -2);
    drawGuard_north(5*32, oy3, 0,  0,  0);
    drawGuard_north(6*32, oy3, -1, 0,  0);
    drawGuard_north(7*32, oy3, 0,  2,  -2);
    drawGuard_north(8*32, oy3, -1, 0,  0);
    drawGuard_north(9*32, oy3, 0,  -2, 2);
    drawGuard_east(10*32, oy3, 0,  0);
    drawGuard_east(11*32, oy3, -1, 0);
    drawGuard_east(12*32, oy3, 0,  -3);
    drawGuard_east(13*32, oy3, -1, 0);
    drawGuard_east(14*32, oy3, 0,  3);
  }

  // ── Row 4: COMMONER archetype ──────────────────────────────────────────────
  // Drab linen tunic, simple cloth cap, worn boots — recognisably working-class.
  const drawCommoner = (ox, oy, dy=0, lx=0, rx=0) => {
    // head
    const hx = ox+12, hy = oy+2+dy;
    cv.fillRect(hx, hy, 8, 8, ...c.SKIN);
    // facial features
    cv.sp(hx+1, hy+1, ...c.SKIN_HI);
    cv.sp(hx+2, hy+2, ...c.HAIR, 150);
    cv.sp(hx+5, hy+2, ...c.HAIR, 150);
    cv.sp(hx+2, hy+3, ...c.HAIR);
    cv.sp(hx+5, hy+3, ...c.HAIR);
    cv.sp(hx+3, hy+5, ...c.SKIN_SH);
    cv.sp(hx+3, hy+7, ...c.OUTLINE, 90);
    cv.sp(hx+4, hy+7, ...c.OUTLINE, 90);
    cv.line(hx,   hy,   hx+7, hy,   ...c.OUTLINE);
    cv.line(hx,   hy,   hx,   hy+7, ...c.OUTLINE);
    cv.line(hx+7, hy,   hx+7, hy+7, ...c.OUTLINE);
    cv.line(hx,   hy+7, hx+7, hy+7, ...c.OUTLINE);

    // soft cloth cap — flatter and plainer than faction hat
    cv.fillRect(hx,   hy-1,  8,  3, ...c.THATCH_D);  // brim (no overhang)
    cv.fillRect(hx+1, hy-4,  6,  4, ...c.THATCH_D);  // crown
    cv.fillRect(hx+2, hy-5,  4,  2, ...c.DIRT_D);    // darker cap top
    cv.line(hx,   hy-1, hx+7, hy-1, ...c.OUTLINE);
    cv.line(hx+1, hy-4, hx+6, hy-4, ...c.OUTLINE);

    // plain linen tunic (slightly narrower, no trim badge)
    const bx = ox+11, by = oy+10+dy;
    cv.fillRect(bx, by, 10, 14, ...c.DIRT_M);
    // subtle pleat/seam lines
    cv.line(bx+3, by+1, bx+3, by+12, ...c.DIRT_D, 70);
    cv.line(bx+7, by+1, bx+7, by+12, ...c.DIRT_D, 70);
    // simple cloth belt (no gem badge)
    cv.fillRect(bx, by+7, 10, 2, ...c.DIRT_D);
    cv.line(bx,    by,    bx+9,  by,    ...c.OUTLINE);
    cv.line(bx,    by,    bx,    by+13, ...c.OUTLINE);
    cv.line(bx+9,  by,    bx+9,  by+13, ...c.OUTLINE);
    cv.line(bx,    by+13, bx+9,  by+13, ...c.OUTLINE);
    // right-side body shadow
    cv.fillRect(bx+8, by+1, 2, 12, ...c.OUTLINE, 50);

    // arms in matching tunic cloth
    cv.fillRect(bx-2, by+1, 3, 10, ...c.DIRT_M);
    cv.fillRect(bx+9, by+1, 3, 10, ...c.DIRT_M);
    // bare hands
    cv.fillRect(bx-2, by+9, 3, 3, ...c.SKIN);
    cv.fillRect(bx+9, by+9, 3, 3, ...c.SKIN);

    // legs in darker homespun + worn boots
    const ly = by+13;
    cv.fillRect(bx+1+lx, ly, 4, 10, ...c.DIRT_D);
    cv.fillRect(bx+5+rx, ly, 4, 10, ...c.DIRT_D);
    cv.fillRect(bx+0+lx, ly+8, 5, 3, ...c.WOOD_D);
    cv.fillRect(bx+4+rx, ly+8, 5, 3, ...c.WOOD_D);
    cv.line(bx+1+lx, ly, bx+1+lx, ly+9, ...c.OUTLINE);
    cv.line(bx+4+lx, ly, bx+4+lx, ly+9, ...c.OUTLINE);
    cv.line(bx+5+rx, ly, bx+5+rx, ly+9, ...c.OUTLINE);
    cv.line(bx+8+rx, ly, bx+8+rx, ly+9, ...c.OUTLINE);
    // ground cast shadow
    for (let _sx = -6; _sx <= 6; _sx++) {
      cv.sp(ox+16+_sx, oy+37+dy, ...c.OUTLINE, Math.max(0, 20-Math.abs(_sx)*3));
    }
  };

  const drawCommoner_north = (ox, oy, dy=0, lx=0, rx=0) => {
    const hx = ox+12, hy = oy+2+dy;
    cv.fillRect(hx, hy, 8, 8, ...c.SKIN);
    cv.fillRect(hx, hy, 8, 4, ...c.HAIR);
    cv.sp(hx, hy+3, ...c.SKIN); cv.sp(hx+7, hy+3, ...c.SKIN);
    cv.line(hx, hy, hx, hy+7, ...c.OUTLINE);
    cv.line(hx+7, hy, hx+7, hy+7, ...c.OUTLINE);
    cv.line(hx, hy+7, hx+7, hy+7, ...c.OUTLINE);
    // Cap back
    cv.fillRect(hx, hy-1, 8, 3, ...c.THATCH_D);
    cv.fillRect(hx+1, hy-4, 6, 4, ...c.THATCH_D);
    cv.fillRect(hx+2, hy-5, 4, 2, ...c.DIRT_D);
    cv.line(hx, hy-1, hx+7, hy-1, ...c.OUTLINE);
    cv.line(hx+1, hy-4, hx+6, hy-4, ...c.OUTLINE);
    // Body back
    const bx = ox+11, by = oy+10+dy;
    cv.fillRect(bx, by, 10, 14, ...c.DIRT_M);
    cv.line(bx+5, by, bx+5, by+13, ...c.DIRT_D, 80);
    cv.fillRect(bx, by+7, 10, 2, ...c.DIRT_D);
    cv.line(bx, by, bx+9, by, ...c.OUTLINE); cv.line(bx, by, bx, by+13, ...c.OUTLINE);
    cv.line(bx+9, by, bx+9, by+13, ...c.OUTLINE); cv.line(bx, by+13, bx+9, by+13, ...c.OUTLINE);
    cv.fillRect(bx, by+1, 2, 12, ...c.OUTLINE, 45);
    cv.fillRect(bx-2, by+1, 3, 10, ...c.DIRT_M); cv.fillRect(bx+9, by+1, 3, 10, ...c.DIRT_M);
    cv.fillRect(bx-2, by+9, 3, 3, ...c.SKIN); cv.fillRect(bx+9, by+9, 3, 3, ...c.SKIN);
    const ly = by+13;
    cv.fillRect(bx+1+lx, ly, 4, 10, ...c.DIRT_D); cv.fillRect(bx+5+rx, ly, 4, 10, ...c.DIRT_D);
    cv.fillRect(bx+0+lx, ly+8, 5, 3, ...c.WOOD_D); cv.fillRect(bx+4+rx, ly+8, 5, 3, ...c.WOOD_D);
    cv.line(bx+1+lx, ly, bx+1+lx, ly+9, ...c.OUTLINE); cv.line(bx+4+lx, ly, bx+4+lx, ly+9, ...c.OUTLINE);
    cv.line(bx+5+rx, ly, bx+5+rx, ly+9, ...c.OUTLINE); cv.line(bx+8+rx, ly, bx+8+rx, ly+9, ...c.OUTLINE);
    for (let _sx=-6; _sx<=6; _sx++)
      cv.sp(ox+16+_sx, oy+37+dy, ...c.OUTLINE, Math.max(0, 20-Math.abs(_sx)*3));
  };

  const drawCommoner_east = (ox, oy, dy=0, legOff=0) => {
    const hx = ox+14, hy = oy+2+dy;
    cv.fillRect(hx, hy, 7, 8, ...c.SKIN);
    cv.sp(hx+1, hy+1, ...c.SKIN_HI);
    cv.sp(hx+4, hy+3, ...c.HAIR); cv.sp(hx+4, hy+2, ...c.HAIR, 130);
    cv.sp(hx+6, hy+4, ...c.SKIN_SH); cv.sp(hx+5, hy+6, ...c.SKIN_SH, 140);
    cv.fillRect(hx-1, hy+3, 2, 3, ...c.SKIN);
    cv.line(hx, hy, hx+6, hy, ...c.OUTLINE); cv.line(hx, hy, hx, hy+7, ...c.OUTLINE);
    cv.line(hx+6, hy, hx+6, hy+7, ...c.OUTLINE); cv.line(hx, hy+7, hx+6, hy+7, ...c.OUTLINE);
    // Cap side
    cv.fillRect(hx, hy-1, 7, 3, ...c.THATCH_D);
    cv.fillRect(hx+1, hy-4, 5, 4, ...c.THATCH_D);
    cv.line(hx, hy-1, hx+6, hy-1, ...c.OUTLINE);
    const bx = ox+13, by = oy+10+dy;
    cv.fillRect(bx, by, 8, 14, ...c.DIRT_M);
    cv.fillRect(bx, by+7, 8, 2, ...c.DIRT_D);
    cv.fillRect(bx, by+1, 2, 12, ...c.OUTLINE, 45);
    cv.line(bx, by, bx+7, by, ...c.OUTLINE); cv.line(bx, by, bx, by+13, ...c.OUTLINE);
    cv.line(bx+7, by, bx+7, by+13, ...c.OUTLINE); cv.line(bx, by+13, bx+7, by+13, ...c.OUTLINE);
    cv.fillRect(bx+7, by+1, 3, 10, ...c.DIRT_M); cv.fillRect(bx+7, by+9, 3, 3, ...c.SKIN);
    cv.fillRect(bx-2, by+2, 2, 8, ...c.DIRT_M, 155);
    const ly = by+13;
    cv.fillRect(bx+2+legOff, ly, 4, 10, ...c.DIRT_D);
    cv.fillRect(bx+1+legOff, ly+8, 5, 3, ...c.WOOD_D);
    cv.fillRect(bx+3-legOff, ly+1, 3, 9, ...c.DIRT_D, 155);
    cv.fillRect(bx+2-legOff, ly+8, 4, 2, ...c.WOOD_D, 130);
    cv.line(bx+2+legOff, ly, bx+2+legOff, ly+9, ...c.OUTLINE);
    cv.line(bx+5+legOff, ly, bx+5+legOff, ly+9, ...c.OUTLINE);
    for (let _sx=-6; _sx<=6; _sx++)
      cv.sp(ox+16+_sx, oy+37+dy, ...c.OUTLINE, Math.max(0, 20-Math.abs(_sx)*3));
  };

  {
    const oy4 = 4*48;
    drawCommoner(0*32, oy4, 0,  0,  0);
    drawCommoner(1*32, oy4, -1, 0,  0);
    drawCommoner(2*32, oy4, 0,  -2, 2);
    drawCommoner(3*32, oy4, -1, 0,  0);
    drawCommoner(4*32, oy4, 0,  2,  -2);
    drawCommoner_north(5*32, oy4, 0,  0,  0);
    drawCommoner_north(6*32, oy4, -1, 0,  0);
    drawCommoner_north(7*32, oy4, 0,  2,  -2);
    drawCommoner_north(8*32, oy4, -1, 0,  0);
    drawCommoner_north(9*32, oy4, 0,  -2, 2);
    drawCommoner_east(10*32, oy4, 0,  0);
    drawCommoner_east(11*32, oy4, -1, 0);
    drawCommoner_east(12*32, oy4, 0,  -3);
    drawCommoner_east(13*32, oy4, -1, 0);
    drawCommoner_east(14*32, oy4, 0,  3);
  }

  // ── Row 5: TAVERN STAFF archetype ─────────────────────────────────────────
  // Cream apron over rustic brown tunic, parchment head-kerchief, sleeves
  // rolled up — clearly working hospitality, distinct from commoner/merchant.
  const drawTavernStaff = (ox, oy, dy=0, lx=0, rx=0, laY=0, raY=0) => {
    // head
    const hx = ox+12, hy = oy+2+dy;
    cv.fillRect(hx, hy, 8, 8, ...c.SKIN);
    // facial features (friendly expression with slight smile)
    cv.sp(hx+1, hy+1, ...c.SKIN_HI);
    cv.sp(hx+2, hy+2, ...c.HAIR, 150);
    cv.sp(hx+5, hy+2, ...c.HAIR, 150);
    cv.sp(hx+2, hy+3, ...c.HAIR);
    cv.sp(hx+5, hy+3, ...c.HAIR);
    cv.sp(hx+3, hy+5, ...c.SKIN_SH);
    // slight smile
    cv.sp(hx+2, hy+6, ...c.SKIN_SH, 120);
    cv.sp(hx+3, hy+7, ...c.OUTLINE, 80);
    cv.sp(hx+4, hy+7, ...c.OUTLINE, 80);
    cv.sp(hx+5, hy+6, ...c.SKIN_SH, 120);
    // rosy cheeks (tavern warmth)
    cv.sp(hx+1, hy+5, 220, 160, 140, 80);
    cv.sp(hx+6, hy+5, 220, 160, 140, 80);
    cv.line(hx,   hy,   hx+7, hy,   ...c.OUTLINE);
    cv.line(hx,   hy,   hx,   hy+7, ...c.OUTLINE);
    cv.line(hx+7, hy,   hx+7, hy+7, ...c.OUTLINE);
    cv.line(hx,   hy+7, hx+7, hy+7, ...c.OUTLINE);

    // head kerchief (wrapped cloth, wider than commoner cap, knotted right side)
    cv.fillRect(hx-1, hy-2, 10, 3, ...c.PARCH_L);  // main kerchief band
    cv.fillRect(hx,   hy-4, 8,  3, ...c.PARCH_M);  // crown of kerchief
    cv.line(hx-1, hy-2, hx+8, hy-2, ...c.OUTLINE);
    cv.line(hx,   hy-4, hx+7, hy-4, ...c.OUTLINE);
    // knot at right side
    cv.fillRect(hx+7, hy-2, 3, 3, ...c.PARCH_D);
    cv.line(hx+7, hy-2, hx+9, hy-2, ...c.OUTLINE);

    // body: rustic brown tunic
    const bx = ox+11, by = oy+10+dy;
    cv.fillRect(bx, by, 10, 14, ...c.WOOD_L);
    // apron bib (upper front of apron)
    cv.fillRect(bx+2, by, 6, 4, ...c.PARCH_L);
    // apron body (covers front of torso + below belt)
    cv.fillRect(bx+1, by+3, 8, 11, ...c.PARCH_L);
    // apron tie strings at waist
    cv.line(bx+1, by+4, bx-1, by+3, ...c.PARCH_D);
    cv.line(bx+8, by+4, bx+10, by+3, ...c.PARCH_D);
    // belt (dark, cinching the apron)
    cv.fillRect(bx+1, by+7, 8, 2, ...c.DIRT_D);
    // subtle crease lines on apron
    cv.line(bx+4, by+3, bx+4, by+13, ...c.PARCH_M, 80);
    // body outline
    cv.line(bx,    by,    bx+9,  by,    ...c.OUTLINE);
    cv.line(bx,    by,    bx,    by+13, ...c.OUTLINE);
    cv.line(bx+9,  by,    bx+9,  by+13, ...c.OUTLINE);
    cv.line(bx,    by+13, bx+9,  by+13, ...c.OUTLINE);
    // right-side body shadow
    cv.fillRect(bx+8, by+1, 2, 12, ...c.OUTLINE, 50);

    // arms: rolled-up sleeves — swing via laY/raY
    const laLen = 11 - Math.abs(laY);
    const raLen = 11 - Math.abs(raY);
    const laSkin = Math.max(4 - Math.abs(laY), 2);  // bare forearm shrinks when swung
    const raSkin = Math.max(4 - Math.abs(raY), 2);
    cv.fillRect(bx-2, by+1+laY, 3, laLen - laSkin, ...c.WOOD_L);  // sleeve
    cv.fillRect(bx+9, by+1+raY, 3, raLen - raSkin, ...c.WOOD_L);
    cv.fillRect(bx-2, by+1+laY+(laLen-laSkin), 3, laSkin, ...c.SKIN);  // bare forearm L
    cv.fillRect(bx+9, by+1+raY+(raLen-raSkin), 3, raSkin, ...c.SKIN);  // bare forearm R
    // rolled cuff marks at sleeve-to-skin transition
    cv.line(bx-2, by+1+laY+(laLen-laSkin), bx, by+1+laY+(laLen-laSkin), ...c.WOOD_M);
    cv.line(bx+9, by+1+raY+(raLen-raSkin), bx+11, by+1+raY+(raLen-raSkin), ...c.WOOD_M);

    // legs: dark hose + sturdy boots
    const ly = by+13;
    cv.fillRect(bx+1+lx, ly, 4, 10, ...c.DIRT_D);
    cv.fillRect(bx+5+rx, ly, 4, 10, ...c.DIRT_D);
    cv.fillRect(bx+0+lx, ly+8, 5, 3, ...c.WOOD_D);
    cv.fillRect(bx+4+rx, ly+8, 5, 3, ...c.WOOD_D);
    cv.line(bx+1+lx, ly, bx+1+lx, ly+9, ...c.OUTLINE);
    cv.line(bx+4+lx, ly, bx+4+lx, ly+9, ...c.OUTLINE);
    cv.line(bx+5+rx, ly, bx+5+rx, ly+9, ...c.OUTLINE);
    cv.line(bx+8+rx, ly, bx+8+rx, ly+9, ...c.OUTLINE);
    // ground cast shadow
    for (let _sx = -6; _sx <= 6; _sx++) {
      cv.sp(ox+16+_sx, oy+37+dy, ...c.OUTLINE, Math.max(0, 20-Math.abs(_sx)*3));
    }
  };

  const drawTavernStaff_north = (ox, oy, dy=0, lx=0, rx=0) => {
    const hx = ox+12, hy = oy+2+dy;
    cv.fillRect(hx, hy, 8, 8, ...c.SKIN);
    cv.fillRect(hx, hy, 8, 4, ...c.HAIR);
    cv.sp(hx, hy+3, ...c.SKIN); cv.sp(hx+7, hy+3, ...c.SKIN);
    cv.line(hx, hy, hx, hy+7, ...c.OUTLINE);
    cv.line(hx+7, hy, hx+7, hy+7, ...c.OUTLINE);
    cv.line(hx, hy+7, hx+7, hy+7, ...c.OUTLINE);
    // Kerchief back (knot visible at back of head)
    cv.fillRect(hx-1, hy-2, 10, 3, ...c.PARCH_L);
    cv.fillRect(hx, hy-4, 8, 3, ...c.PARCH_M);
    cv.line(hx-1, hy-2, hx+8, hy-2, ...c.OUTLINE);
    cv.fillRect(hx+3, hy-2, 3, 4, ...c.PARCH_D); // back knot
    cv.line(hx+3, hy+1, hx+5, hy+3, ...c.PARCH_D); // tie end
    // Body back
    const bx = ox+11, by = oy+10+dy;
    cv.fillRect(bx, by, 10, 14, ...c.WOOD_L);
    cv.fillRect(bx+1, by+3, 8, 11, ...c.PARCH_L);
    cv.line(bx+4, by+3, bx+4, by+13, ...c.PARCH_M, 80);
    cv.fillRect(bx+1, by+7, 8, 2, ...c.DIRT_D);
    cv.line(bx, by, bx+9, by, ...c.OUTLINE); cv.line(bx, by, bx, by+13, ...c.OUTLINE);
    cv.line(bx+9, by, bx+9, by+13, ...c.OUTLINE); cv.line(bx, by+13, bx+9, by+13, ...c.OUTLINE);
    cv.fillRect(bx, by+1, 2, 12, ...c.OUTLINE, 45);
    cv.fillRect(bx-2, by+1, 3, 9, ...c.WOOD_L); cv.fillRect(bx+9, by+1, 3, 9, ...c.WOOD_L);
    cv.fillRect(bx-2, by+9, 3, 3, ...c.SKIN); cv.fillRect(bx+9, by+9, 3, 3, ...c.SKIN);
    const ly = by+13;
    cv.fillRect(bx+1+lx, ly, 4, 10, ...c.DIRT_D); cv.fillRect(bx+5+rx, ly, 4, 10, ...c.DIRT_D);
    cv.fillRect(bx+0+lx, ly+8, 5, 3, ...c.WOOD_D); cv.fillRect(bx+4+rx, ly+8, 5, 3, ...c.WOOD_D);
    cv.line(bx+1+lx, ly, bx+1+lx, ly+9, ...c.OUTLINE); cv.line(bx+4+lx, ly, bx+4+lx, ly+9, ...c.OUTLINE);
    cv.line(bx+5+rx, ly, bx+5+rx, ly+9, ...c.OUTLINE); cv.line(bx+8+rx, ly, bx+8+rx, ly+9, ...c.OUTLINE);
    for (let _sx=-6; _sx<=6; _sx++)
      cv.sp(ox+16+_sx, oy+37+dy, ...c.OUTLINE, Math.max(0, 20-Math.abs(_sx)*3));
  };

  const drawTavernStaff_east = (ox, oy, dy=0, legOff=0) => {
    const hx = ox+14, hy = oy+2+dy;
    cv.fillRect(hx, hy, 7, 8, ...c.SKIN);
    cv.sp(hx+1, hy+1, ...c.SKIN_HI);
    cv.sp(hx+4, hy+3, ...c.HAIR); cv.sp(hx+4, hy+2, ...c.HAIR, 130);
    cv.sp(hx+6, hy+4, ...c.SKIN_SH);
    cv.sp(hx+1, hy+5, 220, 160, 140, 70); // rosy cheek visible in profile
    cv.fillRect(hx-1, hy+3, 2, 3, ...c.SKIN);
    cv.line(hx, hy, hx+6, hy, ...c.OUTLINE); cv.line(hx, hy, hx, hy+7, ...c.OUTLINE);
    cv.line(hx+6, hy, hx+6, hy+7, ...c.OUTLINE); cv.line(hx, hy+7, hx+6, hy+7, ...c.OUTLINE);
    // Kerchief side
    cv.fillRect(hx, hy-2, 8, 3, ...c.PARCH_L);
    cv.fillRect(hx+1, hy-4, 6, 3, ...c.PARCH_M);
    cv.line(hx, hy-2, hx+7, hy-2, ...c.OUTLINE);
    const bx = ox+13, by = oy+10+dy;
    cv.fillRect(bx, by, 8, 14, ...c.WOOD_L);
    cv.fillRect(bx+1, by+2, 6, 12, ...c.PARCH_L);
    cv.fillRect(bx+1, by+6, 6, 2, ...c.DIRT_D);
    cv.fillRect(bx, by+1, 2, 12, ...c.OUTLINE, 45);
    cv.line(bx, by, bx+7, by, ...c.OUTLINE); cv.line(bx, by, bx, by+13, ...c.OUTLINE);
    cv.line(bx+7, by, bx+7, by+13, ...c.OUTLINE); cv.line(bx, by+13, bx+7, by+13, ...c.OUTLINE);
    cv.fillRect(bx+7, by+1, 3, 8, ...c.WOOD_L); cv.fillRect(bx+7, by+9, 3, 3, ...c.SKIN);
    cv.fillRect(bx-2, by+2, 2, 7, ...c.WOOD_L, 155);
    const ly = by+13;
    cv.fillRect(bx+2+legOff, ly, 4, 10, ...c.DIRT_D);
    cv.fillRect(bx+1+legOff, ly+8, 5, 3, ...c.WOOD_D);
    cv.fillRect(bx+3-legOff, ly+1, 3, 9, ...c.DIRT_D, 155);
    cv.fillRect(bx+2-legOff, ly+8, 4, 2, ...c.WOOD_D, 130);
    cv.line(bx+2+legOff, ly, bx+2+legOff, ly+9, ...c.OUTLINE);
    cv.line(bx+5+legOff, ly, bx+5+legOff, ly+9, ...c.OUTLINE);
    for (let _sx=-6; _sx<=6; _sx++)
      cv.sp(ox+16+_sx, oy+37+dy, ...c.OUTLINE, Math.max(0, 20-Math.abs(_sx)*3));
  };

  {
    const oy5 = 5*48;
    drawTavernStaff(0*32, oy5, 0,  0,  0,  0,  0);
    drawTavernStaff(1*32, oy5, -1, 0,  0,  1,  1);
    drawTavernStaff(2*32, oy5, 0,  -2, 2,  -2, 2);
    drawTavernStaff(3*32, oy5, -1, 0,  0,   0, 0);
    drawTavernStaff(4*32, oy5, 0,  2,  -2,  2, -2);
    drawTavernStaff_north(5*32, oy5, 0,  0,  0);
    drawTavernStaff_north(6*32, oy5, -1, 0,  0);
    drawTavernStaff_north(7*32, oy5, 0,  2,  -2);
    drawTavernStaff_north(8*32, oy5, -1, 0,  0);
    drawTavernStaff_north(9*32, oy5, 0,  -2, 2);
    drawTavernStaff_east(10*32, oy5, 0,  0);
    drawTavernStaff_east(11*32, oy5, -1, 0);
    drawTavernStaff_east(12*32, oy5, 0,  -3);
    drawTavernStaff_east(13*32, oy5, -1, 0);
    drawTavernStaff_east(14*32, oy5, 0,  3);
  }


  // ── Row 6: SCHOLAR archetype ──────────────────────────────────────────────
  // Ink-blue robe, red faculty cuffs, square mortarboard skullcap, scroll.
  const drawScholar = (ox, oy, dy=0, lx=0, rx=0, laY=0, raY=0) => {
    const hx = ox+12, hy = oy+2+dy;
    cv.fillRect(hx, hy, 8, 8, ...c.SKIN);
    cv.sp(hx+1, hy+1, ...c.SKIN_HI);
    cv.sp(hx+2, hy+2, ...c.HAIR, 160);
    cv.sp(hx+5, hy+2, ...c.HAIR, 160);
    cv.sp(hx+2, hy+3, ...c.HAIR);
    cv.sp(hx+5, hy+3, ...c.HAIR);
    cv.sp(hx+3, hy+5, ...c.SKIN_SH);
    cv.sp(hx+3, hy+7, ...c.OUTLINE, 90);
    cv.sp(hx+4, hy+7, ...c.OUTLINE, 90);
    cv.line(hx, hy, hx+7, hy, ...c.OUTLINE);
    cv.line(hx, hy, hx, hy+7, ...c.OUTLINE);
    cv.line(hx+7, hy, hx+7, hy+7, ...c.OUTLINE);
    cv.line(hx, hy+7, hx+7, hy+7, ...c.OUTLINE);
    // square mortarboard skullcap (flat-topped = clearly academic)
    cv.fillRect(hx, hy-4, 8, 5, ...c.ROOF_SLATE);
    cv.fillRect(hx-1, hy-1, 10, 2, ...c.STONE_D);
    cv.line(hx-1, hy-1, hx+8, hy-1, ...c.OUTLINE);
    cv.line(hx, hy-4, hx+7, hy-4, ...c.OUTLINE);
    const bx = ox+11, by = oy+10+dy;
    cv.fillRect(bx, by, 10, 14, ...c.MERCH_B);
    cv.fillRect(bx, by+11, 10, 3, ...c.FLAG_R);   // red faculty cuffs
    cv.sp(bx+3, by+3, ...c.STONE_D, 120);         // ink-stain spot
    cv.sp(bx+5, by+5, ...c.STONE_D, 90);
    cv.fillRect(bx, by+6, 10, 2, ...c.STONE_D);   // belt/sash
    cv.line(bx, by, bx+9, by, ...c.OUTLINE);
    cv.line(bx, by, bx, by+13, ...c.OUTLINE);
    cv.line(bx+9, by, bx+9, by+13, ...c.OUTLINE);
    cv.line(bx, by+13, bx+9, by+13, ...c.OUTLINE);
    // right-side body shadow
    cv.fillRect(bx+8, by+1, 2, 12, ...c.OUTLINE, 50);
    const laLen = 10 - Math.abs(laY);
    const raLen = 10 - Math.abs(raY);
    cv.fillRect(bx-2, by+1+laY, 3, laLen, ...c.MERCH_B);
    cv.fillRect(bx+9, by+1+raY, 3, raLen, ...c.MERCH_B);
    cv.fillRect(bx-2, by+1+laY+laLen-2, 3, 2, ...c.FLAG_R);
    cv.fillRect(bx+9, by+1+raY+raLen-2, 3, 2, ...c.FLAG_R);
    cv.fillRect(bx-2, by+1+laY+laLen, 3, 2, ...c.SKIN);
    cv.fillRect(bx+9, by+1+raY+raLen, 3, 2, ...c.SKIN);
    cv.fillPoly([
      [bx-1, by+8], [bx+10, by+8],
      [bx+12, oy+46], [bx-3, oy+46],
    ], ...c.MERCH_B);
    cv.line(bx-3, oy+46, bx+12, oy+46, ...c.OUTLINE);
    cv.fillRect(bx+1+lx, oy+44, 4, 2, ...c.STONE_D);
    cv.fillRect(bx+5+rx, oy+44, 4, 2, ...c.STONE_D);
    // ground cast shadow (robe style)
    for (let _sx = -6; _sx <= 6; _sx++) {
      cv.sp(ox+16+_sx, oy+47, ...c.OUTLINE, Math.max(0, 18-Math.abs(_sx)*3));
    }
    // parchment scroll in left hand
    const sx = bx-5, sy = by+4;
    cv.fillRect(sx, sy, 4, 7, ...c.PARCH_L);
    cv.line(sx, sy, sx+3, sy, ...c.PARCH_D);
    cv.line(sx, sy+6, sx+3, sy+6, ...c.PARCH_D);
    cv.line(sx-1, sy, sx-1, sy+7, ...c.WOOD_D);
    cv.line(sx+4, sy, sx+4, sy+7, ...c.WOOD_D);
  };
  const drawScholar_north = (ox, oy, dy=0, lx=0, rx=0) => {
    const hx = ox+12, hy = oy+2+dy;
    cv.fillRect(hx, hy, 8, 8, ...c.SKIN);
    cv.fillRect(hx, hy, 8, 4, ...c.HAIR);
    cv.sp(hx, hy+3, ...c.SKIN); cv.sp(hx+7, hy+3, ...c.SKIN);
    cv.line(hx, hy, hx, hy+7, ...c.OUTLINE);
    cv.line(hx+7, hy, hx+7, hy+7, ...c.OUTLINE);
    cv.line(hx, hy+7, hx+7, hy+7, ...c.OUTLINE);
    // Mortarboard from behind (flat top very readable)
    cv.fillRect(hx, hy-4, 8, 5, ...c.ROOF_SLATE);
    cv.fillRect(hx-1, hy-1, 10, 2, ...c.STONE_D);
    cv.line(hx, hy-4, hx+7, hy-4, ...c.OUTLINE);
    cv.line(hx-1, hy-1, hx+8, hy-1, ...c.OUTLINE);
    // Body back (ink-blue robe)
    const bx = ox+11, by = oy+10+dy;
    cv.fillRect(bx, by, 10, 14, ...c.MERCH_B);
    cv.fillRect(bx, by+11, 10, 3, ...c.FLAG_R);
    cv.line(bx+5, by, bx+5, by+13, ...c.MERCH_B, 170);
    cv.fillRect(bx, by+6, 10, 2, ...c.STONE_D);
    cv.line(bx, by, bx+9, by, ...c.OUTLINE); cv.line(bx, by, bx, by+13, ...c.OUTLINE);
    cv.line(bx+9, by, bx+9, by+13, ...c.OUTLINE); cv.line(bx, by+13, bx+9, by+13, ...c.OUTLINE);
    cv.fillRect(bx, by+1, 2, 12, ...c.OUTLINE, 40);
    cv.fillRect(bx-2, by+1, 3, 9, ...c.MERCH_B); cv.fillRect(bx+9, by+1, 3, 9, ...c.MERCH_B);
    cv.fillRect(bx-2, by+9, 3, 2, ...c.FLAG_R); cv.fillRect(bx+9, by+9, 3, 2, ...c.FLAG_R);
    cv.fillRect(bx-2, by+11, 3, 2, ...c.SKIN); cv.fillRect(bx+9, by+11, 3, 2, ...c.SKIN);
    cv.fillPoly([[bx-1, by+8],[bx+10, by+8],[bx+12, oy+46],[bx-3, oy+46]], ...c.MERCH_B);
    cv.line(bx-3, oy+46, bx+12, oy+46, ...c.OUTLINE);
    cv.fillRect(bx+1+lx, oy+44, 4, 2, ...c.STONE_D); cv.fillRect(bx+5+rx, oy+44, 4, 2, ...c.STONE_D);
    for (let _sx=-6; _sx<=6; _sx++)
      cv.sp(ox+16+_sx, oy+47, ...c.OUTLINE, Math.max(0, 18-Math.abs(_sx)*3));
  };

  const drawScholar_east = (ox, oy, dy=0, legOff=0) => {
    const hx = ox+14, hy = oy+2+dy;
    cv.fillRect(hx, hy, 7, 8, ...c.SKIN);
    cv.sp(hx+1, hy+1, ...c.SKIN_HI);
    cv.sp(hx+4, hy+3, ...c.HAIR); cv.sp(hx+4, hy+2, ...c.HAIR, 140);
    cv.sp(hx+6, hy+4, ...c.SKIN_SH); cv.sp(hx+5, hy+6, ...c.SKIN_SH, 140);
    cv.fillRect(hx-1, hy+3, 2, 3, ...c.SKIN);
    cv.line(hx, hy, hx+6, hy, ...c.OUTLINE); cv.line(hx, hy, hx, hy+7, ...c.OUTLINE);
    cv.line(hx+6, hy, hx+6, hy+7, ...c.OUTLINE); cv.line(hx, hy+7, hx+6, hy+7, ...c.OUTLINE);
    // Mortarboard side (flat top + brim visible from side = very scholarly)
    cv.fillRect(hx, hy-4, 7, 5, ...c.ROOF_SLATE);
    cv.fillRect(hx-1, hy-1, 9, 2, ...c.STONE_D);
    cv.line(hx-1, hy-1, hx+7, hy-1, ...c.OUTLINE);
    cv.line(hx, hy-4, hx+6, hy-4, ...c.OUTLINE);
    const bx = ox+13, by = oy+10+dy;
    cv.fillRect(bx, by, 8, 14, ...c.MERCH_B);
    cv.fillRect(bx, by+11, 8, 3, ...c.FLAG_R);
    cv.fillRect(bx, by+6, 8, 2, ...c.STONE_D);
    cv.fillRect(bx, by+1, 2, 12, ...c.OUTLINE, 45);
    cv.line(bx, by, bx+7, by, ...c.OUTLINE); cv.line(bx, by, bx, by+13, ...c.OUTLINE);
    cv.line(bx+7, by, bx+7, by+13, ...c.OUTLINE); cv.line(bx, by+13, bx+7, by+13, ...c.OUTLINE);
    cv.fillRect(bx+7, by+1, 3, 8, ...c.MERCH_B); cv.fillRect(bx+7, by+9, 3, 2, ...c.FLAG_R);
    cv.fillRect(bx+7, by+11, 3, 2, ...c.SKIN);
    // Scroll in near hand
    cv.fillRect(bx+10, by+3, 4, 7, ...c.PARCH_L);
    cv.line(bx+10, by+3, bx+13, by+3, ...c.PARCH_D);
    cv.line(bx+10, by+9, bx+13, by+9, ...c.PARCH_D);
    // Robe skirt side
    cv.fillPoly([[bx+1, by+8],[bx+8, by+8],[bx+10, oy+46],[bx-1, oy+46]], ...c.MERCH_B);
    cv.line(bx-1, oy+46, bx+10, oy+46, ...c.OUTLINE);
    cv.fillRect(bx+3+legOff, oy+44, 5, 2, ...c.STONE_D);
    for (let _sx=-6; _sx<=6; _sx++)
      cv.sp(ox+16+_sx, oy+47, ...c.OUTLINE, Math.max(0, 18-Math.abs(_sx)*3));
  };

  {
    const oy6 = 6*48;
    drawScholar(0*32, oy6, 0,  0,  0,  0,  0);
    drawScholar(1*32, oy6, -1, 0,  0,  1,  1);
    drawScholar(2*32, oy6, 0,  -2, 2,  -2, 2);
    drawScholar(3*32, oy6, -1, 0,  0,   0, 0);
    drawScholar(4*32, oy6, 0,  2,  -2,  2, -2);
    drawScholar_north(5*32, oy6, 0,  0,  0);
    drawScholar_north(6*32, oy6, -1, 0,  0);
    drawScholar_north(7*32, oy6, 0,  2,  -2);
    drawScholar_north(8*32, oy6, -1, 0,  0);
    drawScholar_north(9*32, oy6, 0,  -2, 2);
    drawScholar_east(10*32, oy6, 0,  0);
    drawScholar_east(11*32, oy6, -1, 0);
    drawScholar_east(12*32, oy6, 0,  -3);
    drawScholar_east(13*32, oy6, -1, 0);
    drawScholar_east(14*32, oy6, 0,  3);
  }

  // ── Row 7: ELDER archetype ────────────────────────────────────────────────
  // Stooped grey robe, white temples, open hood, walking staff, lower stance.
  const drawElder = (ox, oy, dy=0, lx=0, rx=0) => {
    const hx = ox+12, hy = oy+4+dy;   // lower stance (+2px)
    cv.fillRect(hx, hy, 8, 8, ...c.SKIN);
    cv.sp(hx+1, hy+1, ...c.SKIN_HI);
    cv.sp(hx+1, hy+2, ...c.PARCH_L, 200);  // white temple hair
    cv.sp(hx+6, hy+2, ...c.PARCH_L, 200);
    cv.sp(hx+2, hy+3, ...c.STONE_L);       // pale aged eyes
    cv.sp(hx+5, hy+3, ...c.STONE_L);
    cv.sp(hx+3, hy+5, ...c.SKIN_SH);
    cv.sp(hx+1, hy+5, ...c.SKIN_SH, 80);   // wrinkle lines
    cv.sp(hx+6, hy+5, ...c.SKIN_SH, 80);
    cv.sp(hx+3, hy+7, ...c.OUTLINE, 70);
    cv.sp(hx+4, hy+7, ...c.OUTLINE, 70);
    cv.line(hx, hy, hx+7, hy, ...c.OUTLINE);
    cv.line(hx, hy, hx, hy+7, ...c.OUTLINE);
    cv.line(hx+7, hy, hx+7, hy+7, ...c.OUTLINE);
    cv.line(hx, hy+7, hx+7, hy+7, ...c.OUTLINE);
    // open hood showing white hair on sides
    cv.fillRect(hx-1, hy-3, 10, 4, ...c.STONE_L);
    cv.fillRect(hx-1, hy+3, 2, 6, ...c.STONE_L);
    cv.fillRect(hx+8, hy+3, 2, 6, ...c.STONE_L);
    cv.line(hx-1, hy-3, hx+8, hy-3, ...c.OUTLINE);
    const bx = ox+11, by = oy+12+dy;
    cv.fillRect(bx, by, 10, 13, ...c.PLASTER);
    cv.fillRect(bx, by+5, 10, 2, ...c.STONE_M);
    cv.line(bx, by, bx+9, by, ...c.OUTLINE);
    cv.line(bx, by, bx, by+12, ...c.OUTLINE);
    cv.line(bx+9, by, bx+9, by+12, ...c.OUTLINE);
    cv.line(bx, by+12, bx+9, by+12, ...c.OUTLINE);
    // right-side body shadow
    cv.fillRect(bx+8, by+1, 2, 11, ...c.OUTLINE, 45);
    cv.fillPoly([
      [bx-1, by+8], [bx+10, by+8],
      [bx+11, oy+45], [bx-2, oy+45],
    ], ...c.PLASTER);
    cv.line(bx-2, oy+45, bx+11, oy+45, ...c.OUTLINE);
    cv.fillRect(bx+1+lx, oy+43, 4, 2, ...c.WOOD_D);
    cv.fillRect(bx+5+rx, oy+43, 4, 2, ...c.WOOD_D);
    // ground cast shadow
    for (let _sx = -6; _sx <= 6; _sx++) {
      cv.sp(ox+16+_sx, oy+46, ...c.OUTLINE, Math.max(0, 18-Math.abs(_sx)*3));
    }
    cv.fillRect(bx-2, by+2, 3, 9, ...c.PLASTER);
    cv.fillRect(bx+9, by+2, 3, 9, ...c.PLASTER);
    cv.fillRect(bx-2, by+10, 3, 2, ...c.SKIN);
    cv.fillRect(bx+9, by+10, 3, 2, ...c.SKIN);
    // walking staff (gnarled top, taller than NPC)
    const stX = ox+26;
    cv.line(stX, oy+5, stX, oy+47, ...c.WOOD_M);
    cv.sp(stX-1, oy+6, ...c.WOOD_D);
    cv.sp(stX+1, oy+6, ...c.WOOD_D);
    cv.sp(stX, oy+5, ...c.WOOD_D);
    cv.line(stX-1, oy+6, stX+1, oy+6, ...c.OUTLINE);
  };
  const drawElder_north = (ox, oy, dy=0, lx=0, rx=0) => {
    const hx = ox+12, hy = oy+4+dy; // lower stance
    cv.fillRect(hx, hy, 8, 8, ...c.SKIN);
    cv.fillRect(hx, hy, 8, 3, ...c.PARCH_L); // white hair visible at back
    cv.sp(hx, hy+3, ...c.SKIN); cv.sp(hx+7, hy+3, ...c.SKIN);
    cv.line(hx, hy, hx, hy+7, ...c.OUTLINE);
    cv.line(hx+7, hy, hx+7, hy+7, ...c.OUTLINE);
    cv.line(hx, hy+7, hx+7, hy+7, ...c.OUTLINE);
    // Open hood from behind
    cv.fillRect(hx-1, hy-3, 10, 4, ...c.STONE_L);
    cv.fillRect(hx-1, hy+3, 2, 6, ...c.STONE_L);
    cv.fillRect(hx+8, hy+3, 2, 6, ...c.STONE_L);
    cv.line(hx+4, hy-3, hx+4, hy+8, ...c.STONE_L, 120); // hood seam
    cv.line(hx-1, hy-3, hx+8, hy-3, ...c.OUTLINE);
    // Body (stooped grey robe from behind)
    const bx = ox+11, by = oy+12+dy;
    cv.fillRect(bx, by, 10, 13, ...c.PLASTER);
    cv.fillRect(bx, by+5, 10, 2, ...c.STONE_M);
    cv.line(bx+5, by, bx+5, by+12, ...c.PLASTER, 170);
    cv.line(bx, by, bx+9, by, ...c.OUTLINE); cv.line(bx, by, bx, by+12, ...c.OUTLINE);
    cv.line(bx+9, by, bx+9, by+12, ...c.OUTLINE); cv.line(bx, by+12, bx+9, by+12, ...c.OUTLINE);
    cv.fillRect(bx, by+1, 2, 11, ...c.OUTLINE, 40);
    cv.fillPoly([[bx-1, by+8],[bx+10, by+8],[bx+11, oy+45],[bx-2, oy+45]], ...c.PLASTER);
    cv.line(bx-2, oy+45, bx+11, oy+45, ...c.OUTLINE);
    cv.fillRect(bx+1+lx, oy+43, 4, 2, ...c.WOOD_D); cv.fillRect(bx+5+rx, oy+43, 4, 2, ...c.WOOD_D);
    cv.fillRect(bx-2, by+2, 3, 9, ...c.PLASTER); cv.fillRect(bx+9, by+2, 3, 9, ...c.PLASTER);
    cv.fillRect(bx-2, by+10, 3, 2, ...c.SKIN); cv.fillRect(bx+9, by+10, 3, 2, ...c.SKIN);
    // Staff behind character
    cv.line(ox+5, oy+5, ox+5, oy+47, ...c.WOOD_M);
    cv.sp(ox+4, oy+6, ...c.WOOD_D); cv.sp(ox+6, oy+6, ...c.WOOD_D);
    for (let _sx=-6; _sx<=6; _sx++)
      cv.sp(ox+16+_sx, oy+46, ...c.OUTLINE, Math.max(0, 18-Math.abs(_sx)*3));
  };

  const drawElder_east = (ox, oy, dy=0, legOff=0) => {
    const hx = ox+14, hy = oy+4+dy; // lower stance
    cv.fillRect(hx, hy, 7, 8, ...c.SKIN);
    cv.sp(hx+1, hy+1, ...c.SKIN_HI);
    cv.sp(hx+1, hy+2, ...c.PARCH_L, 200); // white temple hair in profile
    cv.sp(hx+4, hy+3, ...c.STONE_L); // pale eye
    cv.sp(hx+4, hy+2, ...c.STONE_L, 130);
    cv.sp(hx+6, hy+4, ...c.SKIN_SH);
    cv.sp(hx+1, hy+5, ...c.SKIN_SH, 70); // wrinkle
    cv.fillRect(hx-1, hy+3, 2, 3, ...c.SKIN);
    cv.line(hx, hy, hx+6, hy, ...c.OUTLINE); cv.line(hx, hy, hx, hy+7, ...c.OUTLINE);
    cv.line(hx+6, hy, hx+6, hy+7, ...c.OUTLINE); cv.line(hx, hy+7, hx+6, hy+7, ...c.OUTLINE);
    // Hood side
    cv.fillRect(hx-1, hy-3, 9, 5, ...c.STONE_L);
    cv.fillRect(hx-1, hy+2, 2, 6, ...c.STONE_L);
    cv.line(hx-1, hy-3, hx+7, hy-3, ...c.OUTLINE);
    const bx = ox+13, by = oy+12+dy;
    cv.fillRect(bx, by, 8, 13, ...c.PLASTER);
    cv.fillRect(bx, by+5, 8, 2, ...c.STONE_M);
    cv.fillRect(bx, by+1, 2, 11, ...c.OUTLINE, 40);
    cv.line(bx, by, bx+7, by, ...c.OUTLINE); cv.line(bx, by, bx, by+12, ...c.OUTLINE);
    cv.line(bx+7, by, bx+7, by+12, ...c.OUTLINE); cv.line(bx, by+12, bx+7, by+12, ...c.OUTLINE);
    // Staff in front (east-facing = staff on near side)
    const stX = bx+10;
    cv.line(stX, oy+5, stX, oy+47, ...c.WOOD_M);
    cv.sp(stX-1, oy+6, ...c.WOOD_D); cv.sp(stX, oy+5, ...c.WOOD_D); cv.sp(stX+1, oy+6, ...c.WOOD_D);
    cv.fillRect(bx+7, by+2, 3, 9, ...c.PLASTER); cv.fillRect(bx+7, by+10, 3, 2, ...c.SKIN);
    // Robe skirt side
    cv.fillPoly([[bx+1, by+8],[bx+8, by+8],[bx+10, oy+45],[bx-1, oy+45]], ...c.PLASTER);
    cv.line(bx-1, oy+45, bx+10, oy+45, ...c.OUTLINE);
    cv.fillRect(bx+3+legOff, oy+43, 5, 2, ...c.WOOD_D);
    for (let _sx=-6; _sx<=6; _sx++)
      cv.sp(ox+16+_sx, oy+46, ...c.OUTLINE, Math.max(0, 18-Math.abs(_sx)*3));
  };

  {
    const oy7 = 7*48;
    drawElder(0*32, oy7, 0,  0,  0);
    drawElder(1*32, oy7, -1, 0,  0);
    drawElder(2*32, oy7, 0,  -2, 2);
    drawElder(3*32, oy7, -1, 0,  0);
    drawElder(4*32, oy7, 0,  2,  -2);
    drawElder_north(5*32, oy7, 0,  0,  0);
    drawElder_north(6*32, oy7, -1, 0,  0);
    drawElder_north(7*32, oy7, 0,  2,  -2);
    drawElder_north(8*32, oy7, -1, 0,  0);
    drawElder_north(9*32, oy7, 0,  -2, 2);
    drawElder_east(10*32, oy7, 0,  0);
    drawElder_east(11*32, oy7, -1, 0);
    drawElder_east(12*32, oy7, 0,  -3);
    drawElder_east(13*32, oy7, -1, 0);
    drawElder_east(14*32, oy7, 0,  3);
  }

  // ── Row 8: SPY archetype ──────────────────────────────────────────────────
  // Dark hooded cloak, hunched narrow silhouette, dagger hilt at belt.
  const drawSpy = (ox, oy, dy=0, lx=0, rx=0) => {
    const hx = ox+13, hy = oy+3+dy;  // centred narrower
    cv.fillRect(hx, hy, 7, 7, ...c.SKIN);
    cv.sp(hx+1, hy+2, ...c.STONE_D);  // shadowed eyes
    cv.sp(hx+4, hy+2, ...c.STONE_D);
    cv.line(hx, hy, hx+6, hy, ...c.OUTLINE);
    cv.line(hx, hy, hx, hy+6, ...c.OUTLINE);
    cv.line(hx+6, hy, hx+6, hy+6, ...c.OUTLINE);
    cv.line(hx, hy+6, hx+6, hy+6, ...c.OUTLINE);
    // deep cowl — wide drape hiding forehead
    cv.fillRect(hx-3, hy-5, 13, 7, ...c.STONE_D);
    cv.fillRect(hx-4, hy+1, 4, 9, ...c.STONE_D);
    cv.fillRect(hx+7, hy+1, 4, 9, ...c.STONE_D);
    cv.fillRect(hx-1, hy-4, 9, 4, ...c.INK);   // shadow inside hood
    cv.line(hx-3, hy-5, hx+9, hy-5, ...c.OUTLINE);
    cv.line(hx-4, hy+9, hx+10, hy+9, ...c.OUTLINE);
    const bx = ox+12, by = oy+11+dy;
    cv.fillRect(bx, by, 8, 13, ...c.STONE_D);
    cv.sp(bx+1, by+1, ...c.STONE_M, 80);
    cv.fillRect(bx, by+7, 8, 2, ...c.INK);      // dark belt
    cv.line(bx, by, bx+7, by, ...c.OUTLINE);
    cv.line(bx, by, bx, by+12, ...c.OUTLINE);
    cv.line(bx+7, by, bx+7, by+12, ...c.OUTLINE);
    cv.line(bx, by+12, bx+7, by+12, ...c.OUTLINE);
    // right-side body shadow (subtle — dark cloak already shadowed)
    cv.fillRect(bx+6, by+1, 2, 11, ...c.OUTLINE, 40);
    // wide cloak skirt (hides legs)
    cv.fillPoly([
      [bx-2, by+6], [bx+9, by+6],
      [bx+13, oy+47], [bx-6, oy+47],
    ], ...c.STONE_D);
    cv.line(bx-6, oy+47, bx+13, oy+47, ...c.OUTLINE);
    cv.fillRect(bx+lx, oy+44, 4, 3, ...c.INK);
    cv.fillRect(bx+4+rx, oy+44, 4, 3, ...c.INK);
    // ground cast shadow
    for (let _sx = -6; _sx <= 6; _sx++) {
      cv.sp(ox+16+_sx, oy+47, ...c.OUTLINE, Math.max(0, 15-Math.abs(_sx)*2));
    }
    // narrow dark sleeves
    cv.fillRect(bx-2, by+1, 3, 9, ...c.STONE_D);
    cv.fillRect(bx+7, by+1, 3, 9, ...c.STONE_D);
    cv.fillRect(bx-2, by+9, 3, 2, ...c.SKIN);
    cv.fillRect(bx+7, by+9, 3, 2, ...c.SKIN);
    // dagger hilt at right hip
    cv.fillRect(bx+6, by+9, 2, 4, ...c.STONE_L);
    cv.fillRect(bx+5, by+8, 4, 2, ...c.WOOD_D);
    cv.line(bx+5, by+8, bx+8, by+8, ...c.OUTLINE);
  };
  const drawSpy_north = (ox, oy, dy=0, lx=0, rx=0) => {
    const hx = ox+13, hy = oy+3+dy;
    cv.fillRect(hx, hy, 7, 7, ...c.SKIN);
    cv.line(hx, hy, hx, hy+6, ...c.OUTLINE);
    cv.line(hx+6, hy, hx+6, hy+6, ...c.OUTLINE);
    cv.line(hx, hy+6, hx+6, hy+6, ...c.OUTLINE);
    // Cowl very prominent from behind
    cv.fillRect(hx-3, hy-5, 13, 8, ...c.STONE_D);
    cv.fillRect(hx-4, hy+2, 4, 9, ...c.STONE_D);
    cv.fillRect(hx+7, hy+2, 4, 9, ...c.STONE_D);
    cv.fillRect(hx, hy-4, 7, 5, ...c.INK);
    cv.line(hx+3, hy-5, hx+3, hy+10, ...c.INK, 120); // back seam of cowl
    cv.line(hx-3, hy-5, hx+9, hy-5, ...c.OUTLINE);
    cv.line(hx-4, hy+10, hx+10, hy+10, ...c.OUTLINE);
    const bx = ox+12, by = oy+11+dy;
    cv.fillRect(bx, by, 8, 13, ...c.STONE_D);
    cv.fillRect(bx, by+7, 8, 2, ...c.INK);
    cv.line(bx+4, by, bx+4, by+12, ...c.INK, 100); // back cloak seam
    cv.line(bx, by, bx+7, by, ...c.OUTLINE); cv.line(bx, by, bx, by+12, ...c.OUTLINE);
    cv.line(bx+7, by, bx+7, by+12, ...c.OUTLINE); cv.line(bx, by+12, bx+7, by+12, ...c.OUTLINE);
    cv.fillRect(bx, by+1, 2, 11, ...c.OUTLINE, 35);
    cv.fillPoly([[bx-2, by+6],[bx+9, by+6],[bx+13, oy+47],[bx-6, oy+47]], ...c.STONE_D);
    cv.line(bx-6, oy+47, bx+13, oy+47, ...c.OUTLINE);
    cv.fillRect(bx+lx, oy+44, 4, 3, ...c.INK); cv.fillRect(bx+4+rx, oy+44, 4, 3, ...c.INK);
    cv.fillRect(bx-2, by+1, 3, 9, ...c.STONE_D); cv.fillRect(bx+7, by+1, 3, 9, ...c.STONE_D);
    cv.fillRect(bx-2, by+9, 3, 2, ...c.SKIN); cv.fillRect(bx+7, by+9, 3, 2, ...c.SKIN);
    for (let _sx=-6; _sx<=6; _sx++)
      cv.sp(ox+16+_sx, oy+47, ...c.OUTLINE, Math.max(0, 15-Math.abs(_sx)*2));
  };

  const drawSpy_east = (ox, oy, dy=0, legOff=0) => {
    const hx = ox+14, hy = oy+3+dy;
    cv.fillRect(hx, hy, 6, 7, ...c.SKIN); // narrow (hooded/hunched)
    cv.sp(hx+3, hy+2, ...c.STONE_D); // one shadowed eye
    cv.sp(hx+5, hy+3, ...c.SKIN_SH); // nose
    cv.fillRect(hx-1, hy+3, 2, 2, ...c.SKIN);
    cv.line(hx, hy, hx+5, hy, ...c.OUTLINE); cv.line(hx, hy, hx, hy+6, ...c.OUTLINE);
    cv.line(hx+5, hy, hx+5, hy+6, ...c.OUTLINE); cv.line(hx, hy+6, hx+5, hy+6, ...c.OUTLINE);
    // Cowl side (prominent angular silhouette)
    cv.fillRect(hx-3, hy-5, 10, 7, ...c.STONE_D);
    cv.fillRect(hx-4, hy+1, 3, 9, ...c.STONE_D);
    cv.fillRect(hx, hy-4, 6, 4, ...c.INK);
    cv.line(hx-3, hy-5, hx+6, hy-5, ...c.OUTLINE);
    cv.line(hx-4, hy+9, hx+6, hy+9, ...c.OUTLINE);
    const bx = ox+12, by = oy+11+dy;
    cv.fillRect(bx, by, 8, 13, ...c.STONE_D);
    cv.fillRect(bx, by+7, 8, 2, ...c.INK);
    cv.fillRect(bx, by+1, 2, 11, ...c.OUTLINE, 35);
    cv.line(bx, by, bx+7, by, ...c.OUTLINE); cv.line(bx, by, bx, by+12, ...c.OUTLINE);
    cv.line(bx+7, by, bx+7, by+12, ...c.OUTLINE); cv.line(bx, by+12, bx+7, by+12, ...c.OUTLINE);
    // Dagger visible at near side hip
    cv.fillRect(bx+7, by+8, 2, 5, ...c.STONE_L);
    cv.fillRect(bx+6, by+7, 4, 2, ...c.WOOD_D);
    cv.line(bx+6, by+7, bx+9, by+7, ...c.OUTLINE);
    cv.fillRect(bx+7, by+1, 3, 9, ...c.STONE_D); cv.fillRect(bx+7, by+9, 3, 2, ...c.SKIN);
    cv.fillPoly([[bx-2, by+6],[bx+9, by+6],[bx+11, oy+47],[bx-4, oy+47]], ...c.STONE_D);
    cv.line(bx-4, oy+47, bx+11, oy+47, ...c.OUTLINE);
    cv.fillRect(bx+3+legOff, oy+44, 4, 3, ...c.INK);
    for (let _sx=-6; _sx<=6; _sx++)
      cv.sp(ox+16+_sx, oy+47, ...c.OUTLINE, Math.max(0, 15-Math.abs(_sx)*2));
  };

  {
    const oy8 = 8*48;
    drawSpy(0*32, oy8, 0,  0,  0);
    drawSpy(1*32, oy8, -1, 0,  0);
    drawSpy(2*32, oy8, 0,  -2, 2);
    drawSpy(3*32, oy8, -1, 0,  0);
    drawSpy(4*32, oy8, 0,  2,  -2);
    drawSpy_north(5*32, oy8, 0,  0,  0);
    drawSpy_north(6*32, oy8, -1, 0,  0);
    drawSpy_north(7*32, oy8, 0,  2,  -2);
    drawSpy_north(8*32, oy8, -1, 0,  0);
    drawSpy_north(9*32, oy8, 0,  -2, 2);
    drawSpy_east(10*32, oy8, 0,  0);
    drawSpy_east(11*32, oy8, -1, 0);
    drawSpy_east(12*32, oy8, 0,  -3);
    drawSpy_east(13*32, oy8, -1, 0);
    drawSpy_east(14*32, oy8, 0,  3);
  }

  // Upscale 2× (32×48 → 64×96 per frame, 480×432 → 960×864 total)  SPA-585
  const scaled = nearestNeighborScale(cv.data, 480, 432, 960, 864);
  return makePNG(960, 864, scaled);
}

// ═══════════════════════════════════════════════════════════════════════════════
// UI PARCHMENT TILE (ui_parchment.png — 48×48, 9-slice compatible)
// Center 16×16 = fill; 16px border on each side with parchment texture
// ═══════════════════════════════════════════════════════════════════════════════
function makeParchment() {
  const cv = createCanvas(48, 48);

  // fill everything with parchment base
  cv.fillRect(0, 0, 48, 48, ...c.PARCH_M);

  // dither texture
  for (let y=0; y<48; y++) for (let x=0; x<48; x++) {
    if ((x+y)%3===0 && Math.random()<0.3) cv.sp(x, y, ...c.PARCH_L, 140);
    if ((x+y)%5===0 && Math.random()<0.15) cv.sp(x, y, ...c.PARCH_D, 80);
  }

  // horizontal fiber lines — simulate paper/vellum grain
  for (let y=5; y<44; y+=3) {
    for (let x=4; x<44; x++) {
      if (Math.random() < 0.25) cv.sp(x, y, ...c.PARCH_L, 55);
      if (Math.random() < 0.10) cv.sp(x, y, ...c.PARCH_D, 35);
    }
  }

  // aged ink blot (small dark smudge, hand-crafted feel)
  const blotX = 34, blotY = 11;
  cv.sp(blotX, blotY, ...c.INK, 160);
  cv.sp(blotX+1, blotY, ...c.INK, 120);
  cv.sp(blotX, blotY+1, ...c.INK, 100);
  cv.sp(blotX-1, blotY, ...c.INK, 70);
  cv.sp(blotX, blotY-1, ...c.INK, 60);
  cv.sp(blotX+1, blotY+1, ...c.INK, 45);

  // edge vignette — subtle darkening 1-2px inward from border
  for (let i=0; i<48; i++) {
    cv.sp(0, i, ...c.PARCH_D, 80);
    cv.sp(47, i, ...c.PARCH_D, 80);
    cv.sp(i, 0, ...c.PARCH_D, 80);
    cv.sp(i, 47, ...c.PARCH_D, 80);
    cv.sp(1, i, ...c.PARCH_D, 40);
    cv.sp(46, i, ...c.PARCH_D, 40);
    cv.sp(i, 1, ...c.PARCH_D, 40);
    cv.sp(i, 46, ...c.PARCH_D, 40);
  }

  // corner decorations (ink scrollwork — more elaborate)
  const scroll = (sx, sy, fx, fy) => {
    cv.line(sx, sy, sx+fx*4, sy+fy*4, ...c.INK, 180);
    cv.line(sx+fx*1, sy, sx+fx*1, sy+fy*3, ...c.INK, 130);
    cv.line(sx, sy+fy*1, sx+fx*3, sy+fy*1, ...c.INK, 130);
    cv.sp(sx+fx*2, sy+fy*2, ...c.INK, 180);  // centre knot
  };
  scroll(2,2, 1,1);    // top-left
  scroll(45,2, -1,1);  // top-right
  scroll(2,45, 1,-1);  // bot-left
  scroll(45,45,-1,-1); // bot-right

  // border outline
  cv.line(0, 0, 47, 0, ...c.PARCH_D);
  cv.line(0, 47, 47, 47, ...c.PARCH_D);
  cv.line(0, 0, 0, 47, ...c.PARCH_D);
  cv.line(47, 0, 47, 47, ...c.PARCH_D);
  // inner border
  cv.line(3, 3, 44, 3, ...c.INK, 100);
  cv.line(3, 44, 44, 44, ...c.INK, 100);
  cv.line(3, 3, 3, 44, ...c.INK, 100);
  cv.line(44, 3, 44, 44, ...c.INK, 100);

  return cv.toPNG();
}

// ═══════════════════════════════════════════════════════════════════════════════
// FACTION BADGES (ui_faction_badges.png — 72×24, three 24×24 badges)
//   col 0 = merchant, col 1 = noble, col 2 = clergy
// ═══════════════════════════════════════════════════════════════════════════════
function makeFactionBadges() {
  const cv = createCanvas(72, 24);

  const badge = (ox, bgR, bgG, bgB, fgR, fgG, fgB, sym) => {
    // shield shape
    cv.fillPoly([
      [ox+3, 1], [ox+20, 1],
      [ox+20, 14], [ox+12, 22],
      [ox+3, 14],
    ], bgR, bgG, bgB);
    cv.line(ox+3,1,  ox+20,1,  ...c.OUTLINE);
    cv.line(ox+20,1, ox+20,14, ...c.OUTLINE);
    cv.line(ox+20,14,ox+12,22, ...c.OUTLINE);
    cv.line(ox+12,22,ox+3,14,  ...c.OUTLINE);
    cv.line(ox+3,14, ox+3,1,   ...c.OUTLINE);

    // symbol
    if (sym === 'coin') {
      cv.fillRect(ox+9, 6, 6, 6, fgR, fgG, fgB);
      cv.line(ox+9,6,  ox+14,6,  ...c.OUTLINE);
      cv.line(ox+9,11, ox+14,11, ...c.OUTLINE);
      cv.line(ox+9,6,  ox+9,11,  ...c.OUTLINE);
      cv.line(ox+14,6, ox+14,11, ...c.OUTLINE);
    } else if (sym === 'crown') {
      cv.fillRect(ox+8,  9, 8, 5, fgR, fgG, fgB);
      cv.line(ox+8,5,  ox+8,9,  fgR, fgG, fgB);
      cv.line(ox+12,4, ox+12,9, fgR, fgG, fgB);
      cv.line(ox+15,5, ox+15,9, fgR, fgG, fgB);
    } else if (sym === 'cross') {
      cv.fillRect(ox+10, 5, 4, 12, fgR, fgG, fgB);
      cv.fillRect(ox+7,  9, 10, 4, fgR, fgG, fgB);
    }
  };

  badge(0,  ...c.MERCH_B, ...c.MERCH_T, 'coin');
  badge(24, ...c.NOBLE_B, ...c.NOBLE_T, 'crown');
  badge(48, ...c.CLERGY_B,...c.CLERGY_T,'cross');

  return cv.toPNG();
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLAIM TYPE ICONS (ui_claim_icons.png — 160×32, five 32×32 icons)  ← SPA-523
//   0=assassination  1=theft  2=slander  3=witness  4=alliance
// ═══════════════════════════════════════════════════════════════════════════════
function makeClaimIcons() {
  const cv = createCanvas(160, 32);

  // 0: assassination — dagger (32×32)
  {
    const ox=0;
    cv.fillRect(ox+14, 2,  6, 18, ...c.STONE_L);
    cv.fillPoly([[ox+14,20],[ox+20,20],[ox+16,28]], ...c.STONE_D);
    cv.fillRect(ox+10, 10, 14, 4, ...c.WOOD_M);
    cv.line(ox+16, 2, ox+16, 26, ...c.OUTLINE);
  }
  // 1: theft — bag with coin (32×32)
  {
    const ox=32;
    cv.fillPoly([[ox+10,10],[ox+22,10],[ox+26,20],[ox+6,20]], ...c.WOOD_L);
    cv.fillRect(ox+10, 20, 12, 8, ...c.WOOD_L);
    cv.line(ox+10, 10, ox+22, 10, ...c.OUTLINE);
    cv.line(ox+6,  20, ox+26, 20, ...c.OUTLINE);
    cv.line(ox+10, 28, ox+22, 28, ...c.OUTLINE);
    cv.sp(ox+14, 6, ...c.MERCH_T);  // string
    cv.sp(ox+16, 6, ...c.MERCH_T);
  }
  // 2: slander — speech bubble (32×32)
  {
    const ox=64;
    cv.fillRect(ox+4,  4, 24, 16, ...c.PARCH_L);
    cv.fillPoly([[ox+8,20],[ox+16,20],[ox+10,28]], ...c.PARCH_L);
    cv.line(ox+4,  4, ox+26,  4, ...c.OUTLINE);
    cv.line(ox+4,  4, ox+4,  18, ...c.OUTLINE);
    cv.line(ox+4,  18, ox+26, 18, ...c.OUTLINE);
    cv.line(ox+26, 4, ox+26,  18, ...c.OUTLINE);
    // text lines
    cv.line(ox+8,  10, ox+22, 10, ...c.INK, 160);
    cv.line(ox+8,  14, ox+18, 14, ...c.INK, 120);
  }
  // 3: witness — eye (32×32)
  {
    const ox=96;
    cv.fillPoly([[ox+4,16],[ox+16,8],[ox+28,16],[ox+16,24]], ...c.PARCH_L);
    cv.fillRect(ox+12, 12, 10, 10, ...c.MERCH_B);
    cv.sp(ox+14, 14, ...c.WATER_L);
    cv.sp(ox+16, 16, 40, 60, 100);
    cv.line(ox+4,  16, ox+16,  8, ...c.OUTLINE);
    cv.line(ox+16,  8, ox+28, 16, ...c.OUTLINE);
    cv.line(ox+28, 16, ox+16, 24, ...c.OUTLINE);
    cv.line(ox+16, 24, ox+4,  16, ...c.OUTLINE);
  }
  // 4: alliance — clasped hands (32×32)
  {
    const ox=128;
    cv.fillRect(ox+4,  8, 10, 16, ...c.SKIN);
    cv.fillRect(ox+18, 8, 10, 16, ...c.SKIN);
    cv.fillRect(ox+10, 12, 12, 8, ...c.SKIN);
    cv.line(ox+4,  8, ox+12,  8, ...c.OUTLINE);
    cv.line(ox+18, 8, ox+26,  8, ...c.OUTLINE);
    cv.line(ox+4,  24, ox+26, 24, ...c.OUTLINE);
    cv.line(ox+4,  8,  ox+4,  24, ...c.OUTLINE);
    cv.line(ox+26, 8,  ox+26, 24, ...c.OUTLINE);
  }

  return cv.toPNG();
}

// ═══════════════════════════════════════════════════════════════════════════════
// NPC PORTRAIT ATLAS  (ui_npc_portraits.png — 384×400, six 64×80 cols × 5 rows)
//   30 individual NPC portraits, one per NPC (ordered by portrait_id in npcs.json)
//   Row 0 (y=  0): NPCs  0– 5  (Merchant: Aldric, Sybil, Oswin, Marta, Rufus, Nell)
//   Row 1 (y= 80): NPCs  6–11  (Merchant cont. + Noble: Cob, Idris, Bess, Sim, Greta, Edric)
//   Row 2 (y=160): NPCs 12–17  (Noble: Isolde, Calder, Bram, Wynn, Pell, Annit)
//   Row 3 (y=240): NPCs 18–23  (Noble cont. + Clergy: Tomas, Hugh, Aldous, Maren, Finn, Vera)
//   Row 4 (y=320): NPCs 24–29  (Clergy cont.: Piety, Jude, Constance, Thomas, Alys, Denny)
//
// Portrait cell: 64×80 px — identical dimensions to old atlas, no script size changes.
// Lookup: portrait_id = NPC.portrait_id (0–29); col = id % 6, row = Math.floor(id / 6)
//
// Hat styles:  'wide' | 'coronet' | 'hood' | 'helm' | 'cap' | 'mitre'
//              | 'veil' | 'wimple' | 'scarf' | 'coif' | 'feathered_cap'
//              | 'pilgrim_hat' | 'bare'
// Expressions: 'neutral' | 'smirk' | 'stern' | 'worried' | 'devout'
// ═══════════════════════════════════════════════════════════════════════════════
function makeNPCPortraits() {
  const cv = createCanvas(384, 400);

  const drawPortrait = (ox, oy, opts) => {
    const {
      body, trim, hatStyle, hat, hatTrim,
      female = false, elder = false, archetype = 'commoner',
      expression = 'neutral', skinTone = null,
    } = opts;
    const skinBase = skinTone || c.SKIN;

    // ── parchment background + ink border ────────────────────────────────────
    cv.fillRect(ox, oy, 64, 80, ...c.PARCH_L);
    // warm gradient: slightly darker at bottom
    cv.fillRect(ox, oy+60, 64, 20, ...c.PARCH_M, 40);
    // subtle vignette: darken edges
    cv.fillRect(ox, oy, 64, 2, ...c.PARCH_D, 60);
    cv.fillRect(ox, oy+78, 64, 2, ...c.PARCH_D, 60);
    cv.fillRect(ox, oy, 2, 80, ...c.PARCH_D, 40);
    cv.fillRect(ox+62, oy, 2, 80, ...c.PARCH_D, 40);
    // decorative corner flourishes (ink dot cluster)
    cv.sp(ox+2, oy+2, ...c.INK, 100); cv.sp(ox+3, oy+2, ...c.INK, 60);
    cv.sp(ox+2, oy+3, ...c.INK, 60);
    cv.sp(ox+61, oy+2, ...c.INK, 100); cv.sp(ox+60, oy+2, ...c.INK, 60);
    cv.sp(ox+61, oy+3, ...c.INK, 60);
    cv.sp(ox+2, oy+77, ...c.INK, 100); cv.sp(ox+3, oy+77, ...c.INK, 60);
    cv.sp(ox+2, oy+76, ...c.INK, 60);
    cv.sp(ox+61, oy+77, ...c.INK, 100); cv.sp(ox+60, oy+77, ...c.INK, 60);
    cv.sp(ox+61, oy+76, ...c.INK, 60);
    cv.line(ox,    oy,    ox+63, oy,    ...c.INK);
    cv.line(ox,    oy,    ox,    oy+79, ...c.INK);
    cv.line(ox+63, oy,    ox+63, oy+79, ...c.INK);
    cv.line(ox,    oy+79, ox+63, oy+79, ...c.INK);
    cv.line(ox+1,  oy+1,  ox+62, oy+1,  ...c.PARCH_M, 80);
    cv.line(ox+1,  oy+1,  ox+1,  oy+78, ...c.PARCH_M, 80);

    // ── head — organic shape (21×22 core with rounded corners & jaw taper) ───
    const hx = ox+21, hy = oy+10;
    // Base fill — slightly larger rect, then we'll clip corners
    cv.fillRect(hx+1, hy,   19, 22, ...c.SKIN);  // main body
    cv.fillRect(hx,   hy+1, 21, 20, ...c.SKIN);  // wider mid-cheek band
    // rounded top corners (remove harsh pixel corners)
    cv.sp(hx,    hy,    ...c.PARCH_L);  // clip top-left
    cv.sp(hx+20, hy,    ...c.PARCH_L);  // clip top-right
    // jaw taper — 1px narrower each side at chin row
    cv.sp(hx,    hy+20, ...c.PARCH_L);  // clip bottom-left
    cv.sp(hx+20, hy+20, ...c.PARCH_L);  // clip bottom-right
    cv.sp(hx,    hy+19, ...c.SKIN_SH, 80);  // chin-left soften
    cv.sp(hx+20, hy+19, ...c.SKIN_SH, 80);  // chin-right soften
    // forehead highlight (catch-light from top)
    cv.fillRect(hx+4, hy+1, 12, 2, ...c.SKIN_HI, 55);
    cv.fillRect(hx+5, hy+2, 10, 1, ...c.SKIN_HI, 35);
    // cheek highlight (left cheek — light source from viewer-left)
    cv.fillRect(hx+1, hy+7, 4, 5, ...c.SKIN_HI, 60);
    cv.fillRect(hx+2, hy+8, 2, 3, ...c.SKIN_HI, 85);
    // right-face shadow (roundness illusion)
    cv.fillRect(hx+17, hy+5, 3, 10, ...c.SKIN_SH, 50);
    cv.fillRect(hx+18, hy+6, 2, 8,  ...c.SKIN_SH, 35);
    // underjaw shadow (chin volume)
    cv.fillRect(hx+2, hy+18, 17, 3, ...c.SKIN_SH, 65);
    cv.fillRect(hx+4, hy+19, 13, 2, ...c.SKIN_SH, 45);
    // temple shadow (side of head)
    cv.sp(hx+1, hy+5, ...c.SKIN_SH, 40);
    cv.sp(hx+1, hy+6, ...c.SKIN_SH, 30);

    // archetype-specific cheek / skin tone variation
    if (archetype === 'guard') {
      // weathered, slightly ruddier skin — sun-exposed
      cv.fillRect(hx+3, hy+9, 4, 4, ...c.SKIN_SH, 25);
      cv.fillRect(hx+14, hy+9, 3, 4, ...c.SKIN_SH, 20);
    } else if (archetype === 'commoner') {
      // tired — slightly darker eye-socket area
      cv.fillRect(hx+3, hy+7, 6, 2, ...c.SKIN_SH, 20);
      cv.fillRect(hx+12, hy+7, 5, 2, ...c.SKIN_SH, 20);
    } else if (archetype === 'merchant') {
      // well-fed, rosy cheeks
      cv.fillRect(hx+2, hy+10, 3, 3, 222, 160, 140, 40);
      cv.fillRect(hx+16, hy+10, 3, 3, 222, 160, 140, 40);
    }

    // ── eyebrows ─────────────────────────────────────────────────────────────
    if (archetype === 'noble') {
      // high arched brows — slightly thinner, elevated
      cv.fillRect(hx+4, hy+4, 5, 1, ...c.HAIR, 200);
      cv.sp(hx+3, hy+5, ...c.HAIR, 100);
      cv.sp(hx+9, hy+4, ...c.HAIR, 80);  // arch peak
      cv.fillRect(hx+12, hy+4, 5, 1, ...c.HAIR, 200);
      cv.sp(hx+11, hy+5, ...c.HAIR, 80);
      cv.sp(hx+17, hy+4, ...c.HAIR, 100);
    } else if (archetype === 'guard') {
      // heavy, flat brows — stern expression
      cv.fillRect(hx+3, hy+5, 7, 2, ...c.HAIR, 200);
      cv.sp(hx+2, hy+6, ...c.HAIR, 140);
      cv.fillRect(hx+11, hy+5, 7, 2, ...c.HAIR, 200);
      cv.sp(hx+18, hy+6, ...c.HAIR, 140);
      // inner brow pinch (furrowed)
      cv.sp(hx+9,  hy+5, ...c.OUTLINE, 50);
      cv.sp(hx+11, hy+5, ...c.OUTLINE, 50);
    } else if (archetype === 'commoner') {
      // low, slightly drooping outer corners — tired look
      cv.fillRect(hx+4, hy+5, 5, 2, ...c.HAIR, 170);
      cv.sp(hx+3, hy+6, ...c.HAIR, 100);
      cv.sp(hx+8, hy+6, ...c.HAIR, 80);  // outer droop
      cv.fillRect(hx+12, hy+5, 5, 2, ...c.HAIR, 170);
      cv.sp(hx+16, hy+6, ...c.HAIR, 80); // outer droop
      cv.sp(hx+17, hy+6, ...c.HAIR, 100);
    } else {
      // default: standard brows
      cv.fillRect(hx+4, hy+5, 5, 2, ...c.HAIR, 180);
      cv.sp(hx+3, hy+6, ...c.HAIR, 120);
      cv.fillRect(hx+12, hy+5, 5, 2, ...c.HAIR, 180);
      cv.sp(hx+17, hy+6, ...c.HAIR, 120);
    }

    // ── eyes — whites, iris, pupil, catch-light ───────────────────────────────
    // Left eye socket
    cv.fillRect(hx+3, hy+8, 7, 4, ...c.SKIN_HI, 180);   // white area
    cv.fillRect(hx+4, hy+8, 5, 3, [200,200,200], 255);   // brighter whites
    // Iris (colored by archetype)
    const irisColor = archetype === 'noble'   ? [60, 80, 120] :
                      archetype === 'clergy'  ? [70, 90, 70]  :
                      archetype === 'merchant'? [80, 60, 30]  :
                                               [50, 45, 40];
    cv.fillRect(hx+5, hy+8, 3, 3, ...irisColor);
    cv.sp(hx+6, hy+9, ...c.OUTLINE);                     // pupil
    cv.sp(hx+5, hy+8, 220, 220, 220, 180);               // catch-light
    // Right eye socket
    cv.fillRect(hx+11, hy+8, 7, 4, ...c.SKIN_HI, 180);
    cv.fillRect(hx+12, hy+8, 5, 3, [200,200,200], 255);
    cv.fillRect(hx+13, hy+8, 3, 3, ...irisColor);
    cv.sp(hx+14, hy+9, ...c.OUTLINE);
    cv.sp(hx+13, hy+8, 220, 220, 220, 180);
    // lower eyelid line (gives eye depth)
    cv.line(hx+4, hy+11, hx+8, hy+11, ...c.SKIN_SH, 70);
    cv.line(hx+12, hy+11, hx+16, hy+11, ...c.SKIN_SH, 70);
    // commoner: heavy lower-lid bags
    if (archetype === 'commoner' || elder) {
      cv.sp(hx+4, hy+12, ...c.SKIN_SH, 50);
      cv.sp(hx+7, hy+12, ...c.SKIN_SH, 50);
      cv.sp(hx+12, hy+12, ...c.SKIN_SH, 50);
      cv.sp(hx+15, hy+12, ...c.SKIN_SH, 50);
    }

    // ── nose ─────────────────────────────────────────────────────────────────
    // Nose bridge
    cv.sp(hx+9, hy+11, ...c.SKIN_SH, 60);
    cv.sp(hx+10, hy+11, ...c.SKIN_SH, 60);
    // Nose tip / nostrils
    cv.sp(hx+9,  hy+13, ...c.SKIN_SH, 120);
    cv.sp(hx+10, hy+13, ...c.SKIN_SH, 100);
    cv.fillRect(hx+8, hy+14, 5, 2, ...c.SKIN_SH, 90);
    cv.sp(hx+7, hy+14, ...c.SKIN_SH, 60);   // left nostril flare
    cv.sp(hx+13, hy+14, ...c.SKIN_SH, 60);  // right nostril flare
    // Nose tip highlight
    cv.sp(hx+10, hy+12, ...c.SKIN_HI, 60);

    // ── mouth ────────────────────────────────────────────────────────────────
    // expression param overrides archetype default when set
    const _expr = expression !== 'neutral' ? expression :
                  (archetype === 'merchant' && !female) ? 'smirk' :
                  ((archetype === 'noble' || archetype === 'guard' || archetype === 'captain') && !female) ? 'stern' : 'neutral';
    if (_expr === 'smirk') {
      // slight smirk — left corner slightly higher
      cv.sp(hx+7, hy+16, ...c.OUTLINE, 50);
      cv.fillRect(hx+8, hy+17, 5, 1, ...c.OUTLINE, 75);
      cv.sp(hx+13, hy+16, ...c.OUTLINE, 65);
      cv.fillRect(hx+8, hy+17, 5, 1, ...c.SKIN_SH, 50);
      cv.sp(hx+7, hy+16, ...c.SKIN_SH, 45);
    } else if (_expr === 'stern') {
      // thin stern set lips
      cv.fillRect(hx+7, hy+16, 7, 1, ...c.OUTLINE, 90);
      cv.sp(hx+6, hy+16, ...c.SKIN_SH, 60);
      cv.sp(hx+14, hy+16, ...c.SKIN_SH, 60);
      cv.fillRect(hx+8, hy+17, 5, 1, ...c.SKIN_SH, 40);
    } else if (_expr === 'worried') {
      // slightly open mouth, corners pulled down
      cv.sp(hx+7, hy+17, ...c.OUTLINE, 70);
      cv.fillRect(hx+8, hy+17, 5, 1, ...c.OUTLINE, 60);
      cv.sp(hx+13, hy+17, ...c.OUTLINE, 70);
      cv.sp(hx+7, hy+18, ...c.OUTLINE, 40);
      cv.sp(hx+13, hy+18, ...c.OUTLINE, 40);
      cv.fillRect(hx+9, hy+18, 3, 1, ...c.SKIN_SH, 60);
    } else if (_expr === 'devout') {
      // serene closed smile, slightly upturned corners
      cv.sp(hx+7, hy+16, ...c.OUTLINE, 50);
      cv.fillRect(hx+8, hy+16, 5, 1, ...c.OUTLINE, 70);
      cv.sp(hx+13, hy+16, ...c.OUTLINE, 50);
      cv.fillRect(hx+8, hy+17, 5, 1, ...c.SKIN_SH, 55);
    } else if (female) {
      // fuller, softer lips
      cv.fillRect(hx+7, hy+16, 7, 1, ...c.SKIN_SH, 140);
      cv.fillRect(hx+8, hy+17, 5, 2, [180, 120, 110], 120);
      cv.fillRect(hx+9, hy+17, 3, 1, [200, 140, 130], 100);  // cupid bow
      cv.sp(hx+6, hy+16, ...c.SKIN_SH, 80);
      cv.sp(hx+14, hy+16, ...c.SKIN_SH, 80);
    } else {
      cv.fillRect(hx+7, hy+16, 7, 1, ...c.OUTLINE, 80);
      cv.fillRect(hx+7, hy+17, 7, 1, ...c.SKIN_SH, 60);
    }

    // elder: beard stubble + wrinkles + grey temples
    if (elder) {
      const elderSkin = [196, 168, 138];  // slightly greyer/paler skin tone
      cv.fillRect(hx+1, hy+12, 18, 8, ...elderSkin, 40);  // age tint
      if (!female) {
        // stubble / short beard
        cv.fillRect(hx+5, hy+18, 11, 4, ...c.HAIR, 65);
        cv.fillRect(hx+7, hy+17, 7, 2, ...c.HAIR, 45);
        cv.sp(hx+5, hy+16, ...c.HAIR, 35);
        cv.sp(hx+15, hy+16, ...c.HAIR, 35);
      }
      // forehead creases
      cv.line(hx+4, hy+3, hx+9, hy+3, ...c.SKIN_SH, 45);
      cv.line(hx+12, hy+3, hx+16, hy+3, ...c.SKIN_SH, 45);
      cv.sp(hx+10, hy+4, ...c.SKIN_SH, 40);
      // crow's feet
      cv.sp(hx+2,  hy+9,  ...c.SKIN_SH, 55);
      cv.sp(hx+2,  hy+10, ...c.SKIN_SH, 45);
      cv.sp(hx+18, hy+9,  ...c.SKIN_SH, 55);
      cv.sp(hx+18, hy+10, ...c.SKIN_SH, 45);
      // nasolabial folds
      cv.sp(hx+7, hy+15, ...c.SKIN_SH, 50);
      cv.sp(hx+13, hy+15, ...c.SKIN_SH, 50);
    }
    // female: side-hair drapes (fuller flow)
    if (female) {
      cv.fillRect(hx-3, hy+3, 4, 24, ...c.HAIR);
      cv.fillRect(hx-4, hy+5, 2, 20, ...c.HAIR, 180);   // outer flow
      cv.fillRect(hx+20, hy+3, 4, 24, ...c.HAIR);
      cv.fillRect(hx+22, hy+5, 2, 20, ...c.HAIR, 180);
      // hair highlight (sheen on the part)
      cv.fillRect(hx-2, hy+3, 1, 12, [90, 64, 42], 180);
      cv.fillRect(hx+21, hy+3, 1, 12, [90, 64, 42], 180);
    }
    // head outline — ink-weight, slightly softer at rounded corners
    cv.line(hx+1,  hy,    hx+19, hy,    ...c.OUTLINE);   // top (skip corners)
    cv.line(hx,    hy+1,  hx,    hy+19, ...c.OUTLINE);   // left
    cv.line(hx+20, hy+1,  hx+20, hy+19, ...c.OUTLINE);  // right
    cv.line(hx+1,  hy+20, hx+19, hy+20, ...c.OUTLINE);  // bottom
    // corner pixels (slightly softened)
    cv.sp(hx+1, hy+1, ...c.OUTLINE, 160);
    cv.sp(hx+19, hy+1, ...c.OUTLINE, 160);
    cv.sp(hx+1, hy+19, ...c.OUTLINE, 160);
    cv.sp(hx+19, hy+19, ...c.OUTLINE, 160);

    // ── hat / headwear ────────────────────────────────────────────────────────
    if (hatStyle === 'wide') {
      cv.fillRect(hx-5, hy-2, 31, 4, ...hat);
      cv.fillRect(hx+3, hy-12, 15, 12, ...hat);
      cv.fillRect(hx+5, hy-14, 11, 4, ...hatTrim);
      cv.fillRect(hx+13, hy-11, 4, 10, ...hat, 160);
      cv.line(hx-5, hy-2, hx+25, hy-2, ...c.OUTLINE);
      cv.line(hx+3, hy-12, hx+17, hy-12, ...c.OUTLINE);
      cv.line(hx+3, hy-12, hx+3,  hy-2,  ...c.OUTLINE);
      cv.line(hx+17,hy-12, hx+17, hy-2,  ...c.OUTLINE);
    } else if (hatStyle === 'coronet') {
      cv.fillRect(hx, hy-3, 21, 4, ...hat);
      cv.fillPoly([[hx+2,hy-3],[hx+5,hy-9],[hx+8,hy-3]], ...hat);
      cv.fillPoly([[hx+8,hy-3],[hx+10,hy-10],[hx+13,hy-3]], ...hat);
      cv.fillPoly([[hx+13,hy-3],[hx+16,hy-9],[hx+19,hy-3]], ...hat);
      cv.fillRect(hx+4, hy-8, 2, 2, ...hatTrim);
      cv.fillRect(hx+9, hy-9, 3, 2, ...hatTrim);
      cv.fillRect(hx+15,hy-8, 2, 2, ...hatTrim);
      cv.line(hx, hy-3, hx+20, hy-3, ...c.OUTLINE);
      cv.line(hx+2,hy-3, hx+5,hy-9, ...c.OUTLINE);
      cv.line(hx+5,hy-9, hx+8,hy-3, ...c.OUTLINE);
      cv.line(hx+8,hy-3, hx+10,hy-10,...c.OUTLINE);
      cv.line(hx+10,hy-10,hx+13,hy-3,...c.OUTLINE);
      cv.line(hx+13,hy-3,hx+16,hy-9, ...c.OUTLINE);
      cv.line(hx+16,hy-9,hx+19,hy-3, ...c.OUTLINE);
    } else if (hatStyle === 'hood') {
      cv.fillRect(hx-3, hy-8, 27, 10, ...hat);
      cv.fillRect(hx-3, hy,    4, 16, ...hat);
      cv.fillRect(hx+20,hy,    4, 16, ...hat);
      cv.fillRect(hx+18, hy-7, 5, 8, ...hat, 160);
      cv.line(hx-3, hy-8, hx+23, hy-8, ...c.OUTLINE);
      cv.line(hx-3, hy-8, hx-3,  hy+15,...c.OUTLINE);
      cv.line(hx+23,hy-8, hx+23, hy+15,...c.OUTLINE);
    } else if (hatStyle === 'helm') {
      cv.fillRect(hx-3, hy-8, 27, 12, ...c.STONE_M);
      cv.fillRect(hx-5, hy,   31, 4,  ...c.STONE_D);
      cv.fillRect(hx+9, hy-8, 3, 16,  ...c.STONE_D);
      cv.sp(hx+2, hy+1, ...c.STONE_L);
      cv.sp(hx+18,hy+1, ...c.STONE_L);
      cv.line(hx-5, hy,   hx+25, hy,   ...c.OUTLINE);
      cv.line(hx-3, hy-8, hx+23, hy-8, ...c.OUTLINE);
      cv.line(hx-3, hy-8, hx-5,  hy,   ...c.OUTLINE);
      cv.line(hx+23,hy-8, hx+25, hy,   ...c.OUTLINE);
    } else if (hatStyle === 'cap') {
      cv.fillRect(hx,   hy-2, 21, 4, ...c.THATCH_D);
      cv.fillRect(hx+3, hy-10,15, 10,...c.THATCH_D);
      cv.fillRect(hx+5, hy-12,11, 4, ...c.DIRT_D);
      cv.line(hx+5, hy-6, hx+16, hy-6, ...c.DIRT_D, 140);
      cv.line(hx,   hy-2, hx+20, hy-2, ...c.OUTLINE);
      cv.line(hx+3, hy-10,hx+17, hy-10,...c.OUTLINE);
    } else if (hatStyle === 'mitre') {
      // Bishop's mitre: tall twin-peak hat with decorative band
      cv.fillRect(hx+2, hy-2, 17, 4, ...hat);
      cv.fillPoly([[hx+2, hy-2],[hx+8, hy-16],[hx+10, hy-2]], ...hat);
      cv.fillPoly([[hx+11, hy-2],[hx+13, hy-16],[hx+19, hy-2]], ...hat);
      cv.fillRect(hx+4, hy-10, 5, 2, ...hatTrim, 200);
      cv.fillRect(hx+12, hy-10, 5, 2, ...hatTrim, 200);
      cv.sp(hx+10, hy-3, ...c.PARCH_L, 120);
      cv.line(hx+2, hy-2, hx+8, hy-16, ...c.OUTLINE);
      cv.line(hx+8, hy-16, hx+10, hy-2, ...c.OUTLINE);
      cv.line(hx+11, hy-2, hx+13, hy-16, ...c.OUTLINE);
      cv.line(hx+13, hy-16, hx+19, hy-2, ...c.OUTLINE);
      cv.line(hx+2, hy-2, hx+19, hy-2, ...c.OUTLINE);
    } else if (hatStyle === 'veil') {
      // Flowing veil — wide drape from crown to below chin
      cv.fillRect(hx-4, hy-6, 29, 8, ...hat, 200);
      cv.fillRect(hx-4, hy+2,  5, 20, ...hat, 180);
      cv.fillRect(hx+20, hy+2, 5, 20, ...hat, 180);
      cv.fillRect(hx+2, hy-8, 17, 3, ...hatTrim, 160);
      cv.line(hx-4, hy-6, hx+24, hy-6, ...c.OUTLINE);
      cv.line(hx-4, hy-6, hx-4, hy+21, ...c.OUTLINE);
      cv.line(hx+24, hy-6, hx+24, hy+21, ...c.OUTLINE);
    } else if (hatStyle === 'wimple') {
      // Nun's wimple: tight white chin-and-head frame
      cv.fillRect(hx-2, hy-4, 25, 6, ...hat);
      cv.fillRect(hx-4, hy+2,  4, 22, ...hat);
      cv.fillRect(hx+21, hy+2, 4, 22, ...hat);
      cv.fillRect(hx+2, hy+22, 17, 4, ...hat, 180);
      cv.fillRect(hx-2, hy-4, 25, 3, ...hatTrim, 100);
      cv.line(hx-2, hy-4, hx+22, hy-4, ...c.OUTLINE);
      cv.line(hx-4, hy+2, hx-4, hy+23, ...c.OUTLINE);
      cv.line(hx+25, hy+2, hx+25, hy+23, ...c.OUTLINE);
    } else if (hatStyle === 'scarf') {
      // Simple headscarf wrapped over crown, loose tail left side
      cv.fillRect(hx-1, hy-5, 23, 7, ...hat, 200);
      cv.fillRect(hx-2, hy+2,  3, 18, ...hat, 160);
      cv.sp(hx+20, hy-1, hat[0], hat[1], hat[2], 200);
      cv.sp(hx+21, hy,   hat[0], hat[1], hat[2], 180);
      cv.line(hx-1, hy-5, hx+21, hy-5, ...c.OUTLINE);
      cv.line(hx-1, hy-5, hx-2,  hy+19,...c.OUTLINE);
    } else if (hatStyle === 'coif') {
      // Tight linen coif covering ears and top of head
      cv.fillRect(hx-1, hy-6, 23, 8, ...hat, 210);
      cv.fillRect(hx-2, hy+2,  3, 20, ...hat, 180);
      cv.fillRect(hx+20, hy+2, 3, 20, ...hat, 180);
      cv.fillRect(hx, hy-6, 21, 2, ...hatTrim, 80);
      cv.line(hx-1, hy-6, hx+21, hy-6, ...c.OUTLINE);
      cv.line(hx-2, hy+2, hx-2, hy+21, ...c.OUTLINE);
      cv.line(hx+22, hy+2, hx+22, hy+21, ...c.OUTLINE);
    } else if (hatStyle === 'feathered_cap') {
      // Noble cap with swept feather plume
      cv.fillRect(hx,   hy-2, 21, 4, ...hat);
      cv.fillRect(hx+3, hy-10,15, 10,...hat);
      cv.line(hx-2, hy-8, hx+4, hy-14, ...c.FLAG_R, 200);
      cv.line(hx-3, hy-8, hx+3, hy-15, ...c.FLAG_R, 160);
      cv.line(hx-1, hy-7, hx+5, hy-13, ...c.PARCH_L, 120);
      cv.line(hx,   hy-2, hx+20, hy-2, ...c.OUTLINE);
      cv.line(hx+3, hy-10,hx+17, hy-10,...c.OUTLINE);
    } else if (hatStyle === 'pilgrim_hat') {
      // Wide-brim pilgrim hat with scallop shell badge pin
      cv.fillRect(hx-6, hy-2, 33, 4, ...hat);
      cv.fillRect(hx+2, hy-12, 17, 12, ...hat);
      cv.fillRect(hx+6, hy-14, 9, 4, ...c.DIRT_D);
      cv.fillRect(hx+4, hy-2, 4, 3, ...c.PARCH_L, 160);
      cv.sp(hx+5, hy-1, ...c.STONE_L, 200);
      cv.line(hx-6, hy-2, hx+26, hy-2, ...c.OUTLINE);
      cv.line(hx+2, hy-12, hx+18, hy-12, ...c.OUTLINE);
      cv.line(hx+2, hy-12, hx+2,  hy-2,  ...c.OUTLINE);
      cv.line(hx+18,hy-12, hx+18, hy-2,  ...c.OUTLINE);
    } else if (hatStyle === 'bare') {
      // No hat — show hair/scalp directly on head
      const hairCol = hat;
      cv.fillRect(hx+1, hy-2, 19, 4, ...hairCol);
      cv.fillRect(hx, hy+1, 3, 4, ...hairCol);
      cv.fillRect(hx+18, hy+1, 3, 4, ...hairCol);
      cv.fillRect(hx+4, hy-2, 8, 1, Math.min(hairCol[0]+20,255), Math.min(hairCol[1]+10,255), Math.min(hairCol[2]+5,255), 140);
      cv.line(hx+1, hy-2, hx+19, hy-2, ...c.OUTLINE);
    }

    // ── neck ──────────────────────────────────────────────────────────────────
    cv.fillRect(ox+27, hy+21, 10, 8, ...c.SKIN);
    cv.fillRect(ox+32, hy+22, 4, 6, ...c.SKIN_SH, 40);

    // ── upper torso / collar (42×34 at x=ox+11, y=oy+38) ────────────────────
    const tx = ox+11, ty = oy+38;
    // Base body fill with subtle right-side shadow for depth
    cv.fillRect(tx, ty, 42, 34, ...body);
    cv.fillRect(tx+34, ty+2, 7, 30, ...body, 150);       // right edge shadow
    // Shoulder shaping — slight highlight on left shoulder
    cv.fillRect(tx+1, ty, 8, 4, ...body, 220);            // left shoulder
    cv.fillRect(tx, ty, 5, 3, ...body, 180);
    // V-neck collar (deeper than before, shows shirt)
    cv.fillPoly([[tx+15, ty], [tx+27, ty], [tx+21, ty+12]], ...c.PARCH_L);
    cv.fillPoly([[tx+17, ty], [tx+25, ty], [tx+21, ty+7]], ...c.SKIN, 200);
    // collar trim lines
    cv.line(tx+15, ty, tx+21, ty+12, ...trim);
    cv.line(tx+21, ty+12, tx+27, ty, ...trim);
    // lapel shadow crease
    cv.line(tx+16, ty, tx+21, ty+10, ...body, 100);
    cv.line(tx+21, ty+10, tx+26, ty, ...body, 100);
    // arm shadow lines (give torso depth)
    cv.line(tx+5,  ty+5,  tx+7,  ty+30, ...body, 120);
    cv.line(tx+35, ty+5,  tx+33, ty+30, ...body, 120);

    // ── belt (archetype-specific detail) ────────────────────────────────────
    cv.fillRect(tx+2, ty+22, 38, 4, ...trim, 180);        // belt strap
    cv.fillRect(tx+19, ty+21, 4, 6, ...trim);              // belt buckle
    cv.fillRect(tx+20, ty+22, 2, 4, ...c.PARCH_L, 160);   // buckle highlight
    cv.line(tx+2, ty+22, tx+39, ty+22, ...c.OUTLINE, 80);
    cv.line(tx+2, ty+25, tx+39, ty+25, ...c.OUTLINE, 80);
    cv.line(tx+19, ty+21, tx+22, ty+21, ...c.OUTLINE, 100);
    cv.line(tx+19, ty+26, tx+22, ty+26, ...c.OUTLINE, 100);

    // ── archetype-specific accessories / badge ────────────────────────────────
    if (archetype === 'merchant') {
      // Small coin purse hanging from belt (left side)
      cv.fillRect(tx+6, ty+25, 5, 6, ...c.DIRT_M);
      cv.fillRect(tx+7, ty+25, 3, 1, ...c.WOOD_D, 140);  // drawstring tie
      cv.line(tx+6, ty+25, tx+10, ty+25, ...c.OUTLINE, 120);
      cv.line(tx+6, ty+30, tx+10, ty+30, ...c.OUTLINE, 120);
      cv.line(tx+6, ty+25, tx+6, ty+30, ...c.OUTLINE, 120);
      cv.line(tx+10, ty+25, tx+10, ty+30, ...c.OUTLINE, 120);
      // Gold coin glint on chest (merchant badge)
      cv.sp(tx+31, ty+8, ...c.MERCH_T);
      cv.sp(tx+32, ty+8, ...c.MERCH_T, 160);
      cv.sp(tx+31, ty+9, ...c.MERCH_T, 160);
      cv.sp(tx+32, ty+9, ...c.PARCH_L, 200);   // coin highlight
    } else if (archetype === 'noble') {
      // Brooch on chest (gemstone clasp)
      cv.fillRect(tx+18, ty+4, 7, 5, ...c.NOBLE_T);
      cv.fillRect(tx+19, ty+5, 5, 3, ...c.PARCH_L, 200);  // gem face
      cv.sp(tx+21, ty+5, ...c.WATER_L, 180);               // gem color
      cv.line(tx+18, ty+4, tx+24, ty+4, ...c.OUTLINE, 100);
      cv.line(tx+18, ty+8, tx+24, ty+8, ...c.OUTLINE, 100);
      // Decorative trim on lapels (gold thread lines)
      cv.line(tx+15, ty, tx+17, ty+8, ...c.NOBLE_T, 80);
      cv.line(tx+25, ty, tx+23, ty+8, ...c.NOBLE_T, 80);
    } else if (archetype === 'clergy') {
      // Cross emblem on chest
      cv.fillRect(tx+18, ty+5, 5, 9, ...c.CLERGY_T, 160);
      cv.fillRect(tx+15, ty+8, 11, 3, ...c.CLERGY_T, 160);
      cv.sp(tx+20, ty+7, ...c.PARCH_L, 120);               // cross highlight
      // Cassock stripe lines (robe detailing)
      cv.line(tx+1, ty+28, tx+41, ty+28, ...c.CLERGY_T, 60);
    } else if (archetype === 'guard') {
      // Chest strap (leather baldric — diagonal)
      cv.line(tx+8, ty+2, tx+36, ty+28, ...c.DIRT_M, 180);
      cv.line(tx+9, ty+2, tx+37, ty+28, ...c.DIRT_D, 100);
      // Badge / rank emblem on left chest
      cv.fillRect(tx+8, ty+8, 7, 7, ...c.STONE_D);
      cv.fillRect(tx+9, ty+9, 5, 5, ...c.STONE_L, 180);
      cv.sp(tx+11, ty+11, ...c.STONE_M, 200);              // badge center
      cv.line(tx+8, ty+8, tx+14, ty+8, ...c.OUTLINE, 100);
      cv.line(tx+8, ty+14, tx+14, ty+14, ...c.OUTLINE, 100);
    } else if (archetype === 'commoner') {
      // Worn patch on elbow area (visible mend)
      cv.fillRect(tx+2, ty+16, 5, 5, ...c.DIRT_L, 130);
      cv.line(tx+2, ty+16, tx+6, ty+16, ...c.DIRT_D, 80);
      cv.line(tx+2, ty+20, tx+6, ty+20, ...c.DIRT_D, 80);
      // Simple tool hook (loop of rope or cord at belt)
      cv.line(tx+28, ty+26, tx+31, ty+26, ...c.DIRT_D, 140);
      cv.line(tx+31, ty+26, tx+31, ty+30, ...c.DIRT_D, 140);
    }

    if (elder) {
      cv.fillRect(tx,    ty,    8, 34, ...c.PARCH_L, 140);
      cv.fillRect(tx+34, ty,    8, 34, ...c.PARCH_L, 140);
      cv.line(tx+8,  ty, tx+8,  ty+33, ...trim, 100);
      cv.line(tx+34, ty, tx+34, ty+33, ...trim, 100);
      // diamond clasp
      cv.fillPoly([[ox+32,ty+14],[ox+35,ty+17],[ox+32,ty+20],[ox+29,ty+17]], ...trim);
      cv.sp(ox+32, ty+17, ...c.PARCH_L);
    }
    cv.line(tx,    ty,    tx+41, ty,    ...c.OUTLINE);
    cv.line(tx,    ty,    tx,    ty+33, ...c.OUTLINE);
    cv.line(tx+41, ty,    tx+41, ty+33, ...c.OUTLINE);
    cv.line(tx,    ty+33, tx+41, ty+33, ...c.OUTLINE);
  };

  // ── 30 individual NPC portrait configs (portrait_id 0–29, matching npcs.json order) ──
  // body/trim = faction palette; hat/hatTrim = headwear palette
  const NPC_PORTRAIT_CONFIGS = [
    // ─── Merchant faction (0–10) ────────────────────────────────────────────
    { body: c.MERCH_B,  trim: c.MERCH_T,  hatStyle: 'wide',        hat: c.WOOD_D,   hatTrim: c.MERCH_T,  archetype: 'merchant',  expression: 'smirk'  }, // 0  Aldric Vane — Guild Master
    { body: c.WOOD_M,   trim: c.PLASTER,  hatStyle: 'scarf',       hat: c.PLASTER,  hatTrim: c.DIRT_M,   archetype: 'tavern',    female: true          }, // 1  Sybil Oats  — Tavern Keeper
    { body: c.DIRT_M,   trim: c.DIRT_D,   hatStyle: 'cap',         hat: c.THATCH_D, hatTrim: c.DIRT_D,   archetype: 'craftsman'                        }, // 2  Oswin Tanner — Craftsman
    { body: c.MERCH_B,  trim: c.MERCH_T,  hatStyle: 'scarf',       hat: c.MERCH_T,  hatTrim: c.MERCH_B,  archetype: 'merchant',  female: true          }, // 3  Marta Coin  — Market Trader
    { body: c.STONE_D,  trim: c.STONE_M,  hatStyle: 'bare',        hat: c.HAIR,     hatTrim: c.STONE_M,  archetype: 'craftsman', expression: 'stern'   }, // 4  Rufus Bolt  — Blacksmith
    { body: c.WOOD_M,   trim: c.PLASTER,  hatStyle: 'scarf',       hat: c.PLASTER,  hatTrim: c.WOOD_D,   archetype: 'tavern',    female: true, expression: 'smirk' }, // 5  Nell Picker — Tavern Barmaid
    { body: c.DIRT_M,   trim: c.DIRT_D,   hatStyle: 'pilgrim_hat', hat: c.THATCH_D, hatTrim: c.DIRT_D,   archetype: 'commoner'                         }, // 6  Cob Farrow  — Traveling Merchant
    { body: c.WOOD_M,   trim: c.DIRT_M,   hatStyle: 'cap',         hat: c.PLASTER,  hatTrim: c.DIRT_M,   archetype: 'craftsman'                        }, // 7  Idris Kemp  — Mill Operator
    { body: c.STONE_M,  trim: c.STONE_D,  hatStyle: 'coif',        hat: c.PARCH_L,  hatTrim: c.STONE_M,  archetype: 'commoner',  female: true, expression: 'stern' }, // 8  Bess Wicker — Storage Keeper
    { body: c.DIRT_M,   trim: c.THATCH_D, hatStyle: 'cap',         hat: c.THATCH_D, hatTrim: c.DIRT_D,   archetype: 'commoner'                         }, // 9  Sim Carter  — Transport Worker
    { body: c.MERCH_B,  trim: c.MERCH_T,  hatStyle: 'veil',        hat: c.PARCH_L,  hatTrim: c.MERCH_T,  archetype: 'merchant',  female: true          }, // 10 Greta Flint — Merchant's Wife
    // ─── Noble faction (11–19) ──────────────────────────────────────────────
    { body: c.NOBLE_B,  trim: c.NOBLE_T,  hatStyle: 'coronet',       hat: c.NOBLE_T,  hatTrim: c.PARCH_L,  archetype: 'noble',   elder: true           }, // 11 Edric Fenn   — Alderman
    { body: c.NOBLE_B,  trim: c.NOBLE_T,  hatStyle: 'veil',          hat: c.PARCH_L,  hatTrim: c.NOBLE_T,  archetype: 'noble',   female: true          }, // 12 Isolde Fenn  — Alderman's Wife
    { body: c.NOBLE_B,  trim: c.NOBLE_T,  hatStyle: 'feathered_cap', hat: c.NOBLE_B,  hatTrim: c.NOBLE_T,  archetype: 'noble',   expression: 'smirk'   }, // 13 Calder Fenn  — Alderman's Son
    { body: c.STONE_M,  trim: c.STONE_L,  hatStyle: 'helm',          hat: c.STONE_M,  hatTrim: c.STONE_L,  archetype: 'captain', expression: 'stern'   }, // 14 Bram Guard   — Guard Captain
    { body: c.STONE_M,  trim: c.STONE_D,  hatStyle: 'helm',          hat: c.STONE_M,  hatTrim: c.STONE_D,  archetype: 'guard'                          }, // 15 Wynn Gate    — Town Guard
    { body: c.STONE_D,  trim: c.STONE_M,  hatStyle: 'helm',          hat: c.STONE_D,  hatTrim: c.STONE_M,  archetype: 'guard',   expression: 'worried' }, // 16 Pell Gate    — Town Guard
    { body: c.NOBLE_B,  trim: c.NOBLE_T,  hatStyle: 'coif',          hat: c.PARCH_L,  hatTrim: c.NOBLE_T,  archetype: 'scholar', female: true          }, // 17 Annit Scribe — Clerk
    { body: c.NOBLE_B,  trim: c.STONE_M,  hatStyle: 'cap',           hat: c.STONE_D,  hatTrim: c.NOBLE_T,  archetype: 'noble',   expression: 'stern'   }, // 18 Tomas Reeve  — Tax Collector
    { body: c.NOBLE_B,  trim: c.STONE_M,  hatStyle: 'hood',          hat: c.STONE_M,  hatTrim: c.PARCH_D,  archetype: 'noble',   elder: true           }, // 19 Old Hugh     — Retired Steward
    // ─── Clergy faction (20–29) ─────────────────────────────────────────────
    { body: c.CLERGY_B, trim: c.CLERGY_T, hatStyle: 'mitre',         hat: c.PARCH_L,  hatTrim: c.MERCH_T,  archetype: 'clergy',  elder: true           }, // 20 Aldous Prior    — Head Priest
    { body: c.CLERGY_B, trim: c.CLERGY_T, hatStyle: 'wimple',        hat: c.PARCH_L,  hatTrim: c.CLERGY_T, archetype: 'clergy',  female: true          }, // 21 Maren Nun       — Nun/Healer
    { body: c.CLERGY_B, trim: c.CLERGY_T, hatStyle: 'bare',          hat: c.HAIR,     hatTrim: c.CLERGY_T, archetype: 'clergy',  expression: 'worried' }, // 22 Finn Monk       — Young Monk
    { body: c.PLASTER,  trim: c.DIRT_M,   hatStyle: 'scarf',         hat: c.DIRT_M,   hatTrim: c.PLASTER,  archetype: 'commoner',female: true          }, // 23 Vera Midwife    — Folk Healer
    { body: c.CLERGY_B, trim: c.CLERGY_T, hatStyle: 'wimple',        hat: c.PARCH_L,  hatTrim: c.STONE_M,  archetype: 'clergy',  elder: true, female: true, expression: 'devout' }, // 24 Old Piety  — Devout Elder
    { body: c.STONE_M,  trim: c.CLERGY_B, hatStyle: 'hood',          hat: c.STONE_D,  hatTrim: c.CLERGY_T, archetype: 'clergy'                         }, // 25 Jude Bellringer — Chapel Worker
    { body: c.STONE_D,  trim: c.CLERGY_T, hatStyle: 'veil',          hat: c.INK,      hatTrim: c.STONE_D,  archetype: 'commoner',female: true, expression: 'worried' }, // 26 Constance Widow
    { body: c.DIRT_M,   trim: c.DIRT_D,   hatStyle: 'pilgrim_hat',   hat: c.THATCH_D, hatTrim: c.DIRT_D,   archetype: 'commoner'                       }, // 27 Thomas Pilgrim  — Traveler
    { body: c.GRASS_D,  trim: c.GRASS_M,  hatStyle: 'bare',          hat: c.GRASS_M,  hatTrim: c.DIRT_M,   archetype: 'commoner',female: true          }, // 28 Alys Herbwife   — Herbalist
    { body: c.STONE_D,  trim: c.STONE_M,  hatStyle: 'bare',          hat: c.HAIR,     hatTrim: c.STONE_D,  archetype: 'craftsman',expression: 'stern', skinTone: c.SKIN_SH }, // 29 Denny Gravedigger
  ];

  // Draw all 30 portraits in a 6-column × 5-row grid
  for (let i = 0; i < NPC_PORTRAIT_CONFIGS.length; i++) {
    drawPortrait((i % 6) * 64, Math.floor(i / 6) * 80, NPC_PORTRAIT_CONFIGS[i]);
  }

  return cv.toPNG();
}

// ═══════════════════════════════════════════════════════════════════════════════
// RUMOR STATE ICONS  (ui_state_icons.png — 144×16, nine 16×16 icons)
//   Matches RumorState enum order (states 0–8):
//   col 0  UNAWARE      — empty circle (NPC hasn't heard it)
//   col 1  EVALUATING   — hourglass (pondering / undecided)
//   col 2  BELIEVE      — open scroll with check (accepted)
//   col 3  REJECTING    — bold X mark (actively dismissing)
//   col 4  SPREAD       — speech bubble with ripple (actively spreading)
//   col 5  ACT          — lightning bolt (acting on belief)
//   col 6  CONTRADICTED — crossed arrows (conflicting rumors)
//   col 7  EXPIRED      — broken circle X (rumor died out)
//   col 8  DEFENDING    — kite shield (protecting a subject)
//
// Palette-locked; no colours outside P.  Background transparent.
// ═══════════════════════════════════════════════════════════════════════════════
function makeStateIcons() {
  const cv = createCanvas(144, 16);

  // ── 0: UNAWARE — empty circle ────────────────────────────────────────────
  {
    const ox = 0;
    const pts = [[ox+7,1],[ox+11,2],[ox+14,5],[ox+14,10],[ox+11,13],[ox+7,14],[ox+3,12],[ox+1,8],[ox+1,5],[ox+3,2]];
    cv.fillPoly(pts, ...c.STONE_M, 100);
    for (let i=0; i<pts.length; i++)
      cv.line(...pts[i], ...pts[(i+1)%pts.length], ...c.STONE_D);
    cv.sp(ox+7, 7, ...c.STONE_D);
    cv.sp(ox+7, 8, ...c.STONE_D);
    cv.sp(ox+8, 7, ...c.STONE_D);
  }

  // ── 1: EVALUATING — hourglass ─────────────────────────────────────────────
  {
    const ox = 16;
    cv.fillPoly([[ox+3,1],[ox+12,1],[ox+10,6],[ox+5,6]], ...c.THATCH_L);
    cv.fillPoly([[ox+5,9],[ox+10,9],[ox+12,15],[ox+3,15]], ...c.THATCH_L);
    cv.fillRect(ox+6, 6, 3, 4, ...c.MERCH_T);
    cv.line(ox+3, 1, ox+12, 1,  ...c.OUTLINE);
    cv.line(ox+12,1, ox+10, 6,  ...c.OUTLINE);
    cv.line(ox+10,6, ox+12, 15, ...c.OUTLINE);
    cv.line(ox+12,15,ox+3,  15, ...c.OUTLINE);
    cv.line(ox+3, 15,ox+5,  9,  ...c.OUTLINE);
    cv.line(ox+5, 9, ox+5,  6,  ...c.OUTLINE);
    cv.line(ox+5, 6, ox+3,  1,  ...c.OUTLINE);
  }

  // ── 2: BELIEVE — scroll with check ────────────────────────────────────────
  {
    const ox = 32;
    cv.fillRect(ox+1, 2, 13, 12, ...c.PARCH_M);
    cv.fillRect(ox+1, 1, 13, 3, ...c.PARCH_D);
    cv.fillRect(ox+1, 12, 13, 3, ...c.PARCH_D);
    cv.line(ox+4, 5, ox+11, 5, ...c.INK, 180);
    cv.line(ox+4, 7, ox+11, 7, ...c.INK, 140);
    cv.line(ox+4, 9, ox+8,  9, ...c.INK, 120);
    // check mark
    cv.line(ox+9, 9, ox+10,11, ...c.WOOD_D);
    cv.line(ox+10,11,ox+13, 7, ...c.WOOD_D);
    cv.line(ox+1, 1, ox+13, 1,  ...c.OUTLINE);
    cv.line(ox+1, 1, ox+1, 14,  ...c.OUTLINE);
    cv.line(ox+13,1, ox+13,14,  ...c.OUTLINE);
    cv.line(ox+1,14, ox+13,14,  ...c.OUTLINE);
  }

  // ── 3: REJECTING — bold X ────────────────────────────────────────────────
  {
    const ox = 48;
    cv.fillPoly([[ox+2,1],[ox+5,1],[ox+8,5],[ox+11,1],[ox+14,1],[ox+14,4],[ox+11,7],
                 [ox+14,12],[ox+14,15],[ox+11,15],[ox+8,11],[ox+5,15],[ox+2,15],
                 [ox+2,12],[ox+5,7],[ox+2,4]], ...c.NOBLE_B);
    cv.sp(ox+7, 7, ...c.NOBLE_T);
    cv.sp(ox+8, 8, ...c.NOBLE_T);
    cv.line(ox+2, 1, ox+14, 13, ...c.OUTLINE);
    cv.line(ox+14,1, ox+2,  13, ...c.OUTLINE);
  }

  // ── 4: SPREAD — speech bubble with ripple ────────────────────────────────
  {
    const ox = 64;
    cv.fillRect(ox+1, 1, 11, 8, ...c.PARCH_L);
    cv.fillPoly([[ox+3,9],[ox+7,9],[ox+4,14]], ...c.PARCH_L);
    cv.sp(ox+4, 4, ...c.CANVAS);
    cv.sp(ox+7, 4, ...c.CANVAS);
    cv.sp(ox+10,4, ...c.CANVAS);
    // ripple arcs
    cv.sp(ox+13, 3, ...c.FORGE, 180);
    cv.sp(ox+13, 5, ...c.FORGE, 200);
    cv.sp(ox+13, 7, ...c.FORGE, 180);
    cv.sp(ox+14, 4, ...c.FORGE, 140);
    cv.sp(ox+14, 6, ...c.FORGE, 140);
    cv.line(ox+1, 1, ox+11, 1,  ...c.OUTLINE);
    cv.line(ox+1, 1, ox+1,  8,  ...c.OUTLINE);
    cv.line(ox+1, 8, ox+11, 8,  ...c.OUTLINE);
    cv.line(ox+11,1, ox+11, 8,  ...c.OUTLINE);
    cv.line(ox+3, 9, ox+4, 14,  ...c.OUTLINE);
    cv.line(ox+7, 9, ox+4, 14,  ...c.OUTLINE);
  }

  // ── 5: ACT — lightning bolt ───────────────────────────────────────────────
  {
    const ox = 80;
    cv.fillPoly([[ox+8,1],[ox+4,7],[ox+7,7],[ox+5,15],[ox+12,6],[ox+8,6],[ox+11,1]], ...c.FLAG_R);
    cv.line(ox+8,  1, ox+11, 1, ...c.ROOF_TILE, 200);
    cv.line(ox+12, 6, ox+8,  6, ...c.ROOF_TILE, 160);
    cv.line(ox+8, 1, ox+11, 1,  ...c.OUTLINE);
    cv.line(ox+11,1, ox+12, 6,  ...c.OUTLINE);
    cv.line(ox+12,6, ox+8,  6,  ...c.OUTLINE);
    cv.line(ox+8, 6, ox+5, 15,  ...c.OUTLINE);
    cv.line(ox+5,15, ox+4,  7,  ...c.OUTLINE);
    cv.line(ox+4, 7, ox+7,  7,  ...c.OUTLINE);
    cv.line(ox+7, 7, ox+8,  1,  ...c.OUTLINE);
  }

  // ── 6: CONTRADICTED — two arrows clashing ────────────────────────────────
  {
    const ox = 96;
    // right-pointing arrow (top)
    cv.line(ox+1, 5, ox+7, 5, ...c.MERCH_B);
    cv.fillPoly([[ox+6,3],[ox+9,5],[ox+6,7]], ...c.MERCH_B);
    // left-pointing arrow (bottom)
    cv.line(ox+14,10, ox+8, 10, ...c.NOBLE_B);
    cv.fillPoly([[ox+9,8],[ox+6,10],[ox+9,12]], ...c.NOBLE_B);
    // clash marks
    cv.line(ox+6, 5, ox+10,10, ...c.OUTLINE);
    cv.line(ox+10,5, ox+6, 10, ...c.OUTLINE);
    cv.line(ox+1, 5, ox+6, 5,  ...c.OUTLINE);
    cv.line(ox+14,10,ox+9, 10, ...c.OUTLINE);
  }

  // ── 7: EXPIRED — circle with X ───────────────────────────────────────────
  {
    const ox = 112;
    const pts = [[ox+7,1],[ox+11,2],[ox+14,5],[ox+14,10],[ox+11,13],[ox+7,14],[ox+3,12],[ox+1,8],[ox+1,5],[ox+3,2]];
    cv.fillPoly(pts, ...c.STONE_M, 200);
    cv.line(ox+4, 4, ox+11, 11, ...c.STONE_D);
    cv.line(ox+11,4, ox+4,  11, ...c.STONE_D);
    for (let i=0; i<pts.length; i++)
      cv.line(...pts[i], ...pts[(i+1)%pts.length], ...c.OUTLINE);
  }

  // ── 8: DEFENDING — kite shield ───────────────────────────────────────────
  {
    const ox = 128;
    cv.fillPoly([
      [ox+4,1],[ox+11,1],[ox+14,4],[ox+14,10],[ox+8,15],[ox+2,10],[ox+2,4],
    ], ...c.WATER_D);
    // boss line + center diamond
    cv.line(ox+2, 8, ox+14, 8, ...c.WATER_L, 180);
    cv.fillRect(ox+6, 6, 4, 4, ...c.WATER_L, 160);
    cv.sp(ox+7, 7, ...c.WATER_L);
    cv.sp(ox+8, 8, ...c.WATER_L);
    // outline
    cv.line(ox+4, 1,  ox+11,1,  ...c.OUTLINE);
    cv.line(ox+11,1,  ox+14,4,  ...c.OUTLINE);
    cv.line(ox+14,4,  ox+14,10, ...c.OUTLINE);
    cv.line(ox+14,10, ox+8, 15, ...c.OUTLINE);
    cv.line(ox+8, 15, ox+2, 10, ...c.OUTLINE);
    cv.line(ox+2, 10, ox+2, 4,  ...c.OUTLINE);
    cv.line(ox+2, 4,  ox+4, 1,  ...c.OUTLINE);
  }

  return cv.toPNG();
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROPS ATLAS  (tiles_props.png — 960×32, fifteen 64×32 isometric prop tiles)
//   0=crate  1=barrel  2=sign  3=fence  4=cart  5=hay_bale  6=flower_pot  7=well_bucket
//   8=oak_tree  9=lantern_post  10=garden_bed  (SPA-526)
//   11=market_stall  12=bench  13=stone_well   (SPA-551)
//   14=chapel_candle                            (SPA-595)
//   15=woodpile  16=notice_board  17=iron_torch (SPA-602)
//   col 0  CRATE        — wooden storage crate
//   col 1  BARREL       — wooden barrel
//   col 2  SIGN         — post-mounted wooden sign
//   col 3  FENCE        — short fence segment
//   col 4  CART         — two-wheeled merchant cart
//   col 5  HAY_BALE     — round hay bale
//   col 6  FLOWER_POT   — terracotta pot with flowers
//   col 7  WELL_BUCKET  — wooden bucket with rope
//
// Each tile is 64×32 (same as ground tiles).  Props are drawn as small 2.5D
// objects sitting on the ground surface (base near y=26, top near y=10).
// Palette-locked; all colours from P.  Background transparent.
// ═══════════════════════════════════════════════════════════════════════════════
function makePropsAtlas() {
  const cv = createCanvas(1152, 32);  // SPA-602: expanded from 960 to 1152 (props 15–17: woodpile, notice_board, iron_torch)

  // ── shared: draw an isometric cuboid centred at (cx, cy) ──────────────────
  // hw/hh = iso half-width/height of top face; bh = box height in screen pixels
  const drawCuboid = (cx, cy, hw, hh, bh, tCol, lCol, rCol) => {
    // top face
    cv.fillPoly([
      [cx-hw, cy-bh], [cx, cy-bh-hh],
      [cx+hw, cy-bh], [cx, cy-bh+hh],
    ], ...tCol);
    outlineIso(cv, ...c.OUTLINE, cx, cy-bh, hw, hh);
    // left face
    cv.fillPoly([
      [cx-hw, cy-bh], [cx, cy-bh+hh],
      [cx, cy+hh],    [cx-hw, cy],
    ], ...lCol);
    cv.line(cx-hw, cy-bh, cx-hw, cy, ...c.OUTLINE);
    cv.line(cx-hw, cy,    cx, cy+hh,  ...c.OUTLINE);
    // right face
    cv.fillPoly([
      [cx, cy-bh+hh], [cx+hw, cy-bh],
      [cx+hw, cy],    [cx, cy+hh],
    ], ...rCol);
    cv.line(cx+hw, cy-bh, cx+hw, cy, ...c.OUTLINE);
    cv.line(cx+hw, cy,    cx, cy+hh,  ...c.OUTLINE);
  };

  // ── 0: CRATE ──────────────────────────────────────────────────────────────
  {
    const ox=0, cx=ox+32, cy=25;
    drawCuboid(cx, cy, 12, 6, 10, c.WOOD_L, c.WOOD_M, c.WOOD_D);
    // plank lines on left face
    cv.line(cx-12, cy-4, cx, cy+2,    ...c.WOOD_D, 80);
    cv.line(cx-12, cy-7, cx, cy-1,    ...c.WOOD_D, 50);  // extra plank
    // plank lines on right face
    cv.line(cx, cy+2,  cx+12, cy-4,   ...c.WOOD_D, 60);
    // wood grain noise on top face
    cv.sp(cx-4, cy-11, ...c.WOOD_L, 80);
    cv.sp(cx+2, cy-12, ...c.WOOD_D, 60);
    // metal corner rivets (4 corners)
    cv.sp(cx-12, cy-10, ...c.STONE_L);
    cv.sp(cx-1,  cy-14, ...c.STONE_L);
    cv.sp(cx-1,  cy+5,  ...c.STONE_L);
    cv.sp(cx+12, cy-10, ...c.STONE_L);
    cv.sp(cx+1,  cy+5,  ...c.STONE_L);
    // central latch on front face
    cv.sp(cx, cy-2, ...c.STONE_L);
  }

  // ── 1: BARREL ─────────────────────────────────────────────────────────────
  {
    const ox=64, cx=ox+32, cy=25;
    // barrel body (approximated as narrow cuboid with rounded lines)
    drawCuboid(cx, cy, 9, 4, 12, c.WOOD_L, c.WOOD_M, c.WOOD_D);
    // hoop bands (3 dark horizontal lines wrapping the barrel)
    cv.line(cx-9, cy-5,  cx, cy-1,  ...c.WOOD_D);
    cv.line(cx-9, cy,    cx, cy+4,  ...c.WOOD_D);
    cv.line(cx-9, cy-10, cx, cy-6,  ...c.WOOD_D);
    // hoop bands on right face
    cv.line(cx, cy-1,  cx+9, cy-5,  ...c.WOOD_D);
    cv.line(cx, cy+4,  cx+9, cy,    ...c.WOOD_D);
    cv.line(cx, cy-6,  cx+9, cy-10, ...c.WOOD_D);
    // dark stave lines on left face (barrel boards)
    cv.line(cx-5, cy-11, cx-5, cy+3, ...c.WOOD_D, 60);
    cv.line(cx-2, cy-12, cx-2, cy+4, ...c.WOOD_D, 40);
    cv.line(cx+3, cy-12, cx+3, cy+4, ...c.WOOD_D, 40);
    // moisture/age stain on lower barrel
    cv.sp(cx-3, cy+2, ...c.WOOD_D, 80);
    cv.sp(cx+2, cy+3, ...c.WOOD_D, 60);
    // bung hole dot
    cv.sp(cx-1, cy-4, ...c.STONE_M);
  }

  // ── 2: SIGN ───────────────────────────────────────────────────────────────
  {
    const ox=128, cx=ox+32, cy=28;
    // post (2px wide, extends from ground to above mid-tile)
    cv.fillRect(cx-1, 4, 2, cy-3, ...c.WOOD_D);
    cv.line(cx-1, 4, cx, 4, ...c.OUTLINE);
    cv.line(cx-1, 4, cx-1, cy-3, ...c.OUTLINE);
    cv.line(cx,   4, cx, cy-3, ...c.OUTLINE);
    // sign board (angled slightly for iso feel)
    cv.fillRect(cx-7, 6, 14, 8, ...c.WOOD_M);
    cv.fillRect(cx-6, 7, 12, 6, ...c.PARCH_L);
    // "text" lines on sign
    cv.line(cx-4, 9,  cx+4, 9,  ...c.INK, 160);
    cv.line(cx-3, 11, cx+3, 11, ...c.INK, 120);
    // board outline
    cv.line(cx-7, 6,  cx+6, 6,  ...c.OUTLINE);
    cv.line(cx-7, 13, cx+6, 13, ...c.OUTLINE);
    cv.line(cx-7, 6,  cx-7, 13, ...c.OUTLINE);
    cv.line(cx+6, 6,  cx+6, 13, ...c.OUTLINE);
    // decorative bracket arm (post to sign)
    cv.line(cx-1, 5, cx-1, 7, ...c.WOOD_D, 120);
    // knot detail on post
    cv.sp(cx, 16, ...c.WOOD_D, 100);
    cv.sp(cx-1, 17, ...c.WOOD_D, 70);
    // third text line on parchment
    cv.line(cx-2, 12, cx+2, 12, ...c.INK, 80);
  }

  // ── 3: FENCE ──────────────────────────────────────────────────────────────
  {
    const ox=192, cx=ox+32, cy=27;
    // two posts left and right
    cv.fillRect(cx-18, 12, 3, cy-11, ...c.WOOD_M);
    cv.fillRect(cx+15, 12, 3, cy-11, ...c.WOOD_M);
    cv.line(cx-18, 12, cx-16, 12, ...c.OUTLINE);
    cv.line(cx+15, 12, cx+17, 12, ...c.OUTLINE);
    // two horizontal rails
    cv.line(cx-18, 16, cx+17, 16, ...c.WOOD_D);
    cv.line(cx-18, 22, cx+17, 22, ...c.WOOD_D);
    // pickets between rails
    for (let px = cx-12; px < cx+14; px += 6) {
      cv.fillRect(px, 15, 2, 9, ...c.WOOD_M);
      cv.line(px, 15, px+1, 15, ...c.OUTLINE);
    }
  }

  // ── 4: CART ───────────────────────────────────────────────────────────────
  {
    const ox=256, cx=ox+32, cy=24;
    // cart body box (low and wide)
    drawCuboid(cx, cy, 14, 7, 7, c.WOOD_L, c.WOOD_M, c.WOOD_D);
    // planks on left face
    cv.line(cx-14, cy-1, cx, cy+5, ...c.WOOD_D, 70);
    cv.line(cx-14, cy-4, cx, cy+2, ...c.WOOD_D, 70);
    // two wheels (left side visible)
    const drawWheel = (wx, wy, r) => {
      for (let a = 0; a < Math.PI*2; a += 0.35)
        cv.sp(wx + Math.round(r*Math.cos(a)), wy + Math.round(r*Math.sin(a)), ...c.WOOD_D);
      // spokes
      for (let a = 0; a < Math.PI*2; a += Math.PI/3)
        cv.line(wx, wy, wx+Math.round((r-1)*Math.cos(a)), wy+Math.round((r-1)*Math.sin(a)), ...c.WOOD_D, 160);
      cv.sp(wx, wy, ...c.STONE_L);  // hub
    };
    drawWheel(cx-16, cy+2, 5);
    drawWheel(cx+14, cy-3, 5);
    // handles extending front
    cv.line(cx-5, cy+7, cx-10, cy+12, ...c.WOOD_D);
    cv.line(cx+5, cy+7, cx+10, cy+12, ...c.WOOD_D);
    // cargo: burlap sack on cart bed
    cv.fillRect(cx-6, cy-12, 8, 6, ...c.DIRT_L);
    cv.line(cx-6, cy-12, cx+1, cy-12, ...c.DIRT_D);
    cv.line(cx-6, cy-12, cx-6, cy-7,  ...c.DIRT_D);
    cv.line(cx+1, cy-12, cx+1, cy-7,  ...c.DIRT_D);
    cv.sp(cx-3, cy-10, ...c.DIRT_M, 150);   // sack crease
    // wheel shadow dot (ground contact)
    cv.sp(cx-15, cy+6, ...c.OUTLINE, 40);
    cv.sp(cx+14, cy+1, ...c.OUTLINE, 40);
  }

  // ── 5: HAY_BALE ───────────────────────────────────────────────────────────
  {
    const ox=320, cx=ox+32, cy=24;
    // round bale (iso cylinder approximation using wide cuboid)
    drawCuboid(cx, cy, 14, 6, 9, c.THATCH_L, c.THATCH_L, c.THATCH_D);
    // wrap lines (simulate twine bands)
    cv.line(cx-10, cy-5, cx-2, cy-1, ...c.THATCH_D, 120);
    cv.line(cx-3,  cy-2, cx+8, cy-7, ...c.THATCH_D, 120);
    // straw tufts sticking out top
    for (let tx = cx-8; tx <= cx+8; tx += 4)
      cv.sp(tx, cy-9-((tx-cx)%3 === 0 ? 2 : 0), ...c.THATCH_L, 180);
    // bale outline (rounded feel)
    cv.line(cx-14, cy-9, cx, cy-15, ...c.OUTLINE);
    cv.line(cx, cy-15, cx+14, cy-9, ...c.OUTLINE);
    // dense straw fringe on left face
    for (let tx=cx-12; tx<=cx-2; tx+=3)
      cv.sp(tx, cy-9+((tx%3===0)?1:0), ...c.THATCH_D, 90);
    // right face straw texture
    for (let tx=cx+2; tx<=cx+12; tx+=3)
      cv.sp(tx, cy-9+((tx%3===0)?1:0), ...c.THATCH_D, 70);
    // twine knot at centre of bale
    cv.sp(cx, cy-6, ...c.WOOD_D, 180);
    cv.sp(cx-1, cy-7, ...c.WOOD_D, 120);
    cv.sp(cx+1, cy-7, ...c.WOOD_D, 120);
  }

  // ── 6: FLOWER_POT ─────────────────────────────────────────────────────────
  {
    const ox=384, cx=ox+32, cy=27;
    // terracotta pot (trapezoid, wider at top)
    cv.fillPoly([
      [cx-5, cy-9], [cx+4, cy-9],
      [cx+6, cy],   [cx-7, cy],
    ], ...c.ROOF_TILE);
    cv.fillRect(cx-6, cy-9, 11, 2, ...c.ROOF_TILE); // lip
    cv.line(cx-6, cy-9, cx+4, cy-9, ...c.OUTLINE);
    cv.line(cx-7, cy,   cx+6, cy,   ...c.OUTLINE);
    cv.line(cx-6, cy-9, cx-7, cy,   ...c.OUTLINE);
    cv.line(cx+4, cy-9, cx+6, cy,   ...c.OUTLINE);
    // soil (dark circle inside pot)
    cv.fillRect(cx-4, cy-11, 7, 3, ...c.DIRT_D);
    cv.line(cx-4, cy-11, cx+2, cy-11, ...c.OUTLINE);
    // flower stems and blooms
    cv.line(cx-1, cy-11, cx-2, cy-16, ...c.GRASS_M);
    cv.line(cx+1, cy-11, cx+2, cy-16, ...c.GRASS_M);
    cv.sp(cx-2, cy-17, ...c.FLAG_R);               // red flower
    cv.sp(cx-3, cy-16, ...c.FLAG_R, 160);
    cv.sp(cx+2, cy-17, ...c.CANVAS);               // gold flower
    cv.sp(cx+3, cy-16, ...c.CANVAS, 160);
  }

  // ── 7: WELL_BUCKET ────────────────────────────────────────────────────────
  {
    const ox=448, cx=ox+32, cy=26;
    // bucket body (tapered — wider at top)
    cv.fillPoly([
      [cx-5, cy-8], [cx+4, cy-8],
      [cx+3, cy],   [cx-4, cy],
    ], ...c.WOOD_M);
    cv.line(cx-5, cy-8, cx+4, cy-8, ...c.STONE_L);    // metal rim at top
    cv.line(cx-4, cy,   cx+3, cy,   ...c.OUTLINE);    // bucket base
    cv.line(cx-5, cy-8, cx-4, cy,   ...c.OUTLINE);
    cv.line(cx+4, cy-8, cx+3, cy,   ...c.OUTLINE);
    // plank lines on bucket
    cv.line(cx-5, cy-5, cx+4, cy-5, ...c.WOOD_D, 80);
    cv.line(cx-4, cy-2, cx+3, cy-2, ...c.WOOD_D, 80);
    // handle arc
    cv.line(cx-5, cy-8, cx-5, cy-14, ...c.STONE_L);
    cv.line(cx+4, cy-8, cx+4, cy-14, ...c.STONE_L);
    cv.line(cx-5, cy-14, cx+4, cy-14, ...c.STONE_L);
    // rope hanging from above
    cv.line(cx, cy-14, cx, cy-20, ...c.WOOD_D, 180);
  }

  // ── 8: OAK_TREE ───────────────────────────────────────────────────────────────
  {
    const ox=512, cx=ox+32, cy=27;
    // trunk (narrow, from ground up ~13px)
    cv.fillRect(cx-2, cy-12, 4, 13, ...c.WOOD_D);
    cv.line(cx-2, cy-12, cx+1, cy-12, ...c.OUTLINE);
    cv.line(cx-2, cy-12, cx-2, cy,    ...c.OUTLINE);
    cv.line(cx+1, cy-12, cx+1, cy,    ...c.OUTLINE);
    cv.line(cx-1, cy-10, cx-1, cy-5,  ...c.WOOD_M, 100);  // bark texture
    cv.line(cx+0, cy-8,  cx+0, cy-3,  ...c.WOOD_M, 80);
    cv.sp(cx-3, cy-1, ...c.WOOD_D);   // root flares
    cv.sp(cx+2, cy-1, ...c.WOOD_D);
    // canopy outer dark ring
    for (let a=0; a<Math.PI*2; a+=0.15)
      cv.sp(cx+Math.round(12*Math.cos(a)), cy-18+Math.round(7*Math.sin(a)), ...c.GRASS_D);
    // canopy mid fill
    for (let dy2=-6; dy2<=6; dy2++) {
      for (let dx2=-11; dx2<=11; dx2++) {
        if (dx2*dx2/121 + dy2*dy2/49 <= 1.0)
          cv.sp(cx+dx2, cy-18+dy2, ...c.GRASS_M);
      }
    }
    // canopy highlight (top-left catch-light)
    for (let dy2=-5; dy2<=1; dy2++) {
      for (let dx2=-8; dx2<=-2; dx2++) {
        if (dx2*dx2/64 + dy2*dy2/36 <= 1.0)
          cv.sp(cx+dx2, cy-20+dy2, ...c.GRASS_L, 180);
      }
    }
    cv.isoNoise(cx, cy-18, 10, 6, ...c.GRASS_D, 8, 0.20);
    cv.isoNoise(cx, cy-18, 10, 6, ...c.GRASS_L, 6, 0.10);
  }

  // ── 9: LANTERN_POST ────────────────────────────────────────────────────────────
  {
    const ox=576, cx=ox+32, cy=27;
    // tall post (2px wide, stone-grey)
    cv.fillRect(cx-1, 4, 2, cy-3, ...c.STONE_M);
    cv.line(cx-1, 4,  cx,  4,    ...c.OUTLINE);
    cv.line(cx-1, 4,  cx-1, cy-3, ...c.OUTLINE);
    cv.line(cx,   4,  cx,   cy-3, ...c.OUTLINE);
    // decorative iron band mid-post
    cv.fillRect(cx-2, cy-16, 4, 2, ...c.STONE_D);
    cv.line(cx-2, cy-16, cx+1, cy-16, ...c.OUTLINE);
    // lantern housing box
    cv.fillRect(cx-5, 2, 9, 7, ...c.STONE_D);
    cv.line(cx-5, 2,  cx+3, 2,  ...c.OUTLINE);
    cv.line(cx-5, 8,  cx+3, 8,  ...c.OUTLINE);
    cv.line(cx-5, 2,  cx-5, 8,  ...c.OUTLINE);
    cv.line(cx+3, 2,  cx+3, 8,  ...c.OUTLINE);
    // warm glow inner fill
    cv.fillRect(cx-3, 3, 6, 5, ...c.CANVAS, 200);
    // lantern cap (triangle)
    cv.fillPoly([[cx-5, 2], [cx+3, 2], [cx-1, -2]], ...c.STONE_D);
    // soft bloom around lantern
    for (let gly=-3; gly<=5; gly++) {
      for (let glx=-7; glx<=7; glx++) {
        const dist = Math.sqrt(glx*glx + gly*gly);
        if (dist < 8 && dist > 4)
          cv.sp(cx+glx, 5+gly, ...c.CANVAS, Math.max(0, (8-dist)*10)|0);
      }
    }
  }

  // ── 10: GARDEN_BED ────────────────────────────────────────────────────────────
  {
    const ox=640, cx=ox+32, cy=26;
    // raised plank frame (low iso cuboid)
    drawCuboid(cx, cy, 14, 6, 5, c.WOOD_M, c.WOOD_D, c.WOOD_D);
    cv.line(cx-14, cy-1, cx, cy+5, ...c.WOOD_D, 60);   // plank lines
    cv.line(cx, cy+5, cx+14, cy-1, ...c.WOOD_D, 60);
    // soil top face
    cv.fillPoly([
      [cx-14, cy-5], [cx, cy-11],
      [cx+14, cy-5], [cx, cy+1],
    ], ...c.DIRT_D);
    cv.isoNoise(cx, cy-5, 13, 5, ...c.DIRT_M, 8, 0.15);
    // plant tufts in a row
    const plantXs = [cx-8, cx-3, cx+2, cx+8];
    for (const px of plantXs) {
      cv.line(px, cy-5, px, cy-11, ...c.GRASS_M);
      cv.sp(px-1, cy-11, ...c.GRASS_L, 180);
      cv.sp(px,   cy-12, ...c.GRASS_L, 220);
      cv.sp(px+1, cy-11, ...c.GRASS_L, 180);
      cv.sp(px,   cy-13, ...c.GRASS_D, 150);
    }
  }

  // ── 11: MARKET_STALL (SPA-551) — wooden counter with CANVAS awning + FLAG_R stripe
  {
    const ox=704, cx=ox+32, cy=24;
    // counter body (low, wide cuboid)
    drawCuboid(cx, cy, 16, 6, 4, c.WOOD_L, c.WOOD_M, c.WOOD_D);
    // plank line on counter top
    cv.line(cx-14, cy-1, cx, cy+4, ...c.WOOD_D, 50);
    // goods on counter surface (parchment-coloured bundles)
    cv.fillRect(cx-11, cy-8, 5, 3, ...c.PARCH_L);
    cv.line(cx-11, cy-8, cx-7, cy-8, ...c.PARCH_D, 120);
    cv.fillRect(cx+3, cy-8, 4, 3, ...c.PARCH_L);
    // two support posts at front corners
    cv.fillRect(cx-17, cy-13, 2, 13, ...c.WOOD_D);
    cv.line(cx-17, cy-13, cx-16, cy-13, ...c.OUTLINE);
    cv.fillRect(cx+15, cy-13, 2, 13, ...c.WOOD_D);
    cv.line(cx+15, cy-13, cx+16, cy-13, ...c.OUTLINE);
    // awning (flat quadrilateral slanting back from posts)
    cv.fillPoly([[cx-17, cy-12], [cx+16, cy-12], [cx+11, cy-18], [cx-12, cy-18]], ...c.CANVAS);
    // red stripe along front awning edge
    cv.line(cx-17, cy-12, cx+16, cy-12, ...c.FLAG_R);
    cv.line(cx-16, cy-13, cx+15, cy-13, ...c.FLAG_R, 160);
    // awning outline
    cv.line(cx-12, cy-18, cx+11, cy-18, ...c.OUTLINE);
    cv.line(cx-17, cy-12, cx-12, cy-18, ...c.OUTLINE);
    cv.line(cx+16, cy-12, cx+11, cy-18, ...c.OUTLINE);
  }

  // ── 12: BENCH (SPA-551) — simple wooden bench, seat + four legs ───────────────
  {
    const ox=768, cx=ox+32, cy=26;
    // seat plank (low cuboid)
    drawCuboid(cx, cy, 13, 5, 3, c.WOOD_L, c.WOOD_M, c.WOOD_D);
    // wood grain on top face
    cv.line(cx-11, cy-2, cx,   cy+3, ...c.WOOD_D, 50);
    cv.line(cx-3,  cy-3, cx+8, cy+2, ...c.WOOD_D, 35);
    // four legs (two visible pairs in iso)
    const legXs = [cx-12, cx-2, cx+3, cx+11];
    for (const lx of legXs) {
      cv.fillRect(lx-1, cy+1, 2, 4, ...c.WOOD_D);
      cv.line(lx-1, cy+1, lx, cy+1, ...c.OUTLINE);
      cv.line(lx-1, cy+5, lx+1, cy+5, ...c.OUTLINE);
    }
  }

  // ── 13: STONE_WELL (SPA-551) — stone drum, wooden A-frame, rope ──────────────
  {
    const ox=832, cx=ox+32, cy=22;
    const wr=9, wh=8;   // well radius / wall height
    // top rim face (iso ellipse approximation)
    for (let y2=cy-4; y2<=cy+4; y2++) {
      for (let x2=cx-wr; x2<=cx+wr; x2++) {
        if (Math.abs(x2-cx)/wr + Math.abs(y2-cy)/4 <= 1.0)
          cv.sp(x2, y2, ...c.STONE_L);
      }
    }
    cv.isoNoise(cx, cy, wr-1, 3, ...c.STONE_M, 8, 0.25);
    // water surface inside
    for (let y2=cy-2; y2<=cy+2; y2++) {
      for (let x2=cx-6; x2<=cx+6; x2++) {
        if (Math.abs(x2-cx)/6 + Math.abs(y2-cy)/2 <= 0.90)
          cv.sp(x2, y2, ...c.WATER_D, 190);
      }
    }
    cv.sp(cx-2, cy-1, ...c.WATER_L, 130);
    // left face of stone drum
    cv.fillPoly([[cx-wr, cy], [cx, cy+4], [cx, cy+4+wh], [cx-wr, cy+wh]], ...c.STONE_M);
    cv.line(cx-wr, cy+3, cx, cy+6, ...c.STONE_D, 70);   // mortar seam
    cv.line(cx-wr, cy+6, cx, cy+9, ...c.STONE_D, 50);
    // right face (darker)
    cv.fillPoly([[cx, cy+4], [cx+wr, cy], [cx+wr, cy+wh], [cx, cy+4+wh]], ...c.STONE_D);
    // drum outline
    cv.line(cx-wr, cy, cx, cy+4, ...c.OUTLINE);
    cv.line(cx, cy+4, cx+wr, cy, ...c.OUTLINE);
    cv.line(cx-wr, cy, cx-wr, cy+wh, ...c.OUTLINE);
    cv.line(cx+wr, cy, cx+wr, cy+wh, ...c.OUTLINE);
    cv.line(cx-wr, cy+wh, cx, cy+4+wh, ...c.OUTLINE);
    cv.line(cx, cy+4+wh, cx+wr, cy+wh, ...c.OUTLINE);
    // A-frame: two diagonal legs meeting at apex
    cv.line(cx-7, cy-2, cx, cy-16, ...c.WOOD_D);
    cv.line(cx+7, cy-2, cx, cy-16, ...c.WOOD_D);
    cv.line(cx-7, cy-2, cx, cy-16, ...c.WOOD_M, 70);   // highlight sheen
    // crossbar
    cv.line(cx-5, cy-10, cx+5, cy-10, ...c.WOOD_D);
    // rope hanging from crossbar centre
    cv.line(cx, cy-10, cx, cy-3, ...c.WOOD_D, 190);
    // apex peg / pulley
    cv.sp(cx, cy-16, ...c.STONE_M);
    cv.sp(cx-1, cy-16, ...c.STONE_D, 160);
  }

  // ── 14: CHAPEL_CANDLE (SPA-595) — ivory pillar candle, FORGE flame, warm halo ──
  {
    const ox=896, cx=ox+32, cy=27;
    // stone base plate (low iso diamond, STONE_M)
    cv.fillPoly([[cx-6, cy], [cx, cy+3], [cx+6, cy], [cx, cy-3]], ...c.STONE_M);
    cv.line(cx-6, cy,   cx,   cy-3, ...c.OUTLINE);
    cv.line(cx,   cy-3, cx+6, cy,   ...c.OUTLINE);
    // candle body (CHAPEL_STONE — ivory column, ~16px tall, slightly tapered)
    cv.fillPoly([
      [cx-3, cy-16], [cx+3, cy-16],
      [cx+4, cy],    [cx-4, cy],
    ], ...c.CHAPEL_STONE);
    cv.line(cx-3, cy-16, cx+3, cy-16, ...c.OUTLINE);
    cv.line(cx-4, cy,    cx+4, cy,    ...c.OUTLINE);
    cv.line(cx-3, cy-16, cx-4, cy,    ...c.OUTLINE);
    cv.line(cx+3, cy-16, cx+4, cy,    ...c.OUTLINE);
    // shadow side of candle body (right face slightly darker)
    cv.line(cx+3, cy-16, cx+4, cy, ...c.STONE_M, 80);
    // melted wax drip on left side
    cv.sp(cx-3, cy-10, ...c.CHAPEL_STONE, 200);
    cv.sp(cx-4, cy-9,  ...c.CHAPEL_STONE, 180);
    cv.sp(cx-4, cy-8,  ...c.CHAPEL_STONE, 130);
    // melt pool at candle top (wider, PLASTER tint)
    cv.line(cx-4, cy-16, cx+4, cy-16, ...c.PLASTER, 180);
    // wick
    cv.sp(cx, cy-17, ...c.INK, 220);
    // flame — FORGE core with CANVAS tip and base glow
    cv.sp(cx,   cy-22, ...c.CANVAS, 200);   // tip
    cv.sp(cx,   cy-21, ...c.FORGE,  240);
    cv.sp(cx-1, cy-20, ...c.FORGE,  220);
    cv.sp(cx+1, cy-20, ...c.FORGE,  220);
    cv.sp(cx,   cy-20, ...c.FORGE,  255);
    cv.sp(cx-1, cy-19, ...c.FORGE,  190);
    cv.sp(cx+1, cy-19, ...c.FORGE,  190);
    cv.sp(cx,   cy-19, ...c.FORGE,  230);
    cv.sp(cx,   cy-18, ...c.CANVAS, 170);   // base glow
    // warm bloom halo around flame
    for (let gly = -7; gly <= 1; gly++) {
      for (let glx = -5; glx <= 5; glx++) {
        const dist = Math.sqrt(glx*glx + gly*gly);
        if (dist < 6 && dist > 2)
          cv.sp(cx+glx, cy-20+gly, ...c.FORGE, Math.max(0, (6-dist)*9)|0);
      }
    }
  }

  // ── 15: WOODPILE (SPA-602) — stacked log pile, WOOD_M/WOOD_D ──────────────
  {
    const ox=960, cx=ox+32, cy=25;
    // bottom log (longest, widest face visible)
    cv.fillPoly([
      [cx-12, cy-2], [cx, cy-5], [cx+12, cy-2],
      [cx+12, cy+1], [cx,   cy+4], [cx-12, cy+1],
    ], ...c.WOOD_M);
    // end-grain left (visible cut end, darker ring)
    cv.fillPoly([[cx-14, cy-1],[cx-12,cy-2],[cx-12,cy+1],[cx-14,cy+2]], ...c.WOOD_D);
    cv.sp(cx-13, cy, ...c.DIRT_D, 120);  // heartwood dot
    // bark lines on top face
    cv.line(cx-8, cy-4, cx+8, cy-4, ...c.WOOD_D, 80);
    cv.line(cx-5, cy-3, cx+5, cy-3, ...c.WOOD_D, 50);
    // middle log (slightly narrower, offset to show stacking)
    cv.fillPoly([
      [cx-10, cy-6], [cx+1, cy-9], [cx+11, cy-6],
      [cx+11, cy-4], [cx+1,  cy-7], [cx-10, cy-4],
    ], ...c.WOOD_M);
    cv.fillPoly([[cx-12,cy-5],[cx-10,cy-6],[cx-10,cy-4],[cx-12,cy-3]], ...c.WOOD_D);
    cv.sp(cx-11, cy-4, ...c.DIRT_D, 100);
    cv.line(cx-6, cy-8, cx+6, cy-8, ...c.WOOD_D, 70);
    // top log (shortest, topmost)
    cv.fillPoly([
      [cx-8, cy-10], [cx+2, cy-13], [cx+9, cy-10],
      [cx+9, cy-8],  [cx+2, cy-11], [cx-8, cy-8],
    ], ...c.WOOD_M);
    cv.fillPoly([[cx-10,cy-9],[cx-8,cy-10],[cx-8,cy-8],[cx-10,cy-7]], ...c.WOOD_D);
    cv.sp(cx-9, cy-8, ...c.DIRT_D, 90);
    // outline all logs (OUTLINE)
    cv.line(cx-12, cy-2, cx, cy-5, ...c.OUTLINE, 160);
    cv.line(cx, cy-5, cx+12, cy-2, ...c.OUTLINE, 160);
    cv.line(cx-10, cy-6, cx+1, cy-9, ...c.OUTLINE, 140);
    cv.line(cx+1, cy-9, cx+11, cy-6, ...c.OUTLINE, 140);
    cv.line(cx-8, cy-10, cx+2, cy-13, ...c.OUTLINE, 120);
    cv.line(cx+2, cy-13, cx+9, cy-10, ...c.OUTLINE, 120);
  }

  // ── 16: NOTICE_BOARD (SPA-602) — tall post + parchment board ────────────
  {
    const ox=1024, cx=ox+32, cy=26;
    // post: WOOD_D vertical pole, sunk into ground
    cv.line(cx, cy, cx, cy-22, ...c.WOOD_D);
    cv.sp(cx-1, cy-15, ...c.WOOD_M, 120);  // post highlight
    // horizontal crossbar near top
    cv.line(cx-5, cy-19, cx+5, cy-19, ...c.WOOD_D);
    cv.line(cx-4, cy-18, cx+4, cy-18, ...c.WOOD_M, 80);
    // parchment board hung from crossbar
    cv.fillRect(cx-7, cy-17, 15, 11, ...c.PARCH_L);
    cv.line(cx-7, cy-17, cx+7, cy-17, ...c.PARCH_D);
    cv.line(cx-7, cy-6,  cx+7, cy-6,  ...c.PARCH_D);
    cv.line(cx-7, cy-17, cx-7, cy-6,  ...c.PARCH_D);
    cv.line(cx+7, cy-17, cx+7, cy-6,  ...c.PARCH_D);
    // ink text lines on parchment (3 lines of "text")
    cv.line(cx-5, cy-14, cx+5, cy-14, ...c.INK, 160);
    cv.line(cx-5, cy-11, cx+3, cy-11, ...c.INK, 120);
    cv.line(cx-5, cy-9,  cx+4, cy-9,  ...c.INK, 100);
    // hanging cords from crossbar to board corners
    cv.line(cx-6, cy-19, cx-6, cy-17, ...c.WOOD_D, 140);
    cv.line(cx+6, cy-19, cx+6, cy-17, ...c.WOOD_D, 140);
    // post base stub (ground contact)
    cv.sp(cx-1, cy, ...c.WOOD_D, 180);
    cv.sp(cx+1, cy, ...c.WOOD_D, 180);
    // outline board
    cv.line(cx-8, cy-18, cx+8, cy-18, ...c.OUTLINE, 120);
    cv.line(cx-8, cy-5,  cx+8, cy-5,  ...c.OUTLINE, 120);
  }

  // ── 17: IRON_TORCH (SPA-602) — iron bracket torch, FORGE flame ───────────
  {
    const ox=1088, cx=ox+32, cy=26;
    // small stone base block (bracket mount)
    cv.fillRect(cx-4, cy-8, 8, 4, ...c.STONE_M);
    cv.line(cx-4, cy-8, cx+3, cy-8, ...c.OUTLINE, 180);
    cv.line(cx-4, cy-8, cx-4, cy-4, ...c.STONE_D, 140);
    cv.sp(cx-3, cy-6, ...c.STONE_L, 60);  // stone highlight
    // iron bracket arm (diagonal up-left)
    cv.line(cx-3, cy-8, cx-6, cy-14, ...c.STONE_D);
    cv.sp(cx-4, cy-12, ...c.STONE_D, 200);
    // torch cup at bracket tip (small rect)
    cv.fillRect(cx-8, cy-16, 5, 4, ...c.STONE_D);
    cv.line(cx-9, cy-16, cx-3, cy-16, ...c.OUTLINE, 160);
    cv.sp(cx-6, cy-15, ...c.STONE_M, 100);  // cup highlight
    // wick
    cv.sp(cx-6, cy-17, ...c.INK, 200);
    // flame — FORGE core, CANVAS tip
    cv.sp(cx-6, cy-22, ...c.CANVAS, 200);  // tip
    cv.sp(cx-6, cy-21, ...c.FORGE,  240);
    cv.sp(cx-7, cy-20, ...c.FORGE,  220);
    cv.sp(cx-5, cy-20, ...c.FORGE,  220);
    cv.sp(cx-6, cy-20, ...c.FORGE,  255);
    cv.sp(cx-7, cy-19, ...c.FORGE,  180);
    cv.sp(cx-5, cy-19, ...c.FORGE,  180);
    cv.sp(cx-6, cy-19, ...c.FORGE,  220);
    cv.sp(cx-6, cy-18, ...c.CANVAS, 150);
    // warm glow bloom around flame
    for (let gly = -7; gly <= 1; gly++) {
      for (let glx = -5; glx <= 5; glx++) {
        const dist = Math.sqrt(glx*glx + gly*gly);
        if (dist < 6 && dist > 1.5)
          cv.sp(cx-6+glx, cy-20+gly, ...c.FORGE, Math.max(0, (6-dist)*8)|0);
      }
    }
  }

  // ── ground shadow ellipses under all props ────────────────────────────────
  // Small darkened oval at base gives each prop visual weight on the ground.
  const propShadowCX = [32, 96, 160, 224, 288, 352, 416, 480, 544, 608, 672, 736, 800, 864, 928, 992, 1056, 1120];
  const propShadowCY = [26, 26,  28,  27,  25,  25,  28,  27,  27,  27,  26,  25,  27,  25,  27,   26,   28,   26];
  const propShadowHW = [13, 10,   4,  20,  16,  15,   7,   6,  16,   4,  15,  17,  14,  10,   5,   14,    5,    6];
  for (let _p = 0; _p < 18; _p++) {
    const _cx = propShadowCX[_p], _cy = propShadowCY[_p], _hw = propShadowHW[_p];
    for (let _sx = -_hw; _sx <= _hw; _sx++) {
      const _alpha = Math.max(0, 30 - Math.abs(_sx)*2);
      cv.sp(_cx+_sx, _cy, ...c.OUTLINE, _alpha);
      cv.sp(_cx+_sx, _cy+1, ...c.OUTLINE, _alpha >> 1);
    }
  }

  return cv.toPNG();
}

// ─── Write helper ─────────────────────────────────────────────────────────────
function write(relPath, buf) {
  const full = path.join(__dirname, '..', relPath);
  fs.mkdirSync(path.dirname(full), { recursive: true });
  fs.writeFileSync(full, buf);
  console.log(`  ✓  ${relPath}  (${buf.length} bytes)`);
}

// ─── Main ─────────────────────────────────────────────────────────────────────
console.log('\nRumor Mill — Art Pass 14 (SPA-602): night tile glow enhancement, 3 new props (woodpile, notice_board, iron_torch), interior polish\n');

write('assets/textures/tiles_ground.png',           makeGroundTiles());
write('assets/textures/tiles_road_dirt.png',        makeRoadDirt());
write('assets/textures/tiles_road_stone.png',       makeRoadStone());
write('assets/textures/tiles_buildings.png',        makeBuildingTiles());
write('assets/textures/tiles_buildings_night.png',  makeBuildingTiles(true));
write('assets/textures/tiles_props.png',            makePropsAtlas());
write('assets/textures/npc_sprites.png',            makeNPCSprites());
write('assets/textures/ui_parchment.png',           makeParchment());
write('assets/textures/ui_faction_badges.png',      makeFactionBadges());
write('assets/textures/ui_claim_icons.png',         makeClaimIcons());
write('assets/textures/ui_npc_portraits.png',       makeNPCPortraits());
write('assets/textures/ui_state_icons.png',         makeStateIcons());

console.log('\nAll assets generated.\n');
