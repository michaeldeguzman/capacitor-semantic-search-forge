# usage: st_dump.py data.json out.json
import json, sys, time
from sentence_transformers import SentenceTransformer
d = json.load(open(sys.argv[1]))
docs = [i["text"] for i in d["items"]]; titles = [i["metadata"] for i in d["items"]]; queries = [q[0] for q in d["queries"]]
out = {}
for key, name in [("minilm", "sentence-transformers/all-MiniLM-L6-v2"), ("bge_small", "BAAI/bge-small-en-v1.5")]:
    m = SentenceTransformer(name, device="cpu")
    # bge recommends this prefix on queries for retrieval
    qp = "Represent this sentence for searching relevant passages: " if key == "bge_small" else ""
    enc = lambda xs: m.encode(xs, normalize_embeddings=True).tolist()
    for q in queries: enc([qp + q])  # warm-up
    qv, qms = [], []
    for q in queries:
        t = time.perf_counter(); qv.append(enc([qp + q])[0]); qms.append((time.perf_counter() - t) * 1000)
    t = time.perf_counter(); dv = enc(docs); index_ms = (time.perf_counter() - t) * 1000
    params = sum(p.numel() for p in m.parameters())
    out[key] = {"docs": dv, "titles": enc(titles), "queries": qv, "query_ms": qms, "index_ms": index_ms,
                "info": f"{name} dim {m.get_sentence_embedding_dimension()} params {params/1e6:.1f}M max_seq {m.max_seq_length} query_prefix {bool(qp)}"}
    print(out[key]["info"])
json.dump(out, open(sys.argv[2], "w"))
