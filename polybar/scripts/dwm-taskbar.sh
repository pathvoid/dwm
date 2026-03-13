#!/bin/bash

# Polybar taskbar module - shows all windows on current desktop like a Windows taskbar
# Groups windows by WM_CLASS so each app shows once (like Windows)
# Click inactive app to focus, click active app to minimize

COLOR_ACTIVE="${DWM_TASKBAR_ACTIVE_COLOR:-#eceff4}"
COLOR_INACTIVE="${DWM_TASKBAR_INACTIVE_COLOR:-#d8dee9}"
COLOR_HIDDEN="${DWM_TASKBAR_HIDDEN_COLOR:-#4c566a}"
BG_ACTIVE="${DWM_TASKBAR_ACTIVE_BG:-#434c5e}"
MAX_TITLE_LEN="${DWM_TASKBAR_MAX_TITLE:-25}"
FONT="${DWM_TASKBAR_FONT:-2}"

get_wm_class() {
    local wid="$1"
    local class
    class=$(xprop -id "$wid" WM_CLASS 2>/dev/null | sed -n 's/.*"\([^"]*\)"$/\1/p')
    [ -z "$class" ] && class="unknown"
    echo "$class"
}

get_window_title() {
    local wid="$1"
    local title
    title=$(xprop -id "$wid" _NET_WM_NAME 2>/dev/null | sed 's/^[^"]*"\(.*\)"$/\1/')
    if [ -z "$title" ] || echo "$title" | grep -q "not found"; then
        title=$(xprop -id "$wid" WM_NAME 2>/dev/null | sed 's/^[^"]*"\(.*\)"$/\1/')
    fi
    [ -z "$title" ] && title="?"
    if [ ${#title} -gt "$MAX_TITLE_LEN" ]; then
        title="${title:0:$((MAX_TITLE_LEN - 1))}…"
    fi
    echo "$title"
}

update_taskbar() {
    local current_desktop
    current_desktop=$(xprop -root _NET_CURRENT_DESKTOP 2>/dev/null | awk '{print $3}')
    current_desktop=${current_desktop:-0}

    local active_wid
    active_wid=$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null | grep -o '0x[0-9a-fA-F]*' | tail -1)
    local active_dec=0
    [ -n "$active_wid" ] && active_dec=$(printf "%d" "$active_wid" 2>/dev/null)

    local client_list
    client_list=$(xprop -root _NET_CLIENT_LIST 2>/dev/null | grep -o '0x[0-9a-fA-F]*')

    if [ -z "$client_list" ]; then
        echo ""
        return
    fi

    # Group windows by WM_CLASS
    declare -A class_wid         # representative window ID (prefer active, then first visible)
    declare -A class_title       # title to display
    declare -A class_is_active   # whether the active window belongs to this class
    declare -A class_all_hidden  # whether all windows of this class are hidden
    declare -A class_count       # number of windows in this class
    local class_order=()         # preserve order of first appearance
    local -A class_seen

    while IFS= read -r wid; do
        [ -z "$wid" ] && continue

        local win_desktop
        win_desktop=$(xprop -id "$wid" _NET_WM_DESKTOP 2>/dev/null | awk '{print $3}')
        [ -z "$win_desktop" ] && continue
        [ "$win_desktop" = "4294967295" ] && continue
        [ "$win_desktop" != "$current_desktop" ] && continue

        # Skip dock/toolbar/utility windows
        local wtype
        wtype=$(xprop -id "$wid" _NET_WM_WINDOW_TYPE 2>/dev/null)
        if echo "$wtype" | grep -qE "DOCK|TOOLBAR|UTILITY|SPLASH|NOTIFICATION"; then
            continue
        fi

        # Skip windows requesting to be hidden from taskbar
        local wstate
        wstate=$(xprop -id "$wid" _NET_WM_STATE 2>/dev/null)
        if echo "$wstate" | grep -q "SKIP_TASKBAR"; then
            continue
        fi

        local class
        class=$(get_wm_class "$wid")
        local wid_dec
        wid_dec=$(printf "%d" "$wid" 2>/dev/null)

        # Detect hidden: dwm moves hidden windows far off-screen (negative X)
        local hidden=0
        local win_x
        win_x=$(xwininfo -id "$wid" 2>/dev/null | awk '/Absolute upper-left X:/{print $4}')
        if [ -n "$win_x" ] && [ "$win_x" -lt -1000 ] 2>/dev/null; then
            hidden=1
        fi

        # Track order
        if [ -z "${class_seen[$class]}" ]; then
            class_order+=("$class")
            class_seen[$class]=1
            class_all_hidden[$class]=1
            class_count[$class]=0
            class_is_active[$class]=0
        fi

        class_count[$class]=$(( ${class_count[$class]} + 1 ))

        # If not hidden, this class is not all-hidden
        [ "$hidden" -eq 0 ] && class_all_hidden[$class]=0

        # Check if this window is the active one
        if [ "$wid_dec" = "$active_dec" ]; then
            class_is_active[$class]=1
            class_wid[$class]="$wid"
            class_title[$class]=$(get_window_title "$wid")
        fi

        # Set representative wid if not yet set
        if [ -z "${class_wid[$class]}" ]; then
            class_wid[$class]="$wid"
            class_title[$class]=$(get_window_title "$wid")
        fi
    done <<< "$client_list"

    # Build output
    local output=""
    local idx=0
    for class in "${class_order[@]}"; do
        local wid="${class_wid[$class]}"
        local title="${class_title[$class]}"
        local cnt="${class_count[$class]}"

        # Add count indicator if multiple windows
        if [ "$cnt" -gt 1 ]; then
            title="$title ($cnt)"
        fi

        [ "$idx" -gt 0 ] && output+=" "
        idx=$((idx + 1))

        if [ "${class_all_hidden[$class]}" = "1" ]; then
            # All windows hidden - dimmed, click to restore
            output+="%{F${COLOR_HIDDEN}}%{T${FONT}}%{A1:dwm-taskbar-toggle $wid:} $title %{A}%{T-}%{F-}"
        elif [ "${class_is_active[$class]}" = "1" ]; then
            # Active app - highlighted, click to minimize
            output+="%{F${COLOR_ACTIVE}}%{B${BG_ACTIVE}}%{T${FONT}}%{A1:dwm-taskbar-toggle $wid:} $title %{A}%{T-}%{B-}%{F-}"
        else
            # Inactive app - normal, click to focus
            output+="%{F${COLOR_INACTIVE}}%{T${FONT}}%{A1:dwm-taskbar-toggle $wid:} $title %{A}%{T-}%{F-}"
        fi
    done

    echo "$output"
}

if [ "$1" = "--tail" ]; then
    update_taskbar
    xprop -root -spy _NET_ACTIVE_WINDOW _NET_CLIENT_LIST _NET_CURRENT_DESKTOP _DWM_TOGGLE_HIDE 2>/dev/null | \
    while read -r line; do
        update_taskbar
    done
else
    update_taskbar
fi
