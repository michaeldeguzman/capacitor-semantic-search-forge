// Validation harness for the plugin's on-device tests 1 to 9.
//
// Phase is derived from native state, not web storage:
//   launch 1 (nothing on disk):        tests 1, 2, 4 (+ test 5 scores)
//   launch 2 ('manual' on disk):       tests 3, 6, 7, 8 (test 7 clears it)
//   launch 3 ('bench-pending' on disk): test 9 (leaves 'bench' on disk)
//   launch 4 ('bench' on disk):        nothing; press Reset
// Every result line is also console.logged with an SSTEST prefix so it
// shows in the device log.
const { SemanticSearch } = window.capacitorSemanticSearch;
const COLLECTION = 'manual';
const out = document.getElementById('out');

function log(line) {
  out.textContent += line + '\n';
  console.log('SSTEST ' + line);
}

function check(name, ok, detail) {
  log(`${ok ? 'PASS' : 'FAIL'} ${name}${detail ? ' | ' + detail : ''}`);
}

async function rejects(fn) {
  try {
    await fn();
    return null;
  } catch (e) {
    return (e && e.message) || String(e);
  }
}

const exists = async collection => (await SemanticSearch.getCollectionInfo({ collection })).exists;
const median = xs => [...xs].sort((a, b) => a - b)[Math.floor(xs.length / 2)];

async function phase1() {
  log('== PHASE 1 ==');

  // Test 1
  const a = await SemanticSearch.isAvailable({ lang: 'en' });
  check('T1 isAvailable(en)', a.available && a.dimension === 384 && a.revision === 1, JSON.stringify(a));
  if (!a.available) {
    log('BLOCKED T2 T3 T4 T6 T7 | no sentence embedding for "en" on this device');
    await test8();
    return;
  }

  // Test 2 (+ timing)
  let t = performance.now();
  const u = await SemanticSearch.upsertMany({ collection: COLLECTION, lang: 'en', items: window.PROCEDURES });
  const ms = Math.round(performance.now() - t);
  check('T2 upsertMany 50', u.count === 50 && u.skipped.length === 0, `${JSON.stringify(u)} in ${ms}ms`);

  // Test 4: top result and score. All 50 scores are fetched so test 5 can
  // compare the right answer with the best wrong one.
  let hits = 0;
  let top3 = 0;
  for (const [query, expected] of window.QUERIES) {
    t = performance.now();
    const r = await SemanticSearch.search({ collection: COLLECTION, query, topK: 50, minScore: -1 });
    const qms = Math.round(performance.now() - t);
    const top = r.results[0];
    const rank = r.results.findIndex(x => x.id === expected) + 1;
    const right = r.results[rank - 1];
    const bestWrong = r.results.find(x => x.id !== expected);
    if (rank === 1) hits++;
    if (rank >= 1 && rank <= 3) top3++;
    log(
      `T4 ${rank === 1 ? 'HIT ' : 'MISS'} "${query}" -> ${top.id} ${top.metadata} (${top.score.toFixed(3)}); ` +
        `expected ${expected} rank ${rank}; T5 right ${right.score.toFixed(3)} bestWrong ${bestWrong.id} ${bestWrong.score.toFixed(3)}; ${qms}ms`,
    );
  }
  check('T4 paraphrased queries (expected: 6/10)', hits >= 6, `${hits}/10 top-1, ${top3}/10 top-3`);
  log('Phase 1 done. Kill and relaunch the app for phase 2.');
}

async function phase2() {
  log('== PHASE 2 ==');

  // Test 3: persistence across a process restart
  const info = await SemanticSearch.getCollectionInfo({ collection: COLLECTION });
  check('T3 persisted after relaunch', info.exists && info.count === 50, JSON.stringify(info));

  // Test 6: same ids, changed text
  const changed = window.PROCEDURES.map(p =>
    p.id === 'p01'
      ? { id: 'p01', text: 'Forklift scale recalibration. Recalibrate the load weighing scale on the forklift mast.', metadata: 'Forklift scale recalibration' }
      : p,
  );
  const u = await SemanticSearch.upsertMany({ collection: COLLECTION, lang: 'en', items: changed });
  const info6 = await SemanticSearch.getCollectionInfo({ collection: COLLECTION });
  check('T6 count stays 50', u.count === 50 && info6.count === 50, `upserted ${u.count}, collection ${info6.count}`);
  const rNew = await SemanticSearch.search({ collection: COLLECTION, query: 'calibrating the weighing scale on a forklift', topK: 1 });
  const top = rNew.results[0];
  check('T6 new text found', top && top.id === 'p01' && top.metadata === 'Forklift scale recalibration', JSON.stringify(top));
  const rOld = await SemanticSearch.search({ collection: COLLECTION, query: 'pump is making a grinding noise', topK: 1 });
  check('T6 old text gone', !rOld.results[0] || rOld.results[0].id !== 'p01', JSON.stringify(rOld.results[0]));

  // Test 7: remove two ids, then clear
  const rm = await SemanticSearch.remove({ collection: COLLECTION, ids: ['p02', 'p03'] });
  const info7 = await SemanticSearch.getCollectionInfo({ collection: COLLECTION });
  check('T7 remove 2', rm.count === 2 && info7.count === 48, `removed ${rm.count}, collection ${info7.count}`);
  await SemanticSearch.clear({ collection: COLLECTION });
  const info7b = await SemanticSearch.getCollectionInfo({ collection: COLLECTION });
  check('T7 clear', !info7b.exists && info7b.count === 0, JSON.stringify(info7b));

  await test8();

  // Marker so the next launch runs test 9 in a fresh process.
  await SemanticSearch.upsertMany({ collection: 'bench-pending', items: [{ id: 'x', text: 'marker' }] });
  log('Phase 2 done. Kill and relaunch the app for test 9.');
}

// Test 8: bad input rejects with a readable message, no crash
async function test8() {
  let msg = await rejects(() => SemanticSearch.search({ collection: COLLECTION, query: '' }));
  check('T8 empty query rejects', !!msg, msg);
  msg = await rejects(() => SemanticSearch.search({ collection: 'no-such-collection', query: 'pump noise' }));
  check('T8 unknown collection rejects', !!msg, msg);
  msg = await rejects(() =>
    SemanticSearch.upsertMany({ collection: 'xx-test', lang: 'xx', items: [{ id: 'a', text: 'hello' }] }),
  );
  check('T8 unsupported language rejects', !!msg, msg);
  const ax = await SemanticSearch.isAvailable({ lang: 'xx' });
  check('T8 isAvailable(xx) false', ax.available === false, JSON.stringify(ax));
}

// Test 9: 2,000 synthetic items, import and search timing
async function phase3() {
  log('== PHASE 3 ==');
  await SemanticSearch.clear({ collection: 'bench-pending' });
  const items = window.benchItems();
  log(`T9 start: ${items.length} items, ${JSON.stringify(items).length} bytes of JSON`);
  let t = performance.now();
  const u = await SemanticSearch.upsertMany({ collection: 'bench', lang: 'en', items });
  const importMs = Math.round(performance.now() - t);
  const info = await SemanticSearch.getCollectionInfo({ collection: 'bench' });
  check('T9 import 2000', u.count === 2000 && info.count === 2000, `count ${u.count}, skipped ${u.skipped.length}, ${importMs}ms`);
  const times = [];
  for (const q of window.BENCH_QUERIES) {
    t = performance.now();
    const r = await SemanticSearch.search({ collection: 'bench', query: q, topK: 5, minScore: 0.35 });
    times.push(performance.now() - t);
    log(`T9 search "${q}" -> ${r.results[0] ? r.results[0].metadata + ' ' + r.results[0].score.toFixed(3) : '(none)'}; ${times[times.length - 1].toFixed(1)}ms`);
  }
  log(`T9 search ms over ${times.length} queries: median ${median(times).toFixed(1)}, min ${Math.min(...times).toFixed(1)}, max ${Math.max(...times).toFixed(1)}`);
  log("Phase 3 done. 'bench' left on disk for its file size; press Reset to start over.");
}

async function runNext() {
  try {
    if (await exists(COLLECTION)) await phase2();
    else if (await exists('bench-pending')) await phase3();
    else if (await exists('bench')) log("'bench' is on disk; press Reset to start over.");
    else await phase1();
  } catch (e) {
    log('FAIL unexpected error | ' + ((e && e.message) || e));
  }
  log('DONE');
}

document.getElementById('run').onclick = runNext;
document.getElementById('reset').onclick = async () => {
  for (const collection of [COLLECTION, 'bench-pending', 'bench']) await SemanticSearch.clear({ collection });
  log('Reset: collections cleared.');
};

runNext();
