#!/usr/bin/env bash
# dream.sh — deterministic backbone for the `dream` skill.
#
# The agent-driven steps (spawning scanners, the reducer, applying approved
# diffs) live in SKILL.md. Everything deterministic lives here so it is robust
# and identical every run:
#
#   prepare   discover this repo's new sessions, extract dialogue to cache, pack into
#             shards by token budget, create a run dir + manifest.
#   collect   merge shard findings, append to the ledger, mark sessions processed.
#   mark-proposed  mark findings in proposed-changes.json as awaiting review.
#   finalize  apply review decisions to ledger/suppressions, stamp last_run.
#   status    show processed sessions, pending sessions, and ledger state.
#
# Usage:
#   dream.sh prepare [--limit N] [--full] [--recent]
#   dream.sh collect <run_dir>
#   dream.sh mark-proposed <run_dir>
#   dream.sh finalize <run_dir>
#   dream.sh status

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
DREAM_DIR="$REPO_ROOT/.agents/dreams"
REVIEW_ROOT="$DREAM_DIR/proposals"
STATE="$DREAM_DIR/state.json"
CONFIG_LOCAL="$DREAM_DIR/config.local.json"
LEDGER="$DREAM_DIR/ledger.jsonl"
SUPPRESSIONS="$DREAM_DIR/suppressions.jsonl"
CACHE="$DREAM_DIR/cache/transcripts"
EXTRACT_JQ="$SKILL_DIR/extract.jq"

command -v jq >/dev/null || { echo "ERROR: jq is required" >&2; exit 1; }
command -v uv >/dev/null || { echo "ERROR: uv is required" >&2; exit 1; }

init_runtime() {
  mkdir -p "$DREAM_DIR" "$CACHE" "$REVIEW_ROOT"
  if [ ! -f "$STATE" ]; then
    cat > "$STATE" <<EOF
{
  "version": 1,
  "last_run": null,
  "processed_session_ids": []
}
EOF
  fi
  if [ ! -f "$CONFIG_LOCAL" ]; then
    if jq -e '.config? // empty' "$STATE" >/dev/null 2>&1; then
      jq --arg repo "$REPO_ROOT" --arg codex "$HOME/.codex" '
        .config
        | {
            repo_cwd: (.repo_cwd // $repo),
            codex_dir: (.codex_dir // $codex),
            scanner_token_budget: (.scanner_token_budget // 120000),
            chunk_lines: (.chunk_lines // 1400),
            scanner_model: (.scanner_model // "gpt-5-codex"),
            reducer_model: (.reducer_model // "gpt-5-codex"),
            recency_half_life_days: (.recency_half_life_days // 30)
          }
      ' "$STATE" > "$CONFIG_LOCAL"
    else
      cat > "$CONFIG_LOCAL" <<EOF
{
  "repo_cwd": "$REPO_ROOT",
  "codex_dir": "$HOME/.codex",
  "scanner_token_budget": 120000,
  "chunk_lines": 1400,
  "scanner_model": "gpt-5-codex",
  "reducer_model": "gpt-5-codex",
  "recency_half_life_days": 30
}
EOF
    fi
  fi
  touch "$LEDGER" "$SUPPRESSIONS"
}

init_runtime

config_value() {
  local key="$1" fallback="$2"
  jq -r --arg key "$key" --arg fallback "$fallback" '
    .[$key] // $fallback
  ' "$CONFIG_LOCAL"
}

REPO_CWD="$(config_value repo_cwd "$REPO_ROOT")"
CODEX_DIR="$(config_value codex_dir "$HOME/.codex")"
TOKEN_BUDGET="$(config_value scanner_token_budget 120000)"
CHUNK_LINES="$(config_value chunk_lines 1400)"
SCANNER_MODEL="$(config_value scanner_model gpt-5-codex)"
REDUCER_MODEL="$(config_value reducer_model gpt-5-codex)"
PY=(uv run python)

# --- helpers ----------------------------------------------------------------

# List rollout .jsonl files whose session_meta.cwd is exactly the repo cwd.
discover_sessions() {
  local dirs=()
  [ -d "$CODEX_DIR/archived_sessions" ] && dirs+=("$CODEX_DIR/archived_sessions")
  [ -d "$CODEX_DIR/sessions" ] && dirs+=("$CODEX_DIR/sessions")
  [ ${#dirs[@]} -eq 0 ] && return 0
  # Fast prefilter with a fixed-string match, then verify the first line is a
  # session_meta whose cwd matches (authoritative, excludes incidental mentions).
  rg -lF "\"cwd\":\"$REPO_CWD\"" "${dirs[@]}" 2>/dev/null | while read -r f; do
    local cwd
    cwd="$(head -1 "$f" 2>/dev/null | jq -r 'select(.type=="session_meta") | .payload.cwd' 2>/dev/null || true)"
    [ "$cwd" = "$REPO_CWD" ] && echo "$f"
  done
}

session_id_from_path() {
  local src="$1"
  head -1 "$src" 2>/dev/null | jq -r '.payload.id // empty' 2>/dev/null || true
}

processed_session_ids() {
  jq -r '
    (.processed_session_ids // [])[]?,
    ((.processed_sessions // [])[]? | try capture("(?<id>[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})").id catch empty)
  ' "$STATE" 2>/dev/null | sort -u
}

file_mtime() {
  local f="$1"
  stat -c '%Y' "$f" 2>/dev/null || stat -f '%m' "$f"
}

manifest_review_dir() {
  local run_dir="$1" review_dir
  review_dir="$(jq -r '.review_dir // empty' "$run_dir/manifest.json" 2>/dev/null || true)"
  [ -n "$review_dir" ] || review_dir="$run_dir"
  case "$review_dir" in
    /*) echo "$review_dir" ;;
    *) echo "$REPO_ROOT/$review_dir" ;;
  esac
}

# Extract one rollout to the cache (idempotent unless $1 forces). Echoes cache path.
extract_one() {
  local src="$1" force="${2:-}"
  local base sid date out
  base="$(basename "$src" .jsonl)"
  out="$CACHE/$base.txt"
  if [ -f "$out" ] && [ -z "$force" ]; then echo "$out"; return 0; fi
  sid="$(session_id_from_path "$src")"
  [ -n "$sid" ] || sid="unknown"
  date="$(head -1 "$src" | jq -r '(.payload.timestamp // .timestamp // "")[0:10]' 2>/dev/null || echo "")"
  {
    echo "=== session_id: $sid ==="
    echo "=== session_date: $date ==="
    echo "=== source: $src ==="
    echo
    jq -r -f "$EXTRACT_JQ" "$src" 2>/dev/null | awk -F'\t' '{printf "[%s] %s\n", toupper($1), $2}'
  } > "$out"
  echo "$out"
}

# --- commands ---------------------------------------------------------------

cmd_prepare() {
  local limit="" full="" recent=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --limit) limit="$2"; shift 2 ;;
      --full) full="1"; shift ;;
      --recent) recent="1"; shift ;;
      *) echo "unknown arg: $1" >&2; exit 1 ;;
    esac
  done

  mkdir -p "$CACHE"
  local all processed pending
  all="$(discover_sessions || true)"
  [ -z "$all" ] && { echo "No sessions for $REPO_ROOT found under $CODEX_DIR" >&2; exit 1; }

  if [ -n "$full" ]; then
    pending="$all"
  else
    processed="$(processed_session_ids)"
    pending="$(
      while read -r f; do
        [ -z "$f" ] && continue
        local sid
        sid="$(session_id_from_path "$f")"
        if [ -z "$sid" ] || ! grep -qxF "$sid" <<< "$processed"; then
          echo "$f"
        fi
      done <<< "$all"
    )"
  fi
  [ -z "${pending// }" ] && { echo "Nothing to process — all discovered sessions already done. Use --full to rebuild." ; exit 0; }

  # Order: most recent first (by mtime) when --recent, else stable.
  if [ -n "$recent" ]; then
    pending="$(echo "$pending" | while read -r f; do [ -n "$f" ] && echo "$(file_mtime "$f") $f"; done | sort -rn | awk '{print $2}')"
  fi
  if [ -n "$limit" ]; then
    pending="$(echo "$pending" | head -n "$limit")"
  fi

  local run_id run_dir review_dir review_dir_manifest
  run_id="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
  run_dir="$DREAM_DIR/runs/$run_id"
  review_dir="$REVIEW_ROOT/$run_id"
  review_dir_manifest=".agents/dreams/proposals/$run_id"
  mkdir -p "$run_dir" "$review_dir"

  # Extract + greedily pack into shards by token budget (~ bytes/4).
  local shard=1 shard_bytes=0 budget_bytes=$(( TOKEN_BUDGET * 4 ))
  : > "$run_dir/shard-$(printf '%02d' $shard).files"
  local n_sessions=0
  while read -r src; do
    [ -z "$src" ] && continue
    n_sessions=$((n_sessions+1))
    local cache_path
    cache_path="$(extract_one "$src" "$full")"
    # Chunk oversized sessions so every file fits one Read; a session's chunks
    # pack contiguously (a monster session may span consecutive shards).
    while read -r part; do
      [ -z "$part" ] && continue
      local bytes
      bytes="$(wc -c < "$part" | tr -d ' ')"
      # Roll to a new shard if this file would blow the budget and shard non-empty.
      if [ "$shard_bytes" -gt 0 ] && [ $(( shard_bytes + bytes )) -gt "$budget_bytes" ]; then
        shard=$((shard+1)); shard_bytes=0
        : > "$run_dir/shard-$(printf '%02d' $shard).files"
      fi
      echo "${part#$REPO_ROOT/}" >> "$run_dir/shard-$(printf '%02d' $shard).files"
      shard_bytes=$(( shard_bytes + bytes ))
    done < <("${PY[@]}" "$SKILL_DIR/scripts/chunk.py" "$cache_path" "$CHUNK_LINES")
  done <<< "$pending"

  # Manifest.
  local n_shards
  n_shards="$(ls "$run_dir"/shard-*.files 2>/dev/null | wc -l | tr -d ' ')"
  {
    echo "{"
    echo "  \"run_id\": \"$run_id\","
    echo "  \"created\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    echo "  \"n_sessions\": $n_sessions,"
    echo "  \"n_shards\": $n_shards,"
    echo "  \"scanner_model\": $(jq -Rn --arg v "$SCANNER_MODEL" '$v'),"
    echo "  \"reducer_model\": $(jq -Rn --arg v "$REDUCER_MODEL" '$v'),"
    echo "  \"token_budget\": $TOKEN_BUDGET,"
    echo "  \"review_dir\": \"$review_dir_manifest\","
    echo "  \"session_ids\": $(echo "$pending" | while read -r src; do [ -n "$src" ] && session_id_from_path "$src"; done | jq -R 'select(length > 0)' | jq -s .),"
    echo "  \"source_basenames\": $(echo "$pending" | while read -r src; do [ -n "$src" ] && basename "$src"; done | jq -R 'select(length > 0)' | jq -s .)"
    echo "}"
  } > "$run_dir/manifest.json"

  echo "RUN_DIR=$run_dir"
  echo "REVIEW_DIR=$review_dir"
  echo "Prepared $n_sessions sessions into $n_shards shard(s)."
  echo "Shards:"
  for sf in "$run_dir"/shard-*.files; do
    echo "  $(basename "$sf"): $(wc -l < "$sf" | tr -d ' ') file(s)"
  done
}

cmd_collect() {
  local run_dir="${1:?usage: dream.sh collect <run_dir>}"
  [ -d "$run_dir" ] || { echo "no such run dir: $run_dir" >&2; exit 1; }
  local run_id; run_id="$(jq -r '.run_id' "$run_dir/manifest.json")"

  # Merge all shard findings into findings.json (skip missing/empty gracefully).
  local merged="$run_dir/findings.json"
  jq -s 'add // []' "$run_dir"/findings-shard-*.json 2>/dev/null > "$merged" || echo "[]" > "$merged"
  local n; n="$(jq 'length' "$merged")"
  echo "Merged $n findings -> $merged"

  # Append to ledger with stable ids, lifecycle status, and recurrence keys.
  jq -c --arg run "$run_id" '
    def norm_text:
      ascii_downcase | gsub("[^a-z0-9]";"");
    .[] |
      (((.domain // "?") + "|" + (.type // "?") + "|" + (.target // "?") + "|"
        + ((.evidence // "") | norm_text | .[0:80]))) as $fingerprint |
      (((.evidence // "") | norm_text | .[0:120])) as $evidence_key |
      . + {
        run_id: $run,
        status: "open",
        fingerprint: $fingerprint,
        evidence_key: $evidence_key,
        finding_id: (((.session_id // "unknown") | tostring) + ":" + $fingerprint)
      }
  ' "$merged" >> "$LEDGER"
  echo "Appended $n findings to ledger ($(wc -l < "$LEDGER" | tr -d ' ') total)."

  # Mark this run's sessions as processed.
  local tmp; tmp="$(mktemp)"
  jq --slurpfile m <(jq '{s: ((.session_ids // []) + ((.sessions // []) | map(try capture("(?<id>[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})").id catch empty))) }' "$run_dir/manifest.json") \
     '.processed_session_ids = (((.processed_session_ids // []) + $m[0].s) | unique) | del(.processed_sessions) | del(.config)' "$STATE" > "$tmp"
  mv "$tmp" "$STATE"
  echo "Marked $(jq '((.session_ids // []) + (.sessions // [])) | length' "$run_dir/manifest.json") sessions processed."
}

cmd_mark_proposed() {
  local run_dir="${1:?usage: dream.sh mark-proposed <run_dir>}"
  [ -d "$run_dir" ] || { echo "no such run dir: $run_dir" >&2; exit 1; }
  local review_dir proposed
  review_dir="$(manifest_review_dir "$run_dir")"
  proposed="$review_dir/proposed-changes.json"
  [ -f "$proposed" ] || { echo "no proposed-changes.json at $proposed" >&2; exit 1; }

  local ledger_tmp; ledger_tmp="$(mktemp)"
  jq -c --slurpfile proposed "$proposed" '
    def row_ids:
      [
        (.finding_id // empty),
        (.fingerprint // empty),
        (((.session_id // "unknown") | tostring) + ":" + (.fingerprint // ""))
      ];
    ($proposed[0] // [] | [.[].finding_ids[]?]) as $proposed_ids |
    . as $row |
    ($row | row_ids) as $row_ids |
    if (.status == "open") and (any($row_ids[]; . as $id | $proposed_ids | index($id))) then
      .status = "proposed"
    else
      .
    end
  ' "$LEDGER" > "$ledger_tmp"
  mv "$ledger_tmp" "$LEDGER"
  echo "Marked proposed ledger rows from $proposed."
}

cmd_finalize() {
  local run_dir="${1:?usage: dream.sh finalize <run_dir>}"
  local review_dir decisions
  review_dir="$(manifest_review_dir "$run_dir")"
  decisions="$review_dir/decisions.json"
  if [ -f "$decisions" ]; then
    # decisions.json: [{id, finding_ids:[...], decision:"applied|dismissed|deferred", fingerprint, reason}]
    # Record dismissed fingerprints as suppressions so they never resurface.
    jq -c '.[] | select(.decision=="dismissed") | {fingerprint, reason, ts: now|todate}' \
      "$decisions" >> "$SUPPRESSIONS" 2>/dev/null || true
    echo "Recorded dismissed patterns to suppressions."

    # Apply human decisions to matching ledger rows. Match by stable finding_id,
    # with legacy fingerprint support for older decisions.
    local ledger_tmp; ledger_tmp="$(mktemp)"
    jq -c --slurpfile decisions "$decisions" '
      def norm_status($s):
        if $s == "applied" then "applied"
        elif $s == "dismissed" then "dismissed"
        elif $s == "deferred" then "deferred"
        elif $s == "proposed" then "proposed"
        elif $s == "open" then "open"
        elif $s == "closed" then "dismissed"
        else "open" end;
      def row_ids:
        [
          (.finding_id // empty),
          (.fingerprint // empty),
          (((.session_id // "unknown") | tostring) + ":" + (.fingerprint // ""))
        ];
      def decision_rows:
        ($decisions[0] // [])[] as $d
        | (($d.decision // "deferred") | norm_status(.)) as $status
        | ($d.finding_ids // [])[]? as $fid
        | {finding_id: $fid, status: $status};

      . as $row |
      ($row | row_ids) as $row_ids |
      (([decision_rows | .finding_id as $fid | select($row_ids | index($fid))] | first) // null) as $match |
      .status = (if $match then $match.status else norm_status(.status // "open") end)
    ' "$LEDGER" > "$ledger_tmp"
    mv "$ledger_tmp" "$LEDGER"
    echo "Updated ledger statuses from decisions."
  else
    # Even without decisions, normalize legacy statuses to the strict enum.
    local ledger_tmp; ledger_tmp="$(mktemp)"
    jq -c '
      def norm_status($s):
        if $s == "applied" then "applied"
        elif $s == "dismissed" then "dismissed"
        elif $s == "deferred" then "deferred"
        elif $s == "proposed" then "proposed"
        elif $s == "open" then "open"
        elif $s == "closed" then "dismissed"
        else "open" end;
      .status = norm_status(.status // "open")
    ' "$LEDGER" > "$ledger_tmp"
    mv "$ledger_tmp" "$LEDGER"
    echo "Normalized ledger statuses."
  fi
  local tmp; tmp="$(mktemp)"
  jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.last_run = $ts' "$STATE" > "$tmp"
  mv "$tmp" "$STATE"
  echo "Stamped last_run = $(jq -r .last_run "$STATE")."
}

cmd_status() {
  local all processed pending open proposed applied dismissed deferred
  all="$(discover_sessions || true)"
  processed="$(processed_session_ids)"
  pending="$(
    while read -r f; do
      [ -z "$f" ] && continue
      local sid
      sid="$(session_id_from_path "$f")"
      if [ -z "$sid" ] || ! grep -qxF "$sid" <<< "$processed"; then
        echo "$f"
      fi
    done <<< "$all"
  )"
  open="$( [ -f "$LEDGER" ] && jq -s '[.[] | select(.status=="open")] | length' "$LEDGER" 2>/dev/null || echo 0)"
  proposed="$( [ -f "$LEDGER" ] && jq -s '[.[] | select(.status=="proposed")] | length' "$LEDGER" 2>/dev/null || echo 0)"
  applied="$( [ -f "$LEDGER" ] && jq -s '[.[] | select(.status=="applied")] | length' "$LEDGER" 2>/dev/null || echo 0)"
  dismissed="$( [ -f "$LEDGER" ] && jq -s '[.[] | select(.status=="dismissed")] | length' "$LEDGER" 2>/dev/null || echo 0)"
  deferred="$( [ -f "$LEDGER" ] && jq -s '[.[] | select(.status=="deferred")] | length' "$LEDGER" 2>/dev/null || echo 0)"
  local invalid
  invalid="$( [ -f "$LEDGER" ] && jq -s '[.[] | select((.status as $s | ["open","proposed","applied","dismissed","deferred"] | index($s)) | not)] | length' "$LEDGER" 2>/dev/null || echo 0)"
  echo "last_run:           $(jq -r '.last_run // "never"' "$STATE")"
  echo "discovered:         $(echo "$all" | grep -c . || true)"
  echo "processed:          $(echo "$processed" | grep -c . || true)"
  echo "pending:            $(echo "$pending" | grep -c . || true)"
  echo "open ledger items:  $open"
  echo "proposed:           $proposed"
  echo "applied:            $applied"
  echo "dismissed:          $dismissed"
  echo "deferred:           $deferred"
  echo "invalid statuses:   $invalid"
  echo "suppressions:       $( [ -f "$SUPPRESSIONS" ] && wc -l < "$SUPPRESSIONS" | tr -d ' ' || echo 0)"
}

case "${1:-}" in
  prepare)       shift; cmd_prepare "$@" ;;
  collect)       shift; cmd_collect "$@" ;;
  mark-proposed) shift; cmd_mark_proposed "$@" ;;
  finalize)      shift; cmd_finalize "$@" ;;
  status)        shift; cmd_status "$@" ;;
  *) echo "usage: dream.sh {prepare|collect|mark-proposed|finalize|status}" >&2; exit 1 ;;
esac
