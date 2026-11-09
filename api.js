(function (global) {
  'use strict';

  var PREFIX = 'rucha_store_v1_';
  var K = {
    challenges: 'challenges', activities: 'activities', gallery: 'gallery',
    joined: 'joined', progress: 'progress', goals: 'goals',
    segments: 'segments', clubs: 'clubs', joinedClubs: 'joinedClubs'
  };

  function scope() {
    try {
      var A = global.RUCHA_AUTH;
      var u = A && A.me ? A.me() : null;
      return u && u.id && u.profileComplete !== false ? u.id : 'anon';
    } catch (e) { return 'anon'; }
  }
  function key(k) { return PREFIX + scope() + '_' + k; }
  function lsGet(k, def) {
    try { var v = localStorage.getItem(key(k)); return v ? JSON.parse(v) : def; }
    catch (e) { return def; }
  }
  function lsSet(k, v) {
    try { localStorage.setItem(key(k), JSON.stringify(v)); } catch (e) {}
  }
  function authToken() {
    try { return localStorage.getItem('rucha_auth_v1_token') || ''; } catch (e) { return ''; }
  }
  function wire(obj) {
    var out = {};
    Object.keys(obj || {}).forEach(function (k) {
      if (k.charAt(0) !== '_') out[k] = obj[k];
    });
    return out;
  }

  var override = null;
  try {
    var q = new URLSearchParams(location.search).get('api');
    if (q) { override = q.replace(/\/+$/, ''); localStorage.setItem(PREFIX + 'base', override); }
    else override = localStorage.getItem(PREFIX + 'base');
  } catch (e) {}
  var sameOrigin = location.protocol === 'http:' || location.protocol === 'https:';
  var base = override || (sameOrigin ? '' : null);

  var fb = {};
  var st = {
    online: false, store: 'offline', checked: false, health: null,
    base: override || (sameOrigin ? location.origin : null)
  };

  function endpoint(p) { return (base === null ? '' : base) + '/api/' + p; }

  function request(path, opts) {
    if (base === null) return Promise.reject(new Error('offline'));
    opts = opts || {};
    var ctrl = typeof AbortController !== 'undefined' ? new AbortController() : null;
    var timer = setTimeout(function () { if (ctrl) ctrl.abort(); }, 4500);
    var init = {
      method: opts.method || 'GET',
      headers: { 'Accept': 'application/json' },
      body: undefined
    };
    if (opts.body) {
      init.headers['Content-Type'] = 'application/json';
      init.body = JSON.stringify(wire(opts.body));
    }
    var tok = authToken();
    if (tok) init.headers['Authorization'] = 'Bearer ' + tok;
    if (ctrl) init.signal = ctrl.signal;
    return fetch(endpoint(path), init).then(function (res) {
      if (!res.ok) {
        return res.json().catch(function () { return {}; }).then(function (j) {
          throw new Error((j && j.error) ? j.error : 'Something went wrong (' + res.status + ')');
        });
      }
      var ct = res.headers.get('content-type') || '';
      if (ct && !ct.includes('json')) throw new Error('not JSON');
      return res.json();
    }).finally(function () { clearTimeout(timer); });
  }

  function fallback(keyName) {
    var f = fb[keyName];
    if (typeof f === 'function') return f() || [];
    if (Array.isArray(f)) return f.slice();
    return [];
  }
  function dedupe(arr) {
    var seen = {}, out = [];
    for (var i = 0; i < arr.length; i++) {
      var x = arr[i];
      var id = x && (x.id || x.ID);
      if (id) { if (seen[id]) continue; seen[id] = 1; }
      out.push(x);
    }
    return out;
  }
  function cacheKey(k) { return PREFIX + scope() + '_cache_' + k; }
  function readCache(k) {
    try { var v = localStorage.getItem(cacheKey(k)); return v ? JSON.parse(v) : null; }
    catch (e) { return null; }
  }
  function writeCache(k, data) {
    try { localStorage.setItem(cacheKey(k), JSON.stringify(data)); } catch (e) {}
  }

  function read(path, keyName, mergeLocal) {
    var local = mergeLocal ? lsGet(keyName, []) : [];
    if (st.online) {
      return request(path).then(function (data) {
        if (!Array.isArray(data)) return data;
        writeCache(keyName, data);
        return dedupe(local.concat(data));
      }).catch(function () {
        return dedupe(local.concat(readCache(keyName) || fallback(keyName)));
      });
    }
    return Promise.resolve(dedupe(local.concat(readCache(keyName) || fallback(keyName))));
  }

  function write(path, keyName, obj, method) {
    var list = lsGet(keyName, []);
    var id = obj.id || obj.ID;
    var next = [obj].concat(list.filter(function (x) { return (x.id || x.ID) !== id; }));
    lsSet(keyName, next);
    if (!st.online) return Promise.resolve(obj);
    return request(path, { method: method || 'POST', body: obj })
      .then(function (r) {
        if (r && r.id) {
          lsSet(keyName, next.map(function (x) { return (x.id || x.ID) === id ? r : x; }));
        }
        return r || obj;
      })
      .catch(function () { return obj; });
  }

  function init() {
    st.checked = true;
    if (base === null) { st.online = false; st.store = 'offline'; return Promise.resolve(status()); }
    return request('health').then(function (h) {
      st.health = h;
      st.online = !!(h && h.ok);
      st.store = st.online ? (h.store || 'api') : 'offline';
      return status();
    }).catch(function () {
      st.online = false; st.store = 'offline';
      return status();
    });
  }

  function status() {
    return { online: st.online, store: st.store, base: st.base, checked: st.checked, health: st.health };
  }

  function progressRows() { return lsGet(K.progress, []); }
  function postProgress(row) {
    var r = {
      challengeId: row.challengeId, athleteId: row.athleteId, athleteName: row.athleteName,
      distanceKm: row.distanceKm || 0, durationSec: row.durationSec || 0,
      elevationM: row.elevationM || 0, finishedAt: row.finishedAt || ''
    };
    var list = progressRows().filter(function (x) {
      return !(x.challengeId === r.challengeId && x.athleteId === r.athleteId);
    });
    list.push(Object.assign({}, r, { completed: !!row.completed, bestSeconds: row.durationSec || 0 }));
    lsSet(K.progress, list);
    if (!st.online) return Promise.resolve(row);
    return request('challenges/progress', { method: 'POST', body: r })
      .then(function (res) { return res || row; })
      .catch(function () { return row; });
  }
  function leaderboard(id) {
    if (!st.online) return Promise.reject(new Error('offline'));
    return request('challenges/leaderboard?id=' + encodeURIComponent(id));
  }
  function respondChallenge(id, decision) {
    if (!st.online) return Promise.reject(new Error('offline'));
    return request('challenges/respond', { method: 'POST', body: { id: id, decision: decision } });
  }
  function setGoalState(v) { lsSet(K.goals, v || {}); }
  function getGoalState() { return lsGet(K.goals, {}); }

  function claimAnonymous() {
    var A = global.RUCHA_AUTH;
    var u = A && A.me ? A.me() : null;
    if (!u || !u.id || u.profileComplete === false) return false;
    var uid = u.id, claimed = false;
    function read(k) {
      try { var v = localStorage.getItem(k); return v ? JSON.parse(v) : null; }
      catch (e) { return null; }
    }
    function write(k, v) {
      try { localStorage.setItem(k, JSON.stringify(v)); return true; }
      catch (e) { return false; }
    }
    function idOf(x) {
      if (x == null) return '';
      if (typeof x !== 'object') return String(x);
      if (x.id || x.ID) return String(x.id || x.ID);
      if (x.challengeId && x.athleteId) return x.challengeId + '|' + x.athleteId;
      return JSON.stringify(x);
    }
    function mergeList(a, b) {
      var out = Array.isArray(a) ? a.slice() : [], seen = {};
      out.forEach(function (x) { seen[idOf(x)] = 1; });
      (Array.isArray(b) ? b : []).forEach(function (x) {
        var id = idOf(x);
        if (!seen[id]) { seen[id] = 1; out.push(x); }
      });
      return out;
    }
    Object.keys(K).forEach(function (k) {
      var src = read(PREFIX + 'anon_' + k);
      if (src == null) return;
      var dst = read(PREFIX + uid + '_' + k);
      var merged;
      if (Array.isArray(src) || Array.isArray(dst)) merged = mergeList(dst, src);
      else if (src && typeof src === 'object') merged = Object.assign({}, src, dst || {});
      else merged = dst != null ? dst : src;
      if (write(PREFIX + uid + '_' + k, merged)) {
        try { localStorage.removeItem(PREFIX + 'anon_' + k); } catch (e) {}
        claimed = true;
      }
    });
    Object.keys(K).forEach(function (k) {
      var src = PREFIX + 'anon_cache_' + k;
      var dst = PREFIX + uid + '_cache_' + k;
      try {
        var v = localStorage.getItem(src);
        if (v == null) return;
        if (localStorage.getItem(dst) == null) localStorage.setItem(dst, v);
        localStorage.removeItem(src);
        claimed = true;
      } catch (e) {}
    });
    return claimed;
  }

  global.RUCHA_API = {
    init: init,
    status: status,
    claimAnonymous: claimAnonymous,
    configure: function (o) { fb = (o && o.fallback) || {}; },
    setBase: function (b) {
      override = b ? b.replace(/\/+$/, '') : null;
      try {
        if (override) localStorage.setItem(PREFIX + 'base', override);
        else localStorage.removeItem(PREFIX + 'base');
      } catch (e) {}
      base = override || (sameOrigin ? '' : null);
      st.base = override || (sameOrigin ? location.origin : null);
    },

    getChallenges: function () { return read('challenges', K.challenges, true); },
    addChallenge: function (c) { return write('challenges', K.challenges, c, 'POST'); },
    updateChallenge: function (c) {
      var list = lsGet(K.challenges, []);
      lsSet(K.challenges, list.map(function (x) { return x.id === c.id ? c : x; }));
      if (!st.online) return Promise.resolve(c);
      return request('challenges', { method: 'POST', body: c }).then(function (r) { return r || c; }).catch(function () { return c; });
    },
    joinChallenge: function (id, athlete, name) {
      var j = lsGet(K.joined, []);
      if (j.indexOf(id) < 0) { j.push(id); lsSet(K.joined, j); }
      if (!st.online) return Promise.resolve({ joined: true, athleteId: athlete || 'anon' });
      return request('challenges/join', { method: 'POST', body: { challengeId: id, athleteId: athlete || 'anon', athleteName: name || 'You' } })
        .catch(function () { return { joined: true, athleteId: athlete || 'anon' }; });
    },
    joined: function () { return lsGet(K.joined, []); },
    leaderboard: leaderboard,
    respondChallenge: respondChallenge,
    progressRows: progressRows,
    postProgress: postProgress,
    setGoalState: setGoalState,
    getGoalState: getGoalState,

    getPopularAreas: function () { return read('areas/popular', 'popular', false); },
    getHallOfFame: function () { return read('halloffame', 'hall', false); },
    getSegments: function () { return read('segments', K.segments, true); },
    addSegment: function (s) { return write('segments', K.segments, s, 'POST'); },
    getPlaces: function () { return read('places', 'places', false); },

    getClubs: function () { return read('clubs', K.clubs, true); },
    addClub: function (c) { return write('clubs', K.clubs, c, 'POST'); },
    joinClub: function (id, athlete, name) {
      var j = lsGet(K.joinedClubs, []);
      if (j.indexOf(id) < 0) { j.push(id); lsSet(K.joinedClubs, j); }
      if (!st.online) return Promise.resolve({ joined: true, athleteId: athlete || 'anon' });
      return request('clubs/join', { method: 'POST', body: { clubId: id, athleteId: athlete || 'anon', athleteName: name || 'You' } })
        .catch(function () { return { joined: true, athleteId: athlete || 'anon' }; });
    },
    leaveClub: function (id) {
      var j = lsGet(K.joinedClubs, []);
      lsSet(K.joinedClubs, j.filter(function (x) { return x !== id; }));
      if (!st.online) return Promise.resolve({ joined: false });
      return request('clubs/join', { method: 'POST', body: { clubId: id, leave: true } })
        .catch(function () { return { joined: false }; });
    },
    joinedClubs: function () { return lsGet(K.joinedClubs, []); },

    getActivities: function () { return read('activities', K.activities, true); },
    addActivity: function (a) { return write('activities', K.activities, a, 'POST'); },
    setVisibility: function (id, visibility) {
      var list = lsGet(K.activities, []);
      var changed = null;
      list.forEach(function (a) { if (a.id === id) { a.visibility = visibility; changed = a; } });
      if (changed) lsSet(K.activities, list);
      var A = global.RUCHA_AUTH;
      if (A && A.mode && A.mode() === 'server' && st.online) {
        return request('activities/visibility', { method: 'POST', body: { id: id, visibility: visibility } });
      }
      return Promise.resolve(changed || { id: id, visibility: visibility });
    },

    getGallery: function () { return read('gallery', K.gallery, true); },
    addGallery: function (g) { return write('gallery', K.gallery, g, 'POST'); },
    deleteGallery: function (id) {
      lsSet(K.gallery, lsGet(K.gallery, []).filter(function (x) { return x.id !== id; }));
      if (!st.online) return Promise.resolve({ deleted: true });
      return request('gallery?id=' + encodeURIComponent(id), { method: 'DELETE' })
        .catch(function () { return { deleted: true }; });
    },
    raw: request
  };
})(window);
