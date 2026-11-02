# Embedding bake-off

Run 2026-10-26 on a MacBook Pro (Apple M5 Max, macOS 27.0.1). It answers
one question: the Apple NLEmbedding engine in the original design put
the right procedure first for only 1 of 10 paraphrased queries, so which
engine should v1 use instead? Recorded on 2026-10-26, before the plugin
switched engines. The plugin now ships all-MiniLM-L6-v2, as recommended
below.

## Recommendation

Use **all-MiniLM-L6-v2, converted to Core ML with 8-bit weights**, in
place of `NLEmbedding.sentenceEmbedding`.

| | |
|---|---|
| Quality on this set | 6/10 right answer first, 7/10 in top 3 (7/10 first with title entries), vs 1/10 and 2/10 for the current engine |
| Model size | 22 MB (`.mlmodel`, int8 weights), plus a 226 KB `vocab.txt` |
| Minimum iOS | 14.0 (Core ML "neuralnetwork" format), so the plugin's target is unchanged |
| Speed | 0.7 ms per query embedding in Core ML on the Mac; must be measured on an iPhone |
| Licence | Apache-2.0 |

Why this engine:
- It was best or joint best in every test here, by a wide margin over
  both Apple engines.
- It is the smallest of the models tried (22.7M parameters).
- It runs in the iOS Simulator. Apple's sentence embeddings return nil
  there, so the current engine can't be validated on the Simulator at
  all.
- The same model runs on Android through ONNX or TFLite and gives the
  same vectors. That removes the original design's "Android needs a
  different engine, which gives different vectors" problem.

## Setup

- **Data:** the 50 maintenance procedures and 10 paraphrased queries from
  the example app's validation test in `example/www/js/data.js`. Each
  procedure is indexed as "Title. Body".
- **Scoring:** cosine similarity between L2-normalised vectors, computed
  the same way for every engine.
- **Gap:** score of the right answer minus the score of the best wrong
  answer, per query. A positive gap means the right answer came first;
  bigger gaps make a `MinScore` cut-off easier to set. Cosine gaps and
  hybrid gaps use different scales, so compare them only within a scale.
- **Time per search:** median time to embed one query (after a warm-up)
  plus a dot product against 50 vectors. The dot product takes under
  0.01 ms. Apple engines ran natively; the two Python models ran through
  PyTorch on the CPU. All times are from the Mac, not an iPhone.
- **Hybrid:** BM25 keyword score (k1 = 1.2, b = 0.75, small generic
  stop-word list) and the engine's cosine score, each scaled to 0–1 per
  query, then averaged 50/50.
- **Title entries:** each title is also embedded on its own, and a
  procedure's score is the higher of its title score and its full-text
  score.

## Engines

| Engine | Vector size | Minimum OS | Model size and source |
|---|---|---|---|
| 1. `NLEmbedding.sentenceEmbedding(for: .english)` | 512 | iOS 14 / macOS 11 | Apple system asset, revision 1. On this Mac it lives in a MobileAsset download, not the OS image. |
| 2. `NLContextualEmbedding(language: .english)`, mean-pooled token vectors | 512 | iOS 17 / macOS 14 | Apple mBERT asset, 108 MB on disk. Downloaded on demand with `requestAssets()` (it was already on this Mac). Maximum 256 tokens. |
| 3a. all-MiniLM-L6-v2 | 384 | — | 22.7M parameters, 87 MB fp32 safetensors |
| 3b. bge-small-en-v1.5 | 384 | — | 33.4M parameters, 127 MB fp32 safetensors. Queries get bge's recommended retrieval prefix. |

## Results

| Config | Right first /10 | Right in top 3 /10 | Gap mean | Gap median | Gap min / max | ms per search | Score scale |
|---|---|---|---|---|---|---|---|
| BM25 alone (reference) | 3 | 5 | −1.078 | −0.239 | −4.069 / +3.672 | 0.02 | BM25 |
| **1. NLEmbedding (baseline)** | **1** | **2** | −0.129 | −0.122 | −0.283 / +0.031 | 2.57 | cosine |
| 1 + title entries | 0 | 2 | −0.090 | −0.075 | −0.212 / −0.015 | 2.57 | cosine |
| 1 + BM25 50/50 | 3 | 5 | −0.263 | −0.332 | −0.670 / +0.313 | 2.60 | hybrid 0–1 |
| 1 + title entries + BM25 50/50 | 4 | 5 | −0.178 | −0.086 | −0.667 / +0.280 | 2.60 | hybrid 0–1 |
| **2. NLContextualEmbedding** | **1** | **4** | −0.013 | −0.013 | −0.032 / +0.009 | 6.46 | cosine |
| 2 + title entries | 1 | 4 | −0.013 | −0.012 | −0.032 / +0.009 | 6.46 | cosine |
| 2 + BM25 50/50 | 3 | 5 | −0.165 | −0.143 | −0.555 / +0.557 | 6.49 | hybrid 0–1 |
| **3a. all-MiniLM-L6-v2** | **6** | **7** | +0.055 | +0.115 | −0.248 / +0.237 | 2.67 | cosine |
| 3a + title entries | **7** | 7 | +0.065 | +0.115 | −0.252 / +0.237 | 2.67 | cosine |
| 3a + BM25 50/50 | 5 | 7 | −0.074 | +0.039 | −0.653 / +0.657 | 2.69 | hybrid 0–1 |
| 3a + title entries + BM25 50/50 | 6 | 7 | −0.062 | +0.107 | −0.653 / +0.657 | 2.69 | hybrid 0–1 |
| **3b. bge-small-en-v1.5** | **5** | **7** | +0.024 | +0.022 | −0.062 / +0.123 | 4.86 | cosine |
| 3b + title entries | 6 | 7 | +0.022 | +0.033 | −0.103 / +0.134 | 4.86 | cosine |
| 3b + BM25 50/50 | 5 | 6 | −0.074 | +0.038 | −0.646 / +0.657 | 4.88 | hybrid 0–1 |

### What the numbers say

- **Apple's sentence embedding (engine 1)** separates topics poorly.
  Cosine scores for all query–procedure pairs range from 0.02 to 0.56.
  The right answer was beaten by an unrelated procedure in 9 of 10
  queries, and was ranked 37th for the original demo query ("pump is
  making a grinding noise") and 48th for "red cylinder for putting out
  flames".
- **Apple's contextual embedding (engine 2)**, mean-pooled, crowds every
  score into 0.79–0.93, so gaps are about ±0.01. It reached 4/10 in the
  top 3 but only 1/10 first, and no `MinScore` threshold could work with
  scores that close. Apple doesn't sell this model for sentence
  similarity, and it needs iOS 17 plus a 108 MB on-demand download.
- **The keyword hybrid** lifts engine 1 from 1 to 3 or 4 right-first,
  which is still worse than MiniLM alone. It makes MiniLM slightly worse
  (6 → 5): scaling each query's scores to 0–1 lets single keyword hits
  win, for example "oil" in the query pulls up "Gearbox oil change". A
  keyword boost isn't worth adding to v1.
- **Title entries** gain one query for MiniLM ("red cylinder for putting
  out flames" now finds Fire extinguisher inspection) and one for bge,
  and lose one for engine 1. That needs a way to group several vectors
  under one id, which links to an open design question about
  `metadata` becoming a parent id. Leave it out of v1 and suggest that
  consumers keep their indexed text short instead.
- **MiniLM vs bge-small:** MiniLM puts one more answer first, has wider
  gaps (median +0.115 vs +0.022, which makes a threshold easier to set),
  is about 30% smaller, and needs no query prefix.

### Per-query detail (right-first marked ✓)

| Query | Expected | NLEmbedding: top result (rank of expected) | MiniLM: top result (rank of expected) |
|---|---|---|---|
| pump is making a grinding noise | p01 Bearing wear | p35 Elevator pit (37) | p15 Pump cavitation (11) |
| the conveyor keeps wandering off to the edge | p09 Conveyor tracking | p33 Roof drain (12) | ✓ p09 |
| make sure nobody gets electrocuted while I fix the machine | p06 Lockout tagout | p17 Circuit breaker reset (5) | ✓ p06 |
| oil spraying out of a high pressure line | p03 Hydraulic hose leak | p44 Roller chain lubrication (26) | p08 Gearbox oil change (5) |
| the electric motor feels way too hot | p07 Motor overheating | p16 Switchboard thermal scan (33) | ✓ p07 |
| backup power plant needs its monthly run | p18 Generator load test | ✓ p18 | ✓ p18 |
| white crusty buildup on the car battery | p19 Battery terminal cleaning | p50 UPS battery (4) | ✓ p19 |
| aircon is not blowing cold any more | p21 Refrigerant leak | p46 Ladder inspection (18) | p45 Tyre pressure (10) |
| signs above the exits during a blackout | p37 Emergency lighting | p33 Roof drain (2) | ✓ p37 |
| red cylinder for putting out flames | p11 Fire extinguisher | p27 Steam trap (48) | p36 Relamping (3); ✓ with title entries |

The original demo query misses on every engine. MiniLM and bge both
answer "Pump cavitation troubleshooting", which is arguably a fair
answer to "pump is making a grinding noise". Pick a different demo query,
or reword the bearing procedure, before recording the demo.

### Caveats

- Ten queries is a small sample. A difference of one query between
  engines is noise. The gap between Apple's engines (1/10) and the
  MiniLM-family models (5–7/10) is not.
- The iPhone's sentence-embedding asset may not be the same as this
  Mac's, so engine 1 could do better or worse on a phone. The Simulator
  has no sentence embeddings, so there is no iOS number yet.
- Python times are PyTorch on the CPU and are not comparable to iOS. The
  Core ML figures below are the better guide.

## Core ML check (MiniLM)

Converted with coremltools 9.0 (torch 2.7.0, numpy 2.3; numpy 2.5 breaks
coremltools 9.0). The model wraps the transformer with mean pooling and
L2 normalisation, so Core ML returns the final unit vector. Input is a
fixed 128 tokens (`ids`, `mask` as Int32 [1, 128]).

| Variant | Minimum iOS | Size | Matches sentence-transformers (cosine, min) | Right first / top 3 | With title entries | Predict on Mac |
|---|---|---|---|---|---|---|
| neuralnetwork fp32 | 14 | 86 MB | 0.99997 | 6 / 7 | 7 | 0.73 ms |
| **neuralnetwork int8 weights** | **14** | **22 MB** | — | **6 / 7** | **7** | — |
| mlprogram fp16 | 15 | 43 MB | 1.00000 | 6 / 7 | 7 | 0.94 ms |
| neuralnetwork fp16 | 14 | failed: some weights can't be stored in half precision | | | | |

The int8 model ranks exactly as well as fp32 on this set.

## What it would take to run MiniLM in the plugin

The public API stays the same; only `SemanticSearchPlugin.swift`'s
`model(_:)` and its vector call change, and `VectorStore` stays as it is.

1. **Model file.** Compile the int8 `.mlmodel` to `.mlmodelc` with
   `xcrun coremlcompiler`. Ship it and `vocab.txt` in a CocoaPods
   `resource_bundles` entry, and load it with
   `MLModel(contentsOf:configuration:)`. Adds about 22 MB to the app.
   Check that a MABS 12.1 build carries the resource bundle (CocoaPods
   handles it normally).
2. **Tokenizer in Swift.** This is a BERT uncased WordPiece tokenizer
   (30,522-word vocabulary, lower-casing on): lower-case, strip accents,
   split on whitespace and punctuation, match the longest known word
   pieces, add `[CLS]`/`[SEP]`, then truncate or pad to 128. It's about
   150 lines. Hugging Face's `swift-transformers` package only installs
   through Swift Package Manager and needs a newer iOS than 14, so write
   it by hand. Add an XCTest that compares token ids with the Python
   tokenizer on 20 or so sample strings, including accents and
   punctuation.
3. **Embedding call.** Tokenise, run `prediction(from:)`, read the
   384-number output. No normalising is needed (the model already does
   it), but `VectorStore.normalise` is harmless if kept.
4. **Language and revision.** The model is English-only, so
   `isAvailable` returns true only for `en`. `revision` becomes a
   constant the plugin owns, bumped whenever the bundled model changes,
   so the existing `needsReindex` logic keeps working. Collections
   indexed with NLEmbedding (512 values per vector) are rebuilt
   automatically because the revision changes.
5. **Validation.** The example app's validation tests can now all run on
   the Simulator. Then repeat the paraphrased-query test on an iPhone for
   timing and to confirm the Mac numbers.
6. **Design changes this implies:** the original design's statement that
   the model ships with the OS, its known limits, its native plugin and
   vector-store code, the Android roadmap (same model through ONNX or
   TFLite), and the `MinScore` default. With MiniLM, correct first-place
   answers here scored 0.39–0.62, but on the misses the wrong top answer
   scored 0.25–0.55, so no single threshold separates them cleanly. Start
   at about 0.35 and tune it against real content.

## Reproducing

The scripts are in `tools/embedding-bakeoff/`; its README has the setup and run order:
- `export_data.js`: writes `data.json` from the test data in `example/www/js/data.js`.
- `apple/main.swift`: dumps NLEmbedding and NLContextualEmbedding vectors.
- `st_dump.py`: dumps MiniLM and bge vectors.
- `evaluate.py`: computes every metric above.
- `coreml_convert.py` and `coreml_quality.py`: Core ML conversion and
  checks.
