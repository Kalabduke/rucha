(function (global) {
  'use strict';

  function mulberry32(a) {
    return function () {
      a |= 0; a = a + 0x6D2B79F5 | 0;
      let t = Math.imul(a ^ a >>> 15, 1 | a);
      t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
      return ((t ^ t >>> 14) >>> 0) / 4294967296;
    };
  }

  const EARTH_R = 6371.0088;
  const D2R = Math.PI / 180;
  function haversine(a, b) {
    const dLat = (b[0] - a[0]) * D2R, dLng = (b[1] - a[1]) * D2R;
    const la1 = a[0] * D2R, la2 = b[0] * D2R;
    const h = Math.sin(dLat / 2) ** 2 + Math.cos(la1) * Math.cos(la2) * Math.sin(dLng / 2) ** 2;
    return 2 * EARTH_R * Math.asin(Math.min(1, Math.sqrt(h)));
  }
  function catmull(p0, p1, p2, p3, t) {
    const t2 = t * t, t3 = t2 * t;
    return 0.5 * ((2 * p1) + (-p0 + p2) * t +
      (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
      (-p0 + 3 * p1 - 3 * p2 + p3) * t3);
  }

  function elevationAt(lat, lng, city) {
    const dyKm = (lat - city.lat) * 110.574;
    const dxKm = (lng - city.lng) * 111.320 * Math.cos(city.lat * D2R);
    const ridge = city.eleSlope * dyKm;
    const roll = 26 * Math.sin(dxKm * 0.42 + dyKm * 0.18) + 14 * Math.cos(dxKm * 0.17);
    const entotoBump = 180 * Math.exp(-((dxKm * dxKm) / (2 * 6.5 * 6.5) + ((dyKm - 9.4) ** 2) / (2 * 5 * 5)));
    return city.baseEle + ridge + roll + entotoBump;
  }

  function scaleAnchors(anchors, targetKm) {
    let total = 0;
    for (let i = 1; i < anchors.length; i++) total += haversine(anchors[i - 1], anchors[i]);
    if (total < 0.01) return anchors;
    const f = targetKm / total;
    let cLat = 0, cLng = 0;
    anchors.forEach(a => { cLat += a[0]; cLng += a[1]; });
    cLat /= anchors.length; cLng /= anchors.length;
    return anchors.map(a => [cLat + (a[0] - cLat) * f, cLng + (a[1] - cLng) * f]);
  }

  function buildTrack(anchors, seed, opts) {
    opts = opts || {};
    const city = opts.city || CITIES.addis;
    const rand = mulberry32(seed);
    const per = opts.per || 16;
    const jitter = opts.jitter === undefined ? 0.000055 : opts.jitter;
    const raw = [];
    for (let i = 0; i < anchors.length - 1; i++) {
      const p0 = anchors[Math.max(0, i - 1)], p1 = anchors[i];
      const p2 = anchors[i + 1], p3 = anchors[Math.min(anchors.length - 1, i + 2)];
      for (let s = 0; s < per; s++) {
        const t = s / per;
        raw.push([
          catmull(p0[0], p1[0], p2[0], p3[0], t) + (rand() - 0.5) * jitter,
          catmull(p0[1], p1[1], p2[1], p3[1], t) + (rand() - 0.5) * jitter
        ]);
      }
    }
    raw.push([anchors[anchors.length - 1][0], anchors[anchors.length - 1][1]]);

    let d = 0;
    const track = raw.map((p, i) => {
      if (i > 0) d += haversine(raw[i - 1], p);
      return {
        lat: p[0], lng: p[1],
        ele: Math.round(elevationAt(p[0], p[1], city) + (rand() - 0.5) * 7),
        d: d
      };
    });
    return track;
  }

  function elevationGain(track) {
    let g = 0;
    for (let i = 1; i < track.length; i++) {
      const delta = track[i].ele - track[i - 1].ele;
      if (delta > 0) g += delta;
    }
    return Math.round(g);
  }

  const CITIES = {
    addis:    { id: 'addis',    name: 'Addis Ababa', lat: 9.0320, lng: 38.7469, viewLat: 9.0450, baseEle: 2355, eleSlope: 92, scale: 7000, tag: 'Capital · 2,355 m' },
    entoto:   { id: 'entoto',   name: 'Entoto Hills',     lat: 9.1050, lng: 38.7520, baseEle: 2980, eleSlope: 60,  scale: 10500, tag: 'High-altitude trails' },
    bishoftu: { id: 'bishoftu', name: 'Bishoftu',     lat: 8.7380, lng: 38.9850, baseEle: 1900, eleSlope: 18,  scale: 9800,  tag: 'Crater lakes' },
    hawassa:  { id: 'hawassa',  name: 'Hawassa',       lat: 7.0621, lng: 38.4765, baseEle: 1708, eleSlope: 14,  scale: 8200,  tag: 'Lakeside' },
    bahirdar: { id: 'bahirdar', name: 'Bahir Dar',   lat: 11.5742,lng: 37.3614, baseEle: 1800, eleSlope: 12,  scale: 8200,  tag: 'Lake Tana' },
    gondar:   { id: 'gondar',   name: 'Gondar',     lat: 12.6000,lng: 37.4667, baseEle: 2133, eleSlope: 30,  scale: 8200,  tag: 'Highlands' },
    mekelle:  { id: 'mekelle',  name: 'Mekelle',       lat: 13.4967,lng: 39.4753, baseEle: 2084, eleSlope: 22,  scale: 8200,  tag: 'Tigray highlands' },
    harar:    { id: 'harar',    name: 'Harar',       lat: 9.3139, lng: 42.1181, baseEle: 1885, eleSlope: 20,  scale: 9200,  tag: 'Eastern hills' }
  };

  const LANDMARKS = {
    addis: [
      { name: 'Meskel Square',   lat: 9.0107, lng: 38.7610, kind: 'square' },
      { name: 'Africa Hall / UNECA',     lat: 9.0140, lng: 38.7520, kind: 'building' },
      { name: 'Unity Park',     lat: 9.0130, lng: 38.7540, kind: 'park' },
      { name: 'Addis Ababa Univ.', lat: 9.0470, lng: 38.7570, kind: 'building' },
      { name: 'National Museum',     lat: 9.0380, lng: 38.7530, kind: 'building' },
      { name: 'Mercato',           lat: 9.0290, lng: 38.7350, kind: 'market' },
      { name: 'Piassa',             lat: 9.0360, lng: 38.7500, kind: 'square' },
      { name: 'Kazanchis',         lat: 9.0200, lng: 38.7620, kind: 'district' },
      { name: 'Megenagna',           lat: 9.0300, lng: 38.8100, kind: 'square' },
      { name: 'Bole Airport',     lat: 8.9779, lng: 38.7993, kind: 'building' },
      { name: 'Friendship Park',     lat: 8.9960, lng: 38.7570, kind: 'park' },
      { name: 'Saris',             lat: 8.9600, lng: 38.7400, kind: 'district' },
      { name: 'Entoto Maryam',     lat: 9.1150, lng: 38.7550, kind: 'peak' },
      { name: 'Entoto Natural Park',       lat: 9.1000, lng: 38.7300, kind: 'park' },
      { name: 'Akaki',             lat: 8.8700, lng: 38.7800, kind: 'district' }
    ],
    entoto: [
      { name: 'Entoto Maryam', lat: 9.1150, lng: 38.7550, kind: 'peak' },
      { name: 'Entoto Natural Park',   lat: 9.1000, lng: 38.7300, kind: 'park' },
      { name: 'Mount Entoto Summit',   lat: 9.1210, lng: 38.7460, kind: 'peak' },
      { name: 'Sidist Kilo',     lat: 9.0470, lng: 38.7570, kind: 'district' }
    ],
    bishoftu: [
      { name: 'Lake Bishoftu',   lat: 8.7410, lng: 38.9870, kind: 'water' },
      { name: 'Lake Hora',     lat: 8.7620, lng: 38.9920, kind: 'water' },
      { name: 'Bishoftu Town',   lat: 8.7380, lng: 38.9850, kind: 'district' },
      { name: 'Debre Zeit AFB',     lat: 8.7200, lng: 38.9700, kind: 'building' }
    ],
    hawassa: [
      { name: 'Lake Hawassa', lat: 7.0500, lng: 38.4800, kind: 'water' },
      { name: 'Amora Gedel', lat: 7.0400, lng: 38.4900, kind: 'park' }
    ],
    bahirdar: [
      { name: 'Lake Tana',   lat: 11.6100, lng: 37.3800, kind: 'water' },
      { name: 'Blue Nile Falls', lat: 11.4900, lng: 37.4100, kind: 'peak' }
    ],
    gondar:  [{ name: 'Fasil Ghebbi', lat: 12.6060, lng: 37.4700, kind: 'building' }],
    mekelle: [{ name: 'Mekelle Centre', lat: 13.4967, lng: 39.4753, kind: 'square' }],
    harar:   [{ name: 'Jugol Wall', lat: 9.3110, lng: 42.1200, kind: 'building' }]
  };

  const ATHLETES = [
    { id: 'u0', name: 'Dawit Tesfaye',     handle: '@dawit.runs',  city: 'Addis Ababa', initials: 'DT' },
    { id: 'u1', name: 'Mekdes Alemu',      handle: '@mekdes',      city: 'Entoto',      initials: 'MA' },
    { id: 'u2', name: 'Yonas Bekele',      handle: '@yonas_b',     city: 'Bishoftu',    initials: 'YB' },
    { id: 'u3', name: 'Hanna Girma',       handle: '@hannag',      city: 'Addis Ababa', initials: 'HG' },
    { id: 'u4', name: 'Samuel Kebede',     handle: '@samk',        city: 'Hawassa',     initials: 'SK' },
    { id: 'u5', name: 'Selamawit Haile',   handle: '@selam',       city: 'Addis Ababa', initials: 'SH' },
    { id: 'u6', name: 'Abel Tadesse',      handle: '@abelt',       city: 'Bahir Dar',   initials: 'AT' },
    { id: 'u7', name: 'Ruth Mengistu',     handle: '@ruthm',       city: 'Gondar',      initials: 'RM' },
    { id: 'u8', name: 'Fikadu Worku',      handle: '@fikadu',      city: 'Mekelle',     initials: 'FW' },
    { id: 'u9', name: 'Bethelhem Assefa',  handle: '@betty',       city: 'Harar',       initials: 'BA' },
    { id: 'me', name: 'You',               handle: '@you',         city: 'Addis Ababa', initials: 'ME', me: true }
  ];

  const PALETTE = ['#FF6B35', '#12A88A', '#F2B705', '#5B8DEF', '#E2557B', '#8B5CF6', '#20B2AA', '#EF8354'];
  function avatarColor(id) {
    let h = 0;
    for (let i = 0; i < id.length; i++) h = (h * 31 + id.charCodeAt(i)) | 0;
    return PALETTE[Math.abs(h) % PALETTE.length];
  }

  function gainFromTrack(track) {
    let g = 0;
    const threshold = 3;   // metres; GPS altitude is noisy, ignore smaller wiggles
    let last = track.length ? track[0].ele : 0;
    for (let i = 1; i < track.length; i++) {
      const delta = track[i].ele - last;
      if (delta > threshold) { g += delta; last = track[i].ele; }
      else if (delta < -threshold) { last = track[i].ele; }
    }
    return Math.round(g);
  }
  function paceFor(distanceKm, durationSec) {
    if (distanceKm < 0.02 || durationSec <= 0) return 0;
    return durationSec / distanceKm;
  }
  function caloriesFor(distanceKm, durationSec, gainM, type) {
    if (durationSec <= 0 || distanceKm <= 0) return 0;
    const speedKmh = (distanceKm / durationSec) * 3600;
    const s = speedKmh * 1000 / 60;                
    const grade = Math.min(0.12, (gainM / 1000) / Math.max(distanceKm, 0.1));
    let vo2;
    if (type === 'ride') vo2 = 3.5 + 0.18 * s + 0.9 * s * grade * 0.5;
    else vo2 = 0.2 * s + 0.9 * s * grade + 3.5;
    const met = clampNum(vo2 / 3.5, type === 'ride' ? 3 : 4, 20);
    const weightKg = 68;
    return Math.max(0, Math.round(met * weightKg * (durationSec / 3600)));
  }
  function clampNum(v, a, b) { return Math.max(a, Math.min(b, v)); }

  const ROUTE_COLORS = ['#E8582B', '#0E8A6A', '#2F6FED', '#C0357B', '#B8860B', '#7A4FD1', '#0E9AA7', '#D14B2A', '#3C7A2E', '#A8551C'];
  function routeColor(a) {
    if (a.lineColor) return a.lineColor;
    let h = 0; const id = String(a.id || a.title || 'x');
    for (let i = 0; i < id.length; i++) h = (h * 31 + id.charCodeAt(i)) | 0;
    return ROUTE_COLORS[Math.abs(h) % ROUTE_COLORS.length];
  }

  function liveTrackAround(lat, lng, seed) {
    const city = CITIES.addis;
    const rand = mulberry32(seed || 4242);
    const anchors = [], N = 26;
    for (let i = 0; i <= N; i++) {
      const ang = (i / N) * Math.PI * 2;
      const r = 0.014 * (0.72 + 0.28 * Math.sin(ang * 3 + 0.6));
      anchors.push([
        lat + r * Math.sin(ang) * 0.82 + (rand() - 0.5) * 0.0012,
        lng + r * Math.cos(ang) + (rand() - 0.5) * 0.0012
      ]);
    }
    anchors.push(anchors[0]);
    return buildTrack(anchors, seed || 4242, { city: city, per: 10, jitter: 0.00003 });
  }

  function daysAgo(n, h, m) {
    const d = new Date();
    d.setDate(d.getDate() - n);
    d.setHours(h === undefined ? 6 : h, m === undefined ? 40 : m, 0, 0);
    return d;
  }

  const DEFS = [
    {
      id: 'a1', title: 'Sunrise on Entoto Hill', type: 'run', user: 'u0', city: 'addis',
      km: 14.2, secPerKm: 322, hr: 158, days: 0, hour: 6, minute: 12, seed: 101, kudos: 84, comments: 12,
      note: 'Legs felt light today. The last 2 km up to Entoto Maryam never gets easier.',
      anchors: [[9.0200,38.7620],[9.0350,38.7580],[9.0470,38.7570],[9.0680,38.7540],[9.0880,38.7510],[9.1080,38.7530],[9.1150,38.7550],[9.1000,38.7400],[9.0800,38.7420],[9.0550,38.7480],[9.0350,38.7550],[9.0200,38.7620]],
      tags: ['Hill repeats', 'Altitude']
    },
    {
      id: 'a2', title: 'Bishoftu Lake Circuit', type: 'ride', user: 'u2', city: 'bishoftu',
      km: 32.6, secPerKm: 118, hr: 141, days: 0, hour: 7, minute: 30, seed: 202, kudos: 61, comments: 8,
      note: 'Glassy water at 6am. Three laps then coffee in town.',
      anchors: [[8.7380,38.9850],[8.7450,38.9910],[8.7520,38.9950],[8.7590,38.9900],[8.7600,38.9800],[8.7530,38.9730],[8.7440,38.9720],[8.7370,38.9780],[8.7380,38.9850]],
      tags: ['Endurance', 'Flat & fast']
    },
    {
      id: 'a3', title: 'Meskel Square Loop', type: 'run', user: 'u5', city: 'addis',
      km: 8.6, secPerKm: 298, hr: 150, days: 1, hour: 6, minute: 5, seed: 303, kudos: 47, comments: 6,
      note: 'City still asleep. Best 8 km of the week.',
      anchors: [[9.0107,38.7610],[9.0140,38.7520],[9.0200,38.7620],[9.0100,38.7700],[9.0000,38.7640],[9.0010,38.7530],[9.0107,38.7610]],
      tags: ['Tempo', 'City loop']
    },
    {
      id: 'a4', title: 'Kazanchis → Saris Long Run', type: 'run', user: 'me', city: 'addis',
      km: 21.3, secPerKm: 336, hr: 155, days: 2, hour: 5, minute: 50, seed: 404, kudos: 112, comments: 19,
      note: 'Long slow distance. Fueled with a banana and a lot of hills.',
      anchors: [[9.0200,38.7620],[9.0100,38.7580],[8.9980,38.7520],[8.9860,38.7490],[8.9720,38.7420],[8.9600,38.7400],[8.9720,38.7520],[8.9880,38.7600],[9.0030,38.7660],[9.0200,38.7620]],
      tags: ['Long run', 'PR attempt']
    },
    {
      id: 'a5', title: 'Entoto Natural Park Trail', type: 'run', user: 'u1', city: 'entoto',
      km: 11.8, secPerKm: 388, hr: 162, days: 2, hour: 8, minute: 20, seed: 505, kudos: 73, comments: 11,
      note: 'Eucalyptus mist, 3,000 m, zero signal. Perfect.',
      anchors: [[9.1000,38.7300],[9.1060,38.7380],[9.1140,38.7460],[9.1210,38.7460],[9.1180,38.7580],[9.1080,38.7600],[9.1000,38.7500],[9.0960,38.7380],[9.1000,38.7300]],
      tags: ['Trail', 'Offline map']
    },
    {
      id: 'a6', title: 'Bole Road Tempo', type: 'run', user: 'u3', city: 'addis',
      km: 10.1, secPerKm: 276, hr: 168, days: 3, hour: 6, minute: 25, seed: 606, kudos: 39, comments: 4,
      note: 'Negative split. Felt strong at 2,300 m.',
      anchors: [[8.9779,38.7993],[8.9850,38.7900],[8.9930,38.7820],[9.0010,38.7720],[9.0107,38.7610],[9.0020,38.7700],[8.9900,38.7860],[8.9779,38.7993]],
      tags: ['Tempo', 'Negative split']
    },
    {
      id: 'a7', title: 'Africa Hall Commute Ride', type: 'ride', user: 'u6', city: 'addis',
      km: 9.4, secPerKm: 142, hr: 128, days: 4, hour: 7, minute: 45, seed: 707, kudos: 28, comments: 3,
      note: 'Two wheels beats the taxi every single time.',
      anchors: [[9.0290,38.7350],[9.0330,38.7450],[9.0300,38.7550],[9.0200,38.7620],[9.0140,38.7520],[9.0290,38.7350]],
      tags: ['Commute']
    },
    {
      id: 'a8', title: 'Unity Park Easy Shakeout', type: 'run', user: 'u7', city: 'addis',
      km: 5.2, secPerKm: 352, hr: 132, days: 5, hour: 7, minute: 10, seed: 808, kudos: 22, comments: 2,
      note: 'Recovery day with the club.',
      anchors: [[9.0130,38.7540],[9.0107,38.7610],[9.0180,38.7650],[9.0220,38.7570],[9.0160,38.7500],[9.0130,38.7540]],
      tags: ['Recovery']
    },
    {
      id: 'a9', title: 'Megenagna Hills', type: 'run', user: 'u4', city: 'addis',
      km: 12.7, secPerKm: 318, hr: 156, days: 6, hour: 6, minute: 30, seed: 909, kudos: 55, comments: 7,
      note: 'Rolling hills, cool morning, good company.',
      anchors: [[9.0300,38.8100],[9.0380,38.8000],[9.0420,38.7860],[9.0350,38.7720],[9.0200,38.7620],[9.0240,38.7840],[9.0280,38.8000],[9.0300,38.8100]],
      tags: ['Hills']
    },
    {
      id: 'a10', title: 'Hawassa Lakeside Sunrise', type: 'ride', user: 'u8', city: 'hawassa',
      km: 24.8, secPerKm: 126, hr: 137, days: 7, hour: 6, minute: 40, seed: 1001, kudos: 44, comments: 5,
      note: 'Pelicans on the left, coffee stops on the right.',
      anchors: [[7.0621,38.4765],[7.0550,38.4830],[7.0480,38.4900],[7.0420,38.4820],[7.0460,38.4700],[7.0560,38.4670],[7.0621,38.4765]],
      tags: ['Endurance']
    },
    {
      id: 'a11', title: 'Piassa to Mercato Recovery', type: 'run', user: 'u9', city: 'addis',
      km: 6.4, secPerKm: 361, hr: 130, days: 8, hour: 7, minute: 5, seed: 1102, kudos: 19, comments: 2,
      note: 'Easy miles before the market wakes up.',
      anchors: [[9.0360,38.7500],[9.0330,38.7440],[9.0290,38.7350],[9.0240,38.7400],[9.0280,38.7480],[9.0360,38.7500]],
      tags: ['Recovery']
    }
  ];

  const ACTIVITIES = DEFS.map(d => {
    const city = CITIES[d.city] || CITIES.addis;
    const anchors = scaleAnchors(d.anchors, d.km);
    const track = buildTrack(anchors, d.seed, { city: city, per: 18 });
    const distance = track[track.length - 1].d;
    const duration = Math.round(distance * d.secPerKm);
    const gain = elevationGain(track);
    return Object.assign({}, d, {
      cityObj: city, anchors: anchors, track: track,
      distance: distance, duration: duration, gain: gain,
      date: daysAgo(d.days, d.hour, d.minute),
      athlete: ATHLETES.find(a => a.id === d.user),
      calories: caloriesFor(distance, duration, gain, d.type),
      pace: d.secPerKm,
      startLat: track[0].lat, startLng: track[0].lng,
      endLat: track[track.length - 1].lat, endLng: track[track.length - 1].lng,
      hrSource: 'none', gpsAccuracyM: 0
    });
  });

  const SEGMENTS = [
    { id: 's1', name: 'Entoto Hill Climb',       city: 'addis', km: 6.8, gain: 612, cat: 'HC', type: 'run',  attempts: 4821, leader: 'u1', bestSec: 1542, crown: 'u0', startLat: 9.0470, startLng: 38.7570, endLat: 9.1150, endLng: 38.7550 },
    { id: 's2', name: 'Meskel Square Straight',       city: 'addis', km: 1.2, gain: 4,   cat: '4',  type: 'run',  attempts: 9120, leader: 'u3', bestSec: 205,  crown: 'me', startLat: 9.0107, startLng: 38.7610, endLat: 9.0140, endLng: 38.7520 },
    { id: 's3', name: 'Bole Road Flyer',         city: 'addis', km: 2.4, gain: 12,  cat: '3',  type: 'ride', attempts: 3310, leader: 'u6', bestSec: 248,  crown: null, startLat: 8.9779, startLng: 38.7993, endLat: 9.0107, endLng: 38.7610 },
    { id: 's4', name: 'Saris Rise',         city: 'addis', km: 3.1, gain: 96,  cat: '2',  type: 'run',  attempts: 2740, leader: 'u0', bestSec: 648,  crown: 'u0', startLat: 8.9600, startLng: 38.7400, endLat: 9.0107, endLng: 38.7610 },
    { id: 's5', name: 'Bishoftu Lake Circuit',       city: 'bishoftu', km: 12.6, gain: 42, cat: '3', type: 'ride', attempts: 1890, leader: 'u2', bestSec: 1420, crown: 'u2', startLat: 8.7380, startLng: 38.9850, endLat: 8.7410, endLng: 38.9870 },
    { id: 's6', name: 'Unity Park 400',   city: 'addis', km: 0.4, gain: 1,   cat: '5',  type: 'run',  attempts: 6402, leader: 'u5', bestSec: 66,   crown: 'me', startLat: 9.0130, startLng: 38.7540, endLat: 9.0160, endLng: 38.7570 }
  ];
  const LEADERS = SEGMENTS.reduce((acc, s) => {
    const rand = mulberry32(s.bestSec * 7);
    const pool = ATHLETES.filter(a => !a.me);
    const rows = [];
    for (let i = 0; i < 6; i++) {
      const u = pool[(i * 3 + s.bestSec) % pool.length];
      rows.push({ user: u, sec: Math.round(s.bestSec * (1 + i * 0.031 + rand() * 0.012)) });
    }
    rows.sort((a, b) => a.sec - b.sec);
    acc[s.id] = rows;
    return acc;
  }, {});

  const PLACES = Object.keys(LANDMARKS).reduce((out, cid) => {
    (LANDMARKS[cid] || []).forEach(l => out.push({
      name: l.name, lat: l.lat, lng: l.lng, kind: l.kind,
      city: (CITIES[cid] || {}).name || cid
    }));
    return out;
  }, []);

  function nearestPlace(lat, lng) {
    let best = Infinity, name = 'Open country', city = 'Ethiopia';
    for (const p of PLACES) {
      const d = haversine([lat, lng], [p.lat, p.lng]);
      if (d < best) { best = d; name = p.name; city = p.city; }
    }
    return { name: name, city: city, distanceKm: best };
  }
  function fmtCoord(lat, lng) {
    return Math.abs(lat).toFixed(5) + '° ' + (lat >= 0 ? 'N' : 'S') + ', ' +
           Math.abs(lng).toFixed(5) + '° ' + (lng >= 0 ? 'E' : 'W');
  }
  function startOf(a) {
    if (a.startLat != null && a.startLng != null) return { lat: a.startLat, lng: a.startLng };
    if (a.track && a.track.length) return { lat: a.track[0].lat, lng: a.track[0].lng };
    return { lat: CITIES.addis.lat, lng: CITIES.addis.lng };
  }

  const COMMUNITY_RUN_STARTS = [
    [9.0107, 38.7610], [9.0107, 38.7610], [9.0107, 38.7610], [9.0107, 38.7610],
    [9.0130, 38.7540], [9.0130, 38.7540], [9.0130, 38.7540],
    [9.1000, 38.7300], [9.1150, 38.7550],
    [8.9779, 38.7993], [9.0200, 38.7620], [8.7380, 38.9850]
  ];

  function popularAreas(activities) {
    const cells = new Map();
    const add = (lat, lng) => {
      const la = Math.round(lat * 1000) / 1000, ln = Math.round(lng * 1000) / 1000;
      const k = la.toFixed(3) + ',' + ln.toFixed(3);
      if (!cells.has(k)) cells.set(k, { lat: la, lng: ln, count: 0 });
      cells.get(k).count++;
    };
    COMMUNITY_RUN_STARTS.forEach(p => add(p[0], p[1]));
    (activities || []).forEach(a => {
      const s = startOf(a);
      add(s.lat, s.lng);
    });
    const out = [];
    cells.forEach(c => {
      const np = nearestPlace(c.lat, c.lng);
      out.push({ lat: c.lat, lng: c.lng, runCount: c.count, name: np.name, city: np.city });
    });
    out.sort((a, b) => b.runCount - a.runCount || a.name.localeCompare(b.name));
    return out;
  }

  function hallOfFame() {
    const names = ['Selam Tesfaye', 'Dawit Bekele', 'Marta Lemma', 'Yonas Girma', 'Hana Alemu', 'Abel Tadesse'];
    return SEGMENTS.map((s, i) => {
      const np = nearestPlace(s.startLat, s.startLng);
      return {
        segmentId: s.id, segmentName: s.name, athleteName: names[i % names.length],
        seconds: s.bestSec, startLat: s.startLat, startLng: s.startLng,
        placeName: np.name, city: np.city
      };
    });
  }

  const CLUBS = [
    { id: 'c1', name: 'Entoto Trail Runners', members: 1284, city: 'Addis Ababa', type: 'run',  joined: true,  color: '#12A88A', desc: 'Weekly sunrise trails on the Entoto ridge. All paces welcome.' },
    { id: 'c2', name: 'Addis Ababa Run Club', members: 3920, city: 'Addis Ababa', type: 'run',  joined: true,  color: '#FF6B35', desc: 'The biggest running community in the city. Tuesday tempo, Sunday long.' },
    { id: 'c3', name: 'Bole Wheelers', members: 842,  city: 'Addis Ababa', type: 'ride', joined: false, color: '#5B8DEF', desc: 'Road rides, café stops, and no one gets dropped.' },
    { id: 'c4', name: 'Bishoftu Lake Riders', members: 615,  city: 'Bishoftu',    type: 'ride', joined: false, color: '#F2B705', desc: 'Crater lake laps every Saturday at 6:30.' },
    { id: 'c5', name: 'Sidist Kilo Striders', members: 1106, city: 'Addis Ababa', type: 'run',  joined: false, color: '#8B5CF6', desc: 'Altitude-made speed. Track nights at the university.' }
  ];

  const CHALLENGES = [
    { id: 'h1', name: 'Meskerem 100',   goal: 100, unit: 'km',  joined: 8421, daysLeft: 12, progress: 68.4, icon: 'sun',    color: '#F2B705', prize: '2,000 Br', desc: 'Run 100 km in the Ethiopian New Year month. Enkutatash edition.' },
    { id: 'h2', name: 'Entoto Ascent',   goal: 3000, unit: 'm', joined: 3180, daysLeft: 19, progress: 2140, icon: 'mountain', color: '#12A88A', prize: '1,500 Br', desc: 'Climb 3,000 vertical metres. Every hill counts.' },
    { id: 'h3', name: 'Addis to Lalibela', goal: 780, unit: 'km', joined: 12640, daysLeft: 25, progress: 512.7, icon: 'route', color: '#FF6B35', prize: '5,000 Br', desc: 'A community relay across 780 km of highland road.' },
    { id: 'h4', name: 'Golden Hour 10K', goal: 1, unit: '10K', joined: 5602, daysLeft: 6,  progress: 1, icon: 'bolt', color: '#5B8DEF', prize: '750 Br', desc: 'Log your fastest 10K before 7:00 in the morning.' }
  ];

  const SEED_CHALLENGES = [
    { id: 'ch1', kind: 'route', title: 'Meskel Square to Entoto Maryam', description: 'Climb from the city centre to the Entoto ridge. Start at the square, finish at the church.', startLat: 9.0107, startLng: 38.7610, startName: 'Meskel Square', endLat: 9.1150, endLng: 38.7550, endName: 'Entoto Maryam', targetKm: 12.4, targetSeconds: 0, targetElevationM: 0, segmentId: '', geofenceM: 50, prizeBr: 2000, members: 8421, joined: false, createdBy: 'RUCHA', endsAt: '' },
    { id: 'ch2', kind: 'distance_time', title: 'Golden Hour 10K', description: 'Log your fastest 10 km before 07:00. Run it anywhere.', startLat: null, startLng: null, startName: '', endLat: null, endLng: null, endName: '', targetKm: 10, targetSeconds: 3600, targetElevationM: 0, segmentId: '', geofenceM: 0, prizeBr: 750, members: 5602, joined: false, createdBy: 'RUCHA', endsAt: '' },
    { id: 'ch3', kind: 'elevation', title: 'Entoto Ascent 3000', description: 'Climb 3,000 vertical metres. Every hill counts.', startLat: null, startLng: null, startName: '', endLat: null, endLng: null, endName: '', targetKm: 0, targetSeconds: 0, targetElevationM: 3000, segmentId: '', geofenceM: 0, prizeBr: 1500, members: 3180, joined: false, createdBy: 'RUCHA', endsAt: '' },
    { id: 'ch4', kind: 'streak', title: '7-Day Sunrise Streak', description: 'Run at least 3 km before sunrise, seven days in a row.', startLat: null, startLng: null, startName: '', endLat: null, endLng: null, endName: '', targetKm: 3, targetSeconds: 0, targetElevationM: 0, segmentId: '', geofenceM: 0, prizeBr: 1000, members: 4210, joined: false, createdBy: 'RUCHA', endsAt: '' },
    { id: 'ch5', kind: 'weekly', title: 'Meskerem 100', description: 'Cover 100 km during the Ethiopian New Year month.', startLat: null, startLng: null, startName: '', endLat: null, endLng: null, endName: '', targetKm: 100, targetSeconds: 0, targetElevationM: 0, segmentId: '', geofenceM: 0, prizeBr: 2000, members: 8421, joined: false, createdBy: 'RUCHA', endsAt: '' },
    { id: 'ch6', kind: 'segment_sprint', title: 'Unity Park 400 Crown', description: 'Take the crown on the Unity Park 400 segment.', startLat: 9.0130, startLng: 38.7540, startName: 'Unity Park', endLat: 9.0160, endLng: 38.7570, endName: 'Unity Park Straight', targetKm: 0.4, targetSeconds: 0, targetElevationM: 0, segmentId: 's6', geofenceM: 50, prizeBr: 500, members: 6402, joined: false, createdBy: 'RUCHA', endsAt: '' },
    { id: 'ch7', kind: 'relay', title: 'Addis to Lalibela Relay', description: 'A community relay across 780 km of highland road.', startLat: null, startLng: null, startName: '', endLat: null, endLng: null, endName: '', targetKm: 780, targetSeconds: 0, targetElevationM: 0, segmentId: '', geofenceM: 0, prizeBr: 5000, members: 12640, joined: false, createdBy: 'RUCHA', endsAt: '' }
  ];

  const CHALLENGE_KINDS = [
    { id: 'route', label: 'Point-to-point route', icon: 'route', color: '#E8582B', needsRoute: true, blurb: 'Pick a start and destination on the map. Recording can only begin at the start point.' },
    { id: 'distance_time', label: 'Distance / time trial', icon: 'clock', color: '#2F6FED', needsKm: true, needsTime: true, blurb: 'Enter the kilometres and a target time. Run it anywhere — no fixed location.' },
    { id: 'elevation', label: 'Vertical challenge', icon: 'mountain', color: '#0E8A6A', needsElev: true, blurb: 'Climb a set number of vertical metres. Every hill counts.' },
    { id: 'streak', label: 'Streak', icon: 'flame', color: '#C0357B', needsKm: true, blurb: 'Run a minimum distance every single day to keep the streak alive.' },
    { id: 'weekly', label: 'Weekly distance goal', icon: 'calendar', color: '#B8860B', needsKm: true, blurb: 'Cover a set distance within the week, at your own pace.' },
    { id: 'segment_sprint', label: 'Segment sprint', icon: 'bolt', color: '#7A4FD1', needsRoute: true, blurb: 'Fastest time on a short marked segment. Start at the marked point.' },
    { id: 'relay', label: 'Community relay', icon: 'users', color: '#0E9AA7', needsKm: true, blurb: 'Add your kilometres to a shared community total.' },
    { id: 'fartlek', label: 'Fartlek Friday', icon: 'bolt', color: '#EF8354', needsKm: true, blurb: 'Mix fast surges and easy recovery over a set distance. Run anywhere.' },
    { id: 'vertical', label: 'Vertical Kilometre', icon: 'arrowUp', color: '#0E8A6A', needsElev: true, blurb: 'Gain 1,000 m of elevation in one outing. Pure climbing.' },
    { id: 'consistency', label: '30-Day Consistency', icon: 'check', color: '#2F6FED', needsKm: true, blurb: 'Log at least one run a day for 30 days straight.' },
    { id: 'explorer', label: 'New Roads Explorer', icon: 'map', color: '#B8860B', needsKm: true, blurb: 'Run routes you have never recorded before.' },
    { id: 'buddy', label: 'Buddy Mile', icon: 'community', color: '#C0357B', needsKm: true, blurb: 'Pair up and match a friend\'s distance each week.' }
  ];

  const HOLIDAYS = [
    { name: 'Enkutatash',  note: 'Ethiopian New Year', month: 9,  day: 11, icon: 'sun' },
    { name: 'Meskel',     note: 'Finding of the True Cross', month: 9,  day: 27, icon: 'flower' },
    { name: 'Genna',        note: 'Ethiopian Christmas', month: 1,  day: 7,  icon: 'star' },
    { name: 'Timket',     note: 'Epiphany', month: 1,  day: 19, icon: 'water' },
    { name: 'Adwa Victory', note: 'National holiday', month: 3,  day: 2,  icon: 'flag' },
    { name: 'Patriots Day', note: 'National holiday', month: 5,  day: 5,  icon: 'flag' }
  ];

  const COMMUNITY = {
    athletes: 28417,
    totalKm: 62480,         
    earthCircumferenceKm: 40075,
    cities: 9,
    clubs: 148,
    runsThisWeek: 4821,
    addisAltitude: 2355
  };

  const I18N = {
    en: {
      'nav.dashboard':'Dashboard','nav.explore':'Explore','nav.record':'Record','nav.activities':'Activities',
      'nav.segments':'Segments','nav.community':'Community','nav.profile':'Profile','nav.gallery':'Gallery',
      'brand.tag':'Every kilometre, from the Entoto hills to the world.',
      'side.altitude':'Altitude training','side.altitudeSub':'Addis Ababa · 2,355 m','side.load':'Altitude load',
      'side.offline':'Offline maps ready','side.offlineSub':'No signal needed on the trails',
      'top.search':'Search routes, clubs, athletes…','top.record':'Record','top.greeting':'Good morning',
      'hero.eyebrow':'THE COLLECTIVE JOURNEY','hero.title':'How far we have gone',
      'hero.sub':'Every run and ride from the RUCHA community, this season',
      'hero.laps':'laps around the Earth','hero.athletes':'athletes','hero.cities':'cities','hero.clubs':'clubs',
      'stat.distance':'Distance','stat.time':'Time','stat.elevation':'Elevation','stat.activities':'Activities',
      'stat.thisWeek':'this week','stat.vsLast':'vs last week',
      'map.title':'Your routes','map.sub':'Tap a line to explore the track','map.heat':'Heatmap',
      'map.replay':'Replay','map.replayStop':'Stop','map.routes':'Routes','map.terrain':'Terrain',
      'map.all':'All','map.run':'Runs','map.ride':'Rides','map.km':'km',
      'feed.title':'Community feed','feed.viewAll':'View all','feed.kudos':'Kudos',
      'card.altitude':'Altitude insight','card.altitudeText':'At 2,355 m your aerobic load is ~12% higher than at sea level. RUCHA adjusts pace targets automatically.',
      'card.calendar':'Local calendar','card.next':'Next celebration',
      'card.safety':'Run safe','card.safetyText':'Share your live location with a buddy. Check-ins work even without mobile data.',
      'act.title':'Activities','act.all':'All','act.runs':'Runs','act.rides':'Rides','act.filter':'Filter',
      'act.elevation':'Elevation profile','act.splits':'Splits','act.details':'Activity details',
      'seg.title':'Segments','seg.sub':'Local climbs, sprints and circuits','seg.leaderboard':'Leaderboard',
      'seg.legend':'Legend pace','seg.yourPR':'Your PR','seg.attempts':'attempts','seg.crown':'Crown holder',
      'com.title':'Community','com.challenges':'Challenges','com.clubs':'Clubs','com.joined':'Joined',
      'com.join':'Join club','com.members':'members','com.progress':'progress','com.daysLeft':'days left',
      'prof.title':'Athlete profile','prof.prs':'Personal records','prof.trophies':'Trophies',
      'prof.weekly':'Weekly distance','prof.altitude':'Altitude-adjusted effort',
      'rec.title':'Record an activity','rec.start':'Start','rec.pause':'Pause','rec.resume':'Resume',
      'rec.finish':'Finish & save','rec.ready':'Ready when you are','rec.live':'LIVE TRACKING',
      'rec.distance':'Distance','rec.pace':'Pace','rec.elev':'Elevation','rec.hr':'Heart rate','rec.cal':'Calories',
      'rec.splits':'Kilometre splits','rec.saved':'Activity saved!',
      'common.today':'Today','common.view':'View','common.close':'Close','common.save':'Save',
      'common.all':'All','common.km':'km','common.m':'m','common.seeAll':'See all','common.you':'You',
      'common.offline':'Offline ready','common.ethiopia':'Made for Ethiopia','common.birr':'Br'
    }
  };

  function fmtDuration(sec) {
    sec = Math.max(0, Math.round(sec));
    const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60;
    return h > 0 ? `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
                 : `${m}:${String(s).padStart(2, '0')}`;
  }
  function fmtPace(secPerKm) {
    const m = Math.floor(secPerKm / 60), s = Math.round(secPerKm % 60);
    return `${m}:${String(s).padStart(2, '0')}`;
  }
  function fmtNum(n) { return Math.round(n).toLocaleString('en-US'); }
  function fmtDate(d) {
    return d.toLocaleDateString('en-GB', { weekday: 'short', day: 'numeric', month: 'short' });
  }
  function relativeDay(d) {
    const now = new Date(); const a = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const b = new Date(d.getFullYear(), d.getMonth(), d.getDate());
    const diff = Math.round((a - b) / 86400000);
    if (diff === 0) return 'Today'; if (diff === 1) return 'Yesterday';
    return fmtDate(d);
  }
  function t(key) { return I18N.en[key] || key; }

  function liveTrack(cityId, seed) {
    const city = CITIES[cityId] || CITIES.addis;
    const c = [city.lat, city.lng];
    const rand = mulberry32(seed || 4242);
    const anchors = [];
    const N = 26;
    for (let i = 0; i <= N; i++) {
      const a = (i / N) * Math.PI * 2;
      const r = 0.014 * (0.72 + 0.28 * Math.sin(a * 3 + 0.6));
      anchors.push([
        c[0] + r * Math.sin(a) * 0.82 + (rand() - 0.5) * 0.0012,
        c[1] + r * Math.cos(a) + (rand() - 0.5) * 0.0012
      ]);
    }
    anchors.push(anchors[0]);
    return buildTrack(anchors, seed || 4242, { city: city, per: 10, jitter: 0.00003 });
  }

  const CHALLENGE_VISIBILITY = [
    { id: 'friends', label: 'Friends only', blurb: 'Only people you have added as friends can see and join.' },
    { id: 'public', label: 'Public (signed-in athletes)', blurb: 'Any athlete with an account can see and join.' },
    { id: 'everyone', label: 'Everyone', blurb: 'Anyone, even without an account, can see and join.' }
  ];

  function challengeMetric(c) {
    if (c.targetElevationM > 0 && !c.targetKm) return { metric: 'elevation', unit: 'm', target: c.targetElevationM };
    if (c.targetKm > 0) return { metric: 'distance', unit: 'km', target: c.targetKm };
    if (c.targetSeconds > 0) return { metric: 'time', unit: 'min', target: c.targetSeconds / 60 };
    return { metric: 'distance', unit: 'km', target: 0 };
  }
  function isTimeTrial(c) {
    if (c.mode === 'head_to_head') return true;
    return c.kind === 'distance_time' || c.kind === 'segment_sprint' || c.kind === 'route';
  }
  function fnv32(str) {
    let h = 2166136261 >>> 0;
    for (let i = 0; i < str.length; i++) h = Math.imul(h ^ str.charCodeAt(i), 16777619) >>> 0;
    return h;
  }
  function unitValue(h, i) { return ((h + Math.imul(i + 1, 2654435761)) >>> 0) / 4294967296; }
  const LB_ROSTER = ['Selam Tesfaye', 'Dawit Bekele', 'Marta Lemma', 'Yonas Girma',
    'Hana Alemu', 'Abel Tadesse', 'Lidya Kebede', 'Fasil Teshome',
    'Tigist Haile', 'Robel Mengistu'];
  function sampleProgress(c) {
    if (c.ownerId || c.mode === 'head_to_head') return [];
    const m = challengeMetric(c);
    if (m.target <= 0) return [];
    const h = fnv32(c.id), time = isTimeTrial(c), out = [];
    for (let i = 0; i < LB_ROSTER.length; i++) {
      const u = unitValue(h, i);
      const p = { challengeId: c.id, athleteId: 'sample_' + i, athleteName: LB_ROSTER[i], attempts: 1 };
      if (time) {
        p.completed = u > 0.34;
        if (p.completed) {
          p.distanceKm = m.target;
          p.durationSec = Math.round(c.targetSeconds * 0.82 + c.targetSeconds * 0.3 * u) ||
                          Math.round(m.target * 300 * (0.78 + 0.42 * u)) + 1;
          p.bestSeconds = p.durationSec;
          p.finishedAt = new Date(Date.now() - u * 72 * 3600000).toISOString();
        } else {
          p.distanceKm = m.target * (0.12 + 0.72 * u);
          p.durationSec = Math.round(p.distanceKm * 300);
        }
      } else {
        p.completed = u > 0.85;
        p.distanceKm = p.completed ? m.target : m.target * (0.08 + 0.82 * u);
        p.elevationM = Math.round(p.distanceKm);
        p.durationSec = Math.round(p.distanceKm * 300);
        if (p.completed) p.finishedAt = new Date(Date.now() - u * 72 * 3600000).toISOString();
      }
      if (m.metric === 'elevation') p.distanceKm = 0;
      out.push(p);
    }
    return out;
  }
  function progressValue(c, p) {
    return challengeMetric(c).metric === 'elevation' ? (p.elevationM || 0) : (p.distanceKm || 0);
  }
  function buildLeaderboard(c, rows, viewerId, members) {
    const m = challengeMetric(c), ranking = isTimeTrial(c) ? 'time' : 'progress';
    let all = sampleProgress(c).concat(rows || []);
    if (c.mode === 'head_to_head' && c.inviteStatus === 'accepted') {
      [[c.ownerId, c.ownerName], [c.opponentId, c.opponentName]].forEach(pair => {
        if (pair[0] && !all.some(x => x.athleteId === pair[0]))
          all.push({ challengeId: c.id, athleteId: pair[0], athleteName: pair[1], distanceKm: 0, durationSec: 0 });
      });
    }
    all.sort((a, b) => {
      if (!!a.completed !== !!b.completed) return a.completed ? -1 : 1;
      if (a.completed && ranking === 'time') {
        const ta = a.bestSeconds || Infinity, tb = b.bestSeconds || Infinity;
        if (ta !== tb) return ta - tb;
      }
      return progressValue(c, b) - progressValue(c, a);
    });
    const out = all.map((p, i) => {
      const val = progressValue(c, p);
      const label = m.target > 0 ? val.toFixed(2) + ' / ' + m.target.toFixed(2) + ' ' + m.unit : val.toFixed(2) + ' ' + m.unit;
      let result = 'In progress';
      if (p.completed) result = ranking === 'time' ? fmtDuration(p.bestSeconds) : 'Completed';
      else if (ranking === 'time' && p.bestSeconds) result = fmtDuration(p.bestSeconds);
      return {
        rank: i + 1, athleteId: p.athleteId,
        athleteName: p.athleteName || (members && members[p.athleteId]) || 'RUCHA athlete',
        progress: val, progressLabel: label, target: m.target, unit: m.unit,
        completed: !!p.completed, result: result, finishedAt: p.finishedAt || '',
        me: !!viewerId && p.athleteId === viewerId
      };
    });
    return { challengeId: c.id, ranking: ranking, metric: m.metric, unit: m.unit,
             target: m.target, rows: out, viewerId: viewerId || '',
             joined: !!viewerId && (!!(members && members[viewerId]) || c.ownerId === viewerId ||
               (c.opponentId === viewerId && c.inviteStatus === 'accepted')) };
  }

  global.RUCHA = {
    mulberry32, haversine, buildTrack, elevationAt, elevationGain, scaleAnchors,
    CITIES, LANDMARKS, ATHLETES, PALETTE, avatarColor,
    ACTIVITIES, SEGMENTS, LEADERS, CLUBS, CHALLENGES, HOLIDAYS,
    COMMUNITY, I18N, t, fmtDuration, fmtPace, fmtNum, fmtDate, relativeDay,
    liveTrack, liveTrackAround, daysAgo,
    gainFromTrack, paceFor, caloriesFor,
    ROUTE_COLORS, routeColor,
    PLACES, nearestPlace, fmtCoord, startOf, popularAreas, hallOfFame,
    SEED_CHALLENGES, CHALLENGE_KINDS, CHALLENGE_VISIBILITY,
    challengeMetric, isTimeTrial, sampleProgress, buildLeaderboard
  };
})(window);
