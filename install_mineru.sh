#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${MINERU_VENV_DIR:-mineru}"

if [[ "$VENV_DIR" = /* ]]; then
  VENV_PATH="$VENV_DIR"
else
  VENV_PATH="${SCRIPT_DIR}/${VENV_DIR}"
fi

LOG_FILE="${SCRIPT_DIR}/mineru_install.log"

# Optional: install OS packages (requires sudo)
#   MINERU_INSTALL_SYSTEM_DEPS=1 ./install_mineru.sh
MINERU_INSTALL_SYSTEM_DEPS="${MINERU_INSTALL_SYSTEM_DEPS:-0}"

# Optional: recreate the venv if it already exists
#   MINERU_VENV_RECREATE=1 ./install_mineru.sh
MINERU_VENV_RECREATE="${MINERU_VENV_RECREATE:-0}"

# Optional: override the package spec to install
#   MINERU_PIP_SPEC='magic-pdf' ./install_mineru.sh
MINERU_PIP_SPEC="${MINERU_PIP_SPEC:-magic-pdf[full]}"

export PIP_DISABLE_PIP_VERSION_CHECK=1
export PIP_NO_INPUT=1

echo "=============================================="
echo "MinerU Installation Script"
echo "=============================================="
echo "Environment (reported):"
echo "  OS: Debian GNU/Linux (forky/sid)"
echo "  Python: $(python3 --version 2>&1 || echo 'python3 not found')"
echo "  GPU: NVIDIA GeForce RTX 5090"
echo "  Driver: 580.126.09"
echo "  Note: CUDA toolkit (nvcc) is not required for pip wheels."
echo "=============================================="
echo ""

# -----------------------------------------------------------------------------
# [1/6] Verify Python 3
# -----------------------------------------------------------------------------
echo "[1/6] Verifying Python installation..."
if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 not found."
  echo "On Debian, install it with: sudo apt-get update && sudo apt-get install -y python3"
  exit 1
fi

echo "✓ Python found: $(python3 --version 2>&1)"

# -----------------------------------------------------------------------------
# [2/6] (Optional) Install OS dependencies
# -----------------------------------------------------------------------------
echo "[2/6] Installing OS dependencies (optional)..."
if [ "$MINERU_INSTALL_SYSTEM_DEPS" = "1" ]; then
  if ! command -v sudo >/dev/null 2>&1; then
    echo "ERROR: sudo not found but MINERU_INSTALL_SYSTEM_DEPS=1 was set."
    exit 1
  fi

  echo "  Installing common PDF/OCR/runtime deps via apt..."
  sudo apt-get update
  sudo apt-get install -y \
    python3-venv python3-dev \
    build-essential pkg-config \
    poppler-utils tesseract-ocr \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1
  echo "✓ OS dependencies installed"
else
  echo "  Skipped. (Set MINERU_INSTALL_SYSTEM_DEPS=1 to enable)"
fi

# -----------------------------------------------------------------------------
# [3/6] Create virtual environment
# -----------------------------------------------------------------------------
echo "[3/6] Configuring virtual environment at '${VENV_PATH}'..."

if [ -d "$VENV_PATH" ] && [ "$MINERU_VENV_RECREATE" = "1" ]; then
  echo "  Recreating existing venv at: $VENV_PATH"
  rm -rf "$VENV_PATH"
fi

if [ ! -d "$VENV_PATH" ]; then
  set +e
  python3 -m venv "$VENV_PATH"
  VENV_EXIT=$?
  set -e

  if [ $VENV_EXIT -ne 0 ]; then
    echo "ERROR: Failed to create venv at: $VENV_PATH"
    echo "On Debian, this often means python3-venv is missing. Try:"
    echo "  sudo apt-get update && sudo apt-get install -y python3-venv"
    exit $VENV_EXIT
  fi

  echo "✓ Virtual environment created at: $VENV_PATH"
else
  echo "✓ Using existing virtual environment at: $VENV_PATH"
fi

# -----------------------------------------------------------------------------
# [4/6] Activate venv and upgrade packaging tooling
# -----------------------------------------------------------------------------
echo "[4/6] Activating virtual environment..."
# shellcheck disable=SC1090,SC1091
source "$VENV_PATH/bin/activate"

if [ -z "${VIRTUAL_ENV:-}" ]; then
  echo "ERROR: Failed to activate virtual environment"
  exit 1
fi

echo "✓ Virtual environment activated: $VIRTUAL_ENV"
echo "  Python: $(python --version 2>&1)"

echo "Upgrading pip/setuptools/wheel..."
python -m pip install --upgrade pip setuptools wheel

# -----------------------------------------------------------------------------
# [5/6] Install MinerU
# -----------------------------------------------------------------------------
echo "[5/6] Installing MinerU (pip spec: ${MINERU_PIP_SPEC})..."
echo "  Logging to: $LOG_FILE"

# Detect existing critical packages (e.g., if installing into vLLM venv) and pin them.
CONSTRAINTS_FILE="${SCRIPT_DIR}/mineru_constraints.txt"
rm -f "$CONSTRAINTS_FILE"

echo "  Checking for existing critical dependencies to protect..."
python - <<PYEOF
import sys
import importlib.metadata

critical = [
    "torch", "torchvision", "torchaudio",
    "vllm",
    "opencv-python", "opencv-python-headless",
    "numpy"
]

found = []
for pkg in critical:
    try:
        ver = importlib.metadata.version(pkg)
        found.append(f"{pkg}=={ver}")
    except importlib.metadata.PackageNotFoundError:
        pass

if found:
    with open("$CONSTRAINTS_FILE", "w") as f:
        f.write("\n".join(found) + "\n")
    print("  ✓ Found existing critical packages (pinned in constraints.txt):")
    for item in found:
        print(f"    - {item}")
else:
    print("  (No critical packages found in current venv; clean install safe)")
PYEOF

PIP_ARGS=""
if [ -f "$CONSTRAINTS_FILE" ]; then
  PIP_ARGS="-c $CONSTRAINTS_FILE"
fi

# `[...]` extras must be quoted to avoid shell globbing.
# If MinerU wheels are not available for Python 3.13 yet, consider using Python 3.11/3.12.
# shellcheck disable=SC2086
python -m pip install --upgrade "${MINERU_PIP_SPEC}" $PIP_ARGS 2>&1 | tee "$LOG_FILE"

rm -f "$CONSTRAINTS_FILE"
echo "✓ MinerU install step finished"

# -----------------------------------------------------------------------------
# [6/6] Verify installation
# -----------------------------------------------------------------------------
echo "[6/6] Verifying MinerU installation..."
set +e
python - <<'PYEOF'
import sys

print("\n" + "=" * 60)
print("MinerU Verification")
print("=" * 60)
print("Python:", sys.version.split()[0])

ok = False

# MinerU is commonly distributed as `magic-pdf` (import name `magic_pdf`).
try:
    import magic_pdf  # type: ignore
    print("✓ Imported: magic_pdf")
    ok = True
except Exception as e:
    print("✗ Could not import magic_pdf:", e)

# Some distributions may expose a `mineru` import.
try:
    import mineru  # type: ignore
    print("✓ Imported: mineru")
    ok = True
except Exception as e:
    print("(info) Could not import mineru:", e)

print("\nKey installed packages:")
import subprocess
out = subprocess.check_output([sys.executable, "-m", "pip", "list", "--format=freeze"], text=True)
for line in out.splitlines():
    low = line.lower()
    if any(k in low for k in ("magic-pdf", "magic_pdf", "mineru", "paddle", "torch", "onnx", "opencv")):
        print(" ", line)

print("=" * 60)

if not ok:
    raise SystemExit(1)
PYEOF
VERIFY_EXIT=$?
set -e

if [ $VERIFY_EXIT -ne 0 ]; then
  echo "ERROR: MinerU verification failed. Check the install log: $LOG_FILE"
  exit $VERIFY_EXIT
fi

echo ""
echo "=============================================="
echo "MinerU Installation Complete"
echo "=============================================="
echo "Venv: $VENV_PATH"
echo "To activate:"
# Prefer a relative activation hint if the user ran from this directory.
echo "  source ${VENV_DIR}/bin/activate"
echo "Log:  $LOG_FILE"
echo ""
echo "CLI help (if provided by the package):"
echo "  magic-pdf --help || true"
echo "=============================================="
