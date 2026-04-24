#!/usr/bin/env bash
#
# Run Cadence Xcelium on a flattened module.
# Usage:
#   ./test_script.sh <module>            # run one module, no GUI
#   ./test_script.sh <module> -g|--gui   # run one module with SimVision GUI
#   ./test_script.sh all                 # run every module, no GUI, stop on first failure
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/flat_modules"

run_one() {
  local mod="$1"
  local gui="$2"
  local dir="$MODULES_DIR/$mod"

  if [[ ! -d "$dir" ]]; then
    echo "ERROR: module directory not found: $dir" >&2
    return 1
  fi

  local rtl_f="${mod}_rtl.f"
  local tb_f="${mod}_tb.f"
  local tb_sv="${mod}_tb.sv"

  for f in "$rtl_f" "$tb_f" "$tb_sv"; do
    if [[ ! -f "$dir/$f" ]]; then
      echo "ERROR: missing $f in $dir" >&2
      return 1
    fi
  done

  # Grep out the testbench moudle name
  local tb_top
  tb_top="$(grep -oE '^[[:space:]]*module[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' "$dir/$tb_sv" |
    head -1 | awk '{print $2}')"
  if [[ -z "$tb_top" ]]; then
    echo "ERROR: could not find 'module <name>' in $tb_sv" >&2
    return 1
  fi

  local xrun_args=(
    -sv
    -timescale 1ns/1ps
    -access +rwc
    -top "$tb_top"
    -f "$rtl_f"
    -f "$tb_f"
  )

  if [[ "$gui" == "1" ]]; then
    xrun_args+=(-gui)
  fi

  echo "=================================================="
  echo "Running Xcelium: $mod  (gui=$gui)"
  echo "  dir: $dir"
  echo "  top: $tb_top"
  echo "=================================================="

  (cd "$dir" && xrun "${xrun_args[@]}")
}

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <module|all> [-g|--gui]" >&2
  exit 1
fi

target="$1"
shift

gui="0"
while [[ $# -gt 0 ]]; do
  case "$1" in
  -g | --gui) gui="1" ;;
  *)
    echo "Unknown arg: $1" >&2
    exit 1
    ;;
  esac
  shift
done

if [[ "$target" == "all" ]]; then
  if [[ "$gui" == "1" ]]; then
    echo "ERROR: --gui is not supported with 'all'." >&2
    exit 1
  fi
  shopt -s nullglob
  any=0
  for d in "$MODULES_DIR"/*/; do
    mod="$(basename "$d")"

    # only dirs that look like a module (have an _rtl.f)
    [[ -f "$d/${mod}_rtl.f" ]] || continue
    any=1
    if ! run_one "$mod" "0"; then
      echo "FAILED: $mod  (stopping)" >&2
      exit 1
    fi
  done
  if [[ "$any" == "0" ]]; then
    echo "No modules found under $MODULES_DIR" >&2
    exit 1
  fi
  echo "All modules passed."
else
  run_one "$target" "$gui"
fi
