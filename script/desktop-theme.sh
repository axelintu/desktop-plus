#!/usr/bin/env bash
# Switch the Desktop Plus dark-theme palette.
#
#   desktop-theme.sh list                     Show available palettes
#   desktop-theme.sh current                  Show the palette selected in the source tree
#   desktop-theme.sh source <palette>         Select a palette for the next build (edits the source tree)
#   desktop-theme.sh installed <palette>      Re-theme an installed copy right now, no rebuild
#                    [--path <renderer.css>]  (needs sudo for system installs; restart the app after)
#
# <palette> is a file name from the palettes folder without "_" and ".scss"
# (e.g. tokyo-night-storm), or "stock" for the original GitHub Desktop colors.
# Palettes only apply when the app's theme is set to Dark (or System on a dark desktop).
#
# To add a palette: copy app/styles/themes/palettes/_tokyo-night-storm.scss to a
# new name and change the colors. Keep it plain CSS (no Sass functions).

set -euo pipefail

BEGIN_MARK='/*! desktop-theme:begin'
END_MARK='/*! desktop-theme:end */'

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
selector="$repo_root/app/styles/themes/_palette.scss"

# Palettes live in the source tree, or next to this script in the release bundle.
if [[ -d "$repo_root/app/styles/themes/palettes" ]]; then
  palette_dir="$repo_root/app/styles/themes/palettes"
elif [[ -d "$script_dir/palettes" ]]; then
  palette_dir="$script_dir/palettes"
else
  echo "Can't find the palettes folder next to this script." >&2
  exit 1
fi

die() { echo "error: $*" >&2; exit 1; }

list_palettes() {
  echo "stock"
  for f in "$palette_dir"/_*.scss; do
    [[ -e "$f" ]] || continue
    f="${f##*/_}"
    echo "${f%.scss}"
  done
}

check_palette() {
  [[ "$1" == "stock" || -f "$palette_dir/_$1.scss" ]] ||
    die "unknown palette '$1'. Available: $(list_palettes | tr '\n' ' ')"
}

cmd_current() {
  [[ -f "$selector" ]] || die "not in a source tree (no $selector)"
  local name
  name="$(sed -n "s#^@import 'palettes/\(.*\)';#\1#p" "$selector")"
  echo "${name:-stock}"
}

cmd_source() {
  local name="$1"
  check_palette "$name"
  [[ -d "$(dirname "$selector")" ]] || die "not in a source tree"
  {
    echo "// Active dark-theme palette. Managed by script/desktop-theme.sh; change with:"
    echo "//   script/desktop-theme.sh source <palette>"
    echo "// The loud comments below survive minification so an installed copy can be re-themed."
    echo "$BEGIN_MARK $name */"
    [[ "$name" == "stock" ]] || echo "@import 'palettes/$name';"
    echo "$END_MARK"
  } >"$selector"
  echo "Selected '$name' for the next build ($selector)."
}

find_renderer_css() {
  local candidates=(
    /usr/lib/desktop-plus/resources/app/renderer.css
    /opt/desktop-plus/resources/app/renderer.css
    /usr/lib/github-desktop-plus/resources/app/renderer.css
    "$HOME/.local/share/desktop-plus/resources/app/renderer.css"
  )
  for c in "${candidates[@]}"; do
    [[ -f "$c" ]] && { echo "$c"; return; }
  done
  return 1
}

cmd_installed() {
  local name="$1"; shift
  local css=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --path) css="${2:-}"; shift 2 ;;
      *) die "unknown option $1" ;;
    esac
  done
  check_palette "$name"

  if [[ -z "$css" ]]; then
    css="$(find_renderer_css)" || die "couldn't find an installed Desktop Plus. Pass --path /path/to/resources/app/renderer.css
(Flatpak and AppImage installs are read-only; for those, rebuild with 'source' instead.)"
  fi
  [[ -f "$css" ]] || die "$css does not exist"

  local tmp block
  tmp="$(mktemp)"
  block="$(mktemp)"
  trap "rm -f '$tmp' '$block'" EXIT

  {
    echo "$BEGIN_MARK $name */"
    [[ "$name" == "stock" ]] || cat "$palette_dir/_$name.scss"
    echo "$END_MARK"
  } >"$block"

  if grep -qF "$BEGIN_MARK" "$css"; then
    # Replace whatever palette is currently between the markers.
    awk -v begin="$BEGIN_MARK" -v end="$END_MARK" -v blockfile="$block" '
      index($0, begin) {
        pre = substr($0, 1, index($0, begin) - 1)
        printf "%s", pre
        while ((getline line < blockfile) > 0) print line
        skipping = 1
      }
      skipping && index($0, end) {
        rest = substr($0, index($0, end) + length(end))
        if (rest != "") print rest
        skipping = 0
        next
      }
      !skipping { print }
    ' "$css" >"$tmp"
  else
    # Older/official builds have no markers: append so these rules win.
    { cat "$css"; echo; cat "$block"; } >"$tmp"
  fi

  if [[ ! -f "$css.orig" ]]; then
    if [[ -w "$(dirname "$css")" ]]; then cp "$css" "$css.orig"; else sudo cp "$css" "$css.orig"; fi
  fi
  if [[ -w "$css" ]]; then cat "$tmp" >"$css"; else sudo tee "$css" >/dev/null <"$tmp"; fi

  echo "Applied '$name' to $css (backup at $css.orig). Restart Desktop Plus to see it."
  echo "Note: package updates overwrite this file, so run this again after updating."
}

usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

case "${1:-}" in
  list) list_palettes ;;
  current) cmd_current ;;
  source) [[ -n "${2:-}" ]] || usage 1; cmd_source "$2" ;;
  installed) [[ -n "${2:-}" ]] || usage 1; name="$2"; shift 2; cmd_installed "$name" "$@" ;;
  -h|--help|help|"") usage ;;
  *) usage 1 ;;
esac
