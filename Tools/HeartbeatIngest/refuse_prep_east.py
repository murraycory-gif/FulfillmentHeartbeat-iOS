#!/usr/bin/env python3
"""Refuse a cooked pack that would publish a bad Prep rate or an East Dynacap hole.

Prep Not Ready Hours % is a 0–1 fraction in Excel. A company mean above 20, or at
least half the rows exactly 100, means Store # (always 1) was scaled into the rate.
Dynacap East (Jewel Osco + Mid-Atlantic + Shaws) is the Excel DIVISION_NM slicer.
This gate only counts. It does not invent Prep rates or East rows.
"""
from __future__ import annotations

import json
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from thin_company import canon_store  # noqa: E402

EAST = ("Jewel Osco", "Mid-Atlantic", "Shaws")
PREP_MEAN_MAX = 20.0
PREP_HUNDRED_SHARE = 0.5


def east_name(raw: str) -> str | None:
    compact = "".join(ch for ch in (raw or "").lower() if ch.isalnum())
    if not compact:
        return None
    if "jewel" in compact:
        return "Jewel Osco"
    if "midatlantic" in compact:
        return "Mid-Atlantic"
    if compact.startswith("shaw"):
        return "Shaws"
    return None


def _pnr(raw: str | None) -> float | None:
    if not raw:
        return None
    try:
        data = json.loads(raw)
    except (TypeError, json.JSONDecodeError):
        return None
    value = data.get("pnr_rate_pct") if isinstance(data, dict) else None
    if isinstance(value, bool) or value is None:
        return None
    if isinstance(value, (int, float)):
        number = float(value)
    elif isinstance(value, str):
        try:
            number = float(value)
        except ValueError:
            return None
    else:
        return None
    if number != number:
        return None
    return number


def _counts(rows: list[tuple[str, str]], roster_div: dict[str, str]) -> dict[str, int]:
    counts = {name: 0 for name in EAST}
    for store, division in rows:
        name = east_name(roster_div.get(canon_store(store), "")) or east_name(division)
        if name:
            counts[name] += 1
    return counts


def evaluate(con: sqlite3.Connection) -> tuple[list[str], list[str]]:
    prep_rows = con.execute(
        "SELECT payload_json FROM facts WHERE section='prep_not_ready'"
    ).fetchall()
    values = [number for (raw,) in prep_rows if (number := _pnr(raw)) is not None]
    n = len(values)
    eq100 = sum(1 for number in values if abs(number - 100.0) < 0.001)
    mean = (sum(values) / n) if n else None
    pct100 = (100.0 * eq100 / n) if n else 0.0
    mean_text = "n/a" if mean is None else f"{mean:.4f}"
    report = [
        f"prep_not_ready n={n} mean={mean_text} eq100={eq100} pct100={pct100:.2f}"
    ]
    failures: list[str] = []
    if mean is not None and mean > PREP_MEAN_MAX:
        failures.append(
            f"Soft FAIL: prep_not_ready mean {mean:.4f} > {PREP_MEAN_MAX:g} (n={n} eq100={eq100})"
        )
    if n and eq100 * 2 >= n:
        failures.append(
            f"Soft FAIL: prep_not_ready {pct100:.2f}% of rows == 100 (eq100={eq100}/n={n})"
        )

    roster = con.execute(
        "SELECT store_number, COALESCE(division,'') FROM facts WHERE section='store_roster'"
    ).fetchall()
    dynacap = con.execute(
        "SELECT store_number, COALESCE(division,'') FROM facts WHERE section='dynacap'"
    ).fetchall()
    roster_div = {canon_store(store): division for store, division in roster if canon_store(store)}
    roster_east = _counts(roster, roster_div)
    dynacap_east = _counts(dynacap, roster_div)
    roster_total = sum(roster_east.values())
    dynacap_total = sum(dynacap_east.values())
    roster_names = [name for name in EAST if roster_east[name]]
    report.append(
        "roster_east "
        + " ".join(f"{name}={roster_east[name]}" for name in EAST)
        + f" total={roster_total} divisions={','.join(roster_names) or 'none'}"
    )
    report.append(
        "dynacap_east "
        + " ".join(f"{name}={dynacap_east[name]}" for name in EAST)
        + f" total={dynacap_total}"
    )
    if roster_names and dynacap_total == 0:
        failures.append(
            "Soft FAIL: dynacap East hole — Jewel+Mid-Atlantic+Shaws dynacap=0 "
            f"while roster has those divisions (roster_east={roster_total}: {', '.join(roster_names)}). "
            "Not inventing East rows."
        )
    return report, failures


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"Usage: {sys.argv[0]} <current.sqlite>")
    path = sys.argv[1]
    if not Path(path).is_file():
        raise SystemExit(f"Missing pack {path}")
    con = sqlite3.connect(path)
    try:
        report, failures = evaluate(con)
    finally:
        con.close()
    for line in report:
        print(line)
    if failures:
        for line in failures:
            print(line, file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
