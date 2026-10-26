#!/bin/sh
# ~/.config/swaybar/status.sh - the right side of swaybar
#
# speaks the i3bar protocol (man 7 swaybar-protocol): first a header,
# then "[", then one JSON array of blocks per update, forever:
#   󰖩   󰕾 ━━━━━─────   26.10  14:05   󰂁 80%
# with click_events swaybar also writes every click on a block to our
# stdin: wifi opens iwctl, volume opens our volume menu, the mouse wheel
# on volume makes it louder / quieter

# no "set -e": one failed check must not kill the whole bar
set -u

# the same colors as ~/.config/sway/colors
# (this script can't read sway's $variables)
white='#e6e6e6'
gray='#5a5a5a'
red='#d7263d'

# block NAME TEXT COLOR: one block of the bar as a JSON object.
# NAME is how a click finds its block. No separator line between blocks,
# just a 20 px gap. markup pango: the text may hold <span> tags, so one
# block can have a white and a gray part (the volume line)
block() {
    printf '{"name":"%s","full_text":"%s","color":"%s","markup":"pango","separator":false,"separator_block_width":20}' \
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

# line PERCENT: the volume as a line of 10 parts, one per 10%:
# ━ for the filled parts, ─ for the rest, and the rest in gray.
# (PERCENT + 5) / 10 rounds: 54% -> 5 parts, 55% -> 6
line() {
    local full=$((($1 + 5) / 10)) i=0 on='' off=''
    [ "$full" -gt 10 ] && full=10
    while [ "$i" -lt 10 ]; do
        if [ "$i" -lt "$full" ]; then on="$on━"; else off="$off─"; fi
        i=$((i + 1))
    done
    printf "%s<span foreground='%s'>%s</span>" "$on" "$gray" "$off"
}

# vol: volume of the default output. wpctl prints "Volume: 0.50"
# or "Volume: 0.50 [MUTED]"; awk turns 0.50 into 50.
# icon U+F057E nf-md-volume_high and a white line, or U+F0581
# nf-md-volume_off and an all gray line when muted. pipewire not running
# (wpctl fails): the off icon and an empty line
vol() {
    local out pct
    if ! out=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null); then
        block vol "󰖁 $(line 0)" "$gray"
        return
    fi
    pct=$(echo "$out" | awk '{printf "%.0f", $2 * 100}')
    case "$out" in
        *MUTED*) block vol "󰖁 $(line "$pct")" "$gray" ;;
        *) block vol "󰕾 $(line "$pct")" "$white" ;;
    esac
}

clock() {
    block clock "$(date +'%d.%m  %H:%M')" "$white"
}

# bat: battery icon and charge, the last block on the right.
# only if the machine has a battery: a desktop PC has no
# /sys/class/power_supply/BAT*, so the block just isn't there.
# prints a "," before the block, so nothing at all on a desktop.
# icons (nerd font nf-md-battery_*): one per 10%, from U+F008E (empty)
# to U+F0079 (full); U+F0084 when charging; U+F0083 in red when at
# 10% or less and not charging
bat() {
    local b cap status icon color
    for b in /sys/class/power_supply/BAT*; do
        [ -r "$b/capacity" ] || continue
        cap=$(cat "$b/capacity")
        status=$(cat "$b/status" 2>/dev/null)
        color=$white
        if [ "$status" = Charging ]; then
            icon='󰂄'
        elif [ "$cap" -le 10 ]; then
            icon='󰂃'
            color=$red
        else
            # set -- puts the 11 icons into $1 ... $11 (only inside this
            # function); shift N drops the first N, so $1 is the icon
            # for N tens of percent
            set -- 󰂎 󰁺 󰁻 󰁼 󰁽 󰁾 󰁿 󰂀 󰂁 󰂂 󰁹
            shift $((($cap + 5) / 10))
            icon=$1
        fi
        printf ','
        block bat "$icon $cap%" "$color"
        return
    done
}

# a new array every second (the volume should change on the bar right
# away); the "," after it continues the endless array
status_loop() {
    while :; do
        printf '[%s,%s,%s%s],\n' "$(net)" "$(vol)" "$(clock)" "$(bat)"
        sleep 1
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
# swaybar sends "[" first, then one click per line:
#   {"name":"vol","button":1,...}   and from the second one on with a ","
# in front. ${click#,} drops that ",", jq reads the JSON and prints
# "vol 1" (block name, mouse button). The "[" line is not an object,
# jq fails on it and "|| continue" skips it.
# buttons: 1 left click, 4 / 5 the mouse wheel up / down.
# swaymsg exec makes sway start the window, so it doesn't depend on this
# script
while read -r click; do
    what=$(printf '%s\n' "${click#,}" | jq -r '"\(.name) \(.button)"' 2>/dev/null) || continue
    case "$what" in
        "net 1") swaymsg exec 'foot --app-id=iwctl iwctl' >/dev/null ;;
        "vol 1") swaymsg exec 'foot --app-id=volume ~/.local/bin/volume' >/dev/null ;;
        "vol 4") wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+ ;;
        "vol 5") wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
    esac
done
