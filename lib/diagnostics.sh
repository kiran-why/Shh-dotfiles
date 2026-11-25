# Shhware diagnostics API 1

problems=0

# Print a warning that counts as a problem.
bad() {
    warn "$1"
    problems=$((problems + 1))
}

# Check the services. svc_check (distro.sh) gives 0 up, 1 down,
# 2 unknown, 3 can't read the state.
check_services() {
    step "services (services.txt)"

    local svc down rc file
    for file in "$services_file" "$components_file"; do
        if [ ! -f "$file" ] || [ ! -r "$file" ]; then
            bad "UNAVAILABLE: cannot check services without $file"
            return
        fi
    done
    # A part turned off in 'shh config' has its service off too.
    for svc in $(read_list "$services_file" | without "$(off_items "$components_file" 4)"); do
        rc=0
        down=$(svc_check "$svc") || rc=$?
        case "$rc" in
            0) ok "$svc" ;;
            1) bad "$svc is not running:$down" ;;
            2) bad "$svc: unknown to the init system, run sh install.sh" ;;
            *) bad "cannot read the state of the services"
               return 0 ;;
        esac
    done
}

# Check that every file from the list is there. A broken link counts as
# missing.
check_files() {
    step "files"

    [ -f "$list" ] || { bad "no $list (sh lib/link.sh)"; return 0; }
    local k dst n=0 found=0
    while IFS="$tab" read -r k dst || [ -n "$k$dst" ]; do
        n=$((n + 1))
        [ -e "$dst" ] || { bad "missing: $dst (sh lib/link.sh)"; found=1; }
    done <"$list"
    [ "$found" = 1 ] || ok "all $n files in place"
}

# Check what sway needs without elogind.
runtime_dir_present() { [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -d "$XDG_RUNTIME_DIR" ]; }

check_session() {
    step "session"

    if runtime_dir_present; then
        ok "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
    else
        bad "XDG_RUNTIME_DIR is not set (the login sets it: sh install.sh)"
    fi

    # 'id -nG USER' reads /etc/group, 'id -nG' this login (it needs a
    # relogin to change).
    local user group
    user=$(id -un)
    for group in $(printf %s "$seat_groups" | tr , " "); do
        if ! id -nG "$user" | tr ' ' '\n' | grep -qx "$group"; then
            bad "$user is not in group $group (sh install.sh)"
        elif ! id -nG | tr ' ' '\n' | grep -qx "$group"; then
            bad "group $group: log out and in again"
        else
            ok "group $group"
        fi
    done
}

# Doctor checks are read-only and require an explicit option.
# step/ok/info/warn only report. Use bad for a failed required check.
# Optional evidence: unavailable if unreadable, unknown if inconclusive.
# CLI status: 0 no counted problems, 1 failed check/error, 2 invalid arguments.
doctor() {
    [ -f "$distro_file" ] || error "not found: $distro_file (sh lib/link.sh)"
    check_services
    check_files
    check_packages
    check_session

    echo
    [ "$problems" -eq 0 ] || error "$problems problem(s)"
    ok "all good"
}

check_build_tools() {
    local tool
    for tool in git $build_tools; do
        if command -v "$tool" >/dev/null; then ok "$tool"; else bad "missing tool: $tool"; fi
    done
}

doctor_build() {
    local dir parent free
    [ -n "${build_tools:-}" ] || error "no build checks for this distro: $distro"
    step "$distro build/update environment"
    check_build_tools
    if [ "$distro" = kiss ]; then
        dir=${KISS_TMPDIR:-${XDG_CACHE_HOME:-$HOME/.cache}/kiss/proc}
        info "KISS working directory: $dir"
        info "MAKEFLAGS=${MAKEFLAGS:-unset} SAMUFLAGS=${SAMUFLAGS:-unset} CARGO_BUILD_JOBS=${CARGO_BUILD_JOBS:-unset}"
        case "$dir" in /*) parent=$dir ;; *) parent=$PWD/$dir ;; esac
        while [ "$parent" != / ] && [ ! -e "$parent" ] && [ ! -L "$parent" ]; do
            parent=${parent%/*}
            parent=${parent:-/}
        done
        if [ -d "$parent" ] && [ -x "$parent" ] && [ -w "$parent" ]; then
            ok "writable build filesystem: $parent"
            free=$(LC_ALL=C df -Pk "$parent" | LC_ALL=C awk '
                NR == 2 && $4 ~ /^[0-9]+$/ {
                    if ($4 == 0) print "0"
                    else if ($4 * 1024 < 10000000) print "<0.01"
                    else printf "%.2f", $4 * 1024 / 1000000000
                }')
            case "$free" in
                '') info "available space unknown" ;;
                0) bad "no available space on build filesystem" ;;
                *) info "available space: $free GB" ;;
            esac
        else
            bad "build directory unavailable: $parent"
        fi
    elif [ -w "${TMPDIR:-/tmp}" ] && [ -d "${TMPDIR:-/tmp}" ] && [ -x "${TMPDIR:-/tmp}" ]; then
        ok "temporary directory: ${TMPDIR:-/tmp}"
    else
        bad "temporary directory unavailable: ${TMPDIR:-/tmp}"
    fi
    info "installer log: $HOME/.local/state/shh/install.log"
    [ "$problems" -eq 0 ]
}

# Describe the local file only. Never source resolver settings or print their values.
network_dns() {
    local file=/etc/resolv.conf target summary
    step "local DNS configuration"
    if command -v resolvconf >/dev/null; then info "resolvconf tool present"; fi
    if [ -L "$file" ]; then
        info "resolv.conf: symbolic link"
        if [ ! -e "$file" ]; then
            if target=$(readlink "$file" 2>/dev/null); then
                case "$target" in /*) ;; *) target=${file%/*}/$target ;; esac
                if [ -x "${target%/*}/" ] && [ ! -L "$target" ]; then
                    bad "FAIL: resolv.conf link target missing"; return
                fi
            fi
            info "UNAVAILABLE: cannot resolve resolv.conf link"; return
        fi
    elif [ -f "$file" ]; then info "resolv.conf: regular file"
    elif [ ! -x "${file%/*}" ]; then info "UNAVAILABLE: resolver directory"; return
    elif [ ! -e "$file" ]; then warn "WARN: no resolv.conf"; return
    fi
    if [ ! -f "$file" ] || [ ! -r "$file" ]; then
        info "UNAVAILABLE: resolv.conf is not a readable regular file"; return
    fi
    if ! summary=$(awk '
        function v4(s, a,i) {
            if (split(s,a,"[.]") != 4) return 0
            for (i=1;i<=4;i++) if (a[i] !~ /^[0-9]+$/ || length(a[i])>3 || a[i]+0>255) return 0
            return 1
        }
        function groups(s, a,n,i) {
            if (!length(s)) return 0
            n=split(s,a,":")
            for (i=1;i<=n;i++) if (a[i] !~ /^[[:xdigit:]]+$/ || length(a[i])>4) return 99
            return n
        }
        function v6(s, tail,pos) {
            if (s ~ /%./) sub(/%[^%[:space:]]+$/, "", s)
            if (s ~ /[.]/) {
                tail=s; sub(/^.*:/,"",tail)
                if (!v4(tail)) return 0
                sub(/[^:]+$/, "0:0", s)
            }
            pos=index(s,"::")
            if (pos) return groups(substr(s,1,pos-1))+groups(substr(s,pos+2)) < 8
            return groups(s)==8
        }
        NR==1 && $0=="# Generated by resolvconf" { marker=1 }
        { sub(/[[:space:]]*[#;].*$/, "") }
        $1=="nameserver" {
            if (NF!=2 || !(v4($2) || (index($2,":") && v6($2)))) invalid++
            else if ($2 ~ /(^|[.:])0[0-9]+[.]/ || $2 ~ /[.]0[0-9]+$/) uncertain++
            else valid++
        }
        END {print marker+0, valid+0, invalid+0, uncertain+0}
    ' 2>/dev/null <"$file"); then info "UNAVAILABLE: resolver file inspection"; return; fi
    set -- $summary
    if [ "$1" = 1 ]; then info "file carries resolvconf generator header"
    else info "UNKNOWN: resolver file manager"; fi
    if [ "$2" -gt 0 ]; then ok "OK: $2 nameserver record(s) with numeric addresses"; fi
    if [ "$3" -gt 0 ]; then bad "FAIL: $3 malformed nameserver record(s)"; fi
    if [ "$4" -gt 0 ]; then info "UNKNOWN: $4 ambiguous nameserver record(s)"; fi
    if [ "$2 $3 $4" = '0 0 0' ]; then warn "WARN: no explicit nameserver records"; fi
}

# Bound each IPC/netlink client and share a six-second budget across interfaces.
# fd 3 carries diagnostic labels outside captured command output.
network_query() {
    local now remaining rc=0
    if ! command -v timeout >/dev/null; then
        echo "NOT TESTED: $1 query (timeout unavailable)" >&3
        return 125
    fi
    if ! command -v setsid >/dev/null; then
        echo "NOT TESTED: $1 query (process isolation unavailable)" >&3
        return 125
    fi
    if ! read -r now _ </proc/uptime || [ -z "$network_start" ]; then
        echo "NOT TESTED: $1 query (elapsed clock unavailable)" >&3
        return 125
    fi
    remaining=$((network_start + 6 - ${now%%.*}))
    if [ "$remaining" -le 0 ]; then
        echo "NOT TESTED: $1 query (network probe time budget exhausted)" >&3
        return 125
    fi
    [ "$remaining" -le 2 ] || remaining=2
    # BusyBox timeout signals only its command. Stop a stuck client's helpers
    # in a private process group so they cannot keep the capture pipe open.
    setsid sh -c '
        timeout -s KILL "$@"
        rc=$?
        case "$rc" in 124|137) kill -KILL 0 ;; esac
        exit "$rc"
    ' sh "$remaining" "$@" </dev/null 3>&- 2>/dev/null || rc=$?
    case "$rc" in
        124|137) echo "UNAVAILABLE: $1 query timed out or was killed" >&3; return 125 ;;
    esac
    return "$rc"
}

network_backend() {
    local service state rc=0
    step "Wi-Fi backend"
    case "$distro" in
        kiss|void)
            service=iwd; [ "$distro" != kiss ] || service=eiwd
            if [ -x /var/service ] && [ ! -e "/var/service/$service" ]; then
                warn "WARN: $service service entry absent"
            elif state=$(network_query sv status "/var/service/$service" 2>/dev/null); then
                case "$state" in
                    run:*) ok "OK: $service service running" ;;
                    down:*) warn "WARN: $service service down" ;;
                    *) info "UNKNOWN: $service supervisor state" ;;
                esac
            elif [ "$?" != 125 ]; then info "UNAVAILABLE: $service supervisor status"; fi ;;
        artix)
            state=$(svc_check iwd network_query 2>/dev/null) || rc=$?
            case "$rc" in
                0) ok "OK: iwd service active in s6" ;;
                1) warn "WARN: iwd service not fully active in s6" ;;
                2) info "UNKNOWN: iwd service registration" ;;
                125) : ;;
                *) info "UNAVAILABLE: iwd supervisor status" ;;
            esac ;;
        *) info "UNKNOWN: Wi-Fi supervisor" ;;
    esac
    if network_query pgrep -x iwd >/dev/null 2>&1; then ok "OK: iwd process visible"
    elif [ "$?" != 125 ]; then info "UNKNOWN: iwd process not confirmed"; fi
}

# A missing session component is actionable only after the startup window.
audio_missing() {
    if [ "$settled" = yes ]; then bad "FAIL: $1 (current snapshot)"
    elif [ "$active" = yes ]; then warn "UNKNOWN: $1 (startup may be in progress)"
    else info "$1 (session expectation unknown here)"; fi
}

audio_alsa() {
    step "ALSA hardware (kernel inventory)"
    for file in /proc/asound/cards /proc/asound/pcm; do
        if [ -x /proc ] && [ ! -e /proc/asound ]; then
            info "UNAVAILABLE: kernel ALSA inventory /proc/asound absent"; break
        elif [ -x /proc/asound ] && [ ! -e "$file" ]; then
            info "UNAVAILABLE: $file absent"
        elif [ -f "$file" ] && rows=$(cat "$file" 2>/dev/null); then
            case "$file" in
                */cards) pattern='^[[:space:]]*[0-9]+ [[]' ;;
                */pcm) pattern='^[0-9]+-[0-9]+:' ;;
            esac
            if matches=$(printf '%s\n' "$rows" | grep -E "$pattern"); then
                info "$file"
                printf '%s\n' "$matches"
            elif [ "$file" = /proc/asound/cards ] && [ "$rows" = '--- no soundcards ---' ]; then
                warn "WARN: ALSA reports no cards"
            elif [ "$file" = /proc/asound/pcm ] && [ -z "$rows" ]; then
                info "no ALSA playback or capture PCM listed"
            else info "UNKNOWN: unrecognized $file inventory"; fi
        else info "UNAVAILABLE: cannot read $file"; fi
    done
    if [ -x /dev ] && [ ! -e /dev/snd ]; then
        warn "WARN: /dev/snd absent"
        return
    fi
    if [ ! -d /dev/snd ] || [ ! -r /dev/snd ] || [ ! -x /dev/snd ]; then
        info "UNAVAILABLE: cannot inspect /dev/snd"
        return
    fi
    nodes=0
    for node in /dev/snd/controlC* /dev/snd/pcmC*; do
        [ -c "$node" ] || continue
        nodes=$((nodes + 1))
        if [ ! -r "$node" ] || [ ! -w "$node" ]; then warn "WARN: limited direct user access to $node"; fi
    done
    info "ALSA control/PCM device nodes: $nodes"
}

# Read just the audio inventory; status also contains video nodes and client names.
audio_wp_list() {
    awk -v section="$1:" '
        /^Audio$/ { audio=1; next }
        /^[[:alpha:]]/ { if (inside) closed=1; inside=0; audio=0 }
        audio && /[[:alpha:]]+:$/ { if (inside) closed=1; inside=($NF == section); if (inside) seen=1; next }
        audio && inside {
            if (match($0, /[0-9]+[.] /)) { print substr($0, RSTART); next }
            if ($0 ~ /[[:alnum:]]/) unknown=1
        }
        END { if (!seen || !closed || unknown) exit 1 }'
}

audio_devices() {
    for kind in sink source; do
        case "$kind" in
            sink) section=Sinks; target=@DEFAULT_AUDIO_SINK@ ;;
            source) section=Sources; target=@DEFAULT_AUDIO_SOURCE@ ;;
        esac
        if [ "$backend" = wpctl ]; then
            if ! rows=$(printf '%s\n' "$inventory" | audio_wp_list "$section"); then
                info "UNKNOWN: $kind inventory"; continue
            fi
        elif ! rows=$(audio_pactl list short "${kind}s"); then
            info "UNAVAILABLE: $kind inventory"; continue
        elif [ -n "$rows" ] && ! printf '%s\n' "$rows" | awk 'NF < 2 || $1 !~ /^[0-9]+$/ { exit 1 }'; then
            info "UNKNOWN: $kind inventory"; continue
        fi
        if [ -z "$rows" ]; then
            if [ "$kind" = sink ]; then audio_missing "server lists no playback sink"
            else info "no capture source listed"; fi
            continue
        fi
        info "$section (virtual devices may be included)"
        printf '%s\n' "$rows"
        if [ "$backend" = wpctl ]; then
            name=$(audio_wpctl inspect "$target" | sed -n 's/.*node\.description = "\(.*\)"/\1/p')
            level=$(audio_wpctl get-volume "$target") || level=UNAVAILABLE
        else
            name=$(audio_pactl "get-default-$kind") || name=
            level=UNAVAILABLE
            if [ -n "$name" ]; then
                vol=$(audio_pactl "get-$kind-volume" "$name") || vol=UNAVAILABLE
                mute=$(audio_pactl "get-$kind-mute" "$name") || mute=UNAVAILABLE
                level="$vol / $mute"
            fi
        fi
        case "$level" in
            *MUTED*|*'Mute: yes'*) warn "WARN: default $kind is muted (may be intentional)" ;;
            'Volume: 0.00'|'Volume: 0.0'|'Volume: 0') warn "WARN: default $kind volume is zero (may be intentional)" ;;
        esac
        info "default $kind: ${name:-UNKNOWN} / ${level:-UNKNOWN}"
    done
}

# A socket file can survive a crash or belong to an activation service.
audio_listener() (
    inode=$(awk -v path="$1" '$4=="00010000" && $5=="0001" && $6=="01" {
        n=$7; for (i=1;i<=7;i++) sub(/^[^[:space:]]+[[:space:]]+/, ""); if ($0==path) print n
    }' /proc/net/unix 2>/dev/null) || exit 1
    case "$inode" in ''|*[!0-9]*) exit 1 ;; esac
    for pid in $2; do
        for fd in /proc/"$pid"/fd/*; do
            [ -S "$fd" ] && [ "$(readlink "$fd" 2>/dev/null)" = "socket:[$inode]" ] && exit 0
        done
    done
    exit 1
)

audio_wpctl() { PIPEWIRE_REMOTE="$runtime/pipewire-0" timeout -s KILL 2 wpctl "$@" 2>/dev/null; }
audio_pactl() (
    # libpulse can create a cookie on first use. Keep its config paths unwritable.
    unset PULSE_COOKIE
    HOME=/dev/null XDG_CONFIG_HOME=/dev/null/pulse PULSE_CONFIG_PATH=/dev/null/pulse \
        PULSE_CLIENTCONFIG=/dev/null DISPLAY= timeout -s KILL 2 pactl -s "unix:$runtime/pulse/native" "$@" 2>/dev/null
)

audio_processes() {
    uid=$(id -u) || return 1
    runtime=${XDG_RUNTIME_DIR:-}
    sway_socket=${SWAYSOCK:-}
    sway_start= pw_pids= pulse_pids=
    active=no settled=no visible=' ' partial=no
    [ -r /proc/self/stat ] && [ -r /proc ] && [ -x /proc ] || partial=yes
    for file in /proc/[0-9]*/stat; do
        if ! read -r stat 2>/dev/null <"$file"; then
            [ ! -d "${file%/stat}" ] || partial=yes
            continue
        fi
        case "${stat#* }" in
            '(sway) '*|'(pipewire) '*|'(pipewire-pulse) '*|'(wireplumber) '*) ;;
            *) continue ;;
        esac
        set -- $stat
        case "$3" in Z|X) continue ;; esac
        owner=$(awk '/^Uid:/ { print $3 }' "${file%/stat}/status" 2>/dev/null) || owner=
        if [ -z "$owner" ]; then partial=yes; continue; fi
        [ "$owner" = "$uid" ] || continue
        prog=${2#(}; prog=${prog%)}
        visible="$visible$prog "
        case "$prog" in
            pipewire) pw_pids="$pw_pids $1" ;;
            pipewire-pulse) pulse_pids="$pulse_pids $1" ;;
        esac
        if [ "$prog" = sway ] && [ "${sway_socket##*/}" = "sway-ipc.$uid.$1.sock" ]; then sway_start=${22:-}; fi
    done
}

doctor_audio() (
    export LC_ALL=C
    step "session and audio processes"
    audio_processes
    if [ -n "${SWAYSOCK:-}" ] && [ -S "$SWAYSOCK" ] &&
        timeout -s KILL 2 swaymsg -s "$SWAYSOCK" -t get_version >/dev/null 2>&1; then
        active=yes
        ok "OK: current Sway IPC responded"
        # sound waits up to five seconds before starting the other two daemons.
        hz=$(getconf CLK_TCK 2>/dev/null) || hz=
        if awk -v hz="$hz" -v start="${sway_start:-}" 'NR==1 {
            ready=(hz+0>0 && start+0>0 && $1-start/hz>=10) } END { exit !ready }' /proc/uptime 2>/dev/null; then settled=yes; fi
    elif [ -n "${SWAYSOCK:-}" ]; then info "UNKNOWN: current Sway IPC unconfirmed"
    else info "no SWAYSOCK in this shell; another session may be active"; fi
    case "$visible" in *' sway '*) info "Sway process visible for current UID $uid" ;; esac
    for prog in pipewire wireplumber pipewire-pulse; do
        if path=$(command -v "$prog"); then info "$prog executable: $path"
        else audio_missing "$prog executable unavailable in PATH"; fi
        case "$visible" in
            *" $prog "*) ok "OK: $prog visible for UID $uid" ;;
            *) if [ "$partial" = yes ]; then info "UNAVAILABLE: incomplete process inventory for $prog"
               else audio_missing "$prog process not visible for UID $uid"; fi ;;
        esac
    done

    step "Shhware local audio sockets"
    native=no pulse=no usable=no
    case "$runtime" in
        /*) if [ -d "$runtime" ] && [ -x "$runtime" ] && [ -r "$runtime" ]; then
                meta=$(stat -Lc '%u:%a' "$runtime" 2>/dev/null) || meta=
                case "$meta" in
                    "$uid:700") usable=yes; ok "OK: XDG_RUNTIME_DIR=$runtime (owner $uid, mode 700)" ;;
                    '') info "UNAVAILABLE: runtime ownership and permissions" ;;
                    *) warn "WARN: $runtime owner:mode $meta, expected $uid:700" ;;
                esac
                [ -w "$runtime" ] || warn "WARN: runtime directory is not writable"
            else info "UNAVAILABLE: runtime directory $runtime"; fi ;;
        *) info "UNAVAILABLE: XDG_RUNTIME_DIR unset or not absolute" ;;
    esac
    if [ "$usable" = yes ]; then
        for path in "$runtime/pipewire-0" "$runtime/pulse/native"; do
            if [ -S "$path" ]; then
                ok "OK: UNIX socket present: $path"
                case "$path" in */native) pids=$pulse_pids ;; *) pids=$pw_pids ;; esac
                if audio_listener "$path" "$pids"; then
                    case "$path" in */native) pulse=yes ;; *) native=yes ;; esac
                else info "UNKNOWN: daemon listener unconfirmed for $path (stale socket possible)"; fi
            elif [ -d "${path%/*}" ] && [ ! -x "${path%/*}" ]; then info "UNAVAILABLE: cannot search ${path%/*}"
            else audio_missing "expected socket missing: $path"; fi
        done
    fi
    step "audio server and routing"
    backend=
    for tool in timeout wpctl pactl; do
        command -v "$tool" >/dev/null || info "UNAVAILABLE: $tool"
    done
    # Only connect to an explicit local endpoint with its daemon already visible.
    if [ "$native" = yes ] && command -v timeout >/dev/null && command -v wpctl >/dev/null; then
        if inventory=$(audio_wpctl status); then backend=wpctl; ok "OK: PipeWire answered wpctl"
        else warn "WARN: native socket present, wpctl query failed or timed out"; fi
    fi
    if [ "$native" = yes ] && [ "$pulse" = yes ] && command -v timeout >/dev/null && command -v pactl >/dev/null; then
        if audio_pactl info >/dev/null; then
            ok "OK: Pulse protocol answered pactl"
            backend=${backend:-pactl}
        else warn "WARN: Pulse socket present, pactl query failed or timed out"; fi
    fi
    if [ -n "$backend" ]; then audio_devices
    else info "UNAVAILABLE: no successful bounded local audio query"; fi
    audio_alsa
    step "audio startup messages (wm.log, last 64 KiB)"
    if chunk=$(log_window end "$HOME/.local/state/shh/wm.log"); then
        lines=$(printf '%s\n' "$chunk" | awk '
            /^sound: pipewire did not start, no / ||
            /sound:.*(pipewire(-pulse)?|wireplumber): (not found|Permission denied)/ ||
            /^\[E\].*(mod\.protocol-native|mod\.protocol-pulse|pw\.context).*(failed|unable|Address already in use)/ {
                gsub(/[[:cntrl:]]/, " "); print substr($0,1,240) }' | tail -n 4)
        info "${lines:-no matching sound launcher errors in this window}"
    else info "UNAVAILABLE: wm.log"; fi
    info "audible playback and physical connections: NOT TESTED"
    [ "$problems" -eq 0 ]
)

wifi_interface() { [ -d "$1/wireless" ] || [ -d "$1/phy80211" ]; }

doctor_network() (
    export LC_ALL=C
    exec 3>&1
    network_start=''
    if read -r now _ </proc/uptime; then network_start=${now%%.*}; fi
    net=/sys/class/net
    wifi=0 other=0 wifi_partial=0
    step "interfaces (local snapshot)"
    if [ -r "$net" ] && [ -x "$net" ]; then
        for path in "$net"/*; do
            [ -d "$path" ] || continue
            dev=${path##*/}
            label=$dev
            if [ "$dev" = lo ]; then label="lo (loopback)"; else other=1; fi
            admin=UNAVAILABLE
            if flags=$(cat "$path/flags" 2>/dev/null); then
                case "$flags" in
                    *[13579bBdDfF]) admin=up ;;
                    *[02468aAcCeE]) admin=down ;;
                    *) admin=UNKNOWN ;;
                esac
            fi
            oper=$(cat "$path/operstate" 2>/dev/null) || oper=UNAVAILABLE
            carrier=$(cat "$path/carrier" 2>/dev/null) || carrier=UNAVAILABLE
            ok "OK: $label detected; admin=$admin operstate=$oper carrier=$carrier"
            for af in 4 6; do
                if addresses=$(network_query ip -"$af" -o addr show dev "$dev" 2>/dev/null); then
                    scopes=$(printf '%s\n' "$addresses" | awk '{for(i=1;i<NF;i++) if ($i=="scope") print $(i+1)}' | sort -u | tr '\n' ' ')
                    if [ -n "$scopes" ]; then info "IPv$af assigned (scope): ${scopes% }"
                    elif [ -z "$addresses" ]; then info "IPv$af: none assigned"
                    else info "UNKNOWN: IPv$af address scope"; fi
                elif [ "$?" != 125 ]; then info "UNAVAILABLE: IPv$af address inventory"; fi
            done
            if [ ! -x "$path" ]; then wifi_partial=1; continue; fi
            if wifi_interface "$path"; then
                wifi=1
                ok "OK: Wi-Fi interface $dev"
                if driver=$(readlink "$path/device/driver" 2>/dev/null); then info "bound driver: ${driver##*/}"
                else info "UNKNOWN: bound driver"; fi
                if changes=$(cat "$path/carrier_changes" 2>/dev/null); then
                    info "carrier changes since interface creation: $changes"
                fi
                if link=$(network_query iw dev "$dev" link 2>/dev/null); then
                    case "$link" in
                        'Connected to '*) ok "OK: Wi-Fi associated" ;;
                        'Not connected.'*) warn "WARN: Wi-Fi not associated" ;;
                        *) info "UNKNOWN: Wi-Fi association" ;;
                    esac
                elif [ "$?" = 125 ]; then :
                elif command -v fastfetch >/dev/null && command -v jq >/dev/null &&
                    report=$(network_query fastfetch --config none -s Wifi --format json 2>/dev/null) &&
                    printf '%s\n' "$report" | jq -e --arg dev "$dev" '
                        any(.[] | .result[]?; .inf.description==$dev and
                            (.conn.ssid | type=="string" and length>0))
                    ' >/dev/null 2>&1; then
                    ok "OK: Wi-Fi connection reported by fastfetch"
                elif [ "$?" != 125 ]; then info "UNKNOWN: Wi-Fi association"; fi
            fi
        done
        [ "$other" = 1 ] || warn "WARN: no non-loopback interface visible"
        if [ "$wifi_partial" = 1 ]; then info "UNAVAILABLE: incomplete Wi-Fi inventory"
        elif [ "$wifi" = 0 ]; then info "no Wi-Fi interface detected in sysfs"; fi
    else info "UNAVAILABLE: interface inventory"; fi
    step "registered Wi-Fi radios (ieee80211)"
    radios=/sys/class/ieee80211
    if [ -r "$radios" ] && [ -x "$radios" ]; then
        found=0
        for phy in "$radios"/*; do
            [ -d "$phy" ] || continue
            found=1
            ok "OK: Wi-Fi radio ${phy##*/} registered"
        done
        [ "$found" = 1 ] || info "no registered Wi-Fi radios visible"
    else info "UNAVAILABLE: Wi-Fi radio inventory"; fi
    network_backend
    step "default routes (main table)"
    for af in 4 6; do
        if routes=$(network_query ip -"$af" route show table main 2>/dev/null); then
            if printf '%s\n' "$routes" | grep -Eq '^(default|0\.0\.0\.0/0|::/0)( |$)'; then
                ok "OK: IPv$af default route present"
            else warn "WARN: no forwarding IPv$af default in main table"; fi
        elif [ "$?" != 125 ]; then info "UNAVAILABLE: IPv$af main routing table"; fi
    done
    info "On-link DNS, loopback resolvers and specific or policy routes can work without a main default."
    network_dns
    step "external reachability"
    info "external IP: NOT TESTED"
    info "DNS resolution: NOT TESTED"
    info "HTTPS: NOT TESTED"
    [ "$problems" -eq 0 ]
)

load_memory() {
    awk 'NR == 1 && $1 ~ /^[0-9]+[.][0-9]+$/ && $2 ~ /^[0-9]+[.][0-9]+$/ && $3 ~ /^[0-9]+[.][0-9]+$/ {
             print "  load average (1/5/15 min): " $1 " " $2 " " $3; seen=1
         }
         END { if (!seen) print "  load average unknown" }' 2>/dev/null </proc/loadavg || info "load average unavailable"
    awk '
        $2 ~ /^[0-9]+$/ && $3 == "kB" { kb[$1]=$2 }
        END {
            available=("MemAvailable:" in kb) ? sprintf("%.1f", kb["MemAvailable:"]/1024) : "unknown"
            total=("MemTotal:" in kb) ? sprintf("%.1f", kb["MemTotal:"]/1024) : "unknown"
            print "  RAM available / total (MiB): " available " / " total
            if ("SwapTotal:" in kb && "SwapFree:" in kb)
                printf "  swap used / total (MiB): %.1f / %.1f\n", (kb["SwapTotal:"]-kb["SwapFree:"])/1024, kb["SwapTotal:"]/1024
            else print "  swap unknown"
        }' 2>/dev/null </proc/meminfo || info "memory unavailable"
}

# A single short sample. Keep the locale and working variables in this subshell.
doctor_performance() (
    export LC_ALL=C
    step "system load and memory"
    load_memory
    if [ -r /proc/pressure/memory ]; then
        awk '/^(some|full) / { print "  memory PSI " $0; seen=1 }
             END { if (!seen) print "  memory PSI unknown" }' /proc/pressure/memory || info "memory PSI unavailable"
    else
        info "memory PSI unavailable"
    fi

    step "CPU sensors"
    {
        for file in /sys/devices/system/cpu/cpufreq/policy*/scaling_cur_freq; do
            read -r value 2>/dev/null <"$file" && printf '%s\n' "$value"
        done
    } | awk '/^[0-9]+$/ {
                 if (!n || $1+0 < lo) lo=$1+0
                 if (!n || $1+0 > hi) hi=$1+0
                 n++
             }
             END { if (n) printf "  CPU frequency (MHz, %d policies): %.1f to %.1f\n", n, lo/1000, hi/1000
                   else print "  CPU frequency unavailable" }'
    found=0
    for file in /sys/class/hwmon/hwmon*/name; do
        read -r chip 2>/dev/null <"$file" || continue
        case "$chip" in coretemp|k10temp|zenpower|cpu_thermal) ;; *) continue ;; esac
        for input in "${file%/*}"/temp*_input; do
            read -r value 2>/dev/null <"$input" || continue
            case "${value#-}" in ''|*[!0-9]*) continue ;; esac
            read -r label 2>/dev/null <"${input%_input}_label" || label=${input##*/}
            awk -v chip="$chip" -v label="$label" -v value="$value" 'BEGIN { printf "  %s %s: %.3f °C\n", chip, label, value/1000 }'
            found=1
        done
    done
    if [ "$found" = 0 ]; then
        for file in /sys/class/thermal/thermal_zone*/type; do
            read -r label 2>/dev/null <"$file" || continue
            case "$label" in x86_pkg_temp|cpu-thermal|cpu_thermal) ;; *) continue ;; esac
            read -r value 2>/dev/null <"${file%/*}/temp" || continue
            case "${value#-}" in ''|*[!0-9]*) continue ;; esac
            awk -v label="$label" -v value="$value" 'BEGIN { printf "  %s: %.3f °C\n", label, value/1000 }'
            found=1
        done
    fi
    [ "$found" = 1 ] || info "CPU temperature unavailable"

    step "visible desktop processes (two snapshots about 1 s apart)"
    {
        for pass in 1 2; do
            if [ "$pass" = 2 ]; then
                sleep 1 || break
                echo second
            fi
            for file in /proc/[0-9]*/stat; do
                read -r stat 2>/dev/null <"$file" || continue
                case "${stat#* }" in
                    '(sway) '*|'(foot) '*|'(footclient) '*|'(pipewire) '*|'(pipewire-pulse) '*|'(wireplumber) '*) printf '%s\n' "$stat" ;;
                esac
            done
        done
    } | awk -v hz="$(getconf CLK_TCK 2>/dev/null || :)" -v page="$(getconf PAGESIZE 2>/dev/null || :)" '
        /^second$/ { second=1; next }
        # Only exact comm names without spaces are passed here. Match PID and start time.
        NF >= 24 {
            key=$1 SUBSEP $22 SUBSEP $2
            ticks=$14+$15
            if (!second) { before[key]=ticks; next }
            cpu="unknown"
            if (key in before && ticks >= before[key]) {
                delta=ticks-before[key]
                cpu=(hz+0 > 0) ? sprintf("%.3f s", delta/hz) : sprintf("%.0f ticks", delta)
            }
            rss=(page+0 > 0) ? sprintf("%.1f MiB", $24*page/1048576) : $24 " pages"
            printf "  %s %s: RSS %s, CPU delta %s\n", $1, $2, rss, cpu
            seen=1
        }
        END { if (!second) { print "  CPU sample failed"; exit 1 }
              if (!seen) print "  no matching processes visible" }' || return 1

    step "logged Sway startup (Linux boot and application readiness unmeasured)"
    if chunk=$(log_window start "$HOME/.local/state/shh/wm.log"); then
        marker=$(printf '%s\n' "$chunk" | awk '
            /^[0-9]+:[0-5][0-9]:[0-5][0-9][.][0-9]+ (\[(INFO|DEBUG)\] )?\[sway\/server[.]c:[0-9]+\] Running compositor on wayland display / { print $1; exit }')
        info "Sway main loop, log-relative time: ${marker:-unknown}"
    else
        info "wm.log unavailable"
    fi
)

# Read at most 64 KiB plus one lookahead byte from a regular session log.
log_window() {
    local LC_ALL=C chunk side=$1 file=$2 mode=${3:-}
    [ -f "$2" ] && [ -r "$2" ] || return 1
    # The marker preserves trailing newlines when measuring bytes in shell.
    case "$side" in
        start) set -- dd bs=65537 count=1 ;;
        end)   set -- tail -c 65537 ;;
        *) return 1 ;;
    esac
    if [ "$mode" = report ]; then
        # Pin and verify the opened inode before reading. The deadline also
        # bounds open() if the checked regular file is replaced with a FIFO.
        chunk=$(timeout -s KILL 2 sh -c '
            file=$1; shift
            [ ! -L "$file" ] && [ -f "$file" ] || exit 1
            inode=$(stat -c "%d:%i:%h:%u" "$file") || exit 1
            case "$inode" in *:1:"$(id -u)") ;; *) exit 1 ;; esac
            exec 3<"$file"
            [ -f /proc/self/fd/3 ] &&
                [ "$(stat -Lc "%d:%i:%h:%u" /proc/self/fd/3)" = "$inode" ] &&
                [ "$(stat -c "%d:%i:%h:%u" "$file")" = "$inode" ] || exit 1
            exec "$@" <&3
        ' sh "$file" "$@" && printf .) || return 1
    else
        chunk=$("$@" 2>/dev/null <"$file" && printf .) || return 1
    fi
    chunk=${chunk%.}
    if [ "${#chunk}" -le 65536 ]; then printf '%s' "$chunk"
    elif [ "$side" = start ]; then printf '%s' "$chunk" | sed '$d'
    else printf '%s' "$chunk" | sed '1d'
    fi
}

# Only report a renderer from a wlroots startup that reached Sway's main loop.
# A request, or an attempt followed by fallback, is not proof.
logged_renderer() {
    LC_ALL=C awk -v mode="${1:-}" '
        { sub(/^[[:space:]]*([0-9:.]+ )?(\[(DEBUG|INFO|WARN|ERROR)\] )?/, "") }
        /^\[wlr\] \[util\/env\.c:[0-9]+\] Loading WLR_RENDERER option: / { requested=$NF }
        /^\[wlr\] \[render\/[^]]+\] Creating .*renderer/ {
            attempts++
            if ($0 ~ /^\[wlr\] \[render\/pixman\/[^]]+\] Creating pixman renderer/) backend="pixman"
            if ($0 ~ /^\[wlr\] \[render\/gles2\/[^]]+\] Creating GLES2 renderer/) backend="gles2"
        }
        /^\[wlr\] \[render\/pixman\/[^]]+\] Created pixman buffer / {
            if (backend != "pixman") conflict=1
            actual="pixman"
        }
        /^\[wlr\] \[render\/gles2\/[^]]+\] GL renderer: [^[:space:]]/ {
            if (backend != "gles2") conflict=1
            sub(/^.*\] GL renderer: /, "")
            if (actual != "" && actual != "GLES2 (" $0 ")") conflict=1
            actual="GLES2 (" $0 ")"
        }
        /^\[sway\/server\.c:[0-9]+\] Running compositor on wayland display / { running=1; exit }
        END {
            if (mode=="report") {
                print (running && attempts==1 && !conflict && actual!="" ? backend : "UNKNOWN")
                exit
            }
            printf "requested=%s; actual=%s\n", (requested ? requested : "unknown"),
                (running && attempts == 1 && !conflict && actual != "" ? actual : "unknown")
        }
    '
}

# wm.log mixes Sway and client stderr. Only accept graphics messages from
# known emitters; kernel evidence belongs to this boot, not necessarily this crash.
graphics_errors() {
    LC_ALL=C awk -v source="$1" -v mode="${2:-}" '
        source == "kernel" && $0 == "shh: dmesg unavailable" { print "  dmesg unavailable (restricted or missing)"; next }
        {
            s=tolower($0)
            if (source == "kernel") {
                if (s !~ /(nouveau|amdgpu|i915|drm|nvrm: xid|xe [0-9a-f]+:|sway\[[0-9]+\]: segfault.*(libegl|libgallium|libmesa|libdrm|_dri\.so))/) next
                label="kernel"
            } else if (s ~ /^nouveau: kernel rejected pushbuf/) label="Nouveau (process unknown)"
            else if (s ~ /^[[:space:]]*([0-9:.]+ )?\[error\] \[(wlr\] \[(render|backend)\/|sway\/(server\.c:|desktop\/))/ &&
                     s ~ /(egl|gles|drm|kms|gpu|renderer|atomic commit|page.flip)/) label="Sway/wlroots"
            else next
            if (s !~ /(error|fail|fault|hang|timed? ?out|reset|killed|rejected|segfault|nvrm: xid|cannot|unable)/) next
            if (mode=="report") { if (!seen[label]++) print label; next }
            gsub(/[[:cntrl:]]/, " "); print "  " label ": " substr($0, 1, 300)
        }' | tail -n 6
}

doctor_graphics() {
    local dir="$HOME/.local/state/shh" log lines renderer chunk
    step "DRM (direct access as $(id -un); seatd can grant session access)"
    sh "$hardware_script" --graphics || bad "no DRM card node found or inventory unavailable"

    step "Sway renderer (actual refers only to the logged startup)"
    info "requested (this shell): ${WLR_RENDERER:-auto}"
    [ "${WLR_RENDERER:-}" != pixman ] || warn "pixman requests CPU rendering; this alone does not explain delays"
    [ -z "${WLR_NO_HARDWARE_CURSORS+x}" ] || info "this shell: WLR_NO_HARDWARE_CURSORS=$WLR_NO_HARDWARE_CURSORS"
    [ -z "${NOUVEAU_USE_ZINK+x}" ] || info "this shell: NOUVEAU_USE_ZINK=$NOUVEAU_USE_ZINK"
    for log in wm.log wm-crash.log; do
        if chunk=$(log_window start "$dir/$log"); then
            renderer=$(printf '%s\n' "$chunk" | logged_renderer)
        else
            renderer='requested=unknown; actual=unknown (log unavailable)'
        fi
        info "$log session: $renderer"
    done
    if command -v xwayland_hint >/dev/null; then
        info "Xwayland: config=$(setting xwayland no); $(xwayland_hint)"
    fi

    for log in wm.log wm-crash.log; do
        step "graphics errors: $log"
        if chunk=$(log_window end "$dir/$log"); then
            lines=$(printf '%s\n' "$chunk" | graphics_errors session)
            printf '%s\n' "${lines:-  no matching graphics errors in last 64 KiB}"
        elif [ "$log" = wm-crash.log ]; then
            info "crash log unavailable"
        else
            info "session log unavailable"
        fi
    done
    step "kernel: current boot, last 256 lines (may be a different session)"
    lines=$({ dmesg 2>/dev/null || echo 'shh: dmesg unavailable'; } | tail -n 256 | graphics_errors kernel)
    printf '%s\n' "${lines:-  no matching graphics errors in this window}"
    # Link two concrete events by PID, not just by the name of a driver.
    printf '%s\n' "$lines" | LC_ALL=C awk '
        /sway\[[0-9]+\]: channel [0-9]+ killed!/ { pid=$0; sub(/^.*sway\[/,"",pid); sub(/\].*/,"",pid) }
        /sway\[[0-9]+\]: segfault .* in libgallium/ && pid && index($0,"sway[" pid "]: segfault") {
            print "  Possible GPU channel loss before a Mesa crash (Sway PID " pid "); trigger unknown."
        }'
    [ "$problems" -eq 0 ]
}

# Only release numbers from known version banners cross the output boundary.
report_version() {
    local tool=$1
    command -v "$tool" >/dev/null || { echo UNAVAILABLE; return; }
    command -v timeout >/dev/null || { echo 'NOT TESTED (timeout unavailable)'; return; }
    { timeout -s KILL 2 "$tool" --version && echo SHH_VERSION_OK; } |
        head -c 1024 | awk -v tool="$tool" '
            tool=="sway" && $1=="sway" && $2=="version" { v=$3 }
            $1=="Linked" && $2=="with" && $3=="lib"tool { v=$4 }
            $0=="SHH_VERSION_OK" { ok=1 }
            END { print (ok && length(v)<=16 && v~/^[0-9]+[.][0-9]+([.][0-9]+)?$/ ? v : "UNKNOWN") }'
}

report_system() {
    local hash= tag= version='installed copy (no checkout metadata)' arch init kernel tool stat file present='' missing=''
    if [ "$from_repo" = 1 ]; then
        version='checkout metadata unavailable'
        if hash=$(report_git rev-parse --short=12 HEAD); then
            version='checkout (no recognized release tag)'
            tag=$(report_git describe --tags --long --match 'v[0-9]*' --match '[0-9]*' HEAD) || tag=
            tag=$(printf '%s\n' "$tag" | awk -F- '
                NF==3 && length($1)<=20 && $1~/^v?[0-9]+[.][0-9]+([.][0-9]+)?$/ &&
                length($2)<=10 && $2~/^[0-9]+$/ && $3~/^g[0-9a-f]+$/ {
                    if ($2==0) print $1; else print $2 " commits after " $1
                }')
            version=${tag:-$version}
        fi
    fi
    printf 'Shhware: %s\n' "$version"
    case "$hash" in *[!0-9a-f]*|'') ;; *) [ "${#hash}" != 12 ] || printf 'Checkout: %s\n' "$hash" ;; esac
    printf 'Distribution: %s\n' "$distro"
    kernel=$(uname -r | awk 'match($0,/^[0-9]+[.][0-9]+[.][0-9]+/) && RLENGTH<=16 {print substr($0,1,RLENGTH);exit}')
    arch=$(uname -m) || arch=
    case "$arch" in x86_64|i386|i486|i586|i686|aarch64|armv7l|riscv64|ppc64le|s390x) ;; *) arch=UNKNOWN ;; esac
    read -r init </proc/1/comm || init=
    case "$init" in
        runit|s6-svscan|systemd|openrc-init) ;;
        init) case "$(readlink -f /sbin/init)" in
                  */busybox) init='init (configured /sbin/init: BusyBox)' ;;
              esac ;;
        '') init='UNAVAILABLE (PID 1 name)' ;;
        *) init='unrecognized PID 1' ;;
    esac
    printf 'Linux: %s (%s)\nInit: %s\n' "${kernel:-UNKNOWN}" "$arch" "$init"
    for file in /proc/[0-9]*/stat; do
        read -r stat <"$file" || continue
        case "${stat#* }" in
            '(runsvdir) '[RSDTI]' 1 '*) echo 'Service supervisor: runit (runsvdir is a child of PID 1)'; break ;;
        esac
    done
    for tool in sway pipewire wireplumber; do printf '%s: %s\n' "$tool" "$(report_version "$tool")"; done
    for tool in ip iw wpctl pactl swaymsg timeout; do
        if command -v "$tool" >/dev/null; then present="$present $tool"; else missing="$missing $tool"; fi
    done
    printf 'Tools present:%s\nTools absent:%s\n' "${present:- none}" "${missing:- none}"
}

report_git() {
    env -i PATH="$PATH" HOME=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_OPTIONAL_LOCKS=0 \
        git --git-dir="$repo/.git" "$@" </dev/null
}

report_hardware() {
    # Extract a model designation, never the free-form remainder of a CPU brand string.
    local cpu
    cpu=$(awk -F ': ' '/^model name[[:space:]]*:/ {
        if (match($2,/(AMD Ryzen [3579] [0-9][0-9][0-9][0-9](HX3D|X3D|HX|HS|GE|X|G|H|U)?|Intel\(R\) Core\(TM\) i[3579]-[0-9]+(KF|KS|HX|HK|[KFUHT])?|AMD EPYC [0-9][0-9A-Z][0-9][0-9]P?|Intel\(R\) Xeon\(R\) (Platinum|Gold|Silver|Bronze) [0-9]+[A-Z]?)( |$)/) && RLENGTH<=48) {
            model=substr($2,RSTART,RLENGTH); sub(/ $/,"",model); print model
        }
        exit
    }' /proc/cpuinfo) || cpu=
    printf 'CPU: %s\n' "${cpu:-UNKNOWN (unrecognized or unavailable model)}"
    [ -f "$hardware_script" ] || { echo 'UNAVAILABLE: hardware helper'; return; }
    { sh "$hardware_script" --graphics && echo SHH_DRM_OK; } | awk '
        $1=="PCI" && $3~/^\[[[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]]:[[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]]\]$/ {
            if (++n<=8) {
                driver=substr($4,8)
                if ($4!~/^driver=(amdgpu|radeon|i915|xe|nouveau|nvidia|virtio_gpu|vmwgfx|bochs-drm|ast|unbound)$/) driver="UNKNOWN"
                print "GPU model (PCI vendor:device): " substr($3,2,9) ", driver=" driver
            }
        }
        $0=="SHH_DRM_OK" { card=1 }
        END { if (!n) print "UNKNOWN: no PCI display model identified"
              if (n>8) print "Additional GPU entries omitted"
              print (card ? "OK: DRM card node visible" : "UNKNOWN: no DRM card node confirmed") }'
}

report_config() {
    if runtime_dir_present; then echo 'OK: runtime directory exists'
    else echo 'FAIL: runtime directory unset or missing'; fi
    if [ -f "$list" ]; then echo 'OK: installation manifest present'
    else echo 'UNAVAILABLE: installation manifest'; fi
    echo 'NOT TESTED: managed files, packages, groups and services'
}

report_graphics() (
    local dir="$HOME/.local/state/shh" log chunk summary
    # Pin the working directory and reject symlinks in its path.
    if ! command -v timeout >/dev/null; then echo 'NOT TESTED: safe log reader unavailable'; return; fi
    if ! cd -P "$dir" || [ "$PWD" != "$dir" ]; then
        echo 'UNAVAILABLE: session log directory'; return
    fi
    for log in wm.log wm-crash.log; do
        if chunk=$(log_window start "$log" report); then
            printf '%s logged renderer: %s\n' "$log" "$(printf '%s\n' "$chunk" | logged_renderer report)"
        else echo "$log: UNAVAILABLE (safe log window)"; continue; fi
        if chunk=$(log_window end "$log" report); then
            summary=$(printf '%s\n' "$chunk" | graphics_errors session report)
            printf '%s historical errors (last 64 KiB): %s\n' "$log" "${summary:-no matching category}"
        else echo "$log: UNAVAILABLE (end window)"; fi
    done
)

report_build() {
    local build_tools='' tools tool
    [ -f "$distro_file" ] && [ "$distro" != unknown ] || { echo 'UNAVAILABLE: distro build checks'; return; }
    # All supported distros declare the tools near the top. Never trust a partial line.
    tools=$(head -c 4097 "$distro_file" | LC_ALL=C awk '
        { bytes += length($0) + 1 }
        bytes > 4096 { print "LIMIT"; exit }
        /^build_tools=/ {
            if (length($0) > 256) print "LIMIT"
            else if ($0 ~ /^build_tools=\047[a-z0-9 -]*\047$/) print substr($0,14,length($0)-14)
            exit
        }')
    case "$tools" in
        LIMIT) echo 'UNKNOWN: build tool inspection limit (4096-byte header, 256-byte declaration)'; return ;;
        '') echo 'UNKNOWN: build tool list'; return ;;
    esac
    for tool in $tools; do
        case "$tool" in kiss|cc|make|meson|ninja|pkg-config|pacman|makepkg|xbps-query|xbps-install) ;;
            *) echo 'UNKNOWN: unrecognized build tool list'; return ;;
        esac
        case "$build_tools " in *" $tool "*) ;; *) build_tools="$build_tools $tool" ;; esac
    done
    ok() { printf 'OK: %s available\n' "$1"; }
    bad() { printf 'FAIL: %s\n' "$1"; }
    check_build_tools
    echo 'NOT TESTED: build filesystem and compilation'
}

report_network() {
    local path other=0 wifi=0 partial=0
    if [ -r /sys/class/net ] && [ -x /sys/class/net ]; then
        for path in /sys/class/net/*; do
            [ -d "$path" ] && [ "${path##*/}" != lo ] || continue
            other=$((other+1))
            [ -x "$path" ] || partial=1
            if wifi_interface "$path"; then wifi=$((wifi+1)); fi
        done
        printf 'Non-loopback interfaces: %d, identified Wi-Fi: %d\n' "$other" "$wifi"
        [ "$other" != 0 ] || echo 'WARN: no non-loopback interface visible'
        [ "$partial" = 0 ] || echo 'UNAVAILABLE: incomplete Wi-Fi inventory'
    else echo 'UNAVAILABLE: interface inventory'; fi
    if [ -L /etc/resolv.conf ]; then echo 'NOT TESTED: resolver file is a symbolic link'
    elif [ -f /etc/resolv.conf ] && ! [ "$(stat -c %s /etc/resolv.conf)" -le 65536 ]; then
        echo 'NOT TESTED: resolver file exceeds inspection limit or size unavailable'
    else network_dns; fi
    echo 'NOT TESTED: Wi-Fi association, addresses, routes and external reachability'
}

report_audio() {
    local prog
    audio_processes || { echo 'UNAVAILABLE: current-user process inventory'; return; }
    for prog in pipewire wireplumber pipewire-pulse; do
        case "$visible" in
            *" $prog "*) echo "OK: $prog process visible for current user" ;;
            *) if [ "$partial" = yes ]; then echo "UNAVAILABLE: incomplete process inventory for $prog"
               else echo "UNKNOWN: $prog not visible (session readiness untested)"; fi ;;
        esac
    done
    echo 'NOT TESTED: session readiness, audio server, routing and playback'
}

report() (
    # Only audited helpers use these printers. Their arguments are fixed labels
    # or numbers. A failed required probe is data, independent of output failure.
    step() { :; }
    info() { printf '%s\n' "$1"; }
    ok() { printf '%s\n' "$1"; }
    warn() { printf '%s\n' "$1"; }
    bad() { printf '%s\n' "$1"; }
    printf '%s\n' 'Shhware diagnostic report' \
        'Automatic sanitization may miss personal data. Review manually before posting.'
    for section in system hardware config graphics performance build network audio; do
        printf '\n[%s]\n' "$section"
        case "$section" in
            performance) (load_memory) ;;
            *) ("report_$section") ;;
        esac || echo 'UNAVAILABLE: section collection incomplete'
    done
)

print_report() {
    local body
    distro=
    [ ! -f /etc/os-release ] || distro=$(awk -F= '$1=="ID" {gsub(/["\047]/,"",$2); print $2; exit}' /etc/os-release) || distro=
    case "$distro" in kiss|artix|void) ;; *) distro=unknown ;; esac
    # BusyBox timeout detaches its short-lived timer and closes stdout. Keep
    # the capture pipe open until those timers exit, including on a fast probe.
    body=$(report </dev/null 4>&1) || exit 1
    trap '' PIPE
    printf '%s\n' "$body" || exit 1
}
