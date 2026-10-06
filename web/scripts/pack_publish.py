#!/usr/bin/env python3
"""Upload one cook to a new R2 prefix, then move web-pack/current.json last.

The live prefix and the fallback prefix are never written. A re-cook of the
same cookSha keeps the pack it replaces as previous instead of clearing it.
"""

from __future__ import annotations

import hashlib
import json
import re
import shutil
import signal
import subprocess
import sys
import tempfile
from contextlib import contextmanager
from pathlib import Path

PINNED_LIVE_COOK_SHA = "74d44dde02a0e1c6430a9a78b06034099c84e001"
PINNED_LIVE_PUBLISHED_AT = "2026-10-06T01:35:23Z"
PINNED_LIVE_PREFIX = f"web-pack/{PINNED_LIVE_COOK_SHA}-{PINNED_LIVE_PUBLISHED_AT}"
PINNED_HOME_SHA256 = "fece0ad52e54aa5cb3cb7a3637552d831a4e276d28b695ca3b2797172f7d839a"
PINNED_FILE_SHA256 = {
    "home.json": "fece0ad52e54aa5cb3cb7a3637552d831a4e276d28b695ca3b2797172f7d839a",
    "presub.json": "4a6dae1b78bc7afdc112cfb01f35f74c030f67a7628f01d532d042c7a7d88012",
    "schedule.json": "355d9380e063a6ed91b10f8eddd5e6b9e3b99029423951da38f685e382c482dd",
    "section/dynacap.json": "74ddae60e9f08890eec74033b23a9b065ae898aded143c7c05e766389f16267f",
    "section/five_star.json": "d897682fab9e9d4c99ef0a2233ac45e51162f7843846f380545151d8f656de1b",
    "section/labor.json": "f5c13b9cfc27045ea956e1c91feb5deb595919ab88f82694a8135f78ff6d3ad6",
    "section/lost_revenue.json": "ea5eb712edbedb5e29faca53711ff411b9e7bc0e4086d81bfb7e52bdae3fc997",
    "section/missing_items.json": "0e36937798275be90eb43ac08c5a252e05faf2c4d72cd499eb0f54294fab0862",
    "section/pick_path.json": "e015cd3fa533e4855ad424c17e9c582222735e2200a5302d6733a8c571adb6c2",
    "section/pick_path_picker.json": "2ffa0122cca2023c22e58ce7cab3e424315d2c12b59f0a8add51a7c88c0b357d",
    "section/picker_scorecard.json": "ed295d81358eb147913c1eb957c526b652b4b229a125605b35b6b00873b6c272",
    "section/pph.json": "58b52591cdedd9369650f6981e0a82c0f60f86dfa0224cadbe841241bb0da40a",
    "section/pre_sub_oos.json": "e991bdc34396bf4c832e117bbe910f22b89e09657f0a8afad4defe846d54094f",
    "section/prep_not_ready.json": "9346af1bde88fd7eef9484218ef8fa0389968e2b6d10ed5c501c1458f718a9ec",
    "section/sales.json": "b75d871813f5f29cbb7930792801c39d1e6533cda2e9f5d7a1ab725055a9eb7c",
    "section/schedule_quality.json": "b77a0309c20cec4084aac27cc2cea3328fc7a0fcad25f8bdd1b0f29a89b0d62d",
}
POINTER_KEY = "heartbeat-packs/web-pack/current.json"
NOT_FOUND_LINE = "The specified key does not exist."
_ANSI = re.compile(r"\x1b\[[0-9;]*m")
_TEMP_PATHS: list[str] = []


def _purge_temps() -> None:
    while _TEMP_PATHS:
        shutil.rmtree(_TEMP_PATHS.pop(), ignore_errors=True)


def _on_term(signum, _frame) -> None:
    """A bash-only SIGTERM used to orphan this process and leave its temp dir."""
    _purge_temps()
    raise SystemExit(128 + int(signum))


signal.signal(signal.SIGTERM, _on_term)
signal.signal(signal.SIGHUP, _on_term)


@contextmanager
def _temp_dir():
    path = tempfile.mkdtemp(prefix="hb-pack-")
    _TEMP_PATHS.append(path)
    try:
        yield Path(path)
    finally:
        shutil.rmtree(path, ignore_errors=True)
        try:
            _TEMP_PATHS.remove(path)
        except ValueError:
            pass


def pointer_entry(old: dict) -> dict:
    sha = str(old.get("cookSha") or "")
    published = str(old.get("publishedAt") or "")
    cooked = str(old.get("cookedAt") or "")
    prefix = str(old.get("prefix") or f"web-pack/{sha}-{published}")
    pinned = (
        sha == PINNED_LIVE_COOK_SHA
        and published == PINNED_LIVE_PUBLISHED_AT
        and not cooked
        and prefix == PINNED_LIVE_PREFIX
    )
    if not cooked and not pinned:
        raise SystemExit("data-only upload: pack has no cookedAt")
    return {
        "prefix": prefix,
        "cookSha": sha,
        "publishedAt": published,
        "cookedAt": cooked,
        "schemaVersion": old.get("schemaVersion"),
    }


def plan_pointer(old: dict, sha: str, cooked: str, published: str, schema) -> dict:
    if not cooked or "/" in cooked or "\\" in cooked:
        raise SystemExit("data-only upload: cookedAt missing")
    if cooked == published:
        raise SystemExit("data-only upload: cookedAt must not copy publishedAt")
    prefix = f"web-pack/{sha}-{cooked}"
    live_prefix = str(old.get("prefix") or "")
    if live_prefix and live_prefix == prefix:
        raise SystemExit("data-only upload: refusing to write into the live pack folder")
    previous_obj = old.get("previous") if isinstance(old.get("previous"), dict) else None
    fallback_prefix = str((previous_obj or {}).get("prefix") or "")
    if fallback_prefix and fallback_prefix == prefix:
        raise SystemExit("data-only upload: refusing to write into the fallback pack folder")
    previous = None
    old_sha = str(old.get("cookSha") or "")
    if re.fullmatch(r"[0-9a-f]{40}", old_sha) and live_prefix and live_prefix != prefix:
        previous = pointer_entry(old)
    elif previous_obj:
        previous = pointer_entry(previous_obj)
    return {
        "prefix": prefix,
        "cookSha": sha,
        "cookedAt": cooked,
        "publishedAt": published,
        "schemaVersion": schema,
        "previous": previous,
    }


def upload_pack(root: Path, check_pack: Path, wrangler=None, checker=None, *, first_publish=False, move_pointer=True) -> dict:
    def run(args, check=True):
        return _run(wrangler, args, check=check)

    files = sorted(path for path in root.rglob("*.json") if path.is_file())
    if not files:
        raise SystemExit("data-only upload: no pack json")
    home_path = root / "home.json"
    if not home_path.is_file():
        raise SystemExit("data-only upload: home.json is missing")
    home = json.loads(home_path.read_text(encoding="utf-8"))
    meta = home.get("metadata") if isinstance(home.get("metadata"), dict) else {}
    sha = str(meta.get("cookSha") or home.get("cookSha") or "")
    published = str(home.get("publishedAt") or "")
    cooked = str(home.get("cookedAt") or meta.get("cookedAt") or "")
    schema = home.get("schemaVersion")
    if schema is None:
        schema = meta.get("schemaVersion")
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        raise SystemExit("data-only upload: cookSha missing")
    if not published or "/" in published or "\\" in published:
        raise SystemExit("data-only upload: publishedAt missing")

    with _temp_dir() as tmp:
        tmp_path = Path(tmp)
        pointer_file = tmp_path / "current.json"
        raw = _remote_bytes(run, POINTER_KEY, pointer_file)
        if raw is None or not raw.strip():
            if not first_publish:
                raise SystemExit("data-only upload: current.json is absent; pass --first-publish")
            old = {}
        else:
            try:
                loaded = json.loads(raw.decode("utf-8"))
            except json.JSONDecodeError:
                raise SystemExit("data-only upload: current.json is not json")
            if not isinstance(loaded, dict):
                raise SystemExit("data-only upload: current.json is not an object")
            old = loaded
        old_cooked = str(old.get("cookedAt") or "")
        old_sha = str(old.get("cookSha") or "")
        if old_cooked and old_cooked > cooked:
            raise SystemExit("data-only upload: refusing to replace a newer pointer")
        if old_cooked and old_cooked == cooked and old_sha == sha:
            print("data-only upload: pointer already has this cook")
            return {**old, "unchanged": True}
        plan = plan_pointer(old, sha, cooked, published, schema)
        prefix = plan["prefix"]
        for path in files:
            rel = path.relative_to(root).as_posix()
            key = f"heartbeat-packs/{prefix}/{rel}"
            run(["r2", "object", "put", key, f"--file={path}", "--remote"])
        downloaded = tmp_path / "uploaded"
        for path in files:
            rel = path.relative_to(root).as_posix()
            dest = downloaded / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            key = f"heartbeat-packs/{prefix}/{rel}"
            run(["r2", "object", "get", key, f"--file={dest}", "--remote"])
        if checker is not None:
            checked = checker(downloaded)
        else:
            checked = subprocess.run(["node", str(check_pack), str(downloaded)], check=False)
        if getattr(checked, "returncode", 1) != 0:
            raise SystemExit("data-only upload: check_pack failed on the uploaded set; current.json was not moved")
        if move_pointer:
            _put_pointer(run, tmp_path, plan)
    if move_pointer:
        print(
            f"data-only upload: {len(files)} pack files at {plan['prefix']}/, check_pack passed, current.json updated, site tree not deployed"
        )
    else:
        print(
            f"data-only upload: {len(files)} pack files at {plan['prefix']}/, check_pack passed, current.json deferred until pages deploy succeeds, site tree not deployed"
        )
    return plan


def _run(wrangler, args, check=True):
    if wrangler is not None:
        return wrangler(args, check=check)
    result = subprocess.run(["npx", "wrangler", *args], check=False, capture_output=True, text=True)
    # Wrangler 4.147 prints its banner, a rule, "Resource location", and
    # Downloading "web-pack/current.json"… on stdout. The shell preflight
    # reads only this process's stdout, so that banner has to stay on stderr.
    if result.stdout:
        print(result.stdout, end="" if result.stdout.endswith("\n") else "\n", file=sys.stderr)
    if result.stderr:
        print(result.stderr, end="" if result.stderr.endswith("\n") else "\n", file=sys.stderr)
    if check and result.returncode != 0:
        raise SystemExit(result.returncode or 1)
    return result


def _result_text(result) -> str:
    stdout = getattr(result, "stdout", "") or ""
    stderr = getattr(result, "stderr", "") or ""
    if isinstance(stdout, bytes):
        stdout = stdout.decode("utf-8", "replace")
    if isinstance(stderr, bytes):
        stderr = stderr.decode("utf-8", "replace")
    return f"{stdout}\n{stderr}".lower()


def _output_lines(result) -> list[str]:
    stdout = getattr(result, "stdout", "") or ""
    stderr = getattr(result, "stderr", "") or ""
    if isinstance(stdout, bytes):
        stdout = stdout.decode("utf-8", "replace")
    if isinstance(stderr, bytes):
        stderr = stderr.decode("utf-8", "replace")
    return f"{stdout}\n{stderr}".splitlines()


def _error_body(line: str) -> tuple[bool, str]:
    """Strip ANSI, then an optional '✘ [ERROR] ' or '[ERROR] ' prefix."""
    text = _ANSI.sub("", line).strip()
    if text.startswith("✘ [ERROR] "):
        return True, text[len("✘ [ERROR] ") :]
    if text.startswith("[ERROR] "):
        return True, text[len("[ERROR] ") :]
    return "[ERROR]" in text, text


def _is_not_found(result) -> bool:
    """Wrangler's missing-key line, with or without its error prefix and colour.

    Any other [ERROR] line in the same output is not a missing key. An auth
    failure that also prints the key line must not count as absent.
    """
    saw_missing = False
    for line in _output_lines(result):
        if not _ANSI.sub("", line).strip():
            continue
        is_error, body = _error_body(line)
        if body == NOT_FOUND_LINE:
            saw_missing = True
            continue
        if is_error:
            return False
    return saw_missing


def _remote_bytes(run, key: str, dest: Path):
    """Return bytes, or None only when the object is a definite not-found.

    Any other get failure, including a temporary error that writes no file,
    raises. It must not be treated as a missing pointer.
    """
    if dest.exists():
        dest.unlink()
    got = run(["r2", "object", "get", key, f"--file={dest}", "--remote"], check=False)
    code = getattr(got, "returncode", 1)
    wrote = dest.is_file() and dest.stat().st_size > 0
    if code != 0:
        if wrote or not _is_not_found(got):
            detail = _result_text(got).strip() or f"exit {code}"
            raise SystemExit(f"pointer preflight: {key} get failed: {detail}")
        return None
    if not dest.is_file():
        raise SystemExit(f"pointer preflight: {key} get wrote nothing")
    return dest.read_bytes()


def _put_pointer(run, tmp_path: Path, pointer: dict) -> dict:
    dest = tmp_path / "next-current.json"
    dest.write_text(json.dumps(pointer), encoding="utf-8")
    run(["r2", "object", "put", POINTER_KEY, f"--file={dest}", "--remote"])
    raw = _remote_bytes(run, POINTER_KEY, tmp_path / "readback-current.json")
    if raw is None:
        raise SystemExit("pointer write: current.json was not found after put")
    try:
        loaded = json.loads(raw.decode("utf-8"))
    except json.JSONDecodeError:
        raise SystemExit("pointer write: current.json readback is not json")
    if loaded != pointer:
        raise SystemExit("pointer write: current.json readback does not match")
    return loaded


def _live_matches_previous(live, expected) -> bool:
    """The deferred commit may write only if the live pointer is still plan previous."""
    if expected is None:
        return live is None or live == {}
    if not isinstance(live, dict) or not isinstance(expected, dict):
        return False
    try:
        return pointer_entry(live) == expected
    except SystemExit:
        return False


def commit_pointer(plan_path: Path, wrangler=None) -> dict:
    """Move current.json after a pages deploy has succeeded.

    Data-only upload moves the pointer inside upload_pack. A full deploy
    defers that put until wrangler pages deploy exits 0. The live pointer is
    read again first and must still equal the plan's previous.
    """
    plan = json.loads(Path(plan_path).read_text(encoding="utf-8"))
    if not isinstance(plan, dict):
        raise SystemExit("pointer commit: plan is not an object")
    if plan.get("unchanged"):
        print("pointer commit: current.json already has this cook")
        return plan
    body = {key: value for key, value in plan.items() if key != "unchanged"}

    def run(args, check=True):
        return _run(wrangler, args, check=check)

    with _temp_dir() as tmp_path:
        raw = _remote_bytes(run, POINTER_KEY, tmp_path / "live-current.json")
        if raw is None:
            live = None
        else:
            try:
                live = json.loads(raw.decode("utf-8"))
            except json.JSONDecodeError:
                raise SystemExit("pointer commit: live current.json is not json")
            if not isinstance(live, dict):
                raise SystemExit("pointer commit: live current.json is not an object")
        if not _live_matches_previous(live, body.get("previous")):
            raise SystemExit("pointer commit: live pointer no longer matches the plan previous")
        loaded = _put_pointer(run, tmp_path, body)
    print("pointer commit: current.json updated after the pages deploy")
    return loaded


def pointer_servable(old: dict) -> bool:
    sha = str(old.get("cookSha") or "")
    published = str(old.get("publishedAt") or "")
    cooked = str(old.get("cookedAt") or "")
    prefix = str(old.get("prefix") or "")
    if not re.fullmatch(r"[0-9a-f]{40}", sha) or old.get("schemaVersion") != 1:
        return False
    if not prefix.startswith("web-pack/") or ".." in prefix or "\\" in prefix:
        return False
    if cooked:
        if "/" in cooked or "\\" in cooked or not published:
            return False
        return prefix == f"web-pack/{sha}-{cooked}"
    return sha == PINNED_LIVE_COOK_SHA and published == PINNED_LIVE_PUBLISHED_AT and prefix == PINNED_LIVE_PREFIX


def migrate_pinned_pointer(root: Path, wrangler=None) -> str:
    """Write the pinned pointer once. Never called from preflight or a deploy.

    current.json must be a definite not-found. Every pinned pack file must
    match PINNED_FILE_SHA256. The pointer is read back after the put.
    """
    if not root.is_dir():
        raise SystemExit("pinned migration: data dir is missing")

    def run(args, check=True):
        return _run(wrangler, args, check=check)

    with _temp_dir() as tmp:
        tmp_path = Path(tmp)
        raw = _remote_bytes(run, POINTER_KEY, tmp_path / "current.json")
        if raw is not None:
            raise SystemExit("pinned migration: current.json already exists")
        for rel, digest in PINNED_FILE_SHA256.items():
            blob = _remote_bytes(run, f"heartbeat-packs/{PINNED_LIVE_PREFIX}/{rel}", tmp_path / "object")
            if blob is None:
                raise SystemExit(f"pinned migration: {rel} is missing")
            if hashlib.sha256(blob).hexdigest() != digest:
                raise SystemExit(f"pinned migration: {rel} sha256 does not match")
        pointer = {
            "prefix": PINNED_LIVE_PREFIX,
            "cookSha": PINNED_LIVE_COOK_SHA,
            "publishedAt": PINNED_LIVE_PUBLISHED_AT,
            "cookedAt": "",
            "schemaVersion": 1,
        }
        _put_pointer(run, tmp_path, pointer)
    print("pinned migration: wrote pinned pointer")
    return "migrated"


def preflight_pointer(root: Path, wrangler=None) -> str:
    """Verify current.json. A definite not-found is absent and is not written.

    Any other read error fails closed. Empty or corrupt JSON is not absent.
    A cookedAt pack, or the pinned prefix, is verified with no put. The
    legacy pinned pointer is not written here.
    """
    if not root.is_dir():
        raise SystemExit("pointer preflight: data dir is missing")

    def run(args, check=True):
        return _run(wrangler, args, check=check)

    with _temp_dir() as tmp:
        raw = _remote_bytes(run, POINTER_KEY, Path(tmp) / "current.json")
        if raw is None:
            print("pointer preflight: current.json is absent")
            return "absent"
        text = raw.decode("utf-8")
        if not text.strip():
            raise SystemExit("pointer preflight: current.json is empty")
        try:
            loaded = json.loads(text)
        except json.JSONDecodeError:
            raise SystemExit("pointer preflight: current.json is not json")
        if not isinstance(loaded, dict):
            raise SystemExit("pointer preflight: current.json is not an object")
        if pointer_servable(loaded):
            print("pointer preflight: verified")
            return "verified"
        raise SystemExit("pointer preflight: current.json is not a cooked pack or the pinned live pack")


def print_pointer(wrangler=None) -> str:
    """Canonical live pointer. UI-only deploys compare this before and after."""

    def run(args, check=True):
        return _run(wrangler, args, check=check)

    with _temp_dir() as tmp:
        raw = _remote_bytes(run, POINTER_KEY, tmp / "current.json")
    if raw is None:
        text = "absent"
    else:
        try:
            loaded = json.loads(raw.decode("utf-8"))
        except json.JSONDecodeError:
            raise SystemExit("pointer read: current.json is not json")
        if not isinstance(loaded, dict):
            raise SystemExit("pointer read: current.json is not an object")
        text = json.dumps(pointer_entry(loaded), sort_keys=True)
    print(text)
    return text


def main() -> int:
    argv = sys.argv[1:]
    if argv[:1] == ["print-pointer"]:
        if len(argv) != 1:
            print("usage: pack_publish.py print-pointer", file=sys.stderr)
            return 2
        print_pointer()
        return 0
    if argv[:1] == ["preflight"]:
        if len(argv) != 2:
            print("usage: pack_publish.py preflight DATA_DIR", file=sys.stderr)
            return 2
        preflight_pointer(Path(argv[1]))
        return 0
    if argv[:1] == ["migrate-pinned"]:
        if len(argv) != 2:
            print("usage: pack_publish.py migrate-pinned DATA_DIR", file=sys.stderr)
            return 2
        migrate_pinned_pointer(Path(argv[1]))
        return 0
    if argv[:1] == ["--commit-pointer"]:
        if len(argv) != 2:
            print("usage: pack_publish.py --commit-pointer PLAN.json", file=sys.stderr)
            return 2
        commit_pointer(Path(argv[1]))
        return 0
    first_publish = "--first-publish" in argv
    defer_pointer = "--defer-pointer" in argv
    rest = [item for item in argv if item not in {"--first-publish", "--defer-pointer"}]
    if defer_pointer:
        if len(rest) != 3:
            print(
                "usage: pack_publish.py --defer-pointer [--first-publish] DATA_DIR check_pack.mjs PLAN.json",
                file=sys.stderr,
            )
            return 2
        plan = upload_pack(Path(rest[0]), Path(rest[1]), first_publish=first_publish, move_pointer=False)
        Path(rest[2]).write_text(json.dumps(plan), encoding="utf-8")
        return 0
    if len(rest) != 2:
        print(
            "usage: pack_publish.py [--first-publish] DATA_DIR check_pack.mjs"
            " | --defer-pointer DATA_DIR check_pack.mjs PLAN.json"
            " | --commit-pointer PLAN.json | preflight DATA_DIR | print-pointer | migrate-pinned DATA_DIR",
            file=sys.stderr,
        )
        return 2
    upload_pack(Path(rest[0]), Path(rest[1]), first_publish=first_publish)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
