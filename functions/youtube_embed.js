const { onRequest } = require('firebase-functions/v2/https');

/**
 * Page embed YouTube (IFrame API) — domaine Firebase = Referer valide.
 * Autoplay en mute (politique WebView), unmute via JS appelé depuis l’app TV.
 */
exports.youtubeEmbed = onRequest({ cors: true, region: 'europe-west1' }, async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.status(204).send('');
    return;
  }
  if (req.method !== 'GET') {
    res.status(405).send('Method not allowed');
    return;
  }

  const raw = (req.query.v || req.query.videoId || '').toString().trim();
  const videoId = raw.replace(/[^a-zA-Z0-9_-]/g, '').slice(0, 20);
  if (!videoId || videoId.length < 6) {
    res.status(400).send('Missing video id');
    return;
  }

  const origin = 'https://europe-west1-drapeau-vert-app.cloudfunctions.net';
  const preview = String(req.query.preview || '') === '1';
  const startSec = Math.max(0, parseInt(String(req.query.start || '0'), 10) || 0);

  const html = `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
  <meta name="referrer" content="strict-origin-when-cross-origin">
  <title>DVCR Player</title>
  <style>
    html, body { margin:0; padding:0; background:#000; width:100%; height:100%; overflow:hidden; }
    #player, #player iframe { position:fixed; inset:0; width:100%; height:100%; border:0; }
    #dvcr-cover {
      position:fixed; inset:0; z-index:2147483647;
      background:#111;
      display:flex; align-items:center; justify-content:center;
    }
    #dvcr-cover.hide { display:none; }
    .dvcr-ring {
      width:64px; height:64px;
      border:4px solid #0A4438;
      border-top-color:#167A5F;
      border-radius:50%;
      animation:dvcrspin .75s linear infinite;
    }
    @keyframes dvcrspin { to { transform:rotate(360deg); } }
  </style>
</head>
<body>
  <div id="player"></div>
  <div id="dvcr-cover"><div class="dvcr-ring"></div></div>
  <script>
    var ytPlayer = null;
    var PREVIEW = ${preview ? 'true' : 'false'};
    var START = ${startSec};
    var CLIP = 5;
    var loopArmed = 0;
    function notify(fn, arg) {
      try {
        if (window.DvcrPlayer && typeof DvcrPlayer[fn] === 'function') {
          if (arg === undefined) DvcrPlayer[fn]();
          else DvcrPlayer[fn](arg);
        }
      } catch (e) {}
      try {
        if (fn === 'onPlaying' && window.DvcrPreview && typeof DvcrPreview.onFirstFrame === 'function') {
          DvcrPreview.onFirstFrame();
        }
      } catch (e2) {}
    }
    function unmuteAndPlay() {
      if (PREVIEW) return false;
      try {
        if (!ytPlayer) return false;
        ytPlayer.unMute();
        ytPlayer.setVolume(100);
        ytPlayer.playVideo();
        var muted = false;
        try { muted = !!ytPlayer.isMuted(); } catch (e2) {}
        if (!muted) notify('onUnmuted');
        return !muted;
      } catch (e) { return false; }
    }
    function muteAndHold() {
      try {
        if (!ytPlayer) return;
        ytPlayer.mute();
        ytPlayer.setVolume(0);
        if (START > 0) {
          var t = 0;
          try { t = ytPlayer.getCurrentTime(); } catch (e3) {}
          if (t < START - 0.75) ytPlayer.seekTo(START, true);
        }
        ytPlayer.playVideo();
      } catch (e) {}
    }
    function onYouTubeIframeAPIReady() {
      ytPlayer = new YT.Player('player', {
        width: '100%',
        height: '100%',
        videoId: '${videoId}',
        playerVars: {
          autoplay: 1,
          mute: 1,
          controls: PREVIEW ? 0 : 1,
          rel: 0,
          modestbranding: 1,
          playsinline: 1,
          fs: PREVIEW ? 0 : 1,
          iv_load_policy: 3,
          enablejsapi: 1,
          start: START,
          origin: '${origin}'
        },
        events: {
          onReady: function(e) {
            try {
              e.target.mute();
              if (START > 0) e.target.seekTo(START, true);
              e.target.playVideo();
            } catch (err) {}
            notify('onReady');
            if (PREVIEW) {
              setTimeout(muteAndHold, 250);
              setTimeout(muteAndHold, 900);
            } else {
              setTimeout(unmuteAndPlay, 250);
              setTimeout(unmuteAndPlay, 900);
            }
          },
          onError: function(e) {
            notify('onError', e && e.data != null ? e.data : -1);
          },
          onStateChange: function(e) {
            if (e && e.data === 1) {
              try { document.getElementById('dvcr-cover').classList.add('hide'); } catch (c) {}
              notify('onPlaying');
              if (PREVIEW) muteAndHold();
              else unmuteAndPlay();
            }
          },
          onAutoplayBlocked: function() {
            try { document.getElementById('dvcr-cover').classList.add('hide'); } catch (c) {}
            notify('onAutoplayBlocked');
          }
        }
      });
      if (PREVIEW) {
        setInterval(function() {
          if (!ytPlayer || !ytPlayer.getPlayerState) return;
          try {
            if (ytPlayer.getPlayerState() !== 1) return;
            ytPlayer.mute();
            var t = ytPlayer.getCurrentTime();
            if (START > 1 && t < START - 0.75) {
              ytPlayer.seekTo(START, true);
              return;
            }
            if (loopArmed === 0) loopArmed = Date.now();
            if (t >= START + CLIP || (Date.now() - loopArmed) >= CLIP * 1000) {
              ytPlayer.seekTo(START, true);
              loopArmed = Date.now();
            }
          } catch (e) {}
        }, 250);
      }
    }
    window.unmuteAndPlay = unmuteAndPlay;
  </script>
  <script src="https://www.youtube.com/iframe_api"></script>
</body>
</html>`;

  res.set('Content-Type', 'text/html; charset=utf-8');
  res.set('Cache-Control', 'no-store');
  res.set('Referrer-Policy', 'strict-origin-when-cross-origin');
  res.status(200).send(html);
});
