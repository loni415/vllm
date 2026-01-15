# paddleocr-genai-vllm-server image (PaddleOCR GenAI server using vLLM)

Upstream image:

```
ccr-2vdh3abv-pub.cnc.bj.baidubce.com/paddlepaddle/paddleocr-genai-vllm-server:latest-gpu-sm120
```

## Running without re-contacting the registry

Docker does **not** re-pull an image on every `docker run` by default. After you pull once, subsequent runs will use your local cache.

To be explicit (and to avoid any accidental pulls), use `--pull=never`:

```bash
docker pull ccr-2vdh3abv-pub.cnc.bj.baidubce.com/paddlepaddle/paddleocr-genai-vllm-server:latest-gpu-sm120

docker run -it --gpus all --network host --pull=never \
  ccr-2vdh3abv-pub.cnc.bj.baidubce.com/paddlepaddle/paddleocr-genai-vllm-server:latest-gpu-sm120 \
  paddleocr genai_server --model_name PaddleOCR-VL-0.9B --host 0.0.0.0 --port 8118 --backend vllm
```

## Pinning to an immutable digest (recommended)

Tags like `latest-gpu-sm120` can change over time. To ensure you always run the exact same image, pin by digest:

```bash
IMAGE=ccr-2vdh3abv-pub.cnc.bj.baidubce.com/paddlepaddle/paddleocr-genai-vllm-server:latest-gpu-sm120

docker pull "$IMAGE"
DIGEST_REF=$(docker image inspect --format '{{index .RepoDigests 0}}' "$IMAGE")

echo "$DIGEST_REF"
# ccr-.../paddleocr-genai-vllm-server@sha256:...

docker run -it --gpus all --network host --pull=never \
  "$DIGEST_REF" \
  paddleocr genai_server --model_name PaddleOCR-VL-0.9B --host 0.0.0.0 --port 8118 --backend vllm
```

## Export/import for offline use

Use the helper script in this directory to export the image to a compressed tarball and later import it on another machine.

```bash
# From this directory:
./mirror_image.sh save

# On an offline machine:
./mirror_image.sh load path/to/the_saved_file.tar.zst
```

The script writes outputs under `./artifacts/` (which is gitignored).
