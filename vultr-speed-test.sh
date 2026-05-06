#!/usr/bin/env bash
set -euo pipefail

# --- Colors (disabled when not a terminal) ---
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    RED='\033[0;31m'
    DIM='\033[0;90m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    GREEN='' YELLOW='' RED='' DIM='' BOLD='' RESET=''
fi

# --- Vultr Data Centers: host|location|region ---
DATACENTERS=(
    # Asia Pacific (ap)
    "hnd-jp-ping.vultr.com|Tokyo|ap"
    "osaka-jp-ping.vultr.com|Osaka|ap"
    "sgp-ping.vultr.com|Singapore|ap"
    "sel-kor-ping.vultr.com|Seoul|ap"
    "blr-in-ping.vultr.com|Bangalore|ap"
    "del-in-ping.vultr.com|Delhi NCR|ap"
    "bom-in-ping.vultr.com|Mumbai|ap"
    "syd-au-ping.vultr.com|Sydney|ap"
    "mel-au-ping.vultr.com|Melbourne|ap"
    # North America (na)
    "lax-ca-us-ping.vultr.com|Los Angeles|na"
    "sjo-ca-us-ping.vultr.com|Silicon Valley|na"
    "sea-wa-us-ping.vultr.com|Seattle|na"
    "hon-hi-us-ping.vultr.com|Honolulu|na"
    "il-us-ping.vultr.com|Chicago|na"
    "ga-us-ping.vultr.com|Atlanta|na"
    "fl-us-ping.vultr.com|Miami|na"
    "nj-us-ping.vultr.com|New Jersey|na"
    "tx-us-ping.vultr.com|Dallas|na"
    "tor-ca-ping.vultr.com|Toronto|na"
    "mex-mx-ping.vultr.com|Mexico City|na"
    # South America (sa)
    "sao-br-ping.vultr.com|Sao Paulo|sa"
    "scl-cl-ping.vultr.com|Santiago|sa"
    # Europe (eu)
    "lon-gb-ping.vultr.com|London|eu"
    "man-gb-ping.vultr.com|Manchester|eu"
    "par-fr-ping.vultr.com|Paris|eu"
    "fra-de-ping.vultr.com|Frankfurt|eu"
    "ams-nl-ping.vultr.com|Amsterdam|eu"
    "waw-pl-ping.vultr.com|Warsaw|eu"
    "mad-es-ping.vultr.com|Madrid|eu"
    "sto-se-ping.vultr.com|Stockholm|eu"
    "buh-ro-ping.vultr.com|Bucharest|eu"
    # Middle East & Africa (me)
    "tlv-il-ping.vultr.com|Tel Aviv|me"
    "jnb-za-ping.vultr.com|Johannesburg|me"
)

# --- Defaults ---
COUNT=20
DOWNLOAD=false
TOP_N=5
OUTPUT=""
TMPDIR_PATH=""
PING_TIMEOUT_FLAG=""

usage() {
    cat <<'EOF'
fly2themoon - Find the best Vultr region for your network

Usage: fly2themoon.sh [OPTIONS]

Options:
  -c, --count N         Number of pings per host (default: 20)
  -d, --download        Run download speed test on top results
  -n, --top N           How many top hosts to speed-test (default: 5)
  -o, --output FILE     Save results to CSV file
  -h, --help            Show this help

Examples:
  ./fly2themoon.sh                    # Test all 33 regions
  ./fly2themoon.sh -c 5               # 5 pings each (faster)
  ./fly2themoon.sh -d                 # Include download speed test
  ./fly2themoon.sh -o results.csv     # Save to CSV
EOF
    exit 0
}

detect_os() {
    case "$(uname -s)" in
        Darwin) PING_TIMEOUT_FLAG="-t" ;;
        *)      PING_TIMEOUT_FLAG="-W" ;;
    esac
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -c|--count)   COUNT="$2"; shift 2 ;;
            -d|--download) DOWNLOAD=true; shift ;;
            -n|--top)     TOP_N="$2"; shift 2 ;;
            -o|--output)  OUTPUT="$2"; shift 2 ;;
            -h|--help)    usage ;;
            *) echo "Unknown option: $1"; usage ;;
        esac
    done
}

ping_host() {
    local host="$1" location="$2" tmpdir="$3" count="$4"
    local result_file="$tmpdir/${host}.result"
    local output avg min max stddev loss

    output=$(ping -c "$count" "$PING_TIMEOUT_FLAG" 5 "$host" 2>&1) || true

    loss=$(echo "$output" | awk -F'[,%]' '/packet loss/ {gsub(/ /, "", $3); print $3}')
    if [ -z "$loss" ]; then
        loss="100"
    fi

    if echo "$output" | grep -qE 'round-trip|rtt'; then
        read -r min avg max stddev <<< "$(echo "$output" | awk -F'[ /=]+' '/round-trip|rtt/ {print $6, $7, $8, $9}')"
    else
        min="999" avg="999" max="999" stddev="999"
    fi

    echo "${avg}|${min}|${max}|${stddev}|${loss}|${host}|${location}" > "$result_file"
}

run_pings() {
    local tmpdir="$1"
    local total=${#DATACENTERS[@]}
    local entry host location region

    printf "  Pinging %d data centers (%d times each)...\n\n" "$total" "$COUNT"

    for entry in "${DATACENTERS[@]}"; do
        IFS='|' read -r host location region <<< "$entry"
        ( ping_host "$host" "$location" "$tmpdir" "$COUNT" ) &
    done

    local done_count=0
    while [ "$done_count" -lt "$total" ]; do
        sleep 0.5
        done_count=$(find "$tmpdir" -name "*.result" 2>/dev/null | wc -l | tr -d ' ')
        printf "\r  Progress: %d/%d" "$done_count" "$total"
    done
    wait
    printf "\r  Progress: %d/%d  done\n\n" "$total" "$total"
}

parse_results() {
    local tmpdir="$1"
    local results_file="$tmpdir/sorted.txt"

    cat "$tmpdir"/*.result | sort -t'|' -k1 -g > "$results_file"
    echo "$results_file"
}

color_latency() {
    local avg="$1"
    if [ "$avg" = "999" ]; then
        printf "%s" "$DIM"
    elif awk "BEGIN{exit !($avg < 50)}" 2>/dev/null; then
        printf "%s" "$GREEN"
    elif awk "BEGIN{exit !($avg < 150)}" 2>/dev/null; then
        printf "%s" "$YELLOW"
    else
        printf "%s" "$RED"
    fi
}

format_val() {
    local val="$1"
    if [ "$val" = "999" ]; then
        printf "%7s" "---"
    else
        printf "%7s" "$val"
    fi
}

print_table() {
    local results_file="$1"
    local rank=0

    printf "  ${BOLD}%-4s %-18s %7s  %7s  %7s  %5s" "#" "Location" "Avg(ms)" "Min(ms)" "Max(ms)" "Loss"
    if [ "$DOWNLOAD" = true ]; then
        printf "  %10s" "Speed"
    fi
    printf "${RESET}\n"

    printf "  %-4s %-18s %7s  %7s  %7s  %5s" "---" "------------------" "-------" "-------" "-------" "-----"
    if [ "$DOWNLOAD" = true ]; then
        printf "  %10s" "----------"
    fi
    printf "\n"

    while IFS='|' read -r avg min max stddev loss host location; do
        rank=$((rank + 1))
        local color
        color=$(color_latency "$avg")
        local loss_str
        if [ "$loss" = "100" ] && [ "$avg" = "999" ]; then
            loss_str="100%"
        else
            loss_str="${loss}%"
        fi

        printf "  ${color}%-4s %-18s $(format_val "$avg")  $(format_val "$min")  $(format_val "$max")  %5s" \
            "$rank" "$location" "$loss_str"

        if [ "$DOWNLOAD" = true ]; then
            local speed_file="$TMPDIR_PATH/${host}.speed"
            if [ -f "$speed_file" ]; then
                local speed
                speed=$(cat "$speed_file")
                if [ "$speed" = "--" ]; then
                    printf "  %10s" "--"
                else
                    printf "  %7s %s" "$speed" "Mbps"
                fi
            else
                printf "  %10s" "--"
            fi
        fi

        printf "${RESET}\n"
    done < "$results_file"
}

test_download() {
    local host="$1" tmpdir="$2"
    local speed_bytes speed_mbps

    speed_bytes=$(curl -o /dev/null -s -w '%{speed_download}' --max-time 10 \
        "https://$host/vultr.com.100MB.bin" 2>/dev/null) || speed_bytes="0"

    if [ -z "$speed_bytes" ] || [ "$speed_bytes" = "0" ]; then
        echo "--" > "$tmpdir/${host}.speed"
    else
        speed_mbps=$(awk "BEGIN{printf \"%.1f\", $speed_bytes * 8 / 1000000}")
        echo "$speed_mbps" > "$tmpdir/${host}.speed"
    fi
}

run_downloads() {
    local results_file="$1" tmpdir="$2"
    local count=0

    printf "  Running download speed tests (top %d)...\n\n" "$TOP_N"

    while IFS='|' read -r avg _ _ _ _ host location; do
        if [ "$avg" = "999" ]; then
            continue
        fi
        count=$((count + 1))
        if [ "$count" -gt "$TOP_N" ]; then
            break
        fi
        printf "\r  Testing: %-18s (%d/%d)" "$location" "$count" "$TOP_N"
        test_download "$host" "$tmpdir"
    done < "$results_file"

    printf "\r  Download tests complete.          \n\n"
}

save_csv() {
    local results_file="$1" output_file="$2"
    local rank=0

    echo "rank,location,host,avg_ms,min_ms,max_ms,loss_pct,speed_mbps" > "$output_file"

    while IFS='|' read -r avg min max stddev loss host location; do
        rank=$((rank + 1))
        local speed=""
        local speed_file="$TMPDIR_PATH/${host}.speed"
        if [ -f "$speed_file" ]; then
            speed=$(cat "$speed_file")
            if [ "$speed" = "--" ]; then
                speed=""
            fi
        fi
        if [ "$avg" = "999" ]; then
            avg="" min="" max=""
        fi
        echo "$rank,$location,$host,$avg,$min,$max,$loss,$speed" >> "$output_file"
    done < "$results_file"

    printf "  Results saved to: %s\n\n" "$output_file"
}

cleanup() {
    if [ -n "$TMPDIR_PATH" ] && [ -d "$TMPDIR_PATH" ]; then
        rm -rf "$TMPDIR_PATH"
    fi
}

main() {
    parse_args "$@"
    detect_os

    TMPDIR_PATH=$(mktemp -d)
    trap cleanup EXIT INT TERM

    printf "\n"
    printf "  ${BOLD}fly2themoon - Vultr Latency Test${RESET}\n"
    printf "  %s | %d DCs | Pings: %d\n\n" "$(date '+%Y-%m-%d %H:%M')" "${#DATACENTERS[@]}" "$COUNT"

    run_pings "$TMPDIR_PATH"

    local results_file
    results_file=$(parse_results "$TMPDIR_PATH")

    if [ "$DOWNLOAD" = true ]; then
        run_downloads "$results_file" "$TMPDIR_PATH"
    fi

    print_table "$results_file"
    printf "\n"

    if [ -n "$OUTPUT" ]; then
        save_csv "$results_file" "$OUTPUT"
    fi
}

main "$@"
