/* A selected night retains all four checks and its full data, including gaps. */
(() => {
  const localTime = value => value?new Intl.DateTimeFormat('en-GB',{hour:'2-digit',minute:'2-digit',timeZone:'Asia/Kolkata'}).format(new Date(value)):'—';
  const checks = night => {
    const minutes=night.duration_min, efficiency=night.efficiency_pct, sri=night.sri;
    const midpoint=night.midpoint_local?.slice(11,16), hour=midpoint?Number(midpoint.slice(0,2))+Number(midpoint.slice(3))/60:null;
    const rows=[
      ['Duration',H.duration(minutes),'7–9 hours',minutes===null?null:minutes>=420&&minutes<=540,minutes===null?'No duration recorded.':minutes<420?`${420-minutes} minutes below the 7-hour lower reference.`:minutes>540?`${minutes-540} minutes above the 9-hour upper reference.`:'Within the duration reference.'],
      ['Efficiency',H.formatReading(efficiency)+'%','At least 85%',efficiency===null?null:efficiency>=85,efficiency===null?'No efficiency recorded.':efficiency<85?`${(85-efficiency).toFixed(1)} percentage points below the reference.`:'Within the efficiency reference.'],
      ['Regularity · SRI',H.formatReading(sri)+' /100','70 or above',sri===null?null:sri>=70,sri===null?'No regularity reading.':sri<70?`${70-sri} points below the reference.`:'Your sleep rhythm is within the reference.'],
      ['Timing',midpoint||'—','Midpoint 02:00–04:00',hour===null?null:hour>=2&&hour<=4,hour===null?'No midpoint recorded.':hour>=2&&hour<=4?'Your sleep midpoint is within the reference window.':'Your sleep midpoint is outside the reference window.'],
    ];
    return `<ul class="sleep-checks">${rows.map(([name,value,target,passed,detail])=>`<li class="sleep-check ${passed===null?'missing':passed?'met':'short'}"><span class="check-result" role="img" aria-label="${passed===null?'No reading':passed?'Within reference':'Outside reference'}">${passed?H.icon('check','small'):'−'}</span><div class="grow"><div class="row between"><h3>${name}</h3><strong>${value}</strong></div><p class="check-target">${target}</p><p class="check-detail">${detail}</p></div></li>`).join('')}</ul>${H.note('Four independent checks, not a combined score. The 7–9h check differs from the 8h sleep-need reference.')}`;
  };
  const stages = nights => {
    if (!nights.some(n=>n.duration_min!==null)) return H.note('No recorded stage totals in this window.');
    let body='';
    nights.forEach((night,index)=>{
      let total=0;
      ['deep','light','rem','awake'].forEach(stage=>{
        const height=night.stages[stage]/60/10*120; total+=height;
        body+=`<rect x="${12+index*44}" y="${142-total}" width="24" height="${height}" class="stage-${stage}"/>`;
      });
      body+=`<text x="${24+index*44}" y="162" text-anchor="middle">${Number(night.date.slice(8))}</text>`;
    });
    return `<svg class="chart" viewBox="0 0 340 176" role="img" aria-label="Sleep stages through ${H.dateLabel()}">${body}<text x="336" y="26" text-anchor="end">10h</text><text x="336" y="146" text-anchor="end">0</text></svg>`;
  };
  const rhythm = nights => {
    const known=nights.filter(n=>n.start_iso&&n.end_iso);
    if (!known.length) return H.note('Bedtime and wake readings are missing in this window.');
    let chart='';
    nights.forEach((night,index)=>{
      if (night.start_iso&&night.end_iso) {
        const start=localTime(night.start_iso),end=localTime(night.end_iso);
        let onset=Number(start.slice(0,2))+Number(start.slice(3))/60;
        if(onset<18)onset+=24;
        let wake=Number(end.slice(0,2))+Number(end.slice(3))/60;
        while(wake<onset)wake+=24;
        chart+=`<rect x="${20+index*42}" y="${10+(onset-18)*8}" width="14" height="${(wake-onset)*8}" rx="5" fill="var(--sleep)"/>`;
      }
      chart+=`<text x="${27+index*42}" y="156" text-anchor="middle">${Number(night.date.slice(8))}</text>`;
    });
    const plot=`<svg class="chart" viewBox="0 0 340 168" role="img" aria-label="Bedtimes and wake times through ${H.dateLabel()}">${chart}<text x="336" y="14" text-anchor="end">18:00</text><text x="336" y="62" text-anchor="end">00:00</text><text x="336" y="110" text-anchor="end">06:00</text></svg>`;
    return `${plot}<details><summary class="small">See nightly times</summary><table class="data-table"><thead><tr><th>Night ending</th><th>Bedtime → wake</th></tr></thead><tbody>${nights.map(n=>`<tr><td>${H.dateLabel(n.date)}</td><td>${localTime(n.start_iso)} → ${localTime(n.end_iso)}</td></tr>`).join('')}</tbody></table></details>`;
  };
  const stageDetails = night => Object.values(night.stages).some(v=>v>0)?H.sleepStagesTable():H.note('Stage durations were not recorded for this night.');
  H.sleepView = {localTime,checks,stages,rhythm,stageDetails};
})();
