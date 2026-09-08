/* Additional instruments mirror the mobile app's data views. Geometry uses source values. */
(() => {
  const svg = (body,label,height=170) => `<svg class="chart" viewBox="0 0 340 ${height}" role="img" aria-label="${label}">${body}</svg>`;
  const text = (x,y,label,anchor='start',className='') => `<text x="${x}" y="${y}" text-anchor="${anchor}" class="${className}">${label}</text>`;
  const line = points => points.map((point,index)=>`${index?'L':'M'}${point.join(',')}`).join(' ');
  H.charts.bioField = () => '<canvas class="bio-art bio-halo" width="640" height="640" aria-hidden="true"></canvas>';
  H.charts.ageScale = () => {
    const age=H.demo.today.biological_age, x=value=>16+(value-28)/16*308;
    return svg(`${Array.from({length:33},(_,i)=>`<path d="M${16+i*9.625} ${i%4===0?8:15}v${i%4===0?19:12}" stroke="var(--bio-line)"/>`).join('')}<path d="M${x(age.biological_age)} 0V31" stroke="var(--bio-ink)" stroke-width="2"/><circle cx="${x(age.chronological_age)}" cy="18" r="3" fill="var(--bio-ink)"/>${[28,32,36,40,44].map(v=>text(x(v),46,v,'middle')).join('')}`,'Age scale: estimated 34.3 years compared with chronological age 36.',52);
  };
  H.charts.ageWaterfall = () => {
    const age=H.demo.today.biological_age, low=30, high=38, y=v=>145-(v-low)/(high-low)*126;
    const entries=[{label:'Actual',from:low,to:age.chronological_age,tone:'oxygen'},...age.contributions.map((c,index)=>({label:c.term==='fitness'?'Fitness':'Sleep',from:index?age.chronological_age+age.contributions[0].delta_years:age.chronological_age,to:age.chronological_age+age.contributions.slice(0,index+1).reduce((a,b)=>a+b.delta_years,0),tone:c.term==='fitness'?'fitness':'sleep',delta:c.delta_years})),{label:'Estimate',from:low,to:age.biological_age,tone:'fitness'}];
    let body=[30,32,34,36,38].map(v=>`<path class="gridline" d="M4 ${y(v)}H310"/>${text(338,y(v)+3,v,'end')}`).join('');
    entries.forEach((entry,i)=>{
      const x=12+i*77, top=y(Math.max(entry.from,entry.to)),height=Math.max(3,Math.abs(y(entry.from)-y(entry.to)));
      body+=`<g data-tone="${entry.tone}"><rect x="${x}" y="${top}" width="42" height="${height}" rx="5" fill="var(--family)"/>${text(x+21,top-7,entry.delta!==undefined?(entry.delta>0?'+':'')+entry.delta+'y':entry.to,'middle','chart-point-label')}${text(x+21,166,entry.label,'middle')}</g>`;
      if(i<3)body+=`<path class="baseline-line" d="M${x+42} ${y(entry.to)}h35"/>`;
    });
    return svg(body,'Age estimate: chronological age 36, fitness contribution minus 1.7 years, sleep contribution zero, estimate 34.3.',176);
  };
  H.charts.sleepWeek = () => {
    const nights=H.demo.today.sleep_history_7d;
    let body=[0,4,8].map(v=>`<path class="gridline" d="M4 ${142-v/10*120}H310"/>${text(337,146-v/10*120,v+'h','end')}`).join('');
    nights.forEach((night,index)=>{
      let total=0;
      ['deep','light','rem','awake'].forEach(stage=>{
        const height=night[stage]/60/10*120; total+=height;
        body+=`<rect x="${12+index*44}" y="${142-total}" width="24" height="${height}" class="stage-${stage}"/>`;
      });
      body+=text(24+index*44,162,night.date.slice(8),'middle');
    });
    return svg(body,'Seven nights of sleep stage totals: deep, light, REM and awake, 25–31 July.',174);
  };
  H.charts.sleepGap = () => {
    const nights=H.demo.today.sleep_history_7d, need=H.demo.today.sleep_debt.need_min;
    const y=v=>135-v/600*114;
    let body=`<path class="baseline-line" d="M5 ${y(need)}H307"/>${text(338,y(need)+3,'8h','end')}${text(338,139,'0','end')}`;
    nights.forEach((night,i)=>{
      body+=`<rect x="${12+i*44}" y="${y(need)}" width="24" height="${y(night.duration_min)-y(need)}" fill="var(--family-soft)" stroke="var(--family)" stroke-dasharray="2 3" rx="3"/><rect x="${12+i*44}" y="${y(night.duration_min)}" width="24" height="${135-y(night.duration_min)}" fill="var(--family)" rx="3"/>${text(24+i*44,157,night.date.slice(8),'middle')}`;
    });
    return svg(body,'Nightly time asleep against an eight-hour reference. Each sample night is 100 minutes below the reference.',168);
  };
  H.charts.vo2 = () => {
    const estimate=H.demo.today.vo2max, x=v=>16+(v-30)/25*300;
    return svg(`<path class="gridline" d="M16 60H316"/><rect x="${x(estimate.estimate-estimate.see_ml_kg_min)}" y="42" width="${x(estimate.estimate+estimate.see_ml_kg_min)-x(estimate.estimate-estimate.see_ml_kg_min)}" height="36" fill="var(--family-soft)" rx="8"/><path d="M${x(estimate.median_for_age)} 28V91" class="baseline-line"/><circle cx="${x(estimate.estimate)}" cy="60" r="6" fill="var(--family)"/>${text(x(estimate.estimate),23,estimate.estimate.toFixed(1),'middle','rail-value')}${[30,35,40,45,50,55].map(v=>text(x(v),112,v,'middle')).join('')}`,'VO₂max estimate 43, reference median 39.7, illustrative extent of supplied error magnitude plus or minus 2.95 ml/kg/min. Not a confidence interval.',125);
  };
  H.charts.dayTogether = () => {
    const hr=H.demo.today.today_hr_series,stress=H.demo.today.today_stress_series;
    const x=i=>8+i/(hr.length-1)*296;
    let body='';
    [['heart','Heart rate',hr,40,140,26,102],['stress','Stress',stress,0,100,140,216]].forEach(([tone,label,data,min,max,top,bottom])=>{
      const points=data.map((p,i)=>[x(i),bottom-(p.avg-min)/(max-min)*(bottom-top)]);
      body+=`<g data-tone="${tone}">${text(8,top-10,label)}<path class="gridline" d="M8 ${bottom}H304"/>${text(338,top+3,max,'end')}${text(338,bottom+3,min,'end')}<path d="${line(points)}L304 ${bottom}H8Z" fill="var(--family-soft)"/><path d="${line(points)}" fill="none" stroke="var(--family)" stroke-width="2.2" stroke-linejoin="round"/></g>`;
    });
    body+=`<path id="linked-cursor" d="M304 20V216" class="baseline-line"/>${text(8,238,'06:00')}${text(304,238,'17:00','end')}`;
    return `<div class="linked-chart">${svg(body,'Heart rate and stress aligned by hour, each with its own scale. Drag to inspect matching samples.',248)}<label class="tiny-label">Compare the same moment<input class="linked-scrubber" type="range" min="0" max="11" value="11" aria-label="Compare heart rate and stress by hour"></label><output id="linked-readout" class="colour-key"><span data-tone="heart"><i></i>68 bpm</span><span data-tone="stress"><i></i>Stress 50</span><span>17:00</span></output></div>`;
  };
  H.charts.load = () => H.charts.bars(H.demo.activity.cardio_load.trend_30d.slice(-14).map(p=>p.value),{max:100,labels:['18','','20','','22','','24','','26','','28','','30','31'],target:55,label:'Cardiovascular load for 18–31 July. Sample load is 55 TRIMP each day; reference 55.'});
})();
