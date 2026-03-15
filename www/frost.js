// www/frost.js — FROST count-up animation
// Animates [data-countup="N"] elements when they enter the viewport.

function animateCount(el) {
  var target = +el.dataset.countup;
  el.removeAttribute('data-countup');
  var start = performance.now();
  (function frame(now) {
    var t = Math.min((now - start) / 1400, 1);
    el.textContent = Math.round((1 - Math.pow(1 - t, 3)) * target);
    if (t < 1) requestAnimationFrame(frame);
  })(performance.now());
}

function initCountUps() {
  document.querySelectorAll('[data-countup]').forEach(function(el) {
    new IntersectionObserver(function(entries, obs) {
      if (entries[0].isIntersecting) { animateCount(el); obs.disconnect(); }
    }, { threshold: 0.3 }).observe(el);
  });
}

$(document).on('shiny:connected shiny:value', function() {
  setTimeout(initCountUps, 150);
});
