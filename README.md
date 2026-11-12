# Battle Baseball

Youth baseball **player showcases** in Baton Rouge: players sign up on their own, get their fastball clocked on radar, and earn a player card with their results. Showcases raise money for the local teams whose volunteers run them.

One Flutter app for the web, iPhone, and Android, on Firebase. The design is "The Card": cream card stock, ink outlines, hard lips, and one accent band, in the family of BattlePlan. Its colors come from a scheme (`lib/design/schemes.dart`): Royal Blue by default, and any Battle Baseball admin can switch the whole app and site to another one in Staff tools > Color scheme. The plan behind it: [Battle Baseball: Website and App Plan](https://claude.ai/artifact/6XodKTjTkJmXmxrKbXxJtg).

- Site: https://showcase.getbattleplan.app. The Flutter web build is served at the root, and its signed-out Home is the landing page.
- Five plain pages sit beside it: `/privacy`, `/terms`, `/waiver`, `/support`, `/delete-account`.
- Firebase project: `battlebaseball-prod` (Firestore, Authentication, Hosting). DNS is in Cloudflare's `getbattleplan.app` zone.

## Layout

| Path | What |
|---|---|
| `lib/design/schemes.dart` | The color schemes. Every color in the app comes from the one in use |
| `lib/design/bb.dart` | Tokens (colors from the scheme in use, type), the theme, and the primitives: buttons, paper panels, pills, chips, the wordmark, the fine-print sheet |
| `lib/design/card.dart` | The player card front and back, award seals, leaderboard rows, the velocity chart |
| `lib/design/ticket.dart` | The showcase ticket |
| `lib/data/` | Models, Firestore reads and writes (`repo.dart`), who's signed in with which role (`session.dart`), the sample player (`sample.dart`), and sample data for demo mode (`demo.dart`) |
| `lib/screens/` | Home, Showcases (list, detail, reserve, results), Players (directory, profile, form), Leaders, Host, Account, sign-in, Admin, and event-day tools (check-in, radar, stats, awards, publish) |
| `lib/app.dart` | Routes and the shell: a bottom bar on phones, a top bar from 960 px |
| `web/` | The Flutter web shell: `index.html`, manifest, icons |
| `website/` | The five plain pages. `pages/*.html` are wrapped in `_layout.html` by `tools/build_hosting.mjs`; `site.css` and `fonts/` are all they use |
| `firebase.json` | Hosting serves a file when one matches and hands every other path to the app; `/app/*` redirects to the root |
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
| `/host` | Host a Showcase |
| `/account` | Account |
| `/sign-in`, `/sign-up`, `/welcome` | Sign in, create an account, finish an account |
| `/admin/...` | Staff tools (staff only) |

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

## Payments

Parents pay the owner's Venmo or Cash App (set in Admin, Payment settings) with a code like `BB-7K2F` in the note, then tap **Reserve**. The spot is held for 24 hours while any admin of the event confirms it with **Mark paid**. Holds that end show up at the top of Payments for an admin to release to the waitlist; families get an **I already paid** button.

## Color schemes

Royal Blue is the default. A Battle Baseball admin opens Staff tools > Color scheme, taps a scheme to try it on (only they see it), then taps **Use for everyone**, which saves it to `config/theme` and logs the change. Every open copy of the app switches within a second or two. On the web the scheme's colors are also remembered in the browser (`localStorage` key `bb.scheme`), so the loading screen and the plain pages match it. Add `?scheme=<id>` to a URL (for example `?scheme=christmas`) to look at a scheme without saving it. The ids are in `lib/design/schemes.dart`.

## Demo mode

Add `?demo=1` to any URL to see the app filled with sample data; every write is refused, except that a color scheme picked in Staff tools lasts until the page reloads. `?demo=family` adds a pretend signed-in parent, and `?demo=staff` an owner. It lasts until a full page reload. `/dev/gallery` (demo only) shows every shared component.

## Build and deploy

Needs Flutter 3.50+, Node 20+, and the Firebase CLI.

```bash
flutter pub get
flutter build web --release
node tools/build_hosting.mjs
firebase deploy --only hosting,firestore
```

`build_hosting.mjs` copies the app to `build/hosting`, then the plain pages. It stops if a file in `website/` would overwrite an app file.

There's no dev environment yet: this deploys straight to production.

### Deploying from GitHub

Deploying from a PC is the usual way. The **Deploy** workflow does the same build and deploy on GitHub, but only when started by hand: Actions > Deploy > Run workflow, then pick the site and database rules, the site only, the rules only, or a preview link that expires in a week. It never runs on push.

It signs in with workload identity federation, so there is no key or GitHub secret. Only runs from this repo's `main` branch may act as the `github-deploy` service account. One-time setup: open [Cloud Shell](https://console.cloud.google.com/?cloudshell=true&project=battlebaseball-prod) as a project owner and paste [tools/setup_github_deploy.sh](tools/setup_github_deploy.sh). Running it again is harmless.

## Not built yet

Push notifications and the 24-hour hold timer on the server (both need Cloud Functions and the Blaze plan), Facebook share previews for event and player pages, Sign in with Apple, photo uploads, pitch counts, team placement, host payouts, the Battle Paddle shop, and store builds for iOS and Android.
