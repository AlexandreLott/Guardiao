// Movimento compartilhado: cortina entre páginas, troca de telas do celular e a landing do app.
(function () {
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  var clamp = function (v) { return Math.max(0, Math.min(1, v)); };

  // ----- cortina: sobe, cobre a tela e abre na página seguinte -----
  var curtain = document.createElement("div");
  curtain.className = "curtain"; curtain.setAttribute("aria-hidden", "true");
  curtain.innerHTML = '<img src="assets/logo-512.png" alt="">';
  document.body.appendChild(curtain);
  if (document.documentElement.classList.contains("arriving")) {
    curtain.classList.add("covering");
    document.documentElement.classList.remove("arriving");
    document.body.classList.add("entering");
    void curtain.offsetWidth;
    setTimeout(function () { curtain.classList.add("lift"); }, 60);
  }
  document.addEventListener("click", function (e) {
    var a = e.target.closest && e.target.closest("a[href]");
    if (!a || a.hasAttribute("download") || a.target || e.metaKey || e.ctrlKey || e.shiftKey) return;
    var url = new URL(a.href, location.href);
    var isPage = url.pathname.slice(-5) === ".html" || url.pathname.slice(-1) === "/";
    if (url.origin !== location.origin || !isPage || url.pathname === location.pathname) return;
    e.preventDefault();
    try { sessionStorage.setItem("gt", "1"); } catch (err) {}
    curtain.className = "curtain drop";
    setTimeout(function () { location.href = a.href; }, 580);
  });
  addEventListener("pageshow", function (e) { if (e.persisted) curtain.className = "curtain"; });

  // ----- rolagem animada (feita à mão: o navegador desliga a rolagem suave
  // quando as animações do sistema estão desativadas) -----
  var scrollRaf = 0;
  window.gScrollTo = function (to, ms) {
    var from = scrollY, t0 = performance.now(), d = ms || Math.min(1400, 500 + Math.abs(to - from) * 0.35);
    cancelAnimationFrame(scrollRaf);
    (function step(now) {
      var t = Math.min(1, (now - t0) / d), e = t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
      scrollTo(0, from + (to - from) * e);
      if (t < 1) scrollRaf = requestAnimationFrame(step);
    })(t0);
  };
  addEventListener("wheel", function () { cancelAnimationFrame(scrollRaf); }, { passive: true });
  addEventListener("touchstart", function () { cancelAnimationFrame(scrollRaf); }, { passive: true });
  document.addEventListener("click", function (e) {
    var a = e.target.closest && e.target.closest('a[href^="#"]');
    if (!a || a.dataset.scene !== undefined) return;
    var target = document.getElementById(a.getAttribute("href").slice(1));
    if (!target) return;
    e.preventDefault();
    window.gScrollTo(target.getBoundingClientRect().top + scrollY - 60);
  });

  // ----- menu do topo: o fundo desliza até o item apontado ou ativo -----
  var nav = $(".top nav");
  if (nav) {
    var pill = document.createElement("span");
    pill.className = "nav-pill"; nav.insertBefore(pill, nav.firstChild);
    var items = $$("a", nav);
    var place = function (a) {
      if (!a) { pill.style.opacity = 0; return; }
      pill.style.opacity = 1;
      pill.style.width = a.offsetWidth + "px";
      pill.style.transform = "translateX(" + a.offsetLeft + "px)";
    };
    window.gNavSync = function () { place($("a.active", nav)); };
    items.forEach(function (a) {
      a.addEventListener("mouseenter", function () { place(a); });
      a.addEventListener("focus", function () { place(a); });
    });
    nav.addEventListener("mouseleave", window.gNavSync);
    // marca a seção que está na tela (páginas com âncoras)
    var anchors = items.filter(function (a) { return a.getAttribute("href").charAt(0) === "#" && a.dataset.scene === undefined; });
    if (anchors.length) {
      var spy = function () {
        var best = null;
        anchors.forEach(function (a) {
          var s = document.getElementById(a.getAttribute("href").slice(1));
          if (s && s.getBoundingClientRect().top < innerHeight * 0.45) best = a;
        });
        anchors.forEach(function (a) { a.classList.toggle("active", a === best); });
        if (!nav.matches(":hover")) window.gNavSync();
      };
      addEventListener("scroll", spy, { passive: true }); spy();
    }
  }

  // ----- cada bloco de uma tela do celular entra em sequência -----
  $$(".view").forEach(function (v) {
    Array.prototype.forEach.call(v.children, function (c, k) { c.style.setProperty("--i", k); });
  });

  // ----- landing do app -----
  var stage = $("#lpStage"), hs = $(".hs"), track = $("#hsTrack");
  var panels = $$(".hs-panel"), dots = $$("#hsDots i");

  // Ícones em órbita ao redor do celular.
  var ring = $("#ring");
  if (ring) {
    var icons = $$("img", ring), R = innerWidth < 900 ? 190 : 300;
    icons.forEach(function (img, k) {
      var a = k / icons.length * Math.PI * 2;
      img.style.left = (Math.cos(a) * R) + "px";
      img.style.top = (Math.sin(a) * R * 0.92) + "px";
    });
  }

  function frame() {
    var vh = innerHeight;
    if (stage) {
      var r = stage.getBoundingClientRect();
      stage.style.setProperty("--p", clamp((vh - r.top) / (vh * 0.95)).toFixed(3));
    }
    if (hs) {
      var hr = hs.getBoundingClientRect();
      var p = clamp(-hr.top / (hr.height - vh));
      var x = p * (panels.length - 1);
      track.style.transform = "translate3d(" + (-x * innerWidth).toFixed(1) + "px,0,0)";
      panels.forEach(function (pn, k) { pn.style.setProperty("--off", (k - x).toFixed(3)); });
      var cur = Math.round(x);
      dots.forEach(function (d, k) { d.classList.toggle("on", k === cur); });
      panels.forEach(function (pn, k) {
        var v = $(".view", pn);
        if (v && Math.abs(k - x) < 0.45 && !v.classList.contains("on")) v.classList.add("on");
      });
    }
  }
  if (stage || hs) {
    var busy = false;
    addEventListener("scroll", function () {
      if (busy) return; busy = true;
      requestAnimationFrame(function () { frame(); busy = false; });
    }, { passive: true });
    addEventListener("resize", frame);
    frame();
  }

  // Bloqueio geral: o botão pausa a grade de apps em onda.
  var sw = $("#bigSwitch");
  if (sw) {
    var demo = $("#lockDemo"), state = $("#lockState");
    $$(".grid-apps div").forEach(function (d, k) { d.style.setProperty("--i", k); });
    sw.addEventListener("click", function () {
      var on = sw.getAttribute("aria-checked") !== "true";
      sw.setAttribute("aria-checked", on);
      demo.classList.toggle("paused", on);
      state.textContent = on
        ? "Tudo em pausa. Duolingo e WhatsApp continuam liberados."
        : "Apps liberados, cada um com o seu limite.";
    });
  }
})();
