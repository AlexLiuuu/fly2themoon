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
    "mxp-it-ping.vultr.com|Milan|eu"
    # Middle East & Africa (me)
    "tlv-il-ping.vultr.com|Tel Aviv|me"
    "jnb-za-ping.vultr.com|Johannesburg|me"
)

# --- Defaults ---
COUNT=50
DOWNLOAD=false
TOP_N=5
OUTPUT=""
TMPDIR_PATH=""
PING_TIMEOUT_FLAG=""
REGIONS=""
VERBOSE=false
JOBS=0
HTTPS_ROUNDS=3
ROUNDS=3

usage() {
    cat <<'EOF'
fly2themoon - Find the best Vultr region for your network

Usage: vultr-speed-test.sh [OPTIONS]

Tests all 33 Vultr regions with ICMP ping and HTTPS timing (TCP connect,
TLS handshake, TTFB). Runs 3 rounds by default and uses median scores
to filter out transient network noise (e.g. GFW interference).

Options:
  -c, --count N         Number of pings per host (default: 50)
  -R, --rounds N        Number of test rounds for stability (default: 3)
  -d, --download        Run download speed test on top results
  -n, --top N           How many top hosts to speed-test (default: 5)
  -r, --region REGIONS  Comma-separated regions: ap,na,sa,eu,me (default: all)
  -j, --jobs N          Max parallel jobs (default: 0 = unlimited)
  -v, --verbose         Show TCP connect and TLS handshake times
  -o, --output FILE     Save results to CSV file
  -h, --help            Show this help

Regions:
  ap  Asia Pacific       na  North America      sa  South America
  eu  Europe             me  Middle East/Africa

Examples:
  ./vultr-speed-test.sh                    # 3 rounds, all 33 regions
  ./vultr-speed-test.sh -R 1              # Single round (quick test)
  ./vultr-speed-test.sh -c 5              # 5 pings each (faster)
  ./vultr-speed-test.sh -r ap,na          # Only Asia Pacific + North America
  ./vultr-speed-test.sh -v                 # Show TCP/TLS breakdown
  ./vultr-speed-test.sh -j 4              # Max 4 parallel tests
  ./vultr-speed-test.sh -d                 # Include download speed test
  ./vultr-speed-test.sh -o results.csv     # Save to CSV
EOF
    exit 0
}

filter_datacenters() {
    if [ -z "$REGIONS" ]; then
        return
    fi
    local filtered=()
    local entry host location region
    for entry in "${DATACENTERS[@]}"; do
        IFS='|' read -r host location region <<< "$entry"
        if echo ",$REGIONS," | grep -qi ",$region,"; then
            filtered+=("$entry")
        fi
    done
    if [ ${#filtered[@]} -eq 0 ]; then
        echo "Error: no datacenters match region(s): $REGIONS"
        echo "Valid regions: ap, na, sa, eu, me"
        exit 1
    fi
    DATACENTERS=("${filtered[@]}")
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
            -c|--count)    COUNT="$2"; shift 2 ;;
            -R|--rounds)   ROUNDS="$2"; shift 2 ;;
            -d|--download) DOWNLOAD=true; shift ;;
            -n|--top)      TOP_N="$2"; shift 2 ;;
            -r|--region)   REGIONS="$2"; shift 2 ;;
            -j|--jobs)     JOBS="$2"; shift 2 ;;
            -v|--verbose)  VERBOSE=true; shift ;;
            -o|--output)   OUTPUT="$2"; shift 2 ;;
            -h|--help)     usage ;;
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
        loss="100.0"
    fi

    if echo "$output" | grep -qE 'round-trip|rtt'; then
        read -r min avg max stddev <<< "$(echo "$output" | awk -F'[ /=]+' '/round-trip|rtt/ {print $6, $7, $8, $9}')"
    else
        min="99999" avg="99999" max="99999" stddev="99999"
    fi

    echo "${avg}|${min}|${max}|${stddev}|${loss}|${host}|${location}" > "$result_file"
}

https_test() {
    local host="$1" tmpdir="$2"
    local tcp_vals="" tls_vals="" ttfb_vals=""
    local good=0 r output tcp tls ttfb

    for r in $(seq 1 "$HTTPS_ROUNDS"); do
        output=$(curl -o /dev/null -s -w '%{time_connect}|%{time_appconnect}|%{time_starttransfer}' \
            --max-time 10 --connect-timeout 5 "https://$host/vultr.com.100MB.bin" 2>/dev/null || true)
        if [ -n "$output" ]; then
            IFS='|' read -r tcp tls ttfb <<< "$output"
            tcp=$(awk "BEGIN{printf \"%.1f\", $tcp * 1000}")
            tls=$(awk "BEGIN{printf \"%.1f\", $tls * 1000}")
            ttfb=$(awk "BEGIN{printf \"%.1f\", $ttfb * 1000}")
            if [ "$tls" != "0.0" ]; then
                tcp_vals="$tcp_vals $tcp"
                tls_vals="$tls_vals $tls"
                ttfb_vals="$ttfb_vals $ttfb"
                good=$((good + 1))
            fi
        fi
    done

    if [ "$good" -gt 0 ]; then
        tcp=$(echo "$tcp_vals" | tr ' ' '\n' | grep -v '^$' | sort -n | awk "NR==$(( (good+1)/2 )){print}")
        tls=$(echo "$tls_vals" | tr ' ' '\n' | grep -v '^$' | sort -n | awk "NR==$(( (good+1)/2 )){print}")
        ttfb=$(echo "$ttfb_vals" | tr ' ' '\n' | grep -v '^$' | sort -n | awk "NR==$(( (good+1)/2 )){print}")
    else
        tcp="99999" tls="99999" ttfb="99999"
    fi

    echo "${tcp}|${tls}|${ttfb}" > "$tmpdir/${host}.https"
}

run_pings() {
    local tmpdir="$1"
    local total=${#DATACENTERS[@]}
    local entry host location region
    local i=0

    printf "  Phase 1/2: Ping (%d hosts, %d times each)\n\n" "$total" "$COUNT"

    for entry in "${DATACENTERS[@]}"; do
        IFS='|' read -r host location region <<< "$entry"
        ( ping_host "$host" "$location" "$tmpdir" "$COUNT" ) &
        if [ "$JOBS" -gt 0 ]; then
            i=$((i + 1))
            if [ "$((i % JOBS))" -eq 0 ]; then
                wait
            fi
        fi
    done
    wait
    printf "\r  Ping: %d/%d  done\n" "$total" "$total"
}

run_https_tests() {
    local tmpdir="$1"
    local total=${#DATACENTERS[@]}
    local entry host location region
    local i=0

    printf "  Phase 2/2: HTTPS timing (%d rounds, median)\n\n" "$HTTPS_ROUNDS"

    for entry in "${DATACENTERS[@]}"; do
        IFS='|' read -r host location region <<< "$entry"
        ( https_test "$host" "$tmpdir" ) &
        if [ "$JOBS" -gt 0 ]; then
            i=$((i + 1))
            if [ "$((i % JOBS))" -eq 0 ]; then
                wait
            fi
        fi
    done
    wait
    printf "\r  HTTPS: %d/%d  done\n\n" "$total" "$total"
}

compute_score() {
    local avg="$1" loss="$2" ttfb="$3" stddev="$4"
    awk "BEGIN {
        lat = ($avg >= 99999) ? 0 : (100 - $avg / 5)
        if (lat < 0) lat = 0

        lr = 1 - $loss / 25
        if (lr < 0) lr = 0
        ls = lr * lr * 100

        ts = ($ttfb >= 99999) ? 0 : (100 - $ttfb / 30)
        if (ts < 0) ts = 0

        jit = ($stddev >= 99999) ? 0 : (100 - $stddev)
        if (jit < 0) jit = 0

        if ($ttfb >= 99999) {
            score = (0.50 * ls + 0.30 * lat + 0.20 * jit) * 0.6
        } else {
            score = 0.20 * lat + 0.35 * ls + 0.30 * ts + 0.15 * jit
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

        local tcp="99999" tls="99999" ttfb="99999"
        local https_file="$tmpdir/${host}.https"
        if [ -f "$https_file" ]; then
            IFS='|' read -r tcp tls ttfb < "$https_file"
        fi

        local score
        score=$(compute_score "$avg" "$loss" "$ttfb" "$stddev")

        echo "${score}|${avg}|${min}|${max}|${stddev}|${loss}|${tcp}|${tls}|${ttfb}|${host}|${location}" >> "$raw_file"
    done

    sort -t'|' -k1 -rn "$raw_file" > "$results_file"
    echo "$results_file"
}

median_of() {
    echo "$@" | tr ' ' '\n' | grep -v '^$' | sort -n | awk "NR==$(( ($# + 1) / 2 )){print}"
}

merge_rounds() {
    local tmpdir="$1"
    local final_raw="$tmpdir/final_raw.txt"
    local final_file="$tmpdir/final.txt"
    local rounds_count="$ROUNDS"

    > "$final_raw"

    local hosts_file="$tmpdir/round_1/sorted.txt"
    while IFS='|' read -r _ _ _ _ _ _ _ _ _ host location; do
        local scores="" avgs="" losses="" ttfbs="" stddevs="" tcps="" tlss=""
        local max_score=0 min_score=999

        local rd
        for rd in $(seq 1 "$rounds_count"); do
            local rfile="$tmpdir/round_${rd}/sorted.txt"
            [ -f "$rfile" ] || continue
            local line
            line=$(grep "|${host}|${location}" "$rfile" || true)
            [ -z "$line" ] && continue

            local s a mn mx sd l tc tl tf h lo
            IFS='|' read -r s a mn mx sd l tc tl tf h lo <<< "$line"

            scores="$scores $s"
            avgs="$avgs $a"
            losses="$losses $l"
            ttfbs="$ttfbs $tf"
            stddevs="$stddevs $sd"
            tcps="$tcps $tc"
            tlss="$tlss $tl"

            if [ "$s" -gt "$max_score" ] 2>/dev/null; then max_score="$s"; fi
            if [ "$s" -lt "$min_score" ] 2>/dev/null; then min_score="$s"; fi
        done

        local n
        n=$(echo "$scores" | wc -w | tr -d ' ')
        if [ "$n" -eq 0 ]; then
            continue
        fi

        local med_score med_avg med_loss med_ttfb med_stddev med_tcp med_tls
        med_score=$(echo "$scores" | tr ' ' '\n' | grep -v '^$' | sort -n | awk "NR==$(( (n+1)/2 )){print}")
        med_avg=$(echo "$avgs" | tr ' ' '\n' | grep -v '^$' | sort -n | awk "NR==$(( (n+1)/2 )){print}")
        med_loss=$(echo "$losses" | tr ' ' '\n' | grep -v '^$' | sort -n | awk "NR==$(( (n+1)/2 )){print}")
        med_ttfb=$(echo "$ttfbs" | tr ' ' '\n' | grep -v '^$' | sort -n | awk "NR==$(( (n+1)/2 )){print}")
        med_stddev=$(echo "$stddevs" | tr ' ' '\n' | grep -v '^$' | sort -n | awk "NR==$(( (n+1)/2 )){print}")
        med_tcp=$(echo "$tcps" | tr ' ' '\n' | grep -v '^$' | sort -n | awk "NR==$(( (n+1)/2 )){print}")
        med_tls=$(echo "$tlss" | tr ' ' '\n' | grep -v '^$' | sort -n | awk "NR==$(( (n+1)/2 )){print}")

        local stability=$((max_score - min_score))

        echo "${med_score}|${med_avg}|0|0|${med_stddev}|${med_loss}|${med_tcp}|${med_tls}|${med_ttfb}|${host}|${location}|${stability}" >> "$final_raw"
    done < "$hosts_file"

    sort -t'|' -k1 -rn "$final_raw" > "$final_file"
    echo "$final_file"
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
    if [ "$val" = "99999" ] || [ "$val" = "99999.0" ]; then
        printf "%${width}s" "---"
    else
        printf "%${width}s" "$val"
    fi
}

color_stability() {
    local stab="$1"
    if [ "$stab" -le 5 ] 2>/dev/null; then
        printf "%s" "$GREEN"
    elif [ "$stab" -le 15 ] 2>/dev/null; then
        printf "%s" "$YELLOW"
    else
        printf "%s" "$RED"
    fi
}

print_table() {
    local results_file="$1"
    local rank=0
    local show_stab=false
    [ "$ROUNDS" -gt 1 ] && show_stab=true

    printf "  ${BOLD}%-4s %-18s %5s" "#" "Location" "Score"
    if [ "$show_stab" = true ]; then
        printf "  %5s" "Stab"
    fi
    printf "  %8s  %5s" "Ping(ms)" "Loss"
    if [ "$VERBOSE" = true ]; then
        printf "  %8s  %8s  %8s" "Jit(ms)" "TCP(ms)" "TLS(ms)"
    fi
    printf "  %8s" "TTFB(ms)"
    if [ "$DOWNLOAD" = true ]; then
        printf "  %10s" "Speed"
    fi
    printf "${RESET}\n"

    printf "  %-4s %-18s %5s" "---" "------------------" "-----"
    if [ "$show_stab" = true ]; then
        printf "  %5s" "-----"
    fi
    printf "  %8s  %5s" "--------" "-----"
    if [ "$VERBOSE" = true ]; then
        printf "  %8s  %8s  %8s" "--------" "--------" "--------"
    fi
    printf "  %8s" "--------"
    if [ "$DOWNLOAD" = true ]; then
        printf "  %10s" "----------"
    fi
    printf "\n"

    while IFS='|' read -r score avg min max stddev loss tcp tls ttfb host location stability; do
        rank=$((rank + 1))
        local color
        color=$(color_score "$score")

        local loss_str
        if [ "$avg" = "99999" ]; then
            loss_str="100%"
        else
            loss_str="${loss}%"
        fi

        printf "  ${color}%-4s %-18s %5s" "$rank" "$location" "$score"

        if [ "$show_stab" = true ]; then
            local stab_color
            stab_color=$(color_stability "${stability:-0}")
            printf "  ${RESET}${stab_color}%5s${RESET}${color}" "±${stability:-0}"
        fi

        printf "  $(format_val "$avg")  %5s" "$loss_str"

        if [ "$VERBOSE" = true ]; then
            printf "  $(format_val "$stddev")  $(format_val "$tcp")  $(format_val "$tls")"
        fi

        printf "  $(format_val "$ttfb")"

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

print_recommendation() {
    local results_file="$1"
    local count=0
    local recs=""

    while IFS='|' read -r score avg min max stddev loss tcp tls ttfb host location stability; do
        [ "$avg" = "99999" ] && continue
        [ "${stability:-99}" -gt 15 ] && continue
        count=$((count + 1))
        [ "$count" -gt 3 ] && break
        if [ -n "$recs" ]; then
            recs="$recs, "
        fi
        recs="${recs}${location} (${score}, ±${stability:-0})"
    done < "$results_file"

    if [ -n "$recs" ]; then
        printf "\n  ${GREEN}${BOLD}Recommended:${RESET} ${GREEN}%s${RESET}\n" "$recs"
    fi
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

    while IFS='|' read -r score avg _ _ _ _ _ _ _ host location _; do
        if [ "$avg" = "99999" ]; then
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

    if [ "$ROUNDS" -gt 1 ]; then
        echo "rank,location,host,score,stability,rounds,avg_ms,loss_pct,tcp_ms,tls_ms,ttfb_ms,speed_mbps" > "$output_file"
    else
        echo "rank,location,host,score,avg_ms,loss_pct,tcp_ms,tls_ms,ttfb_ms,speed_mbps" > "$output_file"
    fi

    while IFS='|' read -r score avg min max stddev loss tcp tls ttfb host location stability; do
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
        if [ "$avg" = "99999" ]; then csv_avg=""; fi
        if [ "$tcp" = "99999" ] || [ "$tcp" = "99999.0" ]; then csv_tcp=""; fi
        if [ "$tls" = "99999" ] || [ "$tls" = "99999.0" ]; then csv_tls=""; fi
        if [ "$ttfb" = "99999" ] || [ "$ttfb" = "99999.0" ]; then csv_ttfb=""; fi
        if [ "$ROUNDS" -gt 1 ]; then
            echo "$rank,$location,$host,$score,${stability:-0},$ROUNDS,$csv_avg,$loss,$csv_tcp,$csv_tls,$csv_ttfb,$speed" >> "$output_file"
        else
            echo "$rank,$location,$host,$score,$csv_avg,$loss,$csv_tcp,$csv_tls,$csv_ttfb,$speed" >> "$output_file"
        fi
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
    filter_datacenters

    TMPDIR_PATH=$(mktemp -d)
    trap cleanup EXIT INT TERM

    printf "\n"
    printf "  ${BOLD}fly2themoon - Vultr Speed Test${RESET}\n"
    if [ "$ROUNDS" -gt 1 ]; then
        printf "  %s | %d DCs | %d rounds x %d pings\n\n" \
            "$(date '+%Y-%m-%d %H:%M')" "${#DATACENTERS[@]}" "$ROUNDS" "$COUNT"
    else
        printf "  %s | %d DCs | %d pings\n\n" \
            "$(date '+%Y-%m-%d %H:%M')" "${#DATACENTERS[@]}" "$COUNT"
    fi

    local rd
    for rd in $(seq 1 "$ROUNDS"); do
        local round_dir="$TMPDIR_PATH/round_${rd}"
        mkdir -p "$round_dir"

        if [ "$ROUNDS" -gt 1 ]; then
            printf "  ${BOLD}── Round %d/%d ──────────────────────────────${RESET}\n" "$rd" "$ROUNDS"
        fi

        run_pings "$round_dir"
        run_https_tests "$round_dir"
        parse_results "$round_dir" > /dev/null
    done

    local results_file
    if [ "$ROUNDS" -gt 1 ]; then
        printf "  Merging %d rounds (median)...\n\n" "$ROUNDS"
        results_file=$(merge_rounds "$TMPDIR_PATH")
    else
        results_file="$TMPDIR_PATH/round_1/sorted.txt"
    fi

    if [ "$DOWNLOAD" = true ]; then
        run_downloads "$results_file" "$TMPDIR_PATH"
    fi

    print_table "$results_file"

    if [ "$ROUNDS" -gt 1 ]; then
        print_recommendation "$results_file"
        printf "\n  ${DIM}Score = 20%% ping + 35%% loss + 30%% TTFB + 15%% jitter (median of %d rounds)${RESET}\n" "$ROUNDS"
        printf "  ${DIM}Stab = score range across rounds (lower = more consistent)${RESET}\n\n"
    else
        printf "\n  ${DIM}Score = 20%% ping + 35%% loss + 30%% TTFB + 15%% jitter (higher is better)${RESET}\n\n"
    fi

    if [ -n "$OUTPUT" ]; then
        save_csv "$results_file" "$OUTPUT"
    fi
}

main "$@"
