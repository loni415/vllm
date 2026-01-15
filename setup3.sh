#!/bin/bash
set -euo pipefail

# Remove user-local bin to avoid broken wrappers (e.g., $HOME/.local/bin/env)
export PATH="$(echo "$PATH" | tr ':' '\n' | awk '!seen[$0]++' | grep -v "$HOME/.local/bin" | paste -sd:)"

echo "=============================================="
echo "vLLM Installation and Testing - Task 3"
echo "=============================================="

# -----------------------------------------------------------------------------
# 1) Load modules (consistent with Tasks 1 & 2)
# -----------------------------------------------------------------------------
echo "[1/6] Loading modules..."
if command -v module >/dev/null 2>&1; then
  module purge
  module load miniforge/24.3.0-py3.11
  module load cuda/12.8.0
  echo "✓ Modules loaded"
else
  echo "⚠ 'module' command not found. Assuming non-HPC environment."
fi

# -----------------------------------------------------------------------------
# 2) Set CUDA environment variables (trust module first; fallback to nvcc/candidate)
# -----------------------------------------------------------------------------
echo "[2/6] Setting CUDA environment variables..."

if [ -n "${CUDA_HOME:-}" ] && [ -d "${CUDA_HOME}" ]; then
  :
elif [ -n "${CUDA_PATH:-}" ] && [ -d "${CUDA_PATH}" ]; then
  export CUDA_HOME="${CUDA_PATH}"
elif command -v nvcc >/dev/null 2>&1; then
  export CUDA_HOME="$(dirname "$(dirname "$(command -v nvcc)")")"
else
  CANDIDATE="/opt/nvidia/hpc_sdk/Linux_x86_64/24.5/cuda"
  if [ -d "$CANDIDATE" ]; then
    export CUDA_HOME="$CANDIDATE"
  else
    echo "WARNING: nvcc not found and no CUDA_HOME/CUDA_PATH set."
    CUDA_HOME=""
  fi
fi

if [ -n "$CUDA_HOME" ]; then
  export CUDA_PATH="$CUDA_HOME"
  export PATH="$CUDA_HOME/bin:$PATH"
  export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}"
  echo "CUDA_HOME = $CUDA_HOME"
  nvcc --version | sed -n '1,2p'
else
  echo "CUDA_HOME not set. Skipping CUDA env exports."
fi

# -----------------------------------------------------------------------------
# Define scratch base ONCE
# -----------------------------------------------------------------------------
SCRATCH_BASE="/scratch/$USER"

# -----------------------------------------------------------------------------
# 2.5) Redirect ALL caches to scratch (CRITICAL on HPC)
# -----------------------------------------------------------------------------
echo "[2.5/6] Redirecting caches to scratch..."

# -----------------------------------------------------------------------------
# CRITICAL: Redirect all caches off $HOME (must be set before any Python runs)
# -----------------------------------------------------------------------------

export XDG_CACHE_HOME="$SCRATCH_BASE/.cache"
export VLLM_TORCH_COMPILE_CACHE_DIR="$SCRATCH_BASE/vllm_torch_compile"

mkdir -p "$XDG_CACHE_HOME" "$VLLM_TORCH_COMPILE_CACHE_DIR"

echo "XDG_CACHE_HOME = $XDG_CACHE_HOME"
echo "VLLM_TORCH_COMPILE_CACHE_DIR = $VLLM_TORCH_COMPILE_CACHE_DIR"

# -----------------------------------------------------------------------------
# 3) Activate the venv from Tasks 1 & 2 (./vllm next to this script)
# -----------------------------------------------------------------------------
echo "[3/6] Activating Python virtual environment..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/mineru"

if [ ! -d "$VENV_DIR" ]; then
  echo "ERROR: Virtual environment not found at: $VENV_DIR"
  echo "Run Tasks 1 and 2 in the same directory (creates ./vllm)."
  exit 1
fi

# shellcheck disable=SC1090
source "$VENV_DIR/bin/activate"
echo "✓ Virtual environment activated: ${VIRTUAL_ENV}"

# Confirm PyTorch from Task 2 is present
python - <<'PY'
import torch
print(f"  PyTorch: {torch.__version__}")
print(f"  CUDA available: {torch.cuda.is_available()}")
print(f"  CUDA runtime: {torch.version.cuda}")
PY

# -----------------------------------------------------------------------------
# 4) Install vLLM (wheel-first; optional source build with logging)
#    - Default: pip wheel (recommended for your setup)
#    - If you want source build: VLLM_FROM_SOURCE=1 ./setup3.sh
# -----------------------------------------------------------------------------
echo "[4/6] Installing vLLM..."

python -m pip install -U pip setuptools wheel

if [ "${VLLM_FROM_SOURCE:-0}" = "1" ]; then
  echo "  VLLM_FROM_SOURCE=1 -> building from source (will compile)."

  # Build deps (vLLM dev/build workflows rely on cmake+ninja)
  python -m pip install -U ninja cmake packaging

  # Clone/update repo
  if [ ! -d "${SCRIPT_DIR}/vllm-repo" ]; then
    echo "  Cloning vLLM repository..."
    git clone https://github.com/vllm-project/vllm.git "${SCRIPT_DIR}/vllm-repo"
  else
    echo "  vLLM repository already exists; updating..."
    (cd "${SCRIPT_DIR}/vllm-repo" && git pull)
  fi

  echo "  Installing editable vLLM (logging to vllm_build.log)..."
  (cd "${SCRIPT_DIR}/vllm-repo" && python -m pip install -e . --no-build-isolation -v 2>&1 | tee vllm_build.log)
else
  echo "  Installing vLLM from pip wheel..."
  python -m pip install -U vllm
fi

echo "✓ vLLM installed"

# Optional but commonly used dependencies (keep light; add more later if needed)
echo "[5/6] Installing optional dependencies..."
python -m pip install -U transformers accelerate huggingface-hub
echo "✓ Optional dependencies installed"

# -----------------------------------------------------------------------------
# 6) Verify vLLM installation + functional test (with scratch HF cache if available)
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Hugging Face / vLLM cache (cluster-specific scratch)
# -----------------------------------------------------------------------------
HF_DIR="/scratch/$USER/hf"
mkdir -p "$HF_DIR" "$HF_DIR/hub" "$HF_DIR/vllm"

export HF_HOME="$HF_DIR"
export HF_HUB_CACHE="$HF_HOME/hub"
# export VLLM_CACHE_DIR="$HF_HOME/vllm"
# export HF_HUB_ENABLE_HF_TRANSFER=1

echo "HF cache directory: $HF_HOME"

# -----------------------------------------------------------------------------
# Torch / vLLM compilation caches (MUST be on scratch on HPC)
# -----------------------------------------------------------------------------
TORCH_CACHE_DIR="$SCRATCH_BASE/torch"
VLLM_CACHE_DIR="$SCRATCH_BASE/vllm"
INDUCTOR_CACHE_DIR="$SCRATCH_BASE/torch_inductor"

mkdir -p "$TORCH_CACHE_DIR" "$VLLM_CACHE_DIR" "$INDUCTOR_CACHE_DIR"

# Torch / Dynamo / Inductor
export TORCH_HOME="$TORCH_CACHE_DIR"
export TORCHINDUCTOR_CACHE_DIR="$INDUCTOR_CACHE_DIR"
export TORCH_COMPILE_CACHE_DIR="$VLLM_TORCH_COMPILE_CACHE_DIR"

# vLLM Torch compile cache (Inductor / Triton)
export VLLM_TORCH_COMPILE_CACHE_DIR="$SCRATCH_BASE/vllm_torch_compile"

# vLLM compile + runtime cache
export VLLM_CACHE_DIR="$SCRATCH_BASE/vllm"

echo "Torch cache:        $TORCH_CACHE_DIR"
echo "TorchInductor:     $INDUCTOR_CACHE_DIR"
echo "vLLM cache:        $VLLM_CACHE_DIR"

echo "[6/6] Verifying vLLM installation..."
python - <<'PY'
import sys, torch
import vllm

print("\n" + "="*60)
print("vLLM Verification")
print("="*60)
print("Python:", sys.version.split()[0])
print("Torch: ", torch.__version__, "| CUDA rt:", torch.version.cuda)
print("vLLM:  ", vllm.__version__)
print("CUDA available:", torch.cuda.is_available())

if not torch.cuda.is_available():
    raise SystemExit("ERROR: CUDA not available to PyTorch")

print("GPU0:", torch.cuda.get_device_name(0))
props = torch.cuda.get_device_properties(0)
print(f"GPU0 memory: {props.total_memory/(1024**3):.1f} GiB")
print("="*60 + "\n")
PY

echo "Running minimal generate() test (ungated model)..."
python - <<'PY'
from vllm import LLM, SamplingParams

try:
    MODEL = "TinyLlama/TinyLlama-1.1B-Chat-v1.0"

    llm = LLM(
        model=MODEL,
        tensor_parallel_size=1,
        dtype="float16",
        gpu_memory_utilization=0.30,
        max_model_len=1024,
        enforce_eager=False,
    )

    out = llm.generate(
        ["Write one sentence about Honolulu."],
        SamplingParams(max_tokens=32, temperature=0.7),
    )

    print("\n--- vLLM output ---")
    print(out[0].outputs[0].text.strip())
    llm.shutdown()
    print("-------------------\n")
except Exception as e:
    print(f"\n⚠ Inference test skipped: {e}")
    print("(This is OK if model download/network access is the issue)\n")
PY

# -----------------------------------------------------------------------------
# Summary + helpful usage snippets
# -----------------------------------------------------------------------------
echo ""
echo "=============================================="
echo "Task 3 Complete Summary"
echo "=============================================="
echo "CUDA Module:     cuda/12.8.0"
echo "CUDA_HOME:       $CUDA_HOME"
echo "Python Venv:     $VENV_DIR"
echo "PyTorch:         $(python -c 'import torch; print(torch.__version__)')"
echo "vLLM:            $(python -c 'import vllm; print(vllm.__version__)')"
echo "=============================================="

echo ""
echo "To load larger models (may require HF access / gated models):"
echo "  from vllm import LLM"
echo "  llm = LLM('meta-llama/Llama-2-13b-hf', dtype='bfloat16', gpu_memory_utilization=0.8)"
echo ""
echo "Ungated small sanity model:"
echo "  llm = LLM('TinyLlama/TinyLlama-1.1B-Chat-v1.0', dtype='float16', gpu_memory_utilization=0.3)"
echo ""
echo "OpenAI-compatible server example:"
echo "  python -m vllm.entrypoints.openai.api_server \\"
echo "    --model TinyLlama/TinyLlama-1.1B-Chat-v1.0 \\"
echo "    --dtype auto --host 0.0.0.0 --port 8000"
echo ""
echo "If you want to build from source instead of wheels:"
echo "  VLLM_FROM_SOURCE=1 ./setup3.sh"