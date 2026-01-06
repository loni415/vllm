#!/bin/bash
set -euo pipefail

echo "=============================================="
echo "PyTorch Installation with CUDA 12.8 - Task 2"
echo "=============================================="

# -----------------------------------------------------------------------------
# 1) Load modules
# -----------------------------------------------------------------------------
echo "[1/5] Loading modules..."
module purge
module load miniforge/24.3.0-py3.11
module load cuda/12.8.0
echo "✓ Modules loaded"

# -----------------------------------------------------------------------------
# 2) CUDA environment variables (prefer module-provided; fallback to nvcc-derived)
# -----------------------------------------------------------------------------
echo "[2/5] Setting CUDA environment variables..."

if [ -n "${CUDA_HOME:-}" ] && [ -d "${CUDA_HOME}" ]; then
  :
elif [ -n "${CUDA_PATH:-}" ] && [ -d "${CUDA_PATH}" ]; then
  export CUDA_HOME="${CUDA_PATH}"
elif command -v nvcc >/dev/null 2>&1; then
  export CUDA_HOME="$(dirname "$(dirname "$(command -v nvcc)")")"
else
  echo "ERROR: nvcc not found; cuda/12.8.0 module may not be available on this node."
  exit 1
fi

export CUDA_PATH="$CUDA_HOME"
export PATH="$CUDA_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}"

echo "CUDA_HOME = $CUDA_HOME"
nvcc --version | sed -n '1,5p'

# -----------------------------------------------------------------------------
# 3) Activate the Task 1 uv venv (assumes ./vllm exists next to this script)
# -----------------------------------------------------------------------------
echo "[3/5] Activating Python virtual environment..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/vllm"

if [ ! -d "$VENV_DIR" ]; then
  echo "ERROR: Virtual environment not found at: $VENV_DIR"
  echo "Run Task 1 in the same directory as this script (so it creates ./vllm)."
  exit 1
fi

# shellcheck disable=SC1090
source "$VENV_DIR/bin/activate"
echo "✓ Virtual environment activated: ${VIRTUAL_ENV}"

# Verify venv is using uv's Python
python --version
# -----------------------------------------------------------------------------
# 4) Install PyTorch cu128
# -----------------------------------------------------------------------------
echo "[4/5] Installing PyTorch (cu128 wheels)..."
python -m pip install -U pip setuptools wheel
python -m pip install --index-url https://download.pytorch.org/whl/cu128 torch torchvision torchaudio
echo "✓ PyTorch installed"

# -----------------------------------------------------------------------------
# 5) Verify PyTorch + GPU
# -----------------------------------------------------------------------------
echo "[5/5] Verifying PyTorch installation..."
python - <<'PY'
import sys, torch
print("\n" + "="*50)
print("PyTorch Verification Results")
print("="*50)
print(f"Python:  {sys.version.split()[0]}")
print(f"Torch:   {torch.__version__}")
print(f"CUDA rt: {torch.version.cuda}")
print(f"CUDA available: {torch.cuda.is_available()}")

if not torch.cuda.is_available():
    raise SystemExit("ERROR: torch.cuda.is_available() is False")

print(f"Device count: {torch.cuda.device_count()}")
print(f"GPU0 name:    {torch.cuda.get_device_name(0)}")
print(f"GPU0 cc:      {torch.cuda.get_device_capability(0)}")

props = torch.cuda.get_device_properties(0)
print(f"GPU0 memory:  {props.total_memory / (1024**3):.1f} GiB")

# Simple compute test
x = torch.randn((1024, 1024), device="cuda")
y = torch.randn((1024, 1024), device="cuda")
z = x @ y
torch.cuda.synchronize()
print("GPU compute: ✓ (matmul succeeded)")

print("="*50)
print("✓ All verification checks passed!\n")
PY

echo ""
echo "=============================================="
echo "Task 2 Complete Summary"
echo "=============================================="
echo "CUDA Module: cuda/12.8.0"
echo "CUDA_HOME:   $CUDA_HOME"
echo "Venv:        $VENV_DIR"
echo "Status:      ✓ Ready for Task 3 (vLLM install)"
echo "=============================================="