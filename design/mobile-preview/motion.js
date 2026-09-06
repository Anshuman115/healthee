/* Progressive enhancement: content is visible without motion or IntersectionObserver. */
(() => {
  const preference = matchMedia('(prefers-reduced-motion: reduce)');
  const seen = new Set();
  const animations = new Set();
  let observer;
  let heroObserver;
  let userPaused = false;
  const enabled = () => !preference.matches && !userPaused;
  H.motionControl = (label = false) => `<button class="motion-toggle ${label?'button secondary full section':''}" data-action="motion" aria-label="Pause animations" aria-pressed="false"><svg class="motion-symbol" viewBox="0 0 12 12" aria-hidden="true"><path class="motion-pause" d="M2 1h3v10H2zM7 1h3v10H7z"/><path class="motion-play" d="M3 1l8 5-8 5z"/></svg>${label?'<span class="motion-label">Pause animations</span>':''}</button>`;
  function animate(element, frames, duration = 700, delay = 0) {
    const animation = element.animate(frames, {duration, delay, easing:'cubic-bezier(.16, 1, .3, 1)', fill:'backwards'});
    animations.add(animation);
    animation.onfinish = animation.oncancel = () => animations.delete(animation);
  }
  function reveal(element) {
    element.dataset.motionSeen = 'true';
    animate(element, [{opacity:.35, transform:'translateY(12px)'}, {opacity:1, transform:'none'}]);
    element.querySelectorAll('svg.chart').forEach((chart, index) => {
      // Axes and labels remain fixed; only the plotted marks enter.
      chart.querySelectorAll('rect, .data-line, .data-area, g[data-tone] > path:not(.gridline)').forEach((mark, i) => {
        animate(mark, [{opacity:0, transform:'translateY(6px)'}, {opacity:1, transform:'none'}], 850, Math.min(i * 24 + index * 60, 280));
      });
    });
    element.querySelectorAll('.tile-meter i, .factor-track i, .progress-track > i, .comparison-bar i').forEach((meter, i) => {
      meter.style.transformOrigin = 'left center';
      animate(meter, [{transform:'scaleX(0)'}, {transform:'scaleX(1)'}], 1000, i * 70);
    });
    if (element.matches('.bio-hero')) {
      const art = element.querySelector('.bio-halo');
      if (art) animate(art, [{opacity:0, transform:'scale(.96)'}, {opacity:1, transform:'none'}], 1500);
    }
  }
  function refreshAmbient() {
    document.querySelectorAll('.bio-hero').forEach(hero => {
      hero.dataset.ambient = enabled() && !document.hidden && hero.dataset.inView === 'true' ? 'running' : 'paused';
      H.setHaloMotion(hero, hero.dataset.ambient === 'running');
    });
  }
  function syncControls() {
    document.documentElement.dataset.motion = enabled() ? 'on' : 'off';
    document.querySelectorAll('[data-action="motion"]').forEach(button => {
      const label = preference.matches ? 'Animations off · reduced motion' : enabled() ? 'Pause animations' : 'Resume animations';
      button.setAttribute('aria-label', label);
      button.setAttribute('aria-pressed', String(!enabled()));
      button.disabled = preference.matches;
      const text = button.querySelector('.motion-label');
      if (text) text.textContent = label;
    });
    refreshAmbient();
  }
  H.mountMotion = () => {
    observer?.disconnect(); heroObserver?.disconnect();
    animations.forEach(animation => animation.cancel());
    H.mountHalos();
    syncControls();
    if (!('IntersectionObserver' in window)) return;
    heroObserver = new IntersectionObserver(entries => {
      entries.forEach(entry => { entry.target.dataset.inView = String(entry.isIntersecting); });
      refreshAmbient();
    });
    document.querySelectorAll('.bio-hero').forEach(hero => heroObserver.observe(hero));
    if (!enabled()) return;
    observer = new IntersectionObserver(entries => {
      entries.forEach(entry => {
        if (!entry.isIntersecting) return;
        const key = entry.target.dataset.motionKey;
        if (!seen.has(key)) { seen.add(key); reveal(entry.target); }
        observer.unobserve(entry.target);
      });
    }, {threshold:.08});
    document.querySelectorAll('#main .bio-hero, #main .summary-tile, #main .panel, #main .relationship-card, #main .sleep-reading').forEach((element, index) => {
      const key = `${H.route}:${index}`;
      element.dataset.motionKey = key;
      element.dataset.motionSeen = String(seen.has(key));
      if (!seen.has(key)) observer.observe(element);
    });
  };
  H.actions.motion = () => { userPaused = !userPaused; H.mountMotion(); };
  preference.addEventListener('change', () => H.mountMotion());
  document.addEventListener('visibilitychange', () => {
    refreshAmbient();
    animations.forEach(animation => document.hidden ? animation.pause() : animation.play());
  });
  // Dialog controls are added after a route renders.
  const sheet = H.sheet;
  H.sheet = (...args) => { sheet(...args); syncControls(); };
})();
