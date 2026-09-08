/* Movement, trends and their detail routes share chart and reading components. */
(() => {
  H.screens.workouts = () => `${H.header('Your workouts.','Activity history',true)}${H.link('Record a workout','record','button full')}<div class="section"><p class="tiny-label">Friday, 31 July</p>
    <div class="card flush section workout-row">${H.row('walk','Morning run','30 min · 4.2 km · 135 bpm avg','workout')}${H.row('location','GPS recording','9m 30s · 0.3 km · sample route','route')}</div></div>
    ${H.section('Weekly strength',`
    <div class="card">${H.stat('45','min','Recorded strength activity')}<p class="small section">One session in the sample week. Strength sessions are shown separately from active minutes.</p>${H.evidence('strength_training_mortality')}</div>`)}
    ${H.footer()}`;
  H.screens.workout = () => `${H.header('Morning run.','31 July · 07:00',true)}
    <div class="card"><div class="three">${H.stat('4.2','km','Distance')}${H.stat('30','min','Duration')}${H.stat('7:09','/km','Avg. pace')}</div>${H.source('Helio Strap · recorded workout')}</div>
    ${H.section('Your effort through the run',`
    <div class="card"><div class="row between">${H.stat('135','bpm','Average heart rate')}${H.badge('Peak 168 bpm')}</div>${H.charts.line(H.demo.workout.hr_series.map(p=>p.hr),{min:60,max:180,start:'07:00',end:'07:30',label:'Workout heart rate'})}<p class="small">Minute averages. Brief low readings remain visible in this sample.</p></div>`)}
    ${H.section('Time in heart-rate zones',`
    <div class="card"><div class="factor-bars">${H.demo.workout.zones.map((minutes,index)=>`<div class="factor-row"><span>Zone ${index+1}</span><div class="factor-track"><i style="width:${minutes/30*100}%"></i></div><span>${minutes}m</span></div>`).join('')}</div><p class="small">28 minutes classified; unclassified minutes aren’t assigned to a zone.</p>${H.evidence('cardio_load_trimp','About training load')}</div>`)}
    ${H.section('Session details',`
    <div class="card"><div class="two">${H.stat('250','kcal','Estimated energy')}${H.stat('36.9','','TRIMP load')}${H.stat('8.4','km/h','Average speed')}${H.stat('10','bpm','Heart-rate drift')}</div></div>`)}${H.link('Discuss this workout','coach','button secondary full section')}
    ${H.footer()}`;
  H.metricDefinitions = {
    hr: { title:'Heart rate',value:'68',unit:'bpm',min:40,max:140,values:H.demo.today.today_hr_series.map(p=>p.avg),start:'06:00',end:'17:00',note:'recovery_readiness',copy:'The hourly average gives your day a shape. A workout, movement and rest can all appear in this trace.' },
    hrv: { title:'Heart-rate variability',value:'45',unit:'ms',min:25,max:65,baseline:45,values:H.demo.today.sparklines.hrv_sleep_avg.map(p=>p.value),note:'hrv_recovery',copy:'Look at changes against your own recent pattern. A single night rarely tells the whole story.' },
    rhr: { title:'Resting heart rate',value:'55',unit:'bpm',min:40,max:70,baseline:55,values:H.demo.today.sparklines.rhr_daily.map(p=>p.value),note:'resting_heart_rate',copy:'Your overnight resting heart rate is most useful in context with sleep, activity and your own baseline.' },
    stress: { title:'Stress',value:'50',unit:'/100',min:0,max:100,values:H.demo.today.today_stress_series.map(p=>p.avg),start:'06:00',end:'17:00',note:'hrv_recovery',copy:'This is a device-derived estimate. It cannot tell us whether a demanding moment felt positive or difficult.' },
    spo2: { title:'Blood oxygen',value:'97',unit:'%',min:90,max:100,values:[97,97,97,97,97,97,97],note:'sleep_health_score_multidim',copy:'An overnight average from the strap, not a diagnostic measurement. Fit and movement can affect readings.' },
    breathing: { title:'Breathing rate',value:'14',unit:'/min',min:10,max:20,values:H.demo.today.sparklines.respiratory_rate_sleep.map(p=>p.value),note:'recovery_readiness',copy:'Breaths per minute during sleep. Changes matter in the context of your other overnight signals.' },
    steps: { title:'Steps',value:'8,200',unit:'steps',min:0,max:12000,values:H.demo.activity.steps.trend.map(p=>p.value),note:'steps_mortality',copy:'Daily movement, including the ordinary walks between the rest of your life.' },
    weight: { title:'Weight',value:'72.5',unit:'kg',min:65,max:80,values:[72.5],note:'body_composition',copy:'A dated journal entry. Changes in body weight need a series of comparable readings, not a single measurement.' },
    load: { title:'Training load',value:'55',unit:'TRIMP',min:0,max:100,values:H.demo.activity.cardio_load.trend_30d.map(p=>p.value),note:'cardio_load_trimp',copy:'A model of cardiovascular effort. The 7-day and 28-day averages are both 55 in this sample; the ratio is 1.0.' },
    energy: { title:'Active energy',value:'620',unit:'kcal',min:0,max:1000,values:H.demo.activity.active_calories.trend.map(p=>p.value),note:'energy_expenditure',copy:'Estimated energy from activity. This is not a direct measurement of calories burned.' },
  };
  H.screens.metrics = () => `${H.header('Your health signals.','Explore your measurements',true)}<p class="small">A reading is a starting point. Open one to see its history, context and source.</p><div class="metric-list section">${Object.entries(H.metricDefinitions).map(([key,m])=>`<a href="#metric/${key}" data-tone="${m.tone || 'fitness'}"><p>${m.title}</p><strong>${m.value}</strong> <span class="tiny-label">${m.unit}</span></a>`).join('')}</div>
    <div class="card flush section">${H.row('moon','Sleep history','Duration, stages and regularity','sleep-history')}${H.row('activity','Fitness estimates','VO₂max and biological age','fitness')}</div>
    ${H.footer()}`;
  H.screens.metric = () => {
    const key = H.route.split('/')[1] || 'hrv', metric = H.metricDefinitions[key] || H.metricDefinitions.hrv;
    const long = H.state.range !== '30d';
    const values = metric.values;
    const observed=values.filter(v=>v!==null), sorted=[...observed].sort((a,b)=>a-b);
    const median=(sorted[Math.floor((sorted.length-1)/2)]+sorted[Math.ceil((sorted.length-1)/2)])/2;
    return `${H.header(`${metric.title}.`,'Your personal trend',true)}
    <div class="metric-hero"><p>Latest · 31 July</p><div class="hero-number">${metric.value}<span class="unit">${metric.unit}</span></div><p class="section">${metric.copy}</p></div><div class="section">${H.segment([['30d','30 days'],['90d','90 days'],['1y','1 year'],['5y','5 years']],H.state.range,'range')}</div>${long ? H.notice('A longer view needs your server','This preview includes July samples only. The chart stays labelled with the dates it actually shows.') : ''}
    <div class="card section">${H.charts.line(values,{...metric,label:metric.title,start:metric.start || (values.length===1?'31 Jul':values.length===7?'25 Jul':values.length===14?'18 Jul':'2 Jul'),end:metric.end || '31 Jul'})}${metric.baseline ? '<div class="chart-legend"><span>Dashed line · personal median</span></div>' : ''}<div class="three section">${H.stat((observed.reduce((a,b)=>a+b,0)/observed.length).toFixed(1),'','Mean')}${H.stat(median.toFixed(1),'','Median')}${H.stat((observed.at(-1)-observed[0]).toFixed(1),'','Change')}</div>${H.readingsTable(metric)}</div>
    ${H.section('Put this in context',`
    <div class="card flush">${H.row('journal','Your journal','See what was happening alongside the data','journal')}${H.row('coach','Ask about this trend','Explore the reading with your coach','coach')}</div>`)}${H.evidence(metric.note,'Source & limitations')}${H.source()}
    ${H.footer()}`;
  };
  H.screens.insight = () => `${H.header('Coffee & your sleep.','A pattern in the sample history',true)}${H.badge('Observational · 24 samples','indigo')}<div class="observation"><h3>They moved together.<br>That doesn’t tell us why.</h3><p>Caffeine logs were negatively associated with the sleep measure used in this analysis. Timing, stressful days and other habits could be part of the picture.</p></div>
    <div class="card section"><div class="two">${H.stat('−0.42','','Correlation · ρ')}${H.stat('24','','Paired observations')}</div><hr class="divider"><p class="small">Adjusted q-value 0.03 · same-day association</p><p class="small section">The sample response contains a summary, not the underlying paired values. A scatter plot appears here when those values are available.</p></div>
    ${H.section('A useful next step',`
    <div class="focus-card"><h3>Notice the timing of your coffee.</h3><p>Log when you have it and how your night feels. A little more context can help you explore this pattern.</p>${H.link('Log a coffee','journal')}</div>`)}${H.evidence('caffeine_sleep','Read the evidence')}${H.link('Talk this through','coach','button secondary full section')}
    ${H.footer()}`;
  H.screens.route = () => `${H.header('Your recorded route.','31 July · saved workout',true)}${H.charts.route()}
    <div class="card section"><div class="three">${H.stat('0.3','km','Distance')}${H.stat('9:30','','Duration')}${H.stat('32:12','/km','Avg. pace')}</div>${H.source('Phone GPS · 20 sample fixes')}</div>
    ${H.section('Elevation along the way',`
    <div class="card">${H.charts.line(H.demo.gps_detail.points.map(p=>p.ele),{label:'Route elevation',unit:'m',min:894,max:900,start:'Start',end:'Finish'})}<div class="two">${H.stat('2','m','Elevation gain')}${H.stat('5','m','Elevation loss')}</div></div>`)}
    ${H.notice('Not enough heart-rate coverage','This route has one matched heart-rate point. A fitness estimate is withheld until coverage is sufficient.')}${H.link('Record another route','record','button secondary full')}
    ${H.footer()}`;
  H.screens.record = () => `${H.header('Out for a little movement.','Outdoor workout',true)}${H.charts.route()}<div class="record-reading"><p class="small">${H.state.recording ? 'Demo recording in progress' : 'Ready when you are'}</p><div class="hero-number" id="record-timer">${H.formatTime(H.state.seconds)}</div><p class="small">${H.state.recording ? 'Timer only · no location collected' : 'Try the flow with a sample route'}</p></div><div class="three center">${H.stat('—','km','Distance')}${H.stat('—','/km','Pace')}${H.stat('0','','GPS fixes')}</div><div class="section">${H.button(H.state.recording ? 'Finish demo' : 'Start demo',H.state.recording ? 'record-stop' : 'record-start','full',H.state.recording ? 'stop' : 'play')}</div><p class="form-note center">This HTML preview never requests location or records a real workout.</p>${H.link('View saved route','route','button secondary full')}`;
})();
