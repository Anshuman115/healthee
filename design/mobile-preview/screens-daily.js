/* Recovery is a model breakdown, linked to sleep and activity. */
(() => {
  H.screens.recovery = () => `${H.header('Recovery, in context.','Overnight signals → remaining capacity',true)}${H.scenarioNotice()}${H.recoveryPanel()}
    ${H.panel('Compared with your baseline','recovery',`${H.charts.signals()}${H.note('These sample readings match their recent baselines. A baseline is personal, not a population target.')}`,'metrics')}
    ${H.bridge('sleep','Sleep contributes 40% of the model. The full night includes stages, efficiency and overnight physiology.','sleep','Explore your sleep')}
    ${H.panel('Your body overnight','oxygen',H.overnightVitals(),'sleep','heart')}
    ${H.panel('Capacity changes through the day','movement',`<div class="two">${H.stat('72','/100','Overnight recovery')}${H.stat('36','/100','Remaining readiness')}</div>${H.charts.load()}${H.note('Today’s recorded effort changes remaining readiness. The overnight number does not update to erase that context.')}`,'activity','walk')}
    ${H.evidence('recovery_readiness','Method, weighting & limitations')}${H.footer()}`;
})();
