# usage: evaluate.py data.json vectors1.json [vectors2.json ...]
import json, math, re, sys, time, statistics as st
import numpy as np

d = json.load(open(sys.argv[1]))
ids = [i["id"] for i in d["items"]]; titles = [i["metadata"] for i in d["items"]]
texts = [i["text"] for i in d["items"]]
queries = [q[0] for q in d["queries"]]; expected = [ids.index(q[1]) for q in d["queries"]]
engines = {}
for p in sys.argv[2:]: engines.update(json.load(open(p)))

def unit(m):
    m = np.array(m, dtype=np.float64); return m / np.linalg.norm(m, axis=1, keepdims=True)

# --- BM25 (k1=1.2, b=0.75) over the full procedure text
STOP = set("a an the and or of to for in on at by with is are be it its this that from as when if then them up out off any all every each i my me while too not no more".split())
tok = lambda s: [w for w in re.findall(r"[a-z0-9]+", s.lower()) if w not in STOP]
dt = [tok(t) for t in texts]; N = len(dt); avg = sum(map(len, dt)) / N
df = {}
for t in dt:
    for w in set(t): df[w] = df.get(w, 0) + 1
def bm25(q):
    qs = tok(q); out = np.zeros(N)
    for j, t in enumerate(dt):
        for w in qs:
            f = t.count(w)
            if f: out[j] += math.log(1 + (N - df[w] + 0.5) / (df[w] + 0.5)) * f * 2.2 / (f + 1.2 * (0.25 + 0.75 * len(t) / avg))
    return out
t0 = time.perf_counter(); BM = np.array([bm25(q) for q in queries]); bm_ms = (time.perf_counter() - t0) * 1000 / len(queries)

minmax = lambda r: (r - r.min()) / (r.max() - r.min()) if r.max() > r.min() else np.zeros_like(r)

def metrics(S):
    top1 = top3 = 0; gaps = []; rows = []
    for qi, e in enumerate(expected):
        r = S[qi]; order = np.argsort(-r); rank = int(np.where(order == e)[0][0]) + 1
        wrong = max(r[j] for j in range(N) if j != e)
        top1 += rank == 1; top3 += rank <= 3; gaps.append(r[e] - wrong)
        rows.append((queries[qi], ids[order[0]], titles[order[0]], r[order[0]], ids[e], rank, r[e]))
    return top1, top3, gaps, rows

results = []
def add(name, S, ms, scale):
    t1, t3, g, rows = metrics(S)
    results.append(dict(name=name, top1=t1, top3=t3, gap_mean=st.mean(g), gap_median=st.median(g), gap_min=min(g), gap_max=max(g), ms=ms, scale=scale, rows=rows))

add("BM25 only (reference)", BM, bm_ms, "bm25")
for k, e in engines.items():
    Q, D, T = unit(e["queries"]), unit(e["docs"]), unit(e["titles"])
    cos = Q @ D.T; cos_t = np.maximum(cos, Q @ T.T)
    t0 = time.perf_counter()
    for _ in range(1000): Q[0] @ D.T
    dot_ms = (time.perf_counter() - t0)  # ms per search (1000 runs)
    ms = st.median(e["query_ms"]) + dot_ms
    add(f"{k}", cos, ms, "cosine")
    add(f"{k} + title entries", cos_t, ms, "cosine")
    hyb = lambda S: np.array([0.5 * minmax(S[i]) + 0.5 * minmax(BM[i]) for i in range(len(queries))])
    add(f"{k} + BM25 50/50", hyb(cos), ms + bm_ms, "hybrid 0-1")
    add(f"{k} + title entries + BM25 50/50", hyb(cos_t), ms + bm_ms, "hybrid 0-1")
    print(f"# {k}: {e['info']} | index 50 docs {e['index_ms']:.0f} ms | query embed median {st.median(e['query_ms']):.2f} ms")

print(f"\n| Config | Top-1 /10 | Top-3 /10 | Gap mean | Gap median | Gap min / max | ms/search | Score scale |")
print("|---|---|---|---|---|---|---|---|")
for r in results:
    print(f"| {r['name']} | {r['top1']} | {r['top3']} | {r['gap_mean']:+.3f} | {r['gap_median']:+.3f} | {r['gap_min']:+.3f} / {r['gap_max']:+.3f} | {r['ms']:.2f} | {r['scale']} |")
json.dump(results, open("results.json", "w"), indent=1, default=float)
