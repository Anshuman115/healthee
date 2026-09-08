/* Dated source readings are kept separate from the latest analysis snapshot. */
(() => {
  const nights = [...H.demo.sleep.nights].reverse();
  const nightly = key => nights.map(n => ({date:n.date,value:n[key]??null}));
  const activity = H.demo.activity, today = H.demo.today;
  const latest = today.date;
  const one = value => [{date:latest,value}];
  H.history = {
    latest, earliest:nights[0].date,
    routes:new Set(['today','sleep','activity','insights','actions','recovery','body','fitness','metrics','metric','sleep-history','workouts','journal','action-history']),
    series:{
      hrv:nightly('hrv_sleep_avg'), rhr:nightly('rhr'), sleep:nightly('duration_min'),
      efficiency:nightly('efficiency_pct'), regularity:nightly('sri'), temperature:nightly('skin_temp_c'),
      spo2:nightly('spo2_avg'), breathing:nightly('respiratory_rate'), 'sleep-health':nightly('score'),
      steps:activity.steps.trend, energy:activity.active_calories.trend,
      'total-energy':activity.total_calories.trend, distance:activity.distance.trend,
      load:activity.cardio_load.trend_30d, vo2:today.vo2max.trend_90d,
      mvpa:today.mvpa.daily.map(p=>({date:p.date,value:p.mvpa_min})),
      moderate:today.mvpa.daily.map(p=>({date:p.date,value:p.moderate_min})),
      vigorous:today.mvpa.daily.map(p=>({date:p.date,value:p.vigorous_min})),
      recovery:one(today.recovery_score.recovery), debt:one(today.sleep_debt.debt_min),
      need:one(today.sleep_debt.need_min), 'resting-energy':one(1730), weight:one(H.demo.profile.weight_kg),
      hr:one(today.today_hr_series.at(-1).avg), stress:one(today.today_stress_series.at(-1).avg),
    },
  };
  H.validDate = date => /^\d{4}-\d{2}-\d{2}$/.test(date||'') && date>=H.history.earliest && date<=latest && new Date(date+'T12:00:00Z').toISOString().slice(0,10)===date;
  const requested = new URLSearchParams(location.search).get('date');
  H.state.viewDate = H.validDate(requested) ? requested : latest;
  H.viewDate = () => H.state.viewDate;
  H.isPast = () => H.viewDate()!==latest;
  H.syncViewDate = () => {
    const requested=new URLSearchParams(location.search).get('date');
    const date=H.validDate(requested)?requested:latest, changed=date!==H.viewDate();
    H.state.viewDate=date; H.state.sleepIndex=H.demo.sleep.nights.findIndex(n=>n.date===date);
    return changed;
  };
  H.dateLabel = (date=H.viewDate(),long=false) => new Intl.DateTimeFormat('en-GB',{day:'numeric',month:long?'long':'short',timeZone:'UTC'}).format(new Date(date+'T12:00:00Z'));
  H.moveDate = (date,offset) => { const value=new Date(date+'T12:00:00Z'); value.setUTCDate(value.getUTCDate()+offset); return value.toISOString().slice(0,10); };
  H.historySeries = (key,limit=30) => (H.history.series[key]||[]).filter(p=>p.date<=H.viewDate()).slice(-limit);
  H.dayValue = key => H.history.series[key]?.find(p=>p.date===H.viewDate())?.value??null;
  H.formatReading = value => value===null||value===undefined?'—':Number(value).toLocaleString('en-GB',{maximumFractionDigits:1});
  H.duration = value => value===null||value===undefined?'—':`${Math.floor(value/60)}h ${Math.round(value%60)}m`;
  H.currentNight = () => H.demo.sleep.nights.find(n=>n.date===H.viewDate());
  H.nightsThroughDay = (limit=14) => nights.filter(n=>n.date<=H.viewDate()).slice(-limit);
  H.state.sleepIndex = H.demo.sleep.nights.findIndex(n=>n.date===H.viewDate());
  H.historyChart = (key,limit=14) => {
    const metric=H.metricDefinitions[key], points=H.historySeries(key,limit);
    if (!points.some(p=>p.value!==null)) return H.note('No readings in this date window.');
    return H.charts.line(points.map(p=>p.value),{min:metric.min,max:metric.max,unit:metric.unit,label:metric.title,start:H.dateLabel(points[0].date),end:H.dateLabel(points.at(-1).date)});
  };
  H.historyPanel = (key,limit=14) => {
    const metric=H.metricDefinitions[key], points=H.historySeries(key,limit), value=H.dayValue(key);
    return H.panel(metric.title,metric.tone,`${H.value(H.formatReading(value),metric.unit,value===null?'No reading on this day':H.dateLabel())}${H.historyChart(key,limit)}${H.note(points.length?`${points.length} dated samples through ${H.dateLabel()}.`:'No dated samples before this day.')}`,`metric/${key}`);
  };
  H.unavailablePanel = (title,tone,copy='No saved result for this day in the preview.') => H.panel(title,tone,`${H.value('—')}${H.note(copy)}`);
})();
