# Retrieval quality of converted Core ML models on the bake-off set.
import json, subprocess, numpy as np, coremltools as ct
from coremltools.models.neural_network import quantization_utils as q
from transformers import AutoTokenizer
tok = AutoTokenizer.from_pretrained("sentence-transformers/all-MiniLM-L6-v2"); SEQ = 128
d = json.load(open("data.json")); ids = [i["id"] for i in d["items"]]
q8 = q.quantize_weights(ct.models.MLModel("MiniLM_nn_ios14_fp32.mlmodel"), nbits=8)
q8.save("MiniLM_nn_ios14_int8.mlmodel")
def emb(m, t):
    e = tok([t], padding="max_length", max_length=SEQ, truncation=True, return_tensors="np")
    v = m.predict({"ids": e["input_ids"].astype(np.int32), "mask": e["attention_mask"].astype(np.int32)})["embedding"][0]
    return v / np.linalg.norm(v)
for path in ["MiniLM_nn_ios14_fp32.mlmodel", "MiniLM_nn_ios14_int8.mlmodel", "MiniLM_mlprogram_ios15_fp16.mlpackage"]:
    m = ct.models.MLModel(path)
    D = np.array([emb(m, i["text"]) for i in d["items"]]); T = np.array([emb(m, i["metadata"]) for i in d["items"]])
    t1 = t3 = t1t = 0
    for qt, exp in d["queries"]:
        qv = emb(m, qt); s = D @ qv; st = np.maximum(s, T @ qv); e = ids.index(exp)
        r = int((s > s[e]).sum()) + 1; t1 += r == 1; t3 += r <= 3; t1t += int((st > st[e]).sum()) == 0
    size = subprocess.run(["du", "-sh", path], capture_output=True, text=True).stdout.split()[0]
    print(f"{path}: size {size} | top-1 {t1}/10 top-3 {t3}/10 | with title entries top-1 {t1t}/10")
