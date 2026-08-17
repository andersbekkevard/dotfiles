#!/usr/bin/env python3
"""Read-only, machine-wide storage census for the reclaim-storage skill."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import stat
import subprocess
import sys
import tomllib
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

from codex_sessions import MIN_RETENTION_DAYS, SessionError, audit_sessions


class AuditError(RuntimeError):
    pass


@dataclass(frozen=True)
class Usage:
    allocated_bytes: int
    apparent_bytes: int
    files: int
    directories: int
    errors: tuple[str, ...]


def expand_path(value: str) -> Path:
    return Path(os.path.expandvars(os.path.expanduser(value))).resolve()


def is_within(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
    except ValueError:
        return False
    return True


def allocated(stat_result: os.stat_result) -> int:
    blocks = getattr(stat_result, "st_blocks", None)
    if blocks is None:
        return stat_result.st_size
    return blocks * 512


def measure_path(path: Path) -> Usage:
    """Measure one path without following symlinks or crossing mount devices."""
    try:
        root_stat = path.lstat()
    except FileNotFoundError:
        return Usage(0, 0, 0, 0, ())
    except OSError as exc:
        return Usage(0, 0, 0, 0, (f"{path}: {exc}",))
    if stat.S_ISLNK(root_stat.st_mode):
        return Usage(allocated(root_stat), root_stat.st_size, 1, 0, ())
    if not stat.S_ISDIR(root_stat.st_mode):
        return Usage(allocated(root_stat), root_stat.st_size, 1, 0, ())

    device = root_stat.st_dev
    total_allocated = allocated(root_stat)
    total_apparent = root_stat.st_size
    file_count = 0
    directory_count = 1
    errors: list[str] = []
    seen_inodes: set[tuple[int, int]] = {(root_stat.st_dev, root_stat.st_ino)}

    def onerror(exc: OSError) -> None:
        errors.append(str(exc))

    for current, directories, files in os.walk(
        path, topdown=True, followlinks=False, onerror=onerror
    ):
        current_path = Path(current)
        kept: list[str] = []
        for name in directories:
            child = current_path / name
            try:
                child_stat = child.lstat()
            except OSError as exc:
                errors.append(f"{child}: {exc}")
                continue
            if stat.S_ISLNK(child_stat.st_mode):
                key = (child_stat.st_dev, child_stat.st_ino)
                if key not in seen_inodes:
                    seen_inodes.add(key)
                    total_allocated += allocated(child_stat)
                    total_apparent += child_stat.st_size
                    file_count += 1
                continue
            if child_stat.st_dev != device:
                errors.append(f"mount_boundary:{child}")
                continue
            key = (child_stat.st_dev, child_stat.st_ino)
            if key not in seen_inodes:
                seen_inodes.add(key)
                total_allocated += allocated(child_stat)
                total_apparent += child_stat.st_size
                directory_count += 1
            kept.append(name)
        directories[:] = kept

        for name in files:
            child = current_path / name
            try:
                child_stat = child.lstat()
            except OSError as exc:
                errors.append(f"{child}: {exc}")
                continue
            key = (child_stat.st_dev, child_stat.st_ino)
            if key in seen_inodes:
                continue
            seen_inodes.add(key)
            total_allocated += allocated(child_stat)
            total_apparent += child_stat.st_size
            file_count += 1
    return Usage(total_allocated, total_apparent, file_count, directory_count, tuple(errors))


def load_config(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise AuditError(
            f"machine config does not exist: {path}; copy machine.example.toml "
            "to the ignored machine.local.toml and inspect its paths"
        )
    try:
        with path.open("rb") as handle:
            config = tomllib.load(handle)
    except (OSError, tomllib.TOMLDecodeError) as exc:
        raise AuditError(f"cannot read config {path}: {exc}") from exc
    if config.get("version") != 1:
        raise AuditError(f"unsupported config version in {path}: {config.get('version')!r}")
    return config


def filesystem_capacity(
    paths: Iterable[Path], *, min_total_bytes: int = 16 * 1024 * 1024
) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    seen: set[tuple[int, int]] = set()
    for path in paths:
        existing = path if path.exists() else path.parent
        try:
            stats = existing.stat()
            usage = shutil.disk_usage(existing)
        except OSError as exc:
            results.append({"path": str(path), "error": str(exc)})
            continue
        if usage.total < min_total_bytes:
            continue
        key = (stats.st_dev, usage.total)
        if key in seen:
            continue
        seen.add(key)
        results.append(
            {
                "path": str(existing),
                "device": stats.st_dev,
                "total_bytes": usage.total,
                "used_bytes": usage.used,
                "free_bytes": usage.free,
            }
        )
    return results


def mounted_filesystem_roots() -> list[Path]:
    executable = shutil.which("df")
    if executable is None:
        return []
    try:
        completed = subprocess.run(
            [executable, "-P", "-k"],
            check=False,
            capture_output=True,
            text=True,
            timeout=15,
        )
    except (OSError, subprocess.TimeoutExpired):
        return []
    if completed.returncode != 0:
        return []
    roots: list[Path] = []
    for line in completed.stdout.splitlines()[1:]:
        fields = line.split(maxsplit=5)
        if len(fields) == 6 and fields[5].startswith("/"):
            roots.append(Path(fields[5]))
    return roots


def discover_cargo_targets(search_roots: list[Path], exclude_names: set[str]) -> list[Path]:
    targets: set[Path] = set()
    visited_roots: list[Path] = []
    for root in sorted(set(search_roots), key=lambda item: (len(item.parts), str(item))):
        already_covered = any(is_within(root, old) for old in visited_roots)
        if not root.exists() or root.is_symlink() or already_covered:
            continue
        visited_roots.append(root)
        try:
            root_device = root.stat().st_dev
        except OSError:
            continue
        for current, directories, _files in os.walk(root, topdown=True, followlinks=False):
            current_path = Path(current)
            kept: list[str] = []
            for name in directories:
                child = current_path / name
                if name in exclude_names:
                    continue
                try:
                    child_stat = child.lstat()
                except OSError:
                    continue
                if stat.S_ISLNK(child_stat.st_mode) or child_stat.st_dev != root_device:
                    continue
                if name == "target" and is_cargo_target(child):
                    targets.add(child.resolve())
                    continue
                kept.append(name)
            directories[:] = kept
    return sorted(targets)


def is_cargo_target(path: Path) -> bool:
    markers = (
        path / ".rustc_info.json",
        path / "debug" / ".cargo-lock",
        path / "release" / ".cargo-lock",
    )
    if any(marker.exists() for marker in markers):
        return True
    cachedir = path / "CACHEDIR.TAG"
    if cachedir.is_file():
        try:
            return "Signature: 8a477f597d28d172789f06886806bc55" in cachedir.read_text(
                errors="replace"
            )
        except OSError:
            return False
    return False


def linux_process_references() -> list[tuple[int, Path]] | None:
    proc = Path("/proc")
    if not proc.is_dir():
        return None
    references: list[tuple[int, Path]] = []
    for process in proc.iterdir():
        if not process.name.isdigit():
            continue
        pid = int(process.name)
        links = [process / "cwd"]
        fd_root = process / "fd"
        try:
            links.extend(fd_root.iterdir())
        except OSError:
            pass
        for link in links:
            try:
                target = Path(os.readlink(link))
            except OSError:
                continue
            if target.is_absolute():
                references.append((pid, target))
    return references


def lsof_process_references() -> list[tuple[int, Path]] | None:
    executable = shutil.which("lsof")
    if executable is None:
        return None
    try:
        completed = subprocess.run(
            [executable, "-n", "-P", "-Fn"],
            check=False,
            capture_output=True,
            text=True,
            timeout=30,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if completed.returncode not in {0, 1}:
        return None
    references: list[tuple[int, Path]] = []
    pid: int | None = None
    for line in completed.stdout.splitlines():
        if line.startswith("p") and line[1:].isdigit():
            pid = int(line[1:])
        elif pid is not None and line.startswith("n/"):
            references.append((pid, Path(line[1:])))
    return references


def process_references() -> tuple[list[tuple[int, Path]], str | None]:
    linux = linux_process_references()
    if linux is not None:
        return linux, None
    portable = lsof_process_references()
    if portable is not None:
        return portable, None
    return [], "active_process_scan_unavailable"


def active_pids(path: Path, references: list[tuple[int, Path]]) -> list[int]:
    return sorted({pid for pid, target in references if is_within(target, path)})


def candidate(
    *,
    identifier: str,
    path: Path,
    category: str,
    recreation: str,
    source: str,
    usage: Usage,
    references: list[tuple[int, Path]],
    process_scan_error: str | None = None,
    active_pids_override: list[int] | None = None,
    activity_scope: str = "entire_path",
    block_on_activity: bool = True,
    decision_uncertainty: list[str] | None = None,
    reclaimable_bytes: int | None = None,
    action: str = "Remove only after explicit approval",
) -> dict[str, Any]:
    pids = (
        active_pids_override
        if active_pids_override is not None
        else active_pids(path, references)
    )
    uncertainty = [*usage.errors]
    if process_scan_error:
        uncertainty.append(process_scan_error)
    blocked = bool(uncertainty or (pids and block_on_activity) or path.is_symlink())
    return {
        "id": identifier,
        "path": str(path),
        "category": category,
        "source": source,
        "exists": path.exists() or path.is_symlink(),
        "allocated_bytes": usage.allocated_bytes,
        "apparent_bytes": usage.apparent_bytes,
        "reclaimable_bytes": 0
        if blocked
        else usage.allocated_bytes
        if reclaimable_bytes is None
        else min(reclaimable_bytes, usage.allocated_bytes),
        "files": usage.files,
        "directories": usage.directories,
        "recreation": recreation,
        "action": action,
        "active_pid_count": len(pids),
        "active_pids": pids[:20],
        "activity_scope": activity_scope,
        "blocked": blocked,
        "uncertainty": uncertainty,
        "decision_uncertainty": decision_uncertainty or [],
        "decision_state": "blocked" if blocked else "awaiting_explicit_approval",
    }


def top_level_inventory(roots: list[Path], min_bytes: int) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    seen: set[Path] = set()
    for root in roots:
        if not root.is_dir() or root.is_symlink():
            continue
        try:
            children = sorted(root.iterdir())
        except OSError:
            continue
        for child in children:
            try:
                resolved = child.resolve()
            except OSError:
                resolved = child.absolute()
            if resolved in seen:
                continue
            seen.add(resolved)
            usage = measure_path(child)
            if usage.allocated_bytes >= min_bytes:
                rows.append(
                    {
                        "path": str(child),
                        "allocated_bytes": usage.allocated_bytes,
                        "apparent_bytes": usage.apparent_bytes,
                        "errors": list(usage.errors),
                    }
                )
    return sorted(rows, key=lambda item: item["allocated_bytes"], reverse=True)


def classify_inventory(
    rows: list[dict[str, Any]], candidates: list[dict[str, Any]], min_bytes: int
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    accounted: list[dict[str, Any]] = []
    unknown: list[dict[str, Any]] = []
    for row in rows:
        path = Path(row["path"]).resolve()
        enclosing = [item for item in candidates if is_within(path, Path(item["path"]))]
        if enclosing:
            accounted.append({**row, "covered_paths": [item["path"] for item in enclosing]})
            continue
        descendants = [item for item in candidates if is_within(Path(item["path"]), path)]
        accounted_bytes = sum(
            item["allocated_bytes"] for item in descendants if not item.get("covered_by")
        )
        unaccounted_bytes = max(0, row["allocated_bytes"] - accounted_bytes)
        if unaccounted_bytes >= min_bytes:
            unknown.append(
                {
                    **row,
                    "classification": "partially_accounted" if descendants else "unknown",
                    "accounted_paths": [item["path"] for item in descendants],
                    "unaccounted_estimate_bytes": unaccounted_bytes,
                    "reclaimable_bytes": 0,
                }
            )
        else:
            accounted.append(
                {
                    **row,
                    "covered_paths": [item["path"] for item in descendants],
                    "unaccounted_estimate_bytes": unaccounted_bytes,
                }
            )
    return accounted, unknown


def non_overlapping_total(items: list[dict[str, Any]]) -> tuple[int, list[dict[str, Any]]]:
    selected: list[dict[str, Any]] = []
    for item in sorted(items, key=lambda row: (len(Path(row["path"]).parts), row["path"])):
        path = Path(item["path"])
        covering = next((prior for prior in selected if is_within(path, Path(prior["path"]))), None)
        if covering is not None and covering["reclaimable_bytes"] > 0:
            item["covered_by"] = covering["id"]
            item["counted_reclaimable_bytes"] = 0
        else:
            item["covered_by"] = None
            item["counted_reclaimable_bytes"] = item["reclaimable_bytes"]
            if item["reclaimable_bytes"] > 0:
                selected.append(item)
    return sum(item["counted_reclaimable_bytes"] for item in items), items


def run_audit(config_path: Path) -> dict[str, Any]:
    config = load_config(config_path)
    inventory = config.get("inventory", {})
    inventory_roots = [expand_path(value) for value in inventory.get("roots", [])]
    min_report_bytes = int(inventory.get("min_report_bytes", 1024**3))
    min_capacity_bytes = int(inventory.get("min_capacity_bytes", 16 * 1024 * 1024))
    if min_report_bytes < 0:
        raise AuditError("inventory.min_report_bytes cannot be negative")
    if min_capacity_bytes < 0:
        raise AuditError("inventory.min_capacity_bytes cannot be negative")

    references, process_scan_error = process_references()
    candidates: list[dict[str, Any]] = []
    for spec in config.get("candidates", []):
        path = expand_path(spec["path"])
        candidates.append(
            candidate(
                identifier=str(spec["id"]),
                path=path,
                category=str(spec["category"]),
                recreation=str(spec["recreation"]),
                source="machine_config",
                usage=measure_path(path),
                references=references,
                process_scan_error=process_scan_error,
                decision_uncertainty=[
                    "The configured recreation claim has not been independently verified."
                ],
            )
        )

    cargo = config.get("cargo", {})
    cargo_roots = [expand_path(value) for value in cargo.get("search_roots", [])]
    exclusions = {str(value) for value in cargo.get("exclude_names", [])}
    for index, path in enumerate(discover_cargo_targets(cargo_roots, exclusions), start=1):
        candidates.append(
            candidate(
                identifier=f"cargo-target-{index}",
                path=path,
                category="generated-build-output",
                recreation="Cargo rebuilds it from source and dependencies.",
                source="cargo_discovery",
                usage=measure_path(path),
                references=references,
                process_scan_error=process_scan_error,
                decision_uncertainty=[
                    "Git tracking and unique artifacts have not yet been checked."
                ],
                action="Remove the target directory after checking active builds and Git state",
            )
        )

    codex_result: dict[str, Any] | None = None
    codex = config.get("codex")
    if codex:
        retention_days = int(codex.get("retention_days", MIN_RETENTION_DAYS))
        sessions_root = expand_path(codex["sessions_root"])
        try:
            codex_result = audit_sessions(
                sessions_root, retention_days=retention_days, include_sessions=True
            )
        except SessionError as exc:
            raise AuditError(str(exc)) from exc
        archive_root = expand_path(codex["archive_root"])
        cutoff_date = str(codex_result["cutoff_at"])[:10]
        proposed_archive = archive_root / f"sessions-before-{cutoff_date}"
        session_items = codex_result.pop("sessions")
        eligible_items = [item for item in session_items if item["eligible"]]
        eligible_paths = {Path(item["path"]) for item in eligible_items}
        active_eligible_paths = {
            target for _pid, target in references if target in eligible_paths
        }
        eligible_active_pids = sorted(
            {pid for pid, target in references if target in active_eligible_paths}
        )
        inactive_reclaimable_bytes = sum(
            item["reclaimable_bytes"]
            for item in eligible_items
            if Path(item["path"]) not in active_eligible_paths
        )
        codex_result["archive_root"] = str(archive_root)
        codex_result["proposed_archive_path"] = str(proposed_archive)
        codex_result["eligible_active_pid_count"] = len(eligible_active_pids)
        codex_result["eligible_active_pids"] = eligible_active_pids[:20]
        codex_result["eligible_active_session_count"] = len(active_eligible_paths)
        codex_result["reclaimable_bytes_excluding_active"] = inactive_reclaimable_bytes
        usage = measure_path(sessions_root)
        candidates.append(
            candidate(
                identifier="codex-sessions-older-than-cutoff",
                path=sessions_root,
                category="codex-transcript-archive",
                recreation=(
                    "Not recreatable. Archive preserves messages and metadata but is not "
                    "Codex-resumable."
                ),
                source="codex_programmatic_audit",
                usage=usage,
                references=[],
                process_scan_error=process_scan_error,
                active_pids_override=eligible_active_pids,
                activity_scope="eligible_session_files_only",
                block_on_activity=False,
                decision_uncertainty=[
                    "The archive is not Codex-resumable; source deletion is a separate decision."
                ],
                reclaimable_bytes=inactive_reclaimable_bytes,
                action=(
                    f"Create and verify the additive archive at {proposed_archive}, then "
                    "separately approve source-session removal"
                ),
            )
        )

    candidates.sort(key=lambda item: item["reclaimable_bytes"], reverse=True)
    reclaimable_total, candidates = non_overlapping_total(candidates)
    inventory_rows = top_level_inventory(inventory_roots, min_report_bytes)
    accounted, unknown = classify_inventory(inventory_rows, candidates, min_report_bytes)
    return {
        "schema_version": 1,
        "mode": "audit-only",
        "machine": config.get("machine", "unknown"),
        "config_path": str(config_path.resolve()),
        "mutations_performed": False,
        "filesystem_capacity": filesystem_capacity(
            [*mounted_filesystem_roots(), *inventory_roots],
            min_total_bytes=min_capacity_bytes,
        ),
        "reclaimable_bytes_non_overlapping": reclaimable_total,
        "candidates": candidates,
        "unknown_large_paths": unknown,
        "accounted_large_paths": accounted,
        "codex_sessions": codex_result,
        "notes": [
            "Scope is all configured mutable roots, not immutable operating-system package trees.",
            "Allocated bytes are estimates and can differ from actual freed filesystem blocks.",
            "Unknown large paths are investigation items and contribute zero reclaimable bytes.",
            "No file or directory was changed or removed.",
        ],
    }


def human_bytes(value: int) -> str:
    size = float(value)
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if size < 1024 or unit == "TiB":
            return f"{size:.1f} {unit}"
        size /= 1024
    return f"{size:.1f} TiB"


def print_audit(result: dict[str, Any]) -> None:
    print(f"Storage audit ({result['machine']}): {result['mode']}")
    total = human_bytes(result["reclaimable_bytes_non_overlapping"])
    print(f"Non-overlapping reclaim estimate: {total}")
    ordered = sorted(
        result["candidates"], key=lambda row: row["reclaimable_bytes"], reverse=True
    )
    for item in ordered:
        suffix = f" covered by {item['covered_by']}" if item.get("covered_by") else ""
        print(
            f"- {item['id']}: {human_bytes(item['reclaimable_bytes'])} "
            f"({item['category']}) {item['path']}{suffix}"
        )
    print(f"Unknown large paths: {len(result['unknown_large_paths'])}")
    print("Nothing was removed.")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    audit = subparsers.add_parser("audit")
    audit.add_argument("--config", type=Path, required=True)
    audit.add_argument("--json", action="store_true")
    return parser


def main() -> None:
    args = build_parser().parse_args()
    try:
        result = run_audit(args.config)
    except (AuditError, KeyError, TypeError, ValueError) as exc:
        raise SystemExit(f"reclaim_storage: {exc}") from exc
    if args.json:
        json.dump(result, sys.stdout, indent=2, sort_keys=True)
        print()
    else:
        print_audit(result)


if __name__ == "__main__":
    main()
