#!/bin/sh
# ~/.config/swaybar/status.sh - the right side of swaybar:
#   red dot while recording, network (ethernet or wifi), bluetooth (only with
#   an adapter), volume, clock, battery (laptops only)
# clicks: red dot -> stop recording, network -> wifi menu,
#   bluetooth -> bluetooth menu, volume -> volume menu, wheel on volume -> +/- 5%

# no "set -e": one failed check must not kill the bar
set -u

# same as sway/colors
white='#e6e6e6'
gray='#5a5a5a'
red='#d7263d'

# block NAME TEXT COLOR; 20 = the gap between blocks in px
block() {
    printf '{"name":"%s","full_text":"%s","color":"%s","markup":"pango","separator":false,"separator_block_width":20}' \
        "$1" "$2" "$3"
}

# a red dot while scripts/record runs wf-recorder
rec() {
    pgrep -x wf-recorder >/dev/null || return 0
    block rec '● rec' "$red"
    printf ','
}

# ethernet icon if a cable is up, else wifi icon if wifi is up, else crossed
# out gray wifi. A cable = a real card ("device") that is not wireless;
# tunnels (happ-xray) and bridges have no "device"
net() {
    local dev wired=0 wifi=0
    for dev in /sys/class/net/*; do
        [ "$(cat "$dev/operstate" 2>/dev/null)" = "up" ] || continue
        if [ -d "$dev/wireless" ]; then
            wifi=1
        elif [ -e "$dev/device" ]; then
            wired=1
        fi
    done
    if [ "$wired" = 1 ]; then
        block net '󰈀' "$white"
    elif [ "$wifi" = 1 ]; then
        block net '󰖩' "$white"
    else
        block net '󰖪' "$gray"
    fi
}

# line PERCENT: ━━━━━─────, 10 parts, the empty part gray
line() {
    local full=$((($1 + 5) / 10)) i=0 on='' off=''
    [ "$full" -gt 10 ] && full=10
    while [ "$i" -lt 10 ]; do
        if [ "$i" -lt "$full" ]; then on="$on━"; else off="$off─"; fi
        i=$((i + 1))
    done
    printf "%s<span foreground='%s'>%s</span>" "$on" "$gray" "$off"
}

# volume of the default output; gray when muted or no pipewire
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

# bluetooth: only if an adapter exists (/sys/class/bluetooth/hci0).
# white when a device is connected: the kernel adds hci0:N for each connection
blue() {
    local d hci=0
    for d in /sys/class/bluetooth/hci*; do
        [ -e "$d" ] || continue
        case "${d##*/}" in
            *:*) printf ','; block blue '󰂱' "$white"; return ;;
            *)   hci=1 ;;
        esac
    done
    [ "$hci" = 0 ] || { printf ','; block blue '󰂯' "$gray"; }
}

# date format: man date
clock() {
    block clock "$(date +'%d.%m  %H:%M')" "$white"
}

# set when the low battery notification was shown, so it shows only once;
# removed on charging or above 10%. XDG_RUNTIME_DIR is emptied on every boot
low_flag="${XDG_RUNTIME_DIR:-/tmp}/shh-battery-low"

# battery: only if /sys/class/power_supply/BAT* exists (so not on a desktop).
# red alert icon and a critical notification at 10% or less when not charging
bat() {
    local b cap status icon color low
    for b in /sys/class/power_supply/BAT*; do
        [ -r "$b/capacity" ] || continue
        cap=$(cat "$b/capacity")
        status=$(cat "$b/status" 2>/dev/null)
        color=$white
        low=0
        if [ "$status" = Charging ]; then
            icon='󰂄'
        elif [ "$cap" -le 10 ]; then
            icon='󰂃'
            color=$red
            low=1
        else
            # icons from empty to full, one per 10%
            set -- 󰂎 󰁺 󰁻 󰁼 󰁽 󰁾 󰁿 󰂀 󰂁 󰂂 󰁹
            shift $((($cap + 5) / 10))
            icon=$1
        fi

        if [ "$low" = 1 ] && [ ! -e "$low_flag" ]; then
            notify-send -a battery -u critical 'battery low' "$cap%, plug in the charger" >/dev/null
            : >"$low_flag"
        elif [ "$low" = 0 ] && [ -e "$low_flag" ]; then
            rm -f "$low_flag"
        fi

        printf ','
        block bat "$icon $cap%" "$color"
        return
    done
}

# update every second
status_loop() {
    while :; do
        printf '[%s%s%s,%s,%s%s],\n' "$(rec)" "$(net)" "$(blue)" "$(vol)" "$(clock)" "$(bat)"
        sleep 1
    done
}

printf '{"version":1,"click_events":true}\n[\n'

# stop the loop when the bar closes
status_loop &
loop_pid=$!
trap 'kill "$loop_pid" 2>/dev/null' EXIT
trap 'exit' INT TERM

# clicks come as JSON lines; buttons: 1 left, 4/5 wheel up/down
while read -r click; do
    what=$(printf '%s\n' "${click#,}" | jq -r '"\(.name) \(.button)"' 2>/dev/null) || continue
    case "$what" in
        "rec 1") pkill -INT -x wf-recorder ;;
        "net 1") swaymsg exec 'foot --app-id=wifi ~/.local/bin/wifi' >/dev/null ;;
        "blue 1") swaymsg exec 'foot --app-id=bluetooth ~/.local/bin/bluetooth' >/dev/null ;;
        "vol 1") swaymsg exec 'foot --app-id=volume ~/.local/bin/volume' >/dev/null ;;
        "vol 4") wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+ 2>/dev/null ;;
        "vol 5") wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- 2>/dev/null ;;
    esac
done
