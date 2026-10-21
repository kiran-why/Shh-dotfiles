#!/bin/sh
# ~/.config/swaybar/status.sh - the text on the right side of swaybar
#
# swaybar runs this script and shows every line it prints;
# a new line replaces the old one. plain text, no icons:
#   net enp0s3   bat 87%   21.10  14:05

# no "set -e": one failed check must not kill the whole bar
set -u

# net: name of the first network interface that is up, "net off" if none.
# /sys/class/net has one directory per interface; operstate is "up" or "down"
net() {
    local dev
    for dev in /sys/class/net/*; do
        [ "${dev##*/}" = "lo" ] && continue
        if [ "$(cat "$dev/operstate" 2>/dev/null)" = "up" ]; then
            printf 'net %s' "${dev##*/}"
            return
        fi
    done
    printf 'net off'
}

# bat: battery charge, printed only if the machine has a battery (laptop)
bat() {
    local b
    for b in /sys/class/power_supply/BAT*; do
        [ -r "$b/capacity" ] || continue
        printf '   bat %s%%' "$(cat "$b/capacity")"
        return
    done
}

while :; do
    printf '%s%s   %s \n' "$(net)" "$(bat)" "$(date +'%d.%m  %H:%M')"
    sleep 5
done
