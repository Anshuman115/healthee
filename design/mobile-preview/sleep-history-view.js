/* Date-aware night screens use the shared sleep instruments and checks. */
(() => {
  const {localTime,checks,stages,rhythm,stageDetails}=H.sleepView;
  H.screens.sleep = () => {
    const night=H.currentNight(), week=H.nightsThroughDay(7);
    const naps=H.demo.sleep.naps.filter(n=>(n.date||n.start_iso?.slice(0,10))===H.viewDate());
    return `${H.header('Sleep','')}<div class="sleep-reading"><div><p class="small">Time asleep</p><div class="big-duration">${H.duration(night.duration_min).replace(/([hm])/g,'<small>$1</small>')}</div></div><div class="sleep-device"><strong>${night.zepp_score??'—'}</strong><span>Amazfit score<br>Device estimate</span></div></div>
      <div class="colour-key"><span data-tone="sleep"><i></i>${localTime(night.start_iso)} bedtime</span><span data-tone="movement"><i></i>${localTime(night.end_iso)} wake</span><span>${H.duration(night.tib_min)} in bed</span></div>
      ${H.panel('How your night unfolded','sleep',`${night.stage_timeline.length?H.charts.sleep():H.note('No stage timeline recorded for this night.')}${H.stageLegend()}`,'sleep-history','moon')}
      ${H.panel('Every stage, accounted for','sleep',stageDetails(night),'','moon')}
      ${H.panel('Your body overnight','oxygen',H.overnightVitals(night),'metrics','heart')}
      ${H.panel('Your four sleep checks','sleep',`${checks(night)}${H.evidence('sleep_health_score_multidim','Ranges & evidence')}`,'','moon')}
      ${H.panel('Sleep need & debt','sleep',`${H.value(H.formatReading(H.dayValue('debt')),'min debt',H.dayValue('need')===null?'No saved model for this day':H.duration(H.dayValue('need'))+' need')}${H.isPast()?H.note('Historical sleep-need and debt analyses are not included. The latest debt is not carried backward.'):`<div class="three section">${H.stat('79','%','Sleep performance')}${H.stat('1h 40m','','Nightly gap')}${H.stat('14','','Modelled nights')}</div><div class="progress-track section"><i style="width:79.16%"></i></div>${H.charts.sleepGap()}${H.note('The 8h reference leaves a 1h 40m nightly gap. Debt is a separate 14-night model.')}`}${H.evidence('sleep_need_debt')}`,'','moon')}
      ${H.panel('Your week, stage by stage','sleep',`${stages(week)}${H.stageLegend()}${H.note(`${H.dateLabel(week[0].date)}–${H.dateLabel()} · stage totals can differ from time-asleep estimates.`)}`,'sleep-history','moon')}
      ${H.panel('Sleep timing','sleep',`${rhythm(week)}${H.evidence('sleep_regularity_index','About regularity')}`,'','clock')}
      ${H.chapter('sleep-trends','Beyond a single night','sleep','insights')}${['efficiency','regularity','hrv'].map(key=>H.historyPanel(key)).join('')}
      ${H.panel('Naps & your day','sleep',`${naps.length?naps.map(n=>H.note(`${localTime(n.start_iso)}–${localTime(n.end_iso)} · ${H.duration(n.duration_min)}`)).join(''):H.note('No nap record included for this day.')}${H.link('Journal for this day','journal')}`,'journal','moon')}
      ${H.link('Sleep recommendations','actions')}${H.footer()}`;
  };
  H.screens['sleep-history'] = () => `${H.header('Sleep history','',true)}${H.historyPanel('sleep',30)}${H.panel('Seven nights of stages','sleep',`${stages(H.nightsThroughDay(7))}${H.stageLegend()}`)}${H.section('Open a night',`<div class="card flush">${H.nightsThroughDay(30).reverse().map(n=>`<button class="list-row" data-action="date-night" data-date="${n.date}"><span class="grow"><strong>${H.dateLabel(n.date,true)}</strong><small>${localTime(n.start_iso)} → ${localTime(n.end_iso)}</small></span><strong>${H.duration(n.duration_min)}</strong>${H.icon('chevron')}</button>`).join('')}</div>`)}${H.footer()}`;
  H.actions['date-night'] = element => { H.setViewDate(element.dataset.date); H.navigate('sleep'); };
})();
