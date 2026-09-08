/* Shared, accessible vocabulary across all prototype screens. */
(() => {
  const paths = {
    sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M2 12h2m16 0h2M5 5l1.4 1.4m11.2 11.2L19 19M5 19l1.4-1.4M17.6 6.4 19 5"/>',
    moon: '<path d="M20.5 13a8.5 8.5 0 1 1-9.5-9.5 7 7 0 0 0 9.5 9.5Z"/>',
    activity: '<path d="M3 13h4l3-8 4 14 3-6h4"/>',
    insights: '<path d="M4 19V12m5 7V7m6 12V3m5 16v-8"/>',
    check: '<path d="m5 12 4 4L19 6"/>',
    actions: '<rect x="4" y="4" width="16" height="16" rx="5"/><path d="m8 12 3 3 5-6"/>',
    arrow: '<path d="M5 12h14m-5-5 5 5-5 5"/>',
    chevron: '<path d="m9 5 7 7-7 7"/>',
    back: '<path d="m14 5-7 7 7 7"/>',
    close: '<path d="m6 6 12 12M6 18 18 6"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    heart: '<path d="M20.5 5.5a5.1 5.1 0 0 0-7.2 0L12 6.8l-1.3-1.3a5.1 5.1 0 0 0-7.2 7.2L12 21l8.5-8.3a5.1 5.1 0 0 0 0-7.2Z"/>',
    strap: '<rect x="7" y="6" width="10" height="12" rx="4"/><path d="M9 6V2h6v4m-6 12v4h6v-4m-4-8h2v4h-2"/>',
    battery: '<rect x="3" y="7" width="17" height="10" rx="2"/><path d="M22 10v4M6 10v4m3-4v4m3-4v4m3-4v4"/>',
    coach: '<path d="M20 11a8 8 0 0 1-8 8H4l1.6-4A8 8 0 1 1 20 11Z"/><path d="M8 11h.01M12 11h.01M16 11h.01"/>',
    journal: '<path d="M6 3h13v18H6a3 3 0 0 1-3-3V6a3 3 0 0 1 3-3Zm0 0v14m-3 1a2 2 0 0 1 2-1h14M10 7h5m-5 4h5"/>',
    walk: '<circle cx="14" cy="4" r="2"/><path d="m7 10 5-3 4 5h4m-8-5-2 8 5 3v4m-5-7-4 6"/>',
    coffee: '<path d="M4 8h12v7a5 5 0 0 1-5 5H9a5 5 0 0 1-5-5V8Zm12 1h2a3 3 0 0 1 0 6h-2M7 2v3m5-3v3M2 22h18"/>',
    info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v6m0-10h.01"/>',
    settings: '<path d="m12 3 2 3 4-.2.3 4 2.7 2.2-2.7 2.2-.3 4-4-.2-2 3-2-3-4 .2-.3-4L3 12l2.7-2.2.3-4 4 .2 2-3Z"/><circle cx="12" cy="12" r="3"/>',
    user: '<circle cx="12" cy="8" r="4"/><path d="M4 21v-2a8 8 0 0 1 16 0v2"/>',
    bell: '<path d="M18 8a6 6 0 0 0-12 0c0 8-3 8-3 10h18c0-2-3-2-3-10M10 22h4"/>',
    sync: '<path d="M20 7v5h-5M4 17v-5h5"/><path d="M6 7a7 7 0 0 1 12-1l2 3M4 15l2 3a7 7 0 0 0 12-1"/>',
    shield: '<path d="m12 2 8 3v6c0 5-8 11-8 11S4 16 4 11V5l8-3Z"/><path d="m8 11 3 3 5-5"/>',
    drop: '<path d="M12 2S5 10 5 15a7 7 0 0 0 14 0c0-5-7-13-7-13Z"/>',
    location: '<path d="M19 9c0 6-7 13-7 13S5 15 5 9a7 7 0 1 1 14 0Z"/><circle cx="12" cy="9" r="2"/>',
    clock: '<circle cx="12" cy="12" r="9"/><path d="M12 6v6l4 2"/>',
    flag: '<path d="M5 22V3m0 1c5-5 9 5 14 0v10c-5 5-9-5-14 0"/>',
    spark: '<path d="m12 2 2.7 7.3L22 12l-7.3 2.7L12 22l-2.7-7.3L2 12l7.3-2.7L12 2Z"/>',
    cloud: '<path d="M7 18a5 5 0 1 1 .5-10 6 6 0 0 1 11.4 1.5A4.3 4.3 0 0 1 18 18H7Z"/>',
    play: '<path d="m8 4 12 8-12 8V4Z"/>',
    stop: '<rect x="5" y="5" width="14" height="14" rx="3"/>',
    weight: '<path d="M5 4h14a2 2 0 0 1 2 2v13a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2Z"/><path d="M8 8a5 5 0 0 1 8 0l-4 5-4-5Zm4 0V5"/>',
    leaf: '<path d="M20 3C4 1 1 12 7 17s15-1 13-14ZM4 21 16 8"/>',
    smile: '<circle cx="12" cy="12" r="9"/><path d="M8 9h.01M16 9h.01M8 14a4 4 0 0 0 8 0"/>',
  };
  H.icon = (name, size = '') => `<svg class="icon ${size}" viewBox="0 0 24 24" aria-hidden="true">${paths[name] || paths.activity}</svg>`;
  H.escape = value => String(value).replace(/[&<>"']/g, character => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[character]));
  H.button = (label, action, kind = '', icon = '') => `<button class="button ${kind}" data-action="${action}">${icon ? H.icon(icon, 'small') : ''}${label}</button>`;
  H.link = (label, route, kind = 'text-button') => `<a class="${kind}" href="#${route}">${label}${H.icon('arrow', 'small')}</a>`;
  H.header = (title, subtitle = 'Friday, 31 July', detail = false) => `<header class="page-header ${detail ? 'detail' : ''}">${detail ? `<button class="icon-button" data-action="back" aria-label="Go back">${H.icon('back')}</button>` : ''}<div class="grow">${H.history?.routes.has(H.route?.split('/')[0]) ? (H.route.split('/')[0]==='today' ? H.dateControl() : `<p class="date"><time datetime="${H.viewDate()}">${H.dateLabel(H.viewDate(),true)}</time> · ${H.isPast()?'Selected day':'Latest sample'}</p>`) : `<p class="date">${subtitle}</p>`}<h1>${title}</h1></div>${detail ? '' : `<a href="#settings" class="icon-button avatar" aria-label="Profile and settings">A</a>`}</header>`;
  H.section = (title, body, route = '', label = 'See all') => `<section class="section"><div class="section-head"><h2>${title}</h2>${route ? H.link(label, route) : ''}</div>${body}</section>`;
  H.row = (icon, title, subtitle, route, end = '') => `<a class="list-row" href="#${route}" data-tone="${H.toneFor?.(route) || 'fitness'}"><span class="icon-tile">${H.icon(icon)}</span><span class="grow"><strong>${title}</strong><small>${subtitle}</small></span>${end || H.icon('chevron')}</a>`;
  H.source = (label = 'Helio Strap · sample day, 31 Jul') => `<p class="source">${H.icon('shield')}${label}</p>`;
  H.badge = (label, style = '') => `<span class="badge ${style}">${label}</span>`;
  H.stat = (value, unit, label, extra = '') => `<div class="stat"><p class="stat-label">${label}</p><div class="stat-number">${value}<span>${unit}</span></div>${extra}</div>`;
  H.segment = (items, selected, action) => `<div class="segment">${items.map(([value, label]) => `<button data-action="${action}" data-value="${value}" aria-pressed="${value === selected}">${label}</button>`).join('')}</div>`;
  H.evidence = (note = 'recovery_readiness', label = 'How we know') => `<button class="text-button" data-action="evidence" data-note="${note}">${H.icon('info', 'small')}${label}</button>`;
  H.notice = (title, copy, type = '') => `<div class="notice ${type}">${H.icon(type === 'error' ? 'cloud' : 'info')}<div><strong>${title}</strong><p>${copy}</p></div></div>`;
  H.footer = () => `<footer class="data-footer">${H.icon('shield', 'small')}Your data. A little better understood.<br><span>Design sample · no live measurements</span></footer>`;
})();
