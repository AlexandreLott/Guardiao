// Landing do app: o mesmo celular em 3D do começo ao fim. A rolagem gira o
// aparelho; a cada cena um "dedo" toca no menu do app e a tela muda.
(function () {
  var story = document.getElementById("story");
  if (!story) return;
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  var clamp = function (v, a, b) { return Math.max(a, Math.min(b, v)); };
  var lerp = function (a, b, t) { return a + (b - a) * t; };
  var smooth = function (t) { return t * t * (3 - 2 * t); };

  var board = $("#board"), rig = $("#rig"), screen = $("#appScreen"), tap = $("#tap"), nb = $("#nb");
  var views = $$(".view", screen), navs = $$(".ni", screen), copies = $$(".cp"), sides = $$(".sd");
  var tabs = $$("#sceneTabs button"), links = $$("[data-scene]"), word = $("#bigword"), orbit = $("#orbit");
  var shock = $("#shock"), lockSide = $("#lockSide"), colL = $(".col-l");
  var PER = 1.15; // altura de rolagem de cada cena, em telas

  // espessura do aparelho: placas empilhadas atrás da frente
  for (var d = 7; d >= 1; d--) {
    var e = document.createElement("span");
    e.className = "edge" + (d === 7 ? " last back" : ""); e.style.setProperty("--d", d);
    if (d === 7) e.innerHTML = '<i class="cam"></i><img src="assets/logo-512.png" alt=""><span>Guardian</span>';
    rig.insertBefore(e, rig.firstChild);
  }
  var gsh = document.createElement("span"); gsh.className = "gshadow"; rig.insertBefore(gsh, rig.firstChild);
  // partículas subindo pelo palco
  for (var pk = 0; pk < 14; pk++) {
    var pt = document.createElement("span"); pt.className = "pt";
    pt.style.cssText = "--x:" + (4 + Math.random() * 92).toFixed(1) + "%;--w:" + (3 + Math.random() * 5).toFixed(1) + "px;--t:" + (7 + Math.random() * 8).toFixed(1) + "s;--dl:-" + (Math.random() * 12).toFixed(1) + "s;--dx:" + ((Math.random() - 0.5) * 120).toFixed(0) + "px";
    board.insertBefore(pt, board.firstChild);
  }
  var hud = $("#hud"), hudNum = $("#hudNum"), hudWord = $("#hudWord");

  // apps e fichas em volta do celular: peças 3D com espessura
  var EDGE = { roblox: "#1B3FBF", minecraft: "#3E6B2A", youtube: "#C9CED8", brawlstars: "#B07A00" };
  $$(".fl", rig).forEach(function (el) {
    var isImg = el.tagName === "IMG", box = document.createElement("div"), cube = document.createElement("div");
    box.className = "fl" + (isImg ? "" : " round"); box.style.cssText = el.style.cssText;
    cube.className = "cube";
    var ec = "#1E293B";
    if (isImg) Object.keys(EDGE).forEach(function (k) { if (el.src.indexOf(k) > -1) ec = EDGE[k]; });
    else ec = el.classList.contains("blue") ? "#1E3FCC" : "#C25400";
    cube.style.setProperty("--ec", ec);
    for (var k = 6; k >= 1; k--) {
      var sd = document.createElement("span");
      sd.className = "side" + (k === 6 ? " last" : ""); sd.style.setProperty("--d", k); cube.appendChild(sd);
    }
    var face;
    if (isImg) { face = document.createElement("img"); face.src = el.src; face.alt = ""; }
    else { face = document.createElement("div"); face.innerHTML = el.innerHTML; face.style.background = el.classList.contains("blue") ? "#2B59FF" : "#FF7A1A"; face.style.color = "#fff"; }
    face.className = "face"; cube.appendChild(face);
    var sh = document.createElement("span"); sh.className = "shine"; cube.appendChild(sh);
    box.appendChild(cube); el.parentNode.replaceChild(box, el);
  });

  var scenes = [
    { view: 0, nav: 0, taps: ['[data-nav="0"]'], accent: "#2B59FF", tone: "#E8EDFF", word: "Guardian" },
    { view: 1, nav: 3, taps: ['.view.on [data-tab="apps"]', '[data-nav="3"]'], accent: "#2B59FF", tone: "#E3EAFF", word: "Limites" },
    { view: 2, nav: 3, taps: ['.view.on [data-tab="rot"]', '[data-nav="3"]'], accent: "#8DB800", tone: "#EFF8CF", word: "Rotinas" },
    { view: 3, nav: 2, taps: ['[data-nav="2"]'], accent: "#FF7A1A", tone: "#FFEBDC", word: "Créditos" },
    { view: 4, nav: 1, taps: ['[data-nav="1"]'], accent: "#5B7CFF", tone: "#E9EDFB", word: "Relatório" },
    { view: 5, nav: 3, taps: ['.view.on [data-tab="res"]', '[data-nav="3"]'], accent: "#FF7A1A", tone: "#FFE6D4", word: "Pausa" }
  ];
  // ângulo do celular em repouso em cada cena
  var poses = [
    { rx: 6, ry: -17, rz: 3 }, { rx: 5, ry: 16, rz: -3 }, { rx: 2, ry: 11, rz: 2 },
    { rx: 7, ry: -15, rz: -2 }, { rx: 3, ry: -9, rz: 2 }, { rx: 9, ry: 0, rz: 0 }
  ];

  var cur = -1, token = 0, viewNow = 0;

  // Posições fixas do toque, na medida da tela do celular (300 x 640).
  var TAB_X = { res: 50.5, apps: 117.5, rot: 183.5, cred: 250.5 };
  function center(el) {
    if (el.id === "lockSw") return [257, 246];
    if (el.dataset.tab) return [TAB_X[el.dataset.tab], 98.5];
    return [37.5 + 75 * (+el.dataset.nav || 0), 600];
  }
  function setNav(n) {
    navs.forEach(function (b, k) { b.classList.toggle("on", k === n); });
    nb.style.setProperty("--n", n);
  }
  function setView(v) {
    if (v === viewNow) return;
    screen.style.setProperty("--dir", v > viewNow ? 1 : -1);
    var prev = views[viewNow];
    views.forEach(function (el, k) { el.classList.remove("was"); el.classList.toggle("on", k === v); });
    prev.classList.add("was");
    viewNow = v;
  }
  function find(list) {
    for (var i = 0; i < list.length; i++) {
      var el = screen.querySelector(list[i]);
      if (el && el.offsetParent !== null) return el;
    }
    return navs[0];
  }
  function tapOn(el, done) {
    var t = ++token, p = center(el);
    tap.style.opacity = 1;
    tap.style.transform = "translate(" + p[0] + "px," + p[1] + "px)";
    setTimeout(function () {
      if (t !== token) return;
      tap.classList.add("press"); el.classList.add("hit");
      setTimeout(function () {
        tap.classList.remove("press"); el.classList.remove("hit");
        if (t !== token) return;
        done();
        setTimeout(function () { if (t === token) tap.style.opacity = 0; }, 650);
      }, 210);
    }, 520);
  }
  function replay(el, cls) { el.classList.remove(cls); void el.offsetWidth; el.classList.add(cls); }

  // O momento do bloqueio: onda laranja na tela, selo de cadeado, o aparelho
  // treme, um anel se espalha pelo palco e os apps em volta ficam cinza.
  function setLock(on) {
    var was = screen.classList.contains("paused");
    screen.classList.toggle("paused", on);
    board.classList.toggle("locked", on);
    if (lockSide) lockSide.classList.toggle("locked", on);
    var sw = $("#lockSw"); if (sw) sw.setAttribute("aria-checked", on);
    var note = $(".lk2", lockSide); if (note) note.textContent = on ? "Tudo em pausa agora" : "Um toque e tudo pausa";
    if (on && !was) { replay(rig, "shake"); replay(shock, "go"); }
  }

  // texto, cartões e cores da cena (mudam antes de o celular terminar o giro)
  var curCopy = -1;
  function goCopy(i) {
    var sc = scenes[i];
    curCopy = i;
    copies.forEach(function (c, k) { c.classList.toggle("on", k === i); c.classList.toggle("past", k < i); });
    sides.forEach(function (c, k) { c.classList.toggle("on", k === i); c.classList.toggle("past", k < i); });
    links.forEach(function (a) { if (a.tagName === "A") a.classList.toggle("active", +a.dataset.scene === i); });
    if (window.gNavSync) window.gNavSync();
    board.style.setProperty("--accent", sc.accent);
    board.style.setProperty("--tone", sc.tone);
    word.textContent = sc.word;
    hudNum.textContent = "0" + (i + 1) + " / 0" + scenes.length;
    hudWord.textContent = sc.word;
    replay(board, "bump"); replay(hud, "lock");
  }
  // tela do celular: troca quando o aparelho volta a ficar de frente
  function go(i) {
    var first = cur === -1, sc = scenes[i];
    cur = i;
    if (i !== 5) setLock(false);
    if (first) { token++; setView(sc.view); setNav(sc.nav); return; }
    tapOn(find(sc.taps), function () {
      setView(sc.view); setNav(sc.nav); replay(screen, "scan");
      if (i === 5) setTimeout(function () {
        if (cur !== 5) return;
        tapOn($("#lockSw"), function () { if (cur === 5) setLock(true); });
      }, 1100);
    });
  }

  // tamanho real do celular: zoom (redesenha nítido), nunca escala
  var mobile = false;
  function fit() {
    mobile = innerWidth < 900;
    var bh = board.clientHeight;
    var z = mobile ? clamp((bh - colL.offsetHeight - 44) / 660, 0.4, 1) : clamp(bh * 0.86 / 660, 0.5, 1.3);
    rig.style.zoom = z.toFixed(3);
    hud.style.width = (320 * z + 96).toFixed(0) + "px";
    hud.style.height = (660 * z + 44).toFixed(0) + "px";
  }

  // A rolagem define o alvo; o que aparece persegue o alvo a cada quadro.
  var shownX = null, loop = 0;
  function targetX() {
    var r = story.getBoundingClientRect();
    return clamp(-r.top / (innerHeight * PER), 0, scenes.length - 1);
  }
  function render(x) {
    var i = Math.floor(x), frac = x - i, j = Math.min(i + 1, scenes.length - 1);
    // Entre as cenas o aparelho recua e dá um giro completo, mostrando a
    // traseira. Parado, fica exatamente de frente: assim a tela não embaça.
    var f = j === i ? 0 : smooth(clamp((frac - 0.42) / 0.48, 0, 1));
    var swing = Math.sin(Math.PI * f), dir = i % 2 ? -1 : 1, m = mobile ? 0.6 : 1;
    var flip = i === 1 || i === 3; // nessas passagens ele vira de cima para baixo
    var spin = 360 * f * dir;
    if (f === 0 || f === 1) {
      rig.style.transform = "none";
    } else {
      rig.style.transform = "translate3d(0," + (-swing * 36).toFixed(1) + "px," + (-swing * 320 * m).toFixed(1) + "px)"
        + " rotateX(" + (flip ? spin : swing * 18).toFixed(2) + "deg)"
        + " rotateY(" + (flip ? swing * -20 * dir : spin).toFixed(2) + "deg)"
        + " rotateZ(" + (swing * 7 * dir).toFixed(2) + "deg)";
    }
    screen.style.setProperty("--gl", Math.sin(f * Math.PI * 2).toFixed(3));
    rig.style.setProperty("--sh", (1 - swing * 0.45).toFixed(3));
    rig.style.setProperty("--so", (1 - swing * 0.6).toFixed(3));
    board.style.setProperty("--gy", (x * 260).toFixed(1) + "px");
    board.style.setProperty("--rot", (x * 150).toFixed(1) + "deg");
    board.style.setProperty("--hs", (1 + swing * 0.34).toFixed(3));
    word.style.transform = "translate3d(" + ((0.5 - x / (scenes.length - 1)) * innerWidth * 0.2).toFixed(1) + "px,0,0)";
    orbit.style.transform = "translate3d(" + (innerHeight * 0.3 + Math.cos(x * 1.6) * innerHeight * 0.07).toFixed(1) + "px," + (Math.sin(x * 1.6) * innerHeight * 0.3 - innerHeight * 0.1).toFixed(1) + "px,0)";
    var ci = frac > 0.6 ? j : i, pi = frac > 0.9 ? j : i;
    tabs.forEach(function (t, k) {
      t.classList.toggle("on", k === ci); t.classList.toggle("done", k < ci);
      t.style.setProperty("--f", k === ci ? clamp(x - (ci - 0.4), 0.06, 1).toFixed(3) : 0);
    });
    if (ci !== curCopy) goCopy(ci);
    if (pi !== cur) go(pi);
  }
  function tick() {
    var t = targetX();
    if (shownX === null) shownX = t;
    var dd = t - shownX;
    shownX = Math.abs(dd) < 0.0004 ? t : shownX + dd * 0.13;
    render(shownX);
    loop = shownX === t ? 0 : requestAnimationFrame(tick);
  }
  function wake() { if (!loop) loop = requestAnimationFrame(tick); }
  addEventListener("scroll", wake, { passive: true });
  addEventListener("resize", function () { fit(); shownX = null; wake(); });
  fit(); shownX = targetX(); render(shownX);
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(fit);

  // o menu do topo e as abas levam direto a cada cena
  links.forEach(function (a) {
    a.addEventListener("click", function (e) {
      e.preventDefault();
      var y = story.offsetTop + (+a.dataset.scene) * PER * innerHeight + 4;
      (window.gScrollTo || window.scrollTo)(y);
    });
  });

  // a frase da mensagem acende palavra por palavra com a rolagem
  var man = $("#manifesto");
  if (man) {
    var keys = { "combinar.": "k1", "vigiar.": "k2" };
    man.innerHTML = man.textContent.trim().split(/\s+/).map(function (w) {
      return '<span class="' + (keys[w] || "") + '">' + w + "</span>";
    }).join(" ");
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
