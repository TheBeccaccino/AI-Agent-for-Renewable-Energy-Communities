"""Download the fixed public weights before offline training; no texts are transmitted."""

import argparse
import json
from pathlib import Path
from huggingface_hub import snapshot_download

MODEL = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
REV = "e8f8c211226b894fcb81acc59f3b34ba3efd5f42"
if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="weights/minilm")
    a = ap.parse_args()
    snapshot_download(
        repo_id=MODEL,
        revision=REV,
        local_dir=a.out,
        allow_patterns=["*.json", "*.txt", "*.model", "*.safetensors", "1_Pooling/*"],
        ignore_patterns=["onnx/*", "openvino/*"],
    )
    marker = Path(a.out) / "cerbot_source.json"
    marker.write_text(json.dumps({"repo_id": MODEL, "revision": REV}, indent=2), encoding="utf-8")
    print("Pinned weights saved:", MODEL, REV)
