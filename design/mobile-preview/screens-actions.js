/* Actions, journal and coach use local demo state; nothing is submitted to a health backend. */
(() => {
  H.journalKinds = [
    ['coffee','Caffeine','mg','80'],['drop','Water','ml','250'],['smile','Mood','1–5',''],
    ['leaf','Meditation','minutes','10'],['walk','Exercise','minutes','30'],['weight','Weight','kg',''],
    ['moon','Alcohol','drinks','1'],['clock','Fasting','start / end',''],['check','Habit','note',''],
    ['heart','Symptoms','note',''],
  ];
  const activeChallenge = () => `<a href="#challenge" class="challenge-card" data-tone="movement"><div class="row between">${H.badge('Movement','indigo')}<span class="tiny-label">7-day challenge</span></div><h3>Seven days above ${(H.state.target || 9000).toLocaleString('en-IN')}.</h3><p>A small step up from your recent 8,200-step average.</p><div class="progress-track"><i style="width:${Math.min(100,8200/(H.state.target || 9000)*100)}%"></i></div><div class="row between"><span class="tiny-label">8,200 / ${(H.state.target || 9000).toLocaleString('en-IN')} today</span>${H.icon('arrow','small')}</div></a>`;
  const programCard = () => `
    <div class="card flush">${H.row('flag','Build a walking rhythm',H.state.program ? 'Your active program · week 3 of 4' : 'A four-week program, at your pace','program')}</div>`;
  H.screens.actions = () => `${H.header('Small steps.<br>Your pace.','Actions that fit your life')}
    <div class="focus-card" data-tone="sleep"><div class="row between"><span class="focus-title">Today’s suggestion</span>${H.icon('moon','small')}</div><h3>Sleep earlier tonight.</h3><p>Your sample history has 2 hours of modelled sleep debt. Make space for your next night.</p><button class="check-action" data-action="adopt" aria-pressed="${H.state.adopted}"><span class="checkbox">${H.state.adopted ? H.icon('check','small') : H.icon('plus','small')}</span><span class="grow"><strong>${H.state.adopted ? 'Added to your intentions' : 'I’ll try this tonight'}</strong><small>${H.state.adopted ? 'An intention, not a completed action.' : 'One manageable change to start with.'}</small></span></button>${H.evidence('sleep_need_debt','Why this suggestion')}</div>
    ${H.section('What you’re working on',`<div class="stack">${H.state.challengeEnded ? H.notice('A little space for what’s next','Your sample challenge has ended. You can explore a new one when you’re ready.') : activeChallenge()}${programCard()}</div>`)}
    ${H.section('Your daily check-in',`<div class="journal-strip"><div><h3>There’s more to your day.</h3><p>Coffee, a walk, how you felt.</p></div><a class="icon-button filled" href="#journal" aria-label="Open journal">${H.icon('plus')}</a></div>`)}
    ${H.section('Look back, learn a little',`
    <div class="card flush">${H.row('insights','What changed?','Review outcomes without jumping to conclusions','outcomes')}${H.row('clock','Previous suggestions','Your intentions and action history','action-history')}</div>`)}
    ${H.footer()}`;
  H.screens.challenge = () => `${H.header('A little more walking.','Your 7-day challenge',true)}${H.badge(H.state.challengeEnded ? 'Ended in preview' : 'Active · movement','indigo')}
    <div class="sleep-hero section"><p class="small">Daily target</p><div class="hero-number">${(H.state.target || 9000).toLocaleString('en-IN')}<span class="duration-unit">steps</span></div><p class="small">A step up from your usual 8,200.</p></div>
    <div class="card"><div class="row between"><h3>Your week</h3><span class="tiny-label">25–31 July</span></div><div class="weekly-days">${['S','S','M','T','W','T','F'].map((day,index)=>`<div class="day">${day}<span class="${index===6?'current':''}">${index+25}</span></div>`).join('')}</div><p class="small">0 of 7 days at the target in this sample. That is information to work with, not a verdict.</p><div class="progress-track"><i style="width:${Math.min(100,8200/(H.state.target || 9000)*100)}%"></i></div><p class="tiny-label">Today · 8,200 of ${(H.state.target || 9000).toLocaleString('en-IN')} steps</p></div>
    ${H.section('Make it fit your day',`
    <div class="focus-card" data-tone="sleep"><h3>A walk after dinner.</h3><p>The original suggestion starts with something simple you can attach to an existing routine.</p>${H.evidence('steps_mortality','The evidence behind it')}</div>`)}<div class="two section">${H.button('Adjust target','adapt','secondary')}${H.button('End challenge','end-challenge','secondary')}</div>${H.link('See previous outcomes','outcomes','text-button section')}
    ${H.footer()}`;
  H.screens.program = () => `${H.header('Build a walking rhythm.','A program that can adapt',true)}${H.badge(H.state.program ? 'Active · week 3 of 4' : 'Available program','indigo')}<p class="section small">Build consistency through small changes. Each step has its own review before you move on.</p>
    ${H.section('Your path',`
    <div class="card"><div class="timeline">${[['1','Find your starting point','8,600 steps · outcome available',true],['2','A little further','8,800 steps · outcome available',true],['3','Make room to recover','8,900 steps · current step',true],['4','Keep what works','Final target adjusts to your progress',false]].map(([number,title,copy,active])=>`<div class="timeline-item"><span class="node ${active?'active':''}">${number==='1'||number==='2'?H.icon('check','small'):number}</span><div><h3>${title}</h3><p>${copy}</p>${number==='1'||number==='2'?H.link('Review outcome','outcomes'):''}</div></div>`).join('')}</div></div>`)}
    ${H.notice('Your progress sets the pace','If a target stops fitting, the program can adjust. A recovery step is part of the plan.')}${H.button(H.state.program ? 'End program' : 'Start this program','program-toggle','full secondary')}${H.evidence('steps_mortality','Why daily movement')}
    ${H.footer()}`;
  H.screens.outcomes = () => `${H.header('What changed?','Your completed movement challenge',true)}${H.badge('7-day observation','indigo')}
    <div class="sleep-hero section"><p class="small">Average daily steps</p><div class="hero-number">8,900</div><p class="small">Previously 8,200 · 6 of 7 days met the daily target</p></div>
    <div class="card"><div class="factor-bars"><div class="factor-row"><span>Before</span><div class="factor-track"><i style="width:82%"></i></div><span>8.2k</span></div><div class="factor-row"><span>During</span><div class="factor-track"><i style="width:89%"></i></div><span>8.9k</span></div></div><p class="small">A higher average in the challenge window. This is an observation, not a proven effect of the challenge.</p></div>
    ${H.section('Other things moved too',`
    <div class="card"><div class="two">${H.stat('45 → 46.5','ms','Overnight HRV')}${H.stat('55 → 54','bpm','Resting heart rate')}</div><hr class="divider"><p class="small">These changed during the same period. We don’t attribute them to walking.</p></div>`)}
    ${H.section('The context matters',`
    <div class="card flush">${H.row('info','One illness day','May affect the comparison','recovery')}${H.row('flag','One concurrent challenge','More than one thing changed at once','actions')}${H.row('journal','Your own context','Review the moments you recorded','journal')}</div>`)}
    ${H.notice('A result to learn from','Keep what feels sustainable. One week can suggest a question; it cannot settle cause and effect.')}
    ${H.footer()}`;
  H.screens['action-history'] = () => `${H.header('Your intentions.','Action history · July sample',true)}<p class="small">Adopting a suggestion records your intention. It doesn’t mean the action was completed.</p>
    ${H.section('31 July',`
    <div class="card"><div class="row between"><h3>Sleep earlier tonight</h3>${H.badge(H.state.adopted?'Adopted':'Suggested',H.state.adopted?'indigo':'')}</div><p class="small section">Suggested from your recent sleep debt.</p>${H.evidence('sleep_need_debt')}${H.button(H.state.adopted?'Remove intention':'Adopt suggestion','adopt','full secondary')}</div>`)}
    ${H.section('Keep exploring',`
    <div class="card flush">${H.row('flag','Active challenges','Turn an intention into a measured experiment','actions')}${H.row('insights','Completed outcomes','What happened during your changes','outcomes')}</div>`)}
    ${H.footer()}`;
  const journalEntries = () => {
    const saved = H.state.journal.map(entry=>H.row(entry.icon,H.escape(entry.kind),`${H.escape(entry.value)} ${H.escape(entry.unit)} · ${H.escape(entry.time)} · preview only`,'journal',H.badge('Saved','good'))).join('');
    return `${saved}${H.row('coffee','Morning coffee','80 mg caffeine · sample entry','journal')}${H.row('leaf','A quiet moment','10 minutes meditation · sample entry','journal')}`;
  };
  H.screens.journal = () => `${H.header('The rest of your day.','Your health journal',true)}<p class="small">A few moments of context help make your measurements more personal.</p><div class="journal-grid section">${H.journalKinds.map(([icon,name])=>`<button class="journal-kind" data-action="log" data-kind="${name}">${H.icon(icon)}${name}</button>`).join('')}</div>
    ${H.section('Your recent moments',`
    <div class="card flush">${journalEntries()}</div>`)}
    ${H.notice('A private space in this preview','Entries stay in this page’s memory and disappear on reload. Your health account is never changed.')}
    ${H.footer()}`;
  H.screens.coach = () => `${H.header('Your coach.','A conversation with context',true)}<div class="coach-intro"><div class="coach-symbol">${H.icon('coach')}</div><h2>Let’s make sense<br>of your day.</h2><p>Your measurements tell part of the story. Start with something you’ve been wondering about.</p></div>${H.state.messages.length ? H.state.messages.map(message=>`<div class="coach-message ${message.role}">${message.role==='user' ? H.escape(message.text) : message.text}</div>`).join('') : `<button class="prompt-button" data-action="ask" data-prompt="What should I notice about my sleep?">What should I notice about my sleep?${H.icon('arrow')}</button><button class="prompt-button" data-action="ask" data-prompt="How is my activity affecting recovery?">How is activity affecting my recovery?${H.icon('arrow')}</button><button class="prompt-button" data-action="ask" data-prompt="What does my HRV mean?">What does my HRV mean?${H.icon('arrow')}</button>`}
    <form class="coach-form" id="coach-form"><input name="question" aria-label="Your question for the coach" placeholder="What’s on your mind?" required maxlength="500"><button class="button" aria-label="Send question">${H.icon('arrow')}</button></form><p class="form-note">Scripted design conversation · no AI request is sent. In the app, answers include their sources and data coverage.</p>
    ${H.footer()}`;
})();
