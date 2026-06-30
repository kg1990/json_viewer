// JSONViewer landing page — vanilla JS, client-side only, no network.
(function () {
  "use strict";

  // ---- Language toggle (English <-> 中文) ----
  var html = document.documentElement;
  function setLang(lang) {
    html.setAttribute("lang", lang === "zh" ? "zh-Hans" : "en");
    document.body.setAttribute("data-lang", lang);
    try { localStorage.setItem("jv-lang", lang); } catch (e) {}
    // Swap visible text for every bilingual node. Both strings live in the
    // DOM as data-en / data-zh attributes, so nothing is lost on toggle.
    var nodes = document.querySelectorAll("[data-en][data-zh]");
    for (var j = 0; j < nodes.length; j++) {
      var n = nodes[j];
      var txt = lang === "zh" ? n.getAttribute("data-zh") : n.getAttribute("data-en");
      if (txt !== null) n.textContent = txt;
    }
    var btns = document.querySelectorAll("[data-lang-set]");
    for (var i = 0; i < btns.length; i++) {
      var b = btns[i];
      var active = b.getAttribute("data-lang-set") === lang;
      b.setAttribute("aria-pressed", active ? "true" : "false");
    }
  }
  var toggles = document.querySelectorAll("[data-lang-set]");
  for (var i = 0; i < toggles.length; i++) {
    toggles[i].addEventListener("click", function () {
      setLang(this.getAttribute("data-lang-set"));
    });
  }
  var saved = "en";
  try { saved = localStorage.getItem("jv-lang") || "en"; } catch (e) {}
  setLang(saved);

  // ---- Live demo: Beautify / Minify ----
  var input = document.getElementById("demo-input");
  var output = document.getElementById("demo-output");
  var indentSel = document.getElementById("demo-indent");

  function currentLang() {
    return document.body.getAttribute("data-lang") || "en";
  }

  function showError(err) {
    output.classList.add("is-error");
    var prefix = currentLang() === "zh" ? "无效的 JSON：" : "Invalid JSON: ";
    output.textContent = prefix + err.message;
  }

  function showResult(text) {
    output.classList.remove("is-error");
    output.textContent = text;
  }

  function indentValue() {
    if (!indentSel) return 2;
    var v = indentSel.value;
    if (v === "tab") return "\t";
    return parseInt(v, 10);
  }

  function beautify() {
    try {
      var obj = JSON.parse(input.value);
      showResult(JSON.stringify(obj, null, indentValue()));
    } catch (e) {
      showError(e);
    }
  }

  function minify() {
    try {
      var obj = JSON.parse(input.value);
      showResult(JSON.stringify(obj));
    } catch (e) {
      showError(e);
    }
  }

  var bBtn = document.getElementById("demo-beautify");
  var mBtn = document.getElementById("demo-minify");
  if (bBtn) bBtn.addEventListener("click", beautify);
  if (mBtn) mBtn.addEventListener("click", minify);

  // Initial render.
  if (input && output) beautify();
})();
