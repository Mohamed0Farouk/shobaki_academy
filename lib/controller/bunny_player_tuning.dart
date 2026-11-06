import 'dart:convert' show jsonEncode;

/// hls.js overrides applied to Bunny's macOS player in every build.
///
/// Bunny builds its hls.js config inside the player element and passes it
/// explicitly (`new Hls({...this.config})`), so `Hls.DefaultConfig` cannot be
/// patched from the outside. The tuning script below installs a `config`
/// accessor on `bunny-stream-video.prototype` before Bunny defines the
/// element; the accessor merges these values into whatever config the player
/// assigns.
///
/// Empty means "no change" while the playback experiments are running. Once
/// the macOS DIAG build identifies the winning combination, its values are
/// baked in here and ship in the release build.
const Map<String, Object?> kBunnyMacosShippingOverrides = <String, Object?>{};

/// One selectable playback experiment in the diagnostics console.
///
/// [flags] are consumed by the tuning script (`native`, `hls`) or by the
/// adapter (`sharing`). The flags are persisted in `localStorage` under
/// `shobaki.exp`, which survives the reload used to apply them.
class BunnyPlayerExperiment {
  const BunnyPlayerExperiment(this.id, this.label, [this.flags = const {}]);

  final String id;
  final String label;
  final Map<String, Object?> flags;
}

/// macOS-only experiment matrix. Ordered from the baseline to the most
/// invasive host-level control.
const List<BunnyPlayerExperiment> kMacosPlayerExperiments =
    <BunnyPlayerExperiment>[
  BunnyPlayerExperiment('baseline', 'Baseline'),
  BunnyPlayerExperiment(
    'candidate',
    'Classic MSE + 30s',
    <String, Object?>{
      'hls': <String, Object?>{
        'preferManagedMediaSource': false,
        'maxBufferLength': 30,
        'maxMaxBufferLength': 30,
        'backBufferLength': 30,
        'maxBufferSize': 30000000,
      },
    },
  ),
  BunnyPlayerExperiment(
    'native',
    'Native in webview',
    <String, Object?>{'native': true},
  ),
  BunnyPlayerExperiment(
    'mse',
    'Classic MSE only',
    <String, Object?>{
      'hls': <String, Object?>{'preferManagedMediaSource': false},
    },
  ),
  BunnyPlayerExperiment(
    'worker',
    'Worker off',
    <String, Object?>{
      'hls': <String, Object?>{'enableWorker': false},
    },
  ),
  BunnyPlayerExperiment(
    'buffer',
    'Buffer 30s only',
    <String, Object?>{
      'hls': <String, Object?>{
        'maxBufferLength': 30,
        'maxMaxBufferLength': 30,
        'backBufferLength': 30,
        'maxBufferSize': 30000000,
      },
    },
  ),
  BunnyPlayerExperiment(
    'abr',
    'Safe ABR',
    <String, Object?>{
      'hls': <String, Object?>{
        'abrEwmaDefaultEstimate': 2000000,
        'abrBandWidthFactor': 0.7,
        'abrBandWidthUpFactor': 0.7,
        'startLevel': 0,
      },
    },
  ),
  BunnyPlayerExperiment(
    'sharing-normal',
    'Window sharing normal',
    <String, Object?>{'sharing': 'normal'},
  ),
  BunnyPlayerExperiment(
    'sharing-none',
    'Window sharing none',
    <String, Object?>{'sharing': 'none'},
  ),
];

/// Builds the document-start script that applies [kBunnyMacosShippingOverrides]
/// (and, in diagnostics builds, the selected experiment) to Bunny's player.
///
/// In release builds with no shipping overrides this script is a no-op and is
/// not injected at all. Everything is guarded: if Bunny changes its element or
/// the config hand-off, playback falls back to the untouched player.
String buildMacosPlayerTuningScript({required bool diagnostics}) {
  return _kMacosPlayerTuningTemplate
      .replaceAll('__DIAG__', diagnostics ? 'true' : 'false')
      .replaceAll('__SHIPPING__', jsonEncode(kBunnyMacosShippingOverrides));
}

/// JavaScript injected at document start on macOS only.
///
/// Ordering matters: this runs before Bunny's module script, so the
/// `customElements.define` wrapper is in place before the player element
/// upgrades (the upgrade is synchronous inside `define`).
const String _kMacosPlayerTuningTemplate = r'''
(function () {
  var DIAG = __DIAG__;
  var SHIPPING = __SHIPPING__;

  function readExperiment() {
    if (!DIAG) return {};
    try {
      var raw = window.localStorage &&
                window.localStorage.getItem('shobaki.exp');
      return raw ? (JSON.parse(raw) || {}) : {};
    } catch (e) {
      return {};
    }
  }

  var experiment = readExperiment();

  function merge(dst, src) {
    if (!src) return dst;
    for (var key in src) {
      if (Object.prototype.hasOwnProperty.call(src, key)) dst[key] = src[key];
    }
    return dst;
  }

  var overrides = {};
  merge(overrides, SHIPPING);
  merge(overrides, experiment.hls || {});

  function applyConfig(value) {
    var config = value || {};
    if (!Object.keys(overrides).length) return config;
    var next = {};
    merge(next, config);
    merge(next, overrides);
    // On platforms without classic MSE (iOS) ManagedMediaSource is the only
    // option, so never force the fallback there.
    if (next.preferManagedMediaSource === false &&
        typeof window.MediaSource !== 'function') {
      next.preferManagedMediaSource = true;
    }
    return next;
  }

  // The native control test: Bunny reads `use-hlsjs` when it loads the
  // element, which happens during the synchronous upgrade inside define().
  function applyNativeMode() {
    if (!experiment.native) return;
    try {
      var elements = document.querySelectorAll('bunny-stream-video');
      for (var i = 0; i < elements.length; i++) {
        elements[i].setAttribute('use-hlsjs', 'false');
        elements[i].setAttribute('native-hls', 'safari');
      }
    } catch (e) {}
  }

  try {
    var registry = window.customElements;
    if (registry && typeof registry.define === 'function') {
      var originalDefine = registry.define;
      var wrapped = function (name, ctor, options) {
        if (name === 'bunny-stream-video' && ctor && ctor.prototype) {
          try {
            Object.defineProperty(ctor.prototype, 'config', {
              configurable: true,
              get: function () {
                return this.__shobakiConfig;
              },
              set: function (value) {
                this.__shobakiConfig = applyConfig(value);
              }
            });
          } catch (e) {}
        }
        applyNativeMode();
        return originalDefine.call(registry, name, ctor, options);
      };
      registry.define = wrapped;
      if (registry.define === wrapped) registry.__shobakiWrapped = true;
    }
  } catch (e) {}

  if (!DIAG) return;

  // ---- diagnostics: media / hls.js sampler ----
  var stats = window.__shobakiStats = {
    mode: experiment.native ? 'native' : 'hlsjs',
    exp: experiment.id || 'baseline'
  };
  var counters = {};
  var lastApi = null;
  var lastMedia = null;

  function bump(name) {
    counters[name] = (counters[name] || 0) + 1;
  }

  function findMedia(element) {
    try {
      if (!element) return null;
      if (element.nativeEl) return element.nativeEl;
      if (element.shadowRoot) {
        var inner = element.shadowRoot.querySelector('video');
        if (inner) return inner;
      }
      return element.querySelector ? element.querySelector('video') : null;
    } catch (e) {
      return null;
    }
  }

  function connectMedia(media) {
    if (!media || media === lastMedia) return;
    lastMedia = media;
    var names = ['waiting', 'stalled', 'playing', 'suspend', 'error',
                 'seeking', 'seeked'];
    for (var i = 0; i < names.length; i++) {
      (function (name) {
        media.addEventListener(name, function () { bump(name); });
      })(names[i]);
    }
    bump('mediaConnected');
  }

  function connectHls(api) {
    if (!api || api === lastApi) return;
    lastApi = api;
    var events = (window.Hls && window.Hls.Events) || null;
    if (!events) return;
    try {
      api.on(events.ERROR, function (event, data) {
        var text = String(data && data.details ? data.details : 'error');
        if (data && data.fatal) text = text + '!';
        stats.lastError = text;
        bump('hlsError');
        var list = stats.errors || (stats.errors = []);
        if (list[list.length - 1] !== text) {
          list.push(text);
          if (list.length > 6) list.shift();
        }
      });
    } catch (e) {}
    try {
      api.on(events.BUFFER_EVICTED, function () { bump('evicted'); });
    } catch (e) {}
    try {
      api.on(events.LEVEL_SWITCHED, function () { bump('levelSwitches'); });
    } catch (e) {}
    bump('hlsConnected');
  }

  function bufferedAhead(media) {
    try {
      var time = media.currentTime;
      var ranges = media.buffered;
      var best = 0;
      for (var i = 0; i < ranges.length; i++) {
        if (ranges.start(i) <= time + 0.5 && ranges.end(i) >= time) {
          var ahead = ranges.end(i) - time;
          if (ahead > best) best = ahead;
        }
      }
      return Math.round(best * 10) / 10;
    } catch (e) {
      return -1;
    }
  }

  function segmentTimings() {
    try {
      var entries = performance.getEntriesByType('resource');
      var now = performance.now();
      var total = 0;
      var max = 0;
      var count = 0;
      for (var i = 0; i < entries.length; i++) {
        var entry = entries[i];
        if (entry.duration <= 0) continue;
        if (now - entry.responseEnd > 60000) continue;
        if (!/\.(ts|m4s)(\?|$)/.test(entry.name)) continue;
        total += entry.duration;
        count++;
        if (entry.duration > max) max = entry.duration;
      }
      stats.segCount = count;
      stats.segAvgMs = count ? Math.round(total / count) : 0;
      stats.segMaxMs = Math.round(max);
    } catch (e) {}
  }

  // hls.js does not publish the MediaSource. ManagedMediaSource is attached
  // as srcObject; classic MSE is usually a blob URL owned by the buffer
  // controller. The constructor name is what separates the two.
  function sourceName(media, api) {
    try {
      var object = media && media.srcObject;
      if (object && object.constructor &&
          object.constructor.name &&
          object.constructor.name !== 'MediaStream') {
        return object.constructor.name;
      }
    } catch (e) {}
    try {
      var buf = api && api.bufferController;
      var ms = (api && api.mediaSource) || (buf && buf.mediaSource);
      if (ms && ms.constructor) return ms.constructor.name;
    } catch (e) {}
    try {
      var src = media && (media.currentSrc || media.src) || '';
      if (src.indexOf('blob:') === 0) return 'blob';
      if (/\.m3u8(\?|$)/.test(src)) return 'native-hls';
    } catch (e) {}
    return '';
  }

  function sample() {
    try {
      var element = document.querySelector('bunny-stream-video');
      var media = findMedia(element);
      connectMedia(media);

      var api = element && element.api;
      connectHls(api);

      stats.mode = api ? 'hlsjs' : (experiment.native ? 'native' : 'unknown');
      stats.waiting = counters.waiting || 0;
      stats.stalled = counters.stalled || 0;
      stats.droppedEvents = counters.error || 0;
      stats.evicted = counters.evicted || 0;
      stats.hlsErrors = counters.hlsError || 0;
      stats.levelSwitches = counters.levelSwitches || 0;
      stats.forwardS = media ? bufferedAhead(media) : -1;

      if (media) {
        stats.t = Math.round((media.currentTime || 0) * 10) / 10;
        stats.paused = !!media.paused;
        stats.ready = media.readyState;
        stats.net = media.networkState;
        stats.suspend = counters.suspend || 0;
        try {
          stats.ranges = media.buffered ? media.buffered.length : 0;
        } catch (e) {
          stats.ranges = -1;
        }
        stats.w = media.videoWidth || 0;
        stats.h = media.videoHeight || 0;
        stats.mediaErr = media.error ? media.error.code : 0;
        if (media.getVideoPlaybackQuality) {
          var quality = media.getVideoPlaybackQuality();
          stats.frames = quality.totalVideoFrames;
          stats.droppedFrames = quality.droppedVideoFrames;
        }
      }

      if (api) {
        stats.level = api.currentLevel;
        stats.next = api.nextLevel;
        stats.auto = !!api.autoLevelEnabled;
        stats.bwKbps = Math.round((api.bandwidthEstimate || 0) / 1000);
        stats.streams = (api.levels || []).map(function (level) {
          return Math.round((level.bitrate || 0) / 1000);
        }).join('/');
        stats.worker = !!(api.transmuxer && api.transmuxer.workerContext);
        stats.workerCfg = !!(api.config && api.config.enableWorker);
        stats.preferMMS = !!(api.config &&
            api.config.preferManagedMediaSource);
        stats.maxBuf = api.config ? api.config.maxBufferLength : 0;
        stats.version = (window.Hls && window.Hls.version) ||
            api.version || '';
      } else {
        stats.worker = false;
      }
      stats.source = sourceName(media, api);

      segmentTimings();
      stats.at = Date.now();
    } catch (e) {
      stats.sampleError = String(e);
    }
  }

  setInterval(sample, 1000);
  sample();
})();
''';
