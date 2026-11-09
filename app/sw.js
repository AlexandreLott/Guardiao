/* Guardian alpha 0.1: cache do app inteiro para funcionar sem internet. */
const CACHE = "guardian-alpha-0.2";
const FILES = ["./", "index.html", "bloqueio.html", "manifest.webmanifest", "icons/logo-guardiao.svg", "icons/icon-192.png", "icons/icon-512.png", "icons/icon-maskable-512.png", "icons/apple-touch-180.png", "icons/apps/com.dts.freefireth.png", "icons/apps/com.duolingo.png", "icons/apps/com.epicgames.fortnite.png", "icons/apps/com.google.android.youtube.png", "icons/apps/com.innersloth.spacemafia.png", "icons/apps/com.instagram.android.png", "icons/apps/com.kiloo.subwaysurf.png", "icons/apps/com.kitkagames.fallbuddies.png", "icons/apps/com.kwai.video.png", "icons/apps/com.mojang.minecraftpe.png", "icons/apps/com.netflix.mediaclient.png", "icons/apps/com.roblox.client.png", "icons/apps/com.spotify.music.png", "icons/apps/com.supercell.brawlstars.png", "icons/apps/com.supercell.clashroyale.png", "icons/apps/com.whatsapp.png", "icons/apps/com.zhiliaoapp.musically.png"];

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(FILES)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))).then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (e) => {
  if (e.request.method !== "GET") return;
  e.respondWith(
    fetch(e.request)
      .then((res) => {
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put(e.request, copy));
        return res;
      })
      .catch(() => caches.match(e.request).then((r) => r || caches.match("index.html")))
  );
});
