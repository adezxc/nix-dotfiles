// Prepended to Slack's dist/boot.bundle.cjs at build time (nix-dotfiles).
//
// The Slack webapp plays notification and call sounds by fetching them from
// the slack-edge.com CDN (e.g. https://a.slack-edge.com/bv1-13-br/knock_brush-<hash>.mp3),
// so replacing the local sound files alone has no effect.
//
// This hook redirects those CDN requests to locally patched copies, served
// through Slack's own app:// protocol from dist/ inside app.asar.
//
// Note that the CDN file names for call sounds do not carry the "calls_"
// prefix that the local files use; both variants are mapped.
try {
  if (process.type === "browser") {
    const { app, session } = require("electron");

    // CDN sound name (without hash suffix) -> app://resources/<file>
    const REDIRECTS = {
      knock_brush: "knock_brush.mp3",
      incoming_ring_v2: "calls_incoming_ring_v2.mp3",
      calls_incoming_ring_v2: "calls_incoming_ring_v2.mp3",
      outgoing_ring_v2: "calls_outgoing_ring_v2.mp3",
      calls_outgoing_ring_v2: "calls_outgoing_ring_v2.mp3",
      you_joined_call_v2: "calls_you_joined_call_v2.mp3",
      calls_you_joined_call_v2: "calls_you_joined_call_v2.mp3",
      they_joined_call_v2: "calls_they_joined_call_v2.mp3",
      calls_they_joined_call_v2: "calls_they_joined_call_v2.mp3",
      you_left_call_v2: "calls_you_left_call_v2.mp3",
      calls_you_left_call_v2: "calls_you_left_call_v2.mp3",
      they_left_call_v2: "calls_they_left_call_v2.mp3",
      calls_they_left_call_v2: "calls_they_left_call_v2.mp3",
    };
    const URLS = Object.keys(REDIRECTS).map((name) => `*://*.slack-edge.com/*${name}*.mp3`);

    const intercept = (targetSession) => {
      if (!targetSession) {
        return;
      }
      targetSession.webRequest.onBeforeRequest({ urls: URLS }, (details, callback) => {
        const base = new URL(details.url).pathname.split("/").pop();
        const name = base.replace(/-[a-f0-9]+\.mp3$/, "");
        const target = REDIRECTS[name];
        callback(target ? { redirectURL: `app://resources/${target}` } : {});
      });
    };

    // Slack never registers its own onBeforeRequest handler, so this does
    // not conflict with the app's cookie/profiling webRequest usage.
    app.on("session-created", intercept);
    app.whenReady().then(() => intercept(session.defaultSession));
  }
} catch (err) {
  console.error("skype-sound-inject failed:", err);
}
