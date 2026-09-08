/* Small hash router: browser back, deep links and mobile navigation all work. */
(() => {
  H.actions.jump = element => document.getElementById(element.dataset.target)?.scrollIntoView({behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth',block:'start'});
  H.actions['sleep-previous'] = H.actions['date-previous'];
  H.actions['sleep-next'] = H.actions['date-next'];
  H.actions['select-night'] = element => { H.setViewDate(H.demo.sleep.nights[Number(element.dataset.value)].date); H.navigate('sleep'); };
  const tabs = [['today','Today','sun'],['sleep','Sleep','moon'],['activity','Activity','activity'],['insights','Insights','insights'],['actions','Actions','actions']];
  const parents = { recovery:'today','sleep-history':'sleep',workouts:'activity',workout:'activity',route:'activity',record:'activity',fitness:'activity',body:'activity',metric:'insights',metrics:'insights',insight:'insights',challenge:'actions',program:'actions',outcomes:'actions','action-history':'actions',journal:'actions' };
  const scrollPositions = new Map();
  const routeHistory = [];
  H.directory = [...tabs,['coach','Coach','coach'],['journal','Journal','journal'],['recovery','Recovery','heart'],['fitness','Fitness','activity'],['record','Record workout','location'],['settings','Settings','settings'],['welcome','Welcome','user']];
  H.route = location.hash.slice(1) || 'today';
  H.scenarioNotice = () => {
    if (H.state.scenario === 'missing') return H.notice('Your baseline is taking shape','Two sample nights collected. A few more nights will make your personal comparisons more useful.');
    if (H.state.scenario === 'offline') return `${H.notice('You’re offline. Your history isn’t.','Showing saved July readings. New analysis will be available after the next successful sync.','warm')}${H.link('Check sync','sync')}`;
    if (H.state.scenario === 'illness') return H.notice('A change worth paying attention to','The sample illness signal takes priority over the recovery score. Consider lighter activity. This is not a diagnosis.','error');
    return '';
  };
  H.navigate = route => { if (location.hash === `#${route}`) H.render(); else location.hash = route; };
  H.back = () => {
    if (routeHistory.length) history.back();
    else H.navigate(parents[H.route.split('/')[0]] || 'today');
  };
  const restorePreferences = () => {
    for (const [key,value] of Object.entries(H.state.preferences || {})) {
      const element = document.querySelector(`[data-preference="${key}"]`);
      if (element) element.value = value;
    }
    if (H.route === 'profile' && H.state.profile) Object.entries(H.state.profile).forEach(([key,value])=> { const input=document.querySelector(`#profile-form [name="${key}"]`); if(input) input.value=value; });
  };
  H.render = (keepScroll = false) => {
    const oldPosition = window.scrollY;
    const base = H.route.split('/')[0], active = tabs.some(tab=>tab[0]===base) ? base : parents[base] || 'today';
    const screen = H.isPast() && H.historyScreens[base] ? H.historyScreens[base] : H.screens[base];
    const tones={today:'fitness',sleep:'sleep',activity:'movement',insights:'oxygen',actions:'fitness'};
    document.querySelector('#main').dataset.tone = base==='metric' ? (H.metricDefinitions[H.route.split('/')[1]]?.tone || 'fitness') : (['workout','program','challenge','outcomes','fitness','body','route','record'].includes(base)?H.toneFor(base):tones[active]);
    document.querySelector('#main').innerHTML = `<div class="${keepScroll?'':'page-enter'}">${screen ? screen() : `${H.header('A small detour.','Screen not found',true)}${H.link('Back to Today','today','button full')}`}</div>`;
    document.querySelector('#bottom-nav').innerHTML = tabs.map(([route,label,icon])=>`<a href="#${route}" data-tone="${tones[route]}" ${route===active?'aria-current="page"':''}><span class="nav-icon">${H.icon(icon)}</span><span>${label}</span></a>`).join('');
    document.querySelector('#screen-directory').innerHTML = H.directory.map(([route,label,icon])=>`<a href="#${route}" class="directory-link ${route===base?'active':''}" ${route===base?'aria-current="page"':''}>${H.icon(icon)}${label}</a>`).join('');
    document.title = `Healthee · ${base[0].toUpperCase()+base.slice(1)} — design preview`;
    restorePreferences();
    window.scrollTo({top:keepScroll ? oldPosition : scrollPositions.get(H.route) || 0,behavior:'instant'});
    H.mountMotion();
  };
  addEventListener('hashchange', () => {
    scrollPositions.set(H.route,window.scrollY);
    const next = location.hash.slice(1) || 'today';
    if (routeHistory.at(-1) === next) routeHistory.pop(); else routeHistory.push(H.route);
    H.syncViewDate(); H.route = next;
    H.closeSheet(); H.render();
    document.querySelector('#main').focus({preventScroll:true});
  });
  addEventListener('popstate',()=>{ if(H.syncViewDate()) H.render(true); });
  document.addEventListener('click', event => {
    const element = event.target.closest('[data-action]');
    if (element && !element.disabled) {
      const action = H.actions[element.dataset.action];
      if (action) action(element);
    }
    if (event.target === document.querySelector('#sheet')) {
      const bounds = event.target.getBoundingClientRect();
      if (event.clientY < bounds.top || event.clientX < bounds.left || event.clientX > bounds.right) H.closeSheet();
    }
  });
  document.addEventListener('submit', event => { event.preventDefault(); if(event.target.checkValidity()) H.handleForm(event.target); });
  document.addEventListener('change', event => {
    if (event.target.dataset.preference) { H.state.preferences ||= {}; H.state.preferences[event.target.dataset.preference] = event.target.value; H.toast('Preference updated in this preview'); }
  });
  document.addEventListener('input', event => {
    if (!event.target.classList.contains('chart-scrubber')) return;
    const wrapper = event.target.closest('.chart-interactive');
    const values = wrapper.dataset.chartValues.split(','), index=Number(event.target.value);
    const labels = JSON.parse(wrapper.dataset.chartLabels);
    wrapper.querySelector('output').textContent = `${values[index] || 'No reading'} ${values[index] ? wrapper.dataset.chartUnit : ''} · ${labels[index]}`;
    const dot=wrapper.querySelector('.data-dot');
    if (dot && values[index] !== '') {
      dot.setAttribute('cx',4 + index / Math.max(1,values.length-1) * 302);
      dot.setAttribute('cy',140 - (Number(values[index])-Number(wrapper.dataset.chartMin)) / (Number(wrapper.dataset.chartMax)-Number(wrapper.dataset.chartMin))*122);
    }
  });
  setInterval(() => {
    if (!H.state.recording) return;
    H.state.seconds = Math.floor((Date.now()-H.state.startedAt)/1000);
    const timer = document.querySelector('#record-timer');
    if (timer) timer.textContent = H.formatTime(H.state.seconds);
  },1000);
  matchMedia('(prefers-color-scheme: dark)').addEventListener('change',()=> {if(H.state.theme==='system') H.setTheme('system');});
  H.render();
})();
