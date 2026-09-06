/* One quiet date context follows the reader between data screens. */
(() => {
  H.dateControl = () => {
    const date=H.viewDate(), sleep=H.route.split('/')[0]==='sleep';
    return `<div class="date-navigation" role="group" aria-label="Viewing date"><button data-action="date-previous" aria-label="${sleep?'Previous night':'Previous day'}" ${date===H.history.earliest?'disabled':''}>${H.icon('back')}</button><button class="date-picker-trigger" data-action="date-picker" aria-haspopup="dialog" aria-label="Choose date, ${H.dateLabel(date,true)}"><time datetime="${date}">${H.dateLabel(date,true)}</time><span class="date-caret" aria-hidden="true">⌄</span></button><button data-action="date-next" aria-label="${sleep?'Next night':'Next day'}" ${date===H.history.latest?'disabled':''}>${H.icon('chevron')}</button>${H.isPast()?'<button class="date-latest" data-action="date-latest">Latest</button>':'<span class="date-sample">Sample</span>'}</div>`;
  };
  H.setViewDate = (date,focusAction='date-picker') => {
    if (!H.validDate(date)) return;
    H.state.viewDate=date; H.state.sleepIndex=H.demo.sleep.nights.findIndex(n=>n.date===date);
    const url=new URL(location.href);
    if (date===H.history.latest) url.searchParams.delete('date'); else url.searchParams.set('date',date);
    history.replaceState(history.state,'',url);
    H.closeSheet(); H.render(true);
    const control=document.querySelector(`.date-navigation [data-action="${focusAction}"]:not(:disabled)`) || document.querySelector('.date-picker-trigger');
    control?.focus({preventScroll:true});
  };
  H.openDatePicker = () => {
    const first=H.history.earliest.slice(0,7)+'-01', month=new Date(first+'T12:00:00Z');
    const offset=(month.getUTCDay()+6)%7;
    const count=new Date(Date.UTC(month.getUTCFullYear(),month.getUTCMonth()+1,0)).getUTCDate();
    const buttons=Array.from({length:count},(_,i)=>{
      const date=first.slice(0,8)+String(i+1).padStart(2,'0'), available=H.validDate(date);
      return `<button data-action="date-select" data-date="${date}" aria-label="${H.dateLabel(date,true)}${available?' · readings available':''}" ${date===H.viewDate()?'aria-current="date"':''} ${available?'':'disabled'}>${i+1}${available?'<i aria-hidden="true"></i>':''}</button>`;
    }).join('');
    H.sheet('Choose a day',`<div class="calendar-heading"><strong>${new Intl.DateTimeFormat('en-GB',{month:'long',year:'numeric',timeZone:'UTC'}).format(month)}</strong><button class="text-button" data-action="date-latest">Latest sample ↗</button></div><div class="calendar-week" aria-hidden="true">${['M','T','W','T','F','S','S'].map(d=>`<span>${d}</span>`).join('')}</div><div class="date-calendar" role="group" aria-label="Sample dates">${'<span></span>'.repeat(offset)}${buttons}</div><p class="calendar-help">A dot marks available readings. Some days have partial data. Your selected day follows you between screens.</p>`);
    document.querySelector('.date-calendar [aria-current="date"]')?.focus();
  };
  Object.assign(H.actions,{
    'date-previous':()=>H.setViewDate(H.moveDate(H.viewDate(),-1),'date-previous'),
    'date-next':()=>H.setViewDate(H.moveDate(H.viewDate(),1),'date-next'),
    'date-latest':()=>H.setViewDate(H.history.latest),
    'date-picker':H.openDatePicker,
    'date-select':element=>H.setViewDate(element.dataset.date),
  });
  document.addEventListener('keydown',event=>{
    if (!event.target.matches('.date-calendar button')) return;
    const offsets={ArrowLeft:-1,ArrowRight:1,ArrowUp:-7,ArrowDown:7};
    if (!(event.key in offsets)) return;
    event.preventDefault();
    const date=H.moveDate(event.target.dataset.date,offsets[event.key]);
    document.querySelector(`.date-calendar [data-date="${date}"]:not(:disabled)`)?.focus();
  });
})();
