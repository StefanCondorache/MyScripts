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

# Default configuration values
DEFAULT_LIMIT="100"
INCLUDE_DIRS=false

# ==========================================
# CORE ANALYSIS ENGINE
# ==========================================

analyze_path() {
    local target_dir="$1"
    local item_limit="${2:-$DEFAULT_LIMIT}"

    if [ ! -d "$target_dir" ]; then
        echo -e "$ERROR Target directory '$target_dir' does not exist or is inaccessible."
        exit 1
    fi

    # Ensure the limit is a valid positive integer
    if ! [[ "$item_limit" =~ ^[0-9]+$ ]] || [ "$item_limit" -eq 0 ]; then
        echo -e "$WARNING Invalid limit '$item_limit' provided. Falling back to default: $DEFAULT_LIMIT."
        item_limit="$DEFAULT_LIMIT"
    fi

    # Only escalate when the target actually needs it — scanning your own files should not ask for a password
    local sudo_cmd="sudo"
    local real_dir
    real_dir=$(realpath "$target_dir")
    if [ "$EUID" -eq 0 ] || [ "$real_dir" = "$HOME" ] || [[ "$real_dir" == "$HOME"/* ]]; then
        sudo_cmd=""
    fi

    echo -e "$INFO Display limit configured to: ${YELLOW}$item_limit items${NC}"
    echo -e "$WARNING This might take a moment depending on the storage size..."
    echo -e "$INFO Executing root-isolated space calculation...\n"

    if [ "$INCLUDE_DIRS" = true ]; then
        echo -e "$INFO Scanning space allocation for ${YELLOW}both files and directories${NC} in: ${YELLOW}$target_dir${NC}"
        # Highly optimized single-pass traversal (your original memory alias logic)
        $sudo_cmd du -ahx "$target_dir" 2>/dev/null | sort -rh | head -n "$item_limit"
    else
        echo -e "$INFO Scanning space allocation for ${YELLOW}files only${NC} in: ${YELLOW}$target_dir${NC}"
        # Files-only filter requires find to isolate individual file nodes efficiently
        $sudo_cmd find "$target_dir" -xdev -type f -exec du -h {} + 2>/dev/null | sort -rh | head -n "$item_limit"
    fi

    echo -e "\n$SUCCESS Scan complete for $target_dir."
}

# ==========================================
# TERMINAL UI & MOUNT POINT DETECTION
# ==========================================

get_menu_options() {
    local raw_df
    mapfile -t raw_df < <(df -h -x tmpfs -x devtmpfs -x efivarfs -x loop | awk 'NR>1 {print $6 "," $2 "," $3 "," $4}')

    local max_len=20
    local p line

    for p in "Root Directory (/)" "User Home ($HOME)"; do
        if [ ${#p} -gt $max_len ]; then
            max_len=${#p}
        fi
    done

    for line in "${raw_df[@]}"; do
        local mnt_path="${line%%,*}"
        if [ ${#mnt_path} -gt $max_len ]; then
            max_len=${#mnt_path}
        fi
    done

    local col_width=$((max_len + 5))

    printf "%-${col_width}s %s\n" "Root Directory (/)" "(System Partition Root)"
    printf "%-${col_width}s %s\n" "User Home ($HOME)" "(User Storage Environment)"

    for line in "${raw_df[@]}"; do
        local path total used free
        IFS=, read -r path total used free <<< "$line"

        local details="([${used}/${total} used] — ${free} free)"
        printf "%-${col_width}s %s\n" "$path" "$details"
    done
}

select_target_tui() {
    local selected=0
    local first_run=true

    mapfile -t targets < <(get_menu_options)

    local key=""
    local total_lines=$((6 + ${#targets[@]}))

    tput civis
    trap 'tput cnorm; exit' EXIT INT TERM

    while true; do
        if [ "$first_run" = false ]; then
            echo -en "\033[${total_lines}A"
        fi
        first_run=false

        echo -e "${CYAN}=======================================================================${NC}\033[K"
        echo -e "${CYAN}                      SPACE HUNTER STORAGE TUI                         ${NC}\033[K"
        echo -e "${CYAN}=======================================================================${NC}\033[K"
        echo -e "Use [UP/DOWN] arrows to select target, [ENTER] to execute, [Q] to quit.\033[K"
        echo -e "\033[K"

        for i in "${!targets[@]}"; do
            if [ "$i" -eq "$selected" ]; then
                echo -e "  \033[1;32m> ${targets[$i]} \033[0m\033[K"
            else
                echo -e "    ${targets[$i]}\033[K"
            fi
        done
        echo -e "${CYAN}=======================================================================${NC}\033[K"

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
        elif [[ $key == "q" || $key == "Q" ]]; then
            trap - EXIT INT TERM
            tput cnorm
            echo -e "\n$INFO Aborted."
            exit 0
        elif [[ -z $key ]]; then
            break
        fi
    done

    trap - EXIT INT TERM
    tput cnorm
    echo ""

    local raw_selection="${targets[$selected]}"
    
    if [[ "$raw_selection" == *"User Home"* ]]; then
        TARGET_PATH="$HOME"
    elif [[ "$raw_selection" == *"Root Directory"* ]]; then
        TARGET_PATH="/"
    else
        TARGET_PATH=$(echo "$raw_selection" | awk '{print $1}')
    fi

    # Interactive prompt to include directories
    read -p "Include directories in the scan results? (y/N): " include_dirs_ans
    if [[ "$include_dirs_ans" =~ ^[Yy]$ ]]; then
        INCLUDE_DIRS=true
    fi

    # Interactive prompt for entry count override
    read -p "Enter number of items to display [Default: $DEFAULT_LIMIT]: " user_limit
    if [[ -n "$user_limit" ]]; then
        TARGET_LIMIT="$user_limit"
    else
        TARGET_LIMIT="$DEFAULT_LIMIT"
    fi
    echo ""
}

# ==========================================
# MAIN EXECUTION & ARGUMENT PARSING
# ==========================================

usage() {
    echo "Usage: space-hunter [-d|--dirs] [path] [limit]"
    echo ""
    echo "  -d, --dirs   Include directory totals, not just individual files."
    echo "  -h, --help   Show this message."
    echo ""
    echo "  path         Directory to scan. Omit it to launch the interactive TUI."
    echo "  limit        Number of results to display (default: $DEFAULT_LIMIT)."
}

# Flags may appear anywhere; the remaining positional arguments are path and limit
POSITIONAL=()

while [ $# -gt 0 ]; do
    case "$1" in
        -d|--dirs)
            INCLUDE_DIRS=true
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo -e "$ERROR Unknown flag provided: $1"
            usage
            exit 1
            ;;
        *)
            POSITIONAL+=("$1")
            ;;
    esac
    shift
done

if [ ${#POSITIONAL[@]} -gt 0 ]; then
    TARGET_PATH="${POSITIONAL[0]}"
    TARGET_LIMIT="${POSITIONAL[1]}"
else
    select_target_tui
fi

analyze_path "$TARGET_PATH" "$TARGET_LIMIT"