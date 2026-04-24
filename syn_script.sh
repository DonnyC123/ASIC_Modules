#!/usr/bin/env bash
# Usage:
#   ./syn_script.sh <module>                  # run one module, no GUI, non-LVT
#   ./syn_script.sh <module> --lvt            # run one module with the LVT template
#   ./syn_script.sh <module> -g|--gui         # run one module with Genus GUI
#   ./syn_script.sh all                       # run every module, no GUI, stop on first failure
#   ./syn_script.sh all --lvt                 # same, using the LVT template
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/flat_modules"
TEMPLATE_DEFAULT="$SCRIPT_DIR/../syn/no_lvt.tcl"
TEMPLATE_LVT="$SCRIPT_DIR/../syn/lvt.tcl"
TOP_SUFFIX="${SYN_TOP_SUFFIX:-_top}"

# Default output root is the sibling 'genus/' dir next to flat_modules/.
# Override with:  SYN_WORK_ROOT=/some/other/path ./syn_script.sh <module>
: "${SYN_WORK_ROOT:=$SCRIPT_DIR/../syn}"

run_one() {
  local mod="$1"
  local gui="$2"
  local lvt="$3"
  local mod_dir="$MODULES_DIR/$mod"
  local rtl_f="$mod_dir/${mod}_rtl.f"
  local sdc_file="$SYN_WORK_ROOT/$mod/${mod}.sdc"
  local top="${mod}${TOP_SUFFIX}"

  local template variant
  if [[ "$lvt" == "1" ]]; then
    template="$TEMPLATE_LVT"
    variant="lvt"
  else
    template="$TEMPLATE_DEFAULT"
    variant="nolvt"
  fi

  if [[ ! -d "$mod_dir" ]]; then
    echo "ERROR: module directory not found: $mod_dir" >&2
    return 1
  fi
  if [[ ! -f "$rtl_f" ]]; then
    echo "ERROR: missing RTL file list: $rtl_f" >&2
    return 1
  fi
  if [[ ! -f "$sdc_file" ]]; then
    echo "ERROR: missing SDC: $sdc_file  (run: ./gen_sdc.py $mod)" >&2
    return 1
  fi
  if [[ ! -f "$template" ]]; then
    echo "ERROR: missing Genus template: $template" >&2
    return 1
  fi

  local work="$SYN_WORK_ROOT/$mod/$variant"
  mkdir -p "$work"

  local args=(-files "$template" -log "$work/genus.log")
  if [[ "$gui" != "1" ]]; then
    args+=(-no_gui)
  fi

  echo "=================================================="
  echo "Genus synth: $mod  (variant=$variant, gui=$gui)"
  echo "  module dir: $mod_dir"
  echo "  template  : $template"
  echo "  top       : $top"
  echo "  work dir  : $work"
  echo "=================================================="

  (
    cd "$work" &&
      SYN_MODULE="$mod" \
        SYN_MODULE_DIR="$mod_dir" \
        SYN_RTL_F="$rtl_f" \
        SYN_SDC="$sdc_file" \
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
lvt="0"
while [[ $# -gt 0 ]]; do
  case "$1" in
  -g | --gui) gui="1" ;;
  --lvt) lvt="1" ;;
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
    [[ -f "$d/${mod}_rtl.f" ]] || continue
    any=1
    if ! run_one "$mod" "0" "$lvt"; then
      echo "FAILED: $mod  (stopping)" >&2
      exit 1
    fi
  done
  if [[ "$any" == "0" ]]; then
    echo "No modules found under $MODULES_DIR" >&2
    exit 1
  fi
  echo "All modules synthesized."
else
  run_one "$target" "$gui" "$lvt"
fi
