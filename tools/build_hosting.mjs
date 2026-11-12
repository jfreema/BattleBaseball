// Assembles build/hosting for Firebase Hosting: the Flutter web app (build/web)
// at the root, which is also the landing page, plus the few plain pages kept
// as fast static HTML (website/pages/* wrapped in website/_layout.html).
// Firebase serves a file when one matches and hands every other path to the
// app, so /privacy is the static page and /events/abc is the app.
//
//   flutter build web --release
//   node tools/build_hosting.mjs
//   firebase deploy --only hosting
import { cpSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const site = join(root, "website");
const web = join(root, "build", "web");
const out = join(root, "build", "hosting");

rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });

// The app.
if (existsSync(join(web, "index.html"))) {
  cpSync(web, out, { recursive: true });
} else {
  console.warn("build/web is missing: run `flutter build web --release` first.");
}

// Static files beside it, copied as they are. None may replace an app file.
for (const name of readdirSync(site)) {
  if (name === "pages" || name.startsWith("_")) continue;
  if (existsSync(join(out, name)) && !["fonts", "images"].includes(name)) {
    throw new Error(`website/${name} would overwrite the app's ${name}`);
  }
  cpSync(join(site, name), join(out, name), { recursive: true });
}

// Pages: each starts with <!-- title: ... -->, <!-- description: ... -->,
// and optionally <!-- scripts: a.js b.js -->.
const layout = readFileSync(join(site, "_layout.html"), "utf8");
const esc = (s) => s.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;");
for (const file of readdirSync(join(site, "pages")).filter((f) => f.endsWith(".html"))) {
  if (file === "index.html") throw new Error("The home page is the app: remove website/pages/index.html");
  let body = readFileSync(join(site, "pages", file), "utf8");
  const meta = {};
  body = body.replace(/^\s*<!--\s*(\w+):\s*([\s\S]*?)\s*-->\s*\n/gm, (_, k, v) => {
    meta[k] = v;
    return "";
  });
  const slug = file.replace(/\.html$/, "");
  const scripts = (meta.scripts ?? "")
    .split(/\s+/)
    .filter(Boolean)
    .map((s) => `  <script src="/${s}" defer></script>`)
    .join("\n");
  const html = layout
    .replaceAll("{{title}}", esc(meta.title ?? "Battle Baseball"))
    .replaceAll("{{description}}", esc(meta.description ?? ""))
    .replaceAll("{{path}}", `/${slug}`)
    .replace("{{scripts}}", scripts)
    .replace("{{body}}", body.trimEnd());
  writeFileSync(join(out, file), html);
}

console.log(`Built ${out}`);
