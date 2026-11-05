#!/bin/sh
# ~/.config/swaybar/status.sh - the right side of swaybar:
# recording dot, clock, battery, the menu button (scripts/menu)

# no "set -e": one failed check must not kill the bar
set -u

# same as sway/colors
white='#e6e6e6'
red='#d7263d'

# block NAME TEXT COLOR; 20 = gap between blocks in px
block() {
    printf '{"name":"%s","full_text":"%s","color":"%s","markup":"pango","separator":false,"separator_block_width":20}' \
        "$1" "$2" "$3"
}

# while scripts/record runs
rec() {
    pgrep -x wf-recorder >/dev/null || return 0
    block rec '● rec' "$red"
    printf ','
}

# date format: man date
clock() {
    block clock "$(date +'%d.%m  %H:%M')" "$white"
}

# the low battery notification shows once per discharge
low_flag="${XDG_RUNTIME_DIR:-/tmp}/shh-battery-low"

# laptops only; red and a notification at 10% or less
bat() {
    local b cap status icon color low
    for b in /sys/class/power_supply/BAT*; do
        [ -r "$b/capacity" ] || continue
        read -r cap <"$b/capacity"
        # some batteries report a bit over 100
        [ "$cap" -le 100 ] || cap=100
        status=
        read -r status 2>/dev/null <"$b/status" || :
        color=$white
        low=0
        if [ "$status" = Charging ]; then
            icon='󰂄'
        elif [ "$cap" -le 10 ]; then
            icon='󰂃'
            color=$red
            low=1
        else
            # empty to full, one per 10%
            set -- 󰂎 󰁺 󰁻 󰁼 󰁽 󰁾 󰁿 󰂀 󰂁 󰂂 󰁹
            shift $((($cap + 5) / 10))
            icon=$1
        fi

        if [ "$low" = 1 ] && [ ! -e "$low_flag" ]; then
            notify-send -a battery -u critical 'battery low' "$cap%, plug in the charger" >/dev/null || true
            : >"$low_flag"
        elif [ "$low" = 0 ] && [ -e "$low_flag" ]; then
            rm -f "$low_flag"
        fi

        printf ','
        block bat "$icon $cap%" "$color"
        return
    done
}

# far right: the logo of this distro (nf-linux-*), CRUX has none: tux.
# no os-release: "." of a missing file kills dash
id=
[ ! -r /etc/os-release ] || id=$(. /etc/os-release; echo "${ID:-}")
case "$id" in
    artix)  logo='' ;;
    void)   logo='' ;;
    gentoo) logo='' ;;
    *)      logo='' ;;
esac
menu_button=$(block menu "$logo" "$white")

# scripts wake the loop with USR1 to redraw now (record);
# the pid file is written after the trap, so an early signal can't kill it
bar_pid="${XDG_RUNTIME_DIR:-/tmp}/shh-bar.pid"

status_loop() {
    trap : USR1
    sh -c 'echo "$PPID"' >"$bar_pid"
    while :; do
        printf '[%s%s%s,%s],\n' "$(rec)" "$(clock)" "$(bat)" "$menu_button"
        # wait, unlike sleep, returns at once on a signal
        sleep 1 &
        wait $! || kill $! 2>/dev/null
    done
}

printf '{"version":1,"click_events":true}\n[\n'

status_loop &
loop_pid=$!
# on a reload the new bar may have written its pid already
trap 'kill "$loop_pid" 2>/dev/null
      [ "$(cat "$bar_pid" 2>/dev/null)" != "$loop_pid" ] || rm -f "$bar_pid"' EXIT
trap 'exit' INT TERM

# clicks: button 1 is the left one
while read -r click; do
    what=$(printf '%s\n' "${click#,}" | jq -r '"\(.name) \(.button)"' 2>/dev/null) || continue
    case "$what" in
        "rec 1") pkill -TERM -x wf-recorder ;;
        "menu 1") swaymsg exec '~/.local/bin/menu open' >/dev/null ;;
    esac
    kill -USR1 "$loop_pid" 2>/dev/null
done
