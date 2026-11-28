// Seeds sample showcase results on battlebaseball-prod, so the app has
// something to show before the first real showcase: 15 players named after
// kids from The Simpsons (five each aged 10, 12 and 13, so 10U, 12U and 14U),
// two past showcases (Summer and Fall 2026) with every player on the roster,
// published fastball and 40-yard dash readings, stat lines with home runs,
// awards, and public player cards. That fills each showcase's top fives and
// all nine Leaders boards (fastball, 40 yard and home runs in each age group).
//
// Every document id starts with "seed-". Each run first deletes every
// "seed-" document already there (including the earlier TV-show sample
// players), then writes these. Uses your gcloud sign-in and refuses every
// project but battlebaseball-prod:
//   npm --prefix tools/seed install                 (once)
//   npm --prefix tools/seed run showcase            (write, safe to rerun)
//   npm --prefix tools/seed run showcase -- --remove (delete it all)
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { Timestamp, getFirestore } from 'firebase-admin/firestore';

const projectId = 'battlebaseball-prod';
process.env.GOOGLE_CLOUD_QUOTA_PROJECT ||= projectId;
initializeApp({ projectId, credential: applicationDefault() });
const db = getFirestore();

const family = 'seed-family';
const collections = [
  'events',
  'divisions',
  'players',
  'playerPrivate',
  'publicProfiles',
  'registrations',
  'measurements',
  'statLines',
  'awards',
];

async function removeAll() {
  let n = 0;
  for (const c of collections) {
    const snap = await db.collection(c).get();
    const docs = snap.docs.filter((d) => d.id.startsWith('seed-'));
    for (let i = 0; i < docs.length; i += 400) {
      const batch = db.batch();
      for (const d of docs.slice(i, i + 400)) batch.delete(d.ref);
      await batch.commit();
    }
    n += docs.length;
  }
  return n;
}

const removed = await removeAll();
if (process.argv.includes('--remove')) {
  console.log(`Removed ${removed} sample documents.`);
  process.exit(0);
}

const events = [
  { id: 'seed-summer-2026', name: 'Summer Showcase', start: new Date('2026-06-06T09:00:00-05:00') },
  { id: 'seed-fall-2026', name: 'Fall Showcase', start: new Date('2026-10-17T09:00:00-05:00') },
];

// Birthdays fall between January and May, so each player is the same age at
// both showcases and today. Readings are [summer, fall]: fastball in MPH,
// 40-yard dash in seconds, home runs per showcase.
const kids = [
  // Age 10: 10U
  { id: 'bart', first: 'Bart', last: 'Simpson', born: '2016-04-01', pos: ['SS', 'P'], bats: 'R', throws: 'R', jersey: 10, fb: [52, 55], dash: [6.42, 6.31], hr: [1, 2] },
  { id: 'milhouse', first: 'Milhouse', last: 'Van Houten', born: '2016-03-14', pos: ['1B', 'RF'], bats: 'L', throws: 'L', jersey: 3, fb: [46, 47], dash: [7.08, 6.95], hr: [0, 0] },
  { id: 'martin', first: 'Martin', last: 'Prince', born: '2016-01-20', pos: ['2B', 'C'], bats: 'R', throws: 'R', jersey: 1, fb: [48, 50], dash: [6.88, 6.81], hr: [0, 1] },
  { id: 'ralph', first: 'Ralph', last: 'Wiggum', born: '2016-05-02', pos: ['LF', 'UT'], bats: 'S', throws: 'R', jersey: 14, fb: [44, 49], dash: [7.21, 6.99], hr: [1, 0] },
  { id: 'wendell', first: 'Wendell', last: 'Borton', born: '2016-02-11', pos: ['CF', 'P'], bats: 'R', throws: 'R', jersey: 22, fb: [51, 50], dash: [6.55, 6.6], hr: [0, 1] },
  // Age 12: 12U
  { id: 'nelson', first: 'Nelson', last: 'Muntz', born: '2014-02-08', pos: ['P', '3B'], bats: 'R', throws: 'R', jersey: 44, fb: [63, 66], dash: [6.05, 5.98], hr: [2, 1] },
  { id: 'rod', first: 'Rod', last: 'Flanders', born: '2014-04-22', pos: ['2B', 'SS'], bats: 'R', throws: 'R', jersey: 7, fb: [55, 57], dash: [6.21, 6.12], hr: [0, 0] },
  { id: 'lisa', first: 'Lisa', last: 'Simpson', born: '2014-05-09', pos: ['P', 'CF'], bats: 'L', throws: 'L', jersey: 8, fb: [59, 61], dash: [5.94, 5.89], hr: [1, 1] },
  { id: 'janey', first: 'Janey', last: 'Powell', born: '2014-01-30', pos: ['C', '1B'], bats: 'R', throws: 'R', jersey: 12, fb: [57, 56], dash: [6.33, 6.27], hr: [1, 0] },
  { id: 'uter', first: 'Uter', last: 'Zorker', born: '2014-03-17', pos: ['1B', 'LF'], bats: 'L', throws: 'R', jersey: 33, fb: [54, 58], dash: [6.71, 6.64], hr: [0, 2] },
  // Age 13: 14U
  { id: 'jimbo', first: 'Jimbo', last: 'Jones', born: '2013-03-03', pos: ['P', '1B'], bats: 'R', throws: 'R', jersey: 13, fb: [68, 71], dash: [5.62, 5.58], hr: [2, 3] },
  { id: 'dolph', first: 'Dolph', last: 'Starbeam', born: '2013-01-12', pos: ['SS', 'P'], bats: 'R', throws: 'R', jersey: 2, fb: [66, 67], dash: [5.41, 5.36], hr: [1, 1] },
  { id: 'kearney', first: 'Kearney', last: 'Zzyzwicz', born: '2013-04-28', pos: ['C', '3B'], bats: 'R', throws: 'R', jersey: 50, fb: [64, 69], dash: [5.88, 5.79], hr: [3, 1] },
  { id: 'sherri', first: 'Sherri', last: 'Mackleberry', born: '2013-05-19', pos: ['CF', 'P'], bats: 'L', throws: 'R', jersey: 5, fb: [62, 63], dash: [5.49, 5.52], hr: [0, 1] },
  { id: 'terri', first: 'Terri', last: 'Mackleberry', born: '2013-05-19', pos: ['RF', '2B'], bats: 'L', throws: 'R', jersey: 6, fb: [61, 64], dash: [5.55, 5.47], hr: [1, 0] },
];

const ageOn = (born, day) => {
  const b = new Date(`${born}T12:00:00`);
  let age = day.getFullYear() - b.getFullYear();
  if (day.getMonth() < b.getMonth() || (day.getMonth() === b.getMonth() && day.getDate() < b.getDate())) age--;
  return age;
};
const ageGroup = (age) => (age <= 10 ? '10U' : age <= 12 ? '12U' : '14U');
const ageGroupOrder = ['10U', '12U', '14U'];
// Out of high school the spring they turn 18.
const gradYear = (born) => Number(born.slice(0, 4)) + 18;
// The player form keeps birth dates as MM/DD/YYYY.
const formDate = (born) => `${born.slice(5, 7)}/${born.slice(8, 10)}/${born.slice(0, 4)}`;

const awards = [
  ['seed-summer-2026', 'jimbo', 'mvp'],
  ['seed-summer-2026', 'nelson', 'topPitcher'],
  ['seed-summer-2026', 'kearney', 'topHitter'],
  ['seed-summer-2026', 'martin', 'eliteDefender'],
  ['seed-summer-2026', 'ralph', 'hustle'],
  ['seed-fall-2026', 'bart', 'mvp'],
  ['seed-fall-2026', 'jimbo', 'topPitcher'],
  ['seed-fall-2026', 'uter', 'topHitter'],
  ['seed-fall-2026', 'dolph', 'eliteDefender'],
  ['seed-fall-2026', 'lisa', 'hustle'],
];

const writes = [];
const set = (path, data) => writes.push([db.doc(path), data]);

for (const e of events) {
  set(`events/${e.id}`, {
    name: e.name,
    status: 'final',
    city: 'Baton Rouge, LA',
    // A made-up park: these showcases never happened, so don't name a real one.
    venue: 'Cypress Hollow Ballpark',
    address: 'Baton Rouge, LA',
    start: Timestamp.fromDate(e.start),
    ageGroups: '10U, 12U and 14U',
    price: 85,
    skillsContest: false,
    hostTeam: '',
    raisingFor: '',
    description: '',
    resultsPublished: true,
    createdAt: Timestamp.fromDate(e.start),
  });
  ageGroupOrder.forEach((name, order) =>
    set(`divisions/${e.id}-${name}`, {
      eventId: e.id,
      name,
      capacity: 24,
      taken: kids.filter((k) => ageGroup(ageOn(k.born, e.start)) === name).length,
      order,
    }),
  );
}

for (const k of kids) {
  const id = `seed-${k.id}`;
  const name = `${k.first} ${k.last}`;
  const year = gradYear(k.born);
  set(`players/${id}`, {
    firstName: k.first,
    lastName: k.last,
    guardianUids: [family],
    gradYear: year,
    bats: k.bats,
    throws: k.throws,
    positions: k.pos,
    state: 'LA',
    level: 'Travel',
    reportedVelo: null,
    publicProfile: true,
    fullName: true,
    jersey: k.jersey,
    publicName: name,
  });
  set(`playerPrivate/${id}`, {
    birthDate: formDate(k.born),
    school: 'Springfield Elementary',
    emergencyName: 'Sample family',
    emergencyPhone: '225-555-0100',
    guardianUids: [family],
  });
  set(`publicProfiles/${id}`, {
    name,
    gradYear: year,
    positions: k.pos,
    bats: k.bats,
    throws: k.throws,
    state: 'LA',
    jersey: k.jersey,
    updatedAt: Timestamp.now(),
  });
  events.forEach((e, i) => {
    const div = ageGroup(ageOn(k.born, e.start));
    const at = Timestamp.fromDate(e.start);
    const shared = {
      eventId: e.id,
      eventName: e.name,
      playerId: id,
      publicName: name,
      playerPublic: true,
      divisionName: div,
      gradYear: year,
      published: true,
    };
    set(`registrations/${e.id}_${id}`, {
      eventId: e.id,
      eventName: e.name,
      divisionId: `${e.id}-${div}`,
      divisionName: div,
      playerId: id,
      playerName: name,
      publicName: name,
      playerPublic: true,
      gradYear: year,
      guardianUid: family,
      guardianName: 'Sample family',
      status: 'checkedIn',
      paidVia: 'staff',
      paymentCode: '',
      payerName: '',
      amount: null,
      jersey: k.jersey,
      skillsOptIn: false,
      alreadyPaid: false,
      addedBy: 'seed',
      createdAt: at,
    });
    const reading = (type, value) =>
      set(`measurements/seed-${e.id}-${k.id}-${type}`, {
        ...shared,
        type,
        value,
        recordedBy: 'seed',
        recordedAt: at,
      });
    reading('fastball', k.fb[i]);
    reading('dash40', k.dash[i]);
    const hr = k.hr[i];
    const ab = 4 + ((k.jersey + i) % 2);
    const h = Math.min(ab, hr + 1 + ((k.jersey + i) % 2));
    const pitches = k.pos.includes('P');
    set(`statLines/${e.id}_${id}`, {
      ...shared,
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
    publicName: `${k.first} ${k.last}`,
    playerPublic: true,
    divisionName: ageGroup(ageOn(k.born, e.start)),
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
console.log(
  `Removed ${removed} old sample documents, wrote ${writes.length} (${kids.length} players, ${events.length} showcases).`,
);
