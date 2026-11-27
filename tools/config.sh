# Shhware config API 1

# The choices of the small menus, as "value<TAB>shown text".
modes="copy${tab}Copy   copies, the repo can be deleted
link${tab}Link   links to the repo, edits land in it"
# Both have the same look, options and keys (config/vim, config/nvim).
editors="vim${tab}Vim      fewer dependencies
nvim${tab}Neovim"
file_managers="broot${tab}Broot    folders as a tree
yazi${tab}Yazi     previews, tabs"
# The xkb options for switching the layout.
toggles="alt_shift_toggle${tab}Alt+Shift
ctrl_shift_toggle${tab}Ctrl+Shift
win_space_toggle${tab}Super+Space
caps_toggle${tab}Caps Lock
lalt_lshift_toggle${tab}Left Alt+Left Shift"
# DNS servers, comma-separated (install.sh: /etc/resolvconf.conf). Others
# are set by hand in the config.
dns_list="dhcp${tab}DHCP
1.1.1.1,1.0.0.1${tab}Cloudflare
9.9.9.9,149.112.112.112${tab}Quad9
8.8.8.8,8.8.4.4${tab}Google"

renderers="auto${tab}Auto
gles2${tab}GLES2
pixman${tab}Pixman"

# Change NAME in the config, or add it: set_value NAME VALUE.
set_value() {
    if [ -f "$shh_config" ] && grep -q "^$1=" "$shh_config"; then
        sed -i "s|^$1=.*|$1=$2|" "$shh_config"
    else
        printf '%s=%s\n' "$1" "$2" >>"$shh_config"
    fi
}

# Switch NAME between yes and no: toggle NAME [DEFAULT].
#
# DEFAULT is the value when NAME is not set (yes).
toggle() {
    local default="${2:-yes}"
    if [ "$(setting "$1" "$default")" = yes ]; then set_value "$1" no; else set_value "$1" yes; fi
    note="$(cap "$1"): $(setting "$1" "$default")"
}

top_lines() {
    line settings '' settings 'Install options >'
    line features '' features 'Desktop tools >'
    line misc '' misc 'Additional packages >'
    # Only KISS has parts in the recipes group (components.txt).
    [ -z "$(group recipes)" ] || line recipes '' recipes 'KISS recipes >'
}

top_act() {
    case "$1" in
        settings)
            loop settings 'Enter: change   Esc: back' settings_lines settings_act ;;
        features|misc)
            # The features tab holds the parts with no group.
            tab_group=$1
            [ "$1" != features ] || tab_group=''
            loop "$1" 'Enter: on / off   Esc: back' group_lines group_act ;;
        recipes)
            tab_group=recipes
            loop recipes 'Enter: on / off   Esc: back' recipe_lines recipe_act ;;
    esac
    note=''
}

settings_lines() {
    local label_width=20 dns
    dns=$(label_of "$dns_list" "$(setting dns dhcp)")
    line mode '' mode "$(setting mode "$mode_now") >"
    line layouts '' layouts "$(setting layouts us,ru) >"
    line layout_toggle '' 'switch layout' "$(label_of "$toggles" "$(setting layout_toggle alt_shift_toggle)") >"
    line dns '' DNS "${dns:-Custom} >"
    line gpu '' graphics "$(setting gpu auto) >"
    line editor '' editor "$(setting editor vim) >"
    ! command -v distro_choices >/dev/null || distro_choices
    line files '' 'file manager' "$(setting files broot) >"
    printf -- '-\t\n'
    ! command -v distro_settings >/dev/null || distro_settings
    yes_no nobeep 'Mute the motherboard beeper'
    yes_no maxhz 'Highest refresh rate of every screen'
    if command -v xwayland_hint >/dev/null; then
        yes_no xwayland "$(xwayland_hint)" no
    else
        yes_no xwayland 'X11 programs; after a relogin' no
    fi
    yes_no a11y 'Screen readers in GTK programs; after a relogin' no
}

settings_act() {
    local value
    case "$1" in
        mode)          value=$(choose mode "$modes") ;;
        layout_toggle) value=$(choose 'switch layout' "$toggles") ;;
        dns)           value=$(choose DNS "$dns_list") ;;
        editor)        value=$(choose editor "$editors") ;;
        files)         value=$(choose 'file manager' "$file_managers") ;;
        gpu)
            loop graphics "Enter: change   Esc: back   found: $(found_cards | sed 's/,/, /g')" gpu_lines gpu_act
            note="Graphics: $(setting gpu auto)"
            return 0 ;;
        layouts)
            loop layouts 'Enter: on / off   Esc: back   the first one is the default' layout_lines layout_act
            note="Layouts: $(setting layouts us,ru)"
            return 0 ;;
        xwayland|a11y)
            toggle "$1" no
            return 0 ;;
        *)
            # distro_act comes from distro.sh (Artix: aur helper). A line that is
            # not its own is a yes / no.
            if ! command -v distro_act >/dev/null || ! value=$(distro_act "$1"); then
                toggle "$1"
                return 0
            fi ;;
    esac
    [ -n "$value" ] || return 0
    set_value "$1" "$value"
    case "$1" in
        dns) note="DNS: $(label_of "$dns_list" "$value")" ;;
        *) note="$(cap "$1"): $value" ;;
    esac
}

# Print "name|default" of the parts in a group (components.txt).
group() {
    read_list "$components_file" | awk -F'|' -v g="$1" '$5 == g { print $1 "|" $6 }'
}

# Print the tab of '$tab_group': a line per part, Enter turns it on / off.
group_lines() {
    local name default
    group "$tab_group" | while IFS='|' read -r name default; do
        case "$name" in
            shh_tools) yes_no "$name" 'Diagnostics, reports and debloater' yes 'Shhware Tools' ;;
            *) yes_no "$name" '' "${default:-yes}" ;;
        esac
    done
}

group_act() {
    toggle "$1" "$(group "$tab_group" | awk -F'|' -v n="$1" '$1 == n { print $2 }')"
}

recipe_lines() {
    line all '' 'all recipes' 'Every recipe, even the ones the setup needs >'
    line preview '' preview 'Changes since the last applied selection >'
    local parts
    parts=$(group_lines)
    [ -z "$parts" ] || printf '%s\t\n%s\n' - "$parts"
}

recipe_act() {
    case "$1" in
        preview)
            local header
            header=$(printf ' \n%s\n \n%s' "$(config_banner preview)" 'Local sources only; rebuilds are estimates. Esc: back')
            show_recipe_changes | fzf --no-input --header="$header" >/dev/null || :
            ;;
        all)
            loop 'all recipes' 'Enter: on / off   Esc: back' all_recipe_lines all_recipe_act \
                "$(center 'Off: next source in KISS_PATH, if present; installed package stays')"
            note='' ;;
        *) group_act "$1" ;;
    esac
}

# Every recipe of ours with its version.
#
# A recipe that is off (recipe_NAME=no) is not copied for kiss
# (kiss_repos: distro.sh). That counts from the next build of the package:
# what is installed stays as it is.
#
# The versions line up in one column, a tab's width (8 spaces) right of the
# longest name. A real tab can't be used: fzf splits the lines on it.
all_recipe_lines() {
    local dir name box width
    width=$(ls "$recipes_dir" | awk '{ if (length > w) w = length } END { print w + 8 }')
    for dir in "$recipes_dir"/*/; do
        dir=${dir%/} name=${dir##*/}
        box='[x]'
        [ "$(setting "recipe_$name" yes)" = yes ] || box='[ ]'
        printf "%s\t%-3s %-${width}s%s\n" "recipe_$name" "$box" "$(cap "$name")" "$(cut -d' ' -f1 "$dir/version")"
    done
}

all_recipe_act() {
    toggle "$1"
    note="${1#recipe_}: $(setting "$1" yes)"
}

# Print every xkb layout as "code<TAB>name".
#
# Before the install there is no evdev.lst yet (it comes with sway), so
# a short list is used.
all_layouts() {
    local lst=/usr/share/X11/xkb/rules/evdev.lst
    if [ -f "$lst" ]; then
        awk '/^! layout/ { f = 1; next } /^!/ { f = 0 }
            f && NF { c = $1; $1 = ""; sub(/^ +/, ""); print c "\t" $0 }' "$lst"
        return
    fi
    printf '%s\n' "us${tab}English (US)" "gb${tab}English (UK)" "ru${tab}Russian" \
        "ua${tab}Ukrainian" "by${tab}Belarusian" "kz${tab}Kazakh" "de${tab}German" \
        "fr${tab}French" "es${tab}Spanish" "it${tab}Italian" "pl${tab}Polish" \
        "pt${tab}Portuguese" "tr${tab}Turkish" "cz${tab}Czech"
}

# Print the layouts turned on first, in their order, then the rest.
layout_lines() {
    all_layouts | awk -F "$tab" -v now="$(setting layouts us,ru)" '
        { name[$1] = $2; order[++n] = $1 }
        END {
            k = split(now, on, ",")
            for (i = 1; i <= k; i++) { printf "%s\t[x] %-14s %s\n", on[i], on[i], name[on[i]]; used[on[i]] }
            for (i = 1; i <= n; i++)
                if (!(order[i] in used)) printf "%s\t[ ] %-14s %s\n", order[i], order[i], name[order[i]]
        }'
}

# Print the cards scripts/hardware finds, as the choices below
# (amd,nvidia). "nothing" in a VM or with no card.
menu_cards() {
    local cards
    cards=$(sh "$hardware_script" 2>/dev/null) || cards=''
    "$1" "$cards" | sed 's/^nvidia-580xx$/nvidia/' |
        grep -x 'amd\|intel\|nvidia\|nouveau' | sort -u | paste -sd, -
}

found_cards() {
    local cards
    cards=$(menu_cards available_drivers)
    printf '%s\n' "${cards:-nothing}"
}

# Print the graphics menu: auto, or the drivers picked by hand
# (gpu=amd,nvidia; gpu_drivers: lib.sh).
gpu_lines() {
    local now card label text
    label=$(label_of "$renderers" "$(setting renderer auto)")
    line renderer '' renderer "${label:-Auto} >"
    now=$(setting render_device auto)
    [ "$now" != auto ] || now=Auto
    line render_device '' 'render device' "$now >"
    printf -- '-\t\n'
    now=$(setting gpu auto)
    if [ "$now" = auto ]; then line auto '[x]' auto 'By the card, recommended'
    else line auto '[ ]' auto 'By the card, recommended'; fi
    now=$(menu_cards gpu_drivers)
    for card in amd intel nvidia nouveau; do
        case "$card" in
            amd)     label=AMD;     text='' ;;
            intel)   label=Intel;   text='' ;;
            nvidia)  [ -f "$packages_dir/nvidia.csv" ] || [ -f "$packages_dir/nvidia-580xx.csv" ] || continue
                     label=NVIDIA;  text='The NVIDIA driver' ;;
            nouveau) label=Nouveau; text='The free NVIDIA driver' ;;
        esac
        case ",$now," in
            *",$card,"*) line "$card" '[x]' "$label" "$text" ;;
            *)           line "$card" '[ ]' "$label" "$text" ;;
        esac
    done
}

# Switch to auto, or turn a card on or off, starting from the cards found.
#
# The NVIDIA driver and nouveau can't be on both.
gpu_act() {
    local now
    if [ "$1" = render_device ]; then
        local devices
        devices=$(sh "$hardware_script" --render-devices) || devices=''
        now=$(choose 'render device' "auto${tab}Auto${devices:+
$devices}")
        [ -n "$now" ] || return 0
        set_value render_device "$now"
        note="Render device: $now (next hardware-rendered session)"
        return 0
    fi
    if [ "$1" = renderer ]; then
        now=$(choose renderer "$renderers")
        [ -n "$now" ] || return 0
        set_value renderer "$now"
        note="Renderer: $(label_of "$renderers" "$now") (next Sway start)"
        return 0
    fi
    if [ "$1" = auto ]; then
        set_value gpu auto
        note="Graphics: auto"
        return 0
    fi
    now=$(menu_cards gpu_drivers)
    case ",$now," in
        *",$1,"*) now=$(printf '%s\n' "$now" | tr , '\n' | grep -vxF -- "$1" | paste -sd, -) ;;
        *)
            case "$1" in
                nvidia)  now=$(printf '%s\n' "$now" | tr , '\n' | grep -vx nouveau | paste -sd, -) ;;
                nouveau) now=$(printf '%s\n' "$now" | tr , '\n' | grep -vx nvidia | paste -sd, -) ;;
            esac
            now="${now:+$now,}$1" ;;
    esac
    set_value gpu "${now:-none}"
    note="Graphics: ${now:-none}"
}

# Turn a layout off (one has to stay) or on, at the end of the list.
layout_act() {
    local now
    now=$(setting layouts us,ru)
    case ",$now," in
        *",$1,"*)
            if [ "$now" = "$1" ]; then
                note="One layout has to stay"
                return 0
            fi
            now=$(printf '%s\n' "$now" | tr ',' '\n' | grep -vxF -- "$1" | paste -sd, -) ;;
        *)
            now="$now,$1" ;;
    esac
    set_value layouts "$now"
    note="Layouts: $now"
}

# Show 'shh config': the tabs settings, features, misc (and recipes on
# KISS). Every change goes to the config at once.
config() {
    local config_menu=1
    [ -f "$components_file" ] || error "not found: $components_file (sh lib/link.sh)"
    command -v fzf >/dev/null || pkg_install "" fzf || error "cannot install fzf"
    # The look of every menu. .zprofile sets it only after the install.
    if [ -z "${FZF_DEFAULT_OPTS_FILE:-}" ] && [ -f "$repo/config/fzf/fzfrc" ]; then
        export FZF_DEFAULT_OPTS_FILE="$repo/config/fzf/fzfrc"
    fi

    mkdir -p "${shh_config%/*}"
    if [ ! -f "$shh_config" ]; then
        printf '%s\n' \
            '# ~/.config/shh/config - your choices for install.sh and shh update' \
            '# change: shh config, then shh update (or edit here); a missing line = the default' \
            >"$shh_config"
    fi

    loop 'shh config' 'Enter: open   Esc: done' top_lines top_act

    info "saved in $shh_config"
    [ -n "${SHH_INSTALL:-}" ] || info "apply: shh update (before the first install: sh install.sh)"
}

# Change a color in every config: color OLD NEW.
#
# The palette lives in each program's own config, config/foot/foot.ini
# lists it. The installed files are edited. With '--link' that is the
# repo, with copies the next update puts the colors of the repo back
# (yours stay in .bak files).
color() {
    [ "$#" -eq 2 ] || { usage >&2; exit 1; }
    [ -f "$list" ] || error "no $list (sh lib/link.sh)"

    local old new files c k f
    old=$(printf '%s' "${1#\#}" | tr 'A-F' 'a-f')
    new=$(printf '%s' "${2#\#}" | tr 'A-F' 'a-f')
    for c in "$old" "$new"; do
        printf '%s' "$c" | grep -qx '[0-9a-f]\{6\}' || error "not a color: $c (6 hex digits, like e6e6e6)"
    done

    # Configs and scripts, but not shh itself: its help has a color in it.
    files=$(while IFS="$tab" read -r k f || [ -n "$k$f" ]; do
        case "$f" in "$share"/*|*/shh) continue ;; esac
        printf '%s\n' "$f"
    done <"$list")

    # From now on both are one color: changing it later changes both.
    #
    # One name per line. 'xargs -0', as busybox has no '-d'.
    ! printf '%s\n' "$files" | tr '\n' '\0' | xargs -r -0 grep -qiI -- "$new" || warn "$new is already used too"

    files=$(printf '%s\n' "$files" | tr '\n' '\0' | xargs -r -0 grep -liI -- "$old" || true)
    [ -n "$files" ] || error "$old is not used in the configs"

    # 'readlink -f': with '--link' edit the repo file and keep the link.
    printf '%s\n' "$files" | while IFS= read -r f; do
        sed -i "s/$old/$new/gI" "$(readlink -f "$f")"
        ok "$f"
    done
    info "to see it: Super+Shift+C (sway, bar), makoctl reload, new foot and vim / nvim windows"
}
