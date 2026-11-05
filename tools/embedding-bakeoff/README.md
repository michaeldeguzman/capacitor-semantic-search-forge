# Embedding bake-off scripts

Reproduce `docs/embedding-bakeoff.md`. Run everything from this folder
on a Mac (Apple Silicon, macOS 14+ for NLContextualEmbedding).

Prerequisites: Xcode (or the Xcode command-line tools) for `swiftc`, Node
for `export_data.js`, and Python 3 (tested with 3.13). The first run needs
network access: the MiniLM and bge models download from Hugging Face, and
NLContextualEmbedding downloads its assets if they are missing.

## 1. Test data

```bash
node export_data.js            # writes data.json from example/www/js/data.js
```

## 2. Apple engines (NLEmbedding, NLContextualEmbedding)

```bash
swiftc -O apple/main.swift -o apple/apple
./apple/apple data.json apple_vectors.json
```

NLContextualEmbedding downloads its assets on first use if they are missing.

## 3. MiniLM and bge-small (quality only)

```bash
python3 -m venv venv
./venv/bin/pip install -r requirements-eval.txt
./venv/bin/python st_dump.py data.json st_vectors.json
```

## 4. Metrics

```bash
./venv/bin/python evaluate.py data.json apple_vectors.json st_vectors.json
```

Prints the results table and writes `results.json` (per-query rows).

## 5. Core ML conversion of MiniLM

Use a separate venv: coremltools 9.0 needs torch 2.7.0 and numpy < 2.4
(numpy 2.5 fails inside the converter).

```bash
python3 -m venv venv_ct
./venv_ct/bin/pip install -r requirements-coreml.txt
./venv_ct/bin/python coreml_convert.py   # fp32 (iOS 14), fp16 mlprogram (iOS 15), parity check
./venv_ct/bin/python coreml_quality.py   # int8 (iOS 14) + retrieval quality of each variant
```

Outputs (`*.mlmodel`, `*.mlpackage`, JSON) are git-ignored.
