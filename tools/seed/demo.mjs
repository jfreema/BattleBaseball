// Creates the App Review demo account on battlebaseball-prod: a parent,
// appreview@getbattleplan.app (or DEMO_EMAIL), with two players whose cards
// are private, so nothing shows on the public lists or leaderboards.
//
// Uses your gcloud sign-in (gcloud auth application-default login; no key
// file), and refuses every project but battlebaseball-prod:
//   read -s DEMO_PASSWORD && export DEMO_PASSWORD
//   npm --prefix tools/seed run demo
//
// Safe to run again: it resets the password and rewrites the same "demo-"
// documents. The password goes in App Store Connect only, never the repo.
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

const projectId = 'battlebaseball-prod';
const email = (process.env.DEMO_EMAIL || 'appreview@getbattleplan.app').toLowerCase();
const password = process.env.DEMO_PASSWORD || '';
if (password.length < 12) {
  console.error('Set DEMO_PASSWORD to 12 or more characters.');
  process.exit(1);
}

// A gcloud user sign-in needs a quota project for the Auth admin API.
process.env.GOOGLE_CLOUD_QUOTA_PROJECT ||= projectId;
initializeApp({ projectId, credential: applicationDefault() });
const auth = getAuth();
const db = getFirestore();

const existing = await auth.getUserByEmail(email).catch(() => null);
const user = existing
  ? await auth.updateUser(existing.uid, { password, emailVerified: true, disabled: false })
  : await auth.createUser({ uid: 'demo-appreview', email, password, emailVerified: true, displayName: 'App Review' });
const uid = user.uid;

const players = [
  {
    id: 'demo-review-cole',
    data: { firstName: 'Cole', lastName: 'Reviewer', gradYear: 2032, bats: 'R', throws: 'R', positions: ['SS', 'P'], jersey: 7, reportedVelo: 64 },
    private: { birthDate: '2014-04-12', school: 'Sample Middle School', emergencyName: 'App Review', emergencyPhone: '225-555-0100' },
  },
  {
    id: 'demo-review-mason',
    data: { firstName: 'Mason', lastName: 'Reviewer', gradYear: 2030, bats: 'L', throws: 'L', positions: ['P', 'CF'], jersey: 12, reportedVelo: 71 },
    private: { birthDate: '2012-09-03', school: 'Sample High School', emergencyName: 'App Review', emergencyPhone: '225-555-0100' },
  },
];

const batch = db.batch();
batch.set(db.doc(`users/${uid}`), {
  name: 'App Review',
  email,
  adultConfirmed: true,
  termsAcceptedAt: FieldValue.serverTimestamp(),
  createdAt: FieldValue.serverTimestamp(),
});
batch.set(db.doc(`userEmails/${email}`), { uid, name: 'App Review' });
for (const p of players) {
  const name = `${p.data.firstName} ${p.data.lastName.slice(0, 1)}.`;
  batch.set(db.doc(`players/${p.id}`), {
    ...p.data,
    guardianUids: [uid],
    state: 'LA',
    level: 'Travel',
    publicProfile: false,
    fullName: false,
    publicName: name,
    createdAt: FieldValue.serverTimestamp(),
  });
  batch.set(db.doc(`playerPrivate/${p.id}`), { ...p.private, guardianUids: [uid] });
}
await batch.commit();
console.log(`Demo account ready: ${email} with ${players.length} players.`);
