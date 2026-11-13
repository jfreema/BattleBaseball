// Seeds sample showcase results on battlebaseball-prod, so the app has
// something to show before the first real showcase: 16 players named after
// kids from TV shows, two past showcases (Summer and Fall 2026) with
// published radar readings, stat lines and awards, and public player cards.
// That fills the Showcases, Players and Leaders tabs, with at least five
// players on each board (fastball, home runs, pop time, 40 yard).
//
// Every document id starts with "seed-". Uses your gcloud sign-in and
// refuses every project but battlebaseball-prod:
//   npm --prefix tools/seed run showcase            (write, safe to rerun)
//   npm --prefix tools/seed run showcase -- --remove (delete it all)
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { Timestamp, getFirestore } from 'firebase-admin/firestore';

const projectId = 'battlebaseball-prod';
process.env.GOOGLE_CLOUD_QUOTA_PROJECT ||= projectId;
initializeApp({ projectId, credential: applicationDefault() });
const db = getFirestore();

const family = 'seed-family';
const collections = ['events', 'divisions', 'players', 'publicProfiles', 'registrations', 'measurements', 'statLines', 'awards'];

if (process.argv.includes('--remove')) {
  let n = 0;
  for (const c of collections) {
    const snap = await db.collection(c).get();
    for (const d of snap.docs.filter((d) => d.id.startsWith('seed-'))) {
      await d.ref.delete();
      n++;
    }
  }
  console.log(`Removed ${n} sample documents.`);
  process.exit(0);
}

const events = [
  { id: 'seed-summer-2026', name: 'Summer Showcase', start: new Date('2026-06-06T09:00:00-05:00') },
  { id: 'seed-fall-2026', name: 'Fall Showcase', start: new Date('2026-10-17T09:00:00-05:00') },
];

// fastball [summer, fall] in MPH; pop and dash in seconds (fall); hr [summer, fall].
const kids = [
  { id: 'luke', first: 'Luke', last: 'Dunphy', year: 2029, pos: ['SS', 'P'], bats: 'R', throws: 'R', jersey: 4, fb: [70, 73], dash: 5.21, hr: [1, 1] },
  { id: 'manny', first: 'Manny', last: 'Delgado', year: 2030, pos: ['P', '1B'], bats: 'R', throws: 'R', jersey: 18, fb: [69, 72], dash: 5.48, hr: [0, 1] },
  { id: 'bart', first: 'Bart', last: 'Simpson', year: 2031, pos: ['CF', 'P'], bats: 'L', throws: 'L', jersey: 10, fb: [64, 67], dash: 5.3, hr: [0, 0] },
  { id: 'dustin', first: 'Dustin', last: 'Henderson', year: 2030, pos: ['C', '3B'], bats: 'R', throws: 'R', jersey: 22, fb: [65, 68], pop: 2.08, dash: 5.66, hr: [1, 0] },
  { id: 'lucas', first: 'Lucas', last: 'Sinclair', year: 2030, pos: ['2B', 'SS'], bats: 'R', throws: 'R', jersey: 3, fb: [66, 69], dash: 5.05, hr: [0, 1] },
  { id: 'mike', first: 'Mike', last: 'Wheeler', year: 2030, pos: ['P', 'LF'], bats: 'R', throws: 'R', jersey: 11, fb: [68, 71], dash: 5.39, hr: [1, 1] },
  { id: 'will', first: 'Will', last: 'Byers', year: 2031, pos: ['RF', 'P'], bats: 'L', throws: 'L', jersey: 5, fb: [60, 63], dash: 5.58, hr: [0, 0] },
  { id: 'kevin', first: 'Kevin', last: 'Arnold', year: 2029, pos: ['CF', 'P'], bats: 'R', throws: 'R', jersey: 8, fb: [71, 74], dash: 4.98, hr: [1, 2] },
  { id: 'cory', first: 'Cory', last: 'Matthews', year: 2029, pos: ['C', '2B'], bats: 'R', throws: 'R', jersey: 7, fb: [66, 68], pop: 2.2, dash: 5.31, hr: [0, 0] },
  { id: 'shawn', first: 'Shawn', last: 'Hunter', year: 2029, pos: ['P', '3B'], bats: 'R', throws: 'R', jersey: 21, fb: [72, 76], dash: 5.12, hr: [2, 1] },
  { id: 'malcolm', first: 'Malcolm', last: 'Wilkerson', year: 2029, pos: ['C', '1B'], bats: 'R', throws: 'R', jersey: 13, fb: [67, 70], pop: 2.01, dash: 5.44, hr: [0, 2] },
  { id: 'reese', first: 'Reese', last: 'Wilkerson', year: 2029, pos: ['1B', 'P'], bats: 'L', throws: 'R', jersey: 33, fb: [73, 75], dash: 5.25, hr: [2, 2] },
  { id: 'dewey', first: 'Dewey', last: 'Wilkerson', year: 2032, pos: ['UT'], bats: 'R', throws: 'R', jersey: 1, fb: [57, 60], dash: 6.02, hr: [0, 0] },
  { id: 'jake', first: 'Jake', last: 'Harper', year: 2030, pos: ['C', 'P'], bats: 'R', throws: 'R', jersey: 26, fb: [64, 66], pop: 2.14, dash: 5.71, hr: [1, 0] },
  { id: 'ben', first: 'Ben', last: 'Seaver', year: 2031, pos: ['SS'], bats: 'R', throws: 'R', jersey: 2, fb: [61, 64], dash: 5.4, hr: [0, 0] },
  { id: 'theo', first: 'Theo', last: 'Huxtable', year: 2029, pos: ['C', 'RF'], bats: 'R', throws: 'R', jersey: 15, fb: [68, 70], pop: 1.98, dash: 5.35, hr: [1, 0] },
];

const division = (year) => ({ 2029: '14U', 2030: '13U', 2031: '12U', 2032: '11U' })[year];
const divisionOrder = ['11U', '12U', '13U', '14U'];
const awards = [
  ['seed-summer-2026', 'kevin', 'mvp'],
  ['seed-summer-2026', 'shawn', 'topPitcher'],
  ['seed-summer-2026', 'reese', 'topHitter'],
  ['seed-summer-2026', 'malcolm', 'eliteDefender'],
  ['seed-fall-2026', 'shawn', 'mvp'],
  ['seed-fall-2026', 'reese', 'topPitcher'],
  ['seed-fall-2026', 'kevin', 'topHitter'],
  ['seed-fall-2026', 'dustin', 'eliteDefender'],
  ['seed-fall-2026', 'bart', 'hustle'],
];

const writes = [];
const set = (path, data) => writes.push([db.doc(path), data]);

for (const e of events) {
  set(`events/${e.id}`, {
    name: e.name,
    status: 'final',
    city: 'Baton Rouge, LA',
    venue: 'BREC Central Sports Park',
    address: 'Baton Rouge, LA',
    start: Timestamp.fromDate(e.start),
    ageGroups: '11U to 14U',
    price: 85,
    skillsContest: true,
    hostTeam: '',
    raisingFor: '',
    description: '',
    resultsPublished: true,
    createdAt: Timestamp.fromDate(e.start),
  });
  divisionOrder.forEach((name, order) =>
    set(`divisions/${e.id}-${name}`, {
      eventId: e.id,
      name,
      capacity: 24,
      taken: kids.filter((k) => division(k.year) === name).length,
      order,
    }),
  );
}

for (const k of kids) {
  const id = `seed-${k.id}`;
  const publicName = `${k.first} ${k.last[0]}.`;
  const div = division(k.year);
  set(`players/${id}`, {
    firstName: k.first,
    lastName: k.last,
    guardianUids: [family],
    gradYear: k.year,
    bats: k.bats,
    throws: k.throws,
    positions: k.pos,
    state: 'LA',
    level: 'Travel',
    reportedVelo: null,
    publicProfile: true,
    fullName: false,
    jersey: k.jersey,
    publicName,
  });
  set(`publicProfiles/${id}`, {
    name: publicName,
    gradYear: k.year,
    positions: k.pos,
    bats: k.bats,
    throws: k.throws,
    state: 'LA',
    jersey: k.jersey,
    updatedAt: Timestamp.now(),
  });
  events.forEach((e, i) => {
    const shared = {
      eventId: e.id,
      eventName: e.name,
      playerId: id,
      publicName,
      playerPublic: true,
      divisionName: div,
      published: true,
    };
    const at = Timestamp.fromDate(e.start);
    set(`registrations/${e.id}_${id}`, {
      eventId: e.id,
      eventName: e.name,
      divisionId: `${e.id}-${div}`,
      divisionName: div,
      playerId: id,
      playerName: `${k.first} ${k.last}`,
      publicName,
      playerPublic: true,
      gradYear: k.year,
      guardianUid: family,
      guardianName: 'Sample family',
      status: 'checkedIn',
      paymentCode: 'BB-SEED',
      amount: 85,
      jersey: k.jersey,
      skillsOptIn: true,
      createdAt: at,
    });
    const reading = (type, value) =>
      set(`measurements/seed-${e.id}-${k.id}-${type}`, {
        ...shared,
        gradYear: k.year,
        type,
        value,
        recordedBy: 'seed',
        recordedAt: at,
      });
    reading('fastball', k.fb[i]);
    if (i === 1 && k.pop) reading('popTime', k.pop);
    if (i === 1 && k.dash) reading('dash40', k.dash);
    if (i === 0 && k.dash) reading('dash40', Math.round((k.dash + 0.12) * 100) / 100);
    const hr = k.hr[i];
    const ab = 4 + ((k.jersey + i) % 2);
    const h = Math.min(ab, hr + 1 + ((k.jersey + i) % 2));
    const pitches = k.pos.includes('P');
    set(`statLines/${e.id}_${id}`, {
      ...shared,
      gradYear: k.year,
      ab,
      h,
      hr,
      rbi: hr * 2 + ((k.jersey + i) % 3),
      r: hr + ((k.jersey + i) % 2),
      bb: (k.jersey + i) % 2,
      outs: pitches ? 6 + 3 * ((k.jersey + i) % 2) : 0,
      k: pitches ? 3 + ((k.fb[i] + i) % 4) : 0,
      pbb: pitches ? (k.jersey + i) % 3 : 0,
      recordedBy: 'seed',
      recordedAt: at,
    });
  });
}

for (const [eventId, kid, type] of awards) {
  const k = kids.find((x) => x.id === kid);
  const e = events.find((x) => x.id === eventId);
  set(`awards/seed-${eventId}-${kid}-${type}`, {
    eventId,
    eventName: e.name,
    playerId: `seed-${kid}`,
    publicName: `${k.first} ${k.last[0]}.`,
    playerPublic: true,
    divisionName: division(k.year),
    type,
    recordedBy: 'seed',
    published: true,
  });
}

for (let i = 0; i < writes.length; i += 400) {
  const batch = db.batch();
  for (const [ref, data] of writes.slice(i, i + 400)) batch.set(ref, data);
  await batch.commit();
}
console.log(`Wrote ${writes.length} sample documents (${kids.length} players, ${events.length} showcases).`);
