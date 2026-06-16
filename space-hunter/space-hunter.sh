#!/bin/bash

# Copyright (c) 2026 Condorache Ștefan-Eugen
#
# This software is released under the MIT License.

# Define standardized output colors/tags for the UI
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

INFO="${CYAN}[INFO]${NC}"
SUCCESS="${GREEN}[SUCCESS]${NC}"
WARNING="${YELLOW}[WARNING]${NC}"
ERROR="${RED}[ERROR]${NC}"

# ==========================================
# CORE ANALYSIS ENGINE
# ==========================================

analyze_path() {
    local target_dir="$1"

    if [ ! -d "$target_dir" ]; then
        echo -e "$ERROR Target directory '$target_dir' does not exist or is inaccessible."
        exit 1
    fi

    echo -e "$INFO Scanning space allocation for: ${YELLOW}$target_dir${NC}"
    echo -e "$WARNING This might take a moment depending on the storage size..."
    echo -e "$INFO Executing root-isolated file calculation...\n"

    # Preserves your exact 'memory' alias logic with elevated file safety (-x blocks jumping to other FS)
    sudo du -ahx "$target_dir" 2>/dev/null | sort -rh | head -n 100

    echo -e "\n$SUCCESS Scan complete for $target_dir."
}

# ==========================================
# TERMINAL UI & MOUNT POINT DETECTION
# ==========================================

get_menu_options() {
    # 1. Gather raw data from df, filtering out virtual and containerized filesystems
    # It extracts: Path ($6), Total Size ($2), Used Size ($3), Free Size ($4)
    local raw_df
    raw_df=$(df -h -x tmpfs -x devtmpfs -x efivarfs -x loop | awk 'NR>1 {print $6 "," $2 "," $3 "," $4}')

    # 2. Dynamically calculate the longest path string to ensure optimal, proportional padding
    local max_len=20
    local paths=("/")
    
    # Check length of base targets
    for p in "Root Directory (/)" "User Home ($HOME)"; do
        if [ ${#p} -gt $max_len ]; then
            max_len=${#p}
        fi
    done

    # Check length of active system mounts
    for line in $raw_df; do
        local mnt_path
        mnt_path=$(echo "$line" | cut -d, -f1)
        if [ ${#mnt_path} -gt $max_len ]; then
            max_len=${#mnt_path}
        fi
    done

    # Add a buffer padding cushion (5 extra spaces) for UI breathing room
    local col_width=$((max_len + 5))

    # 3. Format and print the base standard options
    printf "%-${col_width}s %s\n" "Root Directory (/)" "(System Partition Root)"
    printf "%-${col_width}s %s\n" "User Home ($HOME)" "(User Storage Environment)"
    
    # 4. Format and print active disks with the used/total space tracker
    for line in $raw_df; do
        local path total used free
        path=$(echo "$line" | cut -d, -f1)
        total=$(echo "$line" | cut -d, -f2)
        used=$(echo "$line" | cut -d, -f3)
        free=$(echo "$line" | cut -d, -f4)

        local details="([${used}/${total} used] — ${free} free)"
        printf "%-${col_width}s %s\n" "$path" "$details"
    done
}

select_target_tui() {
    local selected=0
    local first_run=true

    # Build the dynamic menu list into an array from active mounts
    mapfile -t targets < <(get_menu_options)

    local key=""
    local total_lines=$((6 + ${#targets[@]}))

    # Hide cursor for clean UI, trap ensures it comes back if user hits Ctrl+C
    tput civis
    trap 'tput cnorm; exit' EXIT INT TERM

    while true; do
        # Move cursor up to overwrite previous menu on loops
        if [ "$first_run" = false ]; then
            echo -en "\033[${total_lines}A"
        fi
        first_run=false

        # Clear tracking strings out of active terminal pipelines (\033[K)
        echo -e "${CYAN}=======================================================================${NC}\033[K"
        echo -e "${CYAN}                      SPACE HUNTER STORAGE TUI                         ${NC}\033[K"
        echo -e "${CYAN}=======================================================================${NC}\033[K"
        echo -e "Use [UP/DOWN] arrows to select target, [ENTER] to execute.\033[K"
        echo -e "\033[K"

        for i in "${!targets[@]}"; do
            if [ "$i" -eq "$selected" ]; then
                echo -e "  \033[1;32m> ${targets[$i]} \033[0m\033[K"
            else
                echo -e "    ${targets[$i]}\033[K"
            fi
        done
        echo -e "${CYAN}=======================================================================${NC}\033[K"

        # Read single keypress silently
        read -rsn1 key
        if [[ $key == $'\e' ]]; then
            read -rsn2 key_ext
            case "$key_ext" in
                [A|OA) # Up arrow
                    ((selected--))
                    if [ "$selected" -lt 0 ]; then selected=$((${#targets[@]} - 1)); fi
                    ;;
                [B|OB) # Down arrow
                    ((selected++))
                    if [ "$selected" -ge ${#targets[@]} ]; then selected=0; fi
                    ;;
            esac
        elif [[ -z $key ]]; then
            # Enter key pressed
            break
        fi
    done

    # Restore cursor stability
    trap - EXIT INT TERM
    tput cnorm
    echo "" # Baseline padding

    # Parse and extract the clean path string from the left side of our padded selection
    local raw_selection="${targets[$selected]}"
    
    # Structural fallback evaluation depending on which row was captured
    if [[ "$raw_selection" == *"User Home"* ]]; then
        TARGET_PATH="$HOME"
    elif [[ "$raw_selection" == *"Root Directory"* ]]; then
        TARGET_PATH="/"
    else
        TARGET_PATH=$(echo "$raw_selection" | awk '{print $1}')
    fi
}

# ==========================================
# MAIN EXECUTION
# ==========================================

# Check if an explicit search argument path was specified on invocation
if [ -n "$1" ]; then
    TARGET_PATH="$1"
    analyze_path "$TARGET_PATH"
else
    # Fallback to Interactive Arrow UI Mode
    select_target_tui
    analyze_path "$TARGET_PATH"
fi