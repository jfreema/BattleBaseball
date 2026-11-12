// Assembles build/hosting for Firebase Hosting: the website (website/pages/*
// wrapped in website/_layout.html) at the root and the Flutter web app
// (build/web, built with --base-href /app/) under /app/.
//
//   flutter build web --release --base-href /app/
//   node tools/build_hosting.mjs
//   firebase deploy --only hosting
import { cpSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const site = join(root, "website");
const out = join(root, "build", "hosting");

rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });

// Static files, copied as they are.
for (const name of readdirSync(site)) {
  if (name === "pages" || name.startsWith("_")) continue;
  cpSync(join(site, name), join(out, name), { recursive: true });
}

// Pages: each starts with <!-- title: ... -->, <!-- description: ... -->,
// and optionally <!-- scripts: a.js b.js -->.
const layout = readFileSync(join(site, "_layout.html"), "utf8");
const esc = (s) => s.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;");
for (const file of readdirSync(join(site, "pages")).filter((f) => f.endsWith(".html"))) {
  let body = readFileSync(join(site, "pages", file), "utf8");
  const meta = {};
  body = body.replace(/^\s*<!--\s*(\w+):\s*([\s\S]*?)\s*-->\s*\n/gm, (_, k, v) => {
    meta[k] = v;
    return "";
  });
  const slug = file.replace(/\.html$/, "");
  const path = slug === "index" ? "/" : `/${slug}`;
  const scripts = (meta.scripts ?? "")
    .split(/\s+/)
    .filter(Boolean)
    .map((s) => `  <script src="/${s}" defer></script>`)
    .join("\n");
  const html = layout
    .replaceAll("{{title}}", esc(meta.title ?? "Battle Baseball"))
    .replaceAll("{{description}}", esc(meta.description ?? ""))
    .replaceAll("{{path}}", path)
    .replace("{{scripts}}", scripts)
    .replace("{{body}}", body.trimEnd());
  writeFileSync(join(out, file), html);
}

// The Flutter web app.
const web = join(root, "build", "web");
if (existsSync(join(web, "index.html"))) {
  cpSync(web, join(out, "app"), { recursive: true });
} else {
  console.warn("build/web is missing: run `flutter build web --release --base-href /app/` first.");
}
console.log(`Built ${out}`);
