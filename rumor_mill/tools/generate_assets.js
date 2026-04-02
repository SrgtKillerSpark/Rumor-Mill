#!/usr/bin/env node
/**
 * generate_assets.js — Art Pass 2 pixel-art generator for Rumor Mill (SPA-79)
 *
 * Produces all textures needed:
 *   assets/textures/tiles_ground.png      (192×32 — 3 ground variants)
 *   assets/textures/tiles_road_dirt.png   (64×32)
 *   assets/textures/tiles_road_stone.png  (64×32)
 *   assets/textures/tiles_buildings.png   (640×64 — 10 building types)
 *   assets/textures/npc_sprites.png       (224×240 — 7 frames × 5 archetypes)
 *                                           row 0 = merchant, 1 = noble, 2 = clergy
 *                                           row 3 = guard,    4 = commoner
 *   assets/textures/ui_parchment.png      (48×48 — 9-slice parchment border tile)
 *   assets/textures/ui_faction_badges.png (72×24 — 3 × 24px faction badges)
 *   assets/textures/ui_claim_icons.png    (80×16 — 5 × 16px claim-type icons)
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
    // arched window on left face
    cv.fillRect(col*64+8, 32-wH+4, 6, 8, 80, 100, 140);
    cv.line(col*64+8, 32-wH+4, col*64+13, 32-wH+4, ...c.OUTLINE);
    // flag on right face
    cv.line(col*64+56, 32-wH-12, col*64+56, 32-wH, ...c.WOOD_M);
    cv.fillRect(col*64+50, 32-wH-12, 8, 5, ...c.FLAG_R);
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
    outlineWalls(col, wH);
    // timber beams on left face
    const ox=col*64;
    cv.line(ox+1,  32-wH, ox+1,  32,   ...c.WOOD_D);
    cv.line(ox+10, 32-wH, ox+10, 32,   ...c.WOOD_D);
    cv.line(ox+1,  32-wH+6, ox+10, 32-wH+6, ...c.WOOD_D);
    // door
    cv.fillRect(ox+4, 32-7, 5, 7, ...c.WOOD_D);
    // lantern glow
    cv.sp(ox+14, 32-wH+2, ...c.FORGE, 200);
    cv.sp(ox+13, 32-wH+2, ...c.FORGE, 100);
    cv.sp(ox+15, 32-wH+2, ...c.FORGE, 100);
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
    // gothic window
    cv.fillRect(ox+6, 32-wH+4, 5, 9, 80, 108, 160);
    cv.sp(ox+8, 32-wH+4, 80, 108, 160);
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
// NPC SPRITES (npc_sprites.png — 224×144)
// Layout: 7 frames wide (32px each) × 3 faction rows (48px each)
//   row 0 = merchant (deep blue/gold)
//   row 1 = noble    (burgundy/silver)
//   row 2 = clergy   (cream/black)
// Columns: 0-2 idle frames, 3-6 walk frames
// ═══════════════════════════════════════════════════════════════════════════════
function makeNPCSprites() {
  // 5 archetype rows × 48px = 240px height
  // row 0=merchant, 1=noble, 2=clergy, 3=guard, 4=commoner
  const cv = createCanvas(224, 240);

  const FACTIONS = [
    { body: c.MERCH_B,  trim: c.MERCH_T,  hat: c.MERCH_B,  hatrim: c.MERCH_T  },
    { body: c.NOBLE_B,  trim: c.NOBLE_T,  hat: c.NOBLE_B,  hatrim: c.NOBLE_T  },
    { body: c.CLERGY_B, trim: c.CLERGY_T, hat: c.CLERGY_B, hatrim: c.CLERGY_T },
  ];

  // Draw one NPC frame at pixel offset (ox, oy), 32×48 canvas region.
  // dy = vertical body-bob offset, lx/rx = left/right foot offsets
  const drawNPC = (ox, oy, fac, dy=0, lx=0, rx=0) => {
    const { body, trim, hat, hatrim } = fac;

    // ── head (8×8, centred at x=16) ──
    const hx = ox+12, hy = oy+2+dy;
    cv.fillRect(hx, hy, 8, 8, ...c.SKIN);
    // eyes
    cv.sp(hx+2, hy+3, ...c.HAIR);
    cv.sp(hx+5, hy+3, ...c.HAIR);
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

    // ── arms ─────────────────────────────────────────────────────────────────
    cv.fillRect(bx-2, by+1, 3, 10, ...body);
    cv.fillRect(bx+9, by+1, 3, 10, ...body);
    // hands
    cv.fillRect(bx-2, by+9, 3, 3, ...c.SKIN);
    cv.fillRect(bx+9, by+9, 3, 3, ...c.SKIN);

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
  };

  for (let fi=0; fi<3; fi++) {
    const oy = fi*48;
    const fac = FACTIONS[fi];

    // idle frame 0 — neutral
    drawNPC(0*32, oy, fac, 0, 0, 0);
    // idle frame 1 — slight bob up
    drawNPC(1*32, oy, fac, -1, 0, 0);
    // idle frame 2 — back to neutral (slight head tilt by shifting eye)
    drawNPC(2*32, oy, fac, 0, 0, 0);

    // walk frame 0 — stride right
    drawNPC(3*32, oy, fac, 0, -2, 2);
    // walk frame 1 — mid-step (bob up)
    drawNPC(4*32, oy, fac, -1, 0, 0);
    // walk frame 2 — stride left
    drawNPC(5*32, oy, fac, 0, 2, -2);
    // walk frame 3 — mid-step (bob up, other phase)
    drawNPC(6*32, oy, fac, -1, 0, 0);
  }

  // ── Row 3: GUARD archetype ─────────────────────────────────────────────────
  // Stone tabard, round nasal helmet, armored arms — clearly military silhouette.
  const drawGuard = (ox, oy, dy=0, lx=0, rx=0) => {
    // head
    const hx = ox+12, hy = oy+2+dy;
    cv.fillRect(hx, hy, 8, 8, ...c.SKIN);
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
  };

  {
    const oy3 = 3*48;
    drawGuard(0*32, oy3, 0,  0,  0);
    drawGuard(1*32, oy3, -1, 0,  0);
    drawGuard(2*32, oy3, 0,  0,  0);
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
    cv.sp(hx+2, hy+3, ...c.HAIR);
    cv.sp(hx+5, hy+3, ...c.HAIR);
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

// ─── Write helper ─────────────────────────────────────────────────────────────
function write(relPath, buf) {
  const full = path.join(__dirname, '..', relPath);
  fs.mkdirSync(path.dirname(full), { recursive: true });
  fs.writeFileSync(full, buf);
  console.log(`  ✓  ${relPath}  (${buf.length} bytes)`);
}

// ─── Main ─────────────────────────────────────────────────────────────────────
console.log('\nRumor Mill — Art Pass 2 asset generation (SPA-79)\n');

write('assets/textures/tiles_ground.png',       makeGroundTiles());
write('assets/textures/tiles_road_dirt.png',    makeRoadDirt());
write('assets/textures/tiles_road_stone.png',   makeRoadStone());
write('assets/textures/tiles_buildings.png',    makeBuildingTiles());
write('assets/textures/npc_sprites.png',        makeNPCSprites());
write('assets/textures/ui_parchment.png',       makeParchment());
write('assets/textures/ui_faction_badges.png',  makeFactionBadges());
write('assets/textures/ui_claim_icons.png',     makeClaimIcons());

console.log('\nAll assets generated.\n');
