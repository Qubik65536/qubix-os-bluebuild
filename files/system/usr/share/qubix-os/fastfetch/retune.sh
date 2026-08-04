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
# Print the logo with no modules and read the gutter out of what fastfetch draws.
# HOW it draws it changed in fastfetch 2.64.0, which reworked built-in logo
# printing to go line by line (DD-042):
#
#   <= 2.63   the logo is drawn as a block, then the cursor is stepped back up
#             and across:  ESC[1G ESC[<h>A ESC[<gutter>C
#   >= 2.64   logo and modules share a line, and the gutter is <gutter> literal
#             spaces at the start of it
#
# Both are read, old form first. Whichever answers is the gutter; they agree
# where both are available (measured on 2.61.0 and 2.66.0: fedora 44,
# fedora_small 22, unknown 36, arch 43).
#
# `--logo-padding-top 1` is what makes the new form exact: it pushes the logo
# down a line, so the first line of output is the gutter and nothing else. Read
# without it, that line also carries the logo's first row, and the gutter would
# have to be recovered by counting art — wrong the moment a logo uses a glyph
# that is not one byte and one column wide.
ERR=$(mktemp) || { echo "retune: could not create a temporary file" >&2; exit 1; }
trap 'rm -f "$ERR"' EXIT INT TERM

OUT=$(fastfetch --pipe false -c "$CONFIG" --logo-padding-top 1 --structure Break \
          2>"$ERR") || true

# Old form: an explicit cursor step, anywhere in the output.
GUTTER=$(printf '%s\n' "$OUT" |
         LC_ALL=C awk '{ if (match($0, /\033\[[0-9]+C/)) {
                            print substr($0, RSTART+2, RLENGTH-3); exit } }')

# New form: the first line that is nothing but escapes and spaces. Logo lines
# carry art, so they are skipped; the module line is pure gutter.
[ -n "$GUTTER" ] || GUTTER=$(printf '%s\n' "$OUT" | LC_ALL=C awk '
  { line = $0; col = 0
    while (length(line) > 0) {
      if (match(line, /^\033\[[0-9;?]*[a-zA-Z]/)) {          # any escape
        fin = substr(line, RSTART + RLENGTH - 1, 1)
        num = substr(line, 3, RLENGTH - 3) + 0
        if (fin == "C") col += (num == 0 ? 1 : num)          # cursor forward
        else if (fin == "G") col = (num == 0 ? 0 : num - 1)  # absolute column
        line = substr(line, RLENGTH + 1)
      } else if (substr(line, 1, 1) == " ") {
        col++; line = substr(line, 2)
      } else { col = 0; break }                              # art: not this line
    }
    if (col > 0) { print col; exit } }')

case "${GUTTER:-}" in
  ''|*[!0-9]*)
    echo "retune: could not measure the logo gutter" >&2
    echo "retune: no cursor step (fastfetch <= 2.63) and no leading spaces" >&2
    echo "retune: (fastfetch >= 2.64) in the output of" >&2
    echo "retune:   fastfetch --pipe false -c $CONFIG \\" >&2
    echo "retune:       --logo-padding-top 1 --structure Break" >&2
    if [ -s "$ERR" ]; then
        echo "retune: fastfetch said:" >&2
        sed 's/^/retune:   /' "$ERR" >&2
    fi
    echo "retune: run that command by hand to see what it prints. If fastfetch" >&2
    echo "retune: has changed how it draws the gutter again, the four columns" >&2
    echo "retune: are gutter+1 (spine), +7 (label), +17 (separator), +68 (right)." >&2
    exit 1 ;;
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
