#!/usr/bin/env bash
# Usage:
#   ./syn_script.sh <module>            # run one module, no GUI
#   ./syn_script.sh <module> -g|--gui   # run one module with Genus GUI
#   ./syn_script.sh all                 # run every module, no GUI, stop on first failure
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/syn_template.tcl"
TOP_SUFFIX="${SYN_TOP_SUFFIX:-_top}"

run_one() {
  local mod="$1"
  local gui="$2"
  local mod_dir="$SCRIPT_DIR/$mod"
  local rtl_f="$mod_dir/${mod}_rtl.f"
  local top="${mod}${TOP_SUFFIX}"

  if [[ ! -d "$mod_dir" ]]; then
    echo "ERROR: module directory not found: $mod_dir" >&2
    return 1
  fi
  if [[ ! -f "$rtl_f" ]]; then
    echo "ERROR: missing RTL file list: $rtl_f" >&2
    return 1
  fi
  if [[ ! -f "$TEMPLATE" ]]; then
    echo "ERROR: missing Genus template: $TEMPLATE" >&2
    return 1
  fi

  local work
  if [[ -n "${SYN_WORK_ROOT:-}" ]]; then
    work="$SYN_WORK_ROOT/$mod"
  else
    work="$mod_dir/syn_out"
  fi
  mkdir -p "$work"

  local args=(-files "$TEMPLATE" -log "$work/genus.log")
  if [[ "$gui" != "1" ]]; then
    args+=(-no_gui)
  fi

  echo "=================================================="
  echo "Genus synth: $mod  (gui=$gui)"
  echo "  module dir: $mod_dir"
  echo "  top       : $top"
  echo "  work dir  : $work"
  echo "=================================================="

  (
    cd "$work" &&
      SYN_MODULE="$mod" \
        SYN_MODULE_DIR="$mod_dir" \
        SYN_RTL_F="$rtl_f" \
        SYN_TOP="$top" \
        genus "${args[@]}"
  )
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
  for d in "$SCRIPT_DIR"/*/; do
    mod="$(basename "$d")"
    [[ -f "$d/${mod}_rtl.f" ]] || continue
    any=1
    if ! run_one "$mod" "0"; then
      echo "FAILED: $mod  (stopping)" >&2
      exit 1
    fi
  done
  if [[ "$any" == "0" ]]; then
    echo "No modules found under $SCRIPT_DIR" >&2
    exit 1
  fi
  echo "All modules synthesized."
else
  run_one "$target" "$gui"
fi
