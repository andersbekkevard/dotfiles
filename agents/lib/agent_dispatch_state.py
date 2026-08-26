"""Shared native-transcript state for model dispatchers."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import uuid
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote


TRANSCRIPT_PREFIX = "Transcript: "
DEFAULT_STATE = Path.home() / ".local/state"
PROVIDERS = ("codex", "claude", "grok")


def dispatch_root() -> Path:
    state_home = os.environ.get("XDG_STATE_HOME")
    base = Path(state_home).expanduser() if state_home else DEFAULT_STATE
    return base / "agent-dispatch"


def private_dir(path: Path) -> Path:
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    root = dispatch_root().resolve()
    current = path.resolve()
    while root == current or root in current.parents:
        current.chmod(0o700)
        if current == root:
            break
        current = current.parent
    return path


def provider_root(provider: str) -> Path:
    if provider not in PROVIDERS:
        raise ValueError(f"unknown dispatch provider: {provider}")
    return private_dir(dispatch_root() / provider)


def new_run_id() -> str:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S")
    return f"{stamp}-{uuid.uuid4().hex[:12]}"


def new_session_id() -> str:
    return str(uuid.uuid4())


def regular_file(path: Path) -> bool:
    try:
        return path.is_file() and not path.is_symlink()
    except OSError:
        return False


def stage_secret(source: Path, destination: Path, *, link: bool = True) -> None:
    if not regular_file(source):
        raise FileNotFoundError(source)
    destination.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    tmp = destination.parent / f".{destination.name}.{os.getpid()}.{uuid.uuid4().hex[:8]}"
    try:
        staged = False
        if link:
            try:
                os.link(source, tmp)
                staged = True
            except OSError:
                pass
        if not staged:
            shutil.copyfile(source, tmp)
        os.chmod(tmp, 0o600)
        os.replace(tmp, destination)
    except BaseException:
        try:
            tmp.unlink()
        except FileNotFoundError:
            pass
        raise


def write_private_text(path: Path, text: str) -> None:
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd, temp_path = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(text)
        os.replace(temp_path, path)
        path.chmod(0o600)
    except BaseException:
        try:
            os.unlink(temp_path)
        except FileNotFoundError:
            pass
        raise


def source_codex_home() -> Path:
    raw = os.environ.get("CODEX_HOME")
    return Path(raw).expanduser() if raw else Path.home() / ".codex"


def source_claude_config_dir() -> Path:
    raw = os.environ.get("CLAUDE_CONFIG_DIR")
    return Path(raw).expanduser() if raw else Path.home() / ".claude"


def source_claude_json() -> Path:
    configured = os.environ.get("CLAUDE_CONFIG_DIR")
    if configured:
        candidate = Path(configured).expanduser() / ".claude.json"
        if regular_file(candidate):
            return candidate
    return Path.home() / ".claude.json"


def read_macos_claude_credentials() -> str | None:
    if sys.platform != "darwin":
        return None
    import pwd

    account = pwd.getpwuid(os.getuid()).pw_name
    try:
        result = subprocess.run(
            [
                "/usr/bin/security",
                "find-generic-password",
                "-a",
                account,
                "-s",
                "Claude Code-credentials",
                "-w",
            ],
            text=True,
            capture_output=True,
            check=False,
            timeout=10,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if result.returncode != 0:
        return None
    credentials = result.stdout.strip()
    try:
        payload = json.loads(credentials)
    except json.JSONDecodeError:
        return None
    if not isinstance(payload, dict) or not isinstance(payload.get("claudeAiOauth"), dict):
        return None
    return credentials


def source_grok_home() -> Path:
    raw = os.environ.get("GROK_HOME")
    return Path(raw).expanduser() if raw else Path.home() / ".grok"


def prepare_codex_home() -> Path:
    home = private_dir(provider_root("codex") / new_run_id())
    source = source_codex_home()
    auth = source / "auth.json"
    if not regular_file(auth):
        raise FileNotFoundError("Codex auth.json is missing")
    stage_secret(auth, home / "auth.json")
    write_private_text(home / "config.toml", 'cli_auth_credentials_store = "file"\n')
    installation_id = source / "installation_id"
    if regular_file(installation_id):
        stage_secret(installation_id, home / "installation_id", link=False)
    return home


def prepare_claude_home() -> Path:
    home = private_dir(provider_root("claude") / new_run_id())
    source = source_claude_config_dir()
    credentials = source / ".credentials.json"
    if regular_file(credentials):
        stage_secret(credentials, home / ".credentials.json")
    else:
        keychain_credentials = read_macos_claude_credentials()
        if keychain_credentials is None:
            raise FileNotFoundError(
                "Claude .credentials.json is missing and macOS Keychain credentials are unavailable"
            )
        write_private_text(home / ".credentials.json", keychain_credentials)
    claude_json = source_claude_json()
    if regular_file(claude_json):
        stage_secret(claude_json, home / ".claude.json", link=False)
    return home


def prepare_grok_home() -> Path:
    home = private_dir(provider_root("grok"))
    source = source_grok_home()
    auth = source / "auth.json"
    if not regular_file(auth):
        raise FileNotFoundError("Grok auth.json is missing")
    stage_secret(auth, home / "auth.json")
    agent_id = source / "agent_id"
    if regular_file(agent_id):
        stage_secret(agent_id, home / "agent_id", link=False)
    return home


def session_meta(path: Path) -> dict[str, object] | None:
    try:
        with path.open(encoding="utf-8") as handle:
            first = handle.readline()
        payload = json.loads(first)
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(payload, dict) or payload.get("type") != "session_meta":
        return None
    inner = payload.get("payload")
    return inner if isinstance(inner, dict) else None


def is_codex_parent_rollout(path: Path) -> bool:
    meta = session_meta(path)
    if meta is None:
        return False
    if meta.get("thread_source") == "subagent":
        return False
    source = meta.get("source")
    return not (isinstance(source, dict) and "subagent" in source)


def resolve_codex_parent_rollout(codex_home: Path) -> Path:
    sessions = codex_home / "sessions"
    matches = [
        path
        for path in sessions.glob("*/*/*/rollout-*.jsonl")
        if path.is_file() and is_codex_parent_rollout(path)
    ]
    if len(matches) != 1:
        raise FileNotFoundError(
            "expected exactly one parent Codex rollout in the dispatch home, "
            f"found {len(matches)}"
        )
    return matches[0].resolve()


def claude_project_slug(cwd: Path) -> str:
    return str(cwd.resolve()).replace("/", "-")


def claude_transcript_path(config_dir: Path, cwd: Path, session_id: str) -> Path:
    return (config_dir / "projects" / claude_project_slug(cwd) / f"{session_id}.jsonl").resolve()


def resolve_claude_transcript(config_dir: Path, session_id: str) -> Path:
    matches = [
        path
        for path in (config_dir / "projects").glob(f"*/{session_id}.jsonl")
        if path.is_file()
    ]
    if len(matches) != 1:
        raise FileNotFoundError(
            "expected exactly one Claude parent session for the assigned id, "
            f"found {len(matches)}"
        )
    return matches[0].resolve()


def grok_cwd_key(cwd: Path) -> str:
    return quote(str(cwd.resolve()), safe="")


def resolve_grok_session(grok_home: Path, cwd: Path, session_id: str) -> Path:
    direct = grok_home / "sessions" / grok_cwd_key(cwd) / session_id
    if direct.is_dir():
        session = direct.resolve()
    else:
        matches = [
            path
            for path in (grok_home / "sessions").glob(f"*/{session_id}")
            if path.is_dir()
        ]
        if len(matches) != 1:
            raise FileNotFoundError(
                "expected exactly one Grok session directory for the assigned id, "
                f"found {len(matches)}"
            )
        session = matches[0].resolve()
    summary = session / "summary.json"
    return summary.resolve() if summary.is_file() else session
