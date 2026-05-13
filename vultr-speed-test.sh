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

Usage: vultr-speed-test.sh [OPTIONS]

Tests all 33 Vultr regions with ICMP ping and HTTPS timing (TCP connect,
TLS handshake, TTFB). Ranks by weighted score combining latency, packet
loss, and real HTTPS performance.

Options:
  -c, --count N         Number of pings per host (default: 20)
  -d, --download        Run download speed test on top results
  -n, --top N           How many top hosts to speed-test (default: 5)
  -o, --output FILE     Save results to CSV file
  -h, --help            Show this help

Examples:
  ./vultr-speed-test.sh                    # Test all 33 regions
  ./vultr-speed-test.sh -c 5              # 5 pings each (faster)
  ./vultr-speed-test.sh -d                 # Include download speed test
  ./vultr-speed-test.sh -o results.csv     # Save to CSV
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

https_test() {
    local host="$1" tmpdir="$2"
    local output tcp tls ttfb

    output=$(curl -o /dev/null -s -w '%{time_connect}|%{time_appconnect}|%{time_starttransfer}' \
        --max-time 10 --connect-timeout 5 "https://$host/vultr.com.100MB.bin" 2>/dev/null || true)

    if [ -n "$output" ]; then
        IFS='|' read -r tcp tls ttfb <<< "$output"
        tcp=$(awk "BEGIN{printf \"%.1f\", $tcp * 1000}")
        tls=$(awk "BEGIN{printf \"%.1f\", $tls * 1000}")
        ttfb=$(awk "BEGIN{printf \"%.1f\", $ttfb * 1000}")
        if [ "$tls" = "0.0" ]; then
            tcp="999" tls="999" ttfb="999"
        fi
    else
        tcp="999" tls="999" ttfb="999"
    fi

    echo "${tcp}|${tls}|${ttfb}" > "$tmpdir/${host}.https"
}

run_pings() {
    local tmpdir="$1"
    local total=${#DATACENTERS[@]}
    local entry host location region

    printf "  Phase 1/2: Ping (%d hosts, %d times each)\n\n" "$total" "$COUNT"

    for entry in "${DATACENTERS[@]}"; do
        IFS='|' read -r host location region <<< "$entry"
        ( ping_host "$host" "$location" "$tmpdir" "$COUNT" ) &
    done

    local done_count=0
    while [ "$done_count" -lt "$total" ]; do
        sleep 0.5
        done_count=$(find "$tmpdir" -name "*.result" 2>/dev/null | wc -l | tr -d ' ')
        printf "\r  Ping: %d/%d" "$done_count" "$total"
    done
    wait
    printf "\r  Ping: %d/%d  done\n" "$total" "$total"
}

run_https_tests() {
    local tmpdir="$1"
    local total=${#DATACENTERS[@]}
    local entry host location region

    printf "  Phase 2/2: HTTPS timing\n\n"

    for entry in "${DATACENTERS[@]}"; do
        IFS='|' read -r host location region <<< "$entry"
        ( https_test "$host" "$tmpdir" ) &
    done

    local done_count=0
    while [ "$done_count" -lt "$total" ]; do
        sleep 0.5
        done_count=$(find "$tmpdir" -name "*.https" 2>/dev/null | wc -l | tr -d ' ')
        printf "\r  HTTPS: %d/%d" "$done_count" "$total"
    done
    wait
    printf "\r  HTTPS: %d/%d  done\n\n" "$total" "$total"
}

compute_score() {
    local avg="$1" loss="$2" ttfb="$3"
    awk "BEGIN {
        lat = ($avg >= 999) ? 0 : (100 - $avg / 5)
        if (lat < 0) lat = 0
        ls = 100 - $loss * 3
        if (ls < 0) ls = 0
        ts = ($ttfb >= 999) ? 0 : (100 - $ttfb / 10)
        if (ts < 0) ts = 0
        if ($ttfb >= 999) {
            score = (0.40 * ls + 0.60 * lat) * 0.6
        } else {
            score = 0.30 * ls + 0.35 * ts + 0.35 * lat
        }
        printf \"%.0f\", score
    }"
}

parse_results() {
    local tmpdir="$1"
    local raw_file="$tmpdir/raw.txt"
    local results_file="$tmpdir/sorted.txt"

    > "$raw_file"

    for f in "$tmpdir"/*.result; do
        [ -f "$f" ] || continue
        local avg min max stddev loss host location
        IFS='|' read -r avg min max stddev loss host location < "$f"

        local tcp="999" tls="999" ttfb="999"
        local https_file="$tmpdir/${host}.https"
        if [ -f "$https_file" ]; then
            IFS='|' read -r tcp tls ttfb < "$https_file"
        fi

        local score
        score=$(compute_score "$avg" "$loss" "$ttfb")

        echo "${score}|${avg}|${min}|${max}|${stddev}|${loss}|${tcp}|${tls}|${ttfb}|${host}|${location}" >> "$raw_file"
    done

    sort -t'|' -k1 -rn "$raw_file" > "$results_file"
    echo "$results_file"
}

color_score() {
    local score="$1"
    if [ "$score" -le 0 ] 2>/dev/null; then
        printf "%s" "$DIM"
    elif [ "$score" -ge 70 ] 2>/dev/null; then
        printf "%s" "$GREEN"
    elif [ "$score" -ge 40 ] 2>/dev/null; then
        printf "%s" "$YELLOW"
    else
        printf "%s" "$RED"
    fi
}

format_val() {
    local val="$1" width="${2:-8}"
    if [ "$val" = "999" ] || [ "$val" = "999.0" ]; then
        printf "%${width}s" "---"
    else
        printf "%${width}s" "$val"
    fi
}

print_table() {
    local results_file="$1"
    local rank=0

    printf "  ${BOLD}%-4s %-18s %5s  %8s  %5s  %8s" "#" "Location" "Score" "Ping(ms)" "Loss" "TTFB(ms)"
    if [ "$DOWNLOAD" = true ]; then
        printf "  %10s" "Speed"
    fi
    printf "${RESET}\n"

    printf "  %-4s %-18s %5s  %8s  %5s  %8s" "---" "------------------" "-----" "--------" "-----" "--------"
    if [ "$DOWNLOAD" = true ]; then
        printf "  %10s" "----------"
    fi
    printf "\n"

    while IFS='|' read -r score avg min max stddev loss tcp tls ttfb host location; do
        rank=$((rank + 1))
        local color
        color=$(color_score "$score")

        local loss_str
        if [ "$loss" = "100" ] && [ "$avg" = "999" ]; then
            loss_str="100%"
        else
            loss_str="${loss}%"
        fi

        printf "  ${color}%-4s %-18s %5s  $(format_val "$avg")  %5s  $(format_val "$ttfb")" \
            "$rank" "$location" "$score" "$loss_str"

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

    while IFS='|' read -r score avg _ _ _ _ _ _ _ host location; do
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

    echo "rank,location,host,score,avg_ms,loss_pct,tcp_ms,tls_ms,ttfb_ms,speed_mbps" > "$output_file"

    while IFS='|' read -r score avg min max stddev loss tcp tls ttfb host location; do
        rank=$((rank + 1))
        local speed=""
        local speed_file="$TMPDIR_PATH/${host}.speed"
        if [ -f "$speed_file" ]; then
            speed=$(cat "$speed_file")
            if [ "$speed" = "--" ]; then
                speed=""
            fi
        fi
        local csv_avg="$avg" csv_tcp="$tcp" csv_tls="$tls" csv_ttfb="$ttfb"
        if [ "$avg" = "999" ]; then csv_avg=""; fi
        if [ "$tcp" = "999" ] || [ "$tcp" = "999.0" ]; then csv_tcp=""; fi
        if [ "$tls" = "999" ] || [ "$tls" = "999.0" ]; then csv_tls=""; fi
        if [ "$ttfb" = "999" ] || [ "$ttfb" = "999.0" ]; then csv_ttfb=""; fi
        echo "$rank,$location,$host,$score,$csv_avg,$loss,$csv_tcp,$csv_tls,$csv_ttfb,$speed" >> "$output_file"
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
    printf "  ${BOLD}fly2themoon - Vultr Speed Test${RESET}\n"
    printf "  %s | %d DCs | Pings: %d\n\n" "$(date '+%Y-%m-%d %H:%M')" "${#DATACENTERS[@]}" "$COUNT"

    run_pings "$TMPDIR_PATH"
    run_https_tests "$TMPDIR_PATH"

    local results_file
    results_file=$(parse_results "$TMPDIR_PATH")

    if [ "$DOWNLOAD" = true ]; then
        run_downloads "$results_file" "$TMPDIR_PATH"
    fi

    print_table "$results_file"

    printf "\n  ${DIM}Score = 35%% ping + 30%% loss + 35%% HTTPS TTFB (higher is better)${RESET}\n\n"

    if [ -n "$OUTPUT" ]; then
        save_csv "$results_file" "$OUTPUT"
    fi
}

main "$@"
