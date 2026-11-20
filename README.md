# Battle Baseball

Youth baseball **player showcases** in Baton Rouge: players sign up on their own, get their fastball clocked on radar, and earn a player card with their results. Showcases raise money for the local teams whose volunteers run them.

One Flutter app for the web, iPhone, and Android, on Firebase. The design is "The Card": cream card stock, ink outlines, hard lips, and one accent band, in the family of BattlePlan. Its colors come from a scheme (`lib/design/schemes.dart`): Royal Blue by default, and any Battle Baseball admin can switch the whole app and site to another one in Staff tools > Color scheme. The plan behind it: [Battle Baseball: Website and App Plan](https://claude.ai/artifact/6XodKTjTkJmXmxrKbXxJtg).

- Site: https://showcase.getbattleplan.app. The Flutter web build is served at the root, and its signed-out Home is the landing page.
- Five plain pages sit beside it: `/privacy`, `/terms`, `/waiver`, `/support`, `/delete-account`.
- Battle Shop, https://shop.getbattleplan.app, is the Merch shop on a site of its own: the same shirts and cart, with nothing of the Battle Baseball site around it and no link into it (see Merch below).
- Firebase project: `battlebaseball-prod` (Firestore, Authentication, Hosting). It has two Hosting sites: `battlebaseball-prod` (the Battle Baseball site) and `battlebaseball-shop` (Battle Shop). DNS is in Cloudflare's `getbattleplan.app` zone: `showcase` and `shop` are DNS-only CNAMEs to each site's `.web.app` address.

## Layout

| Path | What |
|---|---|
| `lib/design/schemes.dart` | The color schemes. Every color in the app comes from the one in use |
| `lib/design/bb.dart` | Tokens (colors from the scheme in use, type), the theme, and the primitives: buttons, paper panels, pills, chips, the wordmark, the fine-print sheet |
| `lib/design/card.dart` | The player card front and back, award seals, leaderboard rows, the velocity chart |
| `lib/design/ticket.dart` | The showcase ticket |
| `lib/data/` | Models, Firestore reads and writes (`repo.dart`), who's signed in with which role (`session.dart`), the sample player (`sample.dart`), sample data for demo mode (`demo.dart`), the merch shop: Shopify products, the cart and checkout (`shop.dart`), product descriptions (`shop_html.dart`), and the sample shirts (`shop_sample.dart`), and which of the two sites the app was opened as (`site.dart`) |
| `lib/screens/` | Home, Showcases (list, detail, reserve, results), Players (directory, profile, form), Leaders, Merch (the shop, a shirt, the cart, and Battle Shop's frame around the same screens), Host, Account, sign-in, Admin, and event-day tools (roster and check-in, radar, stats, awards, publish) |
| `lib/app.dart` | Routes and the shell: a bottom bar on phones, a top bar from 960 px. On Battle Shop's site the routes are the shop's alone |
| `web/` | The Flutter web shell: `index.html`, manifest, icons, and the link preview images (`og.png`, and `og-shop.png` for Battle Shop) |
| `website/` | The five plain pages. `pages/*.html` are wrapped in `_layout.html` by `tools/build_hosting.mjs`; `site.css` and `fonts/` are all they use |
| `firebase.json` | Two Hosting sites. Each serves a file when one matches and hands every other path to the app. On the Battle Baseball site `/app/*` redirects to the root and `/shop` to Battle Shop's site |
| `firestore.rules` | Who can do what (below) |

## Routes

| Path | Screen |
|---|---|
| `/` | Home |
| `/events`, `/events/:id`, `/events/:id/results` | Showcases, one showcase, its results |
| `/events/:id/reserve` | Reserve a spot (sign-in) |
| `/players`, `/players/:id` | Players, a player's card |
| `/players/sample` | The sample card |
| `/players/new`, `/players/:id/edit` | The player form (sign-in) |
| `/leaders` | Leaders |
| `/merch`, `/merch/:handle`, `/merch/cart` | Merch: the shop, a shirt, the cart (`/shop` goes to Battle Shop's site) |
| `/host` | Host a Showcase |
| `/account` | Account |
| `/sign-in`, `/sign-up`, `/welcome` | Sign in, create an account, finish an account |
| `/admin/...` | Staff tools (staff only) |

Battle Shop's site, https://shop.getbattleplan.app, has three addresses and none of the above: `/` is the shop, `/:handle` a shirt, `/cart` the cart.

## Data

| Collection | Holds | Public |
|---|---|---|
| `events`, `divisions` | Showcases and their age groups | Yes, once listed |
| `players`, `playerPrivate` | A family's players; birth date, school, and emergency contact | No |
| `publicProfiles` | What a public card shows: display name, grad year, positions, bats, throws, state, jersey. Written when a guardian switches the card public, deleted when they switch it off | Yes |
| `registrations` | A player's spot at a showcase and its payment status | No |
| `measurements`, `awards` | Radar and timed readings, and awards | Once published |
| `statLines` | One batting and pitching line per player per showcase (`{eventId}_{playerId}`) | Once published |
| `users`, `userEmails`, `roles`, `staffAssignments` | Accounts and roles | No |
| `config/payments` | The Venmo and Cash App handles | Yes |
| `config/theme` | The color scheme everyone sees, picked by an admin in Staff tools > Color scheme | Yes |
| `hostInquiries`, `auditLogs` | Host a Showcase requests; admin actions | No |

## Roles

| Role | Set in | Can |
|---|---|---|
| Owner | `roles/{uid}` with `role: "owner"`, set by hand in the Firebase console | Everything, plus payment settings, adding admins, and Payment check |
| Battle Baseball admin | `roles/{uid}` with `role: "admin"`, added by the owner in the app | Every event: create and edit, mark paid, offer waitlist spots, choose event admins, publish; switch the color scheme |
| Event admin | `staffAssignments/{eventId}_{uid}`, `role: "eventAdmin"` | One event: edit it, mark paid, add volunteers, publish results |
| Event staff | `staffAssignments/{eventId}_{uid}`, `role: "staff"` | One event: check-in, measurements, stats, awards |

To make an account the owner: sign up in the app, then in the Firebase console create `roles/<that user's uid>` with the field `role` = `owner`.

## Age groups, stats and leaderboards

There are three age groups: **10U** (10 and under), **12U** (11 and 12) and **14U** (13 and 14), in `ageGroups` in `lib/data/models.dart`. A showcase's divisions count toward the age group their number falls in, so an "11U" division counts as 12U and "13U" as 14U.

- **Roster.** Families reserve spots, and an event admin can also put any player on file on a showcase: Staff tools > Run > Check-in > **Add player**, pick the player, then the age group (picked for them from the birth date on file, as of the showcase's day). That spot has no hold or payment (`paidVia: "staff"`) and stays out of Payment check; the x on its row takes the player back off. Picking from every player needs a Battle Baseball admin, who can read all players.
- **Stats.** Every showcase records fastball velocity, the 40-yard dash and home runs; pop time only with the skills contest. Run > Stats lists the roster with each player's best fastball and 40 of the day and their line; tapping one opens a sheet with a fastball and 40-yard field (each adds a reading) and the scorebook steppers, home runs included. Run > Measure still takes readings by jersey number.
- **Each showcase's results** show a top 5 for fastball, the 40 (quickest first) and home runs, each player's best of the day, with chips to narrow them to one age group.
- **Leaders** has a board for each stat in each age group: every player's best from all published showcases, with the showcase it came from. Home runs rank by the most in one showcase. Only players with public cards are listed.

## Sample players

`tools/seed/showcase.mjs` loads 15 sample players named after kids from The Simpsons (five each aged 10, 12 and 13), two past showcases (Summer and Fall 2026) with all of them on the roster, published readings, stat lines and awards. Every id starts with `seed-`; each run first deletes every `seed-` document (including the earlier TV-show sample players), so it is safe to run again. It signs in with your gcloud account:

```bash
gcloud auth application-default login
npm --prefix tools/seed install
npm --prefix tools/seed run showcase              # load (or reload) the sample players
npm --prefix tools/seed run showcase -- --remove  # delete them all
```

## Payments

Parents pay the owner's Venmo or Cash App (set in Admin, Payment settings) with a code like `BB-7K2F` in the note, then tap **Reserve**. The spot is held for 24 hours while any admin of the event confirms it with **Mark paid**. Holds that end show up at the top of Payments for an admin to release to the waitlist; families get an **I already paid** button.

## Merch

Merch (`/merch`, and a section on Home) sells the shirts in the Battle Baseball Shopify store, `t03zrq-mv.myshopify.com`, which NinjaPOD prints and ships. The app reads the products, collections, prices and sizes from Shopify's Storefront API (`lib/data/shop.dart`). Shirts and collections are managed in Shopify admin: each collection with shirts in it becomes a section of the shop, except the "Home page" collection. No token is needed. To use one, build with `--dart-define=SHOPIFY_STOREFRONT_TOKEN=...`. The API version is `ShopConfig.apiVersion` (`2026-10`); Shopify keeps each version working for at least a year, so move it up once a year.

- While the store's password page is on, Shopify reports the store as locked and Merch shows **Coming soon**. Turning the password page off opens the shop in the app, with no deploy.
- **Battle Shop** (https://shop.getbattleplan.app) is the same shop on a site of its own, for sharing where the showcase site would be in the way. It shows whatever Merch shows, straight from Shopify. In place of the app's tabs and top bar it is dressed as a storefront: a band across the top of every page with its own mark (the baseball tank off the shirts in bubblegum pink, `assets/brand/tank.png`, beside BATTLE over SHOP), the Cart and a gold stripe; on its first page a ticker and a headline, "Shirts and team gear.", on slowly turning rays, with the shop's lowest price on a starburst; headings on a stroke of gold marker; each price on a gold tag; the shop's other shirts under each shirt's page; and a footer. The ticker, rays and starburst stand still for anyone who has asked their device for less motion. Merch in the app has none of those. Nothing on it leads to Home or any other Battle Baseball screen; those screens have no address there at all. It is the same build of the app: `tools/build_hosting.mjs` makes a second site folder, `build/hosting-shop`, whose `index.html` carries Battle Shop's title, description, link preview (`web/og-shop.png`, drawn from `tools/brand/og-shop.html`) and a loading screen that draws the same band, plus `<meta name="bb-site" content="shop">`. The app reads that (`lib/data/site.dart`) and uses Battle Shop's routes. The screens are Merch's own (`lib/screens/merch.dart`); `ShopSite` tells them which of the two they are showing in, and `BattleShopShell` is the frame. Its cart is its own, since a browser keeps each site's storage apart. To run it locally: `flutter run -d chrome --dart-define=SITE=shop`.
- The cart lives on the device: in the browser's `localStorage` under `bb.cart`, and in memory in the iOS and Android apps, where it lasts while the app is open. **Check out** makes a Shopify cart and opens Shopify's checkout page; on the web it takes the tab. Shopify deletes a cart once its order is placed, so when the buyer comes back the app sees that and takes the bought shirts out of its cart. Prices and sold-out sizes are checked again each time the cart opens.

## Color schemes

Royal Blue is the default. A Battle Baseball admin opens Staff tools > Color scheme, taps a scheme to try it on (only they see it), then taps **Use for everyone**, which saves it to `config/theme` and logs the change. Every open copy of the app switches within a second or two. On the web the scheme's colors are also remembered in the browser (`localStorage` key `bb.scheme`), so the loading screen and the plain pages match it. Add `?scheme=<id>` to a URL (for example `?scheme=christmas`) to look at a scheme without saving it. The ids are in `lib/design/schemes.dart`.

## Demo mode

Add `?demo=1` to any URL to see the app filled with sample data; every write is refused, except that a color scheme picked in Staff tools lasts until the page reloads. `?demo=family` adds a pretend signed-in parent, and `?demo=staff` an owner. It lasts until a full page reload. `/dev/gallery` (demo only) shows every shared component. Merch shows three sample shirts (`lib/data/shop_sample.dart`), and checkout is switched off.

## Build and deploy

Needs Flutter 3.50+, Node 20+, and the Firebase CLI.

```bash
flutter pub get
flutter build web --release
node tools/build_hosting.mjs
firebase deploy --only hosting,firestore
```

`build_hosting.mjs` copies the app to `build/hosting`, then the plain pages, and makes Battle Shop's copy in `build/hosting-shop`. It stops if a file in `website/` would overwrite an app file. `firebase deploy --only hosting` puts both sites up; `--only hosting:battlebaseball-prod` or `--only hosting:battlebaseball-shop` deploys one.

Battle Shop's site was set up once: `firebase hosting:sites:create battlebaseball-shop`, then `shop.getbattleplan.app` added to it as a custom domain in the Firebase console, with a DNS-only CNAME `shop` to `battlebaseball-shop.web.app` in Cloudflare.

There's no dev environment yet: this deploys straight to production.

### Deploying from GitHub

Deploying from a PC is the usual way. The **Deploy** workflow does the same build and deploy on GitHub, but only when started by hand: Actions > Deploy > Run workflow, then pick the site and database rules, the site only, the rules only, or a preview link that expires in a week. It never runs on push.

It signs in with workload identity federation, so there is no key or GitHub secret. Only runs from this repo's `main` branch may act as the `github-deploy` service account. One-time setup: open [Cloud Shell](https://console.cloud.google.com/?cloudshell=true&project=battlebaseball-prod) as a project owner and paste [tools/setup_github_deploy.sh](tools/setup_github_deploy.sh). Running it again is harmless.

## Not built yet

Push notifications and the 24-hour hold timer on the server (both need Cloud Functions and the Blaze plan), Facebook share previews for event and player pages, Sign in with Apple, photo uploads, pitch counts, team placement, host payouts, the Battle Paddle shop, and store builds for iOS and Android.
