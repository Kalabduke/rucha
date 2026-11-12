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


  function popularAreas(activities) {
    // Discover training areas automatically: cluster activity starts that are
    // within 500 m of each other, then name the cluster after the nearest
    // well-known place. Activities without real coordinates are ignored; the
    // app must never invent a popular area in the city centre.
    const starts = [];
    (activities || []).forEach(a => {
      let lat = null, lng = null;
      if (a.startLat != null && a.startLng != null) { lat = +a.startLat; lng = +a.startLng; }
      else if (a.track && a.track.length) { lat = +a.track[0].lat; lng = +a.track[0].lng; }
      if (!isFinite(lat) || !isFinite(lng) || (lat === 0 && lng === 0)) return;
      starts.push({ lat: lat, lng: lng });
    });

    const used = new Array(starts.length).fill(false);
    const out = [];
    for (let i = 0; i < starts.length; i++) {
      if (used[i]) continue;
      used[i] = true;
      const cluster = [starts[i]];
      for (let j = i + 1; j < starts.length; j++) {
        if (used[j]) continue;
        if (haversine([starts[i].lat, starts[i].lng], [starts[j].lat, starts[j].lng]) <= 0.5) {
          used[j] = true;
          cluster.push(starts[j]);
        }
      }
      let latSum = 0, lngSum = 0;
      cluster.forEach(p => { latSum += p.lat; lngSum += p.lng; });
      const lat = Math.round((latSum / cluster.length) * 100000) / 100000;
      const lng = Math.round((lngSum / cluster.length) * 100000) / 100000;
      const np = nearestPlace(lat, lng);
      const name = np.distanceKm <= 2.5
        ? np.name
        : (np.distanceKm <= 40 ? np.city + ' training area' : 'Open country');
      out.push({ lat: lat, lng: lng, runCount: cluster.length, name: name, city: np.city });
    }
    out.sort((a, b) => b.runCount - a.runCount || a.name.localeCompare(b.name));
    return out.slice(0, 12);
  }

  function hallOfFame(segments) {
    return (segments || [])
      .filter(s => s && (s.bestSec || s.bestSeconds))
      .map(s => {
        const startLat = s.startLat != null ? +s.startLat : 0;
        const startLng = s.startLng != null ? +s.startLng : 0;
        const np = nearestPlace(startLat, startLng);
        return {
          segmentId: s.id, segmentName: s.name,
          athleteName: s.bestAthleteName || s.ownerName || 'Athlete',
          seconds: s.bestSec || s.bestSeconds || 0,
          startLat: startLat, startLng: startLng,
          placeName: np.name, city: np.city
        };
      })
      .sort((a, b) => a.seconds - b.seconds);
  }

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
      'seg.title':'Segments','seg.sub':'Segments created from your own activities','seg.leaderboard':'Leaderboard',
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
  function progressValue(c, p) {
    return challengeMetric(c).metric === 'elevation' ? (p.elevationM || 0) : (p.distanceKm || 0);
  }
  function buildLeaderboard(c, rows, viewerId, members) {
    const m = challengeMetric(c), ranking = isTimeTrial(c) ? 'time' : 'progress';
    let all = (rows || []).slice();
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
    CITIES, LANDMARKS, PALETTE, avatarColor, HOLIDAYS,
    I18N, t, fmtDuration, fmtPace, fmtNum, fmtDate, relativeDay,
    liveTrack, liveTrackAround, daysAgo,
    gainFromTrack, paceFor, caloriesFor,
    ROUTE_COLORS, routeColor,
    PLACES, nearestPlace, fmtCoord, startOf, popularAreas, hallOfFame,
    CHALLENGE_KINDS, CHALLENGE_VISIBILITY,
    challengeMetric, isTimeTrial, buildLeaderboard
  };
})(window);
