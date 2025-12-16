#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
MAX_DISPLAY=25
PROGRESS_WIDTH=50

# Determine du command
if command -v gdu &> /dev/null; then
    DU_CMD="gdu -sb"
    DU_MULTIPLIER=1
else
    DU_CMD="du -sk"
    DU_MULTIPLIER=1024
fi

# Functions
format_bytes() {
    local bytes="${1:-0}"
    
    [[ ! "$bytes" =~ ^[0-9]+$ ]] && { echo "0B"; return; }
    
    if (( bytes >= 1073741824 )); then
        printf "%.2fGB" $(bc <<< "scale=2; $bytes / 1073741824")
    elif (( bytes >= 1048576 )); then
        printf "%.2fMB" $(bc <<< "scale=2; $bytes / 1048576")
    elif (( bytes >= 1024 )); then
        printf "%.2fKB" $(bc <<< "scale=2; $bytes / 1024")
    else
        printf "%dB" $bytes
    fi
}

progress_bar() {
    local current=$1 total=$2
    
    (( total == 0 )) && return
    
    local percentage=$(( current * 100 / total ))
    local filled=$(( current * PROGRESS_WIDTH / total ))
    
    printf "\r${CYAN}Progress: [${NC}"
    printf "█%.0s" $(seq 1 $filled)
    printf "░%.0s" $(seq 1 $(( PROGRESS_WIDTH - filled )))
    printf "${CYAN}] %d%% (%d/%d)${NC}" $percentage $current $total
}

print_separator() {
    local char=$1 width=${2:-80}
    printf "${char}%.0s" $(seq 1 $width)
    echo
}

# Header
echo -e "${BOLD}${BLUE}node_modules Analyzer${NC}"
print_separator "═"
echo
echo -e "${CYAN}Analyzing directory:${NC} $(basename "$(pwd)")"
echo -e "${CYAN}Full path:${NC} $(pwd)"
echo

# Find directories using fd
echo -e "${YELLOW}Scanning for node_modules directories...${NC}"

dirs=()
if command -v fd &> /dev/null; then
    # fd with all ignore files disabled, prune to avoid nested node_modules
    while IFS= read -r dir; do
        dirs+=("$dir")
    done < <(fd -I -H --no-global-ignore-file -t d --prune '^node_modules$' . 2>/dev/null)
fi

# Fallback to find if fd not available or found nothing
if [ ${#dirs[@]} -eq 0 ]; then
    echo -e "${YELLOW}Using find...${NC}"
    while IFS= read -r dir; do
        dirs+=("$dir")
    done < <(find . -name "node_modules" -type d -prune 2>/dev/null)
fi

# Check if any found
if [ ${#dirs[@]} -eq 0 ]; then
    echo -e "${RED}No node_modules directories found.${NC}"
    exit 0
fi

echo -e "${GREEN}Found ${#dirs[@]} node_modules directories${NC}"
echo

# Calculate sizes
echo -e "${YELLOW}Calculating sizes...${NC}"
tmp_file=$(mktemp)

current=0
for dir in "${dirs[@]}"; do
    progress_bar $((++current)) ${#dirs[@]}
    
    size=$($DU_CMD "$dir" 2>/dev/null | cut -f1)
    size_bytes=$(( ${size:-0} * DU_MULTIPLIER ))
    
    (( size_bytes > 0 )) && echo "${dir#./}|$size_bytes" >> "$tmp_file"
done

echo -e "\n"

# Sort by size
sort -t'|' -k2 -nr "$tmp_file" -o "$tmp_file"

# Calculate column widths
max_dir_length=20
max_size_length=10
total_size=0

while IFS='|' read -r dir size; do
    (( ${#dir} > max_dir_length )) && max_dir_length=${#dir}
    
    formatted=$(format_bytes $size)
    (( ${#formatted} > max_size_length )) && max_size_length=${#formatted}
    
    total_size=$(( total_size + size ))
done < "$tmp_file"

# Display results
echo -e "${BOLD}Results${NC}"
print_separator "═"

printf "${BOLD}%-${max_dir_length}s  %${max_size_length}s  %10s${NC}\n" \
    "Directory" "Size" "Percentage"
print_separator "─"

# Show entries
count=0
while IFS='|' read -r dir size && (( ++count <= MAX_DISPLAY )); do
    percentage=$(bc <<< "scale=1; $size * 100 / $total_size")
    formatted=$(format_bytes $size)
    
    # Color by size
    if (( size >= 1073741824 )); then color=$RED
    elif (( size >= 524288000 )); then color=$YELLOW
    elif (( size >= 104857600 )); then color=$CYAN
    else color=$GREEN
    fi
    
    printf "${color}%-${max_dir_length}s${NC}  %${max_size_length}s  %9s%%\n" \
        "$dir" "$formatted" "$percentage"
done < "$tmp_file"

total_count=$(wc -l < "$tmp_file")
(( total_count > MAX_DISPLAY )) && \
    echo -e "${CYAN}... and $((total_count - MAX_DISPLAY)) more${NC}"

# Summary
print_separator "─"
echo -e "${BOLD}Summary${NC}"
print_separator "═"

# Get largest
IFS='|' read -r largest_dir largest_size < "$tmp_file"

printf "%-20s%60s\n" \
    "Total directories:" "$total_count" \
    "Total size:" "$(format_bytes $total_size)" \
    "Average size:" "$(format_bytes $((total_size / total_count)))"

# Truncate if needed
if (( ${#largest_dir} > 40 )); then
    largest_display="${largest_dir:0:37}..."
else
    largest_display="$largest_dir"
fi

printf "%-20s%60s\n" \
    "Largest directory:" "$largest_display ($(format_bytes $largest_size))"

rm -f "$tmp_file"
print_separator "═"