#!/usr/bin/env node
/**
 * generate_assets.js — Art Pass 4 pixel-art generator for Rumor Mill (SPA-410)
 *
 * Produces all textures needed:
 *   assets/textures/tiles_ground.png      (192×32 — 3 ground variants)
 *   assets/textures/tiles_road_dirt.png   (64×32)
 *   assets/textures/tiles_road_stone.png  (64×32)
 *   assets/textures/tiles_buildings.png   (640×64 — 10 building types)
 *   assets/textures/npc_sprites.png       (224×288 — 7 frames × 6 archetypes)
 *                                           row 0 = merchant, 1 = noble, 2 = clergy
 *                                           row 3 = guard,    4 = commoner
 *                                           row 5 = tavern_staff (apron/kerchief)
 *   assets/textures/ui_parchment.png      (48×48 — 9-slice parchment border tile)
 *   assets/textures/ui_faction_badges.png (72×24 — 3 × 24px faction badges)
 *   assets/textures/ui_claim_icons.png    (80×16 — 5 × 16px claim-type icons)
 *   assets/textures/ui_npc_portraits.png  (120×96 — 5 cols × 3 rows of 24×32 portraits)
 *                                           col 0=merchant, 1=noble, 2=clergy, 3=guard, 4=commoner
 *                                           row 0=male base, 1=female base, 2=elder/leader
 *   assets/textures/ui_state_icons.png    (72×12 — 6 × 12px rumor-state icons)
 *                                           col 0=EVALUATING, 1=BELIEVE, 2=SPREAD,
 *                                               3=ACT, 4=CONTRADICTED, 5=EXPIRED
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

  return { data, sp, fillRect, fillPoly, line, isoNoise, toPNG: ()=>makePNG(w,h,data) };
}

// ─── Palette ──────────────────────────────────────────────────────────────────
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
// GROUND TILES  (tiles_ground.png — 192×32, three 64×32 isometric tiles)
//   col 0 = void, col 1 = grass, col 2 = dark grass
// ═══════════════════════════════════════════════════════════════════════════════
function makeGroundTiles() {
  const cv = createCanvas(192, 32);

  // ── tile 0: void — very dark, just a subtle diamond outline ──────────────
  // (left transparent so Godot shows nothing)

  // ── tile 1: grass ──────────────────────────────────────────────────────────
  {
    const ox = 64, cx = ox+32, cy = 16;
    fillIso(cv, ...c.GRASS_M, 255, cx, cy);
    cv.isoNoise(cx, cy, 31, 15, ...c.GRASS_L, 10, 0.20);
    cv.isoNoise(cx, cy, 31, 15, ...c.GRASS_D, 8,  0.12);
    // subtle crosshatch-pattern (Pentiment look)
    for (let y=2; y<30; y+=4) {
      for (let x=ox+2; x<ox+62; x+=4) {
        if (Math.abs(x-cx)/31 + Math.abs(y-cy)/15 < 0.90) {
          cv.sp(x, y, ...c.GRASS_D, 80);
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
  // wheel-rut lines
  cv.line(20, 10, 44, 22, ...c.DIRT_D, 160);
  cv.line(22, 12, 46, 24, ...c.DIRT_D, 100);
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
  cv.isoNoise(32, 16, 31, 15, ...c.STONE_L, 8, 0.08);
  outlineIso(cv, ...c.STONE_D, 32, 16);
  return cv.toPNG();
}

// ═══════════════════════════════════════════════════════════════════════════════
// BUILDING TILES (tiles_buildings.png — 640×64, ten 64×64 tiles)
//
// Each tile: bottom half (y32-63) = iso ground face; top (y0-31) = building.
// Tile indices match ATLAS_* constants in world.gd:
//   0=manor  1=tavern  2=chapel  3=market  4=well
//   5=blacksmith  6=mill  7=storage  8=guardpost  9=town_hall
// ═══════════════════════════════════════════════════════════════════════════════
function makeBuildingTiles() {
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
  // 0: MANOR — limestone walls, slate roof, tall (wallH=22)
  // ────────────────────────────────────────────────────────────────────────────
  {
    const col=0, wH=22;
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
    // flag on right face
    cv.line(ox0+56, 32-wH-12, ox0+56, 32-wH, ...c.WOOD_M);
    cv.fillRect(ox0+48, 32-wH-12, 9, 6, ...c.FLAG_R);
    cv.line(ox0+48, 32-wH-12, ox0+56, 32-wH-12, ...c.OUTLINE);
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
    // right face: second narrow window
    cv.fillRect(ox+44, 32-wH+3, 4, 8, 80, 108, 160);
    cv.sp(ox+45, 32-wH+5, ...c.MERCH_T, 180);
    cv.sp(ox+46, 32-wH+7, ...c.FLAG_R, 140);
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
    // goods on counter
    cv.fillRect(ox+10, 32-4, 8, 3, ...c.DIRT_L);
    cv.fillRect(ox+22, 32-4, 6, 3, ...c.ROOF_TILE);
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
    // forge glow opening
    cv.fillRect(ox+4, 32-wH+6, 8, 8, 60, 36, 20);
    cv.fillRect(ox+5, 32-wH+7, 6, 6, ...c.FORGE);
    cv.fillRect(ox+6, 32-wH+8, 4, 3, 255, 200, 80);
    // glow halo
    for (let dy=-2; dy<=2; dy++) for (let dx=-2; dx<=2; dx++)
      if (dx*dx+dy*dy<=5)
        cv.sp(ox+8+dx, 32-wH+10+dy, ...c.FORGE, 60);
    // anvil silhouette on right face
    cv.fillRect(ox+44, 32-6, 12, 4, ...c.STONE_D);
    cv.fillRect(ox+46, 32-10, 8, 4, ...c.STONE_D);
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

  return cv.toPNG();
}

// ═══════════════════════════════════════════════════════════════════════════════
// NPC SPRITES (npc_sprites.png — 224×288)
// Layout: 7 frames wide (32px each) × 6 archetype rows (48px each)
//   row 0 = merchant    (deep blue/gold)
//   row 1 = noble       (burgundy/silver)
//   row 2 = clergy      (cream/black)
//   row 3 = guard       (stone tabard/helmet)
//   row 4 = commoner    (drab linen)
//   row 5 = tavern_staff (apron/kerchief, warm amber)
// Columns: 0-2 idle frames, 3-6 walk frames
// ═══════════════════════════════════════════════════════════════════════════════
function makeNPCSprites() {
  // 6 archetype rows × 48px = 288px height
  // row 0=merchant, 1=noble, 2=clergy, 3=guard, 4=commoner, 5=tavern_staff
  const cv = createCanvas(224, 288);

  const FACTIONS = [
    { body: c.MERCH_B,  trim: c.MERCH_T,  hat: c.MERCH_B,  hatrim: c.MERCH_T  },
    { body: c.NOBLE_B,  trim: c.NOBLE_T,  hat: c.NOBLE_B,  hatrim: c.NOBLE_T  },
    { body: c.CLERGY_B, trim: c.CLERGY_T, hat: c.CLERGY_B, hatrim: c.CLERGY_T },
  ];

  // Draw one NPC frame at pixel offset (ox, oy), 32×48 canvas region.
  // dy  = vertical body-bob offset
  // lx/rx = left/right foot X offsets (walk stride)
  // laY/raY = left/right arm Y offsets (arm swing: negative = raised/forward)
  const drawNPC = (ox, oy, fac, dy=0, lx=0, rx=0, laY=0, raY=0) => {
    const { body, trim, hat, hatrim } = fac;

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

    // ── hat ──────────────────────────────────────────────────────────────────
    // brim
    cv.fillRect(hx-1, hy-1, 10, 3, ...hat);
    cv.line(hx-1, hy-1, hx+8, hy-1, ...c.OUTLINE);
    // crown
    cv.fillRect(hx+1, hy-4, 6, 4, ...hat);
    cv.fillRect(hx+2, hy-5, 4, 2, ...hatrim);
    cv.line(hx+1, hy-4, hx+6, hy-4, ...c.OUTLINE);

    // ── body / torso (10×14) ─────────────────────────────────────────────────
    const bx = ox+11, by = oy+10+dy;
    cv.fillRect(bx, by, 10, 14, ...body);
    // belt / trim stripe
    cv.fillRect(bx, by+6, 10, 2, ...trim);
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

    // ── legs (each 4×10) ─────────────────────────────────────────────────────
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

  for (let fi=0; fi<3; fi++) {
    const oy = fi*48;
    const fac = FACTIONS[fi];

    // idle frame 0 — neutral
    drawNPC(0*32, oy, fac, 0, 0, 0);
    // idle frame 1 — slight bob up, arms relaxed at sides
    drawNPC(1*32, oy, fac, -1, 0, 0, 1, 1);
    // idle frame 2 — slight look-away (same pose, slightly different arm rest)
    drawNPC(2*32, oy, fac, 0, 0, 0, 0, 1);

    // walk frame 0 — right foot fwd, left arm swings forward
    drawNPC(3*32, oy, fac, 0, -2, 2, -2, 2);
    // walk frame 1 — mid-step, arms centred (bob up)
    drawNPC(4*32, oy, fac, -1, 0, 0, 0, 0);
    // walk frame 2 — left foot fwd, right arm swings forward
    drawNPC(5*32, oy, fac, 0, 2, -2, 2, -2);
    // walk frame 3 — mid-step other phase (bob up)
    drawNPC(6*32, oy, fac, -1, 0, 0, 0, 0);
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

  {
    const oy3 = 3*48;
    drawGuard(0*32, oy3, 0,  0,  0);
    drawGuard(1*32, oy3, -1, 0,  0);
    drawGuard(2*32, oy3, 0,  0,  0);
    // walk frames with stride
    drawGuard(3*32, oy3, 0,  -2, 2);
    drawGuard(4*32, oy3, -1, 0,  0);
    drawGuard(5*32, oy3, 0,  2,  -2);
    drawGuard(6*32, oy3, -1, 0,  0);
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
  };

  {
    const oy4 = 4*48;
    drawCommoner(0*32, oy4, 0,  0,  0);
    drawCommoner(1*32, oy4, -1, 0,  0);
    drawCommoner(2*32, oy4, 0,  0,  0);
    drawCommoner(3*32, oy4, 0,  -2, 2);
    drawCommoner(4*32, oy4, -1, 0,  0);
    drawCommoner(5*32, oy4, 0,  2,  -2);
    drawCommoner(6*32, oy4, -1, 0,  0);
  }

  // ── Row 5: TAVERN STAFF archetype ─────────────────────────────────────────
  // Cream apron over rustic brown tunic, parchment head-kerchief, sleeves
  // rolled up — clearly working hospitality, distinct from commoner/merchant.
  const drawTavernStaff = (ox, oy, dy=0, lx=0, rx=0) => {
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

    // arms: rolled-up sleeves (brown upper, bare skin forearm)
    cv.fillRect(bx-2, by+1, 3, 7, ...c.WOOD_L);
    cv.fillRect(bx+9, by+1, 3, 7, ...c.WOOD_L);
    cv.fillRect(bx-2, by+8, 3, 4, ...c.SKIN);   // bare forearm L
    cv.fillRect(bx+9, by+8, 3, 4, ...c.SKIN);   // bare forearm R
    // rolled cuff marks
    cv.line(bx-2, by+8, bx, by+8, ...c.WOOD_M);
    cv.line(bx+9, by+8, bx+11, by+8, ...c.WOOD_M);

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
  };

  {
    const oy5 = 5*48;
    drawTavernStaff(0*32, oy5, 0,  0,  0);
    drawTavernStaff(1*32, oy5, -1, 0,  0);
    drawTavernStaff(2*32, oy5, 0,  0,  0);
    drawTavernStaff(3*32, oy5, 0,  -2, 2);
    drawTavernStaff(4*32, oy5, -1, 0,  0);
    drawTavernStaff(5*32, oy5, 0,  2,  -2);
    drawTavernStaff(6*32, oy5, -1, 0,  0);
  }

  return cv.toPNG();
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

  // corner decorations (ink scrollwork)
  const scroll = (sx, sy, fx, fy) => {
    cv.line(sx, sy, sx+fx*3, sy+fy*3, ...c.INK, 180);
    cv.line(sx+fx*1, sy, sx+fx*1, sy+fy*2, ...c.INK, 120);
    cv.line(sx, sy+fy*1, sx+fx*2, sy+fy*1, ...c.INK, 120);
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
// CLAIM TYPE ICONS (ui_claim_icons.png — 80×16, five 16×16 icons)
//   0=assassination  1=theft  2=slander  3=witness  4=alliance
// ═══════════════════════════════════════════════════════════════════════════════
function makeClaimIcons() {
  const cv = createCanvas(80, 16);

  // 0: assassination — dagger
  {
    const ox=0;
    cv.fillRect(ox+7, 1, 3, 9, ...c.STONE_L);
    cv.fillPoly([[ox+7,10],[ox+10,10],[ox+8,14]], ...c.STONE_D);
    cv.fillRect(ox+5, 5, 7, 2, ...c.WOOD_M);
    cv.line(ox+8, 1, ox+8, 13, ...c.OUTLINE);
  }
  // 1: theft — bag with coin
  {
    const ox=16;
    cv.fillPoly([[ox+5,5],[ox+11,5],[ox+13,10],[ox+3,10]], ...c.WOOD_L);
    cv.fillRect(ox+5,10, 6,4, ...c.WOOD_L);
    cv.line(ox+5,5, ox+11,5, ...c.OUTLINE);
    cv.line(ox+3,10, ox+13,10, ...c.OUTLINE);
    cv.line(ox+5,14, ox+11,14, ...c.OUTLINE);
    cv.sp(ox+7, 3, ...c.MERCH_T);  // string
    cv.sp(ox+8, 3, ...c.MERCH_T);
  }
  // 2: slander — speech bubble
  {
    const ox=32;
    cv.fillRect(ox+2, 2, 12, 8, ...c.PARCH_L);
    cv.fillPoly([[ox+4,10],[ox+8,10],[ox+5,14]], ...c.PARCH_L);
    cv.line(ox+2,2, ox+13,2, ...c.OUTLINE);
    cv.line(ox+2,2, ox+2,9,  ...c.OUTLINE);
    cv.line(ox+2,9, ox+13,9, ...c.OUTLINE);
    cv.line(ox+13,2,ox+13,9, ...c.OUTLINE);
    // text lines
    cv.line(ox+4,5, ox+11,5, ...c.INK, 160);
    cv.line(ox+4,7, ox+9, 7, ...c.INK, 120);
  }
  // 3: witness — eye
  {
    const ox=48;
    cv.fillPoly([[ox+2,8],[ox+8,4],[ox+14,8],[ox+8,12]], ...c.PARCH_L);
    cv.fillRect(ox+6,6, 5,5, ...c.MERCH_B);
    cv.sp(ox+7,7,  ...c.WATER_L);
    cv.sp(ox+8,8,  40,60,100);
    cv.line(ox+2,8, ox+8,4,  ...c.OUTLINE);
    cv.line(ox+8,4, ox+14,8, ...c.OUTLINE);
    cv.line(ox+14,8,ox+8,12, ...c.OUTLINE);
    cv.line(ox+8,12,ox+2,8,  ...c.OUTLINE);
  }
  // 4: alliance — clasped hands
  {
    const ox=64;
    cv.fillRect(ox+2, 4, 5, 8, ...c.SKIN);
    cv.fillRect(ox+9, 4, 5, 8, ...c.SKIN);
    cv.fillRect(ox+5, 6, 6, 4, ...c.SKIN);
    cv.line(ox+2,4,  ox+6,4,  ...c.OUTLINE);
    cv.line(ox+9,4,  ox+13,4, ...c.OUTLINE);
    cv.line(ox+2,12, ox+13,12,...c.OUTLINE);
    cv.line(ox+2,4,  ox+2,12, ...c.OUTLINE);
    cv.line(ox+13,4, ox+13,12,...c.OUTLINE);
  }

  return cv.toPNG();
}

// ═══════════════════════════════════════════════════════════════════════════════
// NPC PORTRAIT ATLAS  (ui_npc_portraits.png — 120×96, five 24×32 cols × 3 rows)
//   Row 0 (y=  0): male archetypes    — merchant, noble, clergy, guard, commoner
//   Row 1 (y= 32): female archetypes  — same faction/role order
//   Row 2 (y= 64): elder/leader variants — cloak trim, rank accessory
//
// Portrait spec (24×32 px per cell):
//   y  0‒ 3  hat / headwear
//   y  4‒11  head (8×8, x 8‒15)
//   y 12‒14  neck
//   y 15‒29  upper torso / collar  (16 px wide, x 4‒19)
//   y 30‒31  bottom border
//
// Hat styles:  'wide'(merchant) | 'coronet'(noble) | 'hood'(clergy)
//              | 'helm'(guard) | 'cap'(commoner)
// Elder row adds: cloak-trim stripe + rank brooch
// Female row adds: flowing side-hair below head edges
// ═══════════════════════════════════════════════════════════════════════════════
function makeNPCPortraits() {
  const cv = createCanvas(120, 96);

  const drawPortrait = (ox, oy, opts) => {
    const { body, trim, hatStyle, hat, hatTrim, female = false, elder = false } = opts;

    // ── parchment background + ink border ────────────────────────────────────
    cv.fillRect(ox, oy, 24, 32, ...c.PARCH_L);
    cv.line(ox,    oy,    ox+23, oy,    ...c.INK);
    cv.line(ox,    oy,    ox,    oy+31, ...c.INK);
    cv.line(ox+23, oy,    ox+23, oy+31, ...c.INK);
    cv.line(ox,    oy+31, ox+23, oy+31, ...c.INK);

    // ── head (8×8 at x=ox+8, y=oy+4) ────────────────────────────────────────
    const hx = ox+8, hy = oy+4;
    cv.fillRect(hx, hy, 8, 8, ...c.SKIN);
    // eyes
    cv.sp(hx+2, hy+3, ...c.HAIR);
    cv.sp(hx+5, hy+3, ...c.HAIR);
    // mouth — slight curve for female, flat line for male
    if (female) {
      cv.sp(hx+2, hy+6, ...c.HAIR, 100);
      cv.sp(hx+3, hy+7, ...c.HAIR);
      cv.sp(hx+4, hy+7, ...c.HAIR);
      cv.sp(hx+5, hy+6, ...c.HAIR, 100);
    } else {
      cv.sp(hx+2, hy+6, ...c.HAIR, 80);
      cv.sp(hx+5, hy+6, ...c.HAIR, 80);
    }
    // female: side-hair drapes 3px below head on each edge
    if (female) {
      cv.fillRect(hx-1, hy+2, 2, 9, ...c.HAIR);
      cv.fillRect(hx+7, hy+2, 2, 9, ...c.HAIR);
    }
    // head outline
    cv.line(hx,   hy,   hx+7, hy,   ...c.OUTLINE);
    cv.line(hx,   hy,   hx,   hy+7, ...c.OUTLINE);
    cv.line(hx+7, hy,   hx+7, hy+7, ...c.OUTLINE);
    cv.line(hx,   hy+7, hx+7, hy+7, ...c.OUTLINE);

    // ── hat / headwear ────────────────────────────────────────────────────────
    if (hatStyle === 'wide') {
      // merchant: wide-brim felt hat
      cv.fillRect(hx-2, hy-1, 12, 2, ...hat);        // wide brim
      cv.fillRect(hx+1, hy-5, 6,  5, ...hat);        // crown
      cv.fillRect(hx+2, hy-6, 4,  2, ...hatTrim);    // trim band
      cv.line(hx-2, hy-1, hx+9,  hy-1, ...c.OUTLINE);
      cv.line(hx+1, hy-5, hx+6,  hy-5, ...c.OUTLINE);
    } else if (hatStyle === 'coronet') {
      // noble: open coronet with 3 points and gem accents
      cv.fillRect(hx, hy-1, 8, 2, ...hat);           // base band
      cv.sp(hx+1, hy-3, ...hat); cv.sp(hx+2, hy-4, ...hat); cv.sp(hx+3, hy-3, ...hat);
      cv.sp(hx+4, hy-3, ...hat); cv.sp(hx+5, hy-4, ...hat); cv.sp(hx+6, hy-3, ...hat);
      cv.sp(hx+7, hy-3, ...hat);
      cv.sp(hx+2, hy-4, ...hatTrim);                 // gem left
      cv.sp(hx+5, hy-4, ...hatTrim);                 // gem right
      cv.line(hx, hy-1, hx+7, hy-1, ...c.OUTLINE);
    } else if (hatStyle === 'hood') {
      // clergy: plain draped hood, darker than robe
      cv.fillRect(hx-1, hy-3, 10, 4, ...hat);        // hood top
      cv.fillRect(hx-1, hy,    2, 6, ...hat);        // left drape
      cv.fillRect(hx+7, hy,    2, 6, ...hat);        // right drape
      cv.line(hx-1, hy-3, hx+8, hy-3, ...c.OUTLINE);
      cv.line(hx-1, hy-3, hx-1, hy+5, ...c.OUTLINE);
      cv.line(hx+8, hy-3, hx+8, hy+5, ...c.OUTLINE);
    } else if (hatStyle === 'helm') {
      // guard: nasal helmet
      cv.fillRect(hx-1, hy-3, 10, 5, ...c.STONE_M);
      cv.fillRect(hx-2, hy,   12, 2, ...c.STONE_D);  // brim
      cv.line(hx+4, hy-3, hx+4, hy+4, ...c.STONE_D); // nasal guard
      cv.line(hx-2, hy,    hx+9,  hy,    ...c.OUTLINE);
      cv.line(hx-1, hy-3,  hx+8,  hy-3,  ...c.OUTLINE);
      cv.line(hx-1, hy-3,  hx-2,  hy,    ...c.OUTLINE);
      cv.line(hx+8, hy-3,  hx+9,  hy,    ...c.OUTLINE);
    } else if (hatStyle === 'cap') {
      // commoner: soft cloth cap
      cv.fillRect(hx,   hy-1, 8, 2, ...c.THATCH_D);
      cv.fillRect(hx+1, hy-4, 6, 4, ...c.THATCH_D);
      cv.fillRect(hx+2, hy-5, 4, 2, ...c.DIRT_D);
      cv.line(hx,   hy-1, hx+7, hy-1, ...c.OUTLINE);
      cv.line(hx+1, hy-4, hx+6, hy-4, ...c.OUTLINE);
    }

    // ── neck ──────────────────────────────────────────────────────────────────
    cv.fillRect(ox+10, hy+8, 4, 4, ...c.SKIN);

    // ── upper torso / collar (16×14 at x=ox+4, y=oy+15) ─────────────────────
    const tx = ox+4, ty = oy+15;
    cv.fillRect(tx, ty, 16, 14, ...body);
    // collar V-notch
    cv.fillPoly([[tx+6, ty], [tx+10, ty], [tx+8, ty+4]], ...c.PARCH_L);
    // trim stripe along collar edge
    cv.line(tx+6, ty, tx+8, ty+4, ...trim);
    cv.line(tx+8, ty+4, tx+10, ty, ...trim);
    // shoulder shading (right side darker)
    cv.fillRect(tx+11, ty+1, 4, 12, ...body, 140);
    // elder: cloak-trim stripe on shoulders + rank brooch
    if (elder) {
      cv.fillRect(tx,    ty,    4, 14, ...c.PARCH_L, 160); // left cloak trim
      cv.fillRect(tx+12, ty,    4, 14, ...c.PARCH_L, 160); // right cloak trim
      // brooch: 3×3 diamond
      cv.sp(ox+11, ty+6, ...trim);
      cv.sp(ox+10, ty+7, ...trim); cv.sp(ox+11, ty+7, ...c.PARCH_L); cv.sp(ox+12, ty+7, ...trim);
      cv.sp(ox+11, ty+8, ...trim);
    }
    // torso outline
    cv.line(tx,    ty,    tx+15, ty,    ...c.OUTLINE);
    cv.line(tx,    ty,    tx,    ty+13, ...c.OUTLINE);
    cv.line(tx+15, ty,    tx+15, ty+13, ...c.OUTLINE);
    cv.line(tx,    ty+13, tx+15, ty+13, ...c.OUTLINE);
  };

  // ── Portrait definitions (col order: merchant, noble, clergy, guard, commoner)
  const ARCHETYPES = [
    { body: c.MERCH_B,   trim: c.MERCH_T,  hatStyle: 'wide',    hat: c.WOOD_M,     hatTrim: c.MERCH_T  },
    { body: c.NOBLE_B,   trim: c.NOBLE_T,  hatStyle: 'coronet', hat: c.NOBLE_T,    hatTrim: c.PARCH_L  },
    { body: c.CLERGY_B,  trim: c.CLERGY_T, hatStyle: 'hood',    hat: c.STONE_M,    hatTrim: c.PARCH_D  },
    { body: c.STONE_M,   trim: c.STONE_L,  hatStyle: 'helm',    hat: c.STONE_M,    hatTrim: c.STONE_L  },
    { body: c.DIRT_M,    trim: c.DIRT_D,   hatStyle: 'cap',     hat: c.THATCH_D,   hatTrim: c.DIRT_D   },
  ];

  // Row 0: male base
  for (let i = 0; i < 5; i++)
    drawPortrait(i*24, 0, { ...ARCHETYPES[i] });

  // Row 1: female base
  for (let i = 0; i < 5; i++)
    drawPortrait(i*24, 32, { ...ARCHETYPES[i], female: true });

  // Row 2: elder / leader variants
  for (let i = 0; i < 5; i++)
    drawPortrait(i*24, 64, { ...ARCHETYPES[i], elder: true });

  return cv.toPNG();
}

// ═══════════════════════════════════════════════════════════════════════════════
// RUMOR STATE ICONS  (ui_state_icons.png — 72×12, six 12×12 icons)
//   col 0  EVALUATING  — hourglass (pondering / undecided)
//   col 1  BELIEVE     — open scroll (accepted rumor)
//   col 2  SPREAD      — speech bubble with ripple (actively spreading)
//   col 3  ACT         — lightning bolt (acting on belief)
//   col 4  CONTRADICTED— crossed arrows (conflicting rumors)
//   col 5  EXPIRED     — broken circle X (rumor died out)
//
// Palette-locked; no colours outside P.  Background transparent.
// Used by: social_graph_overlay, HUD state badges, journal rumor rows.
// ═══════════════════════════════════════════════════════════════════════════════
function makeStateIcons() {
  const cv = createCanvas(72, 12);

  // ── 0: EVALUATING — hourglass ─────────────────────────────────────────────
  {
    const ox = 0;
    // top half (sand reservoir)
    cv.fillPoly([[ox+2,1],[ox+9,1],[ox+7,5],[ox+4,5]], ...c.THATCH_L);
    // bottom half (fallen sand)
    cv.fillPoly([[ox+4,7],[ox+7,7],[ox+9,11],[ox+2,11]], ...c.THATCH_L);
    // sand trickle at middle
    cv.sp(ox+5, 5, ...c.MERCH_T);
    cv.sp(ox+6, 5, ...c.MERCH_T);
    cv.sp(ox+5, 6, ...c.MERCH_T);
    cv.sp(ox+6, 6, ...c.MERCH_T);
    // outline
    cv.line(ox+2, 1, ox+9, 1,  ...c.OUTLINE);
    cv.line(ox+9, 1, ox+7, 5,  ...c.OUTLINE);
    cv.line(ox+7, 5, ox+9, 11, ...c.OUTLINE);
    cv.line(ox+9, 11,ox+2, 11, ...c.OUTLINE);
    cv.line(ox+2, 11,ox+4, 7,  ...c.OUTLINE);
    cv.line(ox+4, 7, ox+4, 5,  ...c.OUTLINE);
    cv.line(ox+4, 5, ox+2, 1,  ...c.OUTLINE);
  }

  // ── 1: BELIEVE — small scroll with text lines ─────────────────────────────
  {
    const ox = 12;
    // scroll body
    cv.fillRect(ox+1, 2, 9, 9, ...c.PARCH_M);
    // rolled ends
    cv.fillRect(ox+1, 1, 9, 2, ...c.PARCH_D);
    cv.fillRect(ox+1, 9, 9, 2, ...c.PARCH_D);
    // text lines
    cv.line(ox+3, 4, ox+8, 4, ...c.INK, 180);
    cv.line(ox+3, 6, ox+8, 6, ...c.INK, 140);
    cv.line(ox+3, 8, ox+6, 8, ...c.INK, 120);
    // check mark (belief confirmed)
    cv.sp(ox+7, 7, ...c.WOOD_D);
    cv.sp(ox+8, 8, ...c.WOOD_D);
    cv.sp(ox+9, 6, ...c.WOOD_D);
    // outline
    cv.line(ox+1, 1, ox+9, 1,  ...c.OUTLINE);
    cv.line(ox+1, 1, ox+1, 10, ...c.OUTLINE);
    cv.line(ox+9, 1, ox+9, 10, ...c.OUTLINE);
    cv.line(ox+1,10, ox+9, 10, ...c.OUTLINE);
  }

  // ── 2: SPREAD — speech bubble with outward ripple ────────────────────────
  {
    const ox = 24;
    // bubble body
    cv.fillRect(ox+1, 1, 8, 6, ...c.PARCH_L);
    // tail
    cv.fillPoly([[ox+2,7],[ox+5,7],[ox+3,10]], ...c.PARCH_L);
    // dot contents (whisper dots)
    cv.sp(ox+3, 3, ...c.CANVAS);
    cv.sp(ox+5, 3, ...c.CANVAS);
    cv.sp(ox+7, 3, ...c.CANVAS);
    // ripple arc right
    cv.sp(ox+10, 2, ...c.FORGE, 180);
    cv.sp(ox+10, 4, ...c.FORGE, 200);
    cv.sp(ox+10, 6, ...c.FORGE, 180);
    // outline
    cv.line(ox+1, 1, ox+8, 1,  ...c.OUTLINE);
    cv.line(ox+1, 1, ox+1, 6,  ...c.OUTLINE);
    cv.line(ox+1, 6, ox+8, 6,  ...c.OUTLINE);
    cv.line(ox+8, 1, ox+8, 6,  ...c.OUTLINE);
    cv.line(ox+2, 7, ox+3,10,  ...c.OUTLINE);
    cv.line(ox+5, 7, ox+3,10,  ...c.OUTLINE);
  }

  // ── 3: ACT — lightning bolt ───────────────────────────────────────────────
  {
    const ox = 36;
    cv.fillPoly([[ox+6,1],[ox+3,6],[ox+6,6],[ox+4,11],[ox+9,5],[ox+6,5],[ox+8,1]], ...c.FLAG_R);
    // bright highlight on leading edge
    cv.line(ox+6, 1, ox+8, 1, ...c.ROOF_TILE, 200);
    cv.line(ox+9, 5, ox+6, 5, ...c.ROOF_TILE, 160);
    // outline
    cv.line(ox+6, 1, ox+8, 1,  ...c.OUTLINE);
    cv.line(ox+8, 1, ox+9, 5,  ...c.OUTLINE);
    cv.line(ox+9, 5, ox+6, 5,  ...c.OUTLINE);
    cv.line(ox+6, 5, ox+4,11,  ...c.OUTLINE);
    cv.line(ox+4,11, ox+3, 6,  ...c.OUTLINE);
    cv.line(ox+3, 6, ox+6, 6,  ...c.OUTLINE);
    cv.line(ox+6, 6, ox+6, 1,  ...c.OUTLINE);
  }

  // ── 4: CONTRADICTED — two arrows clashing ────────────────────────────────
  {
    const ox = 48;
    // left-to-right arrow (belief rumor)
    cv.line(ox+1, 4, ox+5, 4, ...c.MERCH_B);
    cv.fillPoly([[ox+4,2],[ox+7,4],[ox+4,6]], ...c.MERCH_B);
    // right-to-left arrow (contradicting rumor)
    cv.line(ox+10,8, ox+6, 8, ...c.NOBLE_B);
    cv.fillPoly([[ox+7,6],[ox+4,8],[ox+7,10]], ...c.NOBLE_B);
    // clash X at center
    cv.line(ox+4, 4, ox+8, 8,  ...c.OUTLINE);
    cv.line(ox+8, 4, ox+4, 8,  ...c.OUTLINE);
    // arrow outlines
    cv.line(ox+1, 4, ox+4, 4,  ...c.OUTLINE);
    cv.line(ox+10,8, ox+7, 8,  ...c.OUTLINE);
  }

  // ── 5: EXPIRED — circle with X ───────────────────────────────────────────
  {
    const ox = 60;
    // circle (octagonal approx)
    const pts = [[ox+5,1],[ox+8,2],[ox+10,5],[ox+10,7],[ox+8,10],[ox+5,10],[ox+2,8],[ox+1,5],[ox+2,3]];
    cv.fillPoly(pts, ...c.STONE_M, 200);
    // X cross
    cv.line(ox+3, 3, ox+8, 8, ...c.STONE_D);
    cv.line(ox+8, 3, ox+3, 8, ...c.STONE_D);
    // outline circle
    for (let i=0; i<pts.length; i++)
      cv.line(...pts[i], ...pts[(i+1)%pts.length], ...c.OUTLINE);
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
console.log('\nRumor Mill — Art Pass 4 asset generation (SPA-410)\n');

write('assets/textures/tiles_ground.png',       makeGroundTiles());
write('assets/textures/tiles_road_dirt.png',    makeRoadDirt());
write('assets/textures/tiles_road_stone.png',   makeRoadStone());
write('assets/textures/tiles_buildings.png',    makeBuildingTiles());
write('assets/textures/npc_sprites.png',        makeNPCSprites());
write('assets/textures/ui_parchment.png',       makeParchment());
write('assets/textures/ui_faction_badges.png',  makeFactionBadges());
write('assets/textures/ui_claim_icons.png',     makeClaimIcons());
write('assets/textures/ui_npc_portraits.png',   makeNPCPortraits());
write('assets/textures/ui_state_icons.png',     makeStateIcons());

console.log('\nAll assets generated.\n');
