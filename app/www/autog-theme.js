// Light / dark / auto. The choice is remembered in this browser on this PC only.
(function () {
  var KEY = 'autog-theme';
  function saved() { try { return localStorage.getItem(KEY) || 'auto'; } catch (e) { return 'auto'; } }
  function apply(choice) {
    var dark = choice === 'dark' || (choice === 'auto' && window.matchMedia && matchMedia('(prefers-color-scheme: dark)').matches);
    document.documentElement.setAttribute('data-theme', dark ? 'dark' : 'light');
    var b = document.querySelectorAll('.theme button');
    for (var i = 0; i < b.length; i++) {
      var on = b[i].getAttribute('data-theme-choice') === choice;
      b[i].className = on ? 'on' : ''; b[i].setAttribute('aria-pressed', on ? 'true' : 'false');
    }
  }
  apply(saved());                                  // before the page paints
  document.addEventListener('DOMContentLoaded', function () {
    apply(saved());
    document.addEventListener('click', function (e) {
      var c = e.target.getAttribute && e.target.getAttribute('data-theme-choice');
      if (!c) return;
      try { localStorage.setItem(KEY, c); } catch (err) {}
      apply(c);
    });
    if (window.matchMedia) matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function () { apply(saved()); });
  });
})();
