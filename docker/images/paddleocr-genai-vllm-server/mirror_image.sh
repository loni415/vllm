#!/usr/bin/env bash
set -euo pipefail

IMAGE_DEFAULT="ccr-2vdh3abv-pub.cnc.bj.baidubce.com/paddlepaddle/paddleocr-genai-vllm-server:latest-gpu-sm120"
IMAGE="${IMAGE:-$IMAGE_DEFAULT}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARTIFACT_DIR="${ARTIFACT_DIR:-${SCRIPT_DIR}/artifacts}"

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [args]

Commands:
  pull                Pull the image ($IMAGE_DEFAULT)
  save                Pull (if needed) and export the image to ./artifacts/
  load <file>         Load an exported tarball (.tar, .tar.gz, .tar.zst)
  run [extra args...] Run the upstream container with --pull=never (uses cached image)

Environment variables:
  IMAGE         Override the upstream image reference
  ARTIFACT_DIR  Output directory for exported artifacts

Examples:
  IMAGE=$IMAGE_DEFAULT $(basename "$0") save
  $(basename "$0") load ./artifacts/paddleocr-genai-vllm-server_....tar.zst
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

get_repo_digest() {
  # Returns something like:
  #   ccr-.../paddleocr-genai-vllm-server@sha256:...
  docker image inspect --format '{{index .RepoDigests 0}}' "$IMAGE" 2>/dev/null || true
}

cmd="${1:-}"
shift || true

case "$cmd" in
  pull)
    require_cmd docker
    docker pull "$IMAGE"
    ;;

  save)
    require_cmd docker
    mkdir -p "$ARTIFACT_DIR"

    # Ensure we have the image locally.
    docker pull "$IMAGE"

    repo_digest="$(get_repo_digest)"
    short_digest=""
    if [[ -n "$repo_digest" ]]; then
      short_digest="$(echo "$repo_digest" | sed -n 's/.*@sha256:\([0-9a-f]\{12\}\).*/\1/p')"
    fi

    ts="$(date -u +%Y%m%dT%H%M%SZ)"
    base="paddleocr-genai-vllm-server_${ts}"
    if [[ -n "$short_digest" ]]; then
      base="${base}_sha256-${short_digest}"
    fi

    tar_path="${ARTIFACT_DIR}/${base}.tar"
    docker save "$IMAGE" -o "$tar_path"

    if command -v zstd >/dev/null 2>&1; then
      zstd -T0 -f "$tar_path" -o "${tar_path}.zst"
      rm -f "$tar_path"
      echo "Saved: ${tar_path}.zst"
    else
      gzip -f "$tar_path"
      echo "Saved: ${tar_path}.gz"
    fi
    ;;

  load)
    require_cmd docker
    file="${1:-}"
    if [[ -z "$file" ]]; then
      echo "Usage: $(basename "$0") load <file.tar[.gz|.zst]>" >&2
      exit 2
    fi

    if [[ "$file" == *.zst ]]; then
      require_cmd zstd
      zstd -d -c "$file" | docker load
    elif [[ "$file" == *.gz ]]; then
      gunzip -c "$file" | docker load
    else
      docker load -i "$file"
    fi
    ;;

  run)
    require_cmd docker
    docker run -it --gpus all --network host --pull=never \
      "$IMAGE" \
      paddleocr genai_server --model_name PaddleOCR-VL-0.9B --host 0.0.0.0 --port 8118 --backend vllm \
      "$@"
    ;;

  -h|--help|help|"")
    usage
    exit 0
    ;;

  *)
    echo "Unknown command: $cmd" >&2
    usage >&2
    exit 2
    ;;
esac
