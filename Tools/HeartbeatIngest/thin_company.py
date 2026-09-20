#!/usr/bin/env python3
"""Thin a cooked Heartbeat market sqlite into a company seat ≤40MB.

Keeps picker_scorecard facts (slim payloads). Drops pre_sub_oos_item.
Stamps pick_path_picker store from scorecard. Roster overwrites leftover
sheet identity (Loss First DIVISION=Haggen). Drops Applied-filters garbage.
Never touches a needs_attention column — facts has none.
"""
from __future__ import annotations

import json
import os
import sqlite3
import sys
import uuid

COMPANY_SEAT_MAX = 40_000_000

SCORECARD_KEEP = (
    "pph",
    "presub_pct",
    "oos_pct",
    "pick_hours",
    "subs",
    "orders",
    "qty_ordered",
    "dug_orders",
    "oth_elig_pct",
    "oth_eligible_orders",
    "oth5_pct",
    "ott_pct",
    "refund_amt",
    "coe_pct",
    "pph_picks",
)
SCORECARD_OPTIONAL = (
    "qty_ordered",
    "dug_orders",
    "oth_elig_pct",
    "oth_eligible_orders",
    "refund_amt",
    "coe_pct",
    "pph_picks",
)
SCORECARD_TEXT = ("shopper_id", "shopper_name", "employee_alternate_id", "district", "data_window")
PATH_KEEP = ("compliance_pct", "orders", "pph")


def canon_store(raw: str) -> str:
    text = (raw or "").strip()
    if "|" in text:
        text = text.split("|", 1)[0].strip()
    if text.isdigit():
        return str(int(text))
    try:
        value = float(text.replace(",", ""))
        if 0 < value < 1_000_000 and value == round(value):
            return str(int(value))
    except ValueError:
        pass
    digits = "".join(ch for ch in text if ch.isdigit())
    if digits and len(digits) <= 6:
        return str(int(digits))
    return text


def is_garbage_store(raw: str) -> bool:
    text = (raw or "").strip()
    if not text:
        return False
    lower = text.lower()
    if lower.startswith("applied") or "applied filters" in lower:
        return True
    if "relative_week" in lower or "is_opp_store" in lower:
        return True
    if "\n" in text or "\r" in text:
        return True
    return False


def load_json(raw: str) -> dict:
    try:
        value = json.loads(raw or "{}")
    except Exception:
        return {}
    return value if isinstance(value, dict) else {}


def slim_payload(payload: dict, keep: tuple[str, ...]) -> dict:
    return {key: payload[key] for key in keep if key in payload and payload[key] is not None}


def slim_text(text: dict, keep: tuple[str, ...]) -> dict:
    out = {}
    for key in keep:
        value = text.get(key)
        if isinstance(value, str) and value.strip():
            out[key] = value.strip()
    return out


def roster_by_store(con: sqlite3.Connection) -> dict[str, tuple[str, str, str, str]]:
    roster = {}
    for store, division, om, name, text_json in con.execute(
        "SELECT store_number, division, operations_om, store_name, text_json FROM facts WHERE section='store_roster'"
    ):
        store = canon_store(store)
        if not store or is_garbage_store(store):
            continue
        text = load_json(text_json)
        roster[store] = (
            (division or "").strip(),
            (om or "").strip(),
            (text.get("district") or "").strip(),
            (name or "").strip(),
        )
    return roster


def counts(con: sqlite3.Connection) -> list[tuple[str, int]]:
    return con.execute("SELECT section, COUNT(*) FROM facts GROUP BY 1 ORDER BY 1").fetchall()


def print_qc(con: sqlite3.Connection, label: str) -> dict[str, int]:
    by_section = {section: n for section, n in counts(con)}
    print(f"{label} {counts(con)}")
    roster = {canon_store(s) for (s,) in con.execute(
        "SELECT store_number FROM facts WHERE section='store_roster'"
    ) if canon_store(s)}
    loss_divs = con.execute(
        "SELECT COALESCE(division,''), COUNT(*) FROM facts WHERE section='lost_revenue' GROUP BY 1 ORDER BY 2 DESC"
    ).fetchall()
    print(f"{label} lost_revenue divisions {loss_divs}")
    print(f"{label} lost_revenue blank_om", con.execute(
        "SELECT COUNT(*) FROM facts WHERE section='lost_revenue' AND TRIM(COALESCE(operations_om,''))=''"
    ).fetchone()[0])
    prep_divs = con.execute(
        "SELECT COALESCE(division,''), COUNT(*) FROM facts WHERE section='prep_not_ready' GROUP BY 1 ORDER BY 2 DESC"
    ).fetchall()
    print(f"{label} prep_not_ready divisions {prep_divs}")
    five_stores = {canon_store(s) for (s,) in con.execute(
        "SELECT store_number FROM facts WHERE section='five_star'"
    ) if canon_store(s)}
    print(f"{label} five_star stores {len(five_stores)} roster_missing {len(roster - five_stores)}")
    print(f"{label} picker_scorecard {by_section.get('picker_scorecard', 0)}")
    garbage = con.execute(
        "SELECT COUNT(*) FROM facts WHERE store_number LIKE 'Applied%' OR store_number LIKE '%applied filters%'"
    ).fetchone()[0]
    print(f"{label} garbage_filter_rows {garbage}")
    return by_section


def thin(path: str) -> None:
    con = sqlite3.connect(path)
    con.isolation_level = None
    print("before_bytes", os.path.getsize(path))
    before = print_qc(con, "before")

    roster = roster_by_store(con)
    if len(roster) < 200:
        raise SystemExit("Soft FAIL: store_roster too small to stamp company identity")
    picker_n = con.execute("SELECT COUNT(*) FROM facts WHERE section='picker_scorecard'").fetchone()[0]
    if picker_n < 1000:
        raise SystemExit(
            f"Soft FAIL: picker_scorecard count is {picker_n} before thin — refusing to wipe Path Picker or publish without ScoreCard facts"
        )

    stores_by: dict[str, set[str]] = {}
    for store, text_json in con.execute(
        "SELECT store_number, text_json FROM facts WHERE section='picker_scorecard'"
    ):
        store = canon_store(store)
        if not store or is_garbage_store(store):
            continue
        text = load_json(text_json)
        for key in ("shopper_id", "shopper_name", "employee_alternate_id"):
            alias = (text.get(key) or "").strip().upper()
            if alias:
                stores_by.setdefault(alias, set()).add(store)

    stamped = []
    for row in con.execute(
        "SELECT division, operations_om, store_name, recorded_on, payload_json, text_json "
        "FROM facts WHERE section='pick_path_picker'"
    ):
        division, om, store_name, recorded_on, payload_json, text_json = row
        text = load_json(text_json)
        payload = load_json(payload_json)
        slim_p = slim_payload(payload, PATH_KEEP)
        ldap = (text.get("shopper_id") or text.get("shopper_name") or text.get("employee_alternate_id") or "").strip().upper()
        slim_t = {"shopper_id": ldap, "shopper_name": text.get("shopper_name") or ldap}
        targets = sorted(stores_by.get(ldap, []))
        if not targets:
            continue
        for store in targets:
            ident = roster.get(store)
            stamped.append(
                (
                    str(uuid.uuid4()).upper(),
                    "pick_path_picker",
                    store,
                    (ident[0] if ident and ident[0] else division) or "",
                    (ident[1] if ident and ident[1] else om) or "",
                    store_name,
                    recorded_on,
                    json.dumps(slim_p, separators=(",", ":")),
                    json.dumps(slim_t, separators=(",", ":")),
                )
            )

    con.execute("BEGIN")
    # Keep picker_scorecard. Drop item grain only. Replace path picker with slim stamps.
    con.execute("DELETE FROM facts WHERE section IN ('pre_sub_oos_item','pick_path_picker')")
    if stamped:
        con.executemany(
            "INSERT INTO facts (id, section, store_number, division, operations_om, store_name, recorded_on, payload_json, text_json) "
            "VALUES (?,?,?,?,?,?,?,?,?)",
            stamped,
        )

    scorecard_rows = list(con.execute(
        "SELECT id, store_number, division, operations_om, store_name, payload_json, text_json "
        "FROM facts WHERE section='picker_scorecard'"
    ))
    for row_id, store, division, om, name, payload_json, text_json in scorecard_rows:
        if is_garbage_store(store):
            con.execute("DELETE FROM facts WHERE id=?", (row_id,))
            continue
        payload = slim_payload(load_json(payload_json), SCORECARD_KEEP)
        text = slim_text(load_json(text_json), SCORECARD_TEXT)
        ldap = (text.get("shopper_id") or text.get("shopper_name") or text.get("employee_alternate_id") or "").strip().upper()
        if ldap:
            text["shopper_id"] = ldap
            text.setdefault("shopper_name", ldap)
        ident = roster.get(canon_store(store))
        new_div = ident[0] if ident and ident[0] else (division or "")
        new_om = ident[1] if ident and ident[1] else (om or "")
        if ident and ident[2] and "district" not in text:
            text["district"] = ident[2]
        con.execute(
            "UPDATE facts SET division=?, operations_om=?, store_name=?, payload_json=?, text_json=? WHERE id=?",
            (
                new_div,
                new_om,
                name or (ident[3] if ident else None),
                json.dumps(payload, separators=(",", ":")),
                json.dumps(text, separators=(",", ":")),
                row_id,
            ),
        )

    # Authoritative roster stamp + drop leftover filter-text facts.
    for row_id, section, store, division, om, name, text_json in con.execute(
        "SELECT id, section, store_number, division, operations_om, store_name, text_json FROM facts"
    ):
        if is_garbage_store(store) or (name and is_garbage_store(name)):
            con.execute("DELETE FROM facts WHERE id=?", (row_id,))
            continue
        if section == "store_roster":
            continue
        ident = roster.get(canon_store(store))
        if not ident:
            continue
        text = load_json(text_json)
        if ident[2] and not (text.get("district") or "").strip():
            text["district"] = ident[2]
        con.execute(
            "UPDATE facts SET division=?, operations_om=?, store_name=?, text_json=? WHERE id=?",
            (
                ident[0] or division or "",
                ident[1] or om or "",
                name or ident[3] or None,
                json.dumps(text, separators=(",", ":")),
                row_id,
            ),
        )

    picker_n = con.execute("SELECT COUNT(*) FROM facts WHERE section='picker_scorecard'").fetchone()[0]
    path_n = con.execute("SELECT COUNT(*) FROM facts WHERE section='pick_path_picker'").fetchone()[0]
    aisle_n = con.execute("SELECT COUNT(*) FROM facts WHERE section='aisle_mapper'").fetchone()[0]
    loss_divs = con.execute(
        "SELECT COUNT(DISTINCT division) FROM facts WHERE section='lost_revenue' AND TRIM(COALESCE(division,''))!=''"
    ).fetchone()[0]
    if picker_n < 1000:
        raise SystemExit(f"Soft FAIL: picker_scorecard count is {picker_n} after thin — refusing LIVE without ScoreCard facts")
    if path_n < 1:
        raise SystemExit("Soft FAIL: pick_path_picker count is 0 after thin — refusing LIVE without shoppers")
    if aisle_n < 1:
        raise SystemExit("Soft FAIL: aisle_mapper missing after thin")
    if loss_divs < 5:
        raise SystemExit(f"Soft FAIL: lost_revenue only {loss_divs} division(s) after roster stamp")

    meta = {s: str(n) for s, n in con.execute("SELECT section, COUNT(*) FROM facts GROUP BY 1")}
    con.execute("UPDATE pack_meta SET counts_json=?", (json.dumps(meta, separators=(",", ":")),))
    con.execute("COMMIT")
    con.execute("VACUUM")
    con.close()

    after_bytes = os.path.getsize(path)
    print("after_bytes", after_bytes)
    if after_bytes > COMPANY_SEAT_MAX:
        print("over_cap_trimming_optional_scorecard_keys", SCORECARD_OPTIONAL)
        trim_optional_scorecard(path)
        after_bytes = os.path.getsize(path)
        print("after_trim_bytes", after_bytes)
    after_con = sqlite3.connect(path)
    after = print_qc(after_con, "after")
    after_con.close()
    print("pick_path_picker", path_n, "picker_scorecard", picker_n, "aisle_mapper", aisle_n)
    if after_bytes > COMPANY_SEAT_MAX:
        raise SystemExit(f"Soft FAIL: thin still too large ({after_bytes}) — company seat cap {COMPANY_SEAT_MAX}")
    if after.get("picker_scorecard", 0) < 1000:
        raise SystemExit("Soft FAIL: picker_scorecard missing after vacuum")
    print("thin", after_bytes)


def trim_optional_scorecard(path: str) -> None:
    con = sqlite3.connect(path)
    con.isolation_level = None
    con.execute("BEGIN")
    for row_id, payload_json in con.execute(
        "SELECT id, payload_json FROM facts WHERE section='picker_scorecard'"
    ):
        payload = slim_payload(load_json(payload_json), SCORECARD_KEEP)
        for key in SCORECARD_OPTIONAL:
            payload.pop(key, None)
        con.execute(
            "UPDATE facts SET payload_json=? WHERE id=?",
            (json.dumps(payload, separators=(",", ":")), row_id),
        )
    con.execute("COMMIT")
    con.execute("VACUUM")
    con.close()


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"Usage: {sys.argv[0]} <current.sqlite>")
    path = sys.argv[1]
    if not os.path.isfile(path):
        raise SystemExit(f"Missing pack {path}")
    thin(path)


if __name__ == "__main__":
    main()
