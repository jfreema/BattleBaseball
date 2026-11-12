// Renders the brand images from their sources with headless Edge or Chrome.
//
//   node tools/brand/render.mjs
//
// web/favicon.svg            -> web/favicon.png (32)
// tools/brand/icon.svg       -> web/icons/Icon-192.png, Icon-512.png
// tools/brand/icon-maskable.svg -> web/icons/Icon-maskable-192.png, -512.png
// tools/brand/og.html        -> web/og.png (1200 x 630)
//
// The B in the mark is Lilita One's, traced once with glyph.mjs. The SVGs
// pin their art to the top left (preserveAspectRatio="xMinYMin") because a
// headless window is never narrower than about 500 px: the picture is taken
// from that corner.
import { execFileSync } from "node:child_process";
import { existsSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..", "..");
const browser = [
  process.env.BROWSER,
  "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe",
  "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe",
  "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  "/usr/bin/google-chrome",
].find((p) => p && existsSync(p));
if (!browser) throw new Error("Set BROWSER to a Chromium-based browser.");

const jobs = [
  ["web/favicon.svg", "web/favicon.png", 32, 32, true],
  ["tools/brand/icon.svg", "web/icons/Icon-192.png", 192, 192],
  ["tools/brand/icon.svg", "web/icons/Icon-512.png", 512, 512],
  ["tools/brand/icon-maskable.svg", "web/icons/Icon-maskable-192.png", 192, 192],
  ["tools/brand/icon-maskable.svg", "web/icons/Icon-maskable-512.png", 512, 512],
  ["tools/brand/og.html", "web/og.png", 1200, 630],
];

for (const [source, out, width, height, clear] of jobs) {
  const profile = mkdtempSync(join(tmpdir(), "bbbrand-"));
  try {
    execFileSync(browser, [
      "--headless=new",
      `--user-data-dir=${profile}`,
      "--no-first-run",
      "--hide-scrollbars",
      "--force-device-scale-factor=1",
      `--window-size=${width},${height}`,
      // Rounded corners stay see-through on the favicon.
      ...(clear ? ["--default-background-color=00000000"] : []),
      "--virtual-time-budget=4000",
      `--screenshot=${join(root, out)}`,
      pathToFileURL(join(root, source)).href,
    ], { stdio: "ignore" });
    console.log(`${out}  ${width}x${height}`);
  } finally {
    try { rmSync(profile, { recursive: true, force: true }); } catch {}
  }
}
