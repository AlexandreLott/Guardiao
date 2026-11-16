(function () {
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  var pad = function (n) { return String(n).padStart(2, "0"); };

  // Barra de progresso da leitura e borda do topo.
  var top = $("#top"), progress = $("#progress");
  // Profundidade na abertura: as peças se movem em ritmos diferentes ao rolar.
  var depth = $$("#heroStage [data-depth]");
  // Linha do dia.
  var steps = $$("#steps .step"), views = $$("#dayScreen .view"), clock = $("#clock"),
      fill = $("#dayFill"), glow = $("#glow"), stepsBox = $("#steps");
  var shown = -1, clockNow = 450, clockTo = 450, raf = 0;

  var clockFrom = 450, clockStart = 0;
  function tickClock(now) {
    var t = Math.min(1, ((now || performance.now()) - clockStart) / 700);
    var e = 1 - Math.pow(1 - t, 3);
    clockNow = clockFrom + (clockTo - clockFrom) * e;
    var m = Math.round(clockNow);
    clock.textContent = pad(Math.floor(m / 60)) + ":" + pad(m % 60);
    if (t < 1) raf = requestAnimationFrame(tickClock);
  }

  var dayScreen = document.getElementById("dayScreen"), wash = null;
  if (dayScreen) { wash = document.createElement("span"); wash.className = "wash"; dayScreen.insertBefore(wash, dayScreen.firstChild); }

  function showStep(i) {
    if (i === shown) return;
    var dir = i > shown ? 1 : -1, prev = views[shown];
    shown = i;
    steps.forEach(function (s, k) { s.classList.toggle("on", k === i); });
    dayScreen.style.setProperty("--dir", dir);
    views.forEach(function (v, k) { v.classList.remove("was"); v.classList.toggle("on", k === i); });
    if (prev) prev.classList.add("was");
    clockTo = +steps[i].dataset.min;
    clockFrom = clockNow; clockStart = performance.now();
    cancelAnimationFrame(raf); raf = requestAnimationFrame(tickClock);
    var tone = steps[i].dataset.tone;
    if (glow) glow.style.background = tone;
    if (prev) {
      var ph = dayScreen.parentNode;
      ph.style.setProperty("--dir", dir);
      ph.classList.remove("bump"); void ph.offsetWidth; ph.classList.add("bump");
      wash.style.background = tone;
      wash.classList.remove("go"); void wash.offsetWidth; wash.classList.add("go");
    }
  }

  function onScroll() {
    var y = window.scrollY, h = document.documentElement.scrollHeight - innerHeight;
    if (progress) progress.style.transform = "scaleX(" + (h > 0 ? y / h : 0) + ")";
    if (top) top.classList.toggle("scrolled", y > 8);
    if (y < innerHeight * 1.2) depth.forEach(function (el) {
      el.style.translate = "0 " + (-y * +el.dataset.depth).toFixed(1) + "px";
    });
    if (steps.length) {
      var mid = innerHeight * 0.5, best = 0, bestD = 1e9;
      steps.forEach(function (s, k) {
        var r = s.getBoundingClientRect(), d = Math.abs(r.top + r.height / 2 - mid);
        if (d < bestD) { bestD = d; best = k; }
      });
      showStep(best);
      var box = stepsBox.getBoundingClientRect();
      var first = steps[0].getBoundingClientRect(), last = steps[steps.length - 1].getBoundingClientRect();
      var from = first.top + first.height / 2 - 62, to = last.top + last.height / 2 - 62;
      var p = Math.max(0, Math.min(1, (mid - from) / (to - from)));
      fill.style.top = (from - box.top) + "px";
      fill.style.height = (p * (to - from)) + "px";
      dayScreen.parentNode.style.rotate = "y " + ((0.5 - p) * 18).toFixed(1) + "deg";
    }
  }
  var ticking = false;
  addEventListener("scroll", function () {
    if (ticking) return; ticking = true;
    requestAnimationFrame(function () { onScroll(); ticking = false; });
  }, { passive: true });
  addEventListener("resize", onScroll);
  onScroll();

  // Contagem regressiva da tela de bloqueio.
  var timer = $("#timer");
  if (timer) {
    var left = 6 * 3600 + 54 * 60 + 12;
    setInterval(function () {
      left = left > 0 ? left - 1 : 0;
      timer.textContent = pad(Math.floor(left / 3600)) + ":" + pad(Math.floor(left % 3600 / 60)) + ":" + pad(left % 60);
    }, 1000);
  }

  // O painel aparece uma vez, quando entra na tela.
  var io = new IntersectionObserver(function (es) {
    es.forEach(function (e) { if (e.isIntersecting) { e.target.classList.add("inview"); io.unobserve(e.target); } });
  }, { threshold: 0.25 });
  $$(".reveal").forEach(function (el) { io.observe(el); });

  // Painel do responsável: filtros e bloqueio funcionam de verdade.
  var panel = $("#panel");
  if (panel) {
    var rows = $$(".prow", panel), count = $("#count");
    $$(".chip", panel).forEach(function (chip) {
      chip.addEventListener("click", function () {
        $$(".chip", panel).forEach(function (c) { c.setAttribute("aria-pressed", c === chip); });
        var f = chip.dataset.f, n = 0;
        rows.forEach(function (r) {
          var ok = f === "all" || r.dataset.c === f;
          r.classList.toggle("hide", !ok); if (ok) n++;
        });
        count.textContent = n + (n === 1 ? " app" : " apps");
      });
    });
    rows.forEach(function (r) {
      var sw = $(".switch", r), pill = $(".pill", r), small = $("small", r);
      var saved = { pill: pill.textContent, cls: pill.className, small: small.textContent };
      if (r.classList.contains("blocked")) saved = { pill: "30 min", cls: "pill", small: "0 min de 30 min hoje" };
      sw.addEventListener("click", function () {
        var on = sw.getAttribute("aria-checked") !== "true";
        sw.setAttribute("aria-checked", on);
        r.classList.toggle("blocked", !on);
        pill.textContent = on ? saved.pill : "Bloqueado";
        pill.className = on ? saved.cls : "pill red";
        small.textContent = on ? saved.small : "Bloqueado o dia todo";
      });
    });
  }

  // Página de download: versão, data e tamanho vêm da release mais recente no GitHub.
  var rel = $("#release");
  if (rel) {
    fetch("https://api.github.com/repos/AlexandreLott/Guardiao/releases/latest")
      .then(function (r) { if (!r.ok) throw 0; return r.json(); })
      .then(function (d) {
        var a = (d.assets || []).filter(function (x) { return /\.apk$/.test(x.name); })[0];
        var n = (d.tag_name || "").replace("apk-", "");
        $("#relVersion").textContent = "1.0." + n;
        $("#relDate").textContent = new Date(d.published_at).toLocaleDateString("pt-BR", { day: "numeric", month: "long", year: "numeric" });
        if (a) {
          $("#relSize").textContent = Math.round(a.size / 1048576) + " MB";
          $$("[data-apk]").forEach(function (el) { el.href = a.browser_download_url; });
        }
        rel.dataset.state = "ok";
      })
      .catch(function () {
        $("#relVersion").textContent = "mais recente";
        $("#relDate").textContent = "veja no GitHub";
        $("#relSize").textContent = "cerca de 70 MB";
      });
  }
})();
