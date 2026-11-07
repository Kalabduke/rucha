(function (global) {
  'use strict';

  var LS = 'rucha_auth_v1_';
  var USER_RE = /^[a-z0-9_]{3,20}$/;
  var listeners = [];
  var mode = 'local';      
  var serverToken = '';
  var db = null;           

  function lsGet(k, def) {
    try { var v = localStorage.getItem(LS + k); return v ? JSON.parse(v) : def; }
    catch (e) { return def; }
  }
  function lsSet(k, v) {
    try { localStorage.setItem(LS + k, JSON.stringify(v)); } catch (e) {}
  }
  function norm(s) { return String(s || '').trim().toLowerCase(); }
  function uid(p) {
    var b = new Uint8Array(10);
    try { crypto.getRandomValues(b); } catch (e) { b = null; }
    if (b) return p + '_' + Array.from(b).map(function (x) { return x.toString(16).padStart(2, '0'); }).join('');
    return p + '_' + Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
  }
  function nowISO() { return new Date().toISOString(); }
  function ok(v) { return Promise.resolve(v); }
  function no(msg) { return Promise.reject(new Error(msg)); }
  function emit() { listeners.forEach(function (f) { try { f(me()); } catch (e) {} }); }

  function hashPassword(pw, salt) {
    var raw = salt + ':' + pw;
    if (global.crypto && global.crypto.subtle && global.TextEncoder) {
      return global.crypto.subtle.digest('SHA-256', new TextEncoder().encode(raw))
        .then(function (buf) {
          return Array.from(new Uint8Array(buf)).map(function (x) { return x.toString(16).padStart(2, '0'); }).join('');
        })
        .catch(function () { return simpleHash(raw); });
    }
    return ok(simpleHash(raw));
  }
  function simpleHash(s) {
    var h1 = 5381, h2 = 52711, i;
    for (i = 0; i < s.length; i++) {
      h1 = ((h1 << 5) + h1 + s.charCodeAt(i)) >>> 0;
      h2 = ((h2 << 5) + h2 + s.charCodeAt(i)) >>> 0;
    }
    return h1.toString(16) + h2.toString(16);
  }

  function loadDB() {
    if (db) return db;
    db = {
      users: lsGet('users', {}), byName: lsGet('byName', {}),
      sessions: lsGet('sessions', {}), edges: lsGet('edges', {}),
      shares: lsGet('shares', {}), currentToken: lsGet('currentToken', '')
    };
    return db;
  }
  function saveDB() {
    Object.keys(db).forEach(function (k) { lsSet(k, db[k]); });
  }

  function api(path, method, body) {
    var Api = global.RUCHA_API;
    if (!Api || !Api.status().online) return no('offline');
    return Api.raw(path, {
      method: method || 'GET',
      body: body,
      auth: true
    });
  }

  function me() {
    if (mode === 'server') return currentServerUser;
    var d = loadDB(), s = d.sessions[d.currentToken];
    if (!s || s.exp < Date.now()) return null;
    var u = d.users[s.userId];
    if (!u) return null;
    return { id: u.id, username: u.username, displayName: u.displayName, city: u.city, createdAt: u.createdAt, local: true };
  }
  var currentServerUser = null;

  function token() { return mode === 'server' ? serverToken : loadDB().currentToken; }
  function authMode() { return mode; }
  function onChange(fn) { if (typeof fn === 'function') listeners.push(fn); }

  function init() {
    var Api = global.RUCHA_API;
    var online = Api && Api.status().online;
    mode = online ? 'server' : 'local';
    if (!online) return ok({ mode: mode, user: me() });
    try { serverToken = localStorage.getItem('rucha_auth_v1_token') || ''; } catch (e) {}
    return api('auth/me').then(function (r) {
      currentServerUser = (r && r.user) || null;
      if (!currentServerUser) serverToken = '';
      return { mode: mode, user: me() };
    }).catch(function () {
      currentServerUser = null;
      return { mode: mode, user: null };
    });
  }

  function persistToken(t) {
    serverToken = t || '';
    try { localStorage.setItem('rucha_auth_v1_token', serverToken); } catch (e) {}
  }

  function register(username, password, displayName) {
    username = norm(username);
    if (!USER_RE.test(username)) return no('Username must be 3-20 characters: letters, numbers and _ only.');
    if (!password || password.length < 6) return no('Password must be at least 6 characters.');
    if (mode === 'server') {
      return api('auth/register', 'POST', { username: username, password: password, displayName: displayName })
        .then(function (r) {
          currentServerUser = r.user; persistToken(r.token); emit(); return r;
        });
    }
    var d = loadDB();
    if (d.byName[username]) return no('That username is already taken on this device.');
    var salt = uid('salt');
    return hashPassword(password, salt).then(function (hash) {
      var u = { id: uid('usr'), username: username, displayName: String(displayName || username).slice(0, 48),
                city: 'Addis Ababa', createdAt: nowISO(), hash: hash, salt: salt };
      d.users[u.id] = u; d.byName[username] = u.id;
      var tok = uid('tok');
      d.sessions[tok] = { userId: u.id, exp: Date.now() + 30 * 864e5 };
      d.currentToken = tok; saveDB(); emit();
      return { user: me(), token: tok };
    });
  }

  function login(username, password) {
    username = norm(username);
    if (mode === 'server') {
      return api('auth/login', 'POST', { username: username, password: password })
        .then(function (r) {
          currentServerUser = r.user; persistToken(r.token); emit(); return r;
        });
    }
    var d = loadDB(), id = d.byName[username], u = id && d.users[id];
    if (!u) return no('Wrong username or password.');
    return hashPassword(password, u.salt).then(function (h) {
      if (h !== u.hash) throw new Error('Wrong username or password.');
      var tok = uid('tok');
      d.sessions[tok] = { userId: u.id, exp: Date.now() + 30 * 864e5 };
      d.currentToken = tok; saveDB(); emit();
      return { user: me(), token: tok };
    });
  }

  function logout() {
    if (mode === 'server') {
      return api('auth/logout', 'POST', {}).catch(function () { return {}; }).then(function () {
        currentServerUser = null; persistToken(''); emit(); return { ok: true };
      });
    }
    var d = loadDB();
    delete d.sessions[d.currentToken]; d.currentToken = ''; saveDB(); emit();
    return ok({ ok: true });
  }

  var cfgCache = null;
  function config() {
    if (mode !== 'server') return ok({ telegram: false, google: false, local: true });
    if (cfgCache) return ok(cfgCache);
    return api('auth/config').then(function (c) { cfgCache = c || {}; return cfgCache; })
      .catch(function () { return { telegram: false, google: false }; });
  }
  function finishSignIn(r) {
    currentServerUser = r.user; persistToken(r.token); emit(); return r;
  }
  function telegramStart() {
    if (mode !== 'server') return no('Telegram sign-in needs the RUCHA server.');
    return api('auth/telegram/start', 'POST', {});
  }
  function telegramVerify(loginId, code) {
    if (mode !== 'server') return no('Telegram sign-in needs the RUCHA server.');
    return api('auth/telegram/verify', 'POST', { loginId: loginId, code: String(code || '').trim() }).then(finishSignIn);
  }
  function googleSignIn(credential) {
    if (mode !== 'server') return no('Google sign-in needs the RUCHA server.');
    return api('auth/google', 'POST', { credential: credential }).then(finishSignIn);
  }
  // Used only when RUCHA is opened as a file with no server: a profile that lives on this device.
  function localProfile(name) {
    var d = loadDB();
    var display = String(name || '').trim().slice(0, 48);
    if (!display) return no('Enter your name.');
    var base = norm(display).replace(/[^a-z0-9_]+/g, '_').replace(/^_+|_+$/g, '').slice(0, 14) || 'runner';
    var uname = base, n = 1;
    while (d.byName[uname]) { n++; uname = base + '_' + n; }
    var u = { id: uid('usr'), username: uname, displayName: display, city: 'Addis Ababa', createdAt: nowISO(), hash: '', salt: '' };
    d.users[u.id] = u; d.byName[uname] = u.id;
    var tok = uid('tok');
    d.sessions[tok] = { userId: u.id, exp: Date.now() + 365 * 864e5 };
    d.currentToken = tok; saveDB(); emit();
    return ok({ user: me(), token: tok });
  }

  function searchUsers(q) {
    if (mode === 'server') return api('users?q=' + encodeURIComponent(norm(q))).catch(function () { return []; });
    var d = loadDB(), cur = me(), out = [], needle = norm(q);
    Object.keys(d.users).forEach(function (id) {
      var u = d.users[id];
      if (cur && u.id === cur.id) return;
      if (!needle || u.username.indexOf(needle) >= 0)
        out.push({ id: u.id, username: u.username, displayName: u.displayName, city: u.city, createdAt: u.createdAt });
    });
    out.sort(function (a, b) { return a.username.localeCompare(b.username); });
    return ok(out.slice(0, 20));
  }

  function friendState() {
    if (mode === 'server') return api('friends').catch(function () { return emptyFriendState(); });
    var d = loadDB(), cur = me();
    if (!cur) return ok(emptyFriendState());
    var st = emptyFriendState();
    Object.keys(d.edges).forEach(function (id) {
      var e = d.edges[id];
      if (e.requesterId !== cur.id && e.addresseeId !== cur.id) return;
      if (e.status === 'pending' && e.addresseeId === cur.id) st.incoming.push(e);
      else if (e.status === 'pending' && e.requesterId === cur.id) st.outgoing.push(e);
      else if (e.status === 'accepted') {
        var other = d.users[e.requesterId === cur.id ? e.addresseeId : e.requesterId];
        if (other) st.friends.push({ id: other.id, username: other.username, displayName: other.displayName, city: other.city });
      }
    });
    return ok(st);
  }
  function emptyFriendState() { return { incoming: [], outgoing: [], friends: [] }; }

  function friendRequest(username) {
    username = norm(username);
    if (mode === 'server') return api('friends', 'POST', { username: username });
    var d = loadDB(), cur = me();
    if (!cur) return no('Sign in first.');
    var id = d.byName[username];
    if (!id) return no('No account with that username.');
    if (id === cur.id) return no('You cannot add yourself.');
    var existing = Object.keys(d.edges).map(function (k) { return d.edges[k]; }).filter(function (e) {
      return (e.requesterId === cur.id && e.addresseeId === id) || (e.requesterId === id && e.addresseeId === cur.id);
    })[0];
    if (existing) return no(existing.status === 'accepted' ? 'You are already friends.' : 'A friend request already exists.');
    var e = { id: uid('fr'), requesterId: cur.id, requesterName: cur.username,
              addresseeId: id, addresseeName: username, status: 'pending', createdAt: nowISO() };
    d.edges[e.id] = e; saveDB(); return ok(e);
  }

  function friendRespond(edgeId, decision) {
    if (mode === 'server') return api('friends', 'POST', { action: 'respond', edgeId: edgeId, decision: decision });
    var d = loadDB(), cur = me(), e = d.edges[edgeId];
    if (!e || !cur || e.addresseeId !== cur.id || e.status !== 'pending') return no('Friend request not found.');
    if (decision === 'accept') e.status = 'accepted'; else delete d.edges[edgeId];
    saveDB(); return ok({ ok: true });
  }

  function friendRemove(otherId) {
    if (mode === 'server') {
      return api('friends', 'POST', { action: 'remove', username: otherId });
    }
    var d = loadDB(), cur = me();
    Object.keys(d.edges).forEach(function (id) {
      var e = d.edges[id];
      if ((e.requesterId === cur.id && e.addresseeId === otherId) ||
          (e.addresseeId === cur.id && e.requesterId === otherId)) delete d.edges[id];
    });
    saveDB(); return ok({ ok: true });
  }

  function shares() {
    if (mode === 'server') return api('shares').catch(function () { return []; });
    var d = loadDB(), cur = me();
    if (!cur) return ok([]);
    return ok(Object.keys(d.shares).map(function (k) { return d.shares[k]; })
      .filter(function (s) { return s.ownerId === cur.id; }));
  }

  function addShare(activityId, title, username, isPublic) {
    if (mode === 'server') {
      return api('shares', 'POST', { activityId: activityId, activityTitle: title, username: username || '', public: !!isPublic });
    }
    var d = loadDB(), cur = me();
    if (!cur) return no('Sign in first.');
    var s = { id: uid('sh'), ownerId: cur.id, ownerName: cur.username, activityId: activityId,
              activityTitle: title, sharedWithId: '', sharedWithName: '', public: !!isPublic, createdAt: nowISO() };
    if (!isPublic) {
      var id = d.byName[norm(username)];
      if (!id) return no('No account with that username.');
      if (id === cur.id) return no('You cannot share with yourself.');
      s.sharedWithId = id; s.sharedWithName = norm(username);
    }
    var dup = Object.keys(d.shares).map(function (k) { return d.shares[k]; }).filter(function (x) {
      return x.activityId === activityId && x.sharedWithId === s.sharedWithId && x.public === s.public;
    })[0];
    if (dup) return ok(dup);
    d.shares[s.id] = s; saveDB(); return ok(s);
  }

  function removeShare(id) {
    if (mode === 'server') return api('shares?id=' + encodeURIComponent(id), 'DELETE');
    var d = loadDB(), cur = me();
    if (d.shares[id] && d.shares[id].ownerId === (cur && cur.id)) delete d.shares[id];
    saveDB(); return ok({ deleted: true });
  }

  function setVisibility(id, visibility) {
    if (mode === 'server') return api('activities/visibility', 'POST', { id: id, visibility: visibility });
    var list = [];
    try { list = JSON.parse(localStorage.getItem('rucha_store_v1_' + (me() ? me().id : 'anon') + '_activities') || '[]'); } catch (e) {}
    var found = false;
    list.forEach(function (a) { if (a.id === id) { a.visibility = visibility; found = true; } });
    if (found) {
      try { localStorage.setItem('rucha_store_v1_' + me().id + '_activities', JSON.stringify(list)); } catch (e) {}
    }
    return ok({ id: id, visibility: visibility });
  }

  function visibilityContext() {
    var d = loadDB(), cur = me();
    var friends = {}, shared = {};
    if (cur) {
      Object.keys(d.edges).forEach(function (k) {
        var e = d.edges[k];
        if (e.status !== 'accepted') return;
        if (e.requesterId === cur.id) friends[e.addresseeId] = true;
        if (e.addresseeId === cur.id) friends[e.requesterId] = true;
      });
    }
    Object.keys(d.shares).forEach(function (k) {
      var s = d.shares[k];
      if (s.public || (cur && s.sharedWithId === cur.id)) shared[s.activityId] = true;
    });
    return { id: cur ? cur.id : '', friends: friends, shared: shared };
  }

  function canSee(a) {
    if (!a) return false;
    if (!a.ownerId || a.visibility === 'public') return true;
    var v = visibilityContext();
    if (v.shared[a.id]) return true;
    if (!v.id) return false;
    if (a.ownerId === v.id) return true;
    return a.visibility === 'friends' && !!v.friends[a.ownerId];
  }

  function canSeeChallenge(c) {
    if (!c) return false;
    if (!c.ownerId || !c.visibility || c.visibility === 'everyone') return true;
    var cur = me(), v = visibilityContext();
    if (cur && (c.ownerId === cur.id || (c.opponentId === cur.id && c.inviteStatus !== 'declined'))) return true;
    if (!cur) return false;
    if (c.visibility === 'friends') return !!v.friends[c.ownerId];
    return c.visibility === 'public';
  }

  global.RUCHA_AUTH = {
    init: init, mode: authMode, me: me, token: token, onChange: onChange,
    register: register, login: login, logout: logout,
    config: config, telegramStart: telegramStart, telegramVerify: telegramVerify,
    googleSignIn: googleSignIn, localProfile: localProfile,
    searchUsers: searchUsers,
    friendState: friendState, friendRequest: friendRequest,
    friendRespond: friendRespond, friendRemove: friendRemove,
    shares: shares, addShare: addShare, removeShare: removeShare,
    setVisibility: setVisibility, canSee: canSee, canSeeChallenge: canSeeChallenge,
    visibilityContext: visibilityContext,
    usernameRule: USER_RE
  };
})(window);
