# Converts all-MiniLM-L6-v2 (+ mean pooling + L2 norm) to Core ML and checks parity.
import json, time, os, subprocess, numpy as np, torch, coremltools as ct
from transformers import AutoModel, AutoTokenizer
from sentence_transformers import SentenceTransformer
NAME = "sentence-transformers/all-MiniLM-L6-v2"; SEQ = 128
tok = AutoTokenizer.from_pretrained(NAME); bert = AutoModel.from_pretrained(NAME, return_dict=False).eval()

class Embed(torch.nn.Module):
    def __init__(s, m): super().__init__(); s.m = m
    def forward(s, ids, mask):
        h = s.m(input_ids=ids, attention_mask=mask)[0]
        m = mask.unsqueeze(-1).to(h.dtype)
        v = (h * m).sum(1) / m.sum(1).clamp(min=1e-9)
        return torch.nn.functional.normalize(v, dim=1)

w = Embed(bert).eval()
ex = tok(["hello world"], padding="max_length", max_length=SEQ, truncation=True, return_tensors="pt")
traced = torch.jit.trace(w, (ex["input_ids"], ex["attention_mask"]))
inputs = [ct.TensorType(name="ids", shape=(1, SEQ), dtype=np.int32), ct.TensorType(name="mask", shape=(1, SEQ), dtype=np.int32)]
d = json.load(open("data.json")); texts = [i["text"] for i in d["items"]] + [q[0] for q in d["queries"]]
ref = SentenceTransformer(NAME, device="cpu").encode(texts, normalize_embeddings=True)

variants = {
  "nn_ios14_fp32": dict(convert_to="neuralnetwork", minimum_deployment_target=ct.target.iOS14),
  "nn_ios14_fp16": dict(convert_to="neuralnetwork", minimum_deployment_target=ct.target.iOS14),
  "mlprogram_ios15_fp16": dict(convert_to="mlprogram", minimum_deployment_target=ct.target.iOS15, compute_precision=ct.precision.FLOAT16),
}
for name, kw in variants.items():
    try:
        m = ct.convert(traced, inputs=inputs, outputs=[ct.TensorType(name="embedding")], **kw)
        if name == "nn_ios14_fp16":
            from coremltools.models.neural_network import quantization_utils as q
            m = q.quantize_weights(m, nbits=16)
        path = f"MiniLM_{name}." + ("mlpackage" if "mlprogram" in name else "mlmodel")
        m.save(path)
        size = subprocess.run(["du", "-sh", path], capture_output=True, text=True).stdout.split()[0]
        cos, ms = [], []
        for i, t in enumerate(texts):
            e = tok([t], padding="max_length", max_length=SEQ, truncation=True, return_tensors="np")
            t0 = time.perf_counter()
            v = m.predict({"ids": e["input_ids"].astype(np.int32), "mask": e["attention_mask"].astype(np.int32)})["embedding"][0]
            ms.append((time.perf_counter() - t0) * 1000)
            cos.append(float(np.dot(v / np.linalg.norm(v), ref[i])))
        print(f"{name}: OK size {size} | parity cosine vs sentence-transformers min {min(cos):.5f} mean {np.mean(cos):.5f} | predict median {np.median(ms[5:]):.2f} ms (Mac, all compute units)")
    except Exception as e:
        print(f"{name}: FAILED {type(e).__name__}: {str(e)[:300]}")
print("vocab.txt size", os.path.getsize(tok.vocab_file) if hasattr(tok, "vocab_file") and tok.vocab_file else "n/a", "| vocab", tok.vocab_size, "| lower", tok.do_lower_case)
