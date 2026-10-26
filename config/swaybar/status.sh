#!/bin/sh
# ~/.config/swaybar/status.sh - the right side of swaybar
#
# speaks the i3bar protocol (man 7 swaybar-protocol): first a header,
# then "[", then one JSON array of blocks per update, forever:
#   󰕾 50%   󰖩   bat 87%   21.10  14:05
# with click_events swaybar also writes every click on a block
# to our stdin; a click on the wifi icon opens iwctl

# no "set -e": one failed check must not kill the whole bar
set -u

# the same colors as ~/.config/sway/colors
# (this script can't read sway's $variables)
white='#e6e6e6'
gray='#5a5a5a'

# block NAME TEXT COLOR: one block of the bar as a JSON object.
# NAME is how a click finds its block. No separator line between blocks,
# just a 20 px gap
block() {
    printf '{"name":"%s","full_text":"%s","color":"%s","separator":false,"separator_block_width":20}' \
        "$1" "$2" "$3"
}

# net: wifi icon (nerd font: U+F05A9 nf-md-wifi), white if some network
# interface is up, crossed out gray (U+F05AA nf-md-wifi_off) if none.
# /sys/class/net has one directory per interface; operstate is "up" or "down"
net() {
    local dev
    for dev in /sys/class/net/*; do
        [ "${dev##*/}" = "lo" ] && continue
        if [ "$(cat "$dev/operstate" 2>/dev/null)" = "up" ]; then
            block net '󰖩' "$white"
            return
        fi
    done
    block net '󰖪' "$gray"
}

# bat: battery charge, only if the machine has a battery (laptop).
# prints the block with a "," after it, so nothing at all on a desktop
bat() {
    local b
    for b in /sys/class/power_supply/BAT*; do
        [ -r "$b/capacity" ] || continue
        block bat "bat $(cat "$b/capacity")%" "$gray"
        printf ','
        return
    done
}

# vol: volume of the default output. wpctl prints "Volume: 0.50"
# or "Volume: 0.50 [MUTED]"; awk turns 0.50 into 50.
# icon U+F057E nf-md-volume_high white, or U+F0581 nf-md-volume_off gray
# when muted or when pipewire is not running (wpctl fails)
vol() {
    local out
    if ! out=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null); then
        block vol '󰖁' "$gray"
        return
    fi
    case "$out" in
        *MUTED*) block vol '󰖁' "$gray" ;;
        *) block vol "󰕾 $(echo "$out" | awk '{printf "%.0f%%", $2 * 100}')" "$white" ;;
    esac
}

clock() {
    block clock "$(date +'%d.%m  %H:%M')" "$white"
}

# a new array every 5 seconds; the "," after it continues the endless array
status_loop() {
    while :; do
        printf '[%s,%s,%s%s],\n' "$(vol)" "$(net)" "$(bat)" "$(clock)"
        sleep 5
    done
}

# the header turns on click events, "[" opens the endless array
printf '{"version":1,"click_events":true}\n[\n'

# the status loop runs in the background (&); $! is its pid.
# when the script ends (bar closed, sway reloaded) the EXIT trap stops it.
# a kill (TERM) or Ctrl+C (INT) is turned into a normal exit, which fires
# the EXIT trap (the same trick as in install.sh)
status_loop &
loop_pid=$!
trap 'kill "$loop_pid" 2>/dev/null' EXIT
trap 'exit' INT TERM

# the clicks are read here, in the foreground: in sh a background job gets
# /dev/null as its stdin, so it would never see them.
# one click = one JSON line like {"name":"net","button":1,...};
# the pattern doesn't care about spaces in it. swaymsg exec makes sway
# start iwctl, so it doesn't depend on this script
while read -r click; do
    case "$click" in
        *'"name"'*'"net"'*) swaymsg exec 'foot --app-id=iwctl iwctl' >/dev/null ;;
    esac
done
