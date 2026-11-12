// Prints one letter of a TrueType font as an SVG path, so the mark's "B" can
// be drawn without the font. Units are the font's own (y up is flipped to
// SVG's y down, baseline at 0).
//
//   node tools/brand/glyph.mjs assets/fonts/lilita_one/LilitaOne-Regular.ttf B
import { readFileSync } from "node:fs";

const [file, letter = "B"] = process.argv.slice(2);
if (!file) {
  console.error("usage: node glyph.mjs <font.ttf> [letter]");
  process.exit(2);
}
const buf = readFileSync(file);
const u16 = (o) => buf.readUInt16BE(o);
const i16 = (o) => buf.readInt16BE(o);
const u32 = (o) => buf.readUInt32BE(o);

const tables = {};
for (let i = 0, n = u16(4); i < n; i++) {
  const o = 12 + i * 16;
  tables[buf.toString("latin1", o, o + 4)] = u32(o + 8);
}

function glyphIndex(code) {
  const cmap = tables.cmap;
  for (let i = 0, n = u16(cmap + 2); i < n; i++) {
    const sub = cmap + u32(cmap + 4 + i * 8 + 4);
    if (u16(sub) !== 4) continue;
    const segs = u16(sub + 6) / 2;
    const ends = sub + 14, starts = ends + segs * 2 + 2, deltas = starts + segs * 2, ranges = deltas + segs * 2;
    for (let s = 0; s < segs; s++) {
      if (code > u16(ends + s * 2)) continue;
      const start = u16(starts + s * 2);
      if (code < start) return 0;
      const range = u16(ranges + s * 2);
      if (range === 0) return (code + i16(deltas + s * 2)) & 0xffff;
      const g = u16(ranges + s * 2 + range + (code - start) * 2);
      return g === 0 ? 0 : (g + i16(deltas + s * 2)) & 0xffff;
    }
  }
  throw new Error("no format 4 cmap");
}

const gid = glyphIndex(letter.codePointAt(0));
const long = i16(tables.head + 50) === 1;
const at = (g) => (long ? u32(tables.loca + g * 4) : u16(tables.loca + g * 2) * 2);
let p = tables.glyf + at(gid);
const contours = i16(p);
if (contours < 0) throw new Error("composite glyphs are not handled");
const box = [i16(p + 2), i16(p + 4), i16(p + 6), i16(p + 8)];
p += 10;
const ends = [];
for (let i = 0; i < contours; i++, p += 2) ends.push(u16(p));
p += 2 + u16(p); // skip the hinting program
const count = ends[ends.length - 1] + 1;
const flags = [];
while (flags.length < count) {
  const f = buf[p++];
  flags.push(f);
  if (f & 8) for (let r = buf[p++]; r > 0; r--) flags.push(f);
}
function coords(short, same) {
  const out = [];
  let v = 0;
  for (const f of flags) {
    if (f & short) v += f & same ? buf[p++] : -buf[p++];
    else if (!(f & same)) { v += i16(p); p += 2; }
    out.push(v);
  }
  return out;
}
const xs = coords(2, 16);
const ys = coords(4, 32);

const n = (v) => String(Math.round(v * 10) / 10);
let d = "";
let first = 0;
for (const end of ends) {
  const pts = [];
  for (let i = first; i <= end; i++) pts.push({ x: xs[i], y: -ys[i], on: (flags[i] & 1) === 1 });
  first = end + 1;
  const mid = (a, b) => ({ x: (a.x + b.x) / 2, y: (a.y + b.y) / 2, on: true });
  // Start on a point that is on the curve, making one if there is none.
  let s = pts.findIndex((q) => q.on);
  let start;
  if (s < 0) { start = mid(pts[0], pts[pts.length - 1]); s = 0; } else { start = pts[s]; s += 1; }
  d += `M${n(start.x)} ${n(start.y)}`;
  const ring = [...pts.slice(s), ...pts.slice(0, s)];
  if (ring[ring.length - 1] !== start) ring.push(start);
  for (let i = 0; i < ring.length; i++) {
    const q = ring[i];
    if (q.on) { d += `L${n(q.x)} ${n(q.y)}`; continue; }
    const next = ring[i + 1] ?? start;
    const to = next.on ? next : mid(q, next);
    d += `Q${n(q.x)} ${n(q.y)} ${n(to.x)} ${n(to.y)}`;
    if (next.on) i++;
  }
  d += "Z";
}
console.log(`unitsPerEm ${u16(tables.head + 18)}  box x ${box[0]}..${box[2]}  y ${box[1]}..${box[3]} (font units, y up)`);
console.log(d);
