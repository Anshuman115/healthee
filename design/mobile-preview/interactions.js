/* Local-only interactions. Delays represent visible design states, never a real request. */
(() => {
  let toastTimeout;
  H.toast = message => {
    const element = document.querySelector('#toast');
    clearTimeout(toastTimeout);
    element.textContent = message;
    element.classList.add('visible');
    toastTimeout = setTimeout(() => element.classList.remove('visible'), 2800);
  };
  H.sheet = (title, content) => {
    const dialog = document.querySelector('#sheet');
    dialog.innerHTML = `<div class="sheet-handle" aria-hidden="true"></div><div class="sheet-head"><h2 id="sheet-title">${title}</h2><button class="icon-button" data-action="close" aria-label="Close dialog">${H.icon('close')}</button></div>${content}`;
    if (!dialog.open) dialog.showModal();
  };
  H.closeSheet = () => document.querySelector('#sheet').close();
  H.formatTime = seconds => `${Math.floor(seconds / 60).toString().padStart(2,'0')}:${(seconds % 60).toString().padStart(2,'0')}`;
  H.setTheme = value => {
    H.state.theme = value;
    document.documentElement.dataset.theme = value === 'system' ? (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light') : value;
    const control = document.querySelector('.studio-bottom [data-action="theme"]');
    control.innerHTML = `Switch to ${document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark'} ${H.icon('arrow','small')}`;
    if (H.route === 'appearance') H.render(true);
  };
  H.openLog = kind => {
    const [icon, name, unit, placeholder] = H.journalKinds.find(item => item[1] === kind);
    const numeric = !['Habit','Symptoms','Fasting'].includes(name);
    const limits = name === 'Mood' ? 'min="1" max="5" step="1"' : 'min="0.1" max="10000" step="0.1"';
    const valueField = name === 'Fasting' ? '<label class="field">What are you recording?<select name="value"><option>Start fasting</option><option>End fasting</option></select></label>' : `<label class="field">${numeric ? `Amount · ${unit}` : 'What would you like to note?'}<${numeric ? 'input' : 'textarea'} name="value" ${numeric ? `type="number" ${limits} placeholder="${placeholder}"` : 'maxlength="500"'} required>${numeric ? '' : '</textarea>'}<small>${name==='Weight'?'Enter a new measurement explicitly. Your previous weight is not prefilled.':'A little context is enough.'}</small></label>`;
    H.sheet(`Log ${name.toLowerCase()}`,`<form id="journal-form" data-kind="${name}" data-icon="${icon}" data-unit="${numeric?unit:''}">${valueField}<label class="field">When?<input type="datetime-local" name="time" value="${H.viewDate()}T17:00" required></label><p class="form-note">Saved to the preview only. Nothing is uploaded.</p><button class="button full" type="submit">Save entry</button></form>`);
  };
  H.evidenceSheet = note => {
    const reference = H.notes?.[note]?.summary ? H.notes[note] : null;
    H.sheet('Behind the explanation',`${H.badge(reference?.grade || 'Method & limitations','indigo')}<h3 class="section">${H.escape(reference?.title || note.replaceAll('_',' '))}</h3><p class="small section">${H.escape(reference?.summary || 'This design shows where the app’s evidence and method explanation will appear. A verified note excerpt is not bundled for this topic.')}</p><p class="form-note">${reference ? 'Research-library excerpt, included for layout review. This preview does not generate health advice.' : 'No evidence grade or source is invented when a matching note is unavailable.'}</p><hr class="divider"><h3>Keep it in context</h3><p class="small section">Your wearable provides estimates. Personal patterns are not a diagnosis, and observations do not establish a cause.</p>${reference?.url ? `<a class="button secondary full section" target="_blank" rel="noreferrer" href="${H.escape(reference.url)}">Open original source ${H.icon('arrow','small')}</a>` : ''}`);
  };
  H.previewSheet = () => H.sheet('Explore the design',`<p class="small">Every screen is a working design sample. Changes stay in this tab and reset on reload.</p><div class="preview-options">${H.directory.map(([route,label,icon])=>`<a href="#${route}">${H.icon(icon)}${label}</a>`).join('')}</div><h3 class="section">Try a different day</h3><div class="preview-options">${[['normal','Sample day'],['missing','Missing data'],['offline','Offline'],['illness','Illness signal']].map(([value,label])=>`<button class="button secondary" data-action="scenario" data-value="${value}">${label}</button>`).join('')}</div>${H.button('Switch light / dark','theme','soft full section','sun')}${H.motionControl(true)}`);
  H.ask = question => {
    const prompt = question.trim();
    if (!prompt) return;
    H.state.messages.push({role:'user',text:prompt});
    let answer = '<p>This is a scripted design preview, so I haven’t analysed that question. Try one of the sleep, recovery or HRV prompts to see how an answer and its sources will look.</p>';
    if (/sleep|recovery|hrv/i.test(prompt)) answer = `<p>In this sample day, sleep is <strong>6h 20m</strong>, compared with an estimated <strong>8h need</strong>. Overnight HRV is <strong>45 ms</strong>, and resting heart rate is <strong>55 bpm</strong>.</p><p>These readings are a starting point. Your recent pattern, how you feel, and the context in your journal belong in the same conversation.</p>${H.evidence('sleep_need_debt','Sleep need & debt')}<br>${H.badge('Scripted sample · July data')}`;
    H.state.messages.push({role:'assistant',text:answer});
    H.render(true);
    document.querySelector('.coach-form').scrollIntoView({block:'nearest',behavior:'instant'});
  };
  const syncDemo = () => {
    H.sheet('Bringing it together',`<div role="status" aria-live="polite"><div class="sync-stages"><div>${H.icon('strap')}Strap</div>${H.icon('arrow')}<div>${H.icon('cloud')}Your server</div></div><p class="center small">Demonstrating a sync…</p><button class="button full section" disabled>Syncing sample</button></div>`);
    const dialog = document.querySelector('#sheet');
    const currentContent = dialog.firstElementChild;
    setTimeout(() => {
      if (!dialog.open || dialog.firstElementChild !== currentContent) return;
      const offline = H.state.scenario === 'offline';
      H.sheet(offline ? 'Your readings are safe.' : 'Everything in its place.',`${H.notice(offline?'Upload is waiting':'Sample sync complete',offline?'Your server is offline. The mobile app keeps collected readings locally until upload can resume.':'Your sample readings are ready to explore. No real device or server was contacted.',offline?'error':'')}${H.button(offline?'Try again':'Done',offline?'sync':'close','full')}`);
    },1000);
  };
  const scanDemo = () => {
    H.sheet('Find your strap',`<p class="small" role="status">Looking for a sample device…</p><button class="button full section" disabled>Scanning</button>`);
    const dialog = document.querySelector('#sheet'), currentContent = dialog.firstElementChild;
    setTimeout(() => {
      if (!dialog.open || dialog.firstElementChild !== currentContent) return;
      H.sheet('A familiar connection.',`<div class="device-visual">${H.icon('strap')}</div><h3 class="center">Amazfit Helio Strap</h3><p class="small center section">Sample device found nearby</p>${H.button('Connect sample strap','pair','full section')}`);
    },900);
  };
  H.actions = {
    back: () => H.back(), close: H.closeSheet, preview: H.previewSheet,
    theme: () => H.setTheme(document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark'),
    'set-theme': element => H.setTheme(element.dataset.value),
    evidence: element => H.evidenceSheet(element.dataset.note),
    range: element => { H.state.range = element.dataset.value; H.render(true); },
    scenario: element => { H.state.scenario = element.dataset.value; H.closeSheet(); H.navigate('today'); H.render(); },
    log: element => H.openLog(element.dataset.kind), 'log-weight': () => H.openLog('Weight'),
    adopt: () => { H.state.adopted = !H.state.adopted; H.render(true); H.toast(H.state.adopted?'Intention added to this preview':'Intention removed from this preview'); },
    toggle: element => { const enabled = element.getAttribute('aria-checked') !== 'true'; element.setAttribute('aria-checked',enabled); H.state.reminders[element.dataset.key] = enabled; H.toast(enabled?'Enabled in preview only':'Disabled in preview'); },
    ask: element => H.ask(element.dataset.prompt), sync: syncDemo, scan: scanDemo,
    pair: () => { H.closeSheet(); H.navigate('device'); H.toast('Sample strap connected'); },
    adapt: () => H.sheet('Make the target fit.',`<p class="small">Adjusting is part of finding a sustainable rhythm.</p><form id="target-form" class="section"><label class="field">Daily steps<input name="target" type="number" min="100" max="100000" step="100" value="${H.state.target || 9000}" required></label><button class="button full">Update sample target</button></form>`),
    'end-challenge': () => H.sheet('End this challenge?',`<p class="small">Your completed days stay in your history. You can make room for a different step.</p><div class="two section">${H.button('Keep going','close','secondary')}${H.button('End challenge','confirm-end')}</div>`),
    'confirm-end': () => { H.state.challengeEnded = true; H.closeSheet(); H.navigate('actions'); H.toast('Sample challenge ended'); },
    'program-toggle': () => { H.state.program = !H.state.program; H.render(true); H.toast(H.state.program?'Program started in preview':'Program ended in preview'); },
    'record-start': () => { H.state.recording = true; H.state.seconds = 0; H.state.startedAt = Date.now(); H.render(true); },
    'record-stop': () => { H.state.recording = false; H.render(true); H.sheet('A little time outside.',`<div class="center section">${H.stat(H.formatTime(H.state.seconds),'','Demo elapsed time')}</div><p class="small section">Your recording flow is complete. No GPS points or health measurements were collected.</p>${H.link('Explore a saved sample','route','button full section')}`); },
    'demo-signin': () => { H.navigate('pairing'); H.toast('Sample sign-in · no account accessed'); },
    'server-setup': () => H.navigate('account'),
  };
  H.handleForm = form => {
    const fields = new FormData(form);
    if (form.id === 'journal-form') {
      H.state.journal.unshift({kind:form.dataset.kind,icon:form.dataset.icon,unit:form.dataset.unit,value:fields.get('value'),time:fields.get('time').replace('T',' ')});
      H.closeSheet(); H.render(true); H.toast('Entry saved in this preview');
    } else if (form.id === 'coach-form') H.ask(String(fields.get('question')));
    else if (form.id === 'profile-form') {
      H.state.profileName = String(fields.get('name')).trim();
      H.state.profile = Object.fromEntries(fields); H.toast('Profile saved in this preview');
    } else if (form.id === 'server-form') H.sheet('Sample connection is ready.',`${H.notice('Your server address has the right format','This preview does not contact it or test authentication. The app will show connection and access failures here.')}${H.button('Done','close','full')}`);
    else if (form.id === 'target-form') { H.state.target = Number(fields.get('target')); H.closeSheet(); H.render(true); H.toast('Sample target updated'); }
  };
})();
