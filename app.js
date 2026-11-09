(function () {
  'use strict';
  const D = window.RUCHA;
  const $ = (s, r) => (r || document).querySelector(s);
  const $$ = (s, r) => Array.prototype.slice.call((r || document).querySelectorAll(s));
  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const D2R = Math.PI / 180;
  const t = key => D.t(key, 'en');

  const Merc = {
    x(lng) { return (lng + 180) / 360; },
    y(lat) {
      const lr = clamp(lat, -85.05112878, 85.05112878) * D2R;
      return 0.5 - Math.log(Math.tan(Math.PI / 4 + lr / 2)) / (2 * Math.PI);
    },
    lng(x) { return x * 360 - 180; },
    lat(y) { return Math.atan(Math.sinh(Math.PI - 2 * Math.PI * y)) / D2R; },
    world(lat, lng, z) {
      const ws = 256 * Math.pow(2, z);
      return [Merc.x(lng) * ws, Merc.y(lat) * ws];
    },
    inv(wx, wy, z) {
      const ws = 256 * Math.pow(2, z);
      return { lat: Merc.lat(wy / ws), lng: Merc.lng(wx / ws) };
    }
  };
  const coord = (lat, lng) => D.fmtCoord(lat, lng);
  const API = () => window.RUCHA_API;
  const SENS = () => window.RUCHA_SENSORS;

  const P = {
    dashboard: '<rect x="3" y="3" width="7" height="9" rx="1.5"/><rect x="14" y="3" width="7" height="5" rx="1.5"/><rect x="14" y="12" width="7" height="9" rx="1.5"/><rect x="3" y="16" width="7" height="5" rx="1.5"/>',
    map: '<path d="M3 6l6-3 6 3 6-3v15l-6 3-6-3-6 3z"/><path d="M9 3v15M15 6v15"/>',
    record: '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="4" fill="currentColor" stroke="none"/>',
    activity: '<path d="M4 6h16M4 12h16M4 18h11"/>',
    segments: '<path d="M5 21V4M5 4h13l-2.5 4L18 12H5"/>',
    community: '<circle cx="9" cy="8" r="3"/><path d="M3 20v-1a6 6 0 0 1 12 0v1"/><circle cx="17.5" cy="9" r="2.2"/><path d="M16 20v-1a4.5 4.5 0 0 1 5-4.5"/>',
    profile: '<circle cx="12" cy="8" r="3.6"/><path d="M4.5 21a7.5 7.5 0 0 1 15 0"/>',
    menu: '<path d="M4 7h16M4 12h16M4 17h16"/>',
    search: '<circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/>',
    moon: '<path d="M20 14.5A8.5 8.5 0 0 1 9.5 4a8.5 8.5 0 1 0 10.5 10.5z"/>',
    sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
    mountain: '<path d="M2 20l7-13 4.5 7 2.5-4 6 10z"/><path d="M6.5 12.5l2.5 1.5 2-1"/>',
    offline: '<path d="M2 8.5a15 15 0 0 1 20 0M5 12a10 10 0 0 1 14 0M8.5 15.5a5 5 0 0 1 7 0"/><circle cx="12" cy="19" r="1" fill="currentColor" stroke="none"/><path d="M3 3l18 18"/>',
    route: '<circle cx="6" cy="18" r="2.4"/><circle cx="18" cy="6" r="2.4"/><path d="M8 18h5a4 4 0 0 0 0-8h-2a4 4 0 0 1 0-8h5"/>',
    clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.5 2"/>',
    heart: '<path d="M20.8 5.6a5.2 5.2 0 0 0-7.4 0L12 7l-1.4-1.4a5.2 5.2 0 0 0-7.4 7.4L12 21l8.8-8a5.2 5.2 0 0 0 0-7.4z"/>',
    flame: '<path d="M12 22c4.4 0 7-3 7-6.6 0-3.8-2.6-5.6-3.6-9.4-.4 2-1.6 3-2.8 3.4.4-3-1-5.4-3.2-7.4.3 3.6-1.6 5.4-3 7.4C5 11 5 13 5 15.4 5 19 7.6 22 12 22z"/>',
    run: '<circle cx="14" cy="4.5" r="2"/><path d="M9 21l2.5-5 3-2.5-1.5-4-3.5 2-2 3"/><path d="M14.5 13.5l3 2 1.5 5"/><path d="M11.5 16l4 1"/>',
    ride: '<circle cx="5.5" cy="17.5" r="3.5"/><circle cx="18.5" cy="17.5" r="3.5"/><path d="M5.5 17.5l4-8h5l4 8M9.5 9.5h6"/><circle cx="15" cy="5" r="1.6"/>',
    kudos: '<path d="M7 10v11H3V10zM7 10l4-7a2 2 0 0 1 2 2v3h5.5a2 2 0 0 1 2 2.4l-1.4 7A2 2 0 0 1 17 19H7"/>',
    close: '<path d="M6 6l12 12M18 6L6 18"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    minus: '<path d="M5 12h14"/>',
    crosshair: '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="2.5"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3"/>',
    play: '<path d="M7 4l13 8-13 8z" fill="currentColor" stroke="none"/>',
    pause: '<rect x="6" y="4" width="4" height="16" rx="1" fill="currentColor" stroke="none"/><rect x="14" y="4" width="4" height="16" rx="1" fill="currentColor" stroke="none"/>',
    stop: '<rect x="5" y="5" width="14" height="14" rx="2" fill="currentColor" stroke="none"/>',
    flag: '<path d="M5 21V4M5 4h13l-2.5 4L18 12H5"/>',
    trophy: '<path d="M7 4h10v5a5 5 0 0 1-10 0z"/><path d="M7 6H4v2a3 3 0 0 0 3 3M17 6h3v2a3 3 0 0 1-3 3M12 14v4M9 21h6M10 18h4"/>',
    star: '<path d="M12 2l2.9 6 6.6.9-4.8 4.7 1.2 6.6L12 17.1 6.1 20.2l1.2-6.6L2.5 8.9 9.1 8z"/>',
    calendar: '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4"/>',
    shield: '<path d="M12 2l8 3v6c0 5-3.5 9-8 11-4.5-2-8-6-8-11V5z"/><path d="M9 12l2 2 4-4"/>',
    check: '<path d="M4 12l5 5L20 6"/>',
    bolt: '<path d="M13 2L4 14h7l-1 8 9-12h-7z"/>',
    layers: '<path d="M12 2l9 5-9 5-9-5z"/><path d="M3 12l9 5 9-5M3 17l9 5 9-5"/>',
    heat: '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1.5" fill="currentColor" stroke="none"/>',
    users: '<circle cx="9" cy="8" r="3"/><path d="M3 20v-1a6 6 0 0 1 12 0v1"/><path d="M16 5.5a3 3 0 0 1 0 5.5M17 14a5 5 0 0 1 4 5v1"/>',
    globe: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a15 15 0 0 1 0 18M12 3a15 15 0 0 0 0 18"/>',
    share: '<circle cx="18" cy="5" r="2.5"/><circle cx="6" cy="12" r="2.5"/><circle cx="18" cy="19" r="2.5"/><path d="M8.2 10.8l7.6-4.4M8.2 13.2l7.6 4.4"/>',
    arrowUp: '<path d="M12 19V5M6 11l6-6 6 6"/>',
    chevron: '<path d="M9 6l6 6-6 6"/>',
    target: '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1.5" fill="currentColor" stroke="none"/>',
    water: '<path d="M12 2c3 4 6 7.5 6 11a6 6 0 0 1-12 0c0-3.5 3-7 6-11z"/>',
    flower: '<circle cx="12" cy="12" r="2"/><path d="M12 10c-2-4-6-3-6-1 0 2 3 3 6 3M14 12c4-2 5-6 3-6-2 0-3 3-3 6M12 14c2 4 6 3 6 1 0-2-3-3-6-3M10 12c-4 2-5 6-3 6 2 0 3-3 3-6"/>',
    sparkles: '<path d="M12 3l1.6 4.4L18 9l-4.4 1.6L12 15l-1.6-4.4L6 9l4.4-1.6zM19 15l.8 2.2L22 18l-2.2.8L19 21l-.8-2.2L16 18l2.2-.8z"/>',
    bike: '<circle cx="5.5" cy="17.5" r="3.5"/><circle cx="18.5" cy="17.5" r="3.5"/><path d="M5.5 17.5l4-8h5l4 8M9.5 9.5h6"/>',
    save: '<path d="M4 4h13l3 3v13H4z"/><path d="M8 4v6h8V4M8 20v-6h8v6"/>',
    info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/>',
    gallery: '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
    camera: '<path d="M3 8h3l1.5-2h9L18 8h3v12H3z"/><circle cx="12" cy="14" r="3.5"/>',
    image: '<rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="8.5" cy="9.5" r="1.6"/><path d="M4 18l5-5 4 4 3-3 4 4"/>',
    download: '<path d="M12 3v12M7 11l5 5 5-5M4 20h16"/>',
    trash: '<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13M10 11v6M14 11v6"/>',
    copy: '<rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2"/>',
    blur: '<circle cx="12" cy="12" r="9"/><path d="M7 12h10M9 8.5h8M9 15.5h8" stroke-dasharray="2 3"/>',
    eye: '<path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6S2 12 2 12z"/><circle cx="12" cy="12" r="2.6"/>',
    eyeOff: '<path d="M3 3l18 18M10.6 6.2A10.9 10.9 0 0 1 12 6c6.5 0 10 6 10 6a18 18 0 0 1-3.2 3.9M6.1 6.8C3.5 8.6 2 12 2 12s3.5 6 10 6c1.8 0 3.4-.5 4.8-1.2"/><path d="M9.9 9.9a3 3 0 0 0 4.2 4.2"/>'
  };
  function icon(name, cls) {
    const paths = P[name] || P.info;
    return '<svg class="ic ' + (cls || '') + '" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + paths + '</svg>';
  }

  const state = {
    view: 'dashboard', theme: 'light',
    city: 'addis', mapFilter: 'all', heat: false, terrain: true,
    basemap: 'osm', distinctLines: true,
    activities: [], kudos: new Set(), joined: new Set(),
    activityFilter: 'all', search: '', gallery: [],
    challenges: [], popularAreas: [], hall: [], segments: [], clubs: [], places: [],
    joinedChallenges: [], backend: { online: false, store: 'offline' }, sensors: null,
    social: { incoming: [], outgoing: [], friends: [], shares: [] },
    leaderboardCache: {}, goal: { km: 0, best: null },
    mapEngine: null, modalMapEngine: null,
    challengeForm: null,
    rec: {
      status: 'idle', type: 'run', elapsed: 0, idx: 0, splits: [], track: null,
      raf: null, last: 0, city: 'addis',
      mode: 'gps', name: '', startTime: 0, pausedAt: 0, pausedTotal: 0,
      realTrack: [], gpsAccuracy: null, gpsState: 'idle', filter: null, lastFix: null, lastFixAt: 0,
      hrAvailable: false, hrValue: null, hrSamples: [], hrMax: 0,
      cadValue: null, cadSamples: [], pwValue: null, pwSamples: [], bikeSpeed: null,
      challengeId: null, geofenceOk: false, geofenceDistance: null,
      goalKm: 0, goalHit: false, goalElapsed: 0, autoStop: false
    }
  };

  const NAV = [
    { id: 'dashboard', icon: 'dashboard', key: 'nav.dashboard' },
    { id: 'explore', icon: 'map', key: 'nav.explore' },
    { id: 'record', icon: 'record', key: 'nav.record' },
    { id: 'activities', icon: 'activity', key: 'nav.activities' },
    { id: 'gallery', icon: 'gallery', key: 'nav.gallery' },
    { id: 'segments', icon: 'segments', key: 'nav.segments' },
    { id: 'community', icon: 'community', key: 'nav.community' },
    { id: 'profile', icon: 'profile', key: 'nav.profile' }
  ];
  const CRUMBS = {
    dashboard: { title: 'Dashboard', sub: 'Addis Ababa · 2,355 m' },
    explore: { title: 'Explore', sub: 'Routes, segments & the heatmap' },
    record: { title: 'Record', sub: 'Live GPS tracking' },
    activities: { title: 'Activities', sub: 'Your training log' },
    gallery: { title: 'Gallery', sub: 'Your run cards, ready to post anywhere' },
    segments: { title: 'Segments', sub: 'Local climbs, sprints & circuits' },
    community: { title: 'Community', sub: 'Clubs & challenges' },
    profile: { title: 'Profile', sub: 'Your athlete profile' }
  };

  function hydrate(root) {
    $$('[data-icon]', root).forEach(el => { el.innerHTML = icon(el.getAttribute('data-icon')); });
    $$('[data-i18n]', root).forEach(el => { el.textContent = t(el.getAttribute('data-i18n')); });
    $$('[data-i18n-ph]', root).forEach(el => { el.setAttribute('placeholder', t(el.getAttribute('data-i18n-ph'))); });
  }
  function toast(msg) {
    const stack = $('#toastStack');
    const node = document.createElement('div');
    node.className = 'toast';
    node.innerHTML = icon('check') + '<span>' + esc(msg) + '</span>';
    stack.appendChild(node);
    setTimeout(() => { node.style.opacity = '0'; node.style.transform = 'translateX(30px)'; node.style.transition = 'all .3s'; setTimeout(() => node.remove(), 320); }, 3200);
  }
  function openModal(html, cls) {
    if (state.modalMapEngine) { state.modalMapEngine.destroy(); state.modalMapEngine = null; }
    const m = $('#modal');
    m.className = 'modal' + (cls ? ' ' + cls : '');
    m.innerHTML = html;
    $('#modalBackdrop').classList.add('open');
    hydrate($('#modal'));
    document.body.style.overflow = 'hidden';
  }
  function closeModal() {
    $('#modalBackdrop').classList.remove('open');
    document.body.style.overflow = '';
    if (state.modalMapEngine) { state.modalMapEngine.destroy(); state.modalMapEngine = null; }
  }
  function avatar(user, extra) {
    if (!user) return '';
    return '<div class="avatar ' + (extra || '') + '" style="background:' + D.avatarColor(user.id) + '">' + esc(user.initials) + '</div>';
  }
  function typeIcon(type) { return type === 'ride' ? 'ride' : 'run'; }
  function typeColor(type) { return type === 'ride' ? 'var(--ride)' : 'var(--run)'; }
  function typeBadge(type) {
    return '<span class="type-dot" style="background:' + typeColor(type) + '">' + icon(typeIcon(type)) + '</span>';
  }
  function fresh(n) {
    const now = new Date();
    return state.activities.filter(a => (now - a.date) / 86400000 <= n);
  }
  function weekStats() {
    const list = fresh(7);
    const dist = list.reduce((s, a) => s + a.distance, 0);
    const time = list.reduce((s, a) => s + a.duration, 0);
    const elev = list.reduce((s, a) => s + a.gain, 0);
    return { dist, time, elev, count: list.length };
  }

  function sparkline(vals, color, w, h) {
    w = w || 76; h = h || 28;
    const mx = Math.max.apply(null, vals), mn = Math.min.apply(null, vals) * 0.82;
    const rng = (mx - mn) || 1;
    const pts = vals.map((v, i) => (i / (vals.length - 1) * w).toFixed(1) + ',' + (h - (v - mn) / rng * h).toFixed(1)).join(' ');
    return '<svg width="' + w + '" height="' + h + '" viewBox="0 0 ' + w + ' ' + h + '"><polyline points="' + pts + '" fill="none" stroke="' + color + '" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" opacity=".85"/></svg>';
  }
  function barChart(vals, labels, color) {
    const W = 620, H = 156, pad = 24, n = vals.length, mx = Math.max.apply(null, vals) * 1.15 || 1;
    const bw = (W - pad * 2) / n * 0.58, gap = (W - pad * 2) / n;
    let s = '<svg class="chart-svg" viewBox="0 0 ' + W + ' ' + H + '" preserveAspectRatio="none" style="height:160px">';
    for (let g = 0; g <= 3; g++) {
      const y = pad + (H - pad * 2) * g / 3;
      s += '<line class="chart-grid" x1="' + pad + '" y1="' + y + '" x2="' + (W - pad) + '" y2="' + y + '"/>';
      s += '<text class="chart-label" x="2" y="' + (y + 3) + '">' + Math.round(mx * (1 - g / 3)) + '</text>';
    }
    vals.forEach((v, i) => {
      const bh = (v / mx) * (H - pad * 2 - 14);
      const x = pad + i * gap + (gap - bw) / 2, y = H - pad - bh;
      s += '<rect x="' + x + '" y="' + y + '" width="' + bw + '" height="' + bh + '" rx="5" fill="' + color + '" opacity="' + (0.42 + 0.58 * (v / mx)).toFixed(2) + '"/>';
      s += '<text class="chart-label" x="' + (x + bw / 2) + '" y="' + (H - 7) + '" text-anchor="middle">' + esc(labels[i]) + '</text>';
    });
    return s + '</svg>';
  }
  function elevationChart(track, color) {
    const W = 620, H = 150, pad = 16;
    const N = 90, eles = [];
    for (let i = 0; i < N; i++) eles.push(track[Math.floor(i / (N - 1) * (track.length - 1))].ele);
    const mn = Math.min.apply(null, eles), mx = Math.max.apply(null, eles), rng = (mx - mn) || 1;
    const pts = eles.map((e, i) => [(i / (N - 1)) * (W - pad * 2) + pad, H - pad - ((e - mn) / rng) * (H - pad * 2 - 10)]);
    const line = pts.map(p => p[0].toFixed(1) + ',' + p[1].toFixed(1)).join(' ');
    const area = 'M' + pts[0][0] + ',' + (H - pad) + ' L' + pts.map(p => p[0].toFixed(1) + ',' + p[1].toFixed(1)).join(' L') + ' L' + pts[pts.length - 1][0] + ',' + (H - pad) + ' Z';
    const id = 'eg' + Math.floor(Math.random() * 1e6);
    let s = '<svg class="chart-svg" viewBox="0 0 ' + W + ' ' + H + '" preserveAspectRatio="none" style="height:150px">';
    s += '<defs><linearGradient id="' + id + '" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="' + color + '" stop-opacity=".42"/><stop offset="1" stop-color="' + color + '" stop-opacity=".02"/></linearGradient></defs>';
    for (let g = 0; g <= 3; g++) { const y = pad + (H - pad * 2) * g / 3; s += '<line class="chart-grid" x1="' + pad + '" y1="' + y + '" x2="' + (W - pad) + '" y2="' + y + '"/>'; }
    s += '<path d="' + area + '" fill="url(#' + id + ')"/>';
    s += '<polyline points="' + line + '" fill="none" stroke="' + color + '" stroke-width="2.2" stroke-linejoin="round" stroke-linecap="round"/>';
    s += '<text class="chart-label" x="' + pad + '" y="12">' + Math.round(mx) + ' m</text>';
    s += '<text class="chart-label" x="' + pad + '" y="' + (H - 3) + '">' + Math.round(mn) + ' m · 0 km</text>';
    s += '<text class="chart-label" x="' + (W - pad) + '" y="' + (H - 3) + '" text-anchor="end">' + track[track.length - 1].d.toFixed(1) + ' km</text>';
    return s + '</svg>';
  }
  function smoothAnchors(anchors, per) {
    const out = [];
    for (let i = 0; i < anchors.length - 1; i++) {
      const p0 = anchors[Math.max(0, i - 1)], p1 = anchors[i], p2 = anchors[i + 1], p3 = anchors[Math.min(anchors.length - 1, i + 2)];
      for (let s = 0; s < per; s++) {
        const q = s / per, q2 = q * q, q3 = q2 * q;
        const cm = (a, b, c, d) => 0.5 * ((2 * b) + (-a + c) * q + (2 * a - 5 * b + 4 * c - d) * q2 + (-a + 3 * b - 3 * c + d) * q3);
        out.push([cm(p0[0], p1[0], p2[0], p3[0]), cm(p0[1], p1[1], p2[1], p3[1])]);
      }
    }
    out.push(anchors[anchors.length - 1]);
    return out;
  }
  function generateRoads(city, seed) {
    const rand = D.mulberry32(seed), roads = [], N = 11, step = 0.0034;
    for (let i = -N; i <= N; i++) {
      const off = i * step, horiz = [], vert = [];
      for (let j = -N; j <= N; j++) {
        const q = j * step;
        horiz.push([city.lat + off + Math.sin(q * 300 + i * 0.42) * 0.00026 + (rand() - 0.5) * 0.00006, city.lng + q]);
        vert.push([city.lat + q, city.lng + off + Math.sin(q * 290 + i * 0.38) * 0.00026 + (rand() - 0.5) * 0.00006]);
      }
      roads.push({ pts: horiz, major: false });
      roads.push({ pts: vert, major: false });
    }
    const majorDefs = [
      [[-0.032, -0.030], [-0.016, -0.014], [0, 0.002], [0.016, 0.020], [0.034, 0.036]],
      [[-0.030, 0.028], [-0.012, 0.014], [0.006, -0.004], [0.030, -0.026]],
      [[-0.024, -0.040], [-0.006, -0.018], [0.014, 0.006], [0.030, 0.032]],
      [[-0.036, 0.006], [-0.014, 0.010], [0.010, 0.002], [0.036, -0.012]],
      [[-0.010, -0.044], [0.004, -0.016], [0.010, 0.016], [0.006, 0.044]]
    ];
    majorDefs.forEach(def => roads.push({ pts: smoothAnchors(def.map(p => [city.lat + p[0], city.lng + p[1]]), 8), major: true }));
    return roads;
  }

  class MapEngine {
    constructor(wrap, opts) {
      this.wrap = wrap;
      this.opts = Object.assign({ city: 'addis', routes: [], mode: 'multi', filter: 'all', heat: false, terrain: false, replay: false, interactive: true, suggested: false, osm: false, markers: [], distinct: false, onPick: null, onTilesFailed: null }, opts || {});
      this.canvas = $('.map-canvas', wrap);
      this.ctx = this.canvas.getContext('2d');
      this.static = document.createElement('canvas');
      this.sctx = this.static.getContext('2d');
      this.city = D.CITIES[this.opts.city] || D.CITIES.addis;
      this.center = { lat: this.city.viewLat || this.city.lat, lng: this.city.lng };
      this.scale = this.city.scale;
      this.panX = 0; this.panY = 0;
      this.w = 1; this.h = 1; this.dpr = Math.min(window.devicePixelRatio || 1, 2);
      this.roads = [];
      this.landmarks = D.LANDMARKS[this.opts.city] || [];
      this.routes = this.opts.routes || [];
      this.focusId = null;
      this.hoverId = null;
      this.liveIndex = -1;
      this.replay = { enabled: !!this.opts.replay, playing: false, t: 0, seconds: 16 };
      this.staticDirty = true;
      this.animating = false;
      this.dead = false;
      this.dragging = false;
      this.moved = false;
      this.osm = !!this.opts.osm;
      this.markers = (this.opts.markers || []).slice();
      this.tiles = { z: 0, imgs: new Map(), ok: 0, fail: 0, failed: false, timer: null };
      this.tileLayer = null;
      this.colors = this.readColors();
      this.resize();
      this.bind();
      this.render();
    }
    readColors() {
      const cs = getComputedStyle(document.documentElement);
      const get = k => (cs.getPropertyValue(k) || '').trim();
      return {
        bg: get('--map-bg') || '#EDEAE1', road: get('--map-road') || '#fff', roadCase: get('--map-road-case') || '#D9D5C9',
        water: get('--map-water') || '#BBDDE4', park: get('--map-park') || '#CFE3C4',
        contour: get('--map-contour') || '#C9C3B2', label: get('--map-label') || '#4B554F',
        text: get('--text') || '#18211E', surface: get('--surface') || '#fff', border: get('--border') || '#E7E4DC',
        run: '#FF5A1F', ride: '#0E8A6A', dark: document.documentElement.getAttribute('data-theme') === 'dark'
      };
    }
    resize() {
      const r = this.wrap.getBoundingClientRect();
      this.w = Math.max(1, r.width); this.h = Math.max(1, r.height);
      [this.canvas, this.static].forEach(c => {
        c.width = Math.round(this.w * this.dpr); c.height = Math.round(this.h * this.dpr);
        c.style.width = this.w + 'px'; c.style.height = this.h + 'px';
      });
      this.ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
      this.sctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
      this.staticDirty = true;
    }
    worldSize() {
      // Pixels for the whole Mercator world at this map scale. Keeping the
      // scale in "pixels per degree of latitude at the centre" means the scale
      // bar and the existing zoom limits stay meaningful.
      return 360 * this.scale * Math.cos(this.center.lat * D2R);
    }
    project(lat, lng) {
      const ws = this.worldSize();
      return [
        (Merc.x(lng) - Merc.x(this.center.lng)) * ws + this.w / 2 + this.panX,
        (Merc.y(lat) - Merc.y(this.center.lat)) * ws + this.h / 2 + this.panY
      ];
    }
    unproject(x, y) {
      const ws = this.worldSize();
      return {
        lat: Merc.lat(Merc.y(this.center.lat) + (y - this.h / 2 - this.panY) / ws),
        lng: Merc.lng(Merc.x(this.center.lng) + (x - this.w / 2 - this.panX) / ws)
      };
    }
    cssVar(n) { return this.colors[n]; }
    activeRoutes() {
      const f = this.opts.filter;
      return this.routes.filter(a => f === 'all' || a.type === f);
    }
    focusRoute() {
      if (!this.focusId) return null;
      return this.routes.find(a => a.id === this.focusId) || null;
    }
    invalidate() {
      if (this.dead) return;
      this.staticDirty = true;
      if (!this.animating) this.render();
    }
    destroy() {
      this.dead = true; this.animating = false;
      if (this.ro) { try { this.ro.disconnect(); } catch (e) {} this.ro = null; }
      if (this.tiles && this.tiles.timer) clearTimeout(this.tiles.timer);
      if (this.tileLayer) { this.tileLayer.remove(); this.tileLayer = null; }
      if (this.tiles) this.tiles.imgs.clear();
    }

    drawStatic() {
      const c = this.sctx, col = this.colors, W = this.w, H = this.h;
      c.clearRect(0, 0, W, H);
      if (this.osm) {
        this.renderTiles();
        this.staticDirty = false;
        return;
      }
      c.fillStyle = col.bg; c.fillRect(0, 0, W, H);
      c.strokeStyle = col.dark ? 'rgba(255,255,255,.05)' : 'rgba(0,0,0,.06)'; c.lineWidth = 1;
      for (let gx = 0; gx < W; gx += 48) { c.beginPath(); c.moveTo(gx + .5, 0); c.lineTo(gx + .5, H); c.stroke(); }
      for (let gy = 0; gy < H; gy += 48) { c.beginPath(); c.moveTo(0, gy + .5); c.lineTo(W, gy + .5); c.stroke(); }

      if (this.opts.terrain) {
        const ep = this.project(this.city.lat + 0.075, this.city.lng - 0.004);
        const g = c.createRadialGradient(ep[0], ep[1], 20, ep[0], ep[1], Math.max(W, H) * 0.85);
        g.addColorStop(0, col.dark ? 'rgba(45,95,66,.34)' : 'rgba(120,150,105,.24)');
        g.addColorStop(1, 'rgba(0,0,0,0)');
        c.fillStyle = g; c.fillRect(0, 0, W, H);
        c.lineWidth = 1;
        c.font = '600 9px Inter, sans-serif';
        for (let e = Math.ceil((this.city.baseEle - 120) / 100) * 100; e < this.city.baseEle + 1000; e += 100) {
          const dyKm = (e - this.city.baseEle) / this.city.eleSlope;
          const lat = this.city.lat + dyKm / 110.574;
          const y = this.project(lat, this.city.lng)[1];
          if (y < -30 || y > H + 30) continue;
          c.beginPath();
          for (let x = -20; x <= W + 20; x += 8) {
            const yy = y + Math.sin(x * 0.011 + e * 0.01) * 9 + Math.cos(x * 0.023) * 3;
            x === -20 ? c.moveTo(x, yy) : c.lineTo(x, yy);
          }
          c.strokeStyle = col.contour; c.globalAlpha = 0.55; c.stroke(); c.globalAlpha = 1;
          if (e % 200 === 0) { c.fillStyle = col.label; c.globalAlpha = .5; c.fillText(e + ' m', 10, y - 5); c.globalAlpha = 1; }
        }
      }

      c.fillStyle = col.water;
      this.landmarks.filter(l => false).forEach(l => {
        const p = this.project(l.lat, l.lng);
        c.beginPath(); c.ellipse(p[0], p[1], this.scale * 0.009, this.scale * 0.007, -0.3, 0, Math.PI * 2); c.fill();
        c.strokeStyle = col.dark ? 'rgba(120,200,220,.25)' : 'rgba(60,130,150,.25)'; c.lineWidth = 1.5; c.stroke();
      });
      c.fillStyle = col.park; c.globalAlpha = col.dark ? .5 : .8;
      this.landmarks.filter(l => false).forEach(l => {
        const p = this.project(l.lat, l.lng);
        c.beginPath(); c.ellipse(p[0], p[1], this.scale * 0.0075, this.scale * 0.0055, 0.4, 0, Math.PI * 2); c.fill();
      });
      c.globalAlpha = 1;

      const majorW = clamp(this.scale / 2400, 2.6, 8), minorW = clamp(this.scale / 15000, 0.5, 1.5);
      const drawRoad = (road) => {
        const pts = road.pts;
        c.beginPath();
        let started = false;
        for (let i = 0; i < pts.length; i++) {
          const p = this.project(pts[i][0], pts[i][1]);
          if (p[0] < -60 || p[0] > W + 60 || p[1] < -60 || p[1] > H + 60) { started = false; continue; }
          if (!started) { c.moveTo(p[0], p[1]); started = true; } else c.lineTo(p[0], p[1]);
        }
        c.lineCap = 'round';
        if (road.major) {
          c.strokeStyle = col.roadCase; c.lineWidth = majorW + 2.4; c.stroke();
          c.strokeStyle = col.road; c.lineWidth = majorW; c.globalAlpha = 1; c.stroke();
        } else {
          c.strokeStyle = col.road; c.lineWidth = minorW; c.globalAlpha = .48; c.stroke(); c.globalAlpha = 1;
        }
      };
      this.roads.filter(r => !r.major).forEach(drawRoad);
      this.roads.filter(r => r.major).forEach(drawRoad);

      if (this.opts.heat && this.opts.mode !== 'live') {
        c.save();
        this.routes.forEach(a => {
          const passes = [[32, .05], [21, .075], [12, .11], [5, .17]];
          passes.forEach(([wd, al]) => {
            c.beginPath();
            a.track.forEach((pt, i) => { const p = this.project(pt.lat, pt.lng); i === 0 ? c.moveTo(p[0], p[1]) : c.lineTo(p[0], p[1]); });
            c.strokeStyle = a.type === 'ride' ? '#0E8A6A' : '#FF5A1F';
            c.globalAlpha = al; c.lineWidth = wd * (this.scale / 8200); c.lineCap = 'round'; c.lineJoin = 'round'; c.stroke();
          });
        });
        c.restore();
      }

      if (this.opts.suggested && this.suggestedTrack) {
        c.save(); c.setLineDash([8, 8]); c.strokeStyle = col.dark ? '#8FD8B4' : '#0E8A6A'; c.lineWidth = 2; c.globalAlpha = .8;
        c.beginPath();
        this.suggestedTrack.forEach((pt, i) => { const p = this.project(pt.lat, pt.lng); i === 0 ? c.moveTo(p[0], p[1]) : c.lineTo(p[0], p[1]); });
        c.stroke(); c.restore();
      }

      const showLabels = this.scale > 4200;
      const placed = [];
      this.landmarks.forEach(l => {
        const p = this.project(l.lat, l.lng);
        if (p[0] < -50 || p[0] > W + 50 || p[1] < -50 || p[1] > H + 50) return;
        c.beginPath(); c.arc(p[0], p[1], l.kind === 'peak' ? 5 : 3.6, 0, Math.PI * 2);
        c.fillStyle = l.kind === 'park' ? '#2E9E5B' : l.kind === 'water' ? '#3C94B0' : l.kind === 'peak' ? '#E8A700' : col.dark ? '#C9D8CE' : '#5B6B62';
        c.fill(); c.strokeStyle = col.surface; c.lineWidth = 1.6; c.stroke();
        if (!showLabels) return;
        const label = l.name;
        c.font = '700 10px Inter, sans-serif';
        const tw = c.measureText(label).width;
        const box = [p[0] + 8, p[1] - 8, tw + 10, 16];
        const collides = placed.some(r => box[0] < r[0] + r[2] && box[0] + box[2] > r[0] && box[1] < r[1] + r[3] && box[1] + box[3] > r[1]);
        if (collides) return;
        placed.push(box);
        c.fillStyle = col.dark ? 'rgba(10,16,13,.78)' : 'rgba(255,255,255,.86)';
        c.fillRect(box[0], box[1], box[2], box[3]);
        c.fillStyle = col.label; c.fillText(label, p[0] + 13, p[1] + 3);
      });
      this.staticDirty = false;
    }

    drawRoute(c, a, isFocus, upto) {
      const pts = a.track, n = Math.min(upto, pts.length - 1);
      if (n < 1) return;
      const color = this.opts.distinct ? D.routeColor(a) : (a.type === 'ride' ? this.colors.ride : this.colors.run);
      const build = () => {
        c.beginPath();
        for (let i = 0; i <= n; i++) { const p = this.project(pts[i].lat, pts[i].lng); i === 0 ? c.moveTo(p[0], p[1]) : c.lineTo(p[0], p[1]); }
      };
      c.lineCap = 'round'; c.lineJoin = 'round';
      build(); c.strokeStyle = color; c.globalAlpha = .16; c.lineWidth = isFocus ? 13 : 9; c.stroke();
      build(); c.globalAlpha = 1; c.lineWidth = isFocus ? 4 : 2.6; c.stroke();
      build(); c.strokeStyle = 'rgba(255,255,255,.55)'; c.globalAlpha = isFocus ? .8 : .35; c.lineWidth = isFocus ? 1.3 : .8; c.stroke();
      c.globalAlpha = 1;

      if (isFocus || a.id === this.hoverId) {
        const totalKm = Math.floor(pts[n].d);
        const stepKm = totalKm > 18 ? 3 : totalKm > 9 ? 2 : 1;
        c.font = '700 9px Inter, sans-serif';
        for (let k = stepKm; k <= totalKm; k += stepKm) {
          let idx = -1;
          for (let i = 1; i <= n; i++) if (pts[i].d >= k) { idx = i; break; }
          if (idx < 0) continue;
          const p = this.project(pts[idx].lat, pts[idx].lng);
          if (p[0] < 0 || p[0] > this.w || p[1] < 0 || p[1] > this.h) continue;
          c.beginPath(); c.arc(p[0], p[1], 8, 0, Math.PI * 2);
          c.fillStyle = this.colors.surface; c.fill(); c.strokeStyle = color; c.lineWidth = 2; c.stroke();
          c.fillStyle = this.colors.text; c.textAlign = 'center'; c.textBaseline = 'middle';
          c.fillText(String(k), p[0], p[1] + .5);
          c.textAlign = 'left'; c.textBaseline = 'alphabetic';
        }
      }
      const s = this.project(pts[0].lat, pts[0].lng), f = this.project(pts[n].lat, pts[n].lng);
      const close = Math.hypot(f[0] - s[0], f[1] - s[1]) < 20;
      const sep = close ? 9 : 0;
      const r = isFocus ? 8 : 6.5;
      const showLetter = isFocus || close;
      const pin = (p, fill, ch, dx) => {
        const x = p[0] + dx, y = p[1];
        c.beginPath(); c.arc(x, y, r, 0, Math.PI * 2);
        c.fillStyle = fill; c.fill(); c.strokeStyle = '#fff'; c.lineWidth = 2; c.stroke();
        if (showLetter) {
          c.fillStyle = '#fff'; c.font = '800 ' + (r > 7 ? 9 : 8) + 'px Inter, sans-serif';
          c.textAlign = 'center'; c.textBaseline = 'middle';
          c.fillText(ch, x, y + .5);
          c.textAlign = 'left'; c.textBaseline = 'alphabetic';
        }
      };
      pin(s, '#12A88A', 'S', -sep);
      if (!this.replay.enabled || n >= pts.length - 1) pin(f, '#FF5A1F', 'F', sep);
    }

    render() {
      if (this.dead) return;
      if (this.staticDirty) this.drawStatic();
      const c = this.ctx;
      c.clearRect(0, 0, this.w, this.h);
      c.drawImage(this.static, 0, 0, this.w, this.h);

      const focus = this.focusRoute();
      const list = this.activeRoutes();
      const visible = this.opts.mode === 'single' && focus ? [focus] : list;
      if (this.opts.mode === 'live' && visible.length) {
        c.save(); c.setLineDash([5, 7]);
        c.beginPath();
        visible[0].track.forEach((pt, i) => { const p = this.project(pt.lat, pt.lng); i === 0 ? c.moveTo(p[0], p[1]) : c.lineTo(p[0], p[1]); });
        c.strokeStyle = visible[0].type === 'ride' ? this.colors.ride : this.colors.run;
        c.globalAlpha = .3; c.lineWidth = 2.2; c.lineCap = 'round'; c.lineJoin = 'round'; c.stroke();
        c.restore();
      }
      if (this.opts.mode === 'single' && this.replay.enabled && focus) {
        c.save(); c.setLineDash([6, 7]);
        c.beginPath();
        focus.track.forEach((pt, i) => { const p = this.project(pt.lat, pt.lng); i === 0 ? c.moveTo(p[0], p[1]) : c.lineTo(p[0], p[1]); });
        c.strokeStyle = focus.type === 'ride' ? this.colors.ride : this.colors.run;
        c.globalAlpha = .3; c.lineWidth = 2.4; c.lineCap = 'round'; c.lineJoin = 'round'; c.stroke();
        c.restore();
      }
      visible.forEach(a => {
        const isFocus = this.opts.mode === 'single' || a.id === this.focusId || a.id === this.hoverId;
        let upto = a.track.length - 1;
        if (this.opts.mode === 'single' && this.replay.enabled) upto = Math.max(1, Math.floor((a.track.length - 1) * this.replay.t));
        if (this.opts.mode === 'live') upto = this.liveIndex >= 0 ? this.liveIndex : 0;
        if (a.id === this.hoverId && this.focusId !== a.id) {  return; }
        this.drawRoute(c, a, isFocus, upto);
      });
      if (this.hoverId && this.focusId !== this.hoverId) {
        const h = list.find(a => a.id === this.hoverId);
        if (h) { let upto = this.opts.mode === 'live' ? Math.max(0, this.liveIndex) : h.track.length - 1; this.drawRoute(c, h, true, upto); }
      }
      if (this.markers && this.markers.length) this.drawMarkers(c);

      let headAct = null, headIdx = -1;
      if (this.opts.mode === 'single' && this.replay.enabled && focus) {
        headAct = focus; headIdx = Math.max(1, Math.floor((focus.track.length - 1) * this.replay.t));
      } else if (this.opts.mode === 'live' && this.liveIndex >= 0 && visible.length) {
        headAct = visible[0]; headIdx = Math.min(this.liveIndex, headAct.track.length - 1);
      }
      if (headAct && headIdx >= 0) {
        const pt = headAct.track[headIdx], p = this.project(pt.lat, pt.lng);
        const color = headAct.type === 'ride' ? this.colors.ride : this.colors.run;
        const g = c.createRadialGradient(p[0], p[1], 2, p[0], p[1], 26);
        g.addColorStop(0, color + '88'); g.addColorStop(1, color + '00');
        c.fillStyle = g; c.beginPath(); c.arc(p[0], p[1], 26, 0, Math.PI * 2); c.fill();
        c.beginPath(); c.arc(p[0], p[1], 8, 0, Math.PI * 2); c.fillStyle = color; c.fill();
        c.strokeStyle = '#fff'; c.lineWidth = 3; c.stroke();
        c.beginPath(); c.arc(p[0], p[1], 3, 0, Math.PI * 2); c.fillStyle = '#fff'; c.fill();
      }
      if (this.userFix && this.opts.mode === 'live') this.drawUser(c);
      this.updateScale();
      const distEl = $('.map-dist', this.wrap);
      if (distEl) {
        const total = this.activeRoutes().reduce((s, a) => s + (Number(a.distance) || 0), 0);
        const label = total > 0 && total < 10 ? total.toFixed(2) : D.fmtNum(total);
        distEl.textContent = ' · ' + label + ' km tracked';
      }
    }
    drawUser(c) {
      const f = this.userFix;
      if (!f || !isFinite(f.lat) || !isFinite(f.lng)) return;
      const p = this.project(f.lat, f.lng);
      if (p[0] < -60 || p[0] > this.w + 60 || p[1] < -60 || p[1] > this.h + 60) return;
      const mPerPx = 111320 * Math.cos(f.lat * D2R) / (this.scale * Math.cos(this.center.lat * D2R));
      const rr = Math.max(10, (f.accuracy || 0) / mPerPx);
      c.beginPath(); c.arc(p[0], p[1], rr, 0, Math.PI * 2);
      c.fillStyle = 'rgba(47,111,237,.14)'; c.fill();
      c.strokeStyle = 'rgba(47,111,237,.45)'; c.lineWidth = 1; c.stroke();
      if (f.heading != null && (f.speed || 0) > 0.8) {
        const a = f.heading * D2R;
        c.save(); c.translate(p[0], p[1]); c.rotate(a);
        c.beginPath(); c.moveTo(0, -17); c.lineTo(6, -8); c.lineTo(-6, -8); c.closePath();
        c.fillStyle = '#2F6FED'; c.fill(); c.restore();
      }
      c.beginPath(); c.arc(p[0], p[1], 7, 0, Math.PI * 2);
      c.fillStyle = '#2F6FED'; c.fill();
      c.strokeStyle = '#fff'; c.lineWidth = 3; c.stroke();
    }
    updateScale() {
      const bar = $('.map-scale-bar', this.wrap), label = $('.map-scale-label', this.wrap);
      if (!bar || !label) return;
      const mPerPx = 111320 / this.scale;
      const target = mPerPx * 78;
      const nice = [50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000].reduce((a, b) => Math.abs(b - target) < Math.abs(a - target) ? b : a);
      const px = nice / mPerPx;
      bar.style.width = clamp(px, 24, 160) + 'px';
      label.textContent = nice >= 1000 ? (nice / 1000) + ' km' : nice + ' m';
    }

    tileZoom() {
      // Round up: tile images are then never enlarged past their native 256px,
      // which keeps streets and labels crisp instead of blurry.
      const z = Math.log2(Math.max(1, this.worldSize() / 256));
      return clamp(Math.ceil(z), 2, 19);
    }
    ensureTileLayer() {
      if (this.tileLayer) return this.tileLayer;
      const layer = document.createElement('div');
      layer.className = 'tile-layer';
      this.wrap.insertBefore(layer, this.canvas);
      this.tileLayer = layer;
      return layer;
    }
    setAttribution(show) {
      const el = $('.map-attribution', this.wrap);
      if (!el) return;
      el.hidden = !show;
      el.textContent = '© OpenStreetMap contributors';
    }
    maybeTilesFailed(force) {
      if (this.tiles.failed || this.tiles.ok > 0 || !this.osm) return;
      if (force || this.tiles.fail >= 6) {
        this.tiles.failed = true;
        if (this.opts.onTilesFailed) this.opts.onTilesFailed();
      }
    }
    renderTiles() {
      const layer = this.ensureTileLayer();
      const z = this.tileZoom(); this.tiles.z = z;
      const W = this.w, H = this.h, pad = 160;
      // Web Mercator is monotonic, so the four padded corners bound every
      // tile that can touch the viewport.
      let minWX = Infinity, maxWX = -Infinity, minWY = Infinity, maxWY = -Infinity;
      [[-pad, -pad], [W + pad, -pad], [-pad, H + pad], [W + pad, H + pad]].forEach(corner => {
        const g = this.unproject(corner[0], corner[1]);
        const w = Merc.world(g.lat, g.lng, z);
        minWX = Math.min(minWX, w[0]); maxWX = Math.max(maxWX, w[0]);
        minWY = Math.min(minWY, w[1]); maxWY = Math.max(maxWY, w[1]);
      });
      const n = Math.pow(2, z);
      const x0 = Math.max(0, Math.floor(minWX / 256)), x1 = Math.min(n - 1, Math.floor(maxWX / 256));
      const y0 = Math.max(0, Math.floor(minWY / 256)), y1 = Math.min(n - 1, Math.floor(maxWY / 256));
      const need = new Set();
      for (let ty = y0; ty <= y1; ty++) {
        for (let tx = x0; tx <= x1; tx++) {
          const key = z + '/' + tx + '/' + ty;
          need.add(key);
          let img = this.tiles.imgs.get(key);
          if (!img) {
            img = new Image();
            img.alt = ''; img.draggable = false; img.decoding = 'async'; img.className = 'osm-tile';
            img.onload = () => {
              this.tiles.ok++;
              if (this.tiles.timer) { clearTimeout(this.tiles.timer); this.tiles.timer = null; }
              this.setAttribution(true);
            };
            img.onerror = () => { this.tiles.fail++; img.style.display = 'none'; this.maybeTilesFailed(false); };
            img.src = 'https://tile.openstreetmap.org/' + z + '/' + tx + '/' + ty + '.png';
            layer.appendChild(img);
            this.tiles.imgs.set(key, img);
          }
          const nw = Merc.inv(tx * 256, ty * 256, z);
          const se = Merc.inv((tx + 1) * 256, (ty + 1) * 256, z);
          const p0 = this.project(nw.lat, nw.lng), p1 = this.project(se.lat, se.lng);
          img.style.left = p0[0].toFixed(1) + 'px';
          img.style.top = p0[1].toFixed(1) + 'px';
          img.style.width = Math.max(1, p1[0] - p0[0]).toFixed(1) + 'px';
          img.style.height = Math.max(1, p1[1] - p0[1]).toFixed(1) + 'px';
        }
      }
      this.tiles.imgs.forEach((img, key) => { if (!need.has(key)) { img.remove(); this.tiles.imgs.delete(key); } });
      if (!this.tiles.timer && this.tiles.ok === 0) {
        this.tiles.timer = setTimeout(() => { this.tiles.timer = null; this.maybeTilesFailed(true); }, 15000);
      }
    }
    setBasemap(osm) {
      const want = !!osm;
      // Tapping "Street map" again retries after a slow/failed load instead of
      // leaving the map stuck on the schematic fallback.
      if (want && this.tiles.failed) {
        this.tiles.failed = false; this.tiles.ok = 0; this.tiles.fail = 0;
        if (this.tiles.timer) { clearTimeout(this.tiles.timer); this.tiles.timer = null; }
        if (this.tileLayer) this.tileLayer.innerHTML = '';
        this.tiles.imgs.clear();
      }
      this.osm = want;
      if (!this.osm && this.tileLayer) {
        this.tileLayer.remove(); this.tileLayer = null;
        this.tiles.imgs.clear();
        this.setAttribution(false);
      }
      this.invalidate();
    }
    setRoutes(arr) { this.routes = arr || []; this.invalidate(); }
    setMarkers(arr) { this.markers = (arr || []).slice(); if (!this.animating) this.render(); }
    drawMarkers(c) {
      this.markers.forEach((m, i) => {
        const p = this.project(m.lat, m.lng);
        if (p[0] < -30 || p[0] > this.w + 30 || p[1] < -30 || p[1] > this.h + 30) return;
        const col = m.color || (i === 0 ? '#12A88A' : '#FF5A1F');
        c.save();
        c.shadowColor = 'rgba(0,0,0,.32)'; c.shadowBlur = 9; c.shadowOffsetY = 3;
        c.beginPath(); c.arc(p[0], p[1] - 13, 11, 0, Math.PI * 2);
        c.fillStyle = col; c.fill(); c.restore();
        c.beginPath(); c.moveTo(p[0] - 6, p[1] - 8); c.lineTo(p[0], p[1] + 3); c.lineTo(p[0] + 6, p[1] - 8); c.closePath();
        c.fillStyle = col; c.fill();
        c.fillStyle = '#fff'; c.font = '800 11px Inter, sans-serif';
        c.textAlign = 'center'; c.textBaseline = 'middle';
        c.fillText(m.label || (i ? 'B' : 'A'), p[0], p[1] - 13);
        c.textAlign = 'left'; c.textBaseline = 'alphabetic';
      });
    }

    bind() {
      const cv = this.canvas;
      const pos = e => { const r = cv.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; };
      cv.addEventListener('pointerdown', e => {
        if (!this.opts.interactive) return;
        this.dragging = true; this.moved = false; this.lastP = pos(e); cv.classList.add('dragging');
        cv.setPointerCapture(e.pointerId);
      });
      cv.addEventListener('pointermove', e => {
        const p = pos(e);
        if (this.dragging) {
          this.moved = true;
          if (this.opts.mode === 'live') this.userPanned = true;
          this.panX += p[0] - this.lastP[0]; this.panY += p[1] - this.lastP[1];
          this.lastP = p; this.invalidate(); hideTooltip(); return;
        }
        const hit = this.hitTest(p[0], p[1]);
        const id = hit ? hit.id : null;
        if (id !== this.hoverId) { this.hoverId = id; if (!this.animating) this.render(); }
        if (hit) {
          const nm = hit.title;
          showTooltip(e.clientX, e.clientY,
            '<b>' + esc(nm) + '</b><span><i class="tt-type" style="background:' + typeColor(hit.type) + '"></i>' +
            hit.distance.toFixed(1) + ' km · ' + D.fmtDuration(hit.duration) + ' · +' + D.fmtNum(hit.gain) + ' m</span>');
        } else hideTooltip();
      });
      const end = () => { this.dragging = false; cv.classList.remove('dragging'); };
      cv.addEventListener('pointerup', end);
      cv.addEventListener('pointercancel', end);
      cv.addEventListener('click', e => {
        if (!this.opts.onPick || this.moved) return;
        const p = pos(e);
        const g = this.unproject(p[0], p[1]);
        this.opts.onPick(g.lat, g.lng);
      });
      cv.addEventListener('pointerleave', () => { end(); hideTooltip(); this.hoverId = null; if (!this.animating) this.render(); });
      cv.addEventListener('wheel', e => {
        if (!this.opts.interactive) return;
        e.preventDefault();
        const p = pos(e), before = this.unproject(p[0], p[1]);
        const f = e.deltaY < 0 ? 1.18 : 1 / 1.18;
        this.scale = clamp(this.scale * f, 2600, 260000);
        const after = this.project(before.lat, before.lng);
        this.panX += p[0] - after[0]; this.panY += p[1] - after[1];
        this.invalidate();
      }, { passive: false });
      if (window.ResizeObserver) {
        this.ro = new ResizeObserver(() => { this.resize(); if (!this.animating) this.render(); });
        this.ro.observe(this.wrap);
      }
    }
    hitTest(mx, my) {
      let best = null, bd = 14;
      if (this.opts.mode === 'live') return null;
      const list = this.activeRoutes();
      for (let k = 0; k < list.length; k++) {
        const pts = list[k].track;
        let upto = pts.length - 1;
        if (this.opts.mode === 'single' && this.replay.enabled) upto = Math.max(1, Math.floor((pts.length - 1) * this.replay.t));
        for (let i = 0; i <= upto; i += 2) {
          const p = this.project(pts[i].lat, pts[i].lng);
          if (p[0] < -10 || p[0] > this.w + 10 || p[1] < -10 || p[1] > this.h + 10) continue;
          const d = Math.hypot(p[0] - mx, p[1] - my);
          if (d < bd) { bd = d; best = list[k]; }
        }
      }
      return best;
    }
    zoom(f) {
      this.scale = clamp(this.scale * f, 2600, 260000); this.invalidate();
    }
    recenter() {
      this.userPanned = false;
      if (this.userFix) {
        this.center = { lat: this.userFix.lat, lng: this.userFix.lng };
        this.scale = Math.max(this.scale, 16000);
      } else {
        this.center = { lat: this.city.viewLat || this.city.lat, lng: this.city.lng };
        this.scale = this.city.scale;
      }
      this.panX = 0; this.panY = 0; this.focusId = null; this.invalidate();
    }
    fitRoute(a) {
      let mnLat = 1e9, mxLat = -1e9, mnLng = 1e9, mxLng = -1e9;
      a.track.forEach(p => { mnLat = Math.min(mnLat, p.lat); mxLat = Math.max(mxLat, p.lat); mnLng = Math.min(mnLng, p.lng); mxLng = Math.max(mxLng, p.lng); });
      const latSpan = Math.max(mxLat - mnLat, 0.004), lngSpan = Math.max((mxLng - mnLng) * Math.cos(this.center.lat * D2R), 0.004);
      this.center = { lat: (mnLat + mxLat) / 2, lng: (mnLng + mxLng) / 2 };
      this.panX = 0; this.panY = 0;
      this.scale = clamp(Math.min(this.w / (lngSpan * 1.5), this.h / (latSpan * 1.5)), 2600, 260000);
      this.invalidate();
    }
    setCity(id) {
      this.city = D.CITIES[id] || D.CITIES.addis;
      this.opts.city = id;
      this.center = { lat: this.city.viewLat || this.city.lat, lng: this.city.lng };
      this.scale = this.city.scale; this.panX = 0; this.panY = 0;
      this.landmarks = D.LANDMARKS[id] || [];
      this.roads = [];
      this.suggestedTrack = null;
      this.invalidate();
    }
    setOptions(o) {
      Object.assign(this.opts, o);
      if (o.filter !== undefined) {  }
      this.invalidate();
    }
    setLive(idx) { this.liveIndex = idx; if (!this.animating) this.render(); }
    toggleReplay() {
      if (!this.replay.enabled) return;
      this.replay.playing = !this.replay.playing;
      if (this.replay.playing) {
        if (this.replay.t >= 0.999) this.replay.t = 0;
        this.animating = true; this.tick();
      } else { this.animating = false; this.render(); }
      return this.replay.playing;
    }
    tick() {
      if (!this.animating || this.dead) return;
      if (this.replay.playing) {
        this.replay.t += 1 / (this.replay.seconds * 60);
        if (this.replay.t >= 1) this.replay.t = 0;
        const bar = $('.replay-bar span');
        if (bar) bar.style.width = (this.replay.t * 100).toFixed(1) + '%';
      }
      this.render();
      requestAnimationFrame(() => this.tick());
    }
  }

  const tooltip = () => $('#mapTooltip');
  function showTooltip(x, y, html) {
    const el = tooltip(); el.innerHTML = html;
    el.style.left = x + 'px'; el.style.top = y + 'px'; el.classList.add('show');
  }
  function hideTooltip() { tooltip().classList.remove('show'); }

  function mapWrapHtml(id, compact) {
    return '<div class="map-wrap' + (compact ? ' compact' : '') + '" id="wrap_' + id + '">' +
      '<canvas class="map-canvas"></canvas>' +
      '<div class="map-badge"><span class="live-dot"></span><span class="map-mode">Map</span><span class="map-dist"></span></div>' +
      '<div class="map-controls">' +
      '<button class="map-ctrl" data-map-zoom="1.3" title="Zoom in">' + icon('plus') + '</button>' +
      '<button class="map-ctrl" data-map-zoom="0.77" title="Zoom out">' + icon('minus') + '</button>' +
      '<button class="map-ctrl" data-map-recenter="1" title="Recenter">' + icon('crosshair') + '</button>' +
      '</div>' +
      '<div class="map-legend">' +
      '<div class="lg-row"><span class="lg-line" style="background:var(--run)"></span>Run</div>' +
      '<div class="lg-row"><span class="lg-line" style="background:var(--ride)"></span>Ride</div>' +
      '<div class="lg-row"><span style="color:#12A88A;font-size:12px;line-height:1">●</span> Start <span style="color:var(--accent);font-size:12px;line-height:1;margin-left:6px">●</span> Finish</div>' +
      '</div>' +
      '<div class="map-scale"><span class="map-scale-label">1 km</span><div class="map-scale-bar"></div></div>' +
      '<div class="map-north">N<b>↑</b></div>' +
      '<div class="map-attribution" hidden></div>' +
      '</div>';
  }
  function mapToolbar(opts) {
    const cityOpts = Object.keys(D.CITIES).map(k => '<option value="' + k + '"' + (k === state.city ? ' selected' : '') + '>' + esc(D.CITIES[k].name) + '</option>').join('');
    let s = '<div class="map-toolbar">' +
      '<div><div class="map-title">' + esc(opts.title || t('map.title')) + '</div><div class="map-sub">' + esc(opts.sub || t('map.sub')) + '</div></div>' +
      '<div class="tb-actions">' +
      '<select class="sel" id="citySelect">' + cityOpts + '</select>' +
      '<div class="seg-toggle" data-filter-group>' +
      ['all', 'run', 'ride'].map(f => '<button data-map-filter="' + f + '" class="' + (state.mapFilter === f ? 'active' : '') + '" data-i18n="map.' + (f === 'all' ? 'all' : f === 'run' ? 'run' : 'ride') + '"></button>').join('') +
      '</div>';
    if (opts.heat !== false) s += '<button class="tb-btn' + (state.heat ? ' on' : '') + '" data-map-action="heat">' + icon('heat') + t('map.heat') + '</button>';
    if (opts.replay) s += '<button class="tb-btn" data-map-action="replay" id="replayBtn">' + icon('play') + '<span data-i18n="map.replay"></span></button>';
    if (false) s += '<button class="tb-btn' + (state.terrain ? ' on green' : '') + '" data-map-action="terrain">' + icon('layers') + t('map.terrain') + '</button>';
    if (opts.basemap) {
      s += '<div class="seg-toggle basemap-toggle" aria-label="Map layer">' +
        '<button data-basemap="osm" class="' + (state.basemap === 'osm' ? 'active' : '') + '">' + icon('globe') + ' Street map</button>' +
        '<button data-basemap="offline" class="' + (state.basemap !== 'osm' ? 'active' : '') + '">' + icon('offline') + ' Plain</button></div>';
    }
    s += '</div></div>';
    return s;
  }
  function mountMap(wrapId, options, target) {
    const wrap = $('#' + wrapId);
    if (!wrap) return null;
    if (target === 'modal') {
      if (state.modalMapEngine) state.modalMapEngine.destroy();
      state.modalMapEngine = new MapEngine(wrap, options);
      return state.modalMapEngine;
    }
    if (state.mapEngine) state.mapEngine.destroy();
    state.mapEngine = new MapEngine(wrap, options);
    return state.mapEngine;
  }
  function drawMini(canvas, a) {
    if (!canvas) return;
    const w = canvas.clientWidth || 120, h = canvas.clientHeight || 90, dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = w * dpr; canvas.height = h * dpr;
    const c = canvas.getContext('2d'); c.setTransform(dpr, 0, 0, dpr, 0, 0);
    const dark = document.documentElement.getAttribute('data-theme') === 'dark';
    c.fillStyle = dark ? '#16221D' : '#EDEAE1'; c.fillRect(0, 0, w, h);
    c.strokeStyle = dark ? 'rgba(255,255,255,.05)' : 'rgba(0,0,0,.045)'; c.lineWidth = 1;
    for (let x = 0; x < w; x += 18) { c.beginPath(); c.moveTo(x, 0); c.lineTo(x, h); c.stroke(); }
    for (let y = 0; y < h; y += 18) { c.beginPath(); c.moveTo(0, y); c.lineTo(w, y); c.stroke(); }
    let mnLat = 1e9, mxLat = -1e9, mnLng = 1e9, mxLng = -1e9;
    a.track.forEach(p => { mnLat = Math.min(mnLat, p.lat); mxLat = Math.max(mxLat, p.lat); mnLng = Math.min(mnLng, p.lng); mxLng = Math.max(mxLng, p.lng); });
    const spanX = Math.max(mxLng - mnLng, 1e-5), spanY = Math.max(mxLat - mnLat, 1e-5), pad = 12;
    const px = lng => pad + ((lng - mnLng) / spanX) * (w - pad * 2);
    const py = lat => h - pad - ((lat - mnLat) / spanY) * (h - pad * 2);
    c.beginPath(); a.track.forEach((p, i) => i === 0 ? c.moveTo(px(p.lng), py(p.lat)) : c.lineTo(px(p.lng), py(p.lat)));
    const color = a.type === 'ride' ? '#0E8A6A' : '#FF5A1F';
    c.strokeStyle = color; c.globalAlpha = .22; c.lineWidth = 7; c.lineJoin = 'round'; c.stroke();
    c.globalAlpha = 1; c.lineWidth = 2.2; c.stroke();
    const s = a.track[0], f = a.track[a.track.length - 1];
    [[s, '#12A88A'], [f, '#FF5A1F']].forEach(([p, col]) => { c.beginPath(); c.arc(px(p.lng), py(p.lat), 3.5, 0, Math.PI * 2); c.fillStyle = col; c.fill(); c.strokeStyle = '#fff'; c.lineWidth = 1.5; c.stroke(); });
  }

  function dashHead() {
    const u = meUser();
    const hr = new Date().getHours();
    const greet = hr < 12 ? 'Good morning' : hr < 18 ? 'Good afternoon' : 'Good evening';
    return '<div class="view-head"><div><h1 class="view-title">' + greet + (u ? ', ' + esc(u.displayName || u.username) : '') + '</h1>' +
      '<div class="view-sub">' + esc(D.fmtDate(new Date())) + '</div></div>' +
      '<div class="view-actions"><button class="btn btn-primary" data-nav="record">' + icon('play') + ' Start recording</button></div></div>';
  }
  function myActivities() {
    const id = myId();
    return state.activities.filter(a => id && a.ownerId === id);
  }
  function communityStats() {
    const acts = state.activities || [];
    const athletes = new Set();
    acts.forEach(a => {
      if (a.ownerId) athletes.add(a.ownerId);
      else if (a.athlete && a.athlete.name) athletes.add(a.athlete.name);
    });
    const cities = new Set(acts.map(a => a.city).filter(Boolean));
    const weekStart = Date.now() - 7 * 86400000;
    return {
      athletes: athletes.size,
      totalKm: acts.reduce((sum, a) => sum + (+a.distance || 0), 0),
      cities: cities.size,
      clubs: (state.clubs || []).length,
      runsThisWeek: acts.filter(a => a.date && +a.date >= weekStart).length
    };
  }
  function statsHtml() {
    const mine = myActivities();
    const now = new Date();
    const days = [];
    for (let i = 6; i >= 0; i--) {
      const d0 = new Date(now.getFullYear(), now.getMonth(), now.getDate() - i);
      const d1 = new Date(d0.getFullYear(), d0.getMonth(), d0.getDate() + 1);
      const list = mine.filter(a => a.date >= d0 && a.date < d1);
      days.push({
        km: list.reduce((x, a) => x + a.distance, 0),
        sec: list.reduce((x, a) => x + a.duration, 0),
        gain: list.reduce((x, a) => x + a.gain, 0),
        n: list.length
      });
    }
    const sum = f => days.reduce((x, d) => x + f(d), 0);
    const cards = [
      { key: 'stat.distance', icon: 'route', color: 'var(--run)', val: sum(d => d.km).toFixed(1), unit: 'km', series: days.map(d => d.km), hex: '#FF5A1F' },
      { key: 'stat.time', icon: 'clock', color: '#2F6FED', val: (sum(d => d.sec) / 3600).toFixed(1), unit: 'h', series: days.map(d => d.sec), hex: '#2F6FED' },
      { key: 'stat.elevation', icon: 'mountain', color: 'var(--accent-2)', val: D.fmtNum(sum(d => d.gain)), unit: 'm', series: days.map(d => d.gain), hex: '#0E8A6A' },
      { key: 'stat.activities', icon: 'activity', color: '#E8A700', val: String(sum(d => d.n)), unit: '', series: days.map(d => d.n), hex: '#E8A700' }
    ];
    return '<div class="stats-grid">' + cards.map(c =>
      '<div class="stat-card" style="--sc:' + c.color + '">' +
      '<div class="stat-label">' + icon(c.icon) + t(c.key) + '</div>' +
      '<div class="stat-value">' + c.val + (c.unit ? '<small>' + c.unit + '</small>' : '') + '</div>' +
      '<div class="stat-foot"><span class="stat-note">Last 7 days' + (meUser() ? '' : ' · sign in to see yours') + '</span></div>' +
      '<div class="stat-spark">' + (c.series.some(v => v > 0) ? sparkline(c.series, c.hex) : '') + '</div></div>'
    ).join('') + '</div>';
  }
  function dashboardMapCard() {
    return '<div class="card map-card">' + mapToolbar({ title: t('map.title'), sub: t('map.sub'), replay: true, heat: true }) +
      mapWrapHtml('dash') +
      '<div class="replay-bar"><span></span></div>' +
      '</div>';
  }
  function insightCards() {
    const next = D.HOLIDAYS.map(h => {
      const now = new Date(); let d = new Date(now.getFullYear(), h.month - 1, h.day);
      if (d < new Date(now.getFullYear(), now.getMonth(), now.getDate())) d = new Date(now.getFullYear() + 1, h.month - 1, h.day);
      return Object.assign({}, h, { date: d });
    }).sort((a, b) => a.date - b.date).slice(0, 3);
    const mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '<div class="side-stack">' +
      '<div class="card card-pad"><div class="row" style="margin-bottom:6px">' +
      '<span class="insight-icon" style="background:rgba(232,167,0,.14);color:#E8A700">' + icon('calendar') + '</span>' +
      '<div><div class="insight-title">' + t('card.calendar') + '</div><div class="card-sub">' + t('card.next') + '</div></div></div>' +
      next.map(h => '<div class="holiday"><div class="holiday-date"><b>' + h.date.getDate() + '</b><span>' + mon[h.date.getMonth()] + '</span></div>' +
        '<div><div class="holiday-name">' + esc(h.name) + '</div>' +
        '<div class="holiday-note">' + esc(h.note) + '</div></div></div>').join('') +
      '</div>' +
      '</div>';
  }
  function feedHtml(list, title, viewAll) {
    return '<div class="card" style="margin-top:18px"><div class="card-head" style="padding-bottom:14px">' +
      '<div><div class="card-title">' + esc(title) + '</div><div class="card-sub">' + t('feed.viewAll') + '</div></div>' +
      (viewAll ? '<div class="head-actions"><button class="btn btn-ghost btn-sm" data-nav="activities">' + t('feed.viewAll') + icon('chevron') + '</button></div>' : '') +
      '</div><div class="feed">' +
      list.map(a => '<div class="feed-item">' + avatar(a.athlete) +
        '<div class="feed-body"><div><span class="feed-name">' + esc(a.athlete ? a.athlete.name : 'You') + '</span>' +
        '<span class="feed-when">' + esc(D.relativeDay(a.date)) + ' · ' + esc(a.cityObj.name) + '</span></div>' +
        '<div class="feed-title" data-activity="' + a.id + '">' + esc(a.title) + '</div>' +
        '<div class="feed-note">' + esc(a.note) + '</div>' +
        '<div class="feed-tags">' + (a.tags || []).map(x => '<span class="tag">' + esc(x) + '</span>').join('') + '</div>' +
        '<div class="feed-stats"><span><b>' + a.distance.toFixed(1) + '</b> km</span><span><b>' + D.fmtDuration(a.duration) + '</b></span>' +
        '<span><b>' + D.fmtPace(a.pace) + '</b> /km</span><span><b>+' + D.fmtNum(a.gain) + '</b> m</span>' +
        '<button class="kudos-btn' + (state.kudos.has(a.id) ? ' liked' : '') + '" data-kudos="' + a.id + '">' + icon('kudos') + (a.kudos + (state.kudos.has(a.id) ? 1 : 0)) + '</button></div></div>' +
        '<div class="feed-thumb"><canvas data-mini="' + a.id + '"></canvas></div></div>').join('') +
      '</div></div>';
  }
  function quickStartDone() {
    try { return localStorage.getItem('rucha_quickstart_v1') === 'done'; } catch (e) { return false; }
  }
  function quickStartHtml() {
    if (quickStartDone()) return '';
    const steps = [
      ['crosshair', 'Allow location', 'Tap Record and allow precise location. RUCHA reads GPS only while a recording is running — never in the background.'],
      ['record', 'Record your run or ride', 'Keep the phone with you. Distance goals, auto-pause and live GPS accuracy are all on the record screen.'],
      ['shield', 'Keep it private', 'Every activity starts private. Share a single run or open it to friends and the community when you choose.'],
      ['segments', 'Make the community yours', 'Turn a recorded route into a segment, create a club or challenge, make a run card in the gallery and find people by their unique username.']
    ];
    return '<section class="quick-start" aria-labelledby="quickStartTitle">' +
      '<div class="quick-start-head"><span class="quick-start-kicker">' + icon('sparkles') + ' Quick Start</span>' +
      '<button class="quick-start-close" data-action="quickstart-dismiss" aria-label="Dismiss Quick Start">' + icon('close') + '</button></div>' +
      '<div class="quick-start-intro"><h2 id="quickStartTitle">Welcome to RUCHA</h2>' +
      '<p>Four things to know before your first kilometre.</p></div>' +
      '<div class="quick-start-grid">' + steps.map((x, i) =>
        '<div class="quick-step"><span class="quick-step-ic">' + icon(x[0]) + '</span>' +
        '<div><b><em>' + (i + 1) + '</em> ' + x[1] + '</b><p>' + x[2] + '</p></div></div>').join('') +
      '</div>' +
      '<div class="quick-start-foot"><a class="btn btn-primary btn-sm" href="help.html" target="_blank" rel="noopener">' +
      icon('info') + ' Read the full guide</a>' +
      '<a class="btn btn-ghost btn-sm" href="privacy.html" target="_blank" rel="noopener">' + icon('shield') + ' Privacy</a>' +
      '<button class="btn btn-ghost btn-sm" data-action="quickstart-dismiss">' + icon('check') + ' Got it</button></div></section>';
  }
  function viewDashboard() {
    const recent = myActivities().sort((a, b) => b.date - a.date).slice(0, 5);
    const empty = '<div class="card card-pad" style="margin-top:18px"><div class="insight-title">Your activities</div>' +
      '<p class="muted" style="margin:8px 0 14px">' + (meUser() ? 'Nothing recorded yet. Your first run or ride will show up here and on the map.' : 'Sign in to record and see your activities.') + '</p>' +
      '<button class="btn btn-primary btn-sm" data-nav="record">' + icon('play') + ' Start recording</button>' +
      ' <a class="text-link" href="help.html" target="_blank" rel="noopener">How RUCHA works</a></div>';
    return dashHead() + quickStartHtml() + statsHtml() +
      '<div class="dash-grid">' + dashboardMapCard() + insightCards() + '</div>' +
      (recent.length ? feedHtml(recent, t('feed.title'), true) : empty);
  }

  function backendBadge() {
    const b = state.backend || {};
    return b.online
      ? '<span class="pill green">' + icon('check') + ' Saved to ' + esc(b.store === 'postgres' ? 'Postgres' : 'database') + '</span>'
      : '<span class="pill">' + icon('offline') + ' Offline · saved on this device</span>';
  }
  const AUTH = () => window.RUCHA_AUTH;
  function meUser() { const A = AUTH(); return A && A.me ? A.me() : null; }
  function myId() { const u = meUser(); return u && u.profileComplete !== false ? u.id : ''; }
  function myName() { const u = meUser(); return u && u.profileComplete !== false ? u.username : 'You'; }

  function updateAccountChip() {
    const u = meUser(), pending = u && u.profileComplete === false;
    const nm = pending ? 'Finish account' : (u ? u.username : 'Sign in');
    const ini = u ? (pending ? '…' : u.username.slice(0, 2).toUpperCase()) : 'ME';
    const set = (id, v) => { const el = $('#' + id); if (el) el.textContent = v; };
    set('accountAvatar', ini); set('accountName', nm);
    set('sideAvatar', ini);
    set('sideUserName', pending ? 'Finish your account' : (u ? (u.displayName || u.username) : 'You'));
    set('sideUserCity', pending ? 'Choose username & password' : (u ? (u.local ? 'Local account · Addis Ababa' : 'Addis Ababa') : 'Addis Ababa'));
    const b = $('#accountBtn'); if (b) b.classList.toggle('signed-in', !!u && !pending);
    const sb = $('#sideAccountBtn'); if (sb) sb.classList.toggle('signed-in', !!u && !pending);
  }
  function requireAccount(msg) {
    const u = meUser();
    if (u && u.profileComplete !== false) return true;
    toast(msg || (u ? 'Finish creating your account first' : 'Create an account or sign in first'));
    openAccountModal();
    return false;
  }
  function refreshSocial() {
    const A = AUTH();
    if (!A) return Promise.resolve();
    if (!meUser()) { state.social = { incoming: [], outgoing: [], friends: [], shares: [] }; return Promise.resolve(); }
    return Promise.all([A.friendState(), A.shares()]).then(res => {
      state.social = {
        incoming: (res[0] && res[0].incoming) || [], outgoing: (res[0] && res[0].outgoing) || [],
        friends: (res[0] && res[0].friends) || [], shares: res[1] || []
      };
      if ($('#accountBody')) renderAccountBody();
    }).catch(() => {});
  }
  function openAccountModal() {
    const A = AUTH();
    if (!A) return;
    const u = meUser();
    if (!u || u.profileComplete === false) { openAuthScreen(); return; }
    const html = '<div class="modal-head">' +
      '<div class="ch-icon" style="background:#0B6E56">' + icon('users') + '</div>' +
      '<div><h3>Account and privacy</h3><p>Your activities are private until you share them</p></div>' +
      '<button class="modal-close" data-action="close-modal">' + icon('close') + '</button></div>' +
      '<div class="modal-body account-body" id="accountBody"></div>';
    openModal(html, 'account-modal');
    renderAccountBody();
    refreshSocial();
  }

  /* ---------- sign in ---------- */
  const TG_ICON = '<svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true"><path fill="currentColor" d="M21.9 4.3 18.7 19.5c-.2 1.1-.9 1.4-1.8.9l-5-3.7-2.4 2.3c-.3.3-.5.5-1 .5l.4-5.1 9.3-8.4c.4-.4-.1-.6-.6-.2L5.1 13.1.2 11.6c-1.1-.3-1.1-1 .2-1.5L20.2 2.7c.9-.3 1.7.2 1.7 1.6z" transform="translate(1.1 1.4) scale(.9)"/></svg>';
  const APPLE_ICON = '<svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true"><path fill="currentColor" d="M16.7 12.9c0-2.1 1.7-3.1 1.8-3.2-1-1.4-2.5-1.6-3-1.6-1.3-.1-2.5.7-3.1.7-.6 0-1.6-.7-2.7-.7-1.4 0-2.7.8-3.4 2.1-1.5 2.5-.4 6.2 1 8.2.7 1 1.5 2.1 2.6 2 1-.1 1.4-.7 2.7-.7 1.2 0 1.6.7 2.7.6 1.1 0 1.8-1 2.5-2 .8-1.2 1.1-2.3 1.2-2.4-.1 0-2.3-.9-2.3-3zM14.6 6.6c.6-.7 1-1.7.9-2.7-.9 0-1.9.6-2.5 1.3-.6.7-1.1 1.7-.9 2.7 1 .1 2-.5 2.5-1.3z"/></svg>';
  const PROVIDER_LABEL = { telegram: 'Telegram', google: 'Google', apple: 'Apple' };
  const auth = {
    step: 'create', cfg: null, loginId: '', link: '', bot: '', busy: false, error: '',
    form: { displayName: '', username: '', password: '' },
    consent: { acceptPrivacy: false, acceptTerms: false },
    usernameState: '', usernameReason: '', showPassword: false,
    pendingUser: null, provider: '', created: false
  };
  let userCheckTimer = null;

  function authScreenEl() { return $('#authScreen'); }
  function isCompleteUser(u) { return !!u && u.profileComplete !== false; }
  function providerLabel(p) { return PROVIDER_LABEL[p] || 'your account'; }
  function authMinPassword() {
    const A = AUTH();
    return +((auth.cfg && auth.cfg.minPassword) || (A && A.minPassword) || 5);
  }
  function resetAuthConsent() {
    // Consent must be an active choice, so the boxes always start empty.
    auth.consent = { acceptPrivacy: false, acceptTerms: false };
  }
  function userNeedsConsent(u) {
    if (!u || u.profileComplete === false) return false;
    const A = AUTH();
    const cfg = auth.cfg || {};
    const pv = cfg.privacyVersion || (A && A.privacyVersion) || '2026-11-07';
    const tv = cfg.termsVersion || (A && A.termsVersion) || '2026-11-07';
    return u.privacyVersion !== pv || u.termsVersion !== tv;
  }
  function fmtConsentDate(s) {
    if (!s) return '';
    const d = new Date(s);
    if (isNaN(d.getTime())) return '';
    try { return d.toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric' }); }
    catch (e) { return ''; }
  }
  function consentObject() {
    const A = AUTH();
    return {
      acceptPrivacy: !!auth.consent.acceptPrivacy,
      acceptTerms: !!auth.consent.acceptTerms,
      privacyVersion: (auth.cfg && auth.cfg.privacyVersion) || (A && A.privacyVersion) || '2026-11-07',
      termsVersion: (auth.cfg && auth.cfg.termsVersion) || (A && A.termsVersion) || '2026-11-07'
    };
  }
  function privacyLinksHtml() {
    return '<a href="privacy.html" target="_blank" rel="noopener">Privacy Policy</a> and <a href="terms.html" target="_blank" rel="noopener">Terms of Use</a>';
  }
  function authBrandSvg(size) {
    return '<svg viewBox="0 0 40 40" width="' + (size || 40) + '" height="' + (size || 40) + '" aria-hidden="true">' +
      '<path d="M8 27 L15 17 L20 22 L27 10 L33 20" fill="none" stroke="#FF5A1F" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/>' +
      '<circle cx="27" cy="10" r="3.4" fill="#E8A700"/><circle cx="8" cy="27" r="2.6" fill="#0E8A6A"/></svg>';
  }
  function authShellHtml() {
    return '<div class="auth-shell">' +
      '<aside class="auth-hero">' +
      '<div class="auth-orb auth-orb-gold" aria-hidden="true"></div>' +
      '<div class="auth-orb auth-orb-green" aria-hidden="true"></div>' +
      '<svg class="auth-hero-route" viewBox="0 0 540 320" aria-hidden="true"><path d="M-10 245 C70 220 90 150 155 168 S255 258 322 214 390 86 470 112 545 190 570 150" fill="none" stroke="rgba(255,255,255,.22)" stroke-width="2.4" stroke-dasharray="1 10" stroke-linecap="round"/></svg>' +
      '<div class="auth-brand">' + authBrandSvg(42) + '<div><b>RUCHA</b><span>ETHIOPIA</span></div></div>' +
      '<div class="auth-hero-copy"><span class="auth-eyebrow">RUN · RIDE · ETHIOPIA</span>' +
      '<h2>Every road is a route.</h2>' +
      '<p>Record with GPS, climb the segments around you, and keep your miles with your people.</p></div>' +
      '<div class="auth-chips"><span>' + icon('route') + ' GPS routes</span><span>' + icon('segments') + ' Local segments</span><span>' + icon('shield') + ' Private by default</span></div>' +
      '<div class="auth-hero-foot"><span class="auth-flag" aria-hidden="true"><i></i><i></i><i></i></span>Addis Ababa · 2,355 m</div>' +
      '</aside>' +
      '<main class="auth-panel"><div class="auth-card" id="authCard"></div>' +
      '<div class="auth-panel-foot"><a href="help.html" target="_blank" rel="noopener">How it works</a>' +
      '<a href="privacy.html" target="_blank" rel="noopener">Privacy</a>' +
      '<a href="terms.html" target="_blank" rel="noopener">Terms</a></div></main></div>';
  }
  function openAuthScreen(opts) {
    opts = opts || {};
    if (authScreenEl()) {
      if (opts.step) { auth.step = opts.step; renderAuth(); }
      return;
    }
    const el = document.createElement('div');
    el.id = 'authScreen'; el.className = 'auth-screen';
    el.setAttribute('role', 'dialog'); el.setAttribute('aria-modal', 'true'); el.setAttribute('aria-label', 'Join or sign in to RUCHA');
    el.innerHTML = authShellHtml();
    document.body.appendChild(el);
    document.body.classList.add('auth-open');
    el.addEventListener('click', onAuthClick);
    el.addEventListener('input', onAuthInput);
    el.addEventListener('change', onAuthChange);
    el.addEventListener('keydown', onAuthKeydown);

    const A = AUTH();
    auth.cfg = null; auth.error = ''; auth.busy = false; auth.showPassword = false;
    auth.usernameState = ''; auth.usernameReason = '';
    auth.loginId = ''; auth.link = ''; auth.bot = ''; auth.created = false;
    resetAuthConsent();
    const u = meUser();
    const pending = u && !isCompleteUser(u);
    auth.pendingUser = pending ? u : null;
    auth.provider = pending && u.providers && u.providers.length ? u.providers[0] : '';
    auth.form.displayName = pending ? (u.displayName || '') : '';
    auth.form.username = '';
    auth.form.password = '';
    auth.step = pending ? 'complete' : (opts.step || 'create');
    renderAuth();
    (A && A.config ? A.config() : Promise.resolve({})).then(cfg => {
      auth.cfg = cfg || {};
      const active = document.activeElement;
      const focusId = active && active.id;
      renderAuth();
      if (focusId && $('#' + focusId)) { const f = $('#' + focusId); f.focus(); if (f.setSelectionRange && f.value) f.setSelectionRange(f.value.length, f.value.length); }
    });
  }
  function openConsentScreen() { openAuthScreen({ step: 'consent' }); }
  function closeAuthScreen(skipped) {
    const el = authScreenEl();
    if (el) el.remove();
    document.body.classList.remove('auth-open');
    if (skipped) { try { sessionStorage.setItem('rucha_skip_auth', '1'); } catch (e) {} }
  }
  function captureAuthForm() {
    const d = $('#authDisplay'), un = $('#authUsername'), pw = $('#authPassword');
    if (d) auth.form.displayName = d.value;
    if (un) auth.form.username = un.value;
    if (pw) auth.form.password = pw.value;
  }
  function authErr(msg) {
    auth.error = msg || ''; auth.busy = false;
    const e = $('#authError'); if (e) e.textContent = auth.error;
    const b = $('#authSubmit'); if (b) { b.disabled = false; if (b.dataset.label) b.textContent = b.dataset.label; }
  }
  function setAuthBusy(on, label) {
    const b = $('#authSubmit'); if (!b) return;
    if (on) { b.dataset.label = b.textContent; b.disabled = true; b.textContent = label || 'Please wait…'; }
    else { b.disabled = false; if (b.dataset.label) b.textContent = b.dataset.label; }
  }
  function completeOrDone(r) {
    if (r && r.user && r.user.profileComplete === false) {
      auth.pendingUser = r.user;
      auth.provider = (r.user.providers && r.user.providers[0]) || auth.provider;
      auth.form.displayName = r.user.displayName || auth.form.displayName;
      auth.form.username = ''; auth.form.password = '';
      auth.usernameState = ''; auth.usernameReason = '';
      auth.step = 'complete'; auth.error = ''; auth.busy = false; auth.created = true;
      renderAuth();
      return;
    }
    authDone(r);
  }
  function authDone(r) {
    const created = !!(auth.created || (r && r.created));
    auth.created = false;
    closeAuthScreen(false);
    try { sessionStorage.removeItem('rucha_skip_auth'); } catch (e) {}
    const u = meUser();
    const finish = () => {
      if (u) toast(created ? 'Welcome to RUCHA, @' + u.username : 'Signed in as @' + u.username);
      afterAuthChange();
      if (userNeedsConsent(meUser())) openConsentScreen();
    };
    if (created && u) claimAndReload(finish); else finish();
  }
  function claimAndReload(done) {
    const Api = API();
    let claimed = false;
    try { claimed = !!(Api && Api.claimAnonymous && Api.claimAnonymous()); } catch (e) {}
    const uid = myId();
    try {
      const src = 'rucha_gallery_v1_anon', dst = 'rucha_gallery_v1_' + uid;
      const raw = localStorage.getItem(src);
      if (raw && uid) {
        const arr = JSON.parse(raw);
        if (Array.isArray(arr)) {
          let cur = [];
          try { cur = JSON.parse(localStorage.getItem(dst) || '[]'); } catch (e) {}
          const ids = {};
          cur.forEach(x => { if (x && x.id) ids[x.id] = 1; });
          const merged = cur.concat(arr.filter(x => x && !ids[x.id]));
          localStorage.setItem(dst, JSON.stringify(merged));
          localStorage.removeItem(src);
          claimed = true;
        }
      }
    } catch (e) {}
    loadGallery();
    const p = Api && Api.getActivities ? Api.getActivities() : Promise.resolve([]);
    Promise.resolve(p).then(list => {
      (Array.isArray(list) ? list : []).forEach(raw => {
        const a = normalizeActivity(raw);
        if (a && !state.activities.some(x => x.id === a.id)) state.activities.push(a);
      });
    }).catch(() => {}).then(() => {
      if (claimed) toast('Your offline activities now belong to this account');
      done();
    });
  }
  function usernameStatusText() {
    const s = auth.usernameState;
    if (s === 'checking') return 'Checking if @' + esc(auth.form.username) + ' is free…';
    if (s === 'available') return '@' + esc(auth.form.username) + ' is available';
    if (s === 'taken') return auth.usernameReason || 'That username is already taken. Try another.';
    if (s === 'invalid') return auth.usernameReason || 'Use 3-20 lowercase letters, numbers or _.';
    return 'Unique and permanent. Other people will find you by this name.';
  }
  function usernameFieldHtml() {
    const cls = auth.usernameState ? ' ' + auth.usernameState : '';
    return '<label class="auth-field" for="authUsername"><span class="auth-label">Username <em>unique</em></span>' +
      '<div class="auth-input-wrap has-prefix"><span class="auth-prefix">@</span>' +
      '<input id="authUsername" class="auth-input" type="text" inputmode="text" maxlength="20" autocomplete="username" autocapitalize="none" spellcheck="false" placeholder="selam_runs" value="' + esc(auth.form.username) + '"></div>' +
      '<span class="auth-hint' + cls + '" id="authUserStatus">' + usernameStatusText() + '</span></label>';
  }
  function passwordFieldHtml() {
    return '<label class="auth-field" for="authPassword"><span class="auth-label">Password <em>' + authMinPassword() + '+ characters</em></span>' +
      '<div class="auth-input-wrap has-action"><input id="authPassword" class="auth-input" type="' + (auth.showPassword ? 'text' : 'password') + '" autocomplete="new-password" placeholder="At least ' + authMinPassword() + ' characters" value="' + esc(auth.form.password) + '">' +
      '<button class="auth-eye" id="authPasswordEye" data-auth="toggle-password" type="button" aria-label="' + (auth.showPassword ? 'Hide password' : 'Show password') + '">' + icon(auth.showPassword ? 'eyeOff' : 'eye') + '</button></div>' +
      '<span class="auth-hint">Use letters and numbers. You can show it while typing.</span></label>';
  }
  function displayFieldHtml() {
    return '<label class="auth-field" for="authDisplay"><span class="auth-label">Display name</span>' +
      '<div class="auth-input-wrap"><input id="authDisplay" class="auth-input" type="text" maxlength="48" autocomplete="name" placeholder="Your display name" value="' + esc(auth.form.displayName) + '"></div>' +
      '<span class="auth-hint">This is the name your friends see on your profile and activities.</span></label>';
  }
  function consentBlockHtml() {
    return '<label class="auth-consent"><input type="checkbox" id="authConsent"' + (auth.consent.acceptPrivacy && auth.consent.acceptTerms ? ' checked' : '') + '>' +
      '<span class="auth-check" aria-hidden="true">' + icon('check') + '</span>' +
      '<span>I accept the ' + privacyLinksHtml() + '. I understand that GPS is used only when I start a recording.</span></label>';
  }
  function authErrorHtml() {
    return '<p class="auth-error" id="authError" role="alert">' + esc(auth.error) + '</p>';
  }
  function socialBlockHtml(offline, login) {
    if (offline) {
      return '<div class="auth-note">' + icon('offline') + '<span>The RUCHA server is offline. This account will be stored on this device and still works without internet.</span></div>';
    }
    const cfg = auth.cfg;
    if (!cfg) return '<div class="auth-socials auth-socials-loading"><span></span><span></span></div>';
    const hasTg = !!cfg.telegram, hasG = !!cfg.google, hasA = !!cfg.apple;
    if (!hasTg && !hasG && !hasA) {
      return '<div class="auth-note">' + icon('info') + '<span>Social sign-in is not set up on this server yet. ' +
        (login ? 'Sign in with your username below' : 'Create a username below') +
        ', or read <a href="help.html" target="_blank" rel="noopener">how RUCHA works</a>.</span></div>';
    }
    let h = '<div class="auth-socials">';
    if (hasTg) {
      h += '<button class="auth-tg" data-auth="telegram" type="button">' + TG_ICON +
        '<span class="auth-tg-text">Continue with Telegram</span><span class="auth-tg-badge">Recommended</span></button>';
    }
    if (hasG || hasA) {
      h += '<div class="auth-social-row' + (hasG && hasA ? ' two' : '') + '">';
      if (hasG) h += '<div id="googleBtn" class="auth-google"></div>';
      if (hasA) {
        const secure = location.protocol === 'https:';
        h += '<button class="auth-apple" type="button"' + (secure ? ' data-auth="apple"' : ' disabled title="Apple sign-in needs an HTTPS site"') + '>' +
          APPLE_ICON + '<span>Continue with Apple</span></button>';
      }
      h += '</div>';
      if (hasA && location.protocol !== 'https:') h += '<p class="auth-hint">Apple sign-in turns on when RUCHA is served over HTTPS with Apple credentials.</p>';
    }
    h += '</div>';
    return h;
  }
  function authSwitchHtml(login) {
    return '<p class="auth-switch">' + (login
      ? 'New to RUCHA? <button class="auth-link" data-auth="create" type="button">Create an account</button>'
      : 'Already have a RUCHA account? <button class="auth-link" data-auth="login" type="button">Sign in</button>') + '</p>';
  }
  function authFootHtml() {
    return '<p class="auth-offline-link"><button class="auth-link-muted" data-auth="skip" type="button">Use without an account</button> · saved on this device</p>';
  }
  function createCardHtml(offline) {
    return '<div class="auth-card-head"><span class="auth-kicker">' + (offline ? 'On this device' : 'Join RUCHA') + '</span>' +
      '<h1>Create your account</h1>' +
      '<p class="auth-lead">One username, one password. Your activities and routes belong to this account.</p></div>' +
      socialBlockHtml(offline) +
      '<div class="auth-divider"><span>or choose a username</span></div>' +
      '<div class="auth-form">' + displayFieldHtml() + usernameFieldHtml() + passwordFieldHtml() + consentBlockHtml() + authErrorHtml() +
      '<button class="auth-submit" id="authSubmit" data-auth="create-submit" type="button">' + icon('check') + 'Create account</button></div>' +
      authSwitchHtml(false) + authFootHtml();
  }
  function loginCardHtml(offline) {
    return '<div class="auth-card-head"><span class="auth-kicker">Welcome back</span>' +
      '<h1>Sign in to RUCHA</h1>' +
      '<p class="auth-lead">Use the username you created. It is not case sensitive.</p></div>' +
      socialBlockHtml(offline, true) +
      '<div class="auth-divider"><span>or use your password</span></div>' +
      '<div class="auth-form">' +
      '<label class="auth-field" for="authUsername"><span class="auth-label">Username</span><div class="auth-input-wrap has-prefix"><span class="auth-prefix">@</span>' +
      '<input id="authUsername" class="auth-input" type="text" maxlength="20" autocomplete="username" autocapitalize="none" spellcheck="false" placeholder="selam_runs" value="' + esc(auth.form.username) + '"></div></label>' +
      passwordFieldHtml() + authErrorHtml() +
      '<button class="auth-submit" id="authSubmit" data-auth="login-submit" type="button">' + icon('check') + 'Sign in</button></div>' +
      authSwitchHtml(true) + authFootHtml();
  }
  function completeCardHtml() {
    const u = auth.pendingUser || meUser() || {};
    const label = providerLabel(auth.provider);
    return '<div class="auth-card-head"><span class="auth-kicker">' + icon('check') + ' ' + esc(label) + ' verified</span>' +
      '<h1>Choose your RUCHA name</h1>' +
      '<p class="auth-lead">You are verified with ' + esc(label) + '. Pick the unique username and password you will use from now on. You only do this once.</p></div>' +
      (u.displayName ? '<div class="auth-provider-chip"><span>' + esc(String(u.displayName).slice(0, 2).toUpperCase()) + '</span><div><b>' + esc(u.displayName) + '</b><small>Verified with ' + esc(label) + '</small></div></div>' : '') +
      '<div class="auth-form">' + displayFieldHtml() + usernameFieldHtml() + passwordFieldHtml() + consentBlockHtml() + authErrorHtml() +
      '<button class="auth-submit" id="authSubmit" data-auth="complete-submit" type="button">' + icon('check') + 'Finish creating account</button></div>' +
      '<p class="auth-fine">Your username is permanent. Your activities will be tied to this account, not to ' + esc(label) + '.</p>' +
      '<p class="auth-switch"><button class="auth-link" data-auth="switch" type="button">Use a different sign-in method</button></p>';
  }
  function telegramCardHtml() {
    return '<button class="auth-back" data-auth="back" type="button">← Back</button>' +
      '<div class="auth-card-head"><span class="auth-kicker">Telegram</span><h1>Check Telegram</h1>' +
      '<p class="auth-lead">The code is sent in the chat, so RUCHA never needs your phone number or email.</p></div>' +
      '<ol class="auth-steps"><li>Open the RUCHA bot in Telegram and press <b>Start</b>.</li><li>The bot sends you a 6 digit code.</li><li>Type that code below.</li></ol>' +
      '<a class="auth-tg auth-tg-open" href="' + esc(auth.link) + '" target="_blank" rel="noopener">' + TG_ICON + '<span>Open @' + esc(auth.bot) + '</span></a>' +
      '<label class="auth-field" for="authCode"><span class="auth-label">6 digit code</span>' +
      '<div class="auth-input-wrap"><input id="authCode" class="auth-input auth-code" inputmode="numeric" pattern="[0-9]*" maxlength="6" autocomplete="one-time-code" placeholder="000000"></div></label>' +
      authErrorHtml() +
      '<button class="auth-submit" id="authSubmit" data-auth="verify" type="button">' + icon('check') + 'Sign in</button>' +
      '<p class="auth-fine">Code not coming? <button class="auth-link" data-auth="restart" type="button">Start again</button></p>';
  }
  function privacyCardHtml(kind) {
    const upgrade = kind === 'consent';
    return '<div class="auth-card-head"><span class="auth-kicker">' + icon('shield') + ' Your privacy</span>' +
      '<h1>' + (upgrade ? 'Review the updated notice' : 'Before you start') + '</h1>' +
      '<p class="auth-lead">' + (upgrade ? 'We updated the privacy notice. Please review and accept the current version to keep using RUCHA.' : 'RUCHA works with your location and your activities, so here is the short version before you enter.') + '</p></div>' +
      '<ul class="auth-privacy-list">' +
      '<li>' + icon('map') + '<span><b>Location only while recording.</b> GPS points are saved with the activity you start, never in the background.</span></li>' +
      '<li>' + icon('shield') + '<span><b>Private by default.</b> Your routes are visible to you until you choose friends or public.</span></li>' +
      '<li>' + icon('profile') + '<span><b>One account.</b> Your username is unique, and your password protects the account on every device.</span></li>' +
      '<li>' + icon('offline') + '<span><b>No ads, no selling data.</b> Offline data stays on this device until you sign in.</span></li></ul>' +
      '<label class="auth-consent"><input type="checkbox" id="privacyGateCheck">' +
      '<span class="auth-check" aria-hidden="true">' + icon('check') + '</span>' +
      '<span>I accept the ' + privacyLinksHtml() + '.</span></label>' + authErrorHtml() +
      '<button class="auth-submit" id="authSubmit" data-auth="privacy-accept" type="button">' + icon('check') + (upgrade ? 'Accept and continue' : 'Accept and enter RUCHA') + '</button>' +
      (upgrade ? '<p class="auth-switch"><button class="auth-link" data-auth="signout" type="button">Sign out instead</button></p>'
        : '<p class="auth-switch"><button class="auth-link" data-auth="back" type="button">Back to sign in</button></p>');
  }
  function renderAuth() {
    const card = $('#authCard'); if (!card) return;
    const A = AUTH();
    const offline = !!(A && A.mode && A.mode() === 'local');
    if (auth.step === 'telegram') {
      card.innerHTML = telegramCardHtml();
      const inp = $('#authCode'); if (inp) inp.focus();
      return;
    }
    if (auth.step === 'complete') {
      card.innerHTML = completeCardHtml();
      refreshUsernameStatus();
      return;
    }
    if (auth.step === 'login') {
      card.innerHTML = loginCardHtml(offline);
      mountProviders();
      refreshUsernameStatus();
      return;
    }
    if (auth.step === 'privacy' || auth.step === 'consent') {
      card.innerHTML = privacyCardHtml(auth.step);
      return;
    }
    card.innerHTML = createCardHtml(offline);
    mountProviders();
    refreshUsernameStatus();
  }
  function mountProviders() {
    const cfg = auth.cfg || {};
    if (cfg.google) mountGoogle(cfg.googleId);
  }
  function mountGoogle(clientId) {
    const draw = () => {
      const host = $('#googleBtn'); if (!host || !window.google || !google.accounts || !google.accounts.id) return;
      google.accounts.id.initialize({
        client_id: clientId, ux_mode: 'popup', auto_select: false,
        callback: resp => {
          if (!resp || !resp.credential) { authErr('Google did not return a sign-in. Try again.'); return; }
          setAuthBusy(true, 'Checking…');
          AUTH().googleSignIn(resp.credential).then(completeOrDone).catch(e => { setAuthBusy(false); authErr(e.message); });
        }
      });
      const parent = host.parentElement;
      const w = Math.min(400, Math.max(160, (parent ? parent.clientWidth : 320) - 2));
      google.accounts.id.renderButton(host, { theme: 'outline', size: 'large', text: 'continue_with', shape: 'rectangular', logo_alignment: 'left', width: w });
    };
    if (window.google && google.accounts && google.accounts.id) { draw(); return; }
    let sc = document.getElementById('gsiScript');
    if (!sc) {
      sc = document.createElement('script');
      sc.id = 'gsiScript'; sc.src = 'https://accounts.google.com/gsi/client'; sc.async = true;
      sc.onerror = () => authErr('Could not load Google sign-in. Check your connection.');
      document.head.appendChild(sc);
    }
    sc.addEventListener('load', draw);
  }
  function ensureApple(cb) {
    if (window.AppleID && window.AppleID.auth) { cb(); return; }
    let sc = document.getElementById('appleIdScript');
    if (sc) { sc.addEventListener('load', cb, { once: true }); return; }
    sc = document.createElement('script');
    sc.id = 'appleIdScript';
    sc.src = 'https://appleid.cdn-apple.com/appleauth/static/jsapi/appleid/1/en_US/appleid.auth.js';
    sc.async = true;
    sc.onload = cb;
    sc.onerror = () => authErr('Could not load Apple sign-in. Check your connection.');
    document.head.appendChild(sc);
  }
  function startApple() {
    if (location.protocol !== 'https:') { authErr('Apple sign-in works only on an HTTPS site.'); return; }
    const cfg = auth.cfg || {};
    if (!cfg.apple || !cfg.appleClientId) { authErr('Apple sign-in is not set up on this server yet.'); return; }
    ensureApple(() => {
      window.AppleID.auth.init({
        clientId: cfg.appleClientId,
        scope: 'name email',
        redirectURI: location.origin + location.pathname,
        usePopup: true
      });
      window.AppleID.auth.signIn().then(res => {
        const authz = res && res.authorization;
        const token = authz && (authz.id_token || authz.idToken || authz.code);
        if (!token) { authErr('Apple did not return a sign-in. Try again.'); return; }
        let name = '';
        if (res && res.user && res.user.name) {
          name = [res.user.name.firstName, res.user.name.lastName].filter(Boolean).join(' ');
        }
        setAuthBusy(true, 'Checking…');
        AUTH().appleSignIn(token, name).then(completeOrDone).catch(e => { setAuthBusy(false); authErr(e.message); });
      }).catch(err => {
        if (err && (err.error === 'popup_closed_by_user' || err.error === 'user_cancelled_authorize')) return;
        authErr((err && err.message) || 'Apple sign-in was cancelled.');
      });
    });
  }
  function scheduleUsernameCheck() {
    clearTimeout(userCheckTimer);
    const u = auth.form.username;
    if (!u) { auth.usernameState = ''; auth.usernameReason = ''; refreshUsernameStatus(); return; }
    const A = AUTH();
    const re = (A && A.usernameRule) || /^[a-z0-9_]{3,20}$/;
    if (!re.test(u)) {
      auth.usernameState = 'invalid';
      auth.usernameReason = 'Use 3-20 lowercase letters, numbers or _.';
      refreshUsernameStatus();
      return;
    }
    auth.usernameState = 'checking'; auth.usernameReason = ''; refreshUsernameStatus();
    userCheckTimer = setTimeout(() => {
      (A && A.usernameAvailable ? A.usernameAvailable(u) : Promise.resolve({ available: true }))
        .then(r => {
          if (u !== auth.form.username) return;
          auth.usernameState = r && r.available ? 'available' : 'taken';
          auth.usernameReason = (r && r.reason) || '';
          refreshUsernameStatus();
        }).catch(() => { auth.usernameState = ''; auth.usernameReason = ''; refreshUsernameStatus(); });
    }, 350);
  }
  function refreshUsernameStatus() {
    const el = $('#authUserStatus'); if (!el) return;
    el.className = 'auth-hint' + (auth.usernameState ? ' ' + auth.usernameState : '');
    el.textContent = usernameStatusText();
  }
  function onAuthInput(e) {
    const t = e.target;
    if (t.id === 'authUsername') {
      const clean = t.value.toLowerCase().replace(/[^a-z0-9_]/g, '').slice(0, 20);
      if (clean !== t.value) t.value = clean;
      auth.form.username = clean;
      scheduleUsernameCheck();
      return;
    }
    if (t.id === 'authPassword') { auth.form.password = t.value; return; }
    if (t.id === 'authDisplay') { auth.form.displayName = t.value; return; }
    if (t.id === 'authCode') {
      t.value = t.value.replace(/\D+/g, '').slice(0, 6);
      if (t.value.length === 6 && !auth.busy) submitCode();
    }
  }
  function onAuthChange(e) {
    if (e.target.id === 'authConsent' || e.target.id === 'privacyGateCheck') {
      auth.consent.acceptPrivacy = e.target.checked;
      auth.consent.acceptTerms = e.target.checked;
    }
  }
  function onAuthKeydown(e) {
    if (e.key === 'Escape') {
      if (auth.step === 'telegram' || auth.step === 'privacy') { auth.step = 'create'; auth.error = ''; renderAuth(); }
      else if (auth.step === 'create' || auth.step === 'login') attemptSkip();
      return;
    }
    if (e.key !== 'Enter' || e.target.tagName === 'TEXTAREA') return;
    if (e.target.id === 'authCode') { e.preventDefault(); submitCode(); return; }
    if (auth.step === 'create') { e.preventDefault(); submitCreate(); }
    else if (auth.step === 'login') { e.preventDefault(); submitLogin(); }
    else if (auth.step === 'complete') { e.preventDefault(); submitComplete(); }
  }
  function submitCreate() {
    if (auth.busy) return;
    const A = AUTH();
    const display = auth.form.displayName.trim();
    const username = auth.form.username.trim().toLowerCase();
    const password = auth.form.password;
    if (!display) { authErr('Enter the name you want on your profile.'); return; }
    if (!A.usernameRule.test(username)) { authErr('Username must be 3-20 characters: letters, numbers and _ only.'); return; }
    if (auth.usernameState === 'taken') { authErr(auth.usernameReason || 'That username is already taken. Try another.'); return; }
    if (password.length < authMinPassword()) { authErr('Password must be at least ' + authMinPassword() + ' characters.'); return; }
    if (!auth.consent.acceptPrivacy || !auth.consent.acceptTerms) { authErr('Accept the Privacy Policy and Terms of Use to create an account.'); return; }
    auth.busy = true; auth.error = ''; setAuthBusy(true, 'Creating account…');
    A.register(username, password, display, consentObject()).then(r => {
      auth.busy = false; auth.created = true; authDone(r);
    }).catch(e => {
      if (/taken/i.test(e.message)) { auth.usernameState = 'taken'; auth.usernameReason = e.message; refreshUsernameStatus(); }
      setAuthBusy(false); authErr(e.message);
    });
  }
  function submitLogin() {
    if (auth.busy) return;
    const A = AUTH();
    const username = auth.form.username.trim().toLowerCase();
    const password = auth.form.password;
    if (!username) { authErr('Enter your username.'); return; }
    if (!password) { authErr('Enter your password.'); return; }
    auth.busy = true; auth.error = ''; setAuthBusy(true, 'Signing in…');
    A.login(username, password).then(r => { auth.busy = false; auth.created = false; authDone(r); })
      .catch(e => { setAuthBusy(false); authErr(e.message); });
  }
  function submitComplete() {
    if (auth.busy) return;
    const A = AUTH();
    const display = auth.form.displayName.trim();
    const username = auth.form.username.trim().toLowerCase();
    const password = auth.form.password;
    if (!display) { authErr('Enter the name you want on your profile.'); return; }
    if (!A.usernameRule.test(username)) { authErr('Username must be 3-20 characters: letters, numbers and _ only.'); return; }
    if (auth.usernameState === 'taken') { authErr(auth.usernameReason || 'That username is already taken. Try another.'); return; }
    if (password.length < authMinPassword()) { authErr('Password must be at least ' + authMinPassword() + ' characters.'); return; }
    if (!auth.consent.acceptPrivacy || !auth.consent.acceptTerms) { authErr('Accept the Privacy Policy and Terms of Use to finish your account.'); return; }
    auth.busy = true; auth.error = ''; setAuthBusy(true, 'Finishing…');
    A.completeProfile(username, password, display, consentObject()).then(r => {
      auth.busy = false; auth.created = true; authDone(r);
    }).catch(e => {
      if (/taken/i.test(e.message)) { auth.usernameState = 'taken'; auth.usernameReason = e.message; refreshUsernameStatus(); }
      setAuthBusy(false); authErr(e.message);
    });
  }
  function submitCode() {
    const inp = $('#authCode'); if (!inp) return;
    const code = inp.value.trim();
    if (code.length !== 6) { authErr('Enter the 6 digit code from Telegram.'); return; }
    auth.busy = true; auth.error = '';
    setAuthBusy(true, 'Checking…');
    AUTH().telegramVerify(auth.loginId, code).then(r => {
      auth.busy = false;
      completeOrDone(r);
    }).catch(e => {
      setAuthBusy(false); authErr(e.message);
      const i = $('#authCode'); if (i) { i.value = ''; i.focus(); }
    });
  }
  function startTelegram() {
    if (auth.busy) return;
    auth.busy = true; auth.error = '';
    const b = $('#authCard').querySelector('[data-auth="telegram"]');
    if (b) b.disabled = true;
    AUTH().telegramStart().then(r => {
      auth.loginId = r.loginId; auth.link = r.link; auth.bot = r.bot;
      auth.step = 'telegram'; auth.busy = false;
      renderAuth();
      try { window.open(r.link, '_blank', 'noopener'); } catch (e) {}
    }).catch(e => {
      auth.busy = false; auth.step = 'create'; renderAuth(); authErr(e.message);
    });
  }
  function attemptSkip() {
    captureAuthForm();
    const A = AUTH();
    if (A && A.hasCurrentConsent && A.hasCurrentConsent()) closeAuthScreen(true);
    else { auth.step = 'privacy'; auth.error = ''; renderAuth(); }
  }
  function acceptPrivacyGate() {
    const chk = $('#privacyGateCheck');
    if (!chk || !chk.checked) { authErr('Tick the box to accept the Privacy Policy and Terms of Use.'); return; }
    const A = AUTH();
    const consent = consentObject();
    consent.acceptPrivacy = true;
    consent.acceptTerms = true;
    auth.busy = true; auth.error = ''; setAuthBusy(true, 'Saving…');
    if (auth.step === 'consent') {
      A.acceptConsent(consent).then(() => {
        auth.busy = false; closeAuthScreen(false); toast('Privacy choices saved'); afterAuthChange();
      }).catch(e => { setAuthBusy(false); authErr(e.message); });
      return;
    }
    A.recordLocalConsent(consent).then(() => {
      auth.busy = false; closeAuthScreen(true);
    }).catch(e => { setAuthBusy(false); authErr(e.message); });
  }
  function onAuthClick(e) {
    const t = e.target.closest('[data-auth]');
    if (!t) return;
    const act = t.getAttribute('data-auth');
    if (act === 'skip') { attemptSkip(); return; }
    if (act === 'telegram') { startTelegram(); return; }
    if (act === 'apple') { startApple(); return; }
    if (act === 'verify') { submitCode(); return; }
    if (act === 'create-submit') { submitCreate(); return; }
    if (act === 'login-submit') { submitLogin(); return; }
    if (act === 'complete-submit') { submitComplete(); return; }
    if (act === 'privacy-accept') { acceptPrivacyGate(); return; }
    if (act === 'toggle-password') {
      auth.showPassword = !auth.showPassword;
      const inp = $('#authPassword');
      if (inp) inp.type = auth.showPassword ? 'text' : 'password';
      t.innerHTML = icon(auth.showPassword ? 'eyeOff' : 'eye');
      t.setAttribute('aria-label', auth.showPassword ? 'Hide password' : 'Show password');
      return;
    }
    if (act === 'login') { captureAuthForm(); auth.step = 'login'; auth.error = ''; auth.usernameState = ''; renderAuth(); return; }
    if (act === 'create') { captureAuthForm(); auth.step = 'create'; auth.error = ''; auth.usernameState = ''; renderAuth(); return; }
    if (act === 'back') { captureAuthForm(); auth.step = 'create'; auth.error = ''; renderAuth(); return; }
    if (act === 'restart') { startTelegram(); return; }
    if (act === 'signout') {
      AUTH().logout().then(() => { closeAuthScreen(false); updateAccountChip(); render(); }).catch(() => {});
      return;
    }
    if (act === 'switch') {
      AUTH().logout().then(() => {
        auth.pendingUser = null; auth.provider = ''; auth.form.username = ''; auth.form.password = '';
        auth.form.displayName = ''; auth.step = 'create'; auth.error = ''; renderAuth();
      }).catch(() => {});
    }
  }
  function renderAccountBody() {
    const A = AUTH(), u = meUser(), box = $('#accountBody');
    if (!A || !box) return;
    if (!u || u.profileComplete === false) { closeModal(); openAuthScreen(); return; }
    const soc = state.social;
    const consentWhen = fmtConsentDate(u.privacyAcceptedAt || u.termsAcceptedAt);
    const consentVersion = u.privacyVersion || (auth.cfg && auth.cfg.privacyVersion) || '';
    const consentStale = userNeedsConsent(u);
    const mine = state.activities.filter(a => !a.ownerId || a.ownerId === u.id);
    const friendRows = soc.friends.map(f =>
      '<div class="soc-row"><span class="soc-avatar">' + esc(f.username.slice(0, 2).toUpperCase()) + '</span>' +
      '<div><b>@' + esc(f.username) + '</b><span>' + esc(f.displayName || f.city || 'RUCHA athlete') + '</span></div>' +
      '<button class="btn btn-ghost btn-sm" data-friend-remove="' + esc(f.id) + '">Remove</button></div>').join('') ||
      '<div class="soc-empty">No friends yet. Add someone by their unique username.</div>';
    const inRows = soc.incoming.map(e =>
      '<div class="soc-row"><span class="soc-avatar">' + esc(e.requesterName.slice(0, 2).toUpperCase()) + '</span>' +
      '<div><b>@' + esc(e.requesterName) + '</b><span>wants to be friends</span></div>' +
      '<button class="btn btn-primary btn-sm" data-friend-accept="' + esc(e.id) + '">Accept</button>' +
      '<button class="btn btn-ghost btn-sm" data-friend-decline="' + esc(e.id) + '">Decline</button></div>').join('');
    const outRows = soc.outgoing.map(e =>
      '<div class="soc-row"><span class="soc-avatar">' + esc(e.addresseeName.slice(0, 2).toUpperCase()) + '</span>' +
      '<div><b>@' + esc(e.addresseeName) + '</b><span>Request pending</span></div></div>').join('');
    const shareRows = soc.shares.map(sh =>
      '<div class="soc-row"><span class="soc-avatar">' + icon('share') + '</span>' +
      '<div><b>' + esc(sh.activityTitle || 'Activity') + '</b><span>' +
      (sh.public ? 'Public link · anyone with the link' : 'Shared with @' + esc(sh.sharedWithName || 'friend')) + '</span></div>' +
      '<button class="btn btn-ghost btn-sm" data-share-remove="' + esc(sh.id) + '">Revoke</button></div>').join('') ||
      '<div class="soc-empty">No shares yet. Your runs stay private.</div>';
    const actOpts = mine.map(a => '<option value="' + esc(a.id) + '">' + esc(a.title) + '</option>').join('');
    box.innerHTML =
      '<div class="acct-profile"><span class="acct-avatar">' + esc(u.username.slice(0, 2).toUpperCase()) + '</span>' +
      '<div><b>@' + esc(u.username) + '</b><span>' + esc(u.displayName || u.username) + ' · ' +
      (u.local ? 'saved on this device' : 'signed in') + '</span></div>' +
      '<button class="btn btn-ghost btn-sm" data-action="auth-logout">Sign out</button></div>' +
      '<div class="acct-section"><div class="insight-title">Add a friend by username</div>' +
      '<div class="acct-inline"><input id="friendUser" class="text-input" placeholder="unique_username">' +
      '<button class="btn btn-secondary btn-sm" data-action="friend-add">Send request</button></div>' +
      (inRows || '') + (outRows || '') + '</div>' +
      '<div class="acct-section"><div class="insight-title">Friends (' + soc.friends.length + ')</div>' + friendRows + '</div>' +
      '<div class="acct-section"><div class="insight-title">Share an activity</div>' +
      '<p class="sensor-note">Everything is private unless you share it or set it to friends/public.</p>' +
      '<div class="acct-inline"><select id="shareActivity" class="text-input">' + actOpts + '</select>' +
      '<button class="btn btn-secondary btn-sm" data-action="share-public">Public link</button></div>' +
      '<div class="acct-inline"><input id="shareUser" class="text-input" placeholder="friend_username">' +
      '<button class="btn btn-secondary btn-sm" data-action="share-friend">Share with friend</button></div>' +
      '<div class="acct-inline"><select id="visibilitySelect" class="text-input">' +
      '<option value="private">Private (only me)</option><option value="friends">Friends</option><option value="public">Public</option></select>' +
      '<button class="btn btn-secondary btn-sm" data-action="set-visibility">Update visibility</button></div>' +
      '</div>' +
      '<div class="acct-section"><div class="insight-title">Active shares</div>' + shareRows + '</div>' +
      '<div class="acct-section"><div class="insight-title">Help &amp; legal</div>' +
      '<div class="acct-links">' +
      '<a class="btn btn-ghost btn-sm" href="help.html" target="_blank" rel="noopener">' + icon('info') + ' How RUCHA works</a>' +
      '<a class="btn btn-ghost btn-sm" href="privacy.html" target="_blank" rel="noopener">' + icon('shield') + ' Privacy</a>' +
      '<a class="btn btn-ghost btn-sm" href="terms.html" target="_blank" rel="noopener">' + icon('profile') + ' Terms</a>' +
      '</div>' +
      '<p class="sensor-note acct-consent">' +
      (consentWhen
        ? 'Privacy and Terms accepted on ' + esc(consentWhen) + (consentVersion ? ' · version ' + esc(consentVersion) : '') + '.'
        : 'Privacy and Terms acceptance is recorded with this account.') +
      '</p>' +
      (consentStale
        ? '<button class="btn btn-primary btn-sm" data-action="review-consent">Review the updated notice</button>'
        : '') +
      '</div>';
  }
  function authAction(act) {
    const A = AUTH();
    if (!A) return;
    const val = id => { const el = $('#' + id); return el ? el.value.trim() : ''; };
    if (act === 'auth-logout') {
      A.logout().then(() => { toast('Signed out'); closeModal(); afterAuthChange(); });
      return;
    }
    if (act === 'friend-add') {
      const n = val('friendUser');
      if (!n) { toast('Enter a username'); return; }
      A.friendRequest(n).then(() => { toast('Friend request sent to @' + n.toLowerCase()); refreshSocial(); })
        .catch(e => toast(e.message));
      return;
    }
    if (act === 'share-public' || act === 'share-friend') {
      const sel = $('#shareActivity');
      const a = sel && state.activities.find(x => x.id === sel.value);
      if (!a) { toast('Choose an activity'); return; }
      if (act === 'share-public') {
        A.addShare(a.id, a.title, '', true).then(() => { toast('Public link created for ' + a.title); refreshSocial(); })
          .catch(e => toast(e.message));
      } else {
        const n = val('shareUser');
        if (!n) { toast('Enter a username'); return; }
        A.addShare(a.id, a.title, n, false).then(() => { toast('Shared with @' + n.toLowerCase()); refreshSocial(); })
          .catch(e => toast(e.message));
      }
      return;
    }
    if (act === 'set-visibility') {
      const sel = $('#shareActivity'), vis = $('#visibilitySelect');
      const a = sel && state.activities.find(x => x.id === sel.value);
      if (!a || !vis) return;
      API().setVisibility(a.id, vis.value);
      a.visibility = vis.value; a.ownerId = myId() || a.ownerId;
      toast('Visibility set to ' + vis.value);
      return;
    }
  }
  function afterAuthChange() {
    updateAccountChip();
    refreshSocial();
    applyActivityPrivacy();
    render();
  }
  function applyActivityPrivacy() {
    const A = AUTH();
    if (!A || !A.canSee) return;
    state.activities = state.activities.filter(a => A.canSee(a));
    state.gallery = state.gallery.filter(g => A.canSee(g));
  }
  function shareButtonsHtml(a) {
    if (!meUser()) return '<button class="btn btn-ghost btn-sm" data-action="open-account">' + icon('shield') + ' Sign in to share</button>';
    return '<button class="btn btn-secondary btn-sm" data-action="quick-share" data-id="' + esc(a.id) + '">' + icon('share') + ' Share / privacy</button>';
  }
  function openQuickShare(id) {
    const a = state.activities.find(x => x.id === id);
    if (!a) return;
    if (!requireAccount()) return;
    openAccountModal();
    setTimeout(() => {
      const sel = $('#shareActivity');
      if (sel) { sel.value = id; renderAccountBody(); }
    }, 60);
  }

  function challengeKind(kind) { return D.CHALLENGE_KINDS.find(k => k.id === kind) || D.CHALLENGE_KINDS[0]; }
  function hasRoute(c) { return c && c.startLat != null && c.startLng != null; }
  function challengeTarget(c) {
    const bits = [];
    if (c.targetKm > 0) bits.push(D.fmtNum(c.targetKm) + ' km');
    if (c.targetSeconds > 0) bits.push('under ' + D.fmtDuration(c.targetSeconds));
    if (c.targetElevationM > 0) bits.push('+' + D.fmtNum(c.targetElevationM) + ' m climb');
    return bits.length ? bits.join(' · ') : 'Community challenge';
  }
  function placeLabel(c, which, reveal) {
    const lat = which === 'start' ? c.startLat : c.endLat;
    const lng = which === 'start' ? c.startLng : c.endLng;
    if (lat == null || lng == null) return '';
    const nm = (which === 'start' ? c.startName : c.endName) || D.nearestPlace(lat, lng).name;
    return esc(nm) + (reveal === false ? '' : ' <span class="coord">' + esc(coord(lat, lng)) + '</span>');
  }
  function challengeCardHtml(c) {
    const k = challengeKind(c.kind);
    const joined = state.joinedChallenges.indexOf(c.id) >= 0 || c.joined;
    const geo = hasRoute(c);
    const visLabel = (D.CHALLENGE_VISIBILITY.find(v => v.id === c.visibility) || {}).label || 'Everyone';
    const visIcon = c.visibility === 'friends' ? 'users' : c.visibility === 'public' ? 'shield' : 'globe';
    const tags = [
      '<span class="ck-badge" style="--ck:' + k.color + '">' + icon(k.icon) + esc(k.label) + '</span>',
      '<span class="pill">' + icon(visIcon) + esc(visLabel) + '</span>',
      c.mode === 'head_to_head' ? '<span class="pill accent">' + icon('bolt') + '1 vs 1 · ' + D.fmtNum(c.targetKm || 5) + ' km</span>' : '',
      geo ? '<span class="pill">' + icon('target') + ' Start geofence ' + (c.geofenceM || 50) + ' m</span>' : ''
    ].filter(Boolean).join('');
    const routeHtml = geo
      ? (joined
        ? '<div class="ch-route">' +
          '<div class="ch-pt"><span class="ch-pin start"></span><div><b>Start</b><span>' + placeLabel(c, 'start', true) + '</span></div></div>' +
          '<div class="ch-line"></div>' +
          '<div class="ch-pt"><span class="ch-pin end"></span><div><b>Destination</b><span>' + placeLabel(c, 'end', true) + '</span></div></div>' +
          '</div>'
        : '<div class="ch-route locked">' + icon('shield') + ' Exact start &amp; destination coordinates are revealed when you join this challenge</div>')
      : '<div class="ch-anywhere">' + icon('globe') + ' No fixed location — enter the distance and run it anywhere in Ethiopia</div>';
    return '<div class="card ch-card">' +
      '<div class="ch-top"><div class="ch-icon" style="background:' + k.color + '">' + icon(k.icon) + '</div>' +
      '<div class="ch-head"><div class="ch-name">' + esc(c.title || 'Untitled challenge') + '</div>' +
      '<div class="ch-desc">' + esc(c.description || k.blurb) + '</div></div></div>' +
      '<div class="ch-tags">' + tags + '</div>' + routeHtml +
      '<div class="ch-meta"><div><b>' + esc(challengeTarget(c)) + '</b><span>Target</span></div>' +
      '<div><b>' + D.fmtNum(c.members || 0) + '</b><span>Joined</span></div>' +
      '<div><b>' + (c.prizeBr ? D.fmtNum(c.prizeBr) + ' Br' : '—') + '</b><span>Prize pool</span></div></div>' +
      '<div class="ch-actions">' +
      '<button class="btn btn-secondary btn-sm" data-challenge-standings="' + esc(c.id) + '">' + icon('trophy') + ' Standings</button>' +
      '<button class="btn btn-secondary btn-sm" data-challenge-detail="' + esc(c.id) + '">' + icon('info') + ' Details</button>' +
      (c.mode === 'head_to_head' && c.inviteStatus === 'pending' && c.opponentId === myId()
        ? '<button class="btn btn-primary btn-sm" data-invite="accept" data-id="' + esc(c.id) + '">Accept duel</button>' +
          '<button class="btn btn-ghost btn-sm" data-invite="decline" data-id="' + esc(c.id) + '">Decline</button>'
        : '<button class="btn btn-secondary btn-sm" data-challenge-record="' + esc(c.id) + '">' + icon('record') + ' Record</button>' +
          '<button class="btn ' + (joined ? 'btn-ghost' : 'btn-primary') + ' btn-sm" data-challenge="' + esc(c.id) + '">' +
          (joined ? icon('check') + ' Joined' : 'Join challenge') + '</button>') +
      '</div></div>';
  }
  function popularAreasHtml() {
    const list = state.popularAreas || [];
    if (!list.length) return '<div class="pa-empty">No runs logged yet. Record an activity to start surfacing popular areas.</div>';
    const max = Math.max.apply(null, list.map(a => a.runCount)) || 1;
    return '<div class="pa-list">' + list.slice(0, 8).map((a, i) =>
      '<button class="pa-row" data-popular="' + i + '">' +
      '<span class="pa-rank">' + (i + 1) + '</span>' +
      '<div class="pa-main"><div class="pa-name">' + esc(a.name || 'Open country') + '<span>' + esc(a.city || 'Ethiopia') + '</span></div>' +
      '<div class="pa-bar"><i style="width:' + (a.runCount / max * 100).toFixed(1) + '%"></i></div></div>' +
      '<div class="pa-count"><b>' + a.runCount + '</b><span>runs</span></div>' +
      '<span class="pa-coord">' + esc(coord(a.lat, a.lng)) + '</span></button>').join('') + '</div>';
  }
  function hallHtml() {
    const list = state.hall || [];
    if (!list.length) return '<div class="pa-empty">Hall of fame is empty — be the first to set a time.</div>';
    return '<div class="hof-list">' + list.map((h, i) =>
      '<div class="hof-row"><span class="hof-rank">' + (i + 1) + '</span>' +
      '<div class="hof-main"><b>' + esc(h.athleteName) + '</b><span>' + esc(h.segmentName) + '</span></div>' +
      '<div class="hof-time">' + D.fmtDuration(h.seconds) + '</div>' +
      '<div class="hof-start"><span>START · ' + esc(coord(h.startLat, h.startLng)) + '</span>' +
      '<b>' + icon('map') + ' ' + esc(h.placeName || 'Open country') + '</b></div></div>').join('') + '</div>';
  }
  function sensorPanelHtml() {
    const S = SENS();
    if (!S) return '';
    const det = state.sensors || { list: [] };
    const hr = S.heart.status(), cad = S.cadence.status(), pw = S.power.status(), fp = S.footpod.status();
    const why = S.bleReason();
    const row = (label, st, action, extra) =>
      '<div class="dev-row"><div><b>' + label + '</b><span>' +
      (st.connected ? esc(st.name || 'Connected') + (extra ? ' · ' + extra : '') : 'Not connected') + '</span></div>' +
      '<button class="btn btn-secondary btn-sm" data-action="' + action + '"' + (why ? ' disabled' : '') + '>' +
      (st.connected ? 'Disconnect' : 'Connect') + '</button></div>';
    const gpsSt = S.gps.status();
    return '<div class="card card-pad sensor-card">' +
      '<div class="sensor-head"><span class="insight-title">Sensors and devices</span>' + backendBadge() + '</div>' +
      '<div class="dev-list">' +
      '<div class="dev-row"><div><b>GPS</b><span>' + (gpsSt.supported ? (gpsSt.secure ? 'Built into this device' : 'Needs an https connection') : 'Not available in this browser') + '</span></div>' +
      '<button class="btn btn-secondary btn-sm" data-action="use-device-gps">Check signal</button></div>' +
      row('Heart rate', hr, 'connect-hr', hr.bpm ? hr.bpm + ' bpm' : '') +
      row('Bike speed and cadence', cad, 'connect-bike', cad.cadence != null ? cad.cadence + ' rpm' : '') +
      row('Power meter', pw, 'connect-power', pw.watts != null ? pw.watts + ' W' : '') +
      row('Running foot pod', fp, 'connect-footpod', fp.cadence != null ? fp.cadence + ' spm' : '') +
      '</div>' +
      (why ? '<p class="sensor-note warn">' + esc(why) + '</p>' : '') +
      '<details class="watch-help"><summary>Using a smartwatch</summary>' +
      '<p>Your watch has to broadcast heart rate over Bluetooth before RUCHA can see it.</p>' +
      '<ul>' +
      '<li><b>Garmin:</b> Settings, Sensors and Accessories, Wrist Heart Rate, Broadcast Heart Rate.</li>' +
      '<li><b>Polar, Coros, Suunto, Wahoo:</b> turn on heart-rate sharing or broadcast in the watch menu.</li>' +
      '<li><b>Samsung Galaxy Watch and Wear OS:</b> use a broadcast app such as HR Broadcast, then connect here.</li>' +
      '<li><b>Apple Watch:</b> it does not broadcast on its own. Use a broadcast app such as Heart Cast or Echo.</li>' +
      '<li>Chest straps and arm bands that use standard Bluetooth work as they are.</li>' +
      '</ul><p>Bluetooth works in Chrome and Edge on Android and desktop. Safari on iPhone does not allow it.</p></details>' +
      '</div>';
  }
  function geofenceHtml() {
    const r = state.rec;
    if (!r.challengeId) return '';
    const c = state.challenges.find(x => x.id === r.challengeId);
    if (!c || !hasRoute(c)) return '';
    const radius = c.geofenceM || 50, ok = r.geofenceOk;
    const dist = r.geofenceDistance != null ? Math.round(r.geofenceDistance) + ' m from start' : 'Waiting for a precise GPS fix';
    return '<div class="geofence ' + (ok ? 'ok' : 'wait') + '" id="geofenceBanner">' +
      '<span class="geo-icon">' + icon(ok ? 'check' : 'crosshair') + '</span>' +
      '<div><b>' + (ok ? 'You are at the starting point — ready to record' : 'Move to the starting point to begin') + '</b>' +
      '<span>' + esc(c.startName || D.nearestPlace(c.startLat, c.startLng).name) + ' · ' + esc(coord(c.startLat, c.startLng)) +
      ' · ' + esc(dist) + ' (allowed within ' + radius + ' m)</span></div>' +
      '</div>';
  }

  function dedupeById(arr) {
    const seen = {}, out = [];
    (arr || []).forEach(x => { if (x && !seen[x.id]) { seen[x.id] = 1; out.push(x); } });
    return out;
  }
  function parseDate(v) {
    if (v instanceof Date) return isNaN(v.getTime()) ? new Date() : v;
    if (v != null && v !== '') { const d = new Date(v); if (!isNaN(d.getTime())) return d; }
    return new Date();
  }
  function athleteFrom(x) {
    if (x.athlete && x.athlete.name) return x.athlete;
    const name = x.athleteName || 'You';
    const initials = (name.split(/\s+/).map(w => w[0]).join('').slice(0, 2) || 'ME').toUpperCase();
    return { id: x.athleteId || 'me', name: name, initials: initials, me: true };
  }
  function cityKeyFor(value) {
    if (!value) return 'addis';
    if (D.CITIES[value]) return value;
    const wanted = String(value).toLowerCase();
    const key = Object.keys(D.CITIES).find(k => D.CITIES[k].name.toLowerCase() === wanted);
    return key || 'addis';
  }
  function segmentCat(gain, km) {
    const gradient = km > 0 ? (+gain || 0) / km : (+gain || 0);
    if (gradient >= 80) return 'HC';
    if (gradient >= 45) return '1';
    if (gradient >= 25) return '2';
    if (gradient >= 12) return '3';
    if (gradient >= 4) return '4';
    return '5';
  }
  function normalizeSegment(x) {
    if (!x || typeof x !== 'object') return null;
    const km = +x.km || 0;
    const gain = x.gain != null ? +x.gain : (x.gainM != null ? +x.gainM : 0);
    const bestSec = x.bestSec != null ? +x.bestSec : (x.bestSeconds != null ? +x.bestSeconds : 0);
    return {
      id: String(x.id || x.ID || ('seg_' + Math.random().toString(36).slice(2, 9))),
      name: x.name || 'Untitled segment', city: cityKeyFor(x.city),
      startLat: x.startLat != null ? +x.startLat : 0, startLng: x.startLng != null ? +x.startLng : 0,
      endLat: x.endLat != null ? +x.endLat : 0, endLng: x.endLng != null ? +x.endLng : 0,
      km: km, gain: Math.round(gain), cat: x.cat || segmentCat(gain, km),
      type: x.type === 'ride' ? 'ride' : 'run',
      bestSec: Math.round(bestSec), attempts: +x.attempts || 0,
      bestAthleteId: x.bestAthleteId || '', bestAthleteName: x.bestAthleteName || '',
      ownerId: x.ownerId || '', ownerName: x.ownerName || '',
      activityId: x.activityId || '', createdAt: x.createdAt || ''
    };
  }
  function toBackendSegment(s) {
    return {
      id: s.id, name: s.name,
      city: (D.CITIES[s.city] || D.CITIES.addis).name,
      startLat: s.startLat, startLng: s.startLng, endLat: s.endLat, endLng: s.endLng,
      km: s.km, gainM: Math.round(s.gain), cat: s.cat, type: s.type,
      bestSeconds: Math.round(s.bestSec || 0), attempts: s.attempts || 0,
      ownerId: s.ownerId || '', ownerName: s.ownerName || '',
      bestAthleteId: s.bestAthleteId || '', bestAthleteName: s.bestAthleteName || '',
      activityId: s.activityId || '', createdAt: s.createdAt || new Date().toISOString()
    };
  }
  function normalizeClub(c) {
    if (!c || typeof c !== 'object') return null;
    return {
      id: String(c.id || c.ID || ('club_' + Math.random().toString(36).slice(2, 9))),
      name: c.name || 'Untitled club', description: c.description || c.desc || '',
      city: c.city || '', type: c.type === 'ride' ? 'ride' : 'run',
      color: c.color || D.PALETTE[Math.abs(String(c.id || c.name || 'club').length) % D.PALETTE.length],
      ownerId: c.ownerId || '', ownerName: c.ownerName || '',
      members: +c.members || 0, joined: !!c.joined, createdAt: c.createdAt || ''
    };
  }
  function normalizeActivity(x) {
    if (!x || typeof x !== 'object') return null;
    const front = x.distance != null && x.duration != null && x.pace != null;
    const track = (Array.isArray(x.track) ? x.track : [])
      .filter(p => p && isFinite(p.lat) && isFinite(p.lng))
      .map(p => ({ lat: +p.lat, lng: +p.lng, ele: isFinite(p.ele) ? +p.ele : 0,
                   d: isFinite(p.d) ? +p.d : 0, t: p.t || 0, accuracy: p.accuracy || 0, hr: p.hr, cad: p.cad, pw: p.pw }));
    const first = track[0] || { lat: D.CITIES.addis.lat, lng: D.CITIES.addis.lng };
    const last = track[track.length - 1] || first;
    const distance = front ? +x.distance : (x.distanceKm != null ? +x.distanceKm : (track.length ? last.d : 0));
    const duration = front ? +x.duration : (x.durationSec != null ? +x.durationSec : 0);
    const pace = front ? +x.pace : (x.paceSecPerKm != null ? +x.paceSecPerKm : D.paceFor(distance, duration));
    const gain = front ? +x.gain : (x.elevationGainM != null ? +x.elevationGainM : D.gainFromTrack(track));
    const calories = front ? +x.calories : (x.calories != null ? +x.calories : D.caloriesFor(distance, duration, gain, x.type));
    const city = x.city || (x.cityObj && x.cityObj.id) || 'addis';
    const cityObj = (x.cityObj && x.cityObj.name) ? x.cityObj : (D.CITIES[city] || D.CITIES.addis);
    const avgHr = x.avgHr != null ? +x.avgHr : null;
    return {
      id: String(x.id || x.ID || ('a_' + Math.random().toString(36).slice(2, 9))),
      title: x.title || 'Activity', type: x.type === 'ride' ? 'ride' : 'run', user: x.user || 'me',
      city: city, cityObj: cityObj,
      km: distance, distance: distance, duration: duration, pace: pace, gain: gain, calories: calories,
      hr: x.hr != null ? +x.hr : avgHr, avgHr: avgHr,
      days: x.days != null ? x.days : 0, seed: x.seed || 1,
      kudos: x.kudos || 0, comments: x.comments || 0,
      note: x.note || (front ? '' : 'Saved in the RUCHA database.'),
      athlete: athleteFrom(x), date: parseDate(x.date || x.startedAt || x.createdAt),
      anchors: x.anchors || [], track: track, tags: x.tags || [],
      startLat: x.startLat != null ? +x.startLat : first.lat,
      startLng: x.startLng != null ? +x.startLng : first.lng,
      endLat: x.endLat != null ? +x.endLat : last.lat,
      endLng: x.endLng != null ? +x.endLng : last.lng,
      gpsAccuracyM: x.gpsAccuracyM != null ? +x.gpsAccuracyM : 0,
      hrSource: x.hrSource || (avgHr != null ? 'Bluetooth HR' : 'none'),
      lineColor: x.lineColor || null, source: x.source || (front ? 'device' : 'database'),
      ownerId: x.ownerId || '', ownerName: x.ownerName || '', visibility: x.visibility || ''
    };
  }
  function toBackendActivity(a) {
    const tr = (a.track || []).map(p => ({ lat: p.lat, lng: p.lng, ele: p.ele || 0, d: p.d || 0, t: p.t || 0, accuracy: p.accuracy || 0, hr: p.hr, cad: p.cad, pw: p.pw }));
    return {
      id: a.id, title: a.title, type: a.type, athleteId: 'me', athleteName: (a.athlete && a.athlete.name) || 'You',
      city: a.city || 'addis',
      startLat: a.startLat != null ? a.startLat : (tr[0] ? tr[0].lat : 0),
      startLng: a.startLng != null ? a.startLng : (tr[0] ? tr[0].lng : 0),
      endLat: a.endLat != null ? a.endLat : (tr.length ? tr[tr.length - 1].lat : 0),
      endLng: a.endLng != null ? a.endLng : (tr.length ? tr[tr.length - 1].lng : 0),
      distanceKm: a.distance, durationSec: Math.round(a.duration), paceSecPerKm: a.pace,
      elevationGainM: Math.round(a.gain), calories: Math.round(a.calories),
      avgHr: a.avgHr != null ? a.avgHr : null, hrSource: a.hrSource || 'none',
      maxHr: a.maxHr != null ? a.maxHr : undefined, avgCadence: a.avgCadence != null ? a.avgCadence : undefined,
      avgPowerW: a.avgPowerW != null ? a.avgPowerW : undefined,
      gpsAccuracyM: a.gpsAccuracyM || 0, source: a.source || 'gps',
      track: tr, startedAt: (a.date instanceof Date ? a.date : new Date()).toISOString(),
      createdAt: new Date().toISOString(),
      ownerId: a.ownerId || myId(), ownerName: a.ownerName || myName(),
      visibility: a.visibility || 'private'
    };
  }
  function normalizeChallenge(c) {
    if (!c || typeof c !== 'object') return null;
    return {
      id: String(c.id || c.ID || ('ch_' + Math.random().toString(36).slice(2, 9))),
      kind: c.kind || 'route', title: c.title || 'Untitled challenge', description: c.description || '',
      startLat: c.startLat != null ? +c.startLat : null, startLng: c.startLng != null ? +c.startLng : null,
      startName: c.startName || '', endLat: c.endLat != null ? +c.endLat : null, endLng: c.endLng != null ? +c.endLng : null,
      endName: c.endName || '', targetKm: +c.targetKm || 0, targetSeconds: +c.targetSeconds || 0,
      targetElevationM: +c.targetElevationM || 0, segmentId: c.segmentId || '', geofenceM: +c.geofenceM || 0,
      prizeBr: +c.prizeBr || 0, members: +c.members || 0, joined: !!c.joined,
      createdBy: c.createdBy || c.ownerName || 'Athlete', endsAt: c.endsAt || '',
      ownerId: c.ownerId || '', ownerName: c.ownerName || '',
      visibility: c.visibility || 'everyone', mode: c.mode || 'open',
      opponentId: c.opponentId || '', opponentName: c.opponentName || '',
      inviteStatus: c.inviteStatus || '', autoStop: !!c.autoStop,
      createdAt: c.createdAt || ''
    };
  }
  function normalizeGallery(g) {
    if (!g || typeof g !== 'object') return null;
    const img = g.dataUrl || g.imageData || '';
    if (!img) return null;
    const meta = g.meta || {
      distance: (g.distanceKm != null ? (+g.distanceKm).toFixed(2) : '0.00'),
      duration: g.duration || '0:00', pace: g.pace || '--:--', city: g.city || 'Addis Ababa'
    };
    return {
      id: String(g.id || g.ID || ('card_' + Math.random().toString(36).slice(2, 9))),
      title: g.title || 'Run card', activityId: g.activityId || '', dataUrl: img, meta: meta,
      created: g.created || (g.createdAt ? Date.parse(g.createdAt) : 0) || Date.now(),
      ownerId: g.ownerId || '', visibility: g.visibility || ''
    };
  }
  function toBackendGallery(g) {
    return {
      id: g.id, title: g.title, activityId: g.activityId, imageData: g.dataUrl,
      distanceKm: parseFloat(g.meta && g.meta.distance) || 0,
      duration: (g.meta && g.meta.duration) || '', city: (g.meta && g.meta.city) || '',
      createdAt: new Date(g.created || Date.now()).toISOString(),
      ownerId: g.ownerId || myId(), visibility: g.visibility || 'private'
    };
  }

  function updateGeofence(lat, lng) {
    const r = state.rec;
    const c = state.challenges.find(x => x.id === r.challengeId);
    if (!c || !hasRoute(c)) { r.geofenceOk = true; return; }
    const dkm = D.haversine([lat, lng], [c.startLat, c.startLng]);
    r.geofenceDistance = dkm * 1000;
    const radius = c.geofenceM || 50;
    const ok = r.geofenceDistance <= radius;
    const changed = ok !== r.geofenceOk;
    r.geofenceOk = ok;
    const banner = $('#geofenceBanner');
    if (banner) {
      banner.className = 'geofence ' + (ok ? 'ok' : 'wait');
      const b = banner.querySelector('b');
      if (b) b.textContent = ok ? 'You are at the starting point — ready to record' : 'Move to the starting point to begin';
      const sub = banner.querySelector('div > span');
      if (sub) sub.textContent = (c.startName || D.nearestPlace(c.startLat, c.startLng).name) + ' · ' +
        coord(c.startLat, c.startLng) + ' · ' + Math.round(r.geofenceDistance) + ' m from start (allowed within ' + radius + ' m)';
      const gi = $('.geo-icon', banner);
      if (gi) gi.innerHTML = icon(ok ? 'check' : 'crosshair');
    }
    const btn = $('[data-rec="start"]');
    if (btn) { btn.disabled = !ok; btn.title = ok ? '' : 'Move to the challenge start first'; }
    if (changed) {
      if (ok) toast('You are at the challenge start — ready to record');
      if (state.view === 'record') render();
    }
  }
  function useDeviceGps() {
    const r = state.rec;
    if (!SENS() || !SENS().gps.available()) { toast('This browser has no GPS. Open RUCHA on your phone.'); return; }
    r.gpsState = 'searching'; refreshGpsPill();
    toast('Checking GPS signal…');
    SENS().gps.probe(8000).then(fix => {
      if (!fix) {
        r.gpsState = 'lost'; refreshGpsPill();
        toast(SENS().gps.status().error || 'No GPS fix yet — move outside with a clear view of the sky');
        return;
      }
      // Paint the first fix immediately, then keep the watch running so the
      // position keeps refining instead of freezing on a coarse network fix.
      const watching = SENS().gps.start(applyGpsFix, gpsWatchError);
      applyGpsFix(fix);
      if (watching) toast('GPS ready · accuracy ±' + Math.round(fix.accuracy || 0) + ' m');
      else toast(SENS().gps.status().error || 'Position found, but live tracking could not start');
    });
  }
  function gpsWatchError(msg, code) {
    if (code === 3) return; // transient timeout while standing still
    state.rec.gpsState = 'lost';
    refreshGpsPill();
    if (msg && (code === 1 || code == null)) toast(msg);
  }
  function primeGps() {
    const r = state.rec;
    if (!SENS() || !SENS().gps.available()) return;
    const g = SENS().gps;
    // Restore the cached fix at once so the map is useful while the phone
    // waits for its first live satellite fix.
    const cached = g.status().last;
    if (cached && (!r.lastFix || (r.lastFix.t || 0) < (cached.t || 0))) {
      r.lastFix = cached;
      r.lastFixAt = cached.t || Date.now();
      if (cached.accuracy != null) r.gpsAccuracy = cached.accuracy;
      // A fix from hours ago is useful as a starting position, but it must not
      // be dressed up as a live strong signal.
      r.gpsState = fixState(cached);
      const eng = state.mapEngine;
      if (eng && state.view === 'record') {
        eng.userFix = cached;
        eng.center = { lat: cached.lat, lng: cached.lng };
        eng.panX = 0; eng.panY = 0;
        eng.scale = Math.max(eng.scale, 16000);
        eng.staticDirty = true;
        eng.render();
      }
    } else if (!r.lastFix) {
      r.gpsState = 'searching';
    } else if (r.gpsState === 'idle') {
      // Coming back after saving a run: reflect how old the retained fix is.
      r.gpsState = fixState(r.lastFix);
    }
    refreshGpsPill();
    // gps.start reuses an existing watch instead of restarting it, so pressing
    // Record no longer throws away the fix we just primed.
    g.start(applyGpsFix, gpsWatchError);
  }
  function gpsQuality(acc) {
    if (acc == null) return 'weak';
    if (acc <= 12) return 'good';
    if (acc <= 25) return 'ok';
    return 'weak';
  }
  function fixState(fix) {
    if (!fix) return 'searching';
    const fresh = Date.now() - (fix.t || 0) <= 60000;
    return fresh ? gpsQuality(fix.accuracy) : 'cached';
  }
  function refreshGpsPill() {
    const el = $('#gpsPill'); if (!el) return;
    const r = state.rec;
    const map = { idle: ['', 'GPS off'], searching: ['', 'Searching for GPS…'], good: ['green', 'GPS strong'], ok: ['green', 'GPS ok'], weak: ['', 'GPS weak'], cached: ['', 'Last GPS fix'], lost: ['', 'No GPS signal'] };
    const m = map[r.gpsState] || map.idle;
    el.className = 'pill ' + m[0];
    el.textContent = m[1] + (r.gpsAccuracy != null && r.gpsState !== 'lost' && r.gpsState !== 'idle' ? ' · ±' + Math.round(r.gpsAccuracy) + ' m' : '');
  }
  function bleFail(kind) {
    const e = SENS()[kind].status().error;
    return e || 'Could not connect';
  }
  function connectHr() {
    if (!SENS()) return;
    const st = SENS().heart.status();
    if (st.connected) {
      SENS().heart.disconnect();
      state.rec.hrAvailable = false; state.rec.hrValue = null; state.rec.hrSamples = [];
      render(); toast('Heart-rate sensor disconnected');
      return;
    }
    SENS().heart.connect(bpm => {
      const r = state.rec;
      r.hrValue = bpm; r.hrAvailable = true;
      if (bpm > r.hrMax) r.hrMax = bpm;
      if (r.status === 'running') r.hrSamples.push(bpm);
      const el = $('#recHR'); if (el) el.textContent = String(Math.round(bpm));
    }).then(connected => {
      state.rec.hrAvailable = !!connected;
      render();
      toast(connected ? 'Heart-rate sensor connected: ' + (SENS().heart.status().name || 'sensor')
                      : bleFail('heart'));
    });
  }
  function connectBike() {
    if (!SENS()) return;
    if (SENS().cadence.status().connected) { SENS().cadence.disconnect(); render(); toast('Cadence sensor disconnected'); return; }
    SENS().cadence.connect(d => {
      const r = state.rec;
      if (d.cadence != null) { r.cadValue = d.cadence; if (r.status === 'running' && d.cadence > 0) r.cadSamples.push(d.cadence); }
      if (d.speed != null) r.bikeSpeed = d.speed;
      const el = $('#recCad'); if (el && r.cadValue != null) el.textContent = String(r.cadValue);
    }).then(ok => { render(); toast(ok ? 'Cadence sensor connected' : bleFail('cadence')); });
  }
  function connectPower() {
    if (!SENS()) return;
    if (SENS().power.status().connected) { SENS().power.disconnect(); render(); toast('Power meter disconnected'); return; }
    SENS().power.connect(w => {
      const r = state.rec;
      r.pwValue = w; if (r.status === 'running') r.pwSamples.push(w);
      const el = $('#recPow'); if (el) el.textContent = String(w);
    }).then(ok => { render(); toast(ok ? 'Power meter connected' : bleFail('power')); });
  }
  function connectFootpod() {
    if (!SENS()) return;
    if (SENS().footpod.status().connected) { SENS().footpod.disconnect(); render(); toast('Foot pod disconnected'); return; }
    SENS().footpod.connect(d => {
      const r = state.rec;
      r.cadValue = d.cadence; if (r.status === 'running' && d.cadence > 0) r.cadSamples.push(d.cadence);
      const el = $('#recCad'); if (el) el.textContent = String(d.cadence);
    }).then(ok => { render(); toast(ok ? 'Foot pod connected' : bleFail('footpod')); });
  }

  function startGpsWatch() {
    if (!SENS()) return false;
    const r = state.rec;
    r.filter = new (SENS().gps.Filter)({
      maxAccuracy: r.type === 'ride' ? 50 : 45,
      maxSpeed: r.type === 'ride' ? 22 : 9,
      minMove: r.type === 'ride' ? 4 : 3
    });
    // Keep the primed fix: it becomes the first point and the map is already
    // centred, instead of clearing everything and waiting for another fix.
    r.gpsState = 'searching'; refreshGpsPill();
    return SENS().gps.start(applyGpsFix, gpsWatchError);
  }
  function applyGpsFix(fix) {
    const r = state.rec;
    if (!isFinite(fix.lat) || !isFinite(fix.lng)) return;
    const first = !r.lastFix;
    r.lastFix = fix; r.lastFixAt = Date.now();
    if (fix.accuracy != null) r.gpsAccuracy = fix.accuracy;
    r.gpsState = gpsQuality(fix.accuracy);
    refreshGpsPill();
    if (state.mapEngine) {
      state.mapEngine.userFix = fix;
      // The first fix zooms the record map to street level; later fixes only
      // follow the runner and leave a zoom level they chose alone.
      if (state.view === 'record' && first && r.status !== 'running' && r.status !== 'paused') {
        state.mapEngine.center = { lat: fix.lat, lng: fix.lng };
        state.mapEngine.panX = 0; state.mapEngine.panY = 0;
        state.mapEngine.scale = Math.max(state.mapEngine.scale, 16000);
        state.mapEngine.staticDirty = true;
      }
    }
    if (r.challengeId) updateGeofence(fix.lat, fix.lng);
    if (r.status !== 'running' || r.mode !== 'gps' || !r.filter) {
      if (state.mapEngine && state.view === 'record') followUser(fix);
      return;
    }
    const res = r.filter.push(fix);
    if (!res.accept) { if (state.mapEngine) followUser(fix); return; }
    const pt = res.point, tr = r.realTrack, prev = tr[tr.length - 1];
    const baseEle = (D.CITIES[state.city] || D.CITIES.addis).baseEle;
    const ele = pt.ele != null ? pt.ele : (prev ? prev.ele : baseEle);
    const d = (prev ? prev.d : 0) + res.stepM / 1000;
    tr.push({
      lat: +pt.lat.toFixed(7), lng: +pt.lng.toFixed(7), ele: +ele.toFixed(1), d: d, t: pt.t,
      accuracy: Math.round(pt.accuracy),
      hr: r.hrValue != null ? Math.round(r.hrValue) : undefined,
      cad: r.cadValue != null ? Math.round(r.cadValue) : undefined,
      pw: r.pwValue != null ? Math.round(r.pwValue) : undefined
    });
    r.track = tr;
    if (state.mapEngine) {
      if (tr.length === 1) {
        state.mapEngine.center = { lat: pt.lat, lng: pt.lng };
        state.mapEngine.panX = 0; state.mapEngine.panY = 0;
        state.mapEngine.scale = Math.max(state.mapEngine.scale, 16000);
        state.mapEngine.staticDirty = true;
      }
      followUser(fix);
    }
    syncLiveMap();
    if (r.autoStop && r.goalKm > 0 && !r.goalHit && d >= r.goalKm * 0.999) {
      r.goalHit = true; r.goalElapsed = (Date.now() - r.startTime - r.pausedTotal) / 1000;
      finishRecorder();
    }
  }
  // keep the runner on screen without fighting manual panning
  function followUser(fix) {
    const eng = state.mapEngine;
    if (!eng || eng.opts.mode !== 'live' || eng.userPanned) return;
    eng.center = { lat: fix.lat, lng: fix.lng };
    eng.panX = 0; eng.panY = 0;
    eng.staticDirty = true;
    if (!eng.animating) eng.render();
  }
  function currentTrack() {
    const r = state.rec;
    return r.realTrack || [];
  }
  function currentMetrics() {
    const r = state.rec, tr = currentTrack();
    const dist = tr.length ? tr[tr.length - 1].d : 0;
    const gain = D.gainFromTrack(tr);
    return { dist: dist, gain: gain, pace: D.paceFor(dist, r.elapsed),
             cal: D.caloriesFor(dist, r.elapsed, gain, r.type), tr: tr };
  }
  function syncLiveMap() {
    const eng = state.mapEngine;
    if (!eng || eng.opts.mode !== 'live') return;
    const tr = currentTrack();
    eng.routes = [{ id: 'live', type: state.rec.type, track: tr,
                    distance: tr.length ? tr[tr.length - 1].d : 0,
                    duration: state.rec.elapsed, gain: 0, title: 'Live' }];
    eng.setLive(Math.max(0, tr.length - 1));
  }
  function computeSplits(tr, elapsed) {
    if (!tr || tr.length < 2) return [];
    const total = tr[tr.length - 1].d, n = Math.floor(total);
    if (n < 1) return [];
    const out = [];
    const hasT = tr[0].t && tr[tr.length - 1].t > tr[0].t;
    const t0 = hasT ? tr[0].t : 0;
    const timeAt = p => hasT ? (p.t - t0) / 1000 : (p.d / Math.max(total, 1e-6)) * Math.max(elapsed, 1);
    let idx = 0, prevTime = 0;
    const baseEle = tr[0].ele || 0;
    for (let km = 1; km <= n; km++) {
      while (idx < tr.length && tr[idx].d < km) idx++;
      const p = tr[Math.min(idx, tr.length - 1)];
      const t = timeAt(p);
      out.push({ km: km, pace: Math.max(1, t - prevTime), elev: p.ele - baseEle });
      prevTime = t;
    }
    return out;
  }

  function viewExplore() {
    const local = state.activities.filter(a => a.city === state.city).slice(0, 6);
    const rows = (local.length ? local : state.activities.slice(0, 6)).map(a =>
      '<div class="club-card" data-route="' + a.id + '" style="cursor:pointer">' +
      '<span class="route-swatch" style="background:' + D.routeColor(a) + '"></span>' +
      '<div style="flex:1"><div class="club-name">' + esc(a.title) + '</div>' +
      '<div class="club-desc">' + esc(a.cityObj.name) + ' · ' + a.distance.toFixed(1) + ' km · +' + D.fmtNum(a.gain) + ' m</div></div>' +
      '<span class="pill">' + D.fmtPace(a.pace) + '/km</span></div>').join('');
    const segRows = state.segments.slice(0, 5).map(s =>
      '<div class="club-card"><span class="seg-cat">' + esc(s.cat) + '</span>' +
      '<div style="flex:1"><div class="club-name">' + esc(s.name) + '</div><div class="club-desc">' + s.km.toFixed(1) + ' km · +' + D.fmtNum(s.gain) + ' m · ' + D.fmtNum(s.attempts) + ' ' + t('seg.attempts') + '</div></div>' +
      '<button class="btn btn-secondary btn-sm" data-segment="' + s.id + '">' + t('seg.leaderboard') + '</button></div>').join('');
    return '<div class="view-head"><div><h1 class="view-title">' + t('nav.explore') + '</h1>' +
      '<div class="view-sub">Routes, popular areas and real street tiles of Ethiopia</div></div>' +
      '<div class="view-actions">' + backendBadge() +
      '<span class="pill accent">' + icon('globe') + D.LANDMARKS[state.city].length + ' landmarks</span></div></div>' +
      '<div class="card map-card" style="min-height:560px">' +
      mapToolbar({ title: 'Explore Ethiopia', sub: 'Drag to pan, scroll to zoom · switch the map underneath the lines', heat: true, replay: false, basemap: true }) +
      mapWrapHtml('explore') + '</div>' +
      '<div class="two-grid" style="margin-top:18px">' +
      '<div class="card"><div class="card-head"><div><div class="card-title">Popular routes</div>' +
      '<div class="card-sub">Click a route to fly the map to it · every line has its own colour</div></div></div>' +
      '<div style="padding:8px 0 4px">' + (rows || '<div class="pa-empty">No routes yet. Record an activity and it will appear here.</div>') + '</div></div>' +
      '<div class="card"><div class="card-head"><div><div class="card-title">Popular running areas</div>' +
      '<div class="card-sub">Ranked by how often that location is used as a run start</div></div></div>' +
      '<div style="padding:12px 18px 18px">' + popularAreasHtml() + '</div></div></div>' +
      '<div class="two-grid" style="margin-top:18px">' +
      '<div class="card"><div class="card-head"><div><div class="card-title">' + t('nav.segments') + '</div><div class="card-sub">' + t('seg.sub') + '</div></div>' +
      '<button class="btn btn-secondary btn-sm" data-action="segment-create">' + icon('plus') + ' Create</button></div>' +
      '<div style="padding:8px 0 4px">' + (segRows || '<div class="pa-empty">No segments yet. Record a run, then create a segment from it.</div>') + '</div></div>' +
      '<div class="card card-pad"><div class="insight-title" style="margin-bottom:10px">' + icon('layers') + ' Two maps, one set of lines</div>' +
      '<p class="insight-text">The offline map is drawn on-device and works with no signal on the Entoto trails. Switch to OpenStreetMap for real street tiles of Ethiopia underneath the exact same GPS lines, start pins and kilometre markers. If tiles load slowly, tap Street map again to retry, or keep the offline overview.</p>' +
      '<div class="hint-row"><span class="pill green">' + icon('check') + ' Distinct route colours</span>' +
      '<span class="pill">' + icon('target') + ' Green start · orange finish</span></div></div></div>';
  }

  function viewActivities() {
    let list = state.activities.slice().sort((a, b) => b.date - a.date);
    if (state.activityFilter !== 'all') list = list.filter(a => a.type === state.activityFilter);
    if (state.search) {
      const q = state.search.toLowerCase();
      list = list.filter(a => (a.title + ' ' + a.cityObj.name + ' ' + (a.tags || []).join(' ')).toLowerCase().includes(q));
    }
    return '<div class="view-head"><div><h1 class="view-title">' + t('act.title') + '</h1>' +
      '<div class="view-sub">' + list.length + ' ' + t('act.title').toLowerCase() + ' · ' + t('common.ethiopia') + '</div></div>' +
      '<div class="view-actions"><div class="seg-toggle">' +
      ['all', 'run', 'ride'].map(f => '<button data-act-filter="' + f + '" class="' + (state.activityFilter === f ? 'active' : '') + '">' +
        (f === 'all' ? t('act.all') : f === 'run' ? t('act.runs') : t('act.rides')) + '</button>').join('') +
      '</div></div></div>' +
      '<div class="card"><div class="table-wrap"><table class="atable"><thead><tr>' +
      '<th>Type</th><th>Activity</th><th>Date</th><th>Distance</th><th>Time</th><th>Pace</th><th>Elev</th><th>Kudos</th>' +
      '</tr></thead><tbody>' +
      list.map(a => '<tr data-activity="' + a.id + '">' +
        '<td>' + typeBadge(a.type) + '</td>' +
        '<td><div class="a-name">' + esc(a.title) + '</div><div class="a-sub">' + esc(a.cityObj.name) + ' · ' + esc(a.athlete ? a.athlete.name : 'You') + '</div></td>' +
        '<td class="muted">' + esc(D.relativeDay(a.date)) + '</td>' +
        '<td class="strong mono">' + a.distance.toFixed(2) + ' km</td>' +
        '<td class="mono">' + D.fmtDuration(a.duration) + '</td>' +
        '<td class="mono">' + D.fmtPace(a.pace) + ' /km</td>' +
        '<td class="mono">+' + D.fmtNum(a.gain) + ' m</td>' +
        '<td>' + icon('kudos') + ' ' + (a.kudos + (state.kudos.has(a.id) ? 1 : 0)) + '</td></tr>').join('') +
      '</tbody></table></div></div>' +
      (list.length === 0 ? '<div class="card card-pad" style="margin-top:14px;text-align:center;color:var(--muted)">' +
        (state.activities.length === 0
          ? '<p style="margin:0 0 14px">No activities yet. Record your first run or ride and it will appear here.</p><button class="btn btn-primary btn-sm" data-nav="record">' + icon('play') + ' Start recording</button>'
          : 'No activities match that search.') + '</div>' : '');
  }

  function viewSegments() {
    const segs = state.segments || [];
    const head = '<div class="view-head"><div><h1 class="view-title">' + t('seg.title') + '</h1><div class="view-sub">' + t('seg.sub') + '</div></div>' +
      '<div class="view-actions"><button class="btn btn-primary btn-sm" data-action="segment-create">' + icon('plus') + ' Create a segment</button></div></div>';
    if (!segs.length) {
      return head + '<div class="gallery-empty card"><div class="gallery-empty-icon">' + icon('segments') + '</div>' +
        '<h3>No segments yet</h3>' +
        '<p>Record a run or ride, then turn it into a segment. Other recordings on the same start and finish will update the course record.</p>' +
        '<button class="btn btn-primary" data-action="segment-create">' + icon('plus') + ' Create your first segment</button>' +
        '<p class="gallery-empty-help"><a class="text-link" href="help.html#segments" target="_blank" rel="noopener">How segments work</a></p></div>';
    }
    const first = segs[0];
    return head +
      '<div class="seg-grid">' + segs.map(s =>
        '<div class="card seg-card" data-segment="' + s.id + '">' +
        '<div class="seg-top"><div class="seg-cat">' + esc(s.cat) + '</div><div><div class="seg-name">' + esc(s.name) + '</div>' +
        '<div class="seg-meta">' + esc((D.CITIES[s.city] || D.CITIES.addis).name) + ' · ' + (s.type === 'ride' ? 'Ride' : 'Run') + '</div></div></div>' +
        '<div class="seg-nums"><div><b>' + s.km.toFixed(1) + '</b><span>km</span></div><div><b>+' + D.fmtNum(s.gain) + '</b><span>m gain</span></div>' +
        '<div><b>' + D.fmtNum(s.attempts) + '</b><span>' + t('seg.attempts') + '</span></div></div>' +
        '<div class="seg-crown">' + icon('trophy') + (s.bestSec
          ? 'Course record: ' + esc(s.bestAthleteName || s.ownerName || 'Athlete') + ' · ' + D.fmtDuration(s.bestSec)
          : 'No time recorded yet') + '</div></div>'
      ).join('') + '</div>' +
      '<div class="card" style="margin-top:18px"><div class="card-head" style="padding-bottom:14px"><div>' +
      '<div class="card-title">Hall of fame</div>' +
      '<div class="card-sub">Course records from segments created by RUCHA athletes</div></div></div>' +
      hallHtml() + '</div>' +
      '<div class="card" style="margin-top:18px"><div class="card-head" style="padding-bottom:14px"><div>' +
      '<div class="card-title">Segment leaderboard — ' + esc(first.name) + '</div>' +
      '<div class="card-sub">' + first.km.toFixed(1) + ' km · +' + D.fmtNum(first.gain) + ' m · ' + D.fmtNum(first.attempts) + ' ' + t('seg.attempts') + '</div></div></div>' +
      leaderRows(first.id, true) + '</div>';
  }
  function leaderRows(segId, withLegend) {
    const s = state.segments.find(x => x.id === segId);
    if (!s) return '<div class="pa-empty">No segment selected.</div>';
    const rows = [];
    if (s.bestSec > 0) {
      rows.push({
        name: s.bestAthleteName || s.ownerName || 'Athlete',
        sec: s.bestSec,
        me: !!myId() && (s.bestAthleteId === myId() || (!s.bestAthleteId && s.ownerId === myId()))
      });
    }
    let html = '<div>';
    if (withLegend) html += '<div class="leader-row legend-row"><span class="leader-rank">' + icon('star') + '</span>' +
      '<span class="leader-name">Course record · ' + D.fmtNum(s.attempts || 0) + ' ' + t('seg.attempts') + '</span>' +
      '<span class="leader-time" style="color:#E8A700">' + (s.bestSec > 0 ? D.fmtDuration(s.bestSec) : '—') + '</span></div>';
    html += rows.map((r, i) =>
      '<div class="leader-row' + (r.me ? ' me' : '') + '"><span class="leader-rank top">' + (i + 1) + '</span>' +
      '<span class="leader-name">' + (r.me ? t('common.you') + ' · ' + t('seg.yourPR') : esc(r.name)) + '</span>' +
      '<span class="leader-time">' + D.fmtDuration(r.sec) + '</span></div>').join('');
    if (!rows.length) html += '<div class="pa-empty" style="padding:16px 18px">No time recorded yet. Record an activity on this route.</div>';
    return html + '</div>';
  }

  function openSegmentCreate() {
    if (!requireAccount('Sign in to create a segment')) return;
    const acts = myActivities().filter(a => a.track && a.track.length >= 2 && a.distance > 0);
    if (!acts.length) {
      toast('Record a run or ride first — segments are created from your own routes.');
      setView('record');
      return;
    }
    state.segmentForm = { activityId: acts[0].id };
    const opts = acts.map(a => '<option value="' + esc(a.id) + '">' + esc(a.title) + ' · ' + a.distance.toFixed(2) + ' km</option>').join('');
    const html = '<div class="modal-head">' +
      '<div class="ch-icon" style="background:#0E8A6A">' + icon('segments') + '</div>' +
      '<div><h3>Create a segment</h3><p>Turn one of your recorded routes into a course other athletes can race</p></div>' +
      '<button class="modal-close" data-action="close-modal">' + icon('close') + '</button></div>' +
      '<div class="modal-body">' +
      '<label class="fld"><span>Recorded activity</span><select id="segActivity" class="text-input">' + opts + '</select></label>' +
      '<label class="fld"><span>Segment name</span><input id="segName" class="text-input" maxlength="80" placeholder="e.g. Entoto ridge climb"></label>' +
      '<div class="cc-blurb" id="segPreview"></div>' +
      '<p class="muted" style="font-size:12px;line-height:1.7">A segment keeps the start and finish of the selected activity. Any later recording that starts and finishes within about 150 m updates the attempt count and course record.</p>' +
      '<div class="cc-footer"><span class="cc-note">' + icon('shield') + ' Only your own recordings can become segments.</span>' +
      '<button class="btn btn-secondary btn-sm" data-action="close-modal">Cancel</button>' +
      '<button class="btn btn-primary btn-sm" data-action="segment-save">' + icon('check') + ' Create segment</button></div></div>';
    openModal(html);
    updateSegmentPreview();
  }
  function updateSegmentPreview() {
    const f = state.segmentForm;
    const box = $('#segPreview');
    if (!f || !box) return;
    const sel = $('#segActivity');
    if (sel) f.activityId = sel.value;
    const a = state.activities.find(x => x.id === f.activityId);
    if (!a) { box.innerHTML = ''; return; }
    const cat = segmentCat(a.gain, a.distance);
    box.innerHTML = icon('info') + '<span><b>' + esc(a.title) + '</b><br>' +
      a.distance.toFixed(2) + ' km · +' + D.fmtNum(a.gain) + ' m · category ' + esc(cat) + ' · ' +
      D.fmtDuration(a.duration) + ' recorded time</span>';
    const name = $('#segName');
    if (name && !name.value) name.placeholder = a.title + ' segment';
  }
  function saveSegment() {
    const f = state.segmentForm;
    if (!f) return;
    const a = state.activities.find(x => x.id === ($('#segActivity') ? $('#segActivity').value : f.activityId));
    if (!a) { toast('Choose one of your recorded activities'); return; }
    if (state.segments.some(s => s.activityId === a.id)) {
      toast('That activity is already a segment');
      return;
    }
    const name = (($('#segName') && $('#segName').value.trim()) || (a.title + ' segment')).slice(0, 80);
    const seg = normalizeSegment({
      id: 'seg_' + Date.now(), name: name, city: a.city,
      startLat: a.startLat, startLng: a.startLng,
      endLat: a.endLat, endLng: a.endLng,
      km: a.distance, gainM: Math.round(a.gain), cat: segmentCat(a.gain, a.distance), type: a.type,
      bestSeconds: Math.round(a.duration), attempts: 1,
      ownerId: myId(), ownerName: myName(),
      bestAthleteId: myId(), bestAthleteName: myName(),
      activityId: a.id, createdAt: new Date().toISOString()
    });
    state.segments = [seg].concat(state.segments);
    state.hall = D.hallOfFame(state.segments);
    API().addSegment(toBackendSegment(seg));
    closeModal();
    state.view = 'segments';
    render();
    toast('Segment created — ' + name);
  }
  function matchSegmentEfforts(a) {
    if (!a || !a.track || a.track.length < 2 || !(a.duration > 0)) return;
    const start = [a.startLat != null ? a.startLat : a.track[0].lat, a.startLng != null ? a.startLng : a.track[0].lng];
    const end = [a.endLat != null ? a.endLat : a.track[a.track.length - 1].lat, a.endLng != null ? a.endLng : a.track[a.track.length - 1].lng];
    let changed = false;
    state.segments.forEach(s => {
      if (s.type !== a.type) return;
      if (D.haversine(start, [s.startLat, s.startLng]) * 1000 > 150) return;
      if (D.haversine(end, [s.endLat, s.endLng]) * 1000 > 150) return;
      const tolerance = Math.max(0.4, (s.km || 0) * 0.15);
      if (Math.abs((a.distance || 0) - (s.km || 0)) > tolerance) return;
      s.attempts = (s.attempts || 0) + 1;
      if (!s.bestSec || a.duration < s.bestSec) {
        s.bestSec = Math.round(a.duration);
        s.bestAthleteId = myId() || 'guest';
        s.bestAthleteName = myName();
      }
      API().addSegment(toBackendSegment(s));
      changed = true;
    });
    if (changed) {
      state.hall = D.hallOfFame(state.segments);
      toast('Segment effort matched — course record updated if it was faster');
    }
  }

  function openClubCreate() {
    if (!requireAccount('Sign in to create a club')) return;
    const cities = Object.keys(D.CITIES).map(k => '<option value="' + esc(D.CITIES[k].name) + '">' + esc(D.CITIES[k].name) + '</option>').join('');
    const html = '<div class="modal-head">' +
      '<div class="ch-icon" style="background:#0B6E56">' + icon('users') + '</div>' +
      '<div><h3>Create a club</h3><p>Gather the people you train with and give your crew a home</p></div>' +
      '<button class="modal-close" data-action="close-modal">' + icon('close') + '</button></div>' +
      '<div class="modal-body">' +
      '<label class="fld"><span>Club name</span><input id="clubName" class="text-input" maxlength="60" placeholder="e.g. Entoto Trail Club"></label>' +
      '<label class="fld"><span>Description</span><textarea id="clubDesc" class="text-input" rows="2" maxlength="300" placeholder="Who is this club for?"></textarea></label>' +
      '<label class="fld"><span>Home city</span><select id="clubCity" class="text-input">' + cities + '</select></label>' +
      '<label class="fld"><span>Discipline</span><select id="clubType" class="text-input"><option value="run">Running</option><option value="ride">Riding</option></select></label>' +
      '<div class="cc-footer"><span class="cc-note">' + icon('users') + ' You become the first member and owner.</span>' +
      '<button class="btn btn-secondary btn-sm" data-action="close-modal">Cancel</button>' +
      '<button class="btn btn-primary btn-sm" data-action="club-save">' + icon('check') + ' Create club</button></div></div>';
    openModal(html);
  }
  function saveClub() {
    const name = ($('#clubName') && $('#clubName').value.trim()) || '';
    if (!name) { toast('Give your club a name first'); return; }
    const description = ($('#clubDesc') && $('#clubDesc').value.trim()) || '';
    const city = ($('#clubCity') && $('#clubCity').value) || (D.CITIES[state.city] || D.CITIES.addis).name;
    const type = ($('#clubType') && $('#clubType').value) === 'ride' ? 'ride' : 'run';
    const c = normalizeClub({
      id: 'club_' + Date.now(), name: name, description: description, city: city, type: type,
      color: D.PALETTE[Math.abs(name.length + type.length) % D.PALETTE.length],
      ownerId: myId(), ownerName: myName(), members: 1, joined: true,
      createdAt: new Date().toISOString()
    });
    state.clubs = [c].concat(state.clubs);
    state.joined.add(c.id);
    API().addClub(c);
    closeModal();
    state.view = 'community';
    render();
    toast('Club created — ' + name + '. Invite your training partners.');
  }

  function visibleChallenges() {
    const A = AUTH();
    return (state.challenges || []).filter(c => !A || !A.canSeeChallenge || A.canSeeChallenge(c));
  }
  function viewCommunity() {
    const list = visibleChallenges();
    const ch = list.map(challengeCardHtml).join('');
    const stats = communityStats();
    const clubs = state.clubs.map(c =>
      '<div class="club-card"><span class="club-logo" style="background:' + c.color + '">' + icon(c.type === 'ride' ? 'ride' : 'run') + '</span>' +
      '<div style="flex:1"><div class="club-name">' + esc(c.name) + '</div>' +
      '<div class="club-desc">' + esc(c.description || 'A club created by a RUCHA athlete.') + '</div>' +
      '<div class="club-members">' + icon('users') + ' ' + D.fmtNum(c.members) + ' ' + t('com.members') + (c.city ? ' · ' + esc(c.city) : '') + '</div></div>' +
      '<button class="btn ' + (state.joined.has(c.id) ? 'btn-ghost' : 'btn-secondary') + ' btn-sm" data-club="' + c.id + '">' +
      (state.joined.has(c.id) ? icon('check') + t('com.joined') : t('com.join')) + '</button></div>').join('');
    return '<div class="view-head"><div><h1 class="view-title">' + t('com.title') + '</h1>' +
      '<div class="view-sub">Clubs, challenges and the people who make the kilometres</div></div>' +
      '<div class="view-actions"><span class="pill accent">' + icon('users') + D.fmtNum(stats.athletes) + ' athletes</span>' +
      '<button class="btn btn-secondary btn-sm" data-action="club-create">' + icon('plus') + ' Create a club</button>' +
      '<button class="btn btn-primary btn-sm" data-action="challenge-create">' + icon('plus') + ' Create a challenge</button></div></div>' +
      '<div class="card-head" style="padding:0 0 12px"><div><div class="card-title">' + t('com.challenges') + '</div>' +
      '<div class="card-sub">' + list.length + ' challenges visible to you · ' + D.CHALLENGE_KINDS.length + ' types to try</div></div>' + backendBadge() + '</div>' +
      '<div class="ch-note">' + icon('shield') + ' Anyone can create a challenge. Choose <b>Friends only</b>, <b>Public</b> or <b>Everyone</b>. ' +
      'Join a challenge to appear on its standings table, or challenge one friend to a fastest-5K duel.</div>' +
      (ch ? '<div class="two-grid" style="margin-bottom:20px">' + ch + '</div>'
          : '<div class="card card-pad" style="margin-bottom:20px;text-align:center;color:var(--muted)">No challenges yet. Create the first one.</div>') +
      '<div class="card"><div class="card-head"><div><div class="card-title">' + t('com.clubs') + '</div><div class="card-sub">' + stats.clubs + ' user-created club' + (stats.clubs === 1 ? '' : 's') + '</div></div>' +
      '<button class="btn btn-secondary btn-sm" data-action="club-create">' + icon('plus') + ' Create a club</button></div>' +
      (clubs ? '<div style="padding:8px 0 4px">' + clubs + '</div>'
             : '<div class="pa-empty">No clubs yet. Create one and invite the people you train with.</div>') + '</div>';
  }

  // fastest time over a distance, from the recorded timestamps of one track
  function bestSplitSeconds(track, km) {
    if (!track || track.length < 2) return null;
    if (!track[0].t || !track[track.length - 1].t) return null;
    if (track[track.length - 1].d < km) return null;
    const dAt = i => track[i].d, tAt = i => track[i].t / 1000;
    // time at exact cumulative distance x, by interpolation
    const timeAt = x => {
      let lo = 0, hi = track.length - 1;
      while (lo < hi - 1) { const m = (lo + hi) >> 1; if (dAt(m) <= x) lo = m; else hi = m; }
      const d0 = dAt(lo), d1 = dAt(hi), t0 = tAt(lo), t1 = tAt(hi);
      return d1 > d0 ? t0 + (t1 - t0) * ((x - d0) / (d1 - d0)) : t0;
    };
    let best = Infinity;
    const total = track[track.length - 1].d;
    for (let i = 0; i < track.length; i++) {
      const start = dAt(i);
      if (start + km > total) break;
      const sec = timeAt(start + km) - tAt(i);
      if (sec > 0 && sec < best) best = sec;
    }
    return isFinite(best) ? best : null;
  }
  function viewProfile() {
    const u = meUser();
    const mine = myActivities();
    const now = new Date();
    const weekly = [], labels = [];
    for (let i = 6; i >= 0; i--) {
      const end = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1 - i * 7);
      const start = new Date(end.getFullYear(), end.getMonth(), end.getDate() - 7);
      weekly.push(mine.filter(a => a.date >= start && a.date < end).reduce((x, a) => x + a.distance, 0));
      labels.push(i === 0 ? 'This wk' : '-' + i + 'w');
    }
    const totalKm = mine.reduce((x, a) => x + a.distance, 0);
    const climb = mine.reduce((x, a) => x + a.gain, 0);
    const runs = mine.filter(a => a.type === 'run');
    const bests = [['1 km', 1], ['5 km', 5], ['10 km', 10]].map(x => {
      let b = null;
      runs.forEach(a => { const v = bestSplitSeconds(a.track, x[1]); if (v != null && (b == null || v < b)) b = v; });
      return [x[0], b != null ? D.fmtDuration(b) : '-'];
    });
    const longest = mine.reduce((m, a) => Math.max(m, a.distance), 0);
    bests.push(['Longest', longest > 0 ? longest.toFixed(1) + ' km' : '-']);
    const since = u && u.createdAt ? new Date(u.createdAt).toLocaleDateString('en-GB', { month: 'long', year: 'numeric' }) : '';
    if (!u) {
      return '<div class="view-head"><div><h1 class="view-title">' + t('prof.title') + '</h1></div></div>' +
        '<div class="card card-pad"><p style="margin:0 0 14px;color:var(--muted)">Sign in to see your own totals, weekly distance and personal bests.</p>' +
        '<button class="btn btn-primary" data-action="open-account">Sign in</button></div>';
    }
    return '<div class="view-head"><div><h1 class="view-title">' + t('prof.title') + '</h1></div></div>' +
      '<div class="card profile-hero" style="margin-bottom:18px">' +
      '<div class="avatar avatar-lg avatar-me">' + esc(u.username.slice(0, 2).toUpperCase()) + '</div>' +
      '<div><div class="profile-name">' + esc(u.displayName || u.username) + '</div>' +
      '<div class="profile-sub">@' + esc(u.username) + (since ? ' · Joined ' + esc(since) : '') + '</div></div>' +
      '<div class="profile-nums"><div><b>' + D.fmtNum(totalKm) + '</b><span>Total km</span></div>' +
      '<div><b>' + mine.length + '</b><span>Activities</span></div>' +
      '<div><b>' + D.fmtNum(climb) + ' m</b><span>Total climb</span></div></div></div>' +
      '<div class="card card-pad"><div class="row" style="margin-bottom:10px"><div><div class="insight-title">' + t('prof.weekly') + '</div>' +
      '<div class="card-sub">Last 7 weeks · kilometres</div></div></div>' +
      (weekly.some(v => v > 0) ? barChart(weekly, labels, '#FF5A1F') : '<p class="muted" style="margin:6px 0 0">Record an activity and your weekly distance shows up here.</p>') + '</div>' +
      '<div class="card card-pad" style="margin-top:18px"><div class="insight-title" style="margin-bottom:14px">' + t('prof.prs') + '</div>' +
      '<div class="pr-grid">' + bests.map(p => '<div class="pr-card"><span>' + p[0] + '</span><b>' + p[1] + '</b></div>').join('') + '</div></div>';
  }

  function trimTrackAt(tr, km) {
    if (!tr || tr.length < 2 || km <= 0) return tr;
    const out = tr.slice();
    for (let i = 1; i < out.length; i++) {
      if (out[i].d >= km) {
        const prev = out[i - 1], cur = out[i];
        const span = cur.d - prev.d;
        const f = span > 0 ? clamp((km - prev.d) / span, 0, 1) : 1;
        out.splice(i + 1);
        out[i] = {
          lat: prev.lat + (cur.lat - prev.lat) * f,
          lng: prev.lng + (cur.lng - prev.lng) * f,
          ele: prev.ele + (cur.ele - prev.ele) * f,
          d: km, t: cur.t, accuracy: cur.accuracy
        };
        return out;
      }
    }
    return out;
  }
  function goalCardHtml() {
    const r = state.rec, g = state.goal;
    const active = r.goalKm > 0 ? r.goalKm : 0;
    const best = g.best;
    return '<div class="card card-pad goal-card">' +
      '<div class="goal-head"><div class="insight-title">' + icon('target') + ' Distance goal &amp; auto-stop</div>' +
      (active ? '<span class="pill green">' + icon('clock') + ' Timer stops at ' + D.fmtNum(active) + ' km</span>' : '') + '</div>' +
      '<p class="sensor-note">Set a distance and the timer stops by itself the moment you reach it. Race a friend over 5 km or set a solo goal.</p>' +
      '<div class="acct-inline"><input id="goalKm" class="text-input" type="number" min="0.1" step="0.1" value="' + (g.km || 5) + '">' +
      '<button class="btn btn-secondary btn-sm" data-action="goal-set">Save goal</button>' +
      '<button class="btn btn-primary btn-sm" data-action="goal-start">Start goal run</button>' +
      (g.km ? '<button class="btn btn-ghost btn-sm" data-action="goal-clear">Clear</button>' : '') + '</div>' +
      (best ? '<div class="goal-best">' + icon('trophy') + ' Best ' + D.fmtNum(best.km) + ' km: <b>' + D.fmtDuration(best.seconds) +
        '</b> · ' + esc(D.relativeDay(parseDate(best.date))) + '</div>' : '') + '</div>';
  }
  function setPersonalGoal(start) {
    const el = $('#goalKm');
    const km = parseFloat(el && el.value);
    if (!isFinite(km) || km < 0.1 || km > 200) { toast('Enter a goal between 0.1 and 200 km'); return; }
    state.goal.km = km;
    API().setGoalState({ km: km, best: state.goal.best });
    if (!start) { render(); toast('Goal saved: ' + D.fmtNum(km) + ' km — tap Start goal run'); return; }
    const r = state.rec;
    if (r.status === 'running' || r.status === 'paused') { toast('Finish or stop the current run first'); return; }
    r.challengeId = null; r.geofenceOk = true; r.geofenceDistance = null;
    r.goalKm = km; r.autoStop = true; r.goalHit = false; r.goalElapsed = 0;
    r.status = 'idle'; r.mode = 'gps';
    setView('record');
    startRecorder();
    render();
    toast(D.fmtNum(km) + ' km goal set — the timer stops automatically at the finish');
  }
  function clearPersonalGoal() {
    state.goal.km = 0; state.goal.best = null;
    API().setGoalState({ km: 0, best: null });
    const r = state.rec;
    if (!r.challengeId) { r.goalKm = 0; r.autoStop = false; r.goalHit = false; r.goalElapsed = 0; }
    render(); toast('Distance goal cleared');
  }

  function viewRecord() {
    const r = state.rec;
    const running = r.status === 'running';
    const paused = r.status === 'paused';
    const hrOn = r.hrAvailable;
    const gated = r.challengeId && !r.geofenceOk;
    const btn = r.status === 'idle'
      ? '<button class="btn btn-primary btn-big" data-rec="start"' + (gated ? ' disabled title="Move to the challenge start first"' : '') + '>' + icon('play') + t('rec.start') + '</button>'
      : running
        ? '<button class="btn btn-ghost btn-big" data-rec="pause">' + icon('pause') + t('rec.pause') + '</button><button class="btn btn-primary btn-big" data-rec="finish">' + icon('stop') + t('rec.finish') + '</button>'
        : paused
          ? '<button class="btn btn-primary btn-big" data-rec="resume">' + icon('play') + t('rec.resume') + '</button><button class="btn btn-ghost btn-big" data-rec="finish">' + icon('stop') + t('rec.finish') + '</button>'
          : '<button class="btn btn-primary btn-big" data-rec="start">' + icon('play') + 'New activity</button>';
    const stats =
      '<div class="rec-stat"><span>' + icon('route') + t('rec.distance') + '</span><b><span id="recDist">0.00</span><small> km</small></b></div>' +
      '<div class="rec-stat"><span>' + icon('clock') + t('stat.time') + '</span><b id="recTime">0:00</b></div>' +
      '<div class="rec-stat"><span>' + icon('bolt') + t('rec.pace') + '</span><b id="recPace">--:--<small> /km</small></b></div>' +
      '<div class="rec-stat"><span>' + icon('mountain') + t('rec.elev') + '</span><b><span id="recElev">0</span><small> m</small></b></div>' +
      (hrOn ? '<div class="rec-stat"><span>' + icon('heart') + t('rec.hr') + '</span><b><span id="recHR">--</span><small> bpm</small></b></div>' : '') +
      ((SENS() && (SENS().cadence.status().connected || SENS().footpod.status().connected)) ? '<div class="rec-stat"><span>' + icon('activity') + 'Cadence</span><b><span id="recCad">--</span><small> ' + (r.type === 'ride' ? 'rpm' : 'spm') + '</small></b></div>' : '') +
      ((SENS() && SENS().power.status().connected) ? '<div class="rec-stat"><span>' + icon('bolt') + 'Power</span><b><span id="recPow">--</span><small> W</small></b></div>' : '') +
      '<div class="rec-stat"><span>' + icon('flame') + t('rec.cal') + '</span><b><span id="recCal">0</span><small> kcal</small></b></div>';
    return '<div class="view-head"><div><h1 class="view-title">' + t('rec.title') + '</h1>' +
      '<div class="view-sub">' + (running ? t('rec.live') + ' · ' + esc(D.CITIES[state.city].name) : t('rec.ready')) + '</div></div>' +
      '<div class="view-actions"><div class="seg-toggle">' +
      '<button data-rec-type="run" class="' + (r.type === 'run' ? 'active' : '') + '">' + icon('run') + ' Run</button>' +
      '<button data-rec-type="ride" class="' + (r.type === 'ride' ? 'active' : '') + '">' + icon('ride') + ' Ride</button>' +
      '</div>' + (running ? '<span class="pill green"><span class="live-dot"></span>' + t('rec.live') + '</span>' : '') + '</div></div>' +
      geofenceHtml() +
      goalCardHtml() +
      '<div class="rec-name-row"><label for="recName">Name this activity</label>' +
      '<input id="recName" class="text-input" type="text" maxlength="64" placeholder="e.g. Sunrise on Entoto Hill" value="' + esc(r.name) + '">' +
      '<span>Your title is saved together with the exact longitude &amp; latitude of the start.</span></div>' +
      '<div class="rec-grid">' +
      '<div class="card map-card">' +
      '<div class="map-toolbar"><div><div class="map-title">' + t('rec.live') + '</div>' +
      '<div class="map-sub">Your position and route, drawn from GPS fixes</div></div>' +
      '<div class="tb-actions"><span class="pill" id="gpsPill"></span></div></div>' +
      mapWrapHtml('rec') + '</div>' +
      '<div class="side-stack">' +
      '<div class="card card-pad"><div class="rec-stats">' + stats + '</div>' +
      '<div class="rec-actions">' + btn + '</div></div>' +
      '<div class="card card-pad"><div class="insight-title" style="margin-bottom:10px">' + t('rec.splits') + '</div>' +
      '<table class="split-table"><thead><tr><th>Km</th><th>Pace</th><th>Elev</th></tr></thead><tbody id="recSplits">' +
      '<tr><td colspan="3" class="muted" style="text-align:center;padding:18px">Start recording to see splits</td></tr></tbody></table></div>' +
      '</div></div>' +
      '<div style="margin-top:18px">' + sensorPanelHtml() + '</div>';
  }

  const CARD_W = 900, CARD_H = 1125;
  const GALLERY_KEY = 'rucha_gallery_v1';
  function galleryKey() { return GALLERY_KEY + '_' + (myId() || 'anon'); }
  const CARD_STYLES = {
    sunset:   { name: 'Sunset',   shade: 'rgba(22,10,6,.55)', accent: '#FF7A42', glow: '#FFB067' },
    midnight: { name: 'Midnight', shade: 'rgba(6,16,26,.60)', accent: '#5FD6A8', glow: '#7CE0C0' },
    ember:    { name: 'Ember',    shade: 'rgba(30,8,8,.58)',  accent: '#F2B705', glow: '#FFD860' }
  };
  const studio = { activityId: null, image: null, blur: 14, style: 'sunset', showRoute: true, canvas: null, dataUrl: null, redraw: null };

  function drawCover(c, img, x, y, w, h) {
    const iw = img.naturalWidth || img.width, ih = img.naturalHeight || img.height;
    if (!iw || !ih) return;
    const s = Math.max(w / iw, h / ih), dw = iw * s, dh = ih * s;
    c.drawImage(img, x + (w - dw) / 2, y + (h - dh) / 2, dw, dh);
  }
  function roundRect(c, x, y, w, h, r) {
    c.beginPath(); c.moveTo(x + r, y);
    c.arcTo(x + w, y, x + w, y + h, r); c.arcTo(x + w, y + h, x, y + h, r);
    c.arcTo(x, y + h, x, y, r); c.arcTo(x, y, x + w, y, r); c.closePath();
  }
  function clipText(c, txt, maxW) {
    if (c.measureText(txt).width <= maxW) return txt;
    let s = txt;
    while (s.length > 1 && c.measureText(s + '...').width > maxW) s = s.slice(0, -1);
    return s + '...';
  }

  function drawShareCard(cv, a, cfg) {
    cv.width = CARD_W; cv.height = CARD_H;
    const c = cv.getContext('2d'), W = CARD_W, H = CARD_H;
    const st = CARD_STYLES[cfg.style] || CARD_STYLES.sunset;
    const blur = cfg.blur || 0;

    const bg = document.createElement('canvas');
    bg.width = W; bg.height = H;
    const bc = bg.getContext('2d');
    if (cfg.image) {
      drawCover(bc, cfg.image, 0, 0, W, H);
    } else {
      const g = bc.createLinearGradient(0, 0, W, H);
      if (cfg.style === 'midnight') { g.addColorStop(0, '#0B2436'); g.addColorStop(.55, '#123B47'); g.addColorStop(1, '#0A1726'); }
      else if (cfg.style === 'ember') { g.addColorStop(0, '#3A120E'); g.addColorStop(.55, '#7A2A12'); g.addColorStop(1, '#20100C'); }
      else { g.addColorStop(0, '#2A1810'); g.addColorStop(.5, '#7A331A'); g.addColorStop(1, '#1B1110'); }
      bc.fillStyle = g; bc.fillRect(0, 0, W, H);
      const rg = bc.createRadialGradient(W * .72, H * .3, 10, W * .72, H * .3, W * .85);
      rg.addColorStop(0, 'rgba(255,196,128,.32)'); rg.addColorStop(1, 'rgba(255,196,128,0)');
      bc.fillStyle = rg; bc.fillRect(0, 0, W, H);
      [[.18, .20, 96, 'rgba(255,200,130,.30)'], [.80, .17, 148, 'rgba(255,140,80,.24)'],
       [.33, .52, 72, 'rgba(255,255,255,.14)'], [.86, .62, 118, 'rgba(240,180,60,.20)'],
       [.13, .82, 132, 'rgba(120,210,180,.16)']].forEach(b => {
        bc.beginPath(); bc.arc(W * b[0], H * b[1], b[2], 0, Math.PI * 2);
        bc.fillStyle = b[3]; bc.fill();
      });
      bc.strokeStyle = 'rgba(255,255,255,.055)'; bc.lineWidth = 2;
      for (let i = 0; i < 9; i++) { bc.beginPath(); bc.arc(W * .78, H * .32, 70 + i * 62, 0, Math.PI * 2); bc.stroke(); }
    }
    const pad = Math.ceil(blur * 1.5) + 12;
    c.save();
    if (blur > 0) c.filter = 'blur(' + blur + 'px)';
    c.drawImage(bg, -pad, -pad, W + pad * 2, H + pad * 2);
    c.restore();

    const sh = c.createLinearGradient(0, 0, 0, H);
    sh.addColorStop(0, 'rgba(0,0,0,.36)'); sh.addColorStop(.42, st.shade); sh.addColorStop(1, 'rgba(0,0,0,.84)');
    c.fillStyle = sh; c.fillRect(0, 0, W, H);

    c.textBaseline = 'alphabetic'; c.textAlign = 'left';
    c.fillStyle = '#FFFFFF'; c.font = '900 30px Inter, sans-serif';
    c.fillText('RUCHA', 64, 96);
    c.font = '700 15px Inter, sans-serif'; c.fillStyle = 'rgba(255,255,255,.66)';
    c.fillText('ETHIOPIA  ·  ' + (a.type === 'ride' ? 'CYCLING' : 'RUNNING'), 64, 126);
    c.fillStyle = st.accent; roundRect(c, 64, 142, 56, 5, 3); c.fill();
    c.textAlign = 'right'; c.fillStyle = 'rgba(255,255,255,.78)'; c.font = '600 17px Inter, sans-serif';
    c.fillText(D.fmtDate(a.date).toUpperCase(), W - 64, 100);
    c.textAlign = 'left';

    if (cfg.showRoute !== false && a.track && a.track.length > 1) {
      let laMin = Infinity, laMax = -Infinity, lnMin = Infinity, lnMax = -Infinity;
      a.track.forEach(p => {
        if (p.lat < laMin) laMin = p.lat; if (p.lat > laMax) laMax = p.lat;
        if (p.lng < lnMin) lnMin = p.lng; if (p.lng > lnMax) lnMax = p.lng;
      });
      const k = Math.cos((laMin + laMax) / 2 * D2R);
      const span = Math.max((lnMax - lnMin) * k, laMax - laMin, 1e-6);
      const boxW = W - 200, boxH = 350, bx = 100, by = 215;
      const px = p => bx + boxW / 2 + (p.lng - (lnMin + lnMax) / 2) * k / span * boxW * .9;
      const py = p => by + boxH / 2 - (p.lat - (laMin + laMax) / 2) / span * boxH * .9;
      const path = () => { c.beginPath(); a.track.forEach((p, i) => i ? c.lineTo(px(p), py(p)) : c.moveTo(px(p), py(p))); };
      c.save(); c.lineJoin = 'round'; c.lineCap = 'round';
      c.strokeStyle = st.glow; c.globalAlpha = .38; c.lineWidth = 20;
      c.shadowColor = st.accent; c.shadowBlur = 34; path(); c.stroke(); c.restore();
      c.save(); c.lineJoin = 'round'; c.lineCap = 'round';
      c.strokeStyle = '#FFFFFF'; c.lineWidth = 6; path(); c.stroke(); c.restore();
      const pStart = a.track[0], pEnd = a.track[a.track.length - 1];
      const sx0 = px(pStart), sy0 = py(pStart), ex0 = px(pEnd), ey0 = py(pEnd);
      const overlap = Math.hypot(ex0 - sx0, ey0 - sy0) < 28;
      const drawPin = (x, y, col, label, dir) => {
        c.beginPath(); c.arc(x, y, 11, 0, Math.PI * 2);
        c.fillStyle = col; c.fill();
        c.lineWidth = 4; c.strokeStyle = 'rgba(0,0,0,.35)'; c.stroke();
        c.font = '800 14px Inter, sans-serif'; c.fillStyle = 'rgba(255,255,255,.92)';
        c.textAlign = dir < 0 ? 'right' : 'left';
        c.fillText(label, x + dir * 19, y + 5);
        c.textAlign = 'left';
      };
      if (overlap) {
        drawPin(sx0 - 11, sy0, '#FFFFFF', 'START', -1);
        drawPin(ex0 + 11, ey0, st.accent, 'FINISH', 1);
      } else {
        drawPin(sx0, sy0, '#FFFFFF', 'START', 1);
        drawPin(ex0, ey0, st.accent, 'FINISH', 1);
      }
    }

    c.fillStyle = 'rgba(255,255,255,.72)'; c.font = '600 22px Inter, sans-serif';
    c.fillText(clipText(c, String(a.title).toUpperCase(), W - 128), 64, 700);

    const dstr = a.distance.toFixed(2);
    c.fillStyle = '#FFFFFF'; c.font = '900 148px Inter, sans-serif';
    c.fillText(dstr, 58, 848);
    const nw = c.measureText(dstr).width;
    c.fillStyle = st.accent; c.font = '800 44px Inter, sans-serif';
    c.fillText('KM', 74 + nw, 848);

    c.strokeStyle = 'rgba(255,255,255,.20)'; c.lineWidth = 2;
    c.beginPath(); c.moveTo(64, 892); c.lineTo(W - 64, 892); c.stroke();
    const stats = [
      ['TIME', D.fmtDuration(a.duration)],
      ['AVG PACE', D.fmtPace(a.pace) + ' /km'],
      ['ELEV GAIN', '+' + D.fmtNum(a.gain) + ' m'],
      ['CALORIES', D.fmtNum(a.calories)]
    ];
    const colW = (W - 128) / 4;
    stats.forEach((s, i) => {
      const x = 64 + i * colW;
      c.fillStyle = 'rgba(255,255,255,.55)'; c.font = '700 14px Inter, sans-serif';
      c.fillText(s[0], x, 936);
      c.fillStyle = '#FFFFFF'; c.font = '800 30px Inter, sans-serif';
      c.fillText(clipText(c, s[1], colW - 12), x, 980);
    });

    c.strokeStyle = 'rgba(255,255,255,.14)'; c.lineWidth = 2;
    c.beginPath(); c.moveTo(64, 1026); c.lineTo(W - 64, 1026); c.stroke();
    c.fillStyle = 'rgba(255,255,255,.62)'; c.font = '600 17px Inter, sans-serif';
    c.fillText('#RUCHA  ·  ' + a.cityObj.name + ', Ethiopia  ·  2,355 m', 64, 1066);

  }

  function renderCardToDataURL(a, cfg) {
    const cv = document.createElement('canvas');
    drawShareCard(cv, a, cfg);
    return cv.toDataURL('image/jpeg', 0.86);
  }
  function loadGallery() {
    try {
      const raw = localStorage.getItem(galleryKey());
      if (raw) {
        const arr = JSON.parse(raw);
        if (Array.isArray(arr)) {
          state.gallery = arr.filter(g => g && g.dataUrl && !g.sample);
          if (state.gallery.length !== arr.length) persistGallery();
          return;
        }
      }
    } catch (e) {  }
    state.gallery = [];
  }
  function persistGallery() {
    try { localStorage.setItem(galleryKey(), JSON.stringify(state.gallery)); return true; }
    catch (e) { return false; }
  }

  function downloadDataUrl(url, name) {
    const a = document.createElement('a');
    a.href = url; a.download = name;
    document.body.appendChild(a); a.click(); a.remove();
  }
  function dataUrlToBlob(url) {
    const parts = String(url).split(',');
    const mime = (parts[0].match(/:(.*?);/) || [])[1] || 'image/jpeg';
    const bin = atob(parts[1] || '');
    const arr = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
    return new Blob([arr], { type: mime });
  }
  function captionFor(a) {
    return a.title + ' — ' + a.distance.toFixed(2) + ' km in ' + D.fmtDuration(a.duration) +
      ' · avg ' + D.fmtPace(a.pace) + '/km · +' + D.fmtNum(a.gain) + ' m · ' +
      a.cityObj.name + ', Ethiopia. Tracked with RUCHA. #RUCHA #RunEthiopia';
  }
  function copyText(txt, okMsg) {
    const done = () => toast(okMsg);
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(txt).then(done).catch(() => fallbackCopy(txt, done));
    } else fallbackCopy(txt, done);
  }
  function fallbackCopy(txt, done) {
    const ta = document.createElement('textarea');
    ta.value = txt; ta.style.position = 'fixed'; ta.style.opacity = '0';
    document.body.appendChild(ta); ta.select();
    try { document.execCommand('copy'); done(); } catch (e) { toast('Could not copy to clipboard'); }
    ta.remove();
  }
  function shareImage(dataUrl, filename, text) {
    const blob = dataUrlToBlob(dataUrl);
    const file = new File([blob], filename, { type: 'image/jpeg' });
    if (navigator.canShare && navigator.canShare({ files: [file] })) {
      navigator.share({ files: [file], title: 'My RUCHA run', text: text })
        .then(() => toast('Shared — ready to post anywhere'))
        .catch(e => { if (!e || e.name !== 'AbortError') fallbackShare(dataUrl, filename); });
      return;
    }
    fallbackShare(dataUrl, filename);
  }
  function fallbackShare(dataUrl, filename) {
    downloadDataUrl(dataUrl, filename);
    toast('Sharing is not available here — image downloaded instead');
  }

  function viewGallery() {
    const cards = state.gallery;
    const head = '<div class="view-head"><div>' +
      '<div class="view-title">Your Gallery</div>' +
      '<div class="view-sub">Run cards saved and ready to post · ' + cards.length + ' card' + (cards.length === 1 ? '' : 's') + '</div></div>' +
      '<div class="view-actions"><button class="btn btn-primary btn-sm" data-action="gallery-create">' + icon('camera') + ' Create a run card</button></div></div>';
    if (!cards.length) {
      return head + '<div class="gallery-empty card"><div class="gallery-empty-icon">' + icon('gallery') + '</div>' +
        '<h3>No run cards yet</h3>' +
        '<p>Take or choose a photo. We blur the background and draw your run on top. Post it anywhere first, then save it here.</p>' +
        '<button class="btn btn-primary" data-action="gallery-create">' + icon('plus') + ' Create your first card</button>' +
        '<p class="gallery-empty-help"><a class="text-link" href="help.html#gallery" target="_blank" rel="noopener">How run cards work</a></p></div>';
    }
    return head + '<div class="gallery-grid">' + cards.map(g =>
      '<div class="gallery-card">' +
        '<div class="gallery-img"><img src="' + g.dataUrl + '" alt="' + esc(g.title) + '"></div>' +
        '<div class="gallery-meta">' +
          '<b class="gallery-title">' + esc(g.title) + '</b>' +
          '<div class="gallery-sub">' + esc(g.meta.distance) + ' km · ' + esc(g.meta.duration) + ' · ' + esc(g.meta.city) + '</div>' +
          '<div class="gallery-actions">' +
            '<button class="btn btn-ghost btn-sm" data-gallery-view="' + g.id + '">' + icon('image') + ' View</button>' +
            '<button class="btn btn-ghost btn-sm" data-gallery-download="' + g.id + '" title="Download">' + icon('download') + '</button>' +
            '<button class="btn btn-ghost btn-sm" data-gallery-share="' + g.id + '" title="Share">' + icon('share') + '</button>' +
            '<button class="btn btn-ghost btn-sm gallery-del" data-gallery-delete="' + g.id + '" title="Delete card">' + icon('trash') + '</button>' +
          '</div></div></div>').join('') + '</div>';
  }

  function openActivityPicker() {
    const list = state.activities.slice(0, 14);
    const html = '<div class="modal-head">' +
      '<div class="studio-head-icon">' + icon('gallery') + '</div>' +
      '<div><h3>Choose a run</h3><p>Pick the activity you want to turn into a photo card.</p></div>' +
      '<button class="modal-close" data-action="close-modal">' + icon('close') + '</button></div>' +
      '<div class="picker-body">' + list.map(a =>
        '<button class="picker-item" data-pick-activity="' + a.id + '">' + typeBadge(a.type) +
        '<div class="picker-info"><b>' + esc(a.title) + '</b><span>' + esc(D.relativeDay(a.date)) + ' · ' + esc(a.cityObj.name) + '</span></div>' +
        '<div class="picker-dist"><b>' + a.distance.toFixed(2) + '</b><span>km</span></div>' +
        '<span class="picker-chev">' + icon('chevron') + '</span></button>').join('') + '</div>';
    openModal(html, 'picker-modal');
  }
  function openShareStudio(activityId) {
    const a = state.activities.find(x => x.id === activityId) || state.activities[0];
    if (!a) { toast('Record an activity first'); return; }
    studio.activityId = a.id; studio.image = null; studio.blur = 14;
    studio.style = 'sunset'; studio.showRoute = true; studio.dataUrl = null;

    const html = '<div class="modal-head studio-head">' +
      '<div class="studio-head-icon">' + icon('image') + '</div>' +
      '<div><h3>Create a run card</h3><p>Turn <b>' + esc(a.title) + '</b> into a photo you can post anywhere.</p></div>' +
      '<button class="modal-close" data-action="close-modal">' + icon('close') + '</button></div>' +
      '<div class="studio-body">' +
        '<div class="studio-preview">' +
          '<div class="studio-preview-label">Preview</div>' +
          '<canvas id="shareCanvas" class="share-canvas"></canvas>' +
          '<div class="studio-preview-hint">Your photo is blurred · your run is drawn on top</div>' +
        '</div>' +
        '<div class="studio-controls">' +
          '<div class="ctrl-block"><div class="ctrl-title"><span>1</span> Pick a background</div>' +
            '<div class="photo-btns">' +
              '<label class="photo-btn">' + icon('camera') + '<span>Take a photo</span>' +
                '<input type="file" accept="image/*" capture="environment" id="photoCapture" hidden></label>' +
              '<label class="photo-btn">' + icon('image') + '<span>Choose a photo</span>' +
                '<input type="file" accept="image/*" id="photoPick" hidden></label>' +
              '<button class="photo-btn" id="photoClear">' + icon('close') + '<span>No photo</span></button>' +
            '</div>' +
            '<div class="photo-name" id="photoName">Using a RUCHA gradient background</div>' +
          '</div>' +
          '<div class="ctrl-block"><div class="ctrl-title"><span>2</span> Blur the background</div>' +
            '<div class="slider-row"><input type="range" id="blurRange" min="0" max="30" value="14" step="1"><b id="blurVal">14 px</b></div>' +
            '<div class="ctrl-note">A soft backdrop keeps every number readable.</div>' +
          '</div>' +
          '<div class="ctrl-block"><div class="ctrl-title"><span>3</span> Card style</div>' +
            '<div class="style-btns">' + Object.keys(CARD_STYLES).map(k =>
              '<button class="style-btn' + (k === studio.style ? ' active' : '') + '" data-style="' + k + '"><i style="background:' + CARD_STYLES[k].accent + '"></i>' + CARD_STYLES[k].name + '</button>').join('') + '</div>' +
            '<label class="switch-row"><input type="checkbox" id="routeToggle" checked><span>Draw my route on the photo</span></label>' +
          '</div>' +
          '<div class="ctrl-block studio-share"><div class="ctrl-title"><span>4</span> Post it elsewhere first</div>' +
            '<div class="ctrl-note">Download, share or copy the caption now — before you save it to your Gallery.</div>' +
            '<div class="studio-share-btns">' +
              '<button class="btn btn-ghost btn-sm" id="cardDownload">' + icon('download') + ' Download</button>' +
              '<button class="btn btn-ghost btn-sm" id="cardShare">' + icon('share') + ' Share</button>' +
              '<button class="btn btn-ghost btn-sm" id="cardCopy">' + icon('copy') + ' Copy caption</button>' +
            '</div></div>' +
          '<button class="btn btn-primary studio-save" id="cardSave">' + icon('save') + ' Save to Gallery</button>' +
        '</div></div>';
    openModal(html, 'studio-modal');
    studio.canvas = $('#shareCanvas');
    mountStudio(a);
  }
  function mountStudio(a) {
    const redraw = () => {
      drawShareCard(studio.canvas, a, { image: studio.image, blur: studio.blur, style: studio.style, showRoute: studio.showRoute });
      studio.dataUrl = studio.canvas.toDataURL('image/jpeg', 0.86);
    };
    studio.redraw = redraw;
    redraw();

    const loadFile = file => {
      if (!file || !/^image\//.test(file.type)) { toast('Please pick an image file'); return; }
      const reader = new FileReader();
      reader.onload = ev => {
        const img = new Image();
        img.onload = () => {
          studio.image = img;
          const nm = $('#photoName'); if (nm) nm.textContent = 'Photo: ' + file.name + ' · background blurred';
          toast('Photo added — background blurred');
          redraw();
        };
        img.onerror = () => toast('Could not read that image');
        img.src = ev.target.result;
      };
      reader.readAsDataURL(file);
    };
    const cap = $('#photoCapture'), pick = $('#photoPick');
    if (cap) cap.addEventListener('change', e => { if (e.target.files[0]) loadFile(e.target.files[0]); });
    if (pick) pick.addEventListener('change', e => { if (e.target.files[0]) loadFile(e.target.files[0]); });
    const clear = $('#photoClear');
    if (clear) clear.addEventListener('click', () => {
      studio.image = null;
      const nm = $('#photoName'); if (nm) nm.textContent = 'Using a RUCHA gradient background';
      if (cap) cap.value = ''; if (pick) pick.value = '';
      redraw();
    });
    const range = $('#blurRange');
    if (range) range.addEventListener('input', e => {
      studio.blur = parseInt(e.target.value, 10);
      const v = $('#blurVal'); if (v) v.textContent = studio.blur + ' px';
      redraw();
    });
    $$('.style-btn').forEach(b => b.addEventListener('click', () => {
      studio.style = b.getAttribute('data-style');
      $$('.style-btn').forEach(x => x.classList.toggle('active', x === b));
      redraw();
    }));
    const rt = $('#routeToggle');
    if (rt) rt.addEventListener('change', e => { studio.showRoute = e.target.checked; redraw(); });

    const filename = 'rucha-' + a.id + '-' + Date.now() + '.jpg';
    const text = captionFor(a);
    const dl = $('#cardDownload');
    if (dl) dl.addEventListener('click', () => { downloadDataUrl(studio.dataUrl, filename); toast('Image downloaded — post it anywhere you like'); });
    const sh = $('#cardShare');
    if (sh) sh.addEventListener('click', () => shareImage(studio.dataUrl, filename, text));
    const cp = $('#cardCopy');
    if (cp) cp.addEventListener('click', () => copyText(text, 'Caption copied — paste it with your photo'));
    const sv = $('#cardSave');
    if (sv) sv.addEventListener('click', () => {
      const card = {
        id: 'card_' + Date.now(), title: a.title, activityId: a.id,
        dataUrl: studio.dataUrl,
        meta: { distance: a.distance.toFixed(2), duration: D.fmtDuration(a.duration), pace: D.fmtPace(a.pace), city: a.cityObj.name },
        created: Date.now()
      };
      state.gallery.unshift(card);
      const ok = persistGallery();
      API().addGallery(toBackendGallery(card));
      closeModal();
      state.view = 'gallery';
      render();
      toast(ok ? 'Saved to your Gallery' : 'Saved for this session — browser storage is full');
    });
  }
  function openGalleryCard(id) {
    const g = state.gallery.find(x => x.id === id);
    if (!g) return;
    const html = '<div class="modal-head">' +
      '<div class="studio-head-icon">' + icon('image') + '</div>' +
      '<div><h3>' + esc(g.title) + '</h3><p>' + esc(g.meta.distance) + ' km · ' + esc(g.meta.duration) + ' · ' + esc(g.meta.city) + '</p></div>' +
      '<button class="modal-close" data-action="close-modal">' + icon('close') + '</button></div>' +
      '<div class="gallery-lightbox"><img src="' + g.dataUrl + '" alt="' + esc(g.title) + '"></div>' +
      '<div class="lightbox-actions">' +
        '<button class="btn btn-ghost btn-sm" data-gallery-download="' + g.id + '">' + icon('download') + ' Download</button>' +
        '<button class="btn btn-ghost btn-sm" data-gallery-share="' + g.id + '">' + icon('share') + ' Share / post elsewhere</button>' +
        '<button class="btn btn-primary btn-sm" data-action="gallery-create">' + icon('plus') + ' Make another</button>' +
      '</div>';
    openModal(html, 'lightbox-modal');
  }

  function tilesFailed() {
    if (state.basemap === 'osm') {
      toast('Street map is slow to load — tap Street map again to retry, or Plain for the offline overview');
    }
  }
  function fitEngineToPoints(eng, a, b) {
    if (!eng) return;
    const la = Math.min(a.lat, b.lat), lb = Math.max(a.lat, b.lat);
    const na = Math.min(a.lng, b.lng), nb = Math.max(a.lng, b.lng);
    eng.center = { lat: (la + lb) / 2, lng: (na + nb) / 2 };
    eng.panX = 0; eng.panY = 0;
    const latSpan = Math.max(lb - la, 0.004), lngSpan = Math.max((nb - na) * Math.cos(eng.center.lat * D2R), 0.004);
    eng.scale = clamp(Math.min(eng.w / (lngSpan * 1.6), eng.h / (latSpan * 1.6)), 2600, 260000);
    eng.invalidate();
  }
  function openChallengeDetail(id) {
    const c = state.challenges.find(x => x.id === id);
    if (!c) return;
    const k = challengeKind(c.kind), geo = hasRoute(c);
    const joined = state.joinedChallenges.indexOf(c.id) >= 0 || c.joined;
    const routeBlock = geo
      ? '<div class="ch-detail-route">' +
        '<div class="cdr-pt"><span class="ch-pin start"></span><div><b>Start</b><span>' + placeLabel(c, 'start', joined) + '</span></div></div>' +
        '<div class="cdr-mid">' + icon('route') + ' Shown to everyone who joins · recording geofence ' + (c.geofenceM || 50) + ' m' +
        (!joined ? ' · join to reveal exact coordinates' : '') + '</div>' +
        '<div class="cdr-pt"><span class="ch-pin end"></span><div><b>Destination</b><span>' + placeLabel(c, 'end', joined) + '</span></div></div></div>'
      : '<div class="ch-anywhere">' + icon('globe') + ' No fixed start or destination — record this anywhere.</div>';
    const html = '<div class="modal-head">' +
      '<div class="ch-icon" style="background:' + k.color + '">' + icon(k.icon) + '</div>' +
      '<div><h3>' + esc(c.title) + '</h3><p>' + esc(k.label) + ' · ' + esc(challengeTarget(c)) + '</p></div>' +
      '<button class="modal-close" data-action="close-modal">' + icon('close') + '</button></div>' +
      '<div class="modal-body"><p class="cd-desc">' + esc(c.description || k.blurb) + '</p>' +
      routeBlock +
      (geo ? '<div class="modal-map">' + mapWrapHtml('cdmap', true) + '</div>' : '') +
      '<div class="detail-stats">' +
      '<div class="detail-stat"><span>Target</span><b>' + esc(challengeTarget(c)) + '</b></div>' +
      '<div class="detail-stat"><span>Members</span><b>' + D.fmtNum(c.members || 0) + '</b></div>' +
      '<div class="detail-stat"><span>Prize pool</span><b>' + (c.prizeBr ? D.fmtNum(c.prizeBr) + ' Br' : '—') + '</b></div>' +
      '<div class="detail-stat"><span>Created by</span><b>' + esc(c.createdBy || c.ownerName || 'Athlete') + '</b></div></div>' +
      '<div class="cd-actions">' +
      '<button class="btn btn-secondary btn-sm" data-challenge-standings="' + esc(c.id) + '">' + icon('trophy') + ' Standings table</button>' +
      (c.mode === 'head_to_head' && c.inviteStatus === 'pending' && c.opponentId === myId()
        ? '<button class="btn btn-primary btn-sm" data-invite="accept" data-id="' + esc(c.id) + '">Accept duel</button>' +
          '<button class="btn btn-ghost btn-sm" data-invite="decline" data-id="' + esc(c.id) + '">Decline</button>'
        : '<button class="btn btn-secondary btn-sm" data-challenge-record="' + esc(c.id) + '">' + icon('record') + ' Record this challenge</button>' +
          '<button class="btn ' + (joined ? 'btn-ghost' : 'btn-primary') + ' btn-sm" data-challenge="' + esc(c.id) + '">' +
          (joined ? icon('check') + ' Joined' : 'Join challenge') + '</button>') +
      '</div></div>';
    openModal(html, 'challenge-modal');
    if (geo) {
      const markers = [
        { lat: c.startLat, lng: c.startLng, label: 'A', color: '#12A88A' },
        { lat: c.endLat, lng: c.endLng, label: 'B', color: '#FF5A1F' }
      ];
      const eng = mountMap('wrap_cdmap', {
        city: state.city, routes: [], mode: 'multi', markers: markers,
        osm: state.basemap === 'osm', terrain: false, heat: false,
        interactive: true, onTilesFailed: tilesFailed
      }, 'modal');
      fitEngineToPoints(eng, { lat: c.startLat, lng: c.startLng }, { lat: c.endLat, lng: c.endLng });
    }
  }

  function createMarkers() {
    const f = state.challengeForm;
    if (!f) return [];
    if (!challengeKind(f.kind).needsRoute) return [];
    return [
      { lat: f.startLat, lng: f.startLng, label: 'A', color: '#12A88A' },
      { lat: f.endLat, lng: f.endLng, label: 'B', color: '#FF5A1F' }
    ];
  }
  function setChallengePoint(which, lat, lng) {
    const f = state.challengeForm;
    if (!f || !challengeKind(f.kind).needsRoute) return;
    if (which === 'start') { f.startLat = lat; f.startLng = lng; }
    else { f.endLat = lat; f.endLng = lng; }
    if (state.modalMapEngine) state.modalMapEngine.setMarkers(createMarkers());
    updateCreatePoints();
    toast((which === 'start' ? 'Start' : 'Destination') + ' placed near ' + D.nearestPlace(lat, lng).name);
  }
  function renderCreateFields() {
    const f = state.challengeForm;
    if (!f) return;
    const k = challengeKind(f.kind);
    const blurb = $('#ccBlurb');
    if (blurb) blurb.innerHTML = icon('info') + '<span>' + esc(k.blurb) + '</span>';
    let fields = '';
    if (k.needsKm) fields += '<label class="fld"><span>Distance (km)</span><input id="ccKm" class="text-input" type="number" min="0" step="0.1" placeholder="e.g. 10"></label>';
    if (k.needsTime) fields += '<label class="fld"><span>Target time (minutes)</span><input id="ccTime" class="text-input" type="number" min="0" placeholder="e.g. 60"></label>';
    if (k.needsElev) fields += '<label class="fld"><span>Elevation target (m)</span><input id="ccElev" class="text-input" type="number" min="0" placeholder="e.g. 1000"></label>';
    if (!fields) fields = '<div class="cc-nohint">' + icon('info') + ' This type needs no extra numbers — the map points define the challenge.</div>';
    const box = $('#ccFields');
    if (box) box.innerHTML = fields;
    if ($('#ccKm')) $('#ccKm').value = f.targetKm;
    if ($('#ccTime')) $('#ccTime').value = f.targetTime;
    if ($('#ccElev')) $('#ccElev').value = f.targetElev;
    const tog = $('#ccPickToggle');
    if (tog) tog.hidden = !k.needsRoute;
    const duel = $('#ccDuelFields');
    if (duel) duel.hidden = f.mode !== 'head_to_head';
    const note = $('#ccNote');
    if (note) note.textContent = f.mode === 'head_to_head'
      ? 'Timers stop automatically at the goal distance.'
      : (k.needsRoute ? 'Recording can only begin within a 50 m geofence of point A.'
                      : 'Recorded anywhere in Ethiopia — no geofence.');
    if (state.modalMapEngine) state.modalMapEngine.setMarkers(createMarkers());
    updateCreatePoints();
  }
  function updateCreatePoints() {
    const f = state.challengeForm;
    const box = $('#ccPoints');
    if (!f || !box) return;
    if (!challengeKind(f.kind).needsRoute) {
      box.innerHTML = '<div class="ch-anywhere">' + icon('globe') + ' No map points needed — runners record this anywhere.</div>';
      return;
    }
    const a = D.nearestPlace(f.startLat, f.startLng), b = D.nearestPlace(f.endLat, f.endLng);
    const km = D.haversine([f.startLat, f.startLng], [f.endLat, f.endLng]);
    box.innerHTML = '<div class="ccp"><span class="ch-pin start"></span><div><b>A · Start</b><span>' + esc(a.name) + ' · ' + esc(coord(f.startLat, f.startLng)) + '</span></div></div>' +
      '<div class="ccp"><span class="ch-pin end"></span><div><b>B · Destination</b><span>' + esc(b.name) + ' · ' + esc(coord(f.endLat, f.endLng)) + '</span></div></div>' +
      '<div class="ccp-dist">' + icon('route') + ' Straight-line ' + km.toFixed(2) + ' km · geofence 50 m</div>';
  }
  function openChallengeCreate() {
    const f = state.challengeForm = {
      kind: 'route', title: '', description: '', picking: 'start',
      startLat: 9.0107, startLng: 38.7610, endLat: 9.1150, endLng: 38.7550,
      targetKm: '', targetTime: '', targetElev: '', prize: '',
      visibility: 'everyone', mode: 'open', opponent: '', goalKm: '5'
    };
    const kindOpts = D.CHALLENGE_KINDS.map(k => '<option value="' + k.id + '">' + esc(k.label) + '</option>').join('');
    const visOpts = D.CHALLENGE_VISIBILITY.map(v => '<option value="' + v.id + '">' + esc(v.label) + '</option>').join('');
    const html = '<div class="modal-head">' +
      '<div class="ch-icon" style="background:#E8582B">' + icon('flag') + '</div>' +
      '<div><h3>Create a challenge</h3><p>Set the rules, choose who can join, and place the start &amp; destination on the map</p></div>' +
      '<button class="modal-close" data-action="close-modal">' + icon('close') + '</button></div>' +
      '<div class="cc-body"><div class="cc-form">' +
      '<label class="fld"><span>Challenge name</span><input id="ccTitle" class="text-input" type="text" maxlength="60" placeholder="e.g. Meskel to Entoto"></label>' +
      '<label class="fld"><span>Type</span><select id="ccKind" class="text-input">' + kindOpts + '</select></label>' +
      '<label class="fld"><span>Who can see &amp; join</span><select id="ccVisibility" class="text-input">' + visOpts + '</select></label>' +
      '<label class="fld"><span>Format</span><select id="ccMode" class="text-input">' +
      '<option value="open">Open challenge · everyone who joins</option>' +
      '<option value="head_to_head">1 vs 1 duel · fastest to the distance</option></select></label>' +
      '<div id="ccDuelFields" hidden>' +
      '<label class="fld"><span>Opponent username</span><input id="ccOpponent" class="text-input" placeholder="their_unique_username"></label>' +
      '<label class="fld"><span>Distance goal (km)</span><input id="ccGoalKm" class="text-input" type="number" min="0.1" step="0.1" value="5"></label>' +
      '<div class="cc-duel-note">' + icon('clock') + ' Both timers stop automatically at the goal. The faster finisher wins.</div></div>' +
      '<div class="cc-blurb" id="ccBlurb"></div>' +
      '<label class="fld"><span>Description</span><textarea id="ccDesc" class="text-input" rows="2" placeholder="What are the rules?"></textarea></label>' +
      '<div class="cc-fields" id="ccFields"></div>' +
      '<label class="fld"><span>Prize pool (Birr)</span><input id="ccPrize" class="text-input" type="number" min="0" placeholder="e.g. 1500"></label>' +
      '</div><div class="cc-map-col">' +
      '<div class="cc-pick-head"><span class="insight-title">' + icon('map') + ' Place points on the map</span>' +
      '<div class="seg-toggle" id="ccPickToggle">' +
      '<button data-pick-point="start" class="active">A · Start</button>' +
      '<button data-pick-point="end">B · Destination</button></div></div>' +
      '<div class="modal-map cc-map">' + mapWrapHtml('ccmap', true) + '</div>' +
      '<div class="cc-points" id="ccPoints"></div></div></div>' +
      '<div class="cc-footer"><span class="cc-note" id="ccNote"></span>' +
      '<button class="btn btn-secondary btn-sm" data-action="close-modal">Cancel</button>' +
      '<button class="btn btn-primary btn-sm" data-action="challenge-save">' + icon('check') + ' Create challenge</button></div>';
    openModal(html, 'create-modal');
    renderCreateFields();
    const eng = mountMap('wrap_ccmap', {
      city: state.city, routes: [], mode: 'multi', terrain: false, heat: false,
      interactive: true, osm: state.basemap === 'osm',
      markers: createMarkers(), onTilesFailed: tilesFailed,
      onPick: (lat, lng) => setChallengePoint(f.picking, lat, lng)
    }, 'modal');
    fitEngineToPoints(eng, { lat: f.startLat, lng: f.startLng }, { lat: f.endLat, lng: f.endLng });
    updateCreatePoints();
  }
  function saveChallenge() {
    const f = state.challengeForm;
    if (!f) return;
    const title = ($('#ccTitle') && $('#ccTitle').value.trim()) || '';
    if (!title) { toast('Give your challenge a name first'); return; }
    const mode = ($('#ccMode') && $('#ccMode').value) || 'open';
    const visibility = ($('#ccVisibility') && $('#ccVisibility').value) || 'everyone';
    const opponent = ($('#ccOpponent') && $('#ccOpponent').value.trim().toLowerCase()) || '';
    const goalKm = parseFloat(($('#ccGoalKm') && $('#ccGoalKm').value) || '') || 5;
    if (mode === 'head_to_head' && !opponent) { toast('Enter the username of the friend you want to challenge'); return; }
    if (visibility === 'friends' && !requireAccount('Sign in to create a friends-only challenge')) return;
    const k = challengeKind(f.kind);
    const km = parseFloat(($('#ccKm') && $('#ccKm').value) || '') || 0;
    const mins = parseFloat(($('#ccTime') && $('#ccTime').value) || '') || 0;
    const elev = parseInt(($('#ccElev') && $('#ccElev').value) || '', 10) || 0;
    const prize = parseInt(($('#ccPrize') && $('#ccPrize').value) || '', 10) || 0;
    const desc = ($('#ccDesc') && $('#ccDesc').value.trim()) || k.blurb;
    const u = meUser();
    let opponentId = '';
    if (mode === 'head_to_head' && AUTH() && AUTH().searchUsers) {
      const found = (AUTH().searchUsersSync ? AUTH().searchUsersSync(opponent) : []).find(x => x.username === opponent);
      opponentId = found ? found.id : '';
    }
    const c = {
      id: 'ch_' + Date.now(), kind: f.kind, title: title, description: desc,
      startLat: k.needsRoute ? f.startLat : null, startLng: k.needsRoute ? f.startLng : null,
      startName: k.needsRoute ? D.nearestPlace(f.startLat, f.startLng).name : '',
      endLat: k.needsRoute ? f.endLat : null, endLng: k.needsRoute ? f.endLng : null,
      endName: k.needsRoute ? D.nearestPlace(f.endLat, f.endLng).name : '',
      targetKm: mode === 'head_to_head' ? goalKm : km,
      targetSeconds: Math.round(mins * 60), targetElevationM: elev,
      segmentId: '', geofenceM: k.needsRoute ? 50 : 0,
      prizeBr: prize, members: mode === 'head_to_head' ? 1 : 0, joined: true,
      createdBy: u ? u.username : 'Guest', endsAt: '',
      ownerId: u ? u.id : '', ownerName: u ? u.username : '',
      visibility: mode === 'head_to_head' ? 'friends' : visibility,
      mode: mode, opponentName: opponent, opponentId: opponentId,
      inviteStatus: mode === 'head_to_head' ? 'pending' : '',
      autoStop: mode === 'head_to_head' || (k.needsKm && km > 0),
      createdAt: new Date().toISOString()
    };
    if (mode === 'head_to_head' && !opponentId && API().status().online) {
      API().addChallenge(c).then(remote => {
        const idx = state.challenges.findIndex(x => x.id === c.id);
        if (idx >= 0 && remote && remote.id) state.challenges[idx] = normalizeChallenge(remote);
        toast('Duel created — waiting for @' + opponent + ' to accept');
      }).catch(() => toast('Duel created locally — waiting for @' + opponent));
    } else {
      API().addChallenge(c);
    }
    state.challenges = [c].concat(state.challenges);
    if (state.joinedChallenges.indexOf(c.id) < 0) state.joinedChallenges.push(c.id);
    API().joinChallenge(c.id, myId() || 'anon', myName());
    closeModal();
    state.view = 'community';
    render();
    toast(mode === 'head_to_head' ? '1 vs 1 duel created — ' + goalKm + ' km, timer stops automatically'
                                  : 'Challenge created — ' + title);
  }
  function recordChallenge(id) {
    const c = state.challenges.find(x => x.id === id);
    if (!c) return;
    closeModal();
    const r = state.rec;
    r.challengeId = id; r.geofenceOk = !hasRoute(c); r.geofenceDistance = null;
    r.status = 'idle'; r.mode = 'gps';
    r.goalKm = (c.targetKm > 0 && (c.mode === 'head_to_head' || c.autoStop || c.kind === 'distance_time')) ? c.targetKm : 0;
    r.autoStop = r.goalKm > 0; r.goalHit = false; r.goalElapsed = 0;
    if (state.joinedChallenges.indexOf(id) < 0) { state.joinedChallenges.push(id); API().joinChallenge(id, 'me'); }
    setView('record');
    if (hasRoute(c)) {
      // The record view's own watch (primeGps → applyGpsFix) updates the
      // geofence. Starting a second watch here produced duplicate fixes.
      toast('Recording is locked to the start at ' + (c.startName || 'Point A'));
    } else {
      r.geofenceOk = true;
      toast('Distance challenge — record anywhere · ' + challengeTarget(c));
    }
  }

  function offlineLeaderboard(c) {
    const rows = (API().progressRows ? API().progressRows() : []).filter(r => r.challengeId === c.id);
    const members = {}, uid = myId();
    if (uid) members[uid] = myName();
    return D.buildLeaderboard(c, rows, uid, members);
  }
  function loadLeaderboard(id) {
    const c = state.challenges.find(x => x.id === id);
    if (!c) return Promise.resolve(null);
    const A = API();
    if (A.status().online && A.leaderboard) {
      return A.leaderboard(id).then(lb => { state.leaderboardCache[id] = lb; return lb; })
        .catch(() => offlineLeaderboard(c));
    }
    return Promise.resolve(offlineLeaderboard(c));
  }
  function leaderboardHtml(lb, c) {
    if (!lb) return '<div class="lb-empty">Standings are not available for this challenge.</div>';
    const done = lb.rows.filter(r => r.completed).length;
    const mine = lb.rows.find(r => r.me);
    const metricLabel = lb.ranking === 'time' ? 'Fastest finish wins' : 'Most progress wins';
    const head = '<div class="lb-summary">' +
      '<div><b>' + esc(metricLabel) + '</b><span>Target ' + (lb.target > 0 ? lb.target.toFixed(2) + ' ' + esc(lb.unit) : 'open') + '</span></div>' +
      '<div><b>' + done + ' / ' + lb.rows.length + '</b><span>Completed</span></div>' +
      '<div><b>' + (mine ? '#' + mine.rank : '—') + '</b><span>Your position</span></div>' +
      (c.mode === 'head_to_head'
        ? '<div><b>' + esc(c.ownerName || 'Challenger') + ' vs ' + esc(c.opponentName || 'Opponent') + '</b><span>1 vs 1 duel</span></div>' : '') +
      '</div>';
    if (!lb.rows.length) return head + '<div class="lb-empty">No one has recorded progress yet. Join the challenge and record a run to appear here.</div>';
    const rows = lb.rows.map(r =>
      '<tr class="' + (r.me ? 'lb-me' : '') + '">' +
      '<td class="lb-rank">#' + r.rank + '</td>' +
      '<td><b>' + esc(r.athleteName) + '</b>' + (r.me ? ' <span class="pill green">You</span>' : '') + '</td>' +
      '<td>' + esc(r.progressLabel) + '</td>' +
      '<td>' + (r.completed ? '<span class="pill green">Completed</span>' : '<span class="pill">In progress</span>') + '</td>' +
      '<td class="lb-result">' + esc(r.result) + '</td></tr>').join('');
    return head + '<div class="lb-wrap"><table class="lb-table"><thead><tr>' +
      '<th>Rank</th><th>Athlete</th><th>Progress</th><th>Status</th><th>Result</th></tr></thead>' +
      '<tbody>' + rows + '</tbody></table></div>' +
      '<p class="sensor-note">Standings update from recorded activities. For a distance or time trial the timer stops automatically at the goal; ' +
      'completed athletes are ranked by their finish time, everyone else by progress.</p>';
  }
  function openChallengeStandings(id) {
    const c = state.challenges.find(x => x.id === id);
    if (!c) return;
    const html = '<div class="modal-head">' +
      '<div class="ch-icon" style="background:#B8860B">' + icon('trophy') + '</div>' +
      '<div><h3>' + esc(c.title) + ' · Standings</h3><p>' + esc(challengeTarget(c)) + ' · ' +
      esc((D.CHALLENGE_VISIBILITY.find(v => v.id === c.visibility) || {}).label || 'Everyone') + '</p></div>' +
      '<button class="modal-close" data-action="close-modal">' + icon('close') + '</button></div>' +
      '<div class="modal-body" id="lbRoot"><div class="lb-empty">Loading standings…</div></div>';
    openModal(html, 'standings-modal');
    loadLeaderboard(id).then(lb => {
      const root = $('#lbRoot');
      if (root) root.innerHTML = leaderboardHtml(lb, c);
    });
  }
  function respondInvite(id, decision) {
    const c = state.challenges.find(x => x.id === id);
    if (!c) return;
    const A = API();
    if (A.status().online && A.respondChallenge) {
      A.respondChallenge(id, decision).then(remote => {
        const idx = state.challenges.findIndex(x => x.id === id);
        if (idx >= 0) state.challenges[idx] = normalizeChallenge(remote && remote.id ? remote : Object.assign({}, c, { inviteStatus: decision === 'accept' ? 'accepted' : 'declined' }));
        toast(decision === 'accept' ? 'Duel accepted — you are on the standings' : 'Duel declined');
        if (state.view === 'community') render(); else closeModal();
      }).catch(() => offlineInvite(c, decision));
      return;
    }
    offlineInvite(c, decision);
  }
  function offlineInvite(c, decision) {
    c.inviteStatus = decision === 'accept' ? 'accepted' : 'declined';
    API().updateChallenge(c);
    toast(decision === 'accept' ? 'Duel accepted — you are on the standings' : 'Duel declined');
    if (state.view === 'community') render(); else closeModal();
  }
  function submitChallengeProgress(c, dist, seconds, gain) {
    if (!c) return;
    const target = c.targetKm > 0 ? c.targetKm : (c.targetElevationM || 0);
    const completed = target > 0 && (c.targetKm > 0 ? dist >= target * 0.999 : gain >= target);
    API().postProgress({
      challengeId: c.id, athleteId: myId() || 'anon', athleteName: myName(),
      distanceKm: dist, durationSec: Math.round(seconds), elevationM: Math.round(gain),
      completed: completed, finishedAt: completed ? new Date().toISOString() : ''
    }).then(() => {
      delete state.leaderboardCache[c.id];
      if (completed) toast('Challenge complete — ' + D.fmtDuration(seconds) + ' · standings updated');
    });
  }

  function openActivity(id) {
    const a = state.activities.find(x => x.id === id);
    if (!a) return;
    const stats = [
      ['Distance', a.distance.toFixed(2) + ' km'], ['Time', D.fmtDuration(a.duration)],
      ['Avg pace', D.fmtPace(a.pace) + ' /km'], ['Elev gain', '+' + D.fmtNum(a.gain) + ' m'],
      ['Calories', D.fmtNum(a.calories) + ' kcal']
    ];
    const splitRows = computeSplits(a.track, a.duration);
    const splits = splitRows.map(s =>
      '<tr><td>' + s.km + '</td><td>' + D.fmtPace(s.pace) + '</td><td>+' + Math.max(0, Math.round(s.elev)) + ' m</td></tr>');
    if (!splits.length) splits.push('<tr><td colspan="3" class="muted">No GPS timestamps for kilometre splits.</td></tr>');
    const html = '<div class="modal-head">' + typeBadge(a.type) +
      '<div><h3>' + esc(a.title) + '</h3>' +
      '<p>' + esc(a.athlete ? a.athlete.name : 'You') + ' · ' + esc(D.relativeDay(a.date)) + ' · ' + esc(a.cityObj.name) + ' · ' + (a.type === 'ride' ? 'Ride' : 'Run') + '</p></div>' +
      '<button class="btn btn-ghost btn-sm" data-action="modal-replay">' + icon('play') + ' Replay</button>' +
      '<button class="btn btn-primary btn-sm" data-action="save-to-gallery" data-id="' + a.id + '">' + icon('image') + ' Save to Gallery</button>' +
      shareButtonsHtml(a) +
      '<button class="modal-close" data-action="close-modal">' + icon('close') + '</button></div>' +
      '<div class="modal-body"><div class="modal-map">' + mapWrapHtml('modalmap', true) + '</div>' +
      '<div class="detail-stats">' + stats.map(s => '<div class="detail-stat"><span>' + s[0] + '</span><b>' + s[1] + '</b></div>').join('') + '</div>' +
      '<div class="coord-strip">' + icon('target') +
      '<span><b>Start</b> ' + esc(coord(a.startLat != null ? a.startLat : a.track[0].lat, a.startLng != null ? a.startLng : a.track[0].lng)) + '</span>' +
      '<span><b>Finish</b> ' + esc(coord(a.endLat != null ? a.endLat : a.track[a.track.length - 1].lat, a.endLng != null ? a.endLng : a.track[a.track.length - 1].lng)) + '</span>' +
      (a.gpsAccuracyM ? '<span class="pill">' + icon('crosshair') + ' GPS ±' + Math.round(a.gpsAccuracyM) + ' m</span>' : '') +
      '<span class="pill">' + icon('save') + (a.hrSource && a.hrSource !== 'none' ? esc(a.hrSource) : 'No HR sensor') + '</span></div>' +
      '<div class="elev-chart"><div class="insight-title" style="margin-bottom:8px">' + icon('mountain') + ' ' + t('act.elevation') + '</div>' +
      elevationChart(a.track, a.type === 'ride' ? '#0E8A6A' : '#FF5A1F') + '</div>' +
      '<div class="two-grid" style="margin-top:18px">' +
      '<div><div class="insight-title" style="margin-bottom:8px">' + t('act.splits') + '</div>' +
      '<table class="split-table"><thead><tr><th>Km</th><th>Pace</th><th>Elev</th></tr></thead><tbody>' + splits.join('') + '</tbody></table></div>' +
      '<div><div class="insight-title" style="margin-bottom:8px">Notes</div>' +
      '<p class="muted" style="font-size:12px;line-height:1.7">' + esc(a.note) + '</p>' +
      '<div class="feed-tags">' + (a.tags || []).map(x => '<span class="tag">' + esc(x) + '</span>').join('') + '</div>' +
      '</div></div></div>';
    openModal(html);
    const eng = mountMap('wrap_modalmap', {
      city: a.city, routes: [a], mode: 'single', filter: 'all', heat: false,
      terrain: false, replay: true, interactive: true, osm: state.basemap === 'osm', onTilesFailed: tilesFailed
    }, 'modal');
    if (eng) { eng.focusId = a.id; eng.fitRoute(a); eng.replay.t = 1; eng.render(); }
  }
  function openSegment(id) {
    const s = state.segments.find(x => x.id === id);
    if (!s) return;
    const cityName = (D.CITIES[s.city] || D.CITIES.addis).name;
    const best = s.bestSec > 0
      ? '<span class="pill gold">' + icon('star') + 'Course record · ' + esc(s.bestAthleteName || s.ownerName || 'Athlete') + ' · ' + D.fmtDuration(s.bestSec) + '</span>'
      : '<span class="pill">' + icon('trophy') + 'No time recorded yet</span>';
    const html = '<div class="modal-head"><div class="seg-cat">' + esc(s.cat) + '</div>' +
      '<div><h3>' + esc(s.name) + '</h3>' +
      '<p>' + esc(cityName) + ' · ' + s.km.toFixed(1) + ' km · +' + D.fmtNum(s.gain) + ' m · ' + D.fmtNum(s.attempts) + ' ' + t('seg.attempts') + '</p></div>' +
      '<button class="modal-close" data-action="close-modal">' + icon('close') + '</button></div>' +
      '<div class="modal-body"><div class="row" style="gap:10px;margin-bottom:16px">' +
      '<span class="pill accent">' + icon('trophy') + t('seg.leaderboard') + '</span>' + best +
      (s.ownerName ? '<span class="pill">' + icon('users') + 'Created by @' + esc(s.ownerName) + '</span>' : '') + '</div>' +
      '<div class="card">' + leaderRows(s.id, true) + '</div>' +
      '<div class="card card-pad" style="margin-top:16px;background:linear-gradient(120deg,var(--accent-soft),transparent)">' +
      '<div class="row"><span class="insight-icon">' + icon('mountain') + '</span><div><div class="insight-title">Segment details</div>' +
      '<div class="insight-text">Start ' + esc(coord(s.startLat, s.startLng)) + ' · finish ' + esc(coord(s.endLat, s.endLng)) + '. ' +
      'Record an activity on the same start and finish (within about 150 m) and your time is added automatically.</div></div></div></div></div>';
    openModal(html);
  }

  function stopRecorder() {
    const r = state.rec;
    if (r.raf) cancelAnimationFrame(r.raf);
    r.raf = null;
    if (SENS()) SENS().gps.stop();
    if (r.status !== 'done') r.status = 'idle';
  }
  function startRecorder() {
    const r = state.rec;
    const c = r.challengeId ? state.challenges.find(x => x.id === r.challengeId) : null;
    if (c && hasRoute(c) && !r.geofenceOk) { toast('Move to the challenge starting point before recording'); return; }
    if (!SENS() || !SENS().gps.available()) { toast('This browser has no GPS. Open RUCHA on your phone to record.'); return; }
    const sg = SENS().gps.status();
    if (!sg.secure) { toast('GPS needs a secure https connection'); return; }
    const nameEl = $('#recName'); if (nameEl) r.name = nameEl.value.trim();
    r.mode = 'gps';
    r.startTime = Date.now(); r.pausedTotal = 0; r.pausedAt = 0;
    r.elapsed = 0; r.idx = 0; r.splits = []; r.last = performance.now();
    r.hrAvailable = !!(SENS().heart.status().connected);
    r.hrValue = r.hrAvailable ? SENS().heart.status().bpm : null; r.hrSamples = []; r.hrMax = 0;
    r.cadSamples = []; r.pwSamples = [];
    r.realTrack = []; r.track = []; r.gpsAccuracy = null;
    if (!r.challengeId && state.goal.km > 0) {
      r.goalKm = state.goal.km; r.autoStop = true;
      r.goalHit = false; r.goalElapsed = 0;
    }
    if (!startGpsWatch()) { toast(SENS().gps.status().error || 'Could not start GPS'); return; }
    r.status = 'running';
    // If the prime pass already has a recent fix, put the first point on the
    // map now instead of showing 0.00 km until the next satellite callback.
    const seed = r.lastFix;
    let seeded = false;
    if (seed && Date.now() - (seed.t || 0) <= 60000 &&
        (seed.accuracy == null || seed.accuracy <= 45)) {
      applyGpsFix(seed);
      seeded = true;
    }
    toast(seeded ? 'Recording started.' : 'Recording started. Waiting for your first GPS point.');
    loopRecorder();
  }
  function loopRecorder() {
    const r = state.rec;
    if (r.status !== 'running') return;
    r.elapsed = Math.max(0, (Date.now() - r.startTime - r.pausedTotal) / 1000);
    if (r.lastFixAt && Date.now() - r.lastFixAt > 15000 && r.gpsState !== 'lost') {
      r.gpsState = 'lost'; refreshGpsPill();
    }
    if (r.autoStop && r.goalKm > 0 && !r.goalHit) {
      const m = currentMetrics();
      if (m.dist >= r.goalKm * 0.999) {
        r.goalHit = true;
        r.goalElapsed = r.elapsed;
        finishRecorder();
        return;
      }
    }
    updateRecUI();
    r.raf = requestAnimationFrame(loopRecorder);
  }
  function updateRecUI() {
    const r = state.rec, m = currentMetrics();
    const set = (id, v) => { const el = $('#' + id); if (el) el.textContent = v; };
    set('recDist', m.dist.toFixed(2));
    set('recTime', D.fmtDuration(r.elapsed));
    set('recPace', m.pace > 0 ? D.fmtPace(m.pace) : '--:--');
    set('recElev', String(Math.round(m.gain)));
    set('recHR', r.hrSamples.length
      ? String(Math.round(r.hrSamples.reduce((a, b) => a + b, 0) / r.hrSamples.length))
      : (r.hrValue != null ? String(Math.round(r.hrValue)) : '--'));
    set('recCal', String(Math.round(m.cal)));
    if (r.cadValue != null) set('recCad', String(Math.round(r.cadValue)));
    if (r.pwValue != null) set('recPow', String(Math.round(r.pwValue)));
    const body = $('#recSplits');
    if (body) {
      const rows = computeSplits(m.tr, r.elapsed);
      body.innerHTML = rows.length
        ? rows.slice(-8).map(x => '<tr><td>' + x.km + '</td><td>' + D.fmtPace(x.pace) + ' /km</td><td>+' + Math.round(x.elev) + ' m</td></tr>').join('')
        : '<tr><td colspan="3" class="muted" style="text-align:center;padding:18px">Waiting for the first kilometre…</td></tr>';
    }
  }
  function finishRecorder() {
    const r = state.rec;
    if (r.raf) cancelAnimationFrame(r.raf);
    r.raf = null;
    if (SENS()) SENS().gps.stop();
    let tr = currentTrack().slice();
    if (tr.length < 2) {
      r.status = 'idle'; r.realTrack = []; r.track = null;
      if (SENS()) { SENS().gps.stop(); }
      toast('Not enough GPS points were recorded to save this activity.');
      render();
      return;
    }
    if (r.status === 'paused') r.pausedTotal += Date.now() - (r.pausedAt || Date.now());
    // smoothing trails the real position by a few metres; close the track on the last good fix
    if (r.lastFix && tr.length && r.lastFix.accuracy != null && r.lastFix.accuracy <= 25) {
      const lp = tr[tr.length - 1];
      const gapM = SENS().gps.distanceM(lp, r.lastFix);
      if (gapM >= 1 && gapM <= 30 && r.lastFix.t >= lp.t) {
        tr.push({ lat: +r.lastFix.lat.toFixed(7), lng: +r.lastFix.lng.toFixed(7), ele: lp.ele, d: lp.d + gapM / 1000,
                  t: r.lastFix.t, accuracy: Math.round(r.lastFix.accuracy) });
      }
    }
    r.elapsed = Math.max(1, (Date.now() - r.startTime - r.pausedTotal) / 1000);
    const goalTime = r.goalHit ? Math.max(1, r.goalElapsed) : 0;
    if (r.goalHit && r.goalKm > 0) tr = trimTrackAt(tr, r.goalKm);
    const dist = tr[tr.length - 1].d;
    const durationSec = Math.round(goalTime || r.elapsed);
    const gain = D.gainFromTrack(tr);
    const pace = D.paceFor(dist, durationSec);
    const cal = D.caloriesFor(dist, durationSec, gain, r.type);
    const nameEl = $('#recName');
    const custom = (nameEl && nameEl.value.trim()) || r.name || '';
    const c = r.challengeId ? state.challenges.find(x => x.id === r.challengeId) : null;
    const nearby = D.nearestPlace(tr[0].lat, tr[0].lng);
    const baseTitle = c ? c.title : (r.type === 'ride' ? 'Evening Ride' : 'Morning Run');
    const title = custom || (baseTitle + ' · ' + (nearby.name !== 'Open country' ? nearby.name : (D.CITIES[state.city] || D.CITIES.addis).name));
    const hrAvg = r.hrSamples.length ? Math.round(r.hrSamples.reduce((a, b) => a + b, 0) / r.hrSamples.length) : null;
    const a = {
      id: 'live_' + Date.now(), title: title, type: r.type, user: 'me', city: state.city,
      km: dist, distance: dist, duration: durationSec, pace: pace,
      hr: hrAvg, avgHr: hrAvg, days: 0, seed: 1, kudos: 0, comments: 0,
      note: 'Recorded with device GPS. Distance, pace and elevation come from your phone\u2019s position fixes.' +
        (goalTime ? ' Goal ' + D.fmtNum(r.goalKm) + ' km reached in ' + D.fmtDuration(durationSec) + ' — the timer stopped automatically.' : ''),
      ownerId: myId(), ownerName: myName(), visibility: 'private',
      cityObj: D.CITIES[state.city] || D.CITIES.addis, anchors: [], track: tr,
      gain: gain, date: new Date(), athlete: athleteFrom({ athleteName: myName(), athleteId: myId() || 'me' }), calories: cal,
      tags: ['Device GPS', c ? 'Challenge' : 'Open run'],
      startLat: tr[0].lat, startLng: tr[0].lng,
      endLat: tr[tr.length - 1].lat, endLng: tr[tr.length - 1].lng,
      gpsAccuracyM: Math.round(avgAccuracy(tr)),
      hrSource: hrAvg != null ? 'Bluetooth HR' : 'none',
      maxHr: r.hrMax || null,
      avgCadence: r.cadSamples.length ? Math.round(r.cadSamples.reduce((x, y) => x + y, 0) / r.cadSamples.length) : null,
      avgPowerW: r.pwSamples.length ? Math.round(r.pwSamples.reduce((x, y) => x + y, 0) / r.pwSamples.length) : null,
      source: 'gps'
    };
    state.activities.unshift(a);
    API().addActivity(toBackendActivity(a));
    matchSegmentEfforts(a);
    if (c) submitChallengeProgress(c, dist, durationSec, gain);
    if (goalTime && r.goalKm > 0) {
      const g = state.goal;
      if (!g.best || durationSec < g.best.seconds) g.best = { km: r.goalKm, seconds: durationSec, date: new Date().toISOString() };
      API().setGoalState({ km: g.km, best: g.best });
    }
    state.popularAreas = D.popularAreas(state.activities);
    if (SENS()) SENS().gps.stop();
    r.status = 'done'; r.track = null; r.realTrack = []; r.challengeId = null; r.gpsState = 'idle';
    r.goalKm = 0; r.goalHit = false; r.goalElapsed = 0; r.autoStop = false;
    toast(goalTime ? D.fmtNum(dist) + ' km goal complete · ' + D.fmtDuration(durationSec) + ' · timer stopped automatically'
                   : 'Activity saved · ' + dist.toFixed(2) + ' km · ' + title);
    render();
    setTimeout(() => openActivity(a.id), 260);
  }
  function avgAccuracy(tr) {
    const v = tr.map(p => p.accuracy).filter(x => x > 0);
    return v.length ? v.reduce((a, b) => a + b, 0) / v.length : 0;
  }
  function recAction(act) {
    const r = state.rec;
    if (act === 'start') {
      if (r.status !== 'idle' && r.status !== 'done') return;
      r.status = 'idle'; startRecorder();
      if (r.status === 'running') render();
    }
    else if (act === 'pause') {
      r.status = 'paused'; r.pausedAt = Date.now();
      if (r.filter) r.filter.markGap();
      if (r.raf) cancelAnimationFrame(r.raf); r.raf = null; render();
    }
    else if (act === 'resume') {
      r.pausedTotal += Date.now() - (r.pausedAt || Date.now());
      if (r.filter) r.filter.markGap();
      r.status = 'running'; r.last = performance.now(); render(); loopRecorder();
    }
    else if (act === 'finish') {
      if (r.status === 'running' || r.status === 'paused') finishRecorder();
    }
  }

  function renderNav() {
    $('#mainNav').innerHTML = NAV.map(n =>
      '<button class="nav-item' + (state.view === n.id ? ' active' : '') + '" data-nav="' + n.id + '">' +
      '<span class="nav-icon">' + icon(n.icon) + '</span><span data-i18n="' + n.key + '"></span>' +
      '</button>').join('');
    $('#mobileNav').innerHTML = NAV.slice(0, 5).map(n =>
      '<button class="' + (state.view === n.id ? 'active' : '') + '" data-nav="' + n.id + '">' + icon(n.icon) + '<span data-i18n="' + n.key + '"></span></button>').join('');
  }
  function render() {
    document.documentElement.setAttribute('data-theme', state.theme);
    const cr = CRUMBS[state.view];
    $('#crumbTitle').textContent = cr.title;
    $('#crumbSub').textContent = cr.sub;
    $('#themeToggle').innerHTML = icon(state.theme === 'dark' ? 'sun' : 'moon');
    updateAccountChip();
    applyActivityPrivacy();

    if (state.mapEngine) { state.mapEngine.destroy(); state.mapEngine = null; }
    if (state.modalMapEngine) { state.modalMapEngine.destroy(); state.modalMapEngine = null; }

    renderNav();
    const views = { dashboard: viewDashboard, explore: viewExplore, record: viewRecord, activities: viewActivities, gallery: viewGallery, segments: viewSegments, community: viewCommunity, profile: viewProfile };
    $('#viewRoot').innerHTML = '<div class="view">' + (views[state.view] || viewDashboard)() + '</div>';
    hideTooltip();
    hydrate(document.body);

    const mapId = state.view === 'dashboard' ? 'wrap_dash' : state.view === 'explore' ? 'wrap_explore' : state.view === 'record' ? 'wrap_rec' : null;
    if (mapId && $('#' + mapId)) {
      const common = { city: state.city, routes: state.view === 'dashboard' ? myActivities() : state.activities, filter: state.mapFilter, heat: state.heat, terrain: false, interactive: true, osm: state.basemap === 'osm', distinct: state.distinctLines, onTilesFailed: tilesFailed };
      let opts;
      if (state.view === 'dashboard') opts = Object.assign({}, common, { mode: 'multi', replay: true });
      else if (state.view === 'explore') opts = Object.assign({}, common, { mode: 'multi', suggested: false });
      else opts = Object.assign({}, common, { mode: 'live', filter: 'all', heat: false, routes: (state.rec.realTrack && state.rec.realTrack.length) ? [{ id: 'live', type: state.rec.type, track: state.rec.realTrack, distance: 0, duration: 0, gain: 0, title: 'Live' }] : [], interactive: true });
      const eng = mountMap(mapId, opts);
      if (state.view === 'dashboard' && eng) { const mine0 = myActivities(); if (mine0.length) eng.focusId = mine0.slice().sort((a, b) => b.date - a.date)[0].id; }
      if (state.view === 'record' && eng) {
        const r0 = state.rec;
        if (r0.lastFix) {
          eng.userFix = r0.lastFix;
          eng.center = { lat: r0.lastFix.lat, lng: r0.lastFix.lng };
          eng.scale = Math.max(eng.scale, 16000);
          eng.staticDirty = true;
        }
        const tr0 = r0.realTrack || [];
        if (tr0.length) { syncLiveMap(); }
        else eng.render();
        refreshGpsPill();
        if (r0.status === 'idle') primeGps();
      }
    }
    $$('canvas[data-mini]').forEach(cv => drawMini(cv, state.activities.find(a => a.id === cv.getAttribute('data-mini'))));
    const lb = $('#liveBadge');
    if (lb) {
      const live = state.rec.status === 'running' || state.rec.status === 'paused';
      lb.hidden = !live;
      lb.classList.toggle('is-paused', state.rec.status === 'paused');
      const lbText = lb.querySelector('.live-badge-text');
      if (lbText) lbText.textContent = state.rec.status === 'paused' ? 'Paused' : 'Recording';
    }
    if (state.view === 'record' && (state.rec.status === 'running' || state.rec.status === 'paused')) {
      updateRecUI();
      syncLiveMap();
    }
    window.scrollTo({ top: 0, behavior: 'instant' });
  }
  function setView(v) {
    if (!CRUMBS[v]) return;
    if (state.view === 'record' && v !== 'record' &&
        (state.rec.status === 'idle' || state.rec.status === 'done')) {
      state.rec.challengeId = null;
      if (SENS()) SENS().gps.stop();
    }
    state.view = v;
    $('#sidebar').classList.remove('open');
    render();
  }

  function handleAction(action, el) {
    switch (action) {
      case 'close-modal': closeModal(); break;
      case 'review-consent': closeModal(); openAuthScreen({ step: 'consent' }); break;
      case 'quickstart-dismiss':
        try { localStorage.setItem('rucha_quickstart_v1', 'done'); } catch (e) {}
        render(); toast('Quick Start hidden — the full guide is under Help'); break;
      
      case 'gallery-create': openActivityPicker(); break;
      case 'save-to-gallery': openShareStudio(el.getAttribute('data-id')); break;
      case 'challenge-create': openChallengeCreate(); break;
      case 'challenge-save': saveChallenge(); break;
      case 'segment-create': openSegmentCreate(); break;
      case 'segment-save': saveSegment(); break;
      case 'club-create': openClubCreate(); break;
      case 'club-save': saveClub(); break;
      case 'connect-hr': connectHr(); break;
      case 'connect-bike': connectBike(); break;
      case 'connect-power': connectPower(); break;
      case 'connect-footpod': connectFootpod(); break;
      case 'use-device-gps': useDeviceGps(); break;
      case 'open-account': openAccountModal(); break;
      case 'auth-login': case 'auth-register': case 'auth-logout':
      case 'friend-add': case 'share-public': case 'share-friend':
      case 'set-visibility': authAction(action); break;
      case 'quick-share': openQuickShare(el.getAttribute('data-id')); break;
      case 'goal-set': setPersonalGoal(false); break;
      case 'goal-start': setPersonalGoal(true); break;
      case 'goal-clear': clearPersonalGoal(); break;
      case 'modal-replay': {
        const eng = state.modalMapEngine;
        if (!eng) break;
        const playing = eng.toggleReplay();
        el.innerHTML = icon(playing ? 'pause' : 'play') + (playing ? ' Pause' : ' Replay');
        break;
      }
      default: break;
    }
  }

  document.addEventListener('click', e => {
    if (e.target.closest('#accountBtn') || e.target.closest('#sideAccountBtn')) { openAccountModal(); return; }
    const tab = e.target.closest('[data-acct-tab]');
    if (tab) {
      const which = tab.getAttribute('data-acct-tab');
      $$('[data-acct-tab]').forEach(b => b.classList.toggle('active', b === tab));
      const lp = $('#acctLogin'), rp = $('#acctRegister');
      if (lp) lp.hidden = which !== 'login';
      if (rp) rp.hidden = which !== 'register';
      return;
    }
    const nav = e.target.closest('[data-nav]');
    if (nav) { setView(nav.getAttribute('data-nav')); return; }
    const act = e.target.closest('[data-activity]');
    if (act) { openActivity(act.getAttribute('data-activity')); return; }
    const seg = e.target.closest('[data-segment]');
    if (seg) { openSegment(seg.getAttribute('data-segment')); return; }
    const kud = e.target.closest('[data-kudos]');
    if (kud) {
      const id = kud.getAttribute('data-kudos');
      state.kudos.has(id) ? state.kudos.delete(id) : state.kudos.add(id);
      kud.classList.toggle('liked');
      const a = state.activities.find(x => x.id === id);
      kud.innerHTML = icon('kudos') + (a.kudos + (state.kudos.has(id) ? 1 : 0));
      return;
    }
    const cd = e.target.closest('[data-challenge-detail]');
    if (cd) { openChallengeDetail(cd.getAttribute('data-challenge-detail')); return; }
    const cr = e.target.closest('[data-challenge-record]');
    if (cr) { recordChallenge(cr.getAttribute('data-challenge-record')); return; }
    const pk = e.target.closest('[data-pick-point]');
    if (pk) {
      const w = pk.getAttribute('data-pick-point');
      if (state.challengeForm) state.challengeForm.picking = w;
      $$('[data-pick-point]').forEach(b => b.classList.toggle('active', b === pk));
      return;
    }
    const pa = e.target.closest('[data-popular]');
    if (pa) {
      const area = state.popularAreas[parseInt(pa.getAttribute('data-popular'), 10)];
      if (area && state.mapEngine) {
        state.mapEngine.center = { lat: area.lat, lng: area.lng };
        state.mapEngine.panX = 0; state.mapEngine.panY = 0;
        state.mapEngine.staticDirty = true; state.mapEngine.render();
        toast('Map centred on ' + (area.name || 'this popular area') + ' · ' + area.runCount + ' runs started here');
      }
      return;
    }
    const bm = e.target.closest('[data-basemap]');
    if (bm) {
      const want = bm.getAttribute('data-basemap') === 'osm' ? 'osm' : 'offline';
      state.basemap = want;
      $$('[data-basemap]').forEach(b => b.classList.toggle('active', b.getAttribute('data-basemap') === want || (want === 'offline' && b.getAttribute('data-basemap') === 'offline')));
      if (state.mapEngine) state.mapEngine.setBasemap(want === 'osm');
      if (state.modalMapEngine) state.modalMapEngine.setBasemap(want === 'osm');
      $$('.map-mode').forEach(el => el.textContent = want === 'osm' ? 'OPENSTREETMAP · ETHIOPIA' : 'RUCHA MAPS · OFFLINE');
      toast(want === 'osm' ? 'Loading OpenStreetMap street tiles — tap Street map again to retry if they are slow' : 'Switched to the offline overview');
      return;
    }
    const fa = e.target.closest('[data-friend-accept]');
    if (fa) { AUTH().friendRespond(fa.getAttribute('data-friend-accept'), 'accept').then(() => { toast('Friend request accepted'); refreshSocial(); }).catch(err => toast(err.message)); return; }
    const fd = e.target.closest('[data-friend-decline]');
    if (fd) { AUTH().friendRespond(fd.getAttribute('data-friend-decline'), 'decline').then(() => { toast('Friend request declined'); refreshSocial(); }).catch(err => toast(err.message)); return; }
    const fr = e.target.closest('[data-friend-remove]');
    if (fr) { AUTH().friendRemove(fr.getAttribute('data-friend-remove')).then(() => { toast('Friend removed'); refreshSocial(); render(); }).catch(err => toast(err.message)); return; }
    const sr = e.target.closest('[data-share-remove]');
    if (sr) { AUTH().removeShare(sr.getAttribute('data-share-remove')).then(() => { toast('Share revoked'); refreshSocial(); }).catch(err => toast(err.message)); return; }
    const cs = e.target.closest('[data-challenge-standings]');
    if (cs) { openChallengeStandings(cs.getAttribute('data-challenge-standings')); return; }
    const iv = e.target.closest('[data-invite]');
    if (iv) { respondInvite(iv.getAttribute('data-id'), iv.getAttribute('data-invite')); return; }
    const actBtn = e.target.closest('[data-action]');
    if (actBtn) { handleAction(actBtn.getAttribute('data-action'), actBtn); return; }
    const pickAct = e.target.closest('[data-pick-activity]');
    if (pickAct) { openShareStudio(pickAct.getAttribute('data-pick-activity')); return; }
    const gView = e.target.closest('[data-gallery-view]');
    if (gView) { openGalleryCard(gView.getAttribute('data-gallery-view')); return; }
    const gDl = e.target.closest('[data-gallery-download]');
    if (gDl) {
      const g = state.gallery.find(x => x.id === gDl.getAttribute('data-gallery-download'));
      if (g) { downloadDataUrl(g.dataUrl, 'rucha-' + g.id + '.jpg'); toast('Card downloaded — ready to post'); }
      return;
    }
    const gSh = e.target.closest('[data-gallery-share]');
    if (gSh) {
      const g = state.gallery.find(x => x.id === gSh.getAttribute('data-gallery-share'));
      if (g) {
        const a = state.activities.find(x => x.id === g.activityId) || state.activities[0];
        shareImage(g.dataUrl, 'rucha-' + g.id + '.jpg', a ? captionFor(a) : g.title);
      }
      return;
    }
    const gDel = e.target.closest('[data-gallery-delete]');
    if (gDel) {
      const id = gDel.getAttribute('data-gallery-delete');
      state.gallery = state.gallery.filter(x => x.id !== id);
      persistGallery(); API().deleteGallery(id); render(); toast('Card removed from Gallery');
      return;
    }
    const mapAct = e.target.closest('[data-map-action]');
    if (mapAct) {
      const a = mapAct.getAttribute('data-map-action');
      const eng = state.mapEngine;
      if (a === 'heat') { state.heat = !state.heat; mapAct.classList.toggle('on'); if (eng) eng.setOptions({ heat: state.heat }); }
      else if (a === 'terrain') { state.terrain = !state.terrain; mapAct.classList.toggle('on'); mapAct.classList.toggle('green'); if (eng) eng.setOptions({ terrain: state.terrain }); }
      else if (a === 'replay' && eng) {
        const playing = eng.toggleReplay();
        mapAct.classList.toggle('on', playing);
        mapAct.innerHTML = icon(playing ? 'pause' : 'play') + '<span>' + (playing ? t('map.replayStop') : t('map.replay')) + '</span>';
      }
      return;
    }
    const zoom = e.target.closest('[data-map-zoom]');
    if (zoom && state.mapEngine) { state.mapEngine.zoom(parseFloat(zoom.getAttribute('data-map-zoom'))); return; }
    const rc = e.target.closest('[data-map-recenter]');
    if (rc && state.mapEngine) {
      const eng = state.mapEngine;
      if (eng.userFix) { eng.recenter(); return; }
      if (SENS() && SENS().gps.available()) {
        toast('Finding your location…');
        SENS().gps.probe(8000).then(fix => {
          if (fix) { eng.userFix = fix; eng.recenter(); }
          else toast(SENS().gps.status().error || 'No GPS signal yet — try again outside');
        });
      } else {
        eng.recenter();
      }
      return;
    }
    const mf = e.target.closest('[data-map-filter]');
    if (mf) {
      state.mapFilter = mf.getAttribute('data-map-filter');
      $$('[data-map-filter]').forEach(b => b.classList.toggle('active', b === mf));
      if (state.mapEngine) state.mapEngine.setOptions({ filter: state.mapFilter });
      return;
    }
    const af = e.target.closest('[data-act-filter]');
    if (af) { state.activityFilter = af.getAttribute('data-act-filter'); render(); return; }
    const rt = e.target.closest('[data-rec-type]');
    if (rt) { state.rec.type = rt.getAttribute('data-rec-type'); render(); return; }
    const rb = e.target.closest('[data-rec]');
    if (rb) { recAction(rb.getAttribute('data-rec')); return; }
    const club = e.target.closest('[data-club]');
    if (club) {
      const id = club.getAttribute('data-club');
      const c = state.clubs.find(x => x.id === id);
      const joining = !state.joined.has(id);
      if (joining) {
        state.joined.add(id);
        if (c) c.members = (c.members || 0) + 1;
        API().joinClub(id, myId() || 'anon', myName());
        toast('Welcome to ' + (c ? c.name : 'the club') + '!');
      } else {
        state.joined.delete(id);
        if (c && c.members > 0) c.members--;
        API().leaveClub(id);
        toast('Left ' + (c ? c.name : 'the club'));
      }
      render(); return;
    }
    const ch = e.target.closest('[data-challenge]');
    if (ch) {
      const id = ch.getAttribute('data-challenge');
      const idx = state.joinedChallenges.indexOf(id);
      const joined = idx < 0;
      if (joined) { state.joinedChallenges.push(id); API().joinChallenge(id, 'me'); }
      else state.joinedChallenges.splice(idx, 1);
      const c = state.challenges.find(x => x.id === id);
      if (c) c.joined = joined;
      if ($('#modal') && $('#modal').classList.contains('challenge-modal')) openChallengeDetail(id);
      else render();
      toast(joined ? 'Challenge joined — start & destination coordinates are now revealed' : 'Left the challenge');
      return;
    }
    const route = e.target.closest('[data-route]');
    if (route && state.mapEngine) {
      const a = state.activities.find(x => x.id === route.getAttribute('data-route'));
      if (a) { state.mapEngine.focusId = a.id; state.mapEngine.fitRoute(a); toast('Map centred on ' + a.title); }
      return;
    }
    if (e.target.id === 'modalBackdrop') closeModal();
  });

  document.addEventListener('change', e => {
    if (e.target.id === 'segActivity' && state.segmentForm) {
      state.segmentForm.activityId = e.target.value;
      const name = $('#segName');
      if (name) name.value = '';
      updateSegmentPreview();
      return;
    }
    if (e.target.id === 'ccKind' && state.challengeForm) {
      state.challengeForm.kind = e.target.value;
      renderCreateFields();
      return;
    }
    if (e.target.id === 'ccVisibility' && state.challengeForm) {
      state.challengeForm.visibility = e.target.value; return;
    }
    if (e.target.id === 'ccMode' && state.challengeForm) {
      state.challengeForm.mode = e.target.value; renderCreateFields(); return;
    }
    if (e.target.id === 'citySelect') {
      state.city = e.target.value;
      if (state.mapEngine) state.mapEngine.setCity(state.city);
      const sub = $('.map-toolbar .map-sub');
      if (sub && state.view === 'explore') sub.textContent = 'Everywhere we have gone · ' + D.CITIES[state.city].name;
    }
  });
  document.addEventListener('keydown', e => {
    if (e.key === 'Escape') { closeModal(); $('#sidebar').classList.remove('open'); }
    if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') { e.preventDefault(); $('#globalSearch').focus(); }
    if (e.target.tagName === 'INPUT') return;
    if (e.key === 'r') setView('record');
    if (e.key === 'm') setView('explore');
  });
  $('#globalSearch').addEventListener('input', e => {
    state.search = e.target.value.trim();
    if (state.view === 'activities') {
      clearTimeout(state.searchTimer);
      state.searchTimer = setTimeout(() => { const v = $('#globalSearch').value; render(); $('#globalSearch').value = v; $('#globalSearch').focus(); }, 220);
    }
  });
  $('#globalSearch').addEventListener('keydown', e => {
    if (e.key === 'Enter' && state.search) { state.view = 'activities'; render(); }
  });
  document.addEventListener('input', e => {
    if (e.target.id === 'recName') { state.rec.name = e.target.value; return; }
    if (e.target.id === 'goalKm') { state.goal.km = Math.max(0, parseFloat(e.target.value) || 0); return; }
    const f = state.challengeForm;
    if (!f) return;
    const id = e.target.id;
    if (id === 'ccTitle') f.title = e.target.value;
    else if (id === 'ccDesc') f.description = e.target.value;
    else if (id === 'ccKm') f.targetKm = e.target.value;
    else if (id === 'ccTime') f.targetTime = e.target.value;
    else if (id === 'ccElev') f.targetElev = e.target.value;
    else if (id === 'ccPrize') f.prize = e.target.value;
    else if (id === 'ccOpponent') f.opponent = e.target.value;
    else if (id === 'ccGoalKm') f.goalKm = e.target.value;
  });
  $('#recordBtn').addEventListener('click', () => setView('record'));
  $('#themeToggle').addEventListener('click', () => { state.theme = state.theme === 'light' ? 'dark' : 'light'; render(); });
  $('#menuToggle').addEventListener('click', () => $('#sidebar').classList.toggle('open'));
  window.addEventListener('resize', () => { $$('canvas[data-mini]').forEach(cv => drawMini(cv, state.activities.find(a => a.id === cv.getAttribute('data-mini')))); });

  function seedStateNow() {
    state.sensors = SENS() ? SENS().detect() : { list: [] };
    state.challenges = [];
    state.popularAreas = D.popularAreas(state.activities);
    state.segments = [];
    state.hall = D.hallOfFame(state.segments);
    state.clubs = [];
    state.places = D.PLACES.slice();
    state.joinedChallenges = API().joined ? API().joined() : [];
    state.joined = new Set(API().joinedClubs ? API().joinedClubs() : []);
  }
  function applyBootData(res) {
    state.challenges = dedupeById((res[0] || []).map(normalizeChallenge).filter(Boolean));
    const areas = (res[1] || []).filter(a => a && isFinite(a.lat) && isFinite(a.lng));
    state.popularAreas = areas.length ? areas : D.popularAreas(state.activities);
    state.segments = (res[3] || []).map(normalizeSegment).filter(Boolean);
    const hall = (res[2] || []).filter(Boolean);
    state.hall = hall.length ? hall : D.hallOfFame(state.segments);
    const places = (res[4] || []).filter(Boolean);
    if (places.length) state.places = places;
    state.joinedChallenges = API().joined ? API().joined() : [];
    state.joined = new Set();
    (API().joinedClubs ? API().joinedClubs() : []).forEach(id => state.joined.add(id));
    const ids = {};
    state.activities.forEach(a => { ids[a.id] = 1; });
    (res[5] || []).forEach(raw => {
      const a = normalizeActivity(raw);
      if (a && a.track.length >= 2 && !ids[a.id]) { ids[a.id] = 1; state.activities.push(a); }
    });
    (res[6] || []).forEach(raw => {
      const g = normalizeGallery(raw);
      if (g && !state.gallery.some(x => x.id === g.id)) state.gallery.push(g);
    });
    state.clubs = (res[7] || []).map(normalizeClub).filter(Boolean);
    state.clubs.forEach(c => { if (c.joined) state.joined.add(c.id); });
    if (!state.hall.length) state.hall = D.hallOfFame(state.segments);
  }
  function finishBoot() {
    if (!state.popularAreas.length) state.popularAreas = D.popularAreas(state.activities);
    if (!state.hall.length) state.hall = D.hallOfFame(state.segments);
    render();
    let skipped = false;
    try { skipped = sessionStorage.getItem('rucha_skip_auth') === '1'; } catch (e) {}
    const u = meUser();
    if (!u) {
      if (!skipped) openAuthScreen();
      return;
    }
    if (u.profileComplete === false) { openAuthScreen({ step: 'complete' }); return; }
    if (userNeedsConsent(u)) openConsentScreen();
  }
  // Earlier RUCHA builds shipped demo rows. Remove those fingerprints from
  // any cache written before the app became fully user-generated.
  function purgeLegacyLocalContent() {
    try {
      const keys = [];
      for (let i = 0; i < localStorage.length; i++) {
        const k = localStorage.key(i);
        if (k && k.indexOf('rucha_store_v1_') === 0) keys.push(k);
      }
      keys.forEach(k => {
        if (!/(^|_)(cache_)?(activities|challenges|segments|hall|gallery|popular)$/.test(k)) return;
        let v;
        try { v = JSON.parse(localStorage.getItem(k)); } catch (e) { return; }
        if (!Array.isArray(v)) return;
        if (/_popular$/.test(k)) { localStorage.removeItem(k); return; }
        const clean = v.filter(x => {
          if (!x || typeof x !== 'object') return false;
          const id = String(x.id || x.segmentId || '');
          if (/_activities$/.test(k)) return !(x.source === 'demo' || id.indexOf('seed_') === 0);
          if (/_challenges$/.test(k)) return !(x.createdBy === 'RUCHA' && /^ch[1-7]$/.test(id));
          if (/_segments$/.test(k)) return !/^s[1-6]$/.test(id);
          if (/_hall$/.test(k)) return !/^s[1-6]$/.test(id);
          if (/_gallery$/.test(k)) return !(x.sample || id.indexOf('sample_') === 0);
          return true;
        });
        if (clean.length !== v.length) localStorage.setItem(k, JSON.stringify(clean));
      });
    } catch (e) { }
  }

  function boot() {
    purgeLegacyLocalContent();
    seedStateNow();
    hydrate(document.body);
    render();
    const Api = API();
    if (!Api) {
      state.backend = { online: false, store: 'offline' };
      loadGallery(); finishBoot(); return;
    }
    Api.configure({
      fallback: {
        challenges: [],
        activities: [],
        gallery: [],
        popular: () => D.popularAreas(state.activities),
        hall: () => D.hallOfFame(state.segments),
        segments: [],
        clubs: [],
        places: () => D.PLACES
      }
    });
    Api.init().then(st => {
      state.backend = { online: !!st.online, store: st.store };
      const A = AUTH();
      return A && A.init ? A.init() : null;
    }).then(() => {
      const A = AUTH();
      return A && A.config ? A.config().catch(() => null) : null;
    }).then(cfg => {
      if (cfg) auth.cfg = cfg;
      updateAccountChip();
      loadGallery();
      applyActivityPrivacy();
      state.joinedChallenges = Api.joined ? Api.joined() : [];
      const gs = Api.getGoalState ? Api.getGoalState() : null;
      if (gs && gs.km) state.goal = { km: +gs.km || 0, best: gs.best || null };
      refreshSocial();
      return Promise.all([
        Api.getChallenges(), Api.getPopularAreas(), Api.getHallOfFame(),
        Api.getSegments(), Api.getPlaces(), Api.getActivities(), Api.getGallery(),
        Api.getClubs ? Api.getClubs() : Promise.resolve([])
      ]);
    }).then(res => {
      applyBootData(res);
      finishBoot();
    }).catch(() => {
      state.backend = { online: false, store: 'offline' };
      loadGallery();
      finishBoot();
    });
  }
  boot();

})();
