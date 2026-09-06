/* Historical views use dated observations, never a relabelled current-day model. */
(() => {
  const screens = H.historyScreens = {};
  const panels = keys => keys.map(key=>H.historyPanel(key)).join('');
  const missing = (title,copy) => `<div class="history-missing"><h3>${title}</h3><p>${copy}</p></div>`;
  const header = (title,detail=false) => H.header(title,'',detail);
  const tiles = () => `<div class="history-tiles">${[['sleep','Sleep',H.duration(H.dayValue('sleep')),'sleep'],['steps','Steps',H.formatReading(H.dayValue('steps')),'movement'],['hrv','HRV',H.formatReading(H.dayValue('hrv'))+' ms','fitness']].map(([key,label,value,tone])=>`<a href="#${key==='sleep'?'sleep':`metric/${key}`}" data-tone="${tone}"><span>${label}</span><strong>${value}</strong></a>`).join('')}</div>`;
  screens.today = () => `${header('Your day')}${tiles()}
    ${missing('Daily analysis','Biological age and recovery were not saved for this day in the preview. Your dated measurements are available below.')}
    ${H.chapter('overnight','Overnight readings','sleep','moon')}${panels(['sleep','hrv','rhr','spo2','breathing','temperature','efficiency','regularity'])}
    ${H.chapter('daytime','Movement & effort','movement','walk')}${panels(['steps','energy','total-energy','distance','mvpa','load'])}
    ${missing('Heart rate & stress timeline','Hourly traces are included only for the latest sample day.')}
    ${H.chapter('longer-view','Fitness & context','fitness','activity')}${panels(['vo2'])}${H.link('Journal for this day','journal')}${H.footer()}`;
  screens.activity = () => `${header('Activity')}${panels(['steps','energy','total-energy','distance','mvpa','moderate','vigorous','load','vo2'])}${missing('Sessions & strength','No dated workout or strength session is included for this day. Weekly totals are not carried back from the latest snapshot.')}${H.link('Browse workouts','workouts')}${H.footer()}`;
  screens.recovery = () => `${header('Recovery',true)}${H.unavailablePanel('Recovery & readiness','fitness','No saved recovery analysis for this day. A historical score is not inferred from today’s model.')}${panels(['hrv','rhr','breathing','sleep','load'])}${H.link('See the full night','sleep')}${H.footer()}`;
  screens.body = () => `${header('Biological age',true)}${H.unavailablePanel('Estimated biological age','fitness','The preview contains one age-model result, dated 31 July. Historical fitness and sleep inputs remain visible below.')}${panels(['vo2','sleep','regularity'])}${H.evidence('biological_age','Research & method')}${H.footer()}`;
  screens.fitness = () => `${header('Fitness',true)}${panels(['vo2'])}${H.note('Historical method and uncertainty metadata are not supplied with these estimates.')}${panels(['load','mvpa','steps'])}${H.link('Biological-age history','body')}${H.footer()}`;
  screens.insights = () => `${header('Insights')}${missing('Patterns for this day','No archived correlation analysis is included for this date. Explore the measurements available up to this day.')}${panels(['hrv','rhr','efficiency','regularity','vo2','steps'])}${H.link('All measurements','metrics')}${H.footer()}`;
  screens.metrics = () => `${header('Health signals',true)}<p class="history-caption">Readings for ${H.dateLabel()}. A dash means no measurement on that day.</p><div class="metric-list section">${Object.entries(H.metricDefinitions).map(([key,m])=>`<a href="#metric/${key}" data-tone="${m.tone}"><p>${m.title}</p><strong>${H.formatReading(H.dayValue(key))}</strong> <span class="tiny-label">${m.unit}</span></a>`).join('')}</div>${H.footer()}`;
  screens.metric = () => {
    const key=H.route.split('/')[1]||'hrv', m=H.metricDefinitions[key]||H.metricDefinitions.hrv;
    const points=H.historySeries(key), observed=points.filter(p=>p.value!==null).map(p=>p.value);
    return `${header(m.title,true)}<div class="metric-hero"><p>${H.dateLabel(H.viewDate(),true)}</p><div class="hero-number">${H.formatReading(H.dayValue(key))}<span class="unit">${m.unit}</span></div></div>
      ${H.panel('Dated history',m.tone,`${H.historyChart(key,30)}${H.note('Chart ends on the selected day. Gaps stay visible.')}<details class="section"><summary>See dated readings</summary><table class="data-table"><thead><tr><th>Date</th><th>${m.unit}</th></tr></thead><tbody>${points.map(p=>`<tr><td>${H.dateLabel(p.date)}</td><td>${H.formatReading(p.value)}</td></tr>`).join('')}</tbody></table></details>${observed.length?H.note(`Mean ${H.formatReading(observed.reduce((a,b)=>a+b,0)/observed.length)} ${m.unit} · ${observed.length} readings`):''}`)}${H.evidence(m.note,'Source & limitations')}${H.link('Journal for this day','journal')}${H.footer()}`;
  };
  screens.actions = () => `${header('Actions')}${missing('No saved suggestion','This preview has no recommendation saved for '+H.dateLabel()+'. Suggestions from later days are kept on their own date.')}${H.link('Journal for this day','journal')}${H.link('Previous suggestions','action-history')}${H.footer()}`;
  screens['action-history'] = () => `${header('Previous suggestions',true)}${missing('No earlier suggestions','The bundled recommendation is dated 31 July. Choose Latest to review it.')}${H.footer()}`;
  screens.workouts = () => `${header('Workouts',true)}${missing('No session in this sample','No workout is included for '+H.dateLabel()+'. This does not mean you were inactive that day.')}${H.historyPanel('load')}${H.footer()}`;
  screens.journal = () => {
    const entries=H.state.journal.filter(entry=>entry.time.slice(0,10)===H.viewDate());
    const rows=entries.map(entry=>H.row(entry.icon,H.escape(entry.kind),`${H.escape(entry.value)} ${H.escape(entry.unit)} · ${H.escape(entry.time.slice(11))}`,'journal',H.badge('Saved','good'))).join('');
    const bundled=H.isPast()?'':`${H.row('coffee','Morning coffee','80 mg caffeine · sample entry','journal')}${H.row('leaf','A quiet moment','10 minutes meditation · sample entry','journal')}`;
    return `${header('Journal',true)}<div class="journal-grid section">${H.journalKinds.map(([icon,name])=>`<button class="journal-kind" data-action="log" data-kind="${name}">${H.icon(icon)}${name}</button>`).join('')}</div>${H.section('Your moments',rows||bundled?`<div class="card flush">${rows}${bundled}</div>`:missing('No entries for this day','Add a moment of context to your readings.'))}${H.note('Entries stay in this preview tab and reset on reload.')}${H.footer()}`;
  };
  H.screens.journal = screens.journal;
})();
