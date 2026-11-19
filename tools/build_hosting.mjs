// Assembles the two sites Firebase Hosting serves, from one build of the app.
//
// build/hosting is Battle Baseball (showcase.getbattleplan.app): the Flutter
// web app (build/web) at the root, which is also the landing page, plus the
// few plain pages kept as fast static HTML (website/pages/* wrapped in
// website/_layout.html). Firebase serves a file when one matches and hands
// every other path to the app, so /privacy is the static page and
// /events/abc is the app.
//
// build/hosting-shop is Battle Shop (shop.getbattleplan.app): the same app
// behind an index.html of its own, which tells the app to be the shop and
// nothing else (see below).
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
const shopOut = join(root, "build", "hosting-shop");

const esc = (s) => s.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;");

rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });

// The app.
if (existsSync(join(web, "index.html"))) {
  cpSync(web, out, { recursive: true });
} else {
  console.warn("build/web is missing: run `flutter build web --release` first.");
}

// Battle Shop: the app again, as a site of its own. Its index.html is the
// app's with Battle Shop's name in place of Battle Baseball's (the tab's
// title, the link preview a shared address gets, the band on the loading
// screen) and with <meta name="bb-site" content="shop">, which the app reads
// (lib/data/site.dart) to show the shop and none of its other screens.
const shop = {
  origin: "https://shop.getbattleplan.app",
  title: "Battle Shop · Battle Baseball shirts and team gear",
  short: "Battle Shop",
  description: "Battle Baseball shirts, and gear for the teams that play in its showcases. Printed to order and shipped to you.",
  image: "og-shop.png",
  imageAlt: "Battle Shop. Shirts and team gear. Battle Baseball tees in coral and royal blue.",
};
rmSync(shopOut, { recursive: true, force: true });
if (existsSync(join(web, "index.html"))) {
  cpSync(web, shopOut, { recursive: true });
  let html = readFileSync(join(web, "index.html"), "utf8");
  // Each part of index.html that names the site. A change there that one of
  // these no longer matches stops the build, so Battle Shop can't quietly
  // go out saying Battle Baseball.
  const set = (pattern, value) => {
    if (!pattern.test(html)) throw new Error(`Battle Shop: nothing in web/index.html matches ${pattern}`);
    html = html.replace(pattern, (_, before, after) => before + value + after);
  };
  const attr = (tag, key, name, value) =>
    set(new RegExp(`(<${tag} ${key}="${name}" (?:content|href)=")[^"]*(")`), esc(value));
  // Its own address everywhere the page gives one, the canonical link's
  // script included.
  set(/()https:\/\/showcase\.getbattleplan\.app()/, shop.origin);
  html = html.replaceAll("https://showcase.getbattleplan.app", shop.origin);
  set(/(<title>)[^<]*(<\/title>)/, esc(shop.title));
  attr("meta", "name", "description", shop.description);
  attr("link", "rel", "canonical", `${shop.origin}/`);
  attr("meta", "property", "og:site_name", shop.short);
  attr("meta", "property", "og:title", shop.title);
  attr("meta", "property", "og:description", shop.description);
  attr("meta", "property", "og:url", `${shop.origin}/`);
  attr("meta", "property", "og:image", `${shop.origin}/${shop.image}`);
  attr("meta", "property", "og:image:alt", shop.imageAlt);
  attr("meta", "name", "twitter:title", shop.title);
  attr("meta", "name", "twitter:description", shop.description);
  attr("meta", "name", "twitter:image", `${shop.origin}/${shop.image}`);
  attr("meta", "name", "apple-mobile-web-app-title", shop.short);
  // A phone's browser tints its bar to match the band at the top of the page.
  attr("meta", "name", "theme-color", "#1A3F9A");
  // What tells the app which site it is.
  set(/(<meta name="viewport"[^>]*>\n)()/, '  <meta name="bb-site" content="shop">\n');
  // The loading screen: Battle Shop's band as the app draws it (the tank and
  // BATTLE over SHOP on the darker blue, over a line of stitches), and no
  // showcase headline. Sizes and positions mirror _BattleShopBar and ShopMark
  // in lib/screens/merch.dart, so the app's first frame lands on top of this
  // without anything moving.
  set(
    /(<div class="shell-bar">)<div class="shell-mark"><b>BATTLE<\/b><i>BASEBALL<\/i><\/div>(<\/div>)/,
    '<div class="shell-row"><img class="shell-tank" src="assets/assets/brand/tank.png" alt="">' +
      '<div class="shell-mark"><b>BATTLE</b><i>SHOP</i></div></div>',
  );
  set(/()[ \t]*<div class="shell-home">[\s\S]*?<\/div>\n()/, "");
  set(
    /(\n)(  <\/style>)/,
    `    /* Battle Shop's band: 76 px on phones and 116 on desktop, on a 3 px ink
       edge, with the mark set in the room above the stitches. */
    .shell-bar {
      position: relative; box-sizing: content-box; max-width: none; margin: 0; padding: 0; height: 76px;
      background: #1a3f9b; background: color-mix(in srgb, var(--ink) 30%, var(--field));
      border-bottom: 3px solid var(--ink); --s: 1.24675;
    }
    .shell-bar::after {
      content: ""; position: absolute; left: 0; right: 0; bottom: 5px; height: 2px;
      background: repeating-linear-gradient(90deg, color-mix(in srgb, var(--coral) 65%, transparent) 0 7px, transparent 7px 12px);
    }
    .shell-row { box-sizing: border-box; display: flex; align-items: center; max-width: 1200px; height: 72px; margin: 0 auto; padding: 0 16px; }
    .shell-tank { height: calc(34.65px * var(--s)); width: auto; margin-right: calc(9.24px * var(--s)); }
    @media (min-width: 960px) {
      .shell-bar { max-width: none; padding: 0; height: 116px; --s: 1.87013; }
      .shell-bar::after { bottom: 7px; }
      .shell-row { height: 110px; padding: 0 40px; }
    }
`,
  );
  writeFileSync(join(shopOut, "index.html"), html);

  const manifest = JSON.parse(readFileSync(join(web, "manifest.json"), "utf8"));
  Object.assign(manifest, { name: shop.short, short_name: shop.short, description: shop.description });
  writeFileSync(join(shopOut, "manifest.json"), JSON.stringify(manifest, null, 2) + "\n");
  writeFileSync(join(shopOut, "robots.txt"), `User-agent: *\nAllow: /\n\nSitemap: ${shop.origin}/sitemap.xml\n`);
  writeFileSync(
    join(shopOut, "sitemap.xml"),
    `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n  <url><loc>${shop.origin}/</loc></url>\n</urlset>\n`,
  );
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
console.log(`Built ${shopOut}`);
