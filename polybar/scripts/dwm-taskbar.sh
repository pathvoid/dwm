#!/bin/bash

# Polybar taskbar module - shows all windows on current desktop like a Windows taskbar
# Click inactive window to focus, click active window to minimize

COLOR_ACTIVE="${DWM_TASKBAR_ACTIVE_COLOR:-#eceff4}"
COLOR_INACTIVE="${DWM_TASKBAR_INACTIVE_COLOR:-#d8dee9}"
COLOR_HIDDEN="${DWM_TASKBAR_HIDDEN_COLOR:-#4c566a}"
BG_ACTIVE="${DWM_TASKBAR_ACTIVE_BG:-#434c5e}"
MAX_TITLE_LEN="${DWM_TASKBAR_MAX_TITLE:-25}"
FONT="${DWM_TASKBAR_FONT:-2}"

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

is_hidden() {
    local wid="$1"
    xprop -id "$wid" WM_STATE 2>/dev/null | grep -q "Iconic"
}

update_taskbar() {
    local current_desktop
    current_desktop=$(xprop -root _NET_CURRENT_DESKTOP 2>/dev/null | awk '{print $3}')
    current_desktop=${current_desktop:-0}

    local active_wid
    active_wid=$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null | grep -o '0x[0-9a-fA-F]*' | tail -1)
    # Normalize to decimal for comparison
    local active_dec=0
    [ -n "$active_wid" ] && active_dec=$(printf "%d" "$active_wid" 2>/dev/null)

    local client_list
    client_list=$(xprop -root _NET_CLIENT_LIST 2>/dev/null | grep -o '0x[0-9a-fA-F]*')

    if [ -z "$client_list" ]; then
        echo ""
        return
    fi

    local output=""
    local count=0
    while IFS= read -r wid; do
        [ -z "$wid" ] && continue

        local win_desktop
        win_desktop=$(xprop -id "$wid" _NET_WM_DESKTOP 2>/dev/null | awk '{print $3}')
        [ -z "$win_desktop" ] && continue
        [ "$win_desktop" = "4294967295" ] && continue
        [ "$win_desktop" != "$current_desktop" ] && continue

        # Skip dock/toolbar/utility windows (polybar, systray, etc.)
        local wtype
        wtype=$(xprop -id "$wid" _NET_WM_WINDOW_TYPE 2>/dev/null)
        echo "$wtype" | grep -qE "DOCK|TOOLBAR|UTILITY|SPLASH|NOTIFICATION" && continue

        local title
        title=$(get_window_title "$wid")
        local wid_dec
        wid_dec=$(printf "%d" "$wid" 2>/dev/null)

        [ "$count" -gt 0 ] && output+=" "
        count=$((count + 1))

        if is_hidden "$wid"; then
            # Hidden/minimized - dimmed, click to restore
            output+="%{F${COLOR_HIDDEN}}%{T${FONT}}%{A1:wmctrl -ia $wid:} $title %{A}%{T-}%{F-}"
        elif [ "$wid_dec" = "$active_dec" ]; then
            # Active window - highlighted with background, click to minimize
            output+="%{F${COLOR_ACTIVE}}%{B${BG_ACTIVE}}%{T${FONT}}%{A1:dwm-taskbar-toggle $wid:} $title %{A}%{T-}%{B-}%{F-}"
        else
            # Inactive window - normal, click to focus
            output+="%{F${COLOR_INACTIVE}}%{T${FONT}}%{A1:wmctrl -ia $wid:} $title %{A}%{T-}%{F-}"
        fi
    done <<< "$client_list"

    echo "$output"
}

if [ "$1" = "--tail" ]; then
    update_taskbar
    xprop -root -spy _NET_ACTIVE_WINDOW _NET_CLIENT_LIST _NET_CURRENT_DESKTOP 2>/dev/null | \
    while read -r line; do
        update_taskbar
    done
else
    update_taskbar
fi
