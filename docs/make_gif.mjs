// Turns the raw RGBA frame dump from --scenario=pennygif into a transparent GIF.
//   node docs/make_gif.mjs <frames dir> <out.gif>
import fs from "node:fs";
import path from "node:path";

const dir = process.argv[2];
const outPath = process.argv[3];
const [W, H, FPS, N] = fs.readFileSync(path.join(dir, "meta.txt"), "utf8").trim().split(/\s+/).map(Number);
const frames = [];
for (let i = 0; i < N; i++) frames.push(new Uint8Array(fs.readFileSync(path.join(dir, `frame_${String(i).padStart(4, "0")}.bin`))));

// union bounding box of everything that is not transparent
let minX = W, minY = H, maxX = -1, maxY = -1;
for (const f of frames) for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
  if (f[(y * W + x) * 4 + 3] > 40) { if (x < minX) minX = x; if (x > maxX) maxX = x; if (y < minY) minY = y; if (y > maxY) maxY = y; }
}
const M = 10;
const cx0 = Math.max(0, minX - M), cy0 = Math.max(0, minY - M);
const cx1 = Math.min(W - 1, maxX + M), cy1 = Math.min(H - 1, maxY + M);
const CW = cx1 - cx0 + 1, CH = cy1 - cy0 + 1;

// palette: 5 bit buckets, most common 255 win, everything else snaps to nearest
const counts = new Uint32Array(32768), sums = new Float64Array(32768 * 3);
for (const f of frames) for (let y = cy0; y <= cy1; y++) for (let x = cx0; x <= cx1; x++) {
  const o = (y * W + x) * 4;
  if (f[o + 3] <= 40) continue;
  const k = ((f[o] >> 3) << 10) | ((f[o + 1] >> 3) << 5) | (f[o + 2] >> 3);
  counts[k]++; sums[k * 3] += f[o]; sums[k * 3 + 1] += f[o + 1]; sums[k * 3 + 2] += f[o + 2];
}
const order = Array.from({ length: 32768 }, (_, i) => i).filter(k => counts[k] > 0).sort((a, b) => counts[b] - counts[a]);
const palette = [[0, 0, 0]];              // slot 0 is the transparent colour
const slotOf = new Map();
for (const k of order.slice(0, 255)) {
  const c = counts[k];
  palette.push([Math.round(sums[k * 3] / c), Math.round(sums[k * 3 + 1] / c), Math.round(sums[k * 3 + 2] / c)]);
  slotOf.set(k, palette.length - 1);
}
const nearest = new Int16Array(32768).fill(-1);
function slotFor(k) {
  const hit = slotOf.get(k); if (hit !== undefined) return hit;
  if (nearest[k] >= 0) return nearest[k];
  const r = ((k >> 10) & 31) * 8 + 4, g = ((k >> 5) & 31) * 8 + 4, b = (k & 31) * 8 + 4;
  let best = 1, bestD = Infinity;
  for (let i = 1; i < palette.length; i++) {
    const dr = palette[i][0] - r, dg = palette[i][1] - g, db = palette[i][2] - b;
    const d = dr * dr + dg * dg + db * db;
    if (d < bestD) { bestD = d; best = i; }
  }
  nearest[k] = best; return best;
}
const mapped = frames.map(f => {
  const out = new Uint8Array(CW * CH);
  for (let y = 0; y < CH; y++) for (let x = 0; x < CW; x++) {
    const o = ((y + cy0) * W + (x + cx0)) * 4;
    out[y * CW + x] = f[o + 3] <= 40 ? 0 : slotFor(((f[o] >> 3) << 10) | ((f[o + 1] >> 3) << 5) | (f[o + 2] >> 3));
  }
  return out;
});

// GIF LZW. The code size grows one code AFTER the table crosses the boundary,
// because the decoder is always one entry behind the encoder.
function lzw(indices) {
  const clear = 256, eoi = 257;
  let codeSize = 9, next = 258, pendingBump = false;
  const dict = new Map(), out = [];
  let bitBuf = 0, bitCount = 0;
  const emit = (code) => {
    bitBuf |= code << bitCount; bitCount += codeSize;
    while (bitCount >= 8) { out.push(bitBuf & 0xff); bitBuf >>>= 8; bitCount -= 8; }
    if (pendingBump && codeSize < 12) { codeSize++; pendingBump = false; }
  };
  emit(clear);
  let prefix = -1;
  for (let i = 0; i < indices.length; i++) {
    const c = indices[i];
    if (prefix < 0) { prefix = c; continue; }
    const key = prefix * 4096 + c;
    const found = dict.get(key);
    if (found !== undefined) { prefix = found; continue; }
    emit(prefix);
    if (next < 4096) {
      dict.set(key, next); next++;
      if (next === (1 << codeSize)) pendingBump = true;
    } else {
      emit(clear); dict.clear(); next = 258; codeSize = 9; pendingBump = false;
    }
    prefix = c;
  }
  if (prefix >= 0) emit(prefix);
  emit(eoi);
  if (bitCount > 0) out.push(bitBuf & 0xff);
  return out;
}

const gif = [];
const u16 = (v) => { gif.push(v & 0xff, (v >> 8) & 0xff); };
const ascii = (s) => { for (const ch of s) gif.push(ch.charCodeAt(0)); };
ascii("GIF89a"); u16(CW); u16(CH); gif.push(0xF7, 0, 0);
for (let i = 0; i < 256; i++) { const c = palette[i] ?? [0, 0, 0]; gif.push(c[0], c[1], c[2]); }
gif.push(0x21, 0xFF, 0x0B); ascii("NETSCAPE2.0"); gif.push(0x03, 0x01, 0x00, 0x00, 0x00);
const delay = Math.max(2, Math.round(100 / FPS));
for (const idx of mapped) {
  gif.push(0x21, 0xF9, 0x04, 0x09); u16(delay); gif.push(0x00, 0x00);
  gif.push(0x2C); u16(0); u16(0); u16(CW); u16(CH); gif.push(0x00, 0x08);
  const data = lzw(idx);
  for (let o = 0; o < data.length; o += 255) {
    const n = Math.min(255, data.length - o);
    gif.push(n);
    for (let k = 0; k < n; k++) gif.push(data[o + k]);
  }
  gif.push(0x00);
}
gif.push(0x3B);
fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, Buffer.from(gif));
console.log(`${outPath}: ${N} frames, ${CW}x${CH}, ${(gif.length / 1024).toFixed(0)} KB`);
