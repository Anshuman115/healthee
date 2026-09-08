/* Charts keep fixture values and missing samples intact. No fabricated trend interpolation. */
(() => {
  let sequence = 0;
  const svg = (content, label, height = 170, classes = '') => `<svg class="chart ${classes}" viewBox="0 0 340 ${height}" role="img" aria-label="${label}">${content}</svg>`;
  const text = (x, y, value, anchor = 'start') => `<text x="${x}" y="${y}" text-anchor="${anchor}">${value}</text>`;
  const path = points => points.map((point, index) => `${index ? 'L' : 'M'}${point[0].toFixed(1)},${point[1].toFixed(1)}`).join(' ');
  const sampleLabels = (count, start, end) => Array.from({length:count}, (_,index) => {
    if (count === 1) return start;
    if (/^\d{2}:\d{2}$/.test(start) && /^\d{2}:\d{2}$/.test(end)) {
      const minutes = value => Number(value.slice(0,2))*60 + Number(value.slice(3));
      const time = Math.round(minutes(start) + index/(count-1)*(minutes(end)-minutes(start)));
      return `${Math.floor(time/60).toString().padStart(2,'0')}:${(time%60).toString().padStart(2,'0')}`;
    }
    if (/^\d+ Jul$/.test(start)) return `${parseInt(start,10)+index} Jul`;
    return `${index+1} of ${count}`;
  });
  H.chartLabels = sampleLabels;
  H.charts.line = (values, options = {}) => {
    const { label = 'Heart rate', unit = 'bpm', min = 50, max = 80, start = '00:00', end = '23:59', baseline = null, compact = false } = options;
    const width = 340, height = compact ? 70 : 170, top = compact ? 6 : 18, bottom = height - (compact ? 6 : 30);
    const x = index => 4 + index / Math.max(1, values.length - 1) * 302;
    const y = value => bottom - (value - min) / (max - min) * (bottom - top);
    const id = `chart-fill-${sequence++}`;
    let content = `<defs><linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1"><stop class="area-top" offset="0%"/><stop class="area-bottom" offset="100%"/></linearGradient></defs>`;
    if (!compact) [min, (min + max) / 2, max].forEach(value => { content += `<path class="gridline" d="M4 ${y(value)}H308"/>${text(338, y(value) + 4, Math.round(value), 'end')}`; });
    if (baseline !== null) content += `<path class="baseline-line" d="M4 ${y(baseline)}H308"/>`;
    let segment = [];
    const flush = () => {
      if (!segment.length) return;
      content += `<path d="${path(segment)} L${segment.at(-1)[0]},${bottom} L${segment[0][0]},${bottom}Z" fill="url(#${id})"/><path class="data-line" d="${path(segment)}"/>`;
      segment = [];
    };
    values.forEach((value, index) => { if (value === null) flush(); else segment.push([x(index), y(value)]); });
    flush();
    if (!compact) content += text(4, height - 6, start) + text(306, height - 6, end, 'end');
    const last = values.at(-1);
    if (last !== null && last !== undefined) content += `<circle class="data-dot" cx="${x(values.length - 1)}" cy="${y(last)}" r="3.5"/>`;
    const chart = svg(content, `${label}, ${unit}. ${start} to ${end}.`, height, compact ? 'sparkline' : '');
    if (compact) return chart;
    return `<div class="chart-interactive" data-chart-values="${values.join(',')}" data-chart-labels="${H.escape(JSON.stringify(sampleLabels(values.length,start,end)))}" data-chart-unit="${unit}" data-chart-min="${min}" data-chart-max="${max}">${chart}<input class="chart-scrubber" type="range" min="0" max="${values.length - 1}" value="${values.length - 1}" aria-label="Explore ${label} samples"><output class="chart-readout">Touch the chart to explore · ${unit}</output></div>`;
  };
  H.charts.bars = (values, { max = 100, labels = ['M','T','W','T','F','S','S'], label = 'Daily activity', target = null, unit = '' } = {}) => {
    const width = 300 / values.length;
    let content = [0, max / 2, max].map(value => `<path class="gridline" d="M2 ${130 - value / max * 116}H310"/>`).join('');
    if (target !== null) content += `<path class="baseline-line" d="M2 ${130 - target / max * 116}H310"/>`;
    values.forEach((value, index) => {
      const x = 4 + index * width;
      content += `<rect class="bar ${index === values.length - 1 ? 'current' : ''}" x="${x}" y="${130 - value / max * 116}" width="${width * .58}" height="${value / max * 116}" rx="5"/><title>${labels[index]}: ${value} ${unit}</title>${text(x + width * .29, 153, labels[index], 'middle')}`;
    });
    content += text(338, 20, max + unit, 'end') + text(338, 134, '0', 'end');
    return svg(content, label, 164);
  };
  H.charts.sleep = (compact = false) => {
    const timeline = (H.currentNight?.() || H.demo.sleep.nights[0]).stage_timeline;
    const stages = ['awake', 'rem', 'light', 'deep'];
    let content = stages.map((stage, index) => text(0, 20 + index * 33, stage === 'rem' ? 'REM' : stage[0].toUpperCase() + stage.slice(1))).join('');
    const points = [];
    timeline.forEach(item => {
      const x = 55 + item.start_offset_min / 450 * 276;
      const y = 8 + stages.indexOf(item.stage) * 33;
      content += `<rect class="stage-${item.stage}" x="${x}" y="${y}" width="${item.duration_min / 450 * 276}" height="20" rx="5"/>`;
      points.push([x, y + 10], [x + item.duration_min / 450 * 276, y + 10]);
    });
    content = `<path class="sleep-connector" d="${path(points)}"/>` + content;
    content += text(55, 153, '23:00') + text(331, 153, '06:30', 'end');
    if (compact) return `<div class="sleep-strip"><i class="stage-light" style="flex:200"></i><i class="stage-deep" style="flex:90"></i><i class="stage-rem" style="flex:160"></i></div><div class="chart-axis"><span>23:00</span><span>06:30</span></div>`;
    return svg(content, 'Sample stage timeline: light 200 minutes, deep 90 minutes, REM 160 minutes. Wearable estimate.', 165);
  };
  H.charts.signals = () => `<div class="signal-chart"><div class="signal-chart-key"><span>Lower</span><span>Your baseline</span><span>Higher</span></div>${[['HRV','45 ms',50],['Resting HR','55 bpm',50],['Sleep','6h 20m',50]].map(([name,value,position]) => `<div class="signal-row"><span>${name}</span><div class="signal-track"><i class="signal-band"></i><i class="signal-center"></i><i class="signal-dot" style="left:${position}%"></i></div><b>${value}</b></div>`).join('')}</div>`;
  H.charts.consistency = () => svg(`<rect class="baseline-band" x="15" y="28" width="294" height="91" rx="8"/>${Array.from({length:7}, (_, index) => `<rect class="bar current" x="${26+index*42}" y="30" width="12" height="87" rx="6"/>${text(32+index*42,145,['S','S','M','T','W','T','F'][index],'middle')}`).join('')}${text(338,34,'23:00','end')}${text(338,119,'06:30','end')}`, 'Bedtime and wake time for seven sample nights: 23:00 to 06:30.', 160);
  H.charts.route = () => {
    const points = H.demo.gps_detail.points;
    const coordinates = points.map((p, index) => [70 + index / (points.length - 1) * 190, 195 - index / (points.length - 1) * 150]);
    return svg(`<rect class="map-land" width="340" height="240"/><path class="map-park" d="M0 0h150l-20 90L0 130ZM205 145l135-35v130H180Z"/><path class="map-water" d="M230 0c-55 90 25 140-20 240h22c43-90-30-165 24-240Z"/><path class="map-road" d="M0 170 340 20M0 220 340 70M30 0l190 240M95 0l190 240"/><path class="route-underlay" d="${path(coordinates)}"/><path class="route-line" d="${path(coordinates)}"/><circle class="route-start" cx="70" cy="195" r="6"/><circle class="data-dot" cx="260" cy="45" r="6"/>${text(18,224,'Sample route · schematic map')}`, 'Sample recorded GPS route from 20 fixture coordinates. Schematic background.', 240, 'route-map');
  };
})();
