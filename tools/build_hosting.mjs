// Assembles build/hosting for Firebase Hosting: the Flutter web app (build/web)
// at the root, which is also the landing page, plus the few plain pages kept
// as fast static HTML (website/pages/* wrapped in website/_layout.html).
// Firebase serves a file when one matches and hands every other path to the
// app, so /privacy is the static page and /events/abc is the app.
//
// Battle Shop (/shop) is the app too, but with a front door of its own:
// shop.html, the app's index.html under the shop's name (see below).
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

const esc = (s) => s.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;");

rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });

// The app.
if (existsSync(join(web, "index.html"))) {
  cpSync(web, out, { recursive: true });
} else {
  console.warn("build/web is missing: run `flutter build web --release` first.");
}

// Battle Shop's front door. The app answers /shop like any other address,
// but index.html introduces every page as Battle Baseball: the tab's title,
// the link preview a shared address gets, and the mark on the loading
// screen. shop.html is the same file introduced as Battle Shop. Firebase
// serves it for /shop (clean URLs) and for /shop/** (a rewrite in
// firebase.json), and the app takes over from there.
const shop = {
  title: "Battle Shop · Battle Baseball shirts and team gear",
  short: "Battle Shop",
  description: "Battle Baseball shirts, and gear for the teams that play in its showcases. Printed to order and shipped to you.",
  url: "https://showcase.getbattleplan.app/shop",
  image: "https://showcase.getbattleplan.app/og-shop.png",
  imageAlt: "Battle Shop. Shirts and team gear. Battle Baseball tees in coral and royal blue.",
};
if (existsSync(join(out, "index.html"))) {
  let html = readFileSync(join(out, "index.html"), "utf8");
  // Each line of index.html's head that names the site. A change there that
  // one of these no longer matches stops the build, so shop.html can't
  // quietly go out saying Battle Baseball.
  const set = (pattern, value) => {
    if (!pattern.test(html)) throw new Error(`shop.html: nothing in web/index.html matches ${pattern}`);
    html = html.replace(pattern, (_, before, after) => before + value + after);
  };
  const attr = (tag, key, name, value) =>
    set(new RegExp(`(<${tag} ${key}="${name}" (?:content|href)=")[^"]*(")`), esc(value));
  set(/(<title>)[^<]*(<\/title>)/, esc(shop.title));
  attr("meta", "name", "description", shop.description);
  attr("link", "rel", "canonical", shop.url);
  attr("meta", "property", "og:site_name", shop.short);
  attr("meta", "property", "og:title", shop.title);
  attr("meta", "property", "og:description", shop.description);
  attr("meta", "property", "og:url", shop.url);
  attr("meta", "property", "og:image", shop.image);
  attr("meta", "property", "og:image:alt", shop.imageAlt);
  attr("meta", "name", "twitter:title", shop.title);
  attr("meta", "name", "twitter:description", shop.description);
  attr("meta", "name", "twitter:image", shop.image);
  attr("meta", "name", "apple-mobile-web-app-title", shop.short);
  // The loading screen's mark: BATTLE over SHOP.
  set(/(<div class="shell-mark"><b>BATTLE<\/b><i>)BASEBALL(<\/i><\/div>)/, "SHOP");
  writeFileSync(join(out, "shop.html"), html);
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
for (const file of readdirSync(join(site, "pages")).filter((f) => f.endsWith(".html"))) {
  if (file === "index.html") throw new Error("The home page is the app: remove website/pages/index.html");
  if (file === "shop.html") throw new Error("Battle Shop is the app: remove website/pages/shop.html");
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
