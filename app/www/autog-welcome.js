// Welcome dialog: step navigation and the three practice questions.
(function () {
  function steps() { return document.querySelectorAll('.wstep'); }
  function current() { var s = steps(); for (var i = 0; i < s.length; i++) if (s[i].style.display !== 'none') return i; return 0; }
  function practiceDone() { return document.querySelectorAll('.practice[data-done]').length === document.querySelectorAll('.practice').length; }
  function show(i) {
    var s = steps(); for (var k = 0; k < s.length; k++) s[k].style.display = k === i ? '' : 'none';
    var back = document.getElementById('w_back'), next = document.getElementById('w_next');
    back.style.visibility = i === 0 ? 'hidden' : 'visible';
    next.firstChild.nodeValue = i === s.length - 1 ? 'Start using AutoG ' : 'Next ';
    next.disabled = (i === 2 && !practiceDone());
    var body = document.querySelector('.modal-body'); if (body) body.scrollTop = 0;
  }
  document.addEventListener('click', function (e) {
    var t = e.target.closest ? e.target.closest('button') : null; if (!t) return;
    if (t.id === 'w_next') { var i = current(); if (i === steps().length - 1) Shiny.setInputValue('welcome_done', Math.random(), {priority: 'event'}); else show(i + 1); }
    if (t.id === 'w_back') show(current() - 1);
    if (t.classList.contains('pr-btn')) {
      var p = t.closest('.practice'), fb = p.querySelector('.pr-fb'), right = t.getAttribute('data-answer') === p.getAttribute('data-correct');
      fb.textContent = (right ? 'Right. ' : 'Not quite. ') + fb.getAttribute('data-why');
      fb.className = 'pr-fb ' + (right ? 'ok' : 'no'); p.setAttribute('data-done', '1');
      var b = p.querySelectorAll('.pr-btn'); for (var k = 0; k < b.length; k++) b[k].classList.toggle('picked', b[k] === t);
      if (practiceDone()) { var n = document.getElementById('pr-need'); if (n) n.style.display = 'none'; document.getElementById('w_next').disabled = false; }
    }
  });
})();
