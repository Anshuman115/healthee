/* Shared data panels keep colour, units, sources and cross-links consistent. */
(() => {
  H.toneFor = route => ({sleep:'sleep','sleep-history':'sleep',recovery:'fitness',fitness:'fitness',body:'fitness',activity:'movement',workouts:'movement',workout:'heart',route:'movement',record:'movement',challenge:'movement',program:'movement',outcomes:'movement'}[route.split('/')[0]] || (route.startsWith('metric/')?H.metricDefinitions[route.split('/')[1]]?.tone:'fitness') || 'fitness');
  H.currentNight = () => H.demo.sleep.nights[H.state.sleepIndex || 0];
  H.panel = (title,tone,body,route='',icon='activity') => `<section class="panel" data-tone="${tone}"><div class="panel-head"><h3 class="panel-title">${H.icon(icon)}${title}</h3>${route?H.link('Details',route):''}</div>${body}</section>`;
  H.value = (value,unit='',context='') => `<div class="panel-summary"><div class="panel-value">${value}<small>${unit}</small></div>${context?`<p>${context}</p>`:''}</div>`;
  H.note = text => `<p class="panel-note">${text}</p>`;
  H.bridge = (tone,copy,route,label) => `<div class="context-bridge" data-tone="${tone}"><p>${copy} <a href="#${route}">${label} ${H.icon('arrow','small')}</a></p></div>`;
  H.chapter = (id,label,tone,icon) => `<div class="chapter-heading" id="${id}" data-tone="${tone}">${H.icon(icon)}<h2>${label}</h2><span class="grow"></span></div>`;
  H.stageLegend = () => `<div class="chart-legend">${[['deep','Deep'],['light','Light'],['rem','REM'],['awake','Awake']].map(([stage,label])=>`<span><i class="stage-${stage}"></i>${label}</span>`).join('')}</div>`;
  H.bioHero = () => {
    const age=H.demo.today.biological_age;
    return `<section class="bio-hero" data-tone="fitness"><canvas class="bio-art bio-atmosphere" width="640" height="1100" aria-hidden="true"></canvas><div class="bio-eyebrow"><span>Biological age · estimate</span><span class="bio-controls">${H.motionControl()}<a href="#body" aria-label="Understand your biological age">${H.icon('arrow')}</a></span></div><div class="bio-display">${H.charts.bioField()}<div class="age-value">${age.biological_age}<small>years</small></div></div><p class="age-context"><strong>${Math.abs(age.delta_years)} years ${age.delta_years<0?'below':'above'}</strong> your chronological age of ${age.chronological_age}</p>${H.charts.ageScale()}<div class="bio-divider bio-bottom"><a href="#fitness"><span>Fitness contribution</span><strong>−1.7 years ↗</strong></a><a href="#sleep"><span>Sleep contribution</span><strong>0.0 years ↗</strong></a></div><span class="model-label">${H.icon('info','small')}Population-based model · not a clinical age</span></section>`;
  };
  H.recoveryWeights = () => `<div class="weight-stack">${[['sleep',40],['fitness',30],['heart',20],['oxygen',10]].map(([tone,weight])=>`<i data-tone="${tone}" style="flex:${weight}" title="${tone}: ${weight}%"></i>`).join('')}</div><div class="colour-key">${[['sleep','Sleep 40%'],['fitness','HRV 30%'],['heart','RHR 20%'],['oxygen','Breathing 10%']].map(([tone,label])=>`<span data-tone="${tone}"><i></i>${label}</span>`).join('')}</div>`;
  H.recoveryPanel = () => H.panel('Recovery, explained','recovery',`${H.value('72','/100','Overnight estimate<br>36 / 100 remaining')}${H.recoveryWeights()}<div class="factor-bars">${[['Sleep','sleep',60],['HRV','fitness',80],['Resting heart','heart',70],['Breathing','oxygen',75]].map(([label,tone,value])=>`<div class="factor-row" data-tone="${tone}"><span>${label}</span><div class="factor-track"><i style="width:${value}%"></i></div><span>${value}</span></div>`).join('')}</div>${H.note('Model components, not four additional health scores. How you feel and any illness signal take priority.')}`,'recovery','activity');
  H.miniTrend = (title,tone,value,unit,values,limits,route,note,icon='activity') => H.panel(title,tone,`${H.value(value,unit)}${H.charts.line(values,{min:limits[0],max:limits[1],compact:true})}${H.note(note)}`,route,icon);
  H.overnightVitals = (n=H.demo.sleep.nights[0]) => {
    return `<div class="vitals-table">${[
      ['heart','Resting heart',n.rhr,'bpm','heart',H.historySeries('rhr',14).map(p=>p.value),[40,70],'rhr'],
      ['fitness','HRV',n.hrv_sleep_avg,'ms','activity',H.historySeries('hrv',14).map(p=>p.value),[25,65],'hrv'],
      ['oxygen','Blood oxygen',n.spo2_avg??'—','%','drop',H.historySeries('spo2',14).map(p=>p.value),[90,100],'spo2'],
      ['oxygen','Breathing',n.respiratory_rate??'—','/min','activity',H.historySeries('breathing',14).map(p=>p.value),[10,20],'breathing'],
      ['stress','Skin temperature',n.skin_temp_c??'—','°C','sun',H.historySeries('temperature',14).map(p=>p.value),[30,36],'temperature'],
    ].map(([tone,label,value,unit,icon,values,limits,route])=>`<a class="vital-row" data-tone="${tone}" href="#metric/${route}"><span class="vital-label">${H.icon(icon)}${label}</span>${H.charts.line(values,{min:limits[0],max:limits[1],compact:true})}<strong>${value}<small> ${unit}</small></strong></a>`).join('')}</div>`;
  };
  H.sleepStagesTable = () => {
    const stages=H.currentNight().stages, total=Object.values(stages).reduce((a,b)=>a+b,0);
    return `<div class="sleep-strip">${['deep','light','rem','awake'].map(stage=>`<i class="stage-${stage}" style="flex:${stages[stage]}"></i>`).join('')}</div><table class="data-table"><thead><tr><th>Stage</th><th>Duration</th><th>Proportion</th></tr></thead><tbody>${['deep','light','rem','awake'].map(stage=>`<tr><td><i class="swatch stage-${stage}"></i>${stage==='rem'?'REM':stage[0].toUpperCase()+stage.slice(1)}</td><td>${Math.floor(stages[stage]/60)}h ${stages[stage]%60}m</td><td>${(stages[stage]/total*100).toFixed(1)}%</td></tr>`).join('')}</tbody></table>${H.note('Proportions use the supplied stage total. Stage totals and time-asleep estimates can differ.')}`;
  };
  H.readingsTable = (metric) => {
    const start=metric.start || (metric.values.length===1?'31 Jul':(32-metric.values.length)+' Jul'),end=metric.end||'31 Jul';
    const labels=H.chartLabels(metric.values.length,start,end), observed=metric.values.filter(v=>v!==null);
    return `${H.note(`Range ${Math.min(...observed)}–${Math.max(...observed)} ${metric.unit} · ${observed.length} observed samples`)}<details class="section"><summary class="small">See dated readings</summary><table class="data-table"><thead><tr><th>Date / time</th><th>Value · ${metric.unit}</th></tr></thead><tbody>${metric.values.map((value,index)=>`<tr><td>${labels[index]}</td><td>${value??'Not recorded'}</td></tr>`).join('')}</tbody></table></details>`;
  };
  const nightly=H.demo.sleep.nights.slice(0,14).reverse();
  const metrics = [
    ['sleep','Sleep duration','380','min','sleep',nightly.map(n=>n.duration_min),0,600,'sleep_need_debt'],
    ['efficiency','Sleep efficiency','84.4','%','sleep',nightly.map(n=>n.efficiency_pct),60,100,'sleep_health_score_multidim'],
    ['regularity','Sleep regularity','74','SRI','sleep',nightly.map(n=>n.sri),40,100,'sleep_regularity_index'],
    ['temperature','Skin temperature','33.2','°C','stress',nightly.map(n=>n.skin_temp_c),30,36,'recovery_readiness'],
    ['mvpa','Active minutes','32','min','movement',H.demo.today.mvpa.daily.map(p=>p.mvpa_min),0,60,'mvpa_minutes_mortality'],
    ['moderate','Moderate activity','24','min','movement',H.demo.today.mvpa.daily.map(p=>p.moderate_min),0,60,'mvpa_minutes_mortality'],
    ['vigorous','Vigorous activity','4','min','movement',H.demo.today.mvpa.daily.map(p=>p.vigorous_min),0,30,'mvpa_minutes_mortality'],
    ['total-energy','Total energy','2,350','kcal','movement',H.demo.activity.total_calories.trend.map(p=>p.value),0,3500,'energy_expenditure'],
    ['resting-energy','Resting energy','1,730','kcal','movement',[1730],0,2500,'energy_expenditure'],
    ['distance','Distance','6,100','m','movement',H.demo.activity.distance.trend.map(p=>p.value),0,10000,'steps_mortality'],
    ['vo2','VO₂max estimate','43.0','ml/kg/min','fitness',H.demo.today.vo2max.trend_90d.map(p=>p.value),30,55,'vo2max_fitness_mortality'],
    ['recovery','Recovery estimate','72','/100','fitness',[72],0,100,'recovery_readiness'],
    ['debt','Sleep debt','120','min','sleep',[120],0,240,'sleep_need_debt'],
    ['need','Sleep need','480','min','sleep',[480],0,600,'sleep_need_debt'],
    ['sleep-health','Sleep dimension count','3','/4','sleep',H.demo.today.sparklines.sleep_health_score_4dim.map(p=>p.value),0,4,'sleep_health_score_multidim'],
  ];
  metrics.forEach(([key,title,value,unit,tone,values,min,max,note])=>{
    H.metricDefinitions[key]={title,value,unit,tone,values,min,max,note,copy:key==='sleep-health'?'The dimension count returned by the sample backend. It is not a validated composite sleep score. See Sleep for the independent dimensions.':'Source readings shown with their dates and units. Missing days remain gaps; longer history requires your server.',start:(32-values.length)+' Jul',end:'31 Jul'};
  });
  Object.entries({hr:'heart',rhr:'heart',hrv:'fitness',stress:'stress',spo2:'oxygen',breathing:'oxygen',steps:'movement',energy:'movement',weight:'fitness',load:'heart'}).forEach(([key,tone])=>H.metricDefinitions[key].tone=tone);
  H.metricDefinitions.spo2.values=nightly.map(n=>n.spo2_avg);
  document.addEventListener('input',event=>{
    if(!event.target.classList.contains('linked-scrubber'))return;
    const index=Number(event.target.value),hr=H.demo.today.today_hr_series[index],stress=H.demo.today.today_stress_series[index];
    document.querySelector('#linked-readout').innerHTML=`<span data-tone="heart"><i></i>${hr.avg} bpm</span><span data-tone="stress"><i></i>Stress ${stress.avg}</span><span>${hr.hour.toString().padStart(2,'0')}:00</span>`;
    const x=8+index/11*296;document.querySelector('#linked-cursor').setAttribute('d',`M${x} 20V216`);
  });
})();
