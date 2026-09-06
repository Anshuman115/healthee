/* Decorative particle field. No measurements enter the animation. */
(() => {
  const fields = new Map();
  const TAU = Math.PI * 2;
  const noise = value => { const n = Math.sin(value * 127.1 + 311.7) * 43758.5453; return n - Math.floor(n); };
  const particles = Array.from({length:1400}, (_,i) => ({
    angle: noise(i + 1) * TAU, spread: (noise(i + 80) - .5) * (i % 3 === 0 ? 60 : 22),
    size: .3 + noise(i + 210) * 1.1, phase: noise(i + 450) * TAU,
    speed: .32 + noise(i + 120) * .38, warm: i % 11 === 0,
  }));
  function palette(canvas) {
    const style = getComputedStyle(canvas);
    return ['--halo-core','--halo-mist','--halo-warm'].map(token => style.getPropertyValue(token).trim());
  }
  function sprite(colour) {
    const canvas = document.createElement('canvas'); canvas.width = canvas.height = 48;
    const ctx = canvas.getContext('2d');
    const glow = ctx.createRadialGradient(24,24,0,24,24,24);
    glow.addColorStop(0,colour); glow.addColorStop(.12,colour); glow.addColorStop(1,'transparent');
    ctx.fillStyle = glow; ctx.fillRect(0,0,48,48);
    return canvas;
  }
  function prepare(field) {
    const size = field.canvas.getBoundingClientRect(), ratio = Math.min(devicePixelRatio || 1,2);
    if (!size.width) return;
    field.canvas.width = Math.round(size.width * ratio); field.canvas.height = Math.round(size.height * ratio);
    field.colours = palette(field.canvas); field.sprites = field.colours.map(sprite);
    field.height = field.canvas.matches('.bio-atmosphere') ? 320 * size.height / size.width : 320;
    field.ctx.setTransform(field.canvas.width / 320,0,0,field.canvas.height / field.height,0,0);
    if (field.canvas.matches('.bio-atmosphere')) prepareStreams(field,size);
    draw(field);
  }
  function point(angle, radius, time) {
    const ripple = Math.sin(angle * 7 + time * .95) * 2.8 + Math.cos(angle * 13 - time * .7) * 1.8;
    return [160 + Math.cos(angle) * (radius + ripple), 160 + Math.sin(angle) * (radius + ripple)];
  }
  function filaments(field, time) {
    const ctx = field.ctx;
    for (let strand=0; strand<10; strand++) {
      ctx.beginPath();
      for (let i=0; i<=150; i++) {
        const angle = i/150*TAU;
        const radius = 109 + Math.sin(angle*5 + strand*.9 + time*.65)*3 + strand*.65;
        const [x,y] = point(angle,radius,time);
        if (i===0) ctx.moveTo(x,y); else ctx.lineTo(x,y);
      }
      ctx.strokeStyle = field.colours[strand===3?2:0]; ctx.globalAlpha = strand===3?.12:.07;
      ctx.lineWidth = .45; ctx.stroke();
    }
  }
  function prepareStreams(field, bounds) {
    const display = field.canvas.closest('.bio-hero').querySelector('.bio-display').getBoundingClientRect();
    const scale = 320 / bounds.width;
    field.centre = [(display.left + display.width/2 - bounds.left)*scale, (display.top + display.height/2 - bounds.top)*scale];
    const radius = 112 * display.width / bounds.width;
    field.streams = Array.from({length:280}, (_,i) => {
      const side = i%4, across = noise(i+870);
      const x = side===0?8:side===1?312:8+across*304;
      const y = side===2?8:side===3?field.height-8:8+across*(field.height-16);
      const dx = x-field.centre[0], dy = y-field.centre[1];
      return {angle:Math.atan2(dy,dx), start:Math.hypot(dx,dy), end:radius*(.98+noise(i+80)*.04),
        duration:6+noise(i+680)*5, phase:noise(i+930), curve:(noise(i+450)-.5)*.28};
    });
  }
  function streamPoint(field, stream, progress) {
    const radius = stream.end + (stream.start-stream.end)*Math.pow(1-progress,1.3);
    const angle = stream.angle + stream.curve*Math.sin(progress*Math.PI);
    return [field.centre[0]+Math.cos(angle)*radius, field.centre[1]+Math.sin(angle)*radius];
  }
  function drawStream(field, stream, i) {
    const ctx = field.ctx, progress = (stream.phase+field.time/stream.duration)%1;
    const [x,y] = streamPoint(field,stream,progress);
    const fade = Math.min(1,progress/.12,(1-progress)/.12);
    const life = fade*(.3+progress*.65), size = 3+noise(i+60)*5;
    const colour = i%13===0?2:0;
    // Short outward tails show the direction; heads disappear into the dense rim.
    if (i%3===0) {
      const [tailX,tailY] = streamPoint(field,stream,Math.max(0,progress-.022));
      ctx.globalAlpha = life*.35; ctx.strokeStyle = field.colours[colour]; ctx.lineWidth = .6;
      ctx.beginPath(); ctx.moveTo(tailX,tailY); ctx.lineTo(x,y); ctx.stroke();
    }
    ctx.globalAlpha = life;
    ctx.drawImage(field.sprites[colour],x-size/2,y-size/2,size,size);
    if (i%3===0) {
      ctx.fillStyle = field.colours[colour];
      ctx.beginPath(); ctx.arc(x,y,.35+noise(i+40)*.4,0,TAU); ctx.fill();
    }
  }
  function atmosphere(field) {
    const ctx = field.ctx, time = field.time, height = field.height;
    ctx.clearRect(0,0,320,height); ctx.globalCompositeOperation = 'lighter';
    for (let i=0; i<5; i++) {
      const x = 160 + Math.sin(time*.24+i*2.1)*145;
      const y = height * (.12+i*.19) + Math.cos(time*.3+i)*22;
      ctx.globalAlpha = .09;
      ctx.drawImage(field.sprites[i===3?2:1],x-90,y-90,180,180);
    }
    field.streams.forEach((stream,i) => drawStream(field,stream,i));
    ctx.globalAlpha = 1; ctx.globalCompositeOperation = 'source-over';
    field.canvas.dataset.frames = String(++field.frames);
  }
  function draw(field) {
    if (field.canvas.matches('.bio-atmosphere')) { atmosphere(field); return; }
    const ctx = field.ctx, time = field.time;
    ctx.clearRect(0,0,320,320);
    ctx.globalCompositeOperation = 'lighter';
    // Broken pools of light give the ring depth without painting behind the number.
    for (let i=0; i<36; i++) {
      const angle = i/36*TAU, [x,y] = point(angle,112,time);
      const size = 30 + Math.sin(angle*3+time*.8)*8;
      ctx.globalAlpha = .2 + Math.sin(angle*3-time*.85)*.05;
      ctx.drawImage(field.sprites[1],x-size/2,y-size/2,size,size);
    }
    filaments(field,time);
    particles.forEach((particle,i) => {
      const angle = particle.angle + time * (i%2===0?.07:-.045) + Math.sin(time*particle.speed + particle.phase)*.065;
      const radius = 112 + particle.spread + Math.sin(time*.85+particle.phase)*4;
      const [x,y] = point(angle,radius,time);
      const life = .45 + (.5+.5*Math.sin(time*1.5+particle.phase))*.55;
      const depth = Math.max(.18,1-Math.abs(particle.spread)/26);
      ctx.globalAlpha = life * depth * .8;
      const size = particle.size * (i%5===0?9:4);
      ctx.drawImage(field.sprites[particle.warm?2:0],x-size/2,y-size/2,size,size);
      if (i%3===0) {
        ctx.fillStyle = field.colours[particle.warm?2:0];
        ctx.beginPath(); ctx.arc(x,y,particle.size*.45,0,TAU); ctx.fill();
      }
    });
    ctx.globalAlpha = 1; ctx.globalCompositeOperation = 'source-over';
    field.canvas.dataset.frames = String(++field.frames);
  }
  function tick(field, now) {
    if (!field.running) return;
    if (now-field.last >= 32) {
      field.time += Math.min((now-field.last)/1000,.05); field.last = now; draw(field);
    }
    field.frame = requestAnimationFrame(next => tick(field,next));
  }
  H.setHaloMotion = (hero,running) => {
    hero.querySelectorAll('.bio-halo, .bio-atmosphere').forEach(canvas => {
      const field = fields.get(canvas);
      if (!field || field.running === running) return;
      field.running = running;
      if (running) { field.last = performance.now(); field.frame = requestAnimationFrame(now => tick(field,now)); }
      else cancelAnimationFrame(field.frame);
    });
  };
  H.mountHalos = () => {
    fields.forEach((field,canvas) => {
      if (!canvas.isConnected) { cancelAnimationFrame(field.frame); field.resize.disconnect(); fields.delete(canvas); }
    });
    document.querySelectorAll('.bio-halo, .bio-atmosphere').forEach(canvas => {
      if (fields.has(canvas)) return;
      const ctx = canvas.getContext('2d'); if (!ctx) return;
      const field = {canvas,ctx,time:0,last:0,frames:0,running:false};
      field.resize = new ResizeObserver(() => prepare(field));
      fields.set(canvas,field); prepare(field); field.resize.observe(canvas);
    });
  };
  const themeObserver = new MutationObserver(() => fields.forEach(prepare));
  themeObserver.observe(document.documentElement,{attributes:true,attributeFilter:['data-theme']});
})();
