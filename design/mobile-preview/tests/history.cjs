/* Date navigation acceptance, including incomplete historical measurements. */
const assert=require('node:assert/strict');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const base=process.env.PREVIEW_URL||'http://127.0.0.1:8765';
async function main() {
  const browser=await chromium.launch({headless:true,executablePath:process.env.CHROMIUM_PATH,args:['--no-sandbox']});
  const page=await browser.newPage({viewport:{width:414,height:1000}}),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  try {
    await page.goto(base);
    await page.getByRole('button',{name:'Previous day',exact:true}).click();
    assert.equal(await page.evaluate(()=>H.viewDate()),'2026-07-30');
    assert.match(await page.locator('#main').textContent(),/Biological age and recovery were not saved/);
    await page.locator('#bottom-nav a[href="#activity"]').click();
    await page.waitForURL(url=>url.hash==='#activity');
    assert.equal(await page.locator('.date-navigation').count(),0);
    await page.evaluate(()=>H.setViewDate('2026-07-29'));
    assert.equal(await page.evaluate(()=>H.viewDate()),'2026-07-29');
    await page.goBack();
    await page.waitForURL(url=>!url.hash||url.hash==='#today');
    await page.waitForFunction(()=>H.viewDate()==='2026-07-30');
    await page.evaluate(()=>H.navigate('fitness'));
    await page.locator('#main h1').filter({hasText:'Fitness'}).waitFor();
    assert.match(await page.locator('.panel-value').first().textContent(),/41.5/);
    await page.reload();
    assert.equal(await page.locator('time').getAttribute('datetime'),'2026-07-30');
    await page.locator('#bottom-nav a[href="#today"]').click();
    await page.locator('.date-picker-trigger').click();
    assert.equal(await page.locator('.date-calendar [data-date="2026-07-01"]').isDisabled(),true);
    await page.locator('.date-calendar [data-date="2026-07-20"]').click();
    await page.evaluate(()=>H.navigate('sleep'));
    await page.locator('.sleep-check').first().waitFor();
    assert.equal(await page.locator('.sleep-check').count(),4);
    assert.equal(await page.locator('time').getAttribute('datetime'),'2026-07-20');
    await page.locator('#bottom-nav a[href="#today"]').click();
    await page.locator('.date-picker-trigger').click();
    await page.locator('.date-calendar [aria-current="date"]').press('ArrowLeft');
    await page.keyboard.press('Enter');
    assert.equal(await page.locator('time').getAttribute('datetime'),'2026-07-19');
    await page.locator('#bottom-nav a[href="#today"]').click();
    await page.locator('.date-latest').click();
    assert.equal(await page.locator('time').getAttribute('datetime'),'2026-07-31');
    const routes=['today','sleep','sleep-history','activity','insights','actions','recovery','fitness','body','metrics','metric/vo2','metric/hr','metric/debt','journal','workouts','action-history'];
    for(const width of [320,375,414,768]) {
      await page.setViewportSize({width,height:1000});
      for(const day of ['02','17','30']) for(const route of routes) {
        await page.goto(`${base}/?date=2026-07-${day}#${route}`);
        await page.locator('#main h1').waitFor();
        const result=await page.evaluate(()=>({date:H.viewDate(),overflow:document.documentElement.scrollWidth>innerWidth,invalid:/\bNaN\b|\bundefined\b|Infinity/.test(document.querySelector('#main').textContent),future:[...document.querySelectorAll('[data-chart-labels]')].some(el=>JSON.parse(el.dataset.chartLabels).some(d=>Number.parseInt(d)>Number(H.viewDate().slice(8))))}));
        assert.deepEqual(result,{date:`2026-07-${day}`,overflow:false,invalid:false,future:false},`${width} ${day} ${route}`);
      }
    }
    await page.goto(`${base}/?date=2026-07-02#sleep`);
    assert.match(await page.locator('.big-duration').textContent(),/—/);
    assert.equal(await page.locator('.sleep-check.missing').count(),1);
    await page.goto(`${base}/?date=2026-07-30#journal`);
    await page.locator('[data-kind="Weight"]').click();
    assert.equal(await page.locator('[name="time"]').inputValue(),'2026-07-30T17:00');
    await page.locator('[name="value"]').fill('73.2');
    await page.locator('#journal-form button[type="submit"]').click();
    assert.match(await page.locator('#main').textContent(),/73.2 kg/);
    await page.locator('#bottom-nav a[href="#today"]').click();
    await page.locator('.date-latest').click();
    await page.evaluate(()=>H.navigate('journal'));
    await page.locator('.journal-grid').waitFor();
    assert.doesNotMatch(await page.locator('#main').textContent(),/73.2 kg/);
    await page.setViewportSize({width:414,height:1000});
    for(const route of ['today','sleep']) {
      await page.goto(`${base}/#${route}`); await page.evaluate(()=>document.fonts.ready);
      await page.screenshot({path:`/tmp/healthee-date-${route}.png`,animations:'disabled'});
    }
    await page.locator('#bottom-nav a[href="#today"]').click();
    await page.locator('.date-picker-trigger').click();
    await page.screenshot({path:'/tmp/healthee-date-calendar.png',animations:'disabled'});
    assert.deepEqual(errors,[]);
    console.log(`Passed ${routes.length*3*4} historical layouts; date persistence, browser back, calendar keyboard, dated journal, missing nights and no future chart samples.`);
  } finally {await browser.close();}
}
main().catch(e=>{console.error(e);process.exitCode=1;});
