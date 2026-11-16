// Página principal: um único celular, sempre inteiro na tela.
//
// Nitidez: parado, o aparelho não tem nenhuma transformação (nem escala, nem
// giro); é desenhado no tamanho final. O 3D acontece só durante as passagens.
//
// Fluidez: as passagens não seguem a roda do mouse quadro a quadro. A rolagem
// escolhe a cena, e cada passagem é uma animação cronometrada que o navegador
// roda na placa de vídeo.
(function () {
  var cine = document.getElementById("cine");
  if (!cine) return;
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  var clamp = function (v, a, b) { return Math.max(a, Math.min(b, v)); };

  var stage = $("#cstage"), cam = $("#cam"), body = $("#zoomed"), screen = $("#appScreen"), tap = $("#tap");
  var views = $$(".view", screen), navs = $$(".nav-item", screen), copies = $$(".caps .cp");
  var hl = $("#hl"), hr = $("#hr"), cue = $("#scrollcue"), shock = $("#shock"), links = $$("[data-scene]");
  var idxBtns = $$("#cindex button"), cubes = $("#cubes"), gsh = $("#gsh");
  var EASE = "cubic-bezier(.62,.04,.22,1)";

  // vidro da tela e anel do toque
  var glass = document.createElement("span"); glass.className = "glass"; screen.appendChild(glass);
  var tring = document.createElement("span"); tring.className = "touchring"; screen.appendChild(tring);
  var coach = document.createElement("div"); coach.className = "coach";
  coach.innerHTML = '<span class="halo2"></span><span class="tip"></span>';
  screen.appendChild(coach);
  // próximo passo de cada cena: onde tocar e o que o toque faz
  var NEXT = [
    "Toque em <b>Responsável</b> para definir os limites",
    "Abra a aba <b>Rotinas</b> para ver os horários",
    "Toque em <b>Créditos</b> para ver as missões",
    "Toque em <b>Relatório</b> para ver a semana",
    "Volte ao <b>Responsável</b> para pausar tudo",
    "Um toque aqui <b>pausa todos os apps</b>"
  ];
  function hideCoach() { coach.classList.remove("show"); }
  function coachFor(i) {
    if (i !== cur || busy && i !== 5) return;
    var el = i === 5 ? $("#lockSw") : find(scenes[i + 1].taps);
    if (!el) return;
    var p = center(el), above = p[1] > 320;
    var tx = Math.max(96, Math.min(screen.clientWidth - 96, p[0])) - p[0];
    coach.style.transform = "translate(" + p[0].toFixed(1) + "px," + p[1].toFixed(1) + "px)";
    coach.style.setProperty("--tx", tx.toFixed(1) + "px");
    coach.classList.toggle("above", above); coach.classList.toggle("below", !above);
    $(".tip", coach).innerHTML = NEXT[i] + "<small>" + (i === 5 ? "acontece em instantes" : "clique aqui ou role a página") + "</small>";
    coach.classList.add("show");
  }
  function goScene(n) { (window.gScrollTo || window.scrollTo)(cine.offsetTop + n * innerHeight + 2); }
  var NAV_SCENE = { "0": 0, "1": 4, "2": 3, "3": 1 }, TAB_SCENE = { res: 5, apps: 1, rot: 2, cred: 3 };
  $$(".nav-item", screen).forEach(function (el) { el.dataset.go = NAV_SCENE[el.dataset.nav]; });
  $$("[data-tab]", screen).forEach(function (el) { el.dataset.go = TAB_SCENE[el.dataset.tab]; });
  screen.addEventListener("click", function (e) {
    var el = e.target.closest && e.target.closest("[data-go]");
    if (el && !e.target.closest(".coach")) goScene(+el.dataset.go);
  });
  coach.addEventListener("click", function () {
    if (cur < scenes.length - 1) (window.gScrollTo || window.scrollTo)(cine.offsetTop + (cur + 1) * innerHeight + 2);
  });
  var sheen = document.createElement("span"); sheen.className = "sheen"; screen.appendChild(sheen);

  // ----- peças 3D em volta do aparelho -----
  var EDGE = { roblox: "#1B3FBF", minecraft: "#3E6B2A", youtube: "#C9CED8", brawlstars: "#B07A00", fortnite: "#2B3A67", musically: "#111827" };
  $$(".fl", cubes).forEach(function (el) {
    var isImg = el.tagName === "IMG", box = document.createElement("div"), cube = document.createElement("div");
    box.className = "fl" + (isImg ? "" : " round") + (el.classList.contains("r") ? " r" : "");
    box.dataset.x = el.dataset.x; box.dataset.y = el.dataset.y; box.style.cssText = el.style.cssText;
    cube.className = "cube";
    var ec = "#1E293B";
    if (isImg) Object.keys(EDGE).forEach(function (k) { if (el.src.indexOf(k) > -1) ec = EDGE[k]; });
    else ec = el.classList.contains("blue") ? "#1E3FCC" : (el.classList.contains("lime") ? "#7FA300" : "#C25400");
    cube.style.setProperty("--ec", ec);
    for (var k = 6; k >= 1; k--) {
      var sd = document.createElement("span"); sd.className = "side" + (k === 6 ? " last" : ""); sd.style.setProperty("--d", k); cube.appendChild(sd);
    }
    var face;
    if (isImg) { face = document.createElement("img"); face.src = el.src; face.alt = ""; }
    else { face = document.createElement("div"); face.innerHTML = el.innerHTML; face.style.background = el.classList.contains("blue") ? "#2B59FF" : (el.classList.contains("lime") ? "#B5E61D" : "#FF7A1A"); face.style.color = el.classList.contains("lime") ? "#0F172A" : "#fff"; }
    face.className = "face"; cube.appendChild(face);
    var sh = document.createElement("span"); sh.className = "shine"; cube.appendChild(sh);
    box.appendChild(cube); el.parentNode.replaceChild(box, el);
  });
  var flEls = $$(".fl", cubes);

  var scenes = [
    { view: 0, nav: 0, taps: ['[data-nav="0"]'], accent: "#2B59FF", cos: [] },
    { view: 1, nav: 3, taps: ['.view.on [data-tab="apps"]', '[data-nav="3"]'], accent: "#2B59FF",
      cos: [['.view.on .pcard .row:nth-child(3) .pill', "No limite: o app fecha sozinho"], ['.view.on .pcard .row:nth-child(6) .pill', "Bloqueado pelo responsável"]] },
    { view: 2, nav: 3, taps: ['.view.on [data-tab="rot"]', '[data-nav="3"]'], accent: "#9BC400",
      cos: [['.view.on .big', "Rotina ativa agora"], ['.view.on .pcard .row:nth-child(4) .pill', "Pausa até as 07:00"]] },
    { view: 3, nav: 2, taps: ['[data-nav="2"]'], accent: "#FF7A1A",
      cos: [['.view.on .big .pbtn', "A criança escolhe onde usar"], ['.view.on .pcard .row:nth-child(1) .pill', "Aprovada pelo responsável"]] },
    { view: 4, nav: 1, taps: ['[data-nav="1"]'], accent: "#5B7CFF",
      cos: [['.view.on .big', "Total da semana"], ['.view.on .pcard .row:nth-child(3)', "O dia mais intenso"]] },
    { view: 5, nav: 3, taps: ['.view.on [data-tab="res"]', '[data-nav="3"]'], accent: "#FF7A1A",
      cos: [['#lockSw', "Um toque pausa tudo"], ['.view.on .lockrow.free .pill', "Estudo continua liberado"]] }
  ];

  var coEls = [0, 1].map(function () {
    var c = document.createElement("div"); c.className = "co";
    c.innerHTML = '<span class="line"></span><span class="dot"></span><span class="tag"></span>';
    stage.appendChild(c); return c;
  });

  var cur = 0, wanted = 0, busy = true, viewNow = 0, mobile = false, H = 600, token = 0;

  // ----- medidas: o aparelho sempre cabe inteiro -----
  function pose(i) {
    var vw = innerWidth, vh = innerHeight;
    if (mobile) return { cx: vw / 2, cy: vh - H / 2 - 14 };
    return { cx: Math.round(vw * (i === 0 ? 0.5 : 0.69)), cy: Math.round(34 + vh / 2) };
  }
  function layout(i) {
    var p = pose(i), w = 320 * H / 667;
    cam.style.left = Math.round(p.cx - w / 2) + "px"; cam.style.top = Math.round(p.cy - H / 2) + "px";
    cubes.style.left = p.cx + "px"; cubes.style.top = p.cy + "px";
  }
  function fit() {
    var vh = innerHeight;
    mobile = innerWidth < 900;
    H = Math.round(mobile ? clamp(vh * 0.6, 300, 620) : clamp((vh - 68) * 0.9, 380, 780));
    body.style.zoom = (H / 667).toFixed(4);
    cam.style.width = Math.round(320 * H / 667) + "px"; cam.style.height = H + "px";
    flEls.forEach(function (f) {
      f.style.setProperty("--x", (+f.dataset.x * H).toFixed(0) + "px");
      f.style.setProperty("--y", (+f.dataset.y * H).toFixed(0) + "px");
    });
    layout(cur);
  }

  // ----- toque, telas do app e bloqueio -----
  // Parado, o aparelho não tem transformação: dá para medir o alvo direto.
  function center(el) {
    var t = (el.classList.contains("nav-item") ? (el.querySelector(".npill") || el) : el).getBoundingClientRect();
    var s = screen.getBoundingClientRect(), k = s.width / screen.clientWidth; // k = zoom atual
    return [(t.left + t.width / 2 - s.left) / k, (t.top + t.height / 2 - s.top) / k];
  }
  function setNav(n) { navs.forEach(function (b, k) { b.classList.toggle("active", k === n); }); }
  // a tela nova se abre em círculo a partir do ponto tocado
  function setView(v, p) {
    if (v === viewNow) return;
    var prev = views[viewNow], next = views[v];
    views.forEach(function (el) { el.classList.remove("was"); el.classList.remove("on"); });
    prev.classList.add("was"); next.classList.add("on");
    viewNow = v;
    var o = p || [150, 320], at = o[0].toFixed(0) + "px " + (o[1] - 30).toFixed(0) + "px";
    var an = next.animate([{ clipPath: "circle(0px at " + at + ")" }, { clipPath: "circle(820px at " + at + ")" }], { duration: 700, easing: "cubic-bezier(.3,.1,.2,1)" });
    an.onfinish = function () { prev.classList.remove("was"); };
  }
  function find(list) {
    for (var i = 0; i < list.length; i++) { var el = screen.querySelector(list[i]); if (el && el.offsetParent !== null) return el; }
    return navs[0];
  }
  function replay(el, cls) { el.classList.remove(cls); void el.offsetWidth; el.classList.add(cls); }
  function tapOn(el, done) {
    var p = center(el), t = ++token;
    hideCoach();
    tap.style.opacity = 1; tap.style.transform = "translate(" + p[0].toFixed(1) + "px," + p[1].toFixed(1) + "px)";
    setTimeout(function () {
      tap.classList.add("press"); el.classList.add("hit");
      tring.style.setProperty("--tx", p[0].toFixed(1) + "px"); tring.style.setProperty("--ty", p[1].toFixed(1) + "px");
      replay(tring, "go");
      // o aparelho cede um pouco sob o dedo
      cam.animate([{ transform: "scale(1)" }, { transform: "scale(.984)" }, { transform: "scale(1)" }], { duration: 380, easing: "ease-out" });
      setTimeout(function () {
        tap.classList.remove("press"); el.classList.remove("hit");
        done(p);
        setTimeout(function () { if (t === token) tap.style.opacity = 0; }, 500);
      }, 200);
    }, 480);
  }
  function setLock(on) {
    var was = screen.classList.contains("paused");
    screen.classList.toggle("paused", on); stage.classList.toggle("locked", on);
    var sw = $("#lockSw"); if (sw) sw.setAttribute("aria-checked", on);
    if (on && !was) {
      replay(shock, "go");
      cam.animate([{ transform: "rotate(0)" }, { transform: "rotate(-2.6deg) scale(1.02)" }, { transform: "rotate(2.2deg)" }, { transform: "rotate(-1.4deg)" }, { transform: "rotate(.8deg)" }, { transform: "rotate(0)" }], { duration: 620, easing: "ease-out" });
      cubes.classList.add("lockd");
    } else if (!on) cubes.classList.remove("lockd");
  }

  function placeCallouts(i) {
    var list = (i > 0 && !mobile) ? scenes[i].cos : [];
    var pr = cam.getBoundingClientRect(), sr = stage.getBoundingClientRect();
    coEls.forEach(function (c, k) {
      var def = list[k], el = def && screen.querySelector(def[0]);
      if (!el || el.offsetParent === null) { c.classList.remove("show"); return; }
      var r = el.getBoundingClientRect();
      var x = r.right - sr.left + 6, y = r.top + r.height / 2 - sr.top;
      var len = Math.max(30, pr.right - sr.left + 26 - x);
      c.style.transform = "translate(" + Math.round(x) + "px," + Math.round(y) + "px)";
      $(".line", c).style.width = Math.round(len) + "px";
      var tag = $(".tag", c); tag.style.left = Math.round(len) + "px"; tag.textContent = def[1];
      c.classList.add("show");
    });
  }
  function hideCallouts() { coEls.forEach(function (c) { c.classList.remove("show"); }); }

  function goCopy(i) {
    copies.forEach(function (c, k) { c.classList.toggle("on", k === i - 1); c.classList.toggle("past", k < i - 1); });
    hl.classList.toggle("off", i !== 0); hr.classList.toggle("off", i !== 0); cue.classList.toggle("off", i !== 0);
    cubes.classList.toggle("scene", i !== 0);
    idxBtns.forEach(function (b, k) { b.classList.toggle("on", k === i); });
    links.forEach(function (a) { if (a.tagName === "A") a.classList.toggle("active", +a.dataset.scene === i); });
    if (window.gNavSync) window.gNavSync();
    stage.style.setProperty("--accent", scenes[i].accent);
    stage.classList.toggle("scene1", i !== 0);
  }

  // ----- troca de cena: toque, tela nova e, se preciso, o aparelho desliza de lugar -----
  function change(from, to, p, done) {
    var a = pose(from), b = pose(to), dx = b.cx - a.cx, dy = b.cy - a.cy;
    hideCallouts();
    setView(scenes[to].view, p); setNav(scenes[to].nav);
    replay(screen, "glint");
    cubes.classList.add("burst"); setTimeout(function () { cubes.classList.remove("burst"); }, 650);
    var lean = ((p ? p[0] : 150) - 150) / 150, dirn = to > from ? 1 : -1;
    body.animate([
      { transform: "rotateX(0deg) rotateY(0deg) translateZ(0)" },
      { transform: "rotateX(7deg) rotateY(" + (lean * 14 + dirn * 10).toFixed(1) + "deg) translateZ(-70px)", offset: 0.35 },
      { transform: "rotateX(-2deg) rotateY(" + (-dirn * 5) + "deg) translateZ(10px)", offset: 0.72 },
      { transform: "rotateX(0deg) rotateY(0deg) translateZ(0)" }
    ], { duration: 1050, easing: "cubic-bezier(.3,.1,.2,1)" });
    if (!dx && !dy) { setTimeout(function () { cur = to; done(); }, 720); return; }
    var opt = { duration: 950, easing: EASE };
    cubes.animate([{ transform: "translate3d(0,0,0)" }, { transform: "translate3d(" + dx + "px," + dy + "px,0)" }], opt);
    var an = cam.animate([{ transform: "translate3d(0,0,0)" }, { transform: "translate3d(" + dx + "px," + dy + "px,0)" }], opt);
    an.onfinish = function () { cur = to; layout(to); done(); };
  }

  function arrive() {
    // espera a tela nova assentar antes de medir onde as etiquetas apontam
    var at = cur;
    [1500, 2400].forEach(function (ms) { setTimeout(function () { if (cur === at && wanted === at) placeCallouts(at); }, ms); });
    if (cur === 5) {
      // mostra o tutorial sobre o botão de bloqueio e só depois o dedo toca
      setTimeout(function () { if (cur === 5 && wanted === 5) coachFor(5); }, 900);
      setTimeout(function () {
        if (cur !== 5 || wanted !== 5) { hideCoach(); busy = false; pump(); return; }
        tapOn($("#lockSw"), function () { if (cur === 5) setLock(true); busy = false; pump(); });
      }, 2900);
      return;
    }
    busy = false; pump();
    setTimeout(function () { if (cur === at && wanted === at && !busy) coachFor(at); }, 1300);
  }
  function pump() {
    if (busy || wanted === cur) return;
    busy = true;
    var from = cur, to = wanted;
    if (from === 5) setLock(false);
    goCopy(to);
    // o "dedo" toca no item do menu (ou na aba) que leva à cena
    tapOn(find(scenes[to].taps), function (p) { change(from, to, p, arrive); });
  }

  // ----- a rolagem só escolhe a cena -----
  function pickScene() {
    var x = (scrollY - cine.offsetTop) / innerHeight;
    var w = clamp(Math.round(x), 0, scenes.length - 1);
    if (w !== wanted) { wanted = w; pump(); }
  }
  var snapT = 0;
  addEventListener("scroll", function () {
    pickScene();
    // ao parar entre duas cenas, encosta na mais próxima
    clearTimeout(snapT);
    snapT = setTimeout(function () {
      var x = (scrollY - cine.offsetTop) / innerHeight, n = Math.round(x);
      if (x > -0.02 && x < scenes.length - 1 && Math.abs(x - n) > 0.02 && window.gScrollTo) window.gScrollTo(cine.offsetTop + n * innerHeight, 480);
    }, 170);
  }, { passive: true });
  addEventListener("resize", function () { fit(); placeCallouts(busy ? 0 : cur); });
  links.forEach(function (a) {
    a.addEventListener("click", function (e) {
      e.preventDefault();
      (window.gScrollTo || window.scrollTo)(cine.offsetTop + (+a.dataset.scene) * innerHeight + 2);
    });
  });

  // ----- o aparelho inclina em 3D na direção do mouse e volta a ficar de
  // frente quando o mouse para (de frente a tela fica nítida) -----
  var tiltT = 0;
  function tiltTo(rx, ry, hold) {
    cam.classList.add("tilting");
    body.style.transform = "rotateX(" + rx.toFixed(2) + "deg) rotateY(" + ry.toFixed(2) + "deg)";
    clearTimeout(tiltT);
    tiltT = setTimeout(function () { cam.classList.remove("tilting"); body.style.transform = "none"; }, hold || 1400);
  }

  // ----- o fundo e as peças acompanham o mouse -----
  var mraf = 0;
  addEventListener("pointermove", function (e) {
    if (e.pointerType === "touch" || mraf) return;
    mraf = requestAnimationFrame(function () {
      mraf = 0;
      var mx = e.clientX / innerWidth - 0.5, my = e.clientY / innerHeight - 0.5;
      cubes.style.setProperty("--mx", (mx * 46).toFixed(1) + "px"); cubes.style.setProperty("--my", (my * 34).toFixed(1) + "px");
      var gr = glass.getBoundingClientRect(), gk = gr.width / (glass.offsetWidth || 1);
      glass.style.setProperty("--gx", ((e.clientX - gr.left) / gk).toFixed(0) + "px");
      glass.style.setProperty("--gy", ((e.clientY - gr.top) / gk).toFixed(0) + "px");
      stage.style.setProperty("--lx", (mx * -40).toFixed(1) + "px"); stage.style.setProperty("--ly", (my * -30).toFixed(1) + "px");
    });
  }, { passive: true });

  // ----- entrada: o aparelho sobe e cresce numa curva só, sem trancos.
  // Usa só deslocamento, escala e opacidade (o navegador roda isso direto
  // na placa de vídeo) e começa depois que a página terminou de carregar.
  function entrance() {
    var vh = innerHeight;
    stage.classList.add("ready");
    var opt = { duration: 1700, easing: "cubic-bezier(.16,1,.3,1)", fill: "backwards", delay: 150 };
    gsh.animate([{ transform: "scale(.4)", opacity: 0 }, { transform: "scale(1)", opacity: 1 }], opt);
    var an = cam.animate([
      { transform: "translate3d(0," + Math.round(vh * 0.62) + "px,0) scale(.88)", opacity: 0 },
      { transform: "translate3d(0,0,0) scale(1)", opacity: 1 }
    ], opt);
    setTimeout(function () { replay(screen, "glint"); }, 1050);
    setTimeout(function () { cubes.classList.add("in"); }, 950);
    an.onfinish = function () {
      replay(shock, "soft");
      busy = false; pickScene(); pump();
      setTimeout(function () { if (cur === 0 && wanted === 0 && !busy) coachFor(0); }, 900);
    };
  }

  (function () {
    var nav = $("#gnav"), NS = "http://www.w3.org/2000/svg";
    var svg = document.createElementNS(NS, "svg"); svg.setAttribute("class", "bulge-bg"); svg.setAttribute("aria-hidden", "true");
    var path = document.createElementNS(NS, "path"); svg.appendChild(path); nav.insertBefore(svg, nav.firstChild);
    var B = 12, x = null, v = 0, target = 0, raf = null;
    function shape(cx, stretch) {
      var W = nav.clientWidth, Hn = nav.clientHeight + B;
      var w = 36 + Math.min(18, Math.abs(stretch) * 0.7);
      var lean = Math.max(-10, Math.min(10, stretch * 0.25));
      var top = 1.5 + Math.min(4, Math.abs(stretch) * 0.1);
      return "M0," + B + " L" + (cx - w - 10) + "," + B +
        " C" + (cx - w * 0.45) + "," + B + " " + (cx - w * 0.55 + lean) + "," + top + " " + (cx + lean) + "," + top +
        " C" + (cx + w * 0.55 + lean) + "," + top + " " + (cx + w * 0.45) + "," + B + " " + (cx + w + 10) + "," + B +
        " L" + W + "," + B + " L" + W + "," + (Hn + 40) + " L0," + (Hn + 40) + " Z";
    }
    function targetX() {
      var a = $(".nav-item.active", nav); if (!a) return nav.clientWidth / 2;
      return a.offsetLeft + a.offsetWidth / 2;
    }
    function tick() {
      var k = 0.075, damp = 0.78;
      v = (v + (target - x) * k) * damp; x += v;
      path.setAttribute("d", shape(x, v));
      if (Math.abs(target - x) > 0.3 || Math.abs(v) > 0.3) raf = requestAnimationFrame(tick);
      else { x = target; v = 0; path.setAttribute("d", shape(x, 0)); raf = null; }
    }
    function update() {
      target = targetX();
      if (x === null) { x = target; path.setAttribute("d", shape(x, 0)); return; }
      if (!raf) raf = requestAnimationFrame(tick);
    }
    new MutationObserver(update).observe(nav, { subtree: true, attributes: true, attributeFilter: ["class"] });
    addEventListener("resize", function () { x = null; update(); });
    update(); setTimeout(function () { x = null; update(); }, 120);
  })();

  fit(); goCopy(0); setNav(0);
  var started = false;
  var start = function () { if (started) return; started = true; fit(); requestAnimationFrame(function () { requestAnimationFrame(entrance); }); };
  var whenReady = function () { if (document.fonts && document.fonts.ready) document.fonts.ready.then(start); else start(); };
  if (document.readyState === "complete") whenReady(); else addEventListener("load", whenReady);
  setTimeout(start, 2500); // garantia, se alguma imagem demorar

  // ----- a frase da mensagem acende palavra por palavra -----
  var man = $("#manifesto");
  if (man) {
    var keys = { "combinar.": "k1", "vigiar.": "k2" };
    man.innerHTML = man.textContent.trim().split(/\s+/).map(function (w) { return '<span class="' + (keys[w] || "") + '">' + w + "</span>"; }).join(" ");
    var ws = $$("span", man);
    var light = function () {
      var r = man.getBoundingClientRect();
      var p = clamp((innerHeight * 0.85 - r.top) / (r.height + innerHeight * 0.35), 0, 1);
      ws.forEach(function (w, k) { w.classList.toggle("lit", k < p * ws.length); });
    };
    addEventListener("scroll", light, { passive: true }); light();
  }
  var clock = $("#btClock");
  if (clock) {
    var left = 6 * 3600 + 54 * 60 + 12, p2 = function (n) { return String(n).padStart(2, "0"); };
    setInterval(function () {
      left = left > 0 ? left - 1 : 0;
      clock.textContent = p2(Math.floor(left / 3600)) + ":" + p2(Math.floor(left % 3600 / 60)) + ":" + p2(left % 60);
    }, 1000);
  }
})();
