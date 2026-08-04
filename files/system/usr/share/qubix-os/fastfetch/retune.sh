#!/bin/sh
# Re-tune a fastfetch config.jsonc to the logo it draws.
#
# Read by: nothing — this is a tool you run by hand, after changing the "source"
#          in a copy of /etc/fastfetch/config.jsonc. See docs/shell.md.
#
# The box in that config is drawn with absolute cursor columns, so it has to know
# where the logo ends. The shipped config is tuned for the full `fedora` mark
# (38 wide, +2 left +4 right padding = a 44-column gutter); other logos differ
# (fedora_small 16, debian 27, manjaro 28, mint 30, gentoo/rocky 35, arch 37,
# ubuntu/nixos 43, kali 48 …). This measures the real gutter and rewrites the four
# column numbers — nothing else about the layout changes.
#
#   usage:  retune.sh [-n] [config]
#
#           -n        show what it would do, change nothing
#           config    defaults to ${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch/config.jsonc
#
# Tune YOUR copy, not the system one: /etc/fastfetch/config.jsonc is replaced by
# every image update, so edits there are lost on the next rebase.
#
#   cp /etc/fastfetch/config.jsonc ~/.config/fastfetch/config.jsonc
#
# The box is 68 columns wide, so the terminal must be at least gutter+68 wide.
set -eu

# ── arguments ────────────────────────────────────────────────────────────────
DRY=0
if [ "${1:-}" = "-n" ]; then
    DRY=1
    shift
fi
CONFIG="${1:-${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch/config.jsonc}"

command -v fastfetch >/dev/null || { echo "retune: fastfetch not found" >&2; exit 1; }
command -v perl >/dev/null || { echo "retune: perl not found" >&2; exit 1; }
[ -f "$CONFIG" ] || { echo "retune: $CONFIG not found" >&2; exit 1; }

# ── measure ──────────────────────────────────────────────────────────────────
# Print the logo with no modules; fastfetch emits ESC[<gutter>C to step past it.
GUTTER=$(fastfetch --pipe false -c "$CONFIG" --structure Break 2>/dev/null |
         LC_ALL=C awk '{ if (match($0, /\033\[[0-9]+C/)) {
                            print substr($0, RSTART+2, RLENGTH-3); exit } }')

case "${GUTTER:-}" in
  ''|*[!0-9]*) echo "retune: could not measure the logo gutter" >&2; exit 1 ;;
esac

# Layout, all derived from the gutter.
SPINE=$((GUTTER + 1))   # left  │
LABEL=$((SPINE + 6))    # first letter of every label
SEP=$((SPINE + 16))     # separator ·
RIGHT=$((SPINE + 67))   # right │
VAL=$((SEP + 3))        # first column a value can occupy

# Current values, read back out of the config.
OLD=$(LC_ALL=C awk '
  function cha(s,   v) { v = ""
      if (match(s, /\\u001b\[[0-9]+G/)) v = substr(s, RSTART+7, RLENGTH-8)
      return v }
  /"separator": / && sep == "" { sep = cha($0) }
  /"key": / && right == "" { n = 0; s = $0
      while (match(s, /\\u001b\[[0-9]+G/)) {
        n++; col[n] = substr(s, RSTART+7, RLENGTH-8)
        s = substr(s, RSTART+RLENGTH) }
      if (n >= 3) { right = col[1]; spine = col[2]; label = col[3] } }
  END { print right, spine, label, sep }
' "$CONFIG")

set -- $OLD
O_RIGHT=${1:-}; O_SPINE=${2:-}; O_LABEL=${3:-}; O_SEP=${4:-}
[ -n "$O_SEP" ] || { echo "retune: could not parse current columns" >&2; exit 1; }

# ── report ───────────────────────────────────────────────────────────────────
printf 'config      : %s\n' "$CONFIG"
printf 'logo gutter : %s columns\n' "$GUTTER"
printf 'spine       : %-4s -> %s\n' "$O_SPINE" "$SPINE"
printf 'label       : %-4s -> %s\n' "$O_LABEL" "$LABEL"
printf 'separator   : %-4s -> %s\n' "$O_SEP"   "$SEP"
printf 'right       : %-4s -> %s\n' "$O_RIGHT" "$RIGHT"
printf 'terminal    : needs %s columns\n' "$RIGHT"

[ "$DRY" = 1 ] && exit 0
[ "$O_SPINE" = "$SPINE" ] && [ "$O_RIGHT" = "$RIGHT" ] && { echo "already tuned"; exit 0; }

# ── rewrite ──────────────────────────────────────────────────────────────────
cp "$CONFIG" "$CONFIG.bak"

# Substitute via placeholders so a new value can't collide with an old one.
# The ─ runs in the rule lines need no edit: spine and right shift together,
# so the gap between them is unchanged.
O_RIGHT=$O_RIGHT O_SPINE=$O_SPINE O_LABEL=$O_LABEL O_SEP=$O_SEP \
RIGHT=$RIGHT SPINE=$SPINE LABEL=$LABEL SEP=$SEP GUTTER=$GUTTER VAL=$VAL \
perl -pi -e '
  my %map = ("$ENV{O_RIGHT}" => "\0R\0", "$ENV{O_SPINE}" => "\0S\0",
             "$ENV{O_LABEL}" => "\0L\0", "$ENV{O_SEP}"   => "\0P\0");
  s/\\u001b\[(\d+)G/exists $map{$1} ? "\\u001b[$map{$1}G" : "\\u001b[${1}G"/ge;
  s/\0R\0/$ENV{RIGHT}/g; s/\0S\0/$ENV{SPINE}/g;
  s/\0L\0/$ENV{LABEL}/g; s/\0P\0/$ENV{SEP}/g;

  # keep the documentation block honest
  s{^//   col\s+\d+   left spine}{sprintf "//   col %3d   left spine", $ENV{SPINE}}e;
  s{^//   col\s+\d+   label start}{sprintf "//   col %3d   label start", $ENV{LABEL}}e;
  s{^//   col\s+\d+   separator}{sprintf "//   col %3d   separator", $ENV{SEP}}e;
  s{^//   col\s+\d+   right spine}{sprintf "//   col %3d   right spine", $ENV{RIGHT}}e;
  s/= logo gutter \(\d+\) \+ 1/= logo gutter ($ENV{GUTTER}) + 1/;
  s/jumps to col \d+ to draw/jumps to col $ENV{RIGHT} to draw/;
  s/comes back to \d+$/comes back to $ENV{SPINE}/;
  s/then jumps to \d+ for the label/then jumps to $ENV{LABEL} for the label/;
  s/terminal \xe2\x89\xa5 \d+ columns/terminal \xe2\x89\xa5 $ENV{RIGHT} columns/;
  s{Values get cols \d+\xe2\x80\x93\d+ \(\d+ chars\)}
   {sprintf "Values get cols %d\xe2\x80\x93%d (%d chars)", $ENV{VAL}, $ENV{RIGHT}-1, $ENV{RIGHT}-$ENV{VAL}}e;
' "$CONFIG"

echo "rewrote $CONFIG (backup: $CONFIG.bak)"
