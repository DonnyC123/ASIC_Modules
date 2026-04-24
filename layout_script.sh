#!/usr/bin/env bash
# Usage:
#   ./layout_script.sh <module>                # one module, no GUI, non-LVT
#   ./layout_script.sh <module> --lvt          # one module with the LVT template
#   ./layout_script.sh <module> -g|--gui       # one module with Innovus GUI
#   ./layout_script.sh all                     # every module, no GUI, stop on first failure
#   ./layout_script.sh all --lvt               # same, using the LVT template
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/flat_modules"
TEMPLATE_DEFAULT="$SCRIPT_DIR/../layout/no_lvt.tcl"
TEMPLATE_LVT="$SCRIPT_DIR/../layout/lvt.tcl"
TOP_SUFFIX="${LAY_TOP_SUFFIX:-_top}"

# Default output root (Innovus run dir per module/variant).
: "${LAY_WORK_ROOT:=$SCRIPT_DIR/../layout}"

# Where the Genus netlist came from
: "${SYN_WORK_ROOT:=$SCRIPT_DIR/../syn}"

run_one() {
  local mod="$1"
  local gui="$2"
  local lvt="$3"
  local mod_dir="$MODULES_DIR/$mod"
  local top="${mod}${TOP_SUFFIX}"

  local template variant
  if [[ "$lvt" == "1" ]]; then
    template="$TEMPLATE_LVT"
    variant="lvt"
  else
    template="$TEMPLATE_DEFAULT"
    variant="nolvt"
  fi

  local syn_out="$SYN_WORK_ROOT/$mod/$variant"
  local netlist="$syn_out/${mod}_netlist.v"
  local sdc_file="$SYN_WORK_ROOT/$mod/${mod}.sdc"

  if [[ ! -d "$mod_dir" ]]; then
    echo "ERROR: module directory not found: $mod_dir" >&2
    return 1
  fi
  if [[ ! -f "$netlist" ]]; then
    echo "ERROR: missing netlist: $netlist  (run: ./syn_script.sh $mod${lvt:+ --lvt})" >&2
    return 1
  fi
  if [[ ! -f "$sdc_file" ]]; then
    echo "ERROR: missing SDC: $sdc_file  (run: ./gen_sdc.py $mod)" >&2
    return 1
  fi
  if [[ ! -f "$template" ]]; then
    echo "ERROR: missing Innovus template: $template" >&2
    return 1
  fi

  local work="$LAY_WORK_ROOT/$mod/$variant"
  mkdir -p "$work"

  local args=(-files "$template" -log "$work/innovus.log")
  if [[ "$gui" != "1" ]]; then
    args+=(-nowin)
  fi

  echo "=================================================="
  echo "Innovus layout: $mod  (variant=$variant, gui=$gui)"
  echo "  module dir: $mod_dir"
  echo "  template  : $template"
  echo "  netlist   : $netlist"
  echo "  sdc       : $sdc_file"
  echo "  top       : $top"
  echo "  work dir  : $work"
  echo "=================================================="

  (
    cd "$work" &&
      LAY_MODULE="$mod" \
        LAY_MODULE_DIR="$mod_dir" \
        LAY_NETLIST="$netlist" \
        LAY_SDC="$sdc_file" \
        LAY_TOP="$top" \
        LAY_VARIANT="$variant" \
        innovus "${args[@]}"
  )
}

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <module|all> [-g|--gui] [--lvt]" >&2
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
  echo "All modules laid out."
else
  run_one "$target" "$gui" "$lvt"
fi
