#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import re
from collections import Counter, deque
from datetime import UTC, datetime
from pathlib import Path
from urllib.parse import quote

FIELDS = ("cwd", "rel", "user", "assistant")
PATH_FIELDS = ("cwd", "rel")


def clip(text: str, limit: int = 140) -> str:
    text = " ".join(text.split())
    if len(text) <= limit:
        return text
    return text[: limit - 1] + "..."


def extract_text(value) -> str:
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        return " ".join(part for item in value if (part := extract_text(item)))
    if isinstance(value, dict):
        parts = []
        if "text" in value and isinstance(value["text"], str):
            parts.append(value["text"])
        if "content" in value:
            parts.append(extract_text(value["content"]))
        if "parts" in value:
            parts.append(extract_text(value["parts"]))
        return " ".join(part for part in parts if part)
    return ""


def normalize_text(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", text.lower()).strip()


def tokenize(text: str) -> list[str]:
    return [token for token in normalize_text(text).split() if token]


def normalize_segment(segment: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", segment.lower()).strip()


def split_segments(path_text: str) -> list[dict[str, object]]:
    segments = []
    for raw in path_text.split("/"):
        raw = raw.strip()
        if not raw:
            continue
        text = normalize_segment(raw)
        segments.append(
            {
                "raw": raw,
                "text": text,
                "tokens": tokenize(raw),
            }
        )
    return segments


def suffix_display(path_text: str, count: int = 3) -> str:
    parts = [part for part in path_text.split("/") if part]
    if not parts:
        return "-"
    if len(parts) <= count:
        return "/".join(parts)
    return ".../" + "/".join(parts[-count:])


def format_label(rec: dict[str, object]) -> str:
    search = rec["search"]
    focus = search["cwd_last_raw"] or search["rel_last_raw"] or "-"
    cwd_suffix = suffix_display(str(rec["cwd"] or ""))
    rel_suffix = suffix_display(str(rec["rel"] or ""), count=4)
    recent_user = clip(" | ".join(rec["users"]), 140) if rec["users"] else "No recent user message."
    return "  ".join(
        part
        for part in (
            focus,
            fmt_when(str(rec["started"]), int(rec["mtime"])),
            cwd_suffix,
            rel_suffix,
            recent_user,
        )
        if part
    )


def parse_session(path: Path) -> dict[str, object]:
    cwd = ""
    started = ""
    users: deque[str] = deque(maxlen=3)
    assistants: deque[str] = deque(maxlen=2)

    try:
        handle = path.open()
    except OSError:
        return {}

    with handle:
        for line in handle:
            try:
                obj = json.loads(line)
            except Exception:
                continue

            payload = obj.get("payload") or {}
            event_type = obj.get("type")

            if event_type == "session_meta":
                cwd = payload.get("cwd") or cwd
                started = payload.get("timestamp") or started
                continue

            if event_type != "response_item":
                continue

            if payload.get("type") != "message":
                continue

            role = payload.get("role")
            text = clip(extract_text(payload.get("content", [])), 240)
            if not text:
                continue

            if role == "user":
                users.append(text)
            elif role == "assistant":
                assistants.append(text)

    stat = path.stat()
    return {
        "path": str(path),
        "cwd": cwd,
        "started": started,
        "mtime": int(stat.st_mtime),
        "size": stat.st_size,
        "users": list(users),
        "assistants": list(assistants),
    }


def build_search_fields(rec: dict[str, object]) -> dict[str, object]:
    cwd = str(rec.get("cwd") or "")
    rel = str(rec.get("rel") or "")
    user_text = " ".join(rec.get("users") or [])
    assistant_text = " ".join(rec.get("assistants") or [])

    cwd_segments = split_segments(cwd)
    rel_segments = split_segments(rel)
    cwd_last = cwd_segments[-1] if cwd_segments else {"raw": "", "text": "", "tokens": []}
    rel_last = rel_segments[-1] if rel_segments else {"raw": "", "text": "", "tokens": []}

    search = {
        "cwd_text": normalize_text(cwd),
        "rel_text": normalize_text(rel),
        "user_text": normalize_text(user_text),
        "assistant_text": normalize_text(assistant_text),
        "cwd_tokens": tokenize(cwd),
        "rel_tokens": tokenize(rel),
        "user_tokens": tokenize(user_text),
        "assistant_tokens": tokenize(assistant_text),
        "cwd_segments": cwd_segments,
        "rel_segments": rel_segments,
        "cwd_last_text": cwd_last["text"],
        "cwd_last_raw": cwd_last["raw"],
        "rel_last_text": rel_last["text"],
        "rel_last_raw": rel_last["raw"],
        "cwd_suffix_text": " / ".join(segment["text"] for segment in cwd_segments[-3:]),
        "rel_suffix_text": " / ".join(segment["text"] for segment in rel_segments[-4:]),
    }
    search["all_tokens"] = sorted(
        {
            *search["cwd_tokens"],
            *search["rel_tokens"],
            *search["user_tokens"],
            *search["assistant_tokens"],
        }
    )
    return search


def walk_sessions(root: Path) -> list[dict[str, object]]:
    records = []
    for path in sorted(root.rglob("*.jsonl")):
        rec = parse_session(path)
        if not rec:
            continue
        rec["rel"] = str(path.relative_to(root))
        rec["search"] = build_search_fields(rec)
        rec["label"] = format_label(rec)
        records.append(rec)
    records.sort(key=lambda item: (item.get("started") or "", item["path"]), reverse=True)
    return records


def build_stats(records: list[dict[str, object]]) -> dict[str, object]:
    field_dfs = {field: Counter() for field in FIELDS}
    avg_lengths = {field: 1.0 for field in FIELDS}

    if not records:
        return {
            "doc_count": 0,
            "field_dfs": {field: {} for field in FIELDS},
            "avg_lengths": avg_lengths,
        }

    for field in FIELDS:
        lengths = []
        for rec in records:
            tokens = rec["search"][f"{field}_tokens"]
            lengths.append(max(1, len(tokens)))
            for token in set(tokens):
                field_dfs[field][token] += 1
        avg_lengths[field] = sum(lengths) / len(lengths)

    return {
        "doc_count": len(records),
        "field_dfs": {field: dict(counter) for field, counter in field_dfs.items()},
        "avg_lengths": avg_lengths,
    }


def load_cache(cache_file: Path) -> dict[str, object]:
    with cache_file.open() as handle:
        return json.load(handle)


def save_cache(cache_file: Path, payload: dict[str, object]) -> None:
    cache_file.parent.mkdir(parents=True, exist_ok=True)
    with cache_file.open("w") as handle:
        json.dump(payload, handle)


def fmt_when(started: str, fallback_mtime: int) -> str:
    if started:
        try:
            dt = datetime.fromisoformat(started.replace("Z", "+00:00"))
            return dt.astimezone().strftime("%Y-%m-%d %H:%M")
        except Exception:
            return started
    return datetime.fromtimestamp(fallback_mtime).strftime("%Y-%m-%d %H:%M")


def fuzzy_subsequence_ratio(token: str, text: str) -> float:
    if not token or not text:
        return 0.0

    index = 0
    for char in text:
        if char == token[index]:
            index += 1
            if index == len(token):
                return len(token) / max(len(text), len(token))
    return 0.0


def inverse_doc_freq(token: str, field: str, stats: dict[str, object]) -> float:
    doc_count = max(1, int(stats["doc_count"]))
    df = int(stats["field_dfs"][field].get(token, 0))
    return max(0.35, math.log(1.0 + ((doc_count - df + 0.5) / (df + 0.5))))


def bm25_score(token: str, field: str, search: dict[str, object], stats: dict[str, object], field_weight: float) -> float:
    tokens = search[f"{field}_tokens"]
    if not tokens:
        return 0.0

    tf = tokens.count(token)
    if tf <= 0:
        return 0.0

    field_len = max(1, len(tokens))
    avg_len = max(1.0, float(stats["avg_lengths"][field]))
    k1 = 1.35
    b = 0.75
    norm = tf + k1 * (1 - b + b * (field_len / avg_len))
    return field_weight * inverse_doc_freq(token, field, stats) * ((tf * (k1 + 1)) / norm)


def field_token_match_bonus(token: str, field: str, search: dict[str, object], stats: dict[str, object]) -> float:
    tokens = search[f"{field}_tokens"]
    if not tokens:
        return 0.0

    rarity = inverse_doc_freq(token, field, stats)
    best = 0.0
    for candidate in set(tokens):
        if token == candidate:
            best = max(best, 28.0)
        elif candidate.startswith(token):
            best = max(best, 20.0 * (0.7 + 0.3 * len(token) / max(len(candidate), 1)))
        elif token in candidate:
            best = max(best, 13.0 * (0.6 + 0.4 * len(token) / max(len(candidate), 1)))
        else:
            fuzzy = fuzzy_subsequence_ratio(token, candidate)
            if fuzzy >= 0.7:
                best = max(best, 4.5 * fuzzy)
    return best * rarity


def path_segment_bonus(token: str, segments: list[dict[str, object]], stats: dict[str, object], field: str, family_weight: float) -> float:
    if not segments:
        return 0.0

    rarity = inverse_doc_freq(token, field, stats)
    best = 0.0
    for rank, segment in enumerate(reversed(segments), start=1):
        position_weight = 1.0 / (rank ** 1.45)
        segment_text = str(segment["text"])
        segment_tokens = segment["tokens"]
        candidate = 0.0

        if token == segment_text:
            candidate = max(candidate, 260.0 * position_weight)
        elif segment_text.startswith(token):
            candidate = max(
                candidate,
                205.0 * position_weight * (0.65 + 0.35 * len(token) / max(len(segment_text), 1)),
            )
        elif token in segment_text:
            candidate = max(
                candidate,
                145.0 * position_weight * (0.55 + 0.45 * len(token) / max(len(segment_text), 1)),
            )
        else:
            fuzzy = fuzzy_subsequence_ratio(token, segment_text.replace(" ", ""))
            if fuzzy >= 0.72:
                candidate = max(candidate, 24.0 * position_weight * fuzzy)

        for part in set(segment_tokens):
            if token == part:
                candidate = max(candidate, 230.0 * position_weight)
            elif part.startswith(token):
                candidate = max(
                    candidate,
                    185.0 * position_weight * (0.7 + 0.3 * len(token) / max(len(part), 1)),
                )
            elif token in part:
                candidate = max(
                    candidate,
                    138.0 * position_weight * (0.55 + 0.45 * len(token) / max(len(part), 1)),
                )
            else:
                fuzzy = fuzzy_subsequence_ratio(token, part)
                if fuzzy >= 0.75:
                    candidate = max(candidate, 26.0 * position_weight * fuzzy)

        best = max(best, candidate)

    return best * rarity * family_weight


def phrase_bonus(query_text: str, query_tokens: list[str], search: dict[str, object], stats: dict[str, object]) -> float:
    if not query_text:
        return 0.0

    phrase_tokens = [token for token in query_tokens if token]
    rarity = sum(inverse_doc_freq(token, "cwd", stats) for token in phrase_tokens) / max(1, len(phrase_tokens))
    bonus = 0.0

    cwd_last = search["cwd_last_text"]
    rel_last = search["rel_last_text"]
    cwd_suffix = search["cwd_suffix_text"]
    rel_suffix = search["rel_suffix_text"]

    if cwd_last:
        if query_text == cwd_last:
            bonus += 420.0
        elif cwd_last.startswith(query_text):
            bonus += 315.0 * (0.7 + 0.3 * len(query_text) / max(len(cwd_last), 1))
        elif query_text in cwd_last:
            bonus += 225.0 * (0.6 + 0.4 * len(query_text) / max(len(cwd_last), 1))

    if cwd_suffix and query_text in cwd_suffix:
        bonus += 170.0 * (0.6 + 0.4 * len(query_text) / max(len(cwd_suffix), 1))

    if rel_last:
        if query_text == rel_last:
            bonus += 180.0
        elif rel_last.startswith(query_text):
            bonus += 140.0 * (0.7 + 0.3 * len(query_text) / max(len(rel_last), 1))
        elif query_text in rel_last:
            bonus += 100.0 * (0.6 + 0.4 * len(query_text) / max(len(rel_last), 1))

    if rel_suffix and query_text in rel_suffix:
        bonus += 76.0

    if query_text and query_text in search["user_text"]:
        bonus += 18.0
    if query_text and query_text in search["assistant_text"]:
        bonus += 8.0

    return bonus * max(1.0, rarity)


def score_item(rec: dict[str, object], query: str, stats: dict[str, object]) -> float | None:
    query_tokens = tokenize(query)
    if not query_tokens:
        return float(rec["mtime"])

    query_text = normalize_text(query)
    search = rec["search"]
    total = 0.0
    matched_tokens = 0

    for token in query_tokens:
        token_score = 0.0
        token_score += path_segment_bonus(token, search["cwd_segments"], stats, "cwd", 1.35)
        token_score += path_segment_bonus(token, search["rel_segments"], stats, "rel", 0.8)
        token_score += field_token_match_bonus(token, "cwd", search, stats) * 1.8
        token_score += field_token_match_bonus(token, "rel", search, stats) * 1.0
        token_score += field_token_match_bonus(token, "user", search, stats) * 0.45
        token_score += field_token_match_bonus(token, "assistant", search, stats) * 0.22
        token_score += bm25_score(token, "cwd", search, stats, 44.0)
        token_score += bm25_score(token, "rel", search, stats, 24.0)
        token_score += bm25_score(token, "user", search, stats, 7.0)
        token_score += bm25_score(token, "assistant", search, stats, 3.0)

        if token_score <= 0.0:
            return None

        matched_tokens += 1
        total += token_score

    total += phrase_bonus(query_text, query_tokens, search, stats)
    if matched_tokens == len(query_tokens):
        total += 18.0 * matched_tokens

    # Small recency bias for ties and near-ties.
    total += min(12.0, max(0.0, (float(rec["mtime"]) - 1_700_000_000) / 10_000_000))
    return total


def iter_ranked(cache: dict[str, object], query: str) -> list[tuple[float, dict[str, object]]]:
    stats = cache["stats"]
    ranked = []
    for rec in cache["items"]:
        score = score_item(rec, query, stats)
        if score is None:
            continue
        ranked.append((score, rec))
    ranked.sort(key=lambda entry: (-entry[0], -int(entry[1]["mtime"]), str(entry[1]["path"])))
    return ranked


def command_refresh(root: Path, cache_file: Path) -> int:
    records = walk_sessions(root)
    payload = {
        "root": str(root),
        "generated_at": datetime.now(UTC).isoformat(timespec="seconds").replace("+00:00", "Z"),
        "items": records,
        "stats": build_stats(records),
    }
    save_cache(cache_file, payload)
    print(f"Indexed {len(records)} sessions into {cache_file}")
    return 0


def command_query(cache_file: Path, viewer_root: str, raw_root: str, query: str) -> int:
    cache = load_cache(cache_file)
    for score, rec in iter_ranked(cache, query):
        rel = str(rec["rel"])
        raw_url = raw_root.rstrip("/") + "/files/" + "/".join(quote(part) for part in rel.split("/"))
        viewer_url = viewer_root.rstrip("/") + "/?path=" + quote(raw_url, safe="")
        print("\t".join([str(rec["label"]), viewer_url, raw_url, str(rec["path"])]))
    return 0


def command_preview(cache_file: Path, file_path: Path) -> int:
    try:
        cache = load_cache(cache_file)
    except FileNotFoundError:
        cache = {"items": []}

    file_str = str(file_path)
    rec = next((item for item in cache["items"] if item["path"] == file_str), None)
    if rec is None:
        rec = parse_session(file_path)
        if not rec:
            print("Could not read session.")
            return 1
        rec["rel"] = str(file_path)
        rec["search"] = build_search_fields(rec)

    print(f"File: {rec['path']}")
    print(f"Started: {fmt_when(str(rec['started']), int(rec['mtime']))}")
    print(f"CWD: {rec['cwd'] or '-'}")
    print(f"Size: {rec['size']} bytes")
    print()
    print("Recent user messages:")
    if rec["users"]:
        for item in rec["users"]:
            print(f"  - {item}")
    else:
        print("  - none")
    print()
    print("Recent assistant messages:")
    if rec["assistants"]:
        for item in rec["assistants"]:
            print(f"  - {item}")
    else:
        print("  - none")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)

    refresh = sub.add_parser("refresh")
    refresh.add_argument("--root", required=True)
    refresh.add_argument("--cache-file", required=True)

    query = sub.add_parser("query")
    query.add_argument("--cache-file", required=True)
    query.add_argument("--viewer-root", required=True)
    query.add_argument("--raw-root", required=True)
    query.add_argument("--query", required=True)

    preview = sub.add_parser("preview")
    preview.add_argument("--cache-file", required=True)
    preview.add_argument("--file", required=True)

    args = parser.parse_args()
    if args.cmd == "refresh":
        return command_refresh(Path(args.root).expanduser(), Path(args.cache_file).expanduser())
    if args.cmd == "query":
        return command_query(
            Path(args.cache_file).expanduser(),
            args.viewer_root,
            args.raw_root,
            args.query,
        )
    return command_preview(
        Path(args.cache_file).expanduser(),
        Path(args.file).expanduser(),
    )


if __name__ == "__main__":
    raise SystemExit(main())
