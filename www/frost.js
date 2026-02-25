// www/frost.js — FROST
// Count-up animation for elements with [data-countup="N"].
// Fires when the element enters the viewport (IntersectionObserver) so the
// animation is always visible, even if the stats are below the fold.
// Shiny's shiny:value event re-scans after every renderUI update.

(function () {
  'use strict';

  // Ease-out cubic: fast start, gentle finish — more satisfying than linear.
  function easeOutCubic(t) {
    return 1 - Math.pow(1 - t, 3);
  }

  function animateCount(el) {
    var target = parseInt(el.getAttribute('data-countup'), 10);
    if (isNaN(target)) return;

    // Remove attribute immediately to prevent the observer from re-triggering
    // on the same element if initCountUps() is called again.
    el.removeAttribute('data-countup');
    el.textContent = '0';

    var duration = 1400; // ms
    var start = performance.now();

    function frame(now) {
      var progress = Math.min((now - start) / duration, 1);
      el.textContent = Math.round(easeOutCubic(progress) * target);
      if (progress < 1) {
        requestAnimationFrame(frame);
      } else {
        el.textContent = target; // guarantee exact final value
      }
    }

    requestAnimationFrame(frame);
  }

  function initCountUps() {
    var els = document.querySelectorAll('[data-countup]');
    if (!els.length) return;

    if ('IntersectionObserver' in window) {
      var observer = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            animateCount(entry.target);
            observer.unobserve(entry.target);
          }
        });
      }, { threshold: 0.3 });

      els.forEach(function (el) { observer.observe(el); });
    } else {
      // Graceful fallback for browsers without IntersectionObserver
      els.forEach(function (el) {
        el.textContent = el.getAttribute('data-countup');
        el.removeAttribute('data-countup');
      });
    }
  }

  // Re-scan after Shiny pushes any renderUI output to the DOM.
  // The small delay lets the browser finish painting before we query.
  $(document).on('shiny:value', function () {
    setTimeout(initCountUps, 150);
  });

  // Also handle elements already in the DOM at connection time.
  $(document).on('shiny:connected', function () {
    setTimeout(initCountUps, 200);
  });

}());
