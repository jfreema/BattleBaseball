# Battle Baseball

Youth baseball **player showcases** in Baton Rouge: players sign up on their own, play on even teams with kids at their level, get their fastball clocked, and share their results. Showcases raise money for the local teams whose volunteers run them.

One Flutter app for iPhone, Android, and the web, on Firebase, in BattlePlan's Open Field look (Navy scheme). The plan behind it: [Battle Baseball: Website and App Plan](https://claude.ai/artifact/6XodKTjTkJmXmxrKbXxJtg).

- Website: https://showcase.getbattleplan.app (static pages in `website/`)
- Web app: https://showcase.getbattleplan.app/app/ (the Flutter web build)
- Firebase project: `battlebaseball-prod` (Firestore, Authentication, Hosting). DNS is in Cloudflare's `getbattleplan.app` zone.

## Layout

| Path | What |
|---|---|
| `lib/design/bb.dart` | The design system: Navy colors, candy faces, Lilita/Black Ops One/Fredoka/Nunito, rimmed cards on a lip, candy buttons, the wordmark |
| `lib/data/` | Models, Firestore reads and writes (`repo.dart`), and who's signed in with which role (`session.dart`) |
| `lib/screens/` | Home, Events (detail, reserve, results), Players, Leaderboards, More, Admin, and event-day tools (check-in, radar, awards, publish) |
| `website/` | Plain HTML and CSS. `pages/*.html` are wrapped in `_layout.html` by `tools/build_hosting.mjs`; `site.css` started from BattlePlan's |
| `firestore.rules` | Who can do what (below) |

## Roles

| Role | Set in | Can |
|---|---|---|
| Owner | `roles/{uid}` with `role: "owner"`, set by hand in the Firebase console | Everything, plus payment settings, adding admins, and Payment check |
| Battle Baseball admin | `roles/{uid}` with `role: "admin"`, added by the owner in the app | Every event: create and edit, mark paid, offer waitlist spots, choose event admins, publish |
| Event admin | `staffAssignments/{eventId}_{uid}`, `role: "eventAdmin"` | One event: edit it, mark paid, add volunteers, publish results |
| Event staff | `staffAssignments/{eventId}_{uid}`, `role: "staff"` | One event: check-in, measurements, awards |

To make an account the owner: sign up in the app, then in the Firebase console create `roles/<that user's uid>` with the field `role` = `owner`.

## Payments

Parents pay the owner's Venmo or Cash App (set in Admin, Payment settings) with a code like `BB-7K2F` in the note, then tap **Reserve, I've paid**. The spot is held for 24 hours while any admin of the event confirms it with **Mark paid**. Holds that end show up at the top of Payments for an admin to release to the waitlist; families get an **I already paid** button. The wording follows the plan's "Saying it gently" section.

## Build and deploy

Needs Flutter 3.50+, Node 20+, and the Firebase CLI.

```bash
flutter pub get
flutter build web --release --base-href /app/
node tools/build_hosting.mjs
firebase deploy --only hosting,firestore
```

There's no dev environment yet: this deploys straight to production.

## Not built yet

Push notifications and the 24-hour hold timer on the server (both need Cloud Functions and the Blaze plan), Facebook share previews for event and player pages, Sign in with Apple and Google, photo uploads, the scorebook and pitch counts, team placement, host payouts, the Battle Paddle shop, and store builds for iOS and Android.
