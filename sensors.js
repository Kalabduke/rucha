(function (global) {
  'use strict';

  var EARTH_R = 6371008.8; // metres
  var D2R = Math.PI / 180;

  function distM(a, b) {
    var dLat = (b.lat - a.lat) * D2R, dLng = (b.lng - a.lng) * D2R;
    var la1 = a.lat * D2R, la2 = b.lat * D2R;
    var h = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(la1) * Math.cos(la2) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
    return 2 * EARTH_R * Math.asin(Math.min(1, Math.sqrt(h)));
  }

  var LAST_FIX_KEY = 'rucha_last_fix_v1';
  var LAST_FIX_MAX_AGE = 6 * 60 * 60 * 1000; // 6 hours

  function loadLastFix() {
    try {
      var raw = global.localStorage && global.localStorage.getItem(LAST_FIX_KEY);
      if (!raw) return null;
      var f = JSON.parse(raw);
      if (!f || !isFinite(f.lat) || !isFinite(f.lng)) return null;
      if (!f.t || Date.now() - f.t > LAST_FIX_MAX_AGE) return null;
      return f;
    } catch (e) { return null; }
  }
  function saveLastFix(fix) {
    try { if (global.localStorage) global.localStorage.setItem(LAST_FIX_KEY, JSON.stringify(fix)); } catch (e) {}
  }

  var S = {
    gps: { supported: !!navigator.geolocation, watching: false, last: null, watchId: null, error: null, onFix: null, onError: null, denied: false },
    hr: { connected: false, bpm: null, name: '', error: null },
    csc: { connected: false, name: '', cadence: null, speed: null, error: null },
    power: { connected: false, name: '', watts: null, error: null },
    rsc: { connected: false, name: '', cadence: null, speed: null, error: null },
    wake: null
  };

  var hasBle = !!(navigator.bluetooth && navigator.bluetooth.requestDevice);
  var secure = global.isSecureContext !== false;

  // Show the last known position straight away instead of waiting for the
  // first live fix (handy on phones where GPS acquisition takes a few seconds).
  S.gps.last = loadLastFix();

  /* ---------------- GPS ---------------- */

  function toFix(pos) {
    var c = pos.coords || {};
    return {
      lat: c.latitude, lng: c.longitude,
      ele: (c.altitude != null && isFinite(c.altitude)) ? c.altitude : null,
      eleAcc: (c.altitudeAccuracy != null && isFinite(c.altitudeAccuracy)) ? c.altitudeAccuracy : null,
      accuracy: (c.accuracy != null && isFinite(c.accuracy)) ? c.accuracy : null,
      speed: (c.speed != null && isFinite(c.speed) && c.speed >= 0) ? c.speed : null,
      heading: (c.heading != null && isFinite(c.heading)) ? c.heading : null,
      t: pos.timestamp || Date.now()
    };
  }

  function gpsErr(err) {
    if (!err) return 'GPS unavailable';
    if (err.code === 1) return 'Location permission denied. Allow location for this site in your browser settings.';
    if (err.code === 2) return 'No GPS signal. Move to open sky and try again.';
    if (err.code === 3) return 'GPS timed out waiting for a fix.';
    return err.message || 'GPS unavailable';
  }

  /*
   * Track filter. Takes raw fixes and returns accepted points only.
   *  - drops fixes with poor horizontal accuracy
   *  - drops fixes that imply an impossible speed
   *  - ignores jitter while standing still (distance < accuracy-based dead zone)
   *  - smooths lat/lng with an accuracy-weighted filter
   */
  function TrackFilter(opts) {
    opts = opts || {};
    this.maxAcc = opts.maxAccuracy || 45;        // metres
    this.maxSpeed = opts.maxSpeed || 12;         // m/s (43 km/h) run; set higher for ride
    this.minMove = opts.minMove || 3;            // metres
    this.last = null;
    this.sLat = null; this.sLng = null; this.sVar = null;
    this.eleBuf = [];
  }
  TrackFilter.prototype.reset = function () {
    this.last = null; this.sLat = null; this.sLng = null; this.sVar = null; this.eleBuf = [];
  };
  TrackFilter.prototype.markGap = function () {
    // after pause: next accepted point starts a new segment, no distance added
    this.gap = true;
  };
  TrackFilter.prototype.smoothEle = function (ele, acc) {
    if (ele == null) return null;
    if (acc != null && acc > 30) return this.eleBuf.length ? this.eleBuf[this.eleBuf.length - 1] : null;
    this.eleBuf.push(ele);
    if (this.eleBuf.length > 7) this.eleBuf.shift();
    var s = this.eleBuf.slice().sort(function (a, b) { return a - b; });
    return s[Math.floor(s.length / 2)];   // rolling median
  };
  // returns { accept:boolean, point?, stepM, reason? }
  TrackFilter.prototype.push = function (fix) {
    if (!isFinite(fix.lat) || !isFinite(fix.lng) || Math.abs(fix.lat) > 90 || Math.abs(fix.lng) > 180) {
      return { accept: false, reason: 'invalid' };
    }
    var acc = fix.accuracy != null ? fix.accuracy : 50;
    if (acc > this.maxAcc) return { accept: false, reason: 'accuracy' };

    // kalman-style smoothing (variance in m^2). A moving fix gets a higher
    // process noise so the drawn track follows corners instead of lagging behind.
    var spd = (fix.speed != null && isFinite(fix.speed)) ? Math.abs(fix.speed) : 0;
    var q = 5 + Math.min(10, spd * 2.5);  // m per sec
    var lat, lng;
    if (this.sLat == null) {
      this.sLat = fix.lat; this.sLng = fix.lng; this.sVar = acc * acc;
      lat = fix.lat; lng = fix.lng;
    } else {
      var dt = Math.max(0.001, (fix.t - this.last.t) / 1000);
      this.sVar += dt * q * q;
      var k = this.sVar / (this.sVar + acc * acc);
      this.sLat += k * (fix.lat - this.sLat);
      this.sLng += k * (fix.lng - this.sLng);
      this.sVar = (1 - k) * this.sVar;
      lat = this.sLat; lng = this.sLng;
    }

    var ele = this.smoothEle(fix.ele, fix.eleAcc);
    var pt = { lat: lat, lng: lng, ele: ele, accuracy: acc, speed: fix.speed, heading: fix.heading, t: fix.t };

    if (!this.last || this.gap) {
      this.last = pt; this.gap = false;
      return { accept: true, point: pt, stepM: 0, first: true };
    }
    var step = distM(this.last, pt);
    var dtS = Math.max(0.001, (pt.t - this.last.t) / 1000);
    if (step / dtS > this.maxSpeed) return { accept: false, reason: 'speed' };
    var dead = Math.max(2, Math.min(acc * 0.35, 8));
    if (step < dead) {
      // standing still: keep position, still report for UI
      return { accept: false, reason: 'still', point: pt };
    }
    this.last = pt;
    return { accept: true, point: pt, stepM: step };
  };

  var gps = {
    available: function () { return S.gps.supported; },
    status: function () {
      return { supported: S.gps.supported, watching: S.gps.watching, last: S.gps.last, error: S.gps.error, secure: secure };
    },
    // One-shot fix for the "check signal" action. Resolves with the first fix
    // (or a recent cached one) instead of waiting for a perfect accuracy.
    probe: function (timeoutMs) {
      timeoutMs = timeoutMs || 8000;
      return new Promise(function (resolve) {
        if (!S.gps.supported) { S.gps.error = 'This browser has no GPS support'; resolve(null); return; }
        function recent() {
          return (S.gps.last && Date.now() - S.gps.last.t < 10 * 60 * 1000) ? S.gps.last : null;
        }
        // A watch that is already running keeps a fresh fix; reuse it.
        if (S.gps.watching && recent() && Date.now() - S.gps.last.t < 120000) { resolve(S.gps.last); return; }
        var done = false, timer;
        function finish(v) {
          if (done) return; done = true;
          clearTimeout(timer);
          resolve(v);
        }
        timer = setTimeout(function () { finish(recent()); }, timeoutMs);
        try {
          navigator.geolocation.getCurrentPosition(function (pos) {
            var f = toFix(pos);
            S.gps.last = f; S.gps.error = null; S.gps.denied = false;
            saveLastFix(f);
            finish(f);
          }, function (err) {
            S.gps.error = gpsErr(err);
            if (err && err.code === 1) S.gps.denied = true;
            finish(err && err.code === 1 ? null : recent());
          }, { enableHighAccuracy: true, maximumAge: 30000, timeout: timeoutMs });
        } catch (e) {
          S.gps.error = String(e);
          finish(recent());
        }
      });
    },
    start: function (onFix, onError) {
      if (!S.gps.supported) { if (onError) onError('This browser has no GPS support'); return false; }
      if (onFix) S.gps.onFix = onFix;
      if (onError) S.gps.onError = onError;
      // Do not hammer watchPosition (and the user with error toasts) while the
      // permission is denied; probe() can recover it once the user allows it.
      if (S.gps.denied) { S.gps.watching = false; return false; }
      // Keep the existing watch alive. Restarting it here used to discard the
      // fix we had just primed and added 10-20 seconds before recording began.
      if (S.gps.watchId != null) { S.gps.watching = true; return true; }
      try {
        S.gps.watchId = navigator.geolocation.watchPosition(function (pos) {
          var fix = toFix(pos);
          S.gps.last = fix; S.gps.watching = true; S.gps.error = null; S.gps.denied = false;
          saveLastFix(fix);
          if (S.gps.onFix) S.gps.onFix(fix);
        }, function (err) {
          S.gps.error = gpsErr(err);
          // A denied permission kills the watch for good; drop the id so a
          // later start can ask again (e.g. after the user changes the setting).
          if (err && err.code === 1) { S.gps.watching = false; S.gps.watchId = null; S.gps.denied = true; }
          if (S.gps.onError) S.gps.onError(S.gps.error, err && err.code);
        }, { enableHighAccuracy: true, maximumAge: 10000, timeout: 30000 });
        S.gps.watching = true;
        wake.request();
        return true;
      } catch (e) { S.gps.error = String(e); if (onError) onError(S.gps.error); return false; }
    },
    stop: function () {
      if (S.gps.watchId != null && navigator.geolocation && navigator.geolocation.clearWatch) {
        try { navigator.geolocation.clearWatch(S.gps.watchId); } catch (e) {}
      }
      S.gps.watchId = null; S.gps.watching = false;
      wake.release();
    },
    distanceM: distM,
    Filter: TrackFilter
  };

  /* ---------------- Screen wake lock (keeps GPS alive while recording) ---------------- */
  var wake = {
    request: function () {
      try {
        if (navigator.wakeLock && navigator.wakeLock.request) {
          navigator.wakeLock.request('screen').then(function (l) { S.wake = l; }).catch(function () {});
        }
      } catch (e) {}
    },
    release: function () {
      try { if (S.wake) S.wake.release(); } catch (e) {}
      S.wake = null;
    }
  };
  document.addEventListener('visibilitychange', function () {
    if (document.visibilityState === 'visible' && S.gps.watching) wake.request();
  });

  /* ---------------- Bluetooth LE sensors ---------------- */

  function bleReason() {
    if (!hasBle) {
      var ua = navigator.userAgent || '';
      if (/iPhone|iPad|iPod/.test(ua)) return 'Safari on iPhone cannot talk to Bluetooth sensors. Use Chrome on Android or a desktop browser, or the Bluefy browser on iOS.';
      return 'This browser does not support Web Bluetooth. Use Chrome or Edge.';
    }
    if (!secure) return 'Bluetooth needs a secure (https) connection.';
    return '';
  }

  function dvU16(dv, o) { return dv.getUint16(o, true); }
  function dvU32(dv, o) { return dv.getUint32(o, true); }

  function parseHR(dv) {
    try {
      var flags = dv.getUint8(0);
      var bpm = (flags & 0x01) ? dvU16(dv, 1) : dv.getUint8(1);
      return (bpm > 20 && bpm < 250) ? bpm : null;
    } catch (e) { return null; }
  }

  function connectNotify(opts, onData, onDrop) {
    return navigator.bluetooth.requestDevice(opts.request).then(function (device) {
      var name = device.name || 'Sensor';
      function attach() {
        return device.gatt.connect().then(function (srv) { return srv.getPrimaryService(opts.service); })
          .then(function (svc) { return svc.getCharacteristic(opts.characteristic); })
          .then(function (ch) {
            return ch.startNotifications().then(function () {
              ch.addEventListener('characteristicvaluechanged', function (e) { onData(e.target.value); });
              return ch;
            });
          });
      }
      var tries = 0;
      device.addEventListener('gattserverdisconnected', function () {
        if (device._wantClosed) { onDrop(); return; }
        if (tries >= 5) { onDrop(); return; }
        tries++;
        setTimeout(function () { attach().then(function () { tries = 0; }).catch(function () {}); }, 1500 * tries);
      });
      return attach().then(function () { return { device: device, name: name }; });
    });
  }

  var heart = {
    available: function () { return hasBle; },
    status: function () {
      return { supported: hasBle, connected: S.hr.connected, bpm: S.hr.bpm, name: S.hr.name, error: S.hr.error || bleReason() };
    },
    connect: function (onBpm) {
      var why = bleReason();
      if (why) { S.hr.error = why; return Promise.resolve(false); }
      return connectNotify({
        request: { filters: [{ services: ['heart_rate'] }], optionalServices: ['battery_service'] },
        service: 'heart_rate', characteristic: 'heart_rate_measurement'
      }, function (dv) {
        var bpm = parseHR(dv);
        if (bpm == null) return;
        S.hr.bpm = bpm; S.hr.connected = true;
        if (onBpm) onBpm(bpm);
      }, function () { S.hr.connected = false; S.hr.bpm = null; }).then(function (r) {
        S.hr.device = r.device; S.hr.name = r.name; S.hr.connected = true; S.hr.error = null;
        return true;
      }).catch(function (e) {
        S.hr.error = (e && e.name === 'NotFoundError') ? 'No device chosen. Turn on heart-rate broadcast on your watch first.' : ((e && e.message) || String(e));
        S.hr.connected = false;
        return false;
      });
    },
    disconnect: function () {
      try { if (S.hr.device) { S.hr.device._wantClosed = true; if (S.hr.device.gatt.connected) S.hr.device.gatt.disconnect(); } } catch (e) {}
      S.hr.connected = false; S.hr.bpm = null; S.hr.device = null; S.hr.name = '';
    }
  };

  // Cycling speed & cadence (service 0x1816). Wheel circumference in metres.
  var cscState = { lastWheel: null, lastCrank: null };
  var cadence = {
    available: function () { return hasBle; },
    status: function () { return { connected: S.csc.connected, name: S.csc.name, cadence: S.csc.cadence, speed: S.csc.speed, error: S.csc.error }; },
    connect: function (onData, wheelM) {
      var why = bleReason();
      if (why) { S.csc.error = why; return Promise.resolve(false); }
      wheelM = wheelM || 2.105;
      cscState = { lastWheel: null, lastCrank: null };
      return connectNotify({
        request: { filters: [{ services: ['cycling_speed_and_cadence'] }] },
        service: 'cycling_speed_and_cadence', characteristic: 'csc_measurement'
      }, function (dv) {
        try {
          var flags = dv.getUint8(0), o = 1, out = {};
          if (flags & 1) {
            var wr = dvU32(dv, o), wt = dvU16(dv, o + 4); o += 6;
            if (cscState.lastWheel) {
              var dr = (wr - cscState.lastWheel.r) >>> 0, dt = (wt - cscState.lastWheel.t + 65536) % 65536;
              if (dt > 0 && dr < 1000) { out.speed = (dr * wheelM) / (dt / 1024); S.csc.speed = out.speed; }
            }
            cscState.lastWheel = { r: wr, t: wt };
          }
          if (flags & 2) {
            var cr = dvU16(dv, o), ct = dvU16(dv, o + 2);
            if (cscState.lastCrank) {
              var dc = (cr - cscState.lastCrank.r + 65536) % 65536, dtc = (ct - cscState.lastCrank.t + 65536) % 65536;
              if (dtc > 0 && dc < 20) { out.cadence = Math.round(dc / (dtc / 1024) * 60); S.csc.cadence = out.cadence; }
            }
            cscState.lastCrank = { r: cr, t: ct };
          }
          if (onData && (out.speed != null || out.cadence != null)) onData(out);
        } catch (e) {}
      }, function () { S.csc.connected = false; S.csc.cadence = null; S.csc.speed = null; }).then(function (r) {
        S.csc.device = r.device; S.csc.name = r.name; S.csc.connected = true; S.csc.error = null; return true;
      }).catch(function (e) { S.csc.error = (e && e.message) || String(e); S.csc.connected = false; return false; });
    },
    disconnect: function () {
      try { if (S.csc.device) { S.csc.device._wantClosed = true; if (S.csc.device.gatt.connected) S.csc.device.gatt.disconnect(); } } catch (e) {}
      S.csc.connected = false; S.csc.cadence = null; S.csc.speed = null; S.csc.name = '';
    }
  };

  // Cycling power (0x1818)
  var power = {
    available: function () { return hasBle; },
    status: function () { return { connected: S.power.connected, name: S.power.name, watts: S.power.watts, error: S.power.error }; },
    connect: function (onWatts) {
      var why = bleReason();
      if (why) { S.power.error = why; return Promise.resolve(false); }
      return connectNotify({
        request: { filters: [{ services: ['cycling_power'] }] },
        service: 'cycling_power', characteristic: 'cycling_power_measurement'
      }, function (dv) {
        try {
          var w = dv.getInt16(2, true);
          if (w >= 0 && w < 3000) { S.power.watts = w; if (onWatts) onWatts(w); }
        } catch (e) {}
      }, function () { S.power.connected = false; S.power.watts = null; }).then(function (r) {
        S.power.device = r.device; S.power.name = r.name; S.power.connected = true; S.power.error = null; return true;
      }).catch(function (e) { S.power.error = (e && e.message) || String(e); S.power.connected = false; return false; });
    },
    disconnect: function () {
      try { if (S.power.device) { S.power.device._wantClosed = true; if (S.power.device.gatt.connected) S.power.device.gatt.disconnect(); } } catch (e) {}
      S.power.connected = false; S.power.watts = null; S.power.name = '';
    }
  };

  // Running speed & cadence (foot pod, 0x1814)
  var footpod = {
    available: function () { return hasBle; },
    status: function () { return { connected: S.rsc.connected, name: S.rsc.name, cadence: S.rsc.cadence, speed: S.rsc.speed, error: S.rsc.error }; },
    connect: function (onData) {
      var why = bleReason();
      if (why) { S.rsc.error = why; return Promise.resolve(false); }
      return connectNotify({
        request: { filters: [{ services: ['running_speed_and_cadence'] }] },
        service: 'running_speed_and_cadence', characteristic: 'rsc_measurement'
      }, function (dv) {
        try {
          var sp = dvU16(dv, 1) / 256, cad = dv.getUint8(3);
          S.rsc.speed = sp; S.rsc.cadence = cad;
          if (onData) onData({ speed: sp, cadence: cad });
        } catch (e) {}
      }, function () { S.rsc.connected = false; S.rsc.cadence = null; S.rsc.speed = null; }).then(function (r) {
        S.rsc.device = r.device; S.rsc.name = r.name; S.rsc.connected = true; S.rsc.error = null; return true;
      }).catch(function (e) { S.rsc.error = (e && e.message) || String(e); S.rsc.connected = false; return false; });
    },
    disconnect: function () {
      try { if (S.rsc.device) { S.rsc.device._wantClosed = true; if (S.rsc.device.gatt.connected) S.rsc.device.gatt.disconnect(); } } catch (e) {}
      S.rsc.connected = false; S.rsc.cadence = null; S.rsc.speed = null; S.rsc.name = '';
    }
  };

  function detect() {
    var bleNote = hasBle ? 'Bluetooth LE' : bleReason();
    return {
      gps: S.gps.supported,
      hr: hasBle,
      list: [
        { key: 'gps', label: 'GPS', available: S.gps.supported && secure, detail: S.gps.supported ? (secure ? 'Position, distance, pace, altitude' : 'Needs an https connection') : 'Not supported in this browser' },
        { key: 'hr', label: 'Heart rate', available: hasBle && secure, detail: bleNote },
        { key: 'cadence', label: 'Bike cadence / speed', available: hasBle && secure, detail: bleNote },
        { key: 'power', label: 'Power meter', available: hasBle && secure, detail: bleNote },
        { key: 'footpod', label: 'Foot pod', available: hasBle && secure, detail: bleNote }
      ]
    };
  }

  global.RUCHA_SENSORS = {
    detect: detect, gps: gps, heart: heart, cadence: cadence, power: power, footpod: footpod,
    wake: wake, status: function () { return S; }, bleReason: bleReason
  };
})(window);
