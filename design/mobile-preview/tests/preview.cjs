/* Browser acceptance for the standalone design. No production services are used. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const baseURL = process.env.PREVIEW_URL || 'http://127.0.0.1:8765';
const artifacts = process.env.PREVIEW_ARTIFACTS || '/tmp/healthee-design-review';
const failures = [];
const routes = ['today','sleep','activity','insights','actions','coach','journal','recovery',
  'sleep-history','workouts','workout','metrics','metric/hrv','metric/hr','metric/rhr',
  'metric/weight','metric/temperature','metric/efficiency','metric/regularity','metric/mvpa','metric/vo2','insight','fitness','body','route','record','challenge','program',
  'outcomes','action-history','settings','profile','device','sync','pairing','appearance',
  'reminders','background','account','about','welcome'];
for (const metric of ['hr','hrv','rhr','stress','spo2','breathing','steps','weight','load','energy','sleep','efficiency','regularity','temperature','mvpa','moderate','vigorous','total-energy','resting-energy','distance','vo2','recovery','debt','need','sleep-health']) {
  if (!routes.includes(`metric/${metric}`)) routes.push(`metric/${metric}`);
}

async function navigate(page, route) {
  await page.goto(`${baseURL}/#${route}`);
  await page.locator('#main h1').waitFor();
  await page.evaluate(() => document.fonts.ready);
}

async function checkScreen(page, route, width, theme) {
  await page.setViewportSize({width, height: 896});
  await navigate(page, route);
  await page.evaluate(value => H.setTheme(value),theme);
  const issues = await page.evaluate(() => {
    const shell = document.querySelector('.app-shell').getBoundingClientRect();
    const overflow = [...document.querySelectorAll('#main *')].filter(element => {
      const bounds = element.getBoundingClientRect();
      return !element.closest('.bio-art') && bounds.width > 0 && (bounds.right > shell.right + 2 || bounds.left < shell.left - 2);
    }).map(element => `${element.tagName}.${element.className?.baseVal || element.className}: ${element.textContent.slice(0,60)}`);
    const invalid = /\bundefined\b|\bNaN\b/.test(document.querySelector('#main').textContent);
    const deadLinks = [...document.querySelectorAll('a[href^="#"]')].filter(a => {
      const routeName = a.hash.slice(1).split('/')[0];
      return routeName !== 'main' && !H.screens[routeName];
    }).map(a => a.hash);
    const deadActions = [...document.querySelectorAll('[data-action]')].filter(b => !H.actions[b.dataset.action]).map(b => b.dataset.action);
    return {overflow, invalid, deadLinks, deadActions, documentOverflow:document.documentElement.scrollWidth>innerWidth};
  });
  if (issues.overflow.length || issues.invalid || issues.deadLinks.length || issues.deadActions.length || issues.documentOverflow) failures.push({route,width,theme,...issues});
}

async function checkInteractions(page) {
  await page.setViewportSize({width:375,height:812});
  await navigate(page,'today');
  await page.locator('#bottom-nav a[href="#sleep"]').click();
  await page.waitForURL('**/#sleep');
  await page.goBack();
  await page.waitForURL('**/#today');
  await page.locator('.preview-bar button').click();
  await page.locator('[data-action="scenario"][data-value="missing"]').click();
  assert.match(await page.locator('.withheld-value').textContent(), /few more nights/i);
  await page.evaluate(() => { H.state.scenario='normal'; H.render(); });
  await navigate(page,'journal');
  await page.locator('[data-kind="Weight"]').click();
  assert.equal(await page.locator('#journal-form [name="value"]').inputValue(),'');
  await page.locator('#journal-form [name="value"]').fill('73.2');
  await page.locator('#journal-form button[type="submit"]').click();
  assert.match(await page.locator('#main').textContent(), /73.2 kg/);
  await page.locator('[data-kind="Habit"]').click();
  await page.locator('#journal-form [name="value"]').fill('<img src=x onerror=alert(1)>');
  await page.locator('#journal-form button[type="submit"]').click();
  assert.equal(await page.locator('#main img').count(),0);
}

async function checkActionFlows(page) {
  await navigate(page,'actions');
  await page.locator('[data-action="adopt"]').click();
  assert.equal(await page.locator('[data-action="adopt"]').getAttribute('aria-pressed'),'true');
  await navigate(page,'challenge');
  await page.locator('[data-action="adapt"]').click();
  await page.locator('[name="target"]').fill('8500');
  await page.locator('#target-form button').click();
  assert.match(await page.locator('#main').textContent(),/8,500/);
  await navigate(page,'coach');
  await page.locator('[data-action="ask"]').first().click();
  assert.equal(await page.locator('.coach-message').count(),2);
  await page.locator('.coach-message [data-action="evidence"]').click();
  assert.equal(await page.locator('#sheet').evaluate(dialog=>dialog.open),true);
  await page.keyboard.press('Escape');
}

async function checkDeviceAndCharts(page) {
  await navigate(page,'metric/hr');
  await page.locator('.chart-scrubber').focus();
  await page.keyboard.press('Home');
  assert.match(await page.locator('.chart-readout').textContent(),/64 bpm/);
  await page.locator('[data-action="range"][data-value="90d"]').click();
  assert.match(await page.locator('#main').textContent(),/longer view needs your server/);
  await navigate(page,'reminders');
  await page.getByRole('switch',{name:'Time to wind down'}).click();
  assert.equal(await page.getByRole('switch',{name:'Time to wind down'}).getAttribute('aria-checked'),'true');
  await navigate(page,'pairing');
  await page.locator('[data-action="scan"]').click();
  await page.locator('[data-action="pair"]').click();
  await page.waitForURL('**/#device');
  await page.locator('[data-action="sync"]').first().click();
  await page.getByText('Sample sync complete',{exact:true}).waitFor();
  await page.keyboard.press('Escape');
  await navigate(page,'record');
  await page.locator('[data-action="record-start"]').click();
  await page.waitForFunction(()=>H.state.seconds>=1);
  await page.locator('[data-action="record-stop"]').click();
  assert.equal(await page.evaluate(()=>H.state.recording),false);
}

async function checkConnectedViews(page) {
  await navigate(page,'sleep');
  assert.equal(await page.locator('.sleep-check').count(),4);
  assert.equal(await page.locator('.sleep-check.met').count(),2);
  assert.equal(await page.locator('.sleep-check.short').count(),2);
  assert.match(await page.locator('.sleep-checks').textContent(),/Regularity · SRI/);
  assert.match(await page.locator('.sleep-checks').textContent(),/40 minutes below/);
  await page.locator('#bottom-nav a[href="#today"]').click();
  await page.getByRole('button',{name:'Previous day',exact:true}).click();
  await page.locator('#bottom-nav a[href="#sleep"]').click();
  await page.locator('.sleep-check').first().waitFor();
  assert.match(await page.locator('.page-header .date').textContent(),/30 July/);
  assert.equal(await page.locator('.date-navigation').count(),0);
  await page.locator('#bottom-nav a[href="#today"]').click();
  await page.getByRole('button',{name:'Next day',exact:true}).click();
  await navigate(page,'today');
  assert.ok(await page.locator('#main svg.chart').count()>=9);
  const slider=page.getByRole('slider',{name:'Compare heart rate and stress by hour'});
  await slider.focus();
  await page.keyboard.press('Home');
  assert.match(await page.locator('#linked-readout').textContent(),/64 bpm/);
  assert.match(await page.locator('#linked-readout').textContent(),/Stress 32/);
  await page.keyboard.press('End');
  assert.match(await page.locator('#linked-readout').textContent(),/17:00/);
  const colours=await page.locator('.summary-tile').evaluateAll(elements=>elements.map(element=>getComputedStyle(element).backgroundColor));
  assert.equal(new Set(colours).size,3);
  await navigate(page,'body');
  assert.match(await page.locator('#main').textContent(),/36 chronological years − 1.7 fitness \+ 0.0 sleep = 34.3/);
  await navigate(page,'metrics');
  assert.equal(await page.locator('.metric-list a').count(),25);
}

async function main() {
  fs.mkdirSync(artifacts,{recursive:true});
  const browser = await chromium.launch({headless:true,executablePath:process.env.CHROMIUM_PATH,args:['--no-sandbox']});
  const page = await browser.newPage({deviceScaleFactor:1});
  page.on('pageerror',error=>failures.push({browserError:error.message}));
  const externalRequests = [];
  page.on('request',request=> { if(!request.url().startsWith(baseURL) && !request.url().startsWith('data:')) externalRequests.push(request.url()); });
  for (const width of [320,375,414,768]) for (const route of routes) await checkScreen(page,route,width,'light');
  for (const route of routes) await checkScreen(page,route,375,'dark');
  console.log(`Checked ${routes.length*5} screen/viewport/theme combinations.`);
  await checkInteractions(page);
  await checkActionFlows(page);
  await checkDeviceAndCharts(page);
  await checkConnectedViews(page);
  for (const route of ['today','sleep','activity','insights','actions','coach','route']) {
    await page.setViewportSize({width:414,height:896});
    await navigate(page,route);
    await page.evaluate(() => H.setTheme('light'));
    await page.screenshot({path:path.join(artifacts,`${route}.png`),fullPage:true,animations:'disabled'});
  }
  await page.setViewportSize({width:1440,height:1000});
  await navigate(page,'today');
  await page.screenshot({path:path.join(artifacts,'desktop.png'),animations:'disabled'});
  await page.emulateMedia({reducedMotion:'reduce'});
  const duration = await page.locator('.page-enter').evaluate(element=>getComputedStyle(element).animationDuration);
  assert.equal(duration,'0.1s');
  assert.deepEqual(externalRequests,[],'The prototype must not contact outside services.');
  await browser.close();
  fs.writeFileSync(path.join(artifacts,'results.json'),JSON.stringify({combinations:routes.length*5,failures},null,2));
  assert.deepEqual(failures,[]);
  console.log(`Interaction, navigation, privacy and reduced-motion checks passed. Screenshots: ${artifacts}`);
}
main().catch(error=> { console.error(error); process.exitCode=1; });
