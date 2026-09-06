/* A complete night: timing, stages, physiology, need and the longer rhythm. */
(() => {
  const nightRange = () => H.demo.sleep.nights.slice(H.state.sleepIndex||0,(H.state.sleepIndex||0)+14).reverse();
  const dimensions = () => {
    const night=H.currentNight();
    const checks=[
      {name:'Duration',value:'6h 20m',target:'7–9 hours',passed:night.duration_min>=420&&night.duration_min<=540,detail:'40 minutes below the 7-hour lower reference.'},
      {name:'Efficiency',value:night.efficiency_pct+'%',target:'At least 85%',passed:night.efficiency_pct>=85,detail:'0.6 percentage points below the reference.'},
      {name:'Regularity · SRI',value:night.sri+' /100',target:'70 or above',passed:night.sri>=70,detail:'Your sample sleep rhythm is within the reference.'},
      {name:'Timing',value:'02:45',target:'Midpoint 02:00–04:00',passed:true,detail:'Your sleep midpoint is within the reference window.'},
    ];
    return `<ul class="sleep-checks">${checks.map(check=>`<li class="sleep-check ${check.passed?'met':'short'}"><span class="check-result" role="img" aria-label="${check.passed?'Within reference':'Below reference'}">${check.passed?H.icon('check','small'):'<span aria-hidden="true">−</span>'}</span><div class="grow"><div class="row between"><h3>${check.name}</h3><strong>${check.value}</strong></div><p class="check-target">${check.target}</p><p class="check-detail">${check.detail}</p></div></li>`).join('')}</ul>${H.note('Four independent checks, not a combined score. The duration check uses the 7–9h range; your sleep-need model uses its 8h midpoint.')}`;
  };
  const trends = () => {
    const nights=nightRange();
    return `<div class="twin-panels">${H.miniTrend('Efficiency','sleep','84.4','%',nights.map(n=>n.efficiency_pct),[60,100],'metric/efficiency',`${nights.length} nights · reference ≥85%`,'moon')}${H.miniTrend('Regularity','sleep','74','SRI',nights.map(n=>n.sri),[40,100],'metric/regularity',`${nights.length} nights · reference ≥70`,'moon')}</div>${H.panel('Overnight HRV trend','fitness',`${H.value('45','ms',`${nights.length} nights<br>Personal baseline: 45`)}${H.charts.line(nights.map(n=>n.hrv_sleep_avg),{min:25,max:65,baseline:45,start:parseInt(nights[0].date.slice(8))+' Jul',end:parseInt(nights.at(-1).date.slice(8))+' Jul',unit:'ms',label:'Overnight HRV'})}`,'metric/hrv')}`;
  };
  H.screens.sleep = () => {
    const night=H.currentNight(), index=H.state.sleepIndex||0;
    return `${H.header('Your night,<br>in detail.','Sleep · wearable estimates')}
      <div class="date-controls"><button class="icon-button" data-action="sleep-previous" aria-label="Previous night" ${index>=H.demo.sleep.nights.length-1?'disabled':''}>${H.icon('back')}</button><span>Night ending ${parseInt(night.date.slice(8))} July</span><button class="icon-button" data-action="sleep-next" aria-label="Next night" ${index===0?'disabled':''}>${H.icon('chevron')}</button></div>
      <div class="sleep-reading"><div><p class="small">Time asleep</p><div class="big-duration">6<small>h</small> 20<small>m</small></div></div><div class="sleep-device"><strong>${night.zepp_score}</strong><span>Amazfit score<br>Device estimate</span></div></div>
      <div class="colour-key"><span data-tone="sleep"><i></i>23:00 bedtime</span><span data-tone="movement"><i></i>06:30 wake</span><span>7h 30m in bed</span></div>
      ${H.panel('How your night unfolded','sleep',`${H.charts.sleep()}${H.stageLegend()}${H.note('Estimated stages from the strap. Time on this chart is elapsed time in bed.')}`,'sleep-history','moon')}
      ${H.panel('Every stage, accounted for','sleep',H.sleepStagesTable(),'','moon')}
      ${H.bridge('sleep','Stages describe the night. HRV, heart rate and breathing show what your body recorded alongside it.','recovery','Follow into recovery')}
      ${H.panel('Your body overnight','oxygen',`${H.overnightVitals(night)}${H.note('Sparklines show recent nights. Missing readings remain gaps; no reading is treated as zero.')}`,'metrics','heart')}
      ${H.panel('Your four sleep checks','sleep',`${dimensions()}${H.evidence('sleep_health_score_multidim','Ranges & evidence')}`,'','moon')}
      ${H.panel('What you slept. What you needed.','sleep',`${H.value('79','% of reference','6h 20m asleep<br>8h age-based need')}<div class="progress-track"><i style="width:79.16%"></i></div><div class="three section">${H.stat('1h 40m','','Nightly gap')}${H.stat('2','h','Modelled debt')}${H.stat('14','','Debt window')}</div>${H.charts.sleepGap()}${H.note('25–31 July · filled bars are time asleep; outlined space is the gap to 8h. Debt is a separate 14-night model.')}${H.evidence('sleep_need_debt')}`,'','moon')}
      ${H.panel('Your week, stage by stage','sleep',`${H.charts.sleepWeek()}${H.stageLegend()}${H.note('25–31 July sample week. See whether stage proportions change without losing total duration.')}`,'sleep-history','moon')}
      ${H.panel('A rhythm you can see','sleep',`${H.value('74','SRI','Bedtime 23:00<br>Wake time 06:30')}${H.charts.consistency()}<div class="three">${H.stat('0','min','Onset variation')}${H.stat('0','min','Wake variation')}${H.stat('7','','Sample nights')}</div>${H.note('All seven sample nights have the same bedtime and wake time.')}${H.evidence('sleep_regularity_index','About regularity')}`,'','clock')}
      ${H.chapter('sleep-trends','Beyond a single night','sleep','insights')}${trends()}
      ${H.bridge('sleep','Caffeine and sleep are associated in the sample history. Review timing and context before drawing a conclusion.','insight','Explore the pattern')}
      ${H.section('Naps & the rest of your day',`<div class="card flush">${H.row('moon','Afternoon nap','31 Jul · 14:00–14:35 · 35 minutes','sleep-history')}${H.row('journal','What happened before bed?','Add caffeine, alcohol or how you felt','journal')}</div>`)}
      ${H.panel('Tonight, build on what you know','sleep',`<h3>Give sleep a little more room.</h3>${H.note('The sample’s time asleep is below its age-based reference. Start with a bedtime and wind-down you can keep.')}${H.link('Set your wind-down','reminders')}`,'actions','moon')}${H.footer()}`;
  };
  H.screens['sleep-history'] = () => `${H.header('A longer view<br>of your nights.','Sleep history · July sample',true)}${H.panel('Seven nights of stages','sleep',`${H.charts.sleepWeek()}${H.stageLegend()}`,'','moon')}${H.panel('Fourteen nights of duration','sleep',`${H.charts.bars(H.demo.sleep.nights.slice(0,14).reverse().map(n=>n.duration_min/60),{max:10,labels:['18','','20','','22','','24','','26','','28','','30','31'],unit:'h',label:'Fourteen nights of sleep duration'})}`,'metric/sleep','moon')}${H.section('Open a night',`<div class="card flush">${H.demo.sleep.nights.slice(0,14).map((night,index)=>`<button class="list-row" data-action="select-night" data-value="${index}"><span class="icon-tile">${H.icon('moon')}</span><span class="grow"><strong>${parseInt(night.date.slice(8))} July</strong><small>23:00 → 06:30</small></span><strong>6h 20m</strong>${H.icon('chevron')}</button>`).join('')}</div>`)}${H.footer()}`;
})();
