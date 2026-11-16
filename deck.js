// Apresentações: um slide por tela. Setas, espaço, roda do mouse e os botões
// passam os slides; cada um anima quando chega.
(function () {
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  var slides = $$(".sl");

  // ----- vídeo da central de apresentação -----
  var frame = $("#vframe");
  if (frame) {
    var video = $("video", frame), play = $("#vplay");
    play.addEventListener("click", function () { video.play(); });
    video.addEventListener("play", function () { frame.classList.add("playing"); video.controls = true; });
    video.addEventListener("pause", function () { if (video.ended) frame.classList.remove("playing"); });
    video.addEventListener("ended", function () { frame.classList.remove("playing"); video.controls = false; });
    $$("[data-src]").forEach(function (b) {
      b.addEventListener("click", function () {
        $$("[data-src]").forEach(function (o) { o.setAttribute("aria-pressed", o === b); });
        video.pause(); video.controls = false; frame.classList.remove("playing");
        video.poster = b.dataset.poster; video.src = b.dataset.src; video.load();
      });
    });
  }
  // ----- clipes curtos: cada botão "Ver em ação" abre o trecho do vídeo daquela funcionalidade -----
  var clipBtns = $$("[data-clip]");
  if (clipBtns.length) {
    var box = document.createElement("div"); box.className = "clipbox";
    box.innerHTML = '<button class="cb-x" aria-label="Fechar">×</button><div class="cb-card"><div class="cb-frame"><video muted loop playsinline preload="none"></video></div><h3></h3></div>';
    document.body.appendChild(box);
    var cv2 = $("video", box), ct = $("h3", box);
    var closeClip = function () { box.classList.remove("open"); cv2.pause(); };
    clipBtns.forEach(function (b) {
      b.addEventListener("click", function (e) {
        e.preventDefault(); e.stopPropagation();
        ct.textContent = b.dataset.title || "";
        cv2.poster = "media/feat-" + b.dataset.clip + ".jpg";
        cv2.src = "media/feat-" + b.dataset.clip + ".mp4";
        cv2.currentTime = 0; cv2.play().catch(function () {});
        box.classList.add("open");
      });
    });
    box.addEventListener("click", function (e) { if (!e.target.closest(".cb-frame")) closeClip(); });
    addEventListener("keydown", function (e) { if (e.key === "Escape") closeClip(); });
  }

  if (!slides.length) return;

  var total = slides.length, cur = 0, moving = false;
  var pad = function (n) { return String(n).padStart(2, "0"); };
  slides.forEach(function (s, k) {
    s.dataset.n = pad(k + 1);
    $$("[data-a]", s).forEach(function (el, i) { el.style.setProperty("--i", i); });
    $$(".dc", s).forEach(function (el, i) { if (!el.style.getPropertyValue("--i")) el.style.setProperty("--i", i); });
  });

  // controles
  var ctl = document.createElement("div");
  ctl.className = "dctl";
  ctl.innerHTML = '<button id="dPrev" aria-label="Slide anterior"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M6 15l6-6 6 6"/></svg></button>'
    + '<span class="count" id="dCount"></span>'
    + '<button id="dNext" aria-label="Próximo slide"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9l6 6 6-6"/></svg></button>'
    + '<button id="dFull" aria-label="Tela cheia"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5"/></svg></button>';
  document.body.appendChild(ctl);
  var dots = document.createElement("div");
  dots.className = "ddots";
  slides.forEach(function (s, k) {
    var b = document.createElement("button");
    b.setAttribute("aria-label", "Ir para o slide " + (k + 1));
    b.addEventListener("click", function () { go(k); });
    dots.appendChild(b);
  });
  document.body.appendChild(dots);
  var count = $("#dCount"), dotList = $$("button", dots);

  // números que contam até o valor
  function countUp(el) {
    if (el.dataset.done) return; el.dataset.done = 1;
    var to = parseFloat(el.dataset.count), dec = +(el.dataset.dec || 0), suf = el.dataset.suf || "", t0 = performance.now();
    (function step(now) {
      var t = Math.min(1, (now - t0) / 1600), e = 1 - Math.pow(1 - t, 3);
      el.textContent = (to * e).toFixed(dec).replace(".", ",") + suf;
      if (t < 1) requestAnimationFrame(step);
    })(t0);
  }

  var glow = document.createElement("div"); glow.className = "deckglow"; glow.setAttribute("aria-hidden", "true");
  var glowA = document.createElement("i"), glowB = document.createElement("i");
  glowA.className = "ga"; glowB.className = "gb"; glow.appendChild(glowA); glow.appendChild(glowB);
  document.body.insertBefore(glow, document.body.firstChild);

  function mark(k) {
    cur = k;
    count.textContent = pad(k + 1) + " / " + pad(total);
    dotList.forEach(function (d, i) { d.classList.toggle("on", i === k); });
    // a luz de fundo assume as cores do slide atual
    var cs = getComputedStyle(slides[k]), g1 = cs.getPropertyValue("--g1").trim(), g2 = cs.getPropertyValue("--g2").trim();
    if (g1) glowA.style.backgroundColor = g1;
    if (g2) glowB.style.backgroundColor = g2;
  }
  // Animação ligada à rolagem: cada slide sabe onde está na tela (--p vai de
  // -1, abaixo, a 1, acima; 0 é o centro) e se move de acordo. A rolagem com
  // o mouse é livre. O slide anima ao chegar e volta a animar se você retornar.
  var pos = slides.map(function () { return 1; });
  // Só recalcula quando a rolagem mudou (ou enquanto o movimento ainda está
  // assentando), e só mexe nos slides que estão perto da tela. Antes isso
  // rodava para os 12 slides em todos os quadros, mesmo com a página parada.
  var lastScrollY = -1, settling = true, tops = [], heights = [];
  function measure() {
    var sy = window.scrollY;
    slides.forEach(function (sl, k) { var r = sl.getBoundingClientRect(); tops[k] = r.top + sy; heights[k] = r.height; });
    lastScrollY = -1;
  }
  // A rolagem é a do próprio navegador, sem nada preso a ela: aqui só se
  // descobre qual slide está na tela para ligar as animações de entrada.
  var lastScrollT = 0;
  function scrollFrame() {
    var y = window.scrollY;
    if (y === lastScrollY) return;
    lastScrollY = y; lastScrollT = performance.now();
    var vh = innerHeight, best = 0, bestD = 9;
    for (var k = 0; k < slides.length; k++) {
      var d = Math.abs((tops[k] - y + heights[k] / 2 - vh / 2) / vh);
      if (d < bestD) { bestD = d; best = k; }
      if (d > 1.6) continue;
      var sl = slides[k];
      if (d < 0.5 && !sl.classList.contains("in")) {
        sl.classList.add("in");
        $$("[data-count]", sl).forEach(countUp);
      } else if (d > 1.05 && sl.classList.contains("in")) {
        sl.classList.remove("in");
        $$("[data-count]", sl).forEach(function (el) { delete el.dataset.done; });
      }
    }
    if (best !== cur || !count.textContent) mark(best);
  }
  mark(0);

  function go(k) {
    k = Math.max(0, Math.min(total - 1, k));
    moving = true;
    var y = slides[k].getBoundingClientRect().top + scrollY;
    (window.gScrollTo || window.scrollTo)(y, 850);
    setTimeout(function () { moving = false; }, 900);
  }
  $("#dPrev").addEventListener("click", function () { go(cur - 1); });
  $("#dNext").addEventListener("click", function () { go(cur + 1); });
  $("#dFull").addEventListener("click", function () {
    if (document.fullscreenElement) document.exitFullscreen();
    else if (document.documentElement.requestFullscreen) document.documentElement.requestFullscreen();
  });
  addEventListener("keydown", function (e) {
    if (e.target.closest && e.target.closest("input, textarea")) return;
    var k = e.key;
    if (k === "ArrowDown" || k === "ArrowRight" || k === "PageDown" || k === " ") { e.preventDefault(); go(cur + 1); }
    else if (k === "ArrowUp" || k === "ArrowLeft" || k === "PageUp") { e.preventDefault(); go(cur - 1); }
    else if (k === "Home") { e.preventDefault(); go(0); }
    else if (k === "End") { e.preventDefault(); go(total - 1); }
    else if (k === "f" || k === "F") $("#dFull").click();
  });

  // ----- celulares com telas reais: desenha o calombo da barra e, nos
  // marcados como "ao vivo", troca de tela ao tocar no menu -----
  $$(".rph").forEach(function (ph) {
    var nav = ph.querySelector(".bottom-nav"); if (!nav) return;
    var NS = "http://www.w3.org/2000/svg", svg = document.createElementNS(NS, "svg"), path = document.createElementNS(NS, "path");
    svg.setAttribute("class", "bulge-bg"); svg.setAttribute("aria-hidden", "true"); svg.appendChild(path); nav.insertBefore(svg, nav.firstChild);
    function draw() {
      var a = nav.querySelector(".nav-item.active"); if (!a) return;
      var B = 12, W = nav.clientWidth, Hn = nav.clientHeight + B, cx = a.offsetLeft + a.offsetWidth / 2, w = 36, top = 1.5;
      path.setAttribute("d", "M0," + B + " L" + (cx - w - 10) + "," + B + " C" + (cx - w * 0.45) + "," + B + " " + (cx - w * 0.55) + "," + top + " " + cx + "," + top +
        " C" + (cx + w * 0.55) + "," + top + " " + (cx + w * 0.45) + "," + B + " " + (cx + w + 10) + "," + B + " L" + W + "," + B + " L" + W + "," + (Hn + 40) + " L0," + (Hn + 40) + " Z");
    }
    draw(); setTimeout(draw, 300); addEventListener("resize", draw);
    if (!ph.dataset.live) return;
    var vs = $$(".view", ph), items = $$(".nav-item", nav);
    items.forEach(function (it, n) {
      it.addEventListener("click", function () {
        items.forEach(function (x, m) { x.classList.toggle("active", m === n); });
        vs.forEach(function (v, m) { v.classList.toggle("on", m === n); });
        draw();
      });
    });
  });

  // ----- cada slide ocupa a tela: o conteúdo é ampliado ou reduzido (zoom de
  // layout, que mantém o texto nítido) até preencher a altura da janela -----
  function fitSlides() {
    var desktop = innerWidth >= 900, vh = innerHeight;
    slides.forEach(function (sl) {
      var w = sl.querySelector(".wrap"); if (!w) return;
      w.style.zoom = 1;
      if (!desktop) return;
      var target = (vh - 176) * 0.93, z = 1;
      for (var k = 0; k < 3; k++) {
        w.style.transform = "none";
        var h = w.getBoundingClientRect().height;
        w.style.transform = "";
        if (!h) break;
        z = Math.max(0.68, Math.min(1.5, z * target / h));
        w.style.zoom = z.toFixed(3);
      }
      // garantia: se ainda passar da altura da janela, reduz aos poucos
      for (var g = 0; g < 6 && sl.offsetHeight > vh + 2 && z > 0.6; g++) { z *= 0.93; w.style.zoom = z.toFixed(3); }
    });
  }
  var refit = function () { fitSlides(); measure(); };
  refit();
  addEventListener("resize", refit);
  addEventListener("load", refit);
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(refit);

  // ----- fundo vivo: os apps do celular flutuam atrás dos slides -----
  // Reagem ao mouse e à rolagem; de tempos em tempos um deles é "bloqueado"
  // (fica cinza e ganha um cadeado), como o Guardian faz.
  var cv = document.createElement("canvas");
  cv.className = "deckbg"; cv.setAttribute("aria-hidden", "true");
  document.body.insertBefore(cv, document.body.firstChild);
  var cx = cv.getContext("2d"), W = 0, H = 0, dpr = 1;
  var mouse = { x: -999, y: -999, tx: 0, ty: 0, on: false };
  var NAMES = ["com.roblox.client", "com.mojang.minecraftpe", "com.dts.freefireth", "com.epicgames.fortnite",
    "com.supercell.brawlstars", "com.supercell.clashroyale", "com.google.android.youtube", "com.zhiliaoapp.musically",
    "com.instagram.android", "com.whatsapp", "com.duolingo", "com.netflix.mediaclient", "com.kiloo.subwaysurf", "com.spotify.music"];
  var COLORS = ["#2B59FF", "#FF7A1A", "#B5E61D", "#7C9BFF"];
  var sprites = [];
  function rnd(a, b) { return a + Math.random() * (b - a); }
  function build() {
    var small = innerWidth < 900, list = [];
    NAMES.slice(0, small ? 7 : NAMES.length).forEach(function (n) {
      var im = new Image(); im.src = "assets/apps/" + n + ".png";
      list.push({ kind: "app", img: im });
    });
    ["lock", "clock", "star", "clock", "lock", "star"].slice(0, small ? 3 : 6).forEach(function (k, i) {
      list.push({ kind: k, color: COLORS[i % COLORS.length] });
    });
    sprites = list.map(function (o) {
      o.x = Math.random(); o.y = Math.random(); o.z = rnd(0.25, 1);
      o.vx = rnd(-1, 1) * 0.000035; o.vy = rnd(-1, 1) * 0.00003;
      o.rot = rnd(-0.3, 0.3); o.vr = rnd(-1, 1) * 0.00012;
      o.ox = 0; o.oy = 0; o.lock = 0; o.pop = 0;
      return o;
    });
  }
  function size() {
    dpr = 1; // os ícones são suaves; desenhar em 2x custava 4 vezes mais
    W = innerWidth; H = innerHeight;
    cv.width = W * dpr; cv.height = H * dpr;
  }
  function rrect(x, y, w, h, r) {
    cx.beginPath(); cx.moveTo(x + r, y);
    cx.arcTo(x + w, y, x + w, y + h, r); cx.arcTo(x + w, y + h, x, y + h, r);
    cx.arcTo(x, y + h, x, y, r); cx.arcTo(x, y, x + w, y, r); cx.closePath();
  }
  function lockGlyph(s, color, lw) {
    cx.strokeStyle = color; cx.lineWidth = lw; cx.lineCap = "round"; cx.lineJoin = "round";
    rrect(-s * 0.36, -s * 0.06, s * 0.72, s * 0.52, s * 0.12); cx.stroke();
    cx.beginPath(); cx.arc(0, -s * 0.08, s * 0.22, Math.PI, 0); cx.stroke();
  }
  function drawSprite(o, now) {
    var s = 26 + 46 * o.z, alpha = 0.10 + 0.26 * o.z;
    var px = o.x * W + mouse.tx * o.z * 34 + o.ox;
    var span = H + 160, py = ((o.y * span - scrollY * o.z * 0.16) % span + span) % span - 80 + mouse.ty * o.z * 22 + o.oy;
    // o mouse empurra os ícones próximos
    var dx = px - mouse.x, dy = py - mouse.y, d = Math.sqrt(dx * dx + dy * dy), fx = 0, fy = 0;
    if (mouse.on && d < 170 && d > 0.01) { var f = (1 - d / 170) * 46; fx = dx / d * f; fy = dy / d * f; }
    o.ox += (fx - o.ox) * 0.09; o.oy += (fy - o.oy) * 0.09;
    o.pop += (0 - o.pop) * 0.08;
    cx.save();
    cx.translate(px, py); cx.rotate(o.rot); cx.scale(1 + o.pop, 1 + o.pop);
    cx.globalAlpha = alpha;
    if (o.kind === "app") {
      if (o.img.complete && o.img.naturalWidth) {
        var locked = o.lock > now;
        rrect(-s / 2, -s / 2, s, s, s * 0.26); cx.save(); cx.clip();
        cx.drawImage(o.img, -s / 2, -s / 2, s, s);
        if (locked) { cx.fillStyle = "rgba(10,14,28,.62)"; cx.fillRect(-s / 2, -s / 2, s, s); }
        cx.restore();
        if (locked) {
          cx.globalAlpha = Math.min(1, alpha * 2.4);
          cx.fillStyle = "#fff"; cx.beginPath(); cx.arc(0, 0, s * 0.27, 0, Math.PI * 2); cx.fill();
          cx.translate(0, -s * 0.03); lockGlyph(s * 0.36, "#0F172A", Math.max(1.5, s * 0.045));
        }
      }
    } else if (o.kind === "lock") {
      lockGlyph(s, o.color, 2.6);
    } else if (o.kind === "clock") {
      cx.strokeStyle = o.color; cx.lineWidth = 2.6; cx.lineCap = "round";
      cx.beginPath(); cx.arc(0, 0, s * 0.42, 0, Math.PI * 2); cx.stroke();
      var t = now / 1000;
      cx.beginPath(); cx.moveTo(0, 0); cx.lineTo(Math.sin(t * 0.9) * s * 0.3, -Math.cos(t * 0.9) * s * 0.3);
      cx.moveTo(0, 0); cx.lineTo(Math.sin(t * 0.075) * s * 0.2, -Math.cos(t * 0.075) * s * 0.2); cx.stroke();
    } else {
      cx.strokeStyle = o.color; cx.lineWidth = 2.6; cx.lineJoin = "round"; cx.beginPath();
      for (var i = 0; i < 10; i++) {
        var a = -Math.PI / 2 + i * Math.PI / 5, r = (i % 2 ? 0.2 : 0.46) * s;
        cx[i ? "lineTo" : "moveTo"](Math.cos(a) * r, Math.sin(a) * r);
      }
      cx.closePath(); cx.stroke();
    }
    cx.restore();
  }
  var lastLock = 0, lastT = 0;
  function loop(now) {
    requestAnimationFrame(loop);
    if (document.hidden) return;
    scrollFrame();
    // o fundo é desenhado a 30 quadros por segundo e fica parado enquanto a
    // página rola, para a rolagem ter o processador só para ela
    if (now - lastScrollT < 160) { lastT = now; return; }
    if (now - lastT < 30) return;
    var dt = Math.min(66, now - (lastT || now)); lastT = now;
    cx.setTransform(dpr, 0, 0, dpr, 0, 0);
    cx.clearRect(0, 0, W, H);
    if (mouse.on) {
      // luz que segue o mouse e acende a malha de pontos por perto
      var g = cx.createRadialGradient(mouse.x, mouse.y, 0, mouse.x, mouse.y, 340);
      g.addColorStop(0, "rgba(43,89,255,.2)"); g.addColorStop(1, "rgba(43,89,255,0)");
      cx.fillStyle = g; cx.fillRect(mouse.x - 340, mouse.y - 340, 680, 680);
      var step = 38, x0 = Math.floor((mouse.x - 230) / step) * step, y0 = Math.floor((mouse.y - 230) / step) * step;
      for (var gx = x0; gx < mouse.x + 230; gx += step) for (var gy = y0; gy < mouse.y + 230; gy += step) {
        var dd = Math.hypot(gx - mouse.x, gy - mouse.y);
        if (dd > 230) continue;
        cx.globalAlpha = (1 - dd / 230) * 0.55; cx.fillStyle = "#7C9BFF";
        cx.beginPath(); cx.arc(gx, gy, 1.6, 0, Math.PI * 2); cx.fill();
      }
      cx.globalAlpha = 1;
    }
    mouse.tx += ((mouse.on ? (mouse.x / W - 0.5) : 0) - mouse.tx) * 0.06;
    mouse.ty += ((mouse.on ? (mouse.y / H - 0.5) : 0) - mouse.ty) * 0.06;
    if (now - lastLock > 2400) {
      lastLock = now;
      var apps = sprites.filter(function (o) { return o.kind === "app" && o.lock < now; });
      if (apps.length) { var pick = apps[Math.floor(Math.random() * apps.length)]; pick.lock = now + 3600; pick.pop = 0.35; }
    }
    sprites.forEach(function (o) {
      o.x = (o.x + o.vx * dt + 1.1) % 1.1; o.y = (o.y + o.vy * dt + 1) % 1; o.rot += o.vr * dt;
      drawSprite(o, now);
    });
  }
  addEventListener("pointermove", function (e) { mouse.x = e.clientX; mouse.y = e.clientY; mouse.on = e.pointerType !== "touch"; }, { passive: true });
  document.addEventListener("pointerleave", function () { mouse.on = false; });
  addEventListener("resize", size);
  size(); build(); requestAnimationFrame(loop);
})();
