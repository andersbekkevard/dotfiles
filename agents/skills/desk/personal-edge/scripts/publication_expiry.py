#!/usr/bin/env python3
"""Durable, ownership-checked expiry for personal-edge publications."""

from __future__ import annotations

import argparse
import contextlib
import datetime as dt
import fcntl
import json
import os
import re
import socket
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any, Callable


API_BASE = "https://api.cloudflare.com/client/v4"
HOSTNAME_RE = re.compile(r"^[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?$")
UNIT_RE = re.compile(r"^[A-Za-z0-9_.@-]+\.service$")
ORIGIN_HOST_RE = re.compile(r"^[A-Za-z0-9_.-]+$")


class ExpiryError(RuntimeError):
    pass


def utc_now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def isoformat(value: dt.datetime) -> str:
    return value.astimezone(dt.timezone.utc).isoformat().replace("+00:00", "Z")


def parse_instant(value: str | None, now: dt.datetime | None = None) -> dt.datetime:
    now = now or utc_now()
    if value is None:
        return now + dt.timedelta(hours=24)
    if value == "now":
        return now
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ExpiryError(f"invalid ISO-8601 expiry: {value}") from exc
    if parsed.tzinfo is None:
        raise ExpiryError("expiry must include a timezone")
    return parsed.astimezone(dt.timezone.utc)


def normalize_hostname(value: str) -> str:
    hostname = value.lower().rstrip(".")
    if not HOSTNAME_RE.fullmatch(hostname) or ".." in hostname:
        raise ExpiryError(f"invalid hostname: {value}")
    return hostname


def state_root() -> Path:
    override = os.environ.get("PERSONAL_EDGE_STATE_DIR")
    return Path(override) if override else Path.home() / ".local/state/personal-edge"


def atomic_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(value, handle, indent=2, sort_keys=True)
            handle.write("\n")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


@contextlib.contextmanager
def expiry_lock():
    root = state_root()
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    path = root / "expiry.lock"
    with path.open("a+", encoding="utf-8") as handle:
        os.chmod(path, 0o600)
        fcntl.flock(handle, fcntl.LOCK_EX)
        yield


class CloudflareClient:
    def __init__(self, token: str, account_id: str, api_base: str = API_BASE):
        self.token = token
        self.account_id = account_id
        self.api_base = api_base.rstrip("/")

    def request(self, method: str, path: str, body: dict[str, Any] | None = None) -> Any:
        data = json.dumps(body).encode() if body is not None else None
        request = urllib.request.Request(
            self.api_base + path,
            data=data,
            method=method,
            headers={
                "Authorization": f"Bearer {self.token}",
                "Content-Type": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                payload = json.load(response)
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode(errors="replace")[:500]
            raise ExpiryError(f"Cloudflare {method} {path} failed: HTTP {exc.code}: {detail}") from exc
        except urllib.error.URLError as exc:
            raise ExpiryError(f"Cloudflare {method} {path} failed: {exc.reason}") from exc
        if not payload.get("success"):
            raise ExpiryError(f"Cloudflare {method} {path} failed: {payload.get('errors')}")
        return payload.get("result")

    def dns_record(self, zone_id: str, record_id: str) -> dict[str, Any] | None:
        try:
            return self.request("GET", f"/zones/{zone_id}/dns_records/{record_id}")
        except ExpiryError as exc:
            if "HTTP 404" in str(exc):
                return None
            raise

    def delete_dns(self, zone_id: str, record_id: str) -> None:
        self.request("DELETE", f"/zones/{zone_id}/dns_records/{record_id}")

    def tunnel_config(self, tunnel_id: str) -> dict[str, Any]:
        result = self.request(
            "GET",
            f"/accounts/{self.account_id}/cfd_tunnel/{tunnel_id}/configurations",
        )
        return result["config"]

    def put_tunnel_config(self, tunnel_id: str, config: dict[str, Any]) -> None:
        self.request(
            "PUT",
            f"/accounts/{self.account_id}/cfd_tunnel/{tunnel_id}/configurations",
            {"config": config},
        )


def matching_ingress(config: dict[str, Any], hostname: str) -> list[dict[str, Any]]:
    return [item for item in config.get("ingress", []) if item.get("hostname") == hostname]


def without_owned_ingress(
    config: dict[str, Any], hostname: str, expected_service: str
) -> tuple[dict[str, Any], bool]:
    matches = matching_ingress(config, hostname)
    if len(matches) > 1:
        raise ExpiryError(f"multiple ingress entries claim {hostname}")
    if matches and matches[0].get("service") != expected_service:
        raise ExpiryError(
            f"ingress ownership mismatch for {hostname}: expected {expected_service}, "
            f"found {matches[0].get('service')}"
        )
    if not matches:
        return config, False
    updated = dict(config)
    updated["ingress"] = [
        item for item in config.get("ingress", []) if item.get("hostname") != hostname
    ]
    return updated, True


def validate_dns(record: dict[str, Any] | None, state: dict[str, Any]) -> None:
    if record is None:
        return
    expected = {
        "type": "CNAME",
        "name": state["hostname"],
        "content": state["dns_content"],
    }
    actual = {key: record.get(key) for key in expected}
    if actual != expected:
        raise ExpiryError(f"DNS ownership mismatch: expected {expected}, found {actual}")


def validate_origin(origin_host: str | None, origin_unit: str | None) -> None:
    if bool(origin_host) != bool(origin_unit):
        raise ExpiryError("origin host and origin unit must be supplied together")
    if origin_host and not ORIGIN_HOST_RE.fullmatch(origin_host):
        raise ExpiryError(f"unsafe origin host: {origin_host}")
    if origin_unit and not UNIT_RE.fullmatch(origin_unit):
        raise ExpiryError(f"unsafe origin unit: {origin_unit}")


def stop_origin(origin_host: str | None, origin_unit: str | None) -> None:
    if not origin_host or not origin_unit:
        return
    local_names = {socket.gethostname(), socket.getfqdn(), "localhost"}
    if origin_host in local_names:
        command = ["systemctl", "--user", "disable", "--now", origin_unit]
    else:
        command = ["ssh", origin_host, "systemctl", "--user", "disable", "--now", origin_unit]
    completed = subprocess.run(command, text=True, capture_output=True)
    if completed.returncode:
        detail = (completed.stderr or completed.stdout).strip()
        raise ExpiryError(f"origin cleanup failed for {origin_host}/{origin_unit}: {detail}")


def process_record(
    client: CloudflareClient,
    state: dict[str, Any],
    stop_origin_fn: Callable[[str | None, str | None], None] = stop_origin,
) -> dict[str, Any]:
    hostname = state["hostname"]
    record = client.dns_record(state["zone_id"], state["dns_record_id"])
    validate_dns(record, state)
    config = client.tunnel_config(state["tunnel_id"])
    updated, ingress_present = without_owned_ingress(config, hostname, state["service"])

    if record is not None:
        client.delete_dns(state["zone_id"], state["dns_record_id"])
    if ingress_present:
        latest_config = client.tunnel_config(state["tunnel_id"])
        updated, ingress_present = without_owned_ingress(
            latest_config, hostname, state["service"]
        )
        if ingress_present:
            client.put_tunnel_config(state["tunnel_id"], updated)

    remaining_record = client.dns_record(state["zone_id"], state["dns_record_id"])
    if remaining_record is not None:
        raise ExpiryError(f"DNS record still exists after cleanup: {hostname}")
    remaining_config = client.tunnel_config(state["tunnel_id"])
    if matching_ingress(remaining_config, hostname):
        raise ExpiryError(f"ingress still exists after cleanup: {hostname}")

    stop_origin_fn(state.get("origin_host"), state.get("origin_unit"))
    return {**state, "completed_at": isoformat(utc_now()), "result": "expired"}


def schedule(args: argparse.Namespace) -> int:
    now = utc_now()
    hostname = normalize_hostname(args.hostname)
    validate_origin(args.origin_host, args.origin_unit)
    state = {
        "version": 1,
        "hostname": hostname,
        "zone_id": args.zone_id,
        "tunnel_id": args.tunnel_id,
        "dns_record_id": args.dns_record_id,
        "dns_content": args.dns_content,
        "service": args.service,
        "origin_host": args.origin_host,
        "origin_unit": args.origin_unit,
        "created_at": isoformat(now),
        "expires_at": isoformat(parse_instant(args.expires_at, now)),
    }
    path = state_root() / "expirations" / f"{hostname}.json"
    if path.exists() and not args.replace:
        existing = json.loads(path.read_text(encoding="utf-8"))
        comparable = set(state) - {"created_at", "expires_at"}
        if all(existing.get(key) == state.get(key) for key in comparable):
            print(f"already scheduled {hostname} for {existing['expires_at']}")
            return 0
        raise ExpiryError(f"different expiry record already exists: {path}")
    atomic_json(path, state)
    print(f"scheduled {hostname} for {state['expires_at']}")
    return 0


def load_client() -> CloudflareClient:
    token = os.environ.get("CLOUDFLARE_API_TOKEN")
    account_id = os.environ.get("CLOUDFLARE_ACCOUNT_ID")
    if not token or not account_id:
        raise ExpiryError("CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID are required")
    return CloudflareClient(token, account_id)


def _run_due(args: argparse.Namespace) -> int:
    now = utc_now()
    paths = sorted((state_root() / "expirations").glob("*.json"))
    if args.hostname:
        hostname = normalize_hostname(args.hostname)
        paths = [path for path in paths if path.stem == hostname]
    due: list[tuple[Path, dict[str, Any]]] = []
    for path in paths:
        state = json.loads(path.read_text(encoding="utf-8"))
        if parse_instant(state["expires_at"]) <= now:
            due.append((path, state))
    if not due:
        print("no due publications")
        return 0

    client = load_client()
    failures = 0
    for path, state in due:
        try:
            receipt = process_record(client, state)
            receipt_path = state_root() / "receipts" / f"{state['hostname']}-{int(now.timestamp())}.json"
            atomic_json(receipt_path, receipt)
            path.unlink()
            print(f"expired {state['hostname']}; receipt={receipt_path}")
        except Exception as exc:
            failures += 1
            print(f"ERROR {state.get('hostname', path.stem)}: {exc}", file=sys.stderr)
    return 1 if failures else 0


def run_due(args: argparse.Namespace) -> int:
    with expiry_lock():
        return _run_due(args)


def status(_: argparse.Namespace) -> int:
    paths = sorted((state_root() / "expirations").glob("*.json"))
    if not paths:
        print("no scheduled publications")
        return 0
    now = utc_now()
    for path in paths:
        state = json.loads(path.read_text(encoding="utf-8"))
        expiry = parse_instant(state["expires_at"])
        disposition = "due" if expiry <= now else "scheduled"
        print(f"{state['hostname']}\t{state['expires_at']}\t{disposition}")
    return 0


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    commands = result.add_subparsers(dest="command", required=True)
    create = commands.add_parser("schedule", help="record an owned publication expiry")
    create.add_argument("--hostname", required=True)
    create.add_argument("--zone-id", required=True)
    create.add_argument("--tunnel-id", required=True)
    create.add_argument("--dns-record-id", required=True)
    create.add_argument("--dns-content", required=True)
    create.add_argument("--service", required=True)
    create.add_argument("--origin-host")
    create.add_argument("--origin-unit")
    create.add_argument("--expires-at", help="ISO-8601 instant or 'now'; defaults to 24 hours")
    create.add_argument("--replace", action="store_true")
    create.set_defaults(func=schedule)

    run = commands.add_parser("run-due", help="expire due publications")
    run.add_argument("--hostname", help="limit processing to one hostname")
    run.set_defaults(func=run_due)

    show = commands.add_parser("status", help="list scheduled publications")
    show.set_defaults(func=status)
    return result


def main() -> int:
    try:
        args = parser().parse_args()
        return args.func(args)
    except (ExpiryError, KeyError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
