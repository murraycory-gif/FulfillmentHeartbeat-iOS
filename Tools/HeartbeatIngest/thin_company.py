#!/usr/bin/env python3
"""Thin a cooked Heartbeat market sqlite into a company seat ≤40MB.

KEEP ranked:
  K1 sales / roster / chrome plane
  K2 slim picker_scorecard FACTS (~2–5MB) — Soft FAIL if chrome cites shoppers and facts are 0
  K3 Loss facts + roster bind — Soft FAIL Haggen-only / blank Ops/OM
  K4 other store grains (Prep / 5★) — stamp identity where Excel/roster allows
  K5 optional slim pick_path_picker (in-place / store-peek-only). Never explode shopper×store.
     Soft KEEP store_number from Excel or ScoreCard LDAP grain. Soft FAIL empty store
     when LDAP/store grain exists. Do not invent stores for Path shoppers with no grain.

DROP:
  D1 pre_sub_oos_item item tape
  D2 fat shopper payloads beyond slim ScoreCard
  D3 market ~56MB as company hub (>40MB Soft FAIL)
  D4 orphan chrome citing shoppers with zero ScoreCard facts

Never touches needs_attention — facts has no such column.
Cook/thin only. Do not conflate into tip 439 iOS paint.
"""
from __future__ import annotations

import json
import os
import sqlite3
import sys

COMPANY_SEAT_MAX = 40_000_000
SCORECARD_MIN = 1000

# K2 core ScoreCard page. Keep small so slim facts land in the ~13.6MB headroom.
SCORECARD_KEEP = (
    "pph",
    "presub_pct",
    "oos_pct",
    "pick_hours",
    "subs",
    "orders",
    "ott_pct",
    "oth5_pct",
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


def canon_ldap(raw: str) -> str:
    return "".join(ch for ch in (raw or "").strip().upper() if ch.isalnum())


def ldap_aliases(text: dict) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for key in ("shopper_id", "shopper_name", "employee_alternate_id"):
        alias = canon_ldap(str(text.get(key) or ""))
        if alias and alias not in seen:
            seen.add(alias)
            out.append(alias)
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


def chrome_shoppers(con: sqlite3.Connection) -> int:
    try:
        raw = con.execute("SELECT json FROM dash_chrome WHERE id=1").fetchone()
    except sqlite3.Error:
        return 0
    if not raw:
        return 0
    data = load_json(raw[0])
    try:
        return int(data.get("pickerShoppers") or 0)
    except (TypeError, ValueError):
        return 0


def print_qc(con: sqlite3.Connection, label: str) -> dict[str, int]:
    by_section = {section: n for section, n in counts(con)}
    print(f"{label} {counts(con)}")
    roster = {
        canon_store(s)
        for (s,) in con.execute("SELECT store_number FROM facts WHERE section='store_roster'")
        if canon_store(s)
    }
    loss_divs = con.execute(
        "SELECT COALESCE(division,''), COUNT(*) FROM facts WHERE section='lost_revenue' GROUP BY 1 ORDER BY 2 DESC"
    ).fetchall()
    print(f"{label} lost_revenue divisions {loss_divs}")
    print(
        f"{label} lost_revenue blank_om",
        con.execute(
            "SELECT COUNT(*) FROM facts WHERE section='lost_revenue' AND TRIM(COALESCE(operations_om,''))= ''"
        ).fetchone()[0],
    )
    prep_divs = con.execute(
        "SELECT COALESCE(division,''), COUNT(*) FROM facts WHERE section='prep_not_ready' GROUP BY 1 ORDER BY 2 DESC"
    ).fetchall()
    print(f"{label} prep_not_ready divisions {prep_divs}")
    five_stores = {
        canon_store(s)
        for (s,) in con.execute("SELECT store_number FROM facts WHERE section='five_star'")
        if canon_store(s)
    }
    missing_five = sorted(roster - five_stores)
    print(f"{label} five_star stores {len(five_stores)} roster_missing_n {len(missing_five)} sample {missing_five[:12]}")
    print(f"{label} picker_scorecard {by_section.get('picker_scorecard', 0)}")
    print(f"{label} chrome_pickerShoppers {chrome_shoppers(con)}")
    path_n = by_section.get("pick_path_picker", 0)
    path_bound = con.execute(
        "SELECT COUNT(*) FROM facts WHERE section='pick_path_picker' AND TRIM(COALESCE(store_number,''))!=''"
    ).fetchone()[0]
    print(f"{label} pick_path_picker {path_n} store_bound {path_bound}")
    garbage = con.execute(
        "SELECT COUNT(*) FROM facts WHERE store_number LIKE 'Applied%' OR store_number LIKE '%applied filters%'"
    ).fetchone()[0]
    print(f"{label} garbage_filter_rows {garbage}")
    return by_section


def refuse_orphan_chrome(con: sqlite3.Connection, scorecard_n: int) -> None:
    cited = chrome_shoppers(con)
    if cited > 0 and scorecard_n < 1:
        raise SystemExit(
            f"Soft FAIL: orphan chrome cites {cited} shoppers with {scorecard_n} picker_scorecard facts (D4)"
        )


def refuse_loss_bind(con: sqlite3.Connection) -> None:
    loss_n = con.execute(
        "SELECT COUNT(*) FROM facts WHERE section='lost_revenue' AND TRIM(store_number)!=''"
    ).fetchone()[0]
    if loss_n < 200:
        return
    divs = con.execute(
        "SELECT COUNT(DISTINCT division) FROM facts WHERE section='lost_revenue' AND TRIM(COALESCE(division,''))!=''"
    ).fetchone()[0]
    if divs < 5:
        raise SystemExit(f"Soft FAIL: lost_revenue only {divs} division(s) after roster stamp (K3 Haggen-only)")
    blank_om = con.execute(
        "SELECT COUNT(*) FROM facts WHERE section='lost_revenue' AND TRIM(COALESCE(operations_om,''))=''"
    ).fetchone()[0]
    if blank_om * 2 > loss_n:
        raise SystemExit(f"Soft FAIL: lost_revenue Ops/OM blank on {blank_om}/{loss_n} after roster stamp (K3)")


def scorecard_store_by_ldap(con: sqlite3.Connection) -> dict[str, str]:
    """LDAP alias → one ScoreCard store. Multi-store shoppers stay in-place (highest orders)."""
    best: dict[str, tuple[str, float]] = {}
    for store, payload_json, text_json in con.execute(
        "SELECT store_number, payload_json, text_json FROM facts WHERE section='picker_scorecard'"
    ):
        store = canon_store(store)
        if not store or is_garbage_store(store):
            continue
        payload = load_json(payload_json)
        try:
            orders = float(payload.get("orders") or 0)
        except (TypeError, ValueError):
            orders = 0.0
        for alias in ldap_aliases(load_json(text_json)):
            prev = best.get(alias)
            if prev is None or orders > prev[1]:
                best[alias] = (store, orders)
    return {alias: store for alias, (store, _) in best.items()}


def stamp_path_picker_stores(
    con: sqlite3.Connection,
    stores_by_ldap: dict[str, str],
    roster: dict[str, tuple[str, str, str, str]],
) -> int:
    """In-place Soft KEEP: Excel store wins; else ScoreCard LDAP grain. Never explode shopper×store."""
    stamped = 0
    rows = list(
        con.execute(
            "SELECT id, store_number, text_json FROM facts WHERE section='pick_path_picker'"
        )
    )
    for row_id, store, text_json in rows:
        existing = canon_store(store)
        if existing and not is_garbage_store(existing):
            continue
        mapped = ""
        for alias in ldap_aliases(load_json(text_json)):
            mapped = stores_by_ldap.get(alias) or ""
            if mapped:
                break
        if not mapped:
            continue
        ident = roster.get(mapped)
        text = load_json(text_json)
        if ident and ident[2] and not (text.get("district") or "").strip():
            text["district"] = ident[2]
        con.execute(
            "UPDATE facts SET store_number=?, division=?, operations_om=?, store_name=?, text_json=? WHERE id=?",
            (
                mapped,
                (ident[0] if ident else "") or "",
                (ident[1] if ident else "") or "",
                (ident[3] if ident else "") or None,
                json.dumps(text, separators=(",", ":")),
                row_id,
            ),
        )
        stamped += 1
    print("stamp_pick_path_picker_store", stamped)
    return stamped


def refuse_path_store_bind(con: sqlite3.Connection, stores_by_ldap: dict[str, str]) -> None:
    path_n = con.execute("SELECT COUNT(*) FROM facts WHERE section='pick_path_picker'").fetchone()[0]
    if path_n < 1:
        return
    if not stores_by_ldap:
        return
    blank = 0
    for store, text_json in con.execute(
        "SELECT store_number, text_json FROM facts WHERE section='pick_path_picker'"
    ):
        if canon_store(store) and not is_garbage_store(store):
            continue
        if any(alias in stores_by_ldap for alias in ldap_aliases(load_json(text_json))):
            blank += 1
    if blank:
        raise SystemExit(
            f"Soft FAIL: pick_path_picker store_number empty on {blank}/{path_n} LDAP rows with ScoreCard store grain (K5)"
        )


def slim_section(con: sqlite3.Connection, section: str, keep: tuple[str, ...], text_keep: tuple[str, ...]) -> None:
    rows = list(
        con.execute(
            "SELECT id, payload_json, text_json FROM facts WHERE section=?",
            (section,),
        )
    )
    for row_id, payload_json, text_json in rows:
        payload = slim_payload(load_json(payload_json), keep)
        text = slim_text(load_json(text_json), text_keep)
        if section == "picker_scorecard":
            ldap = (
                text.get("shopper_id") or text.get("shopper_name") or text.get("employee_alternate_id") or ""
            ).strip().upper()
            if ldap:
                text["shopper_id"] = ldap
                text.setdefault("shopper_name", ldap)
        con.execute(
            "UPDATE facts SET payload_json=?, text_json=? WHERE id=?",
            (json.dumps(payload, separators=(",", ":")), json.dumps(text, separators=(",", ":")), row_id),
        )


def stamp_roster(con: sqlite3.Connection, roster: dict[str, tuple[str, str, str, str]]) -> None:
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


def drop_section(con: sqlite3.Connection, section: str) -> int:
    n = con.execute("SELECT COUNT(*) FROM facts WHERE section=?", (section,)).fetchone()[0]
    if n:
        con.execute("DELETE FROM facts WHERE section=?", (section,))
    return n


def refresh_meta(con: sqlite3.Connection) -> None:
    meta = {s: str(n) for s, n in con.execute("SELECT section, COUNT(*) FROM facts GROUP BY 1")}
    con.execute("UPDATE pack_meta SET counts_json=?", (json.dumps(meta, separators=(",", ":")),))


def thin(path: str) -> None:
    con = sqlite3.connect(path)
    con.isolation_level = None
    print("before_bytes", os.path.getsize(path))
    print_qc(con, "before")

    roster = roster_by_store(con)
    if len(roster) < 200:
        raise SystemExit("Soft FAIL: store_roster too small to stamp company identity (K1)")
    picker_n = con.execute("SELECT COUNT(*) FROM facts WHERE section='picker_scorecard'").fetchone()[0]
    refuse_orphan_chrome(con, picker_n)
    if picker_n < SCORECARD_MIN:
        raise SystemExit(
            f"Soft FAIL: picker_scorecard count is {picker_n} — refusing thin that would publish chrome-only ScoreCard (K2/D4)"
        )

    con.execute("BEGIN")
    dropped_item = drop_section(con, "pre_sub_oos_item")
    print("drop_pre_sub_oos_item", dropped_item)

    slim_section(con, "picker_scorecard", SCORECARD_KEEP, SCORECARD_TEXT)
    slim_section(con, "pick_path_picker", PATH_KEEP, ("shopper_id", "shopper_name", "employee_alternate_id"))
    stores_by_ldap = scorecard_store_by_ldap(con)
    stamp_path_picker_stores(con, stores_by_ldap, roster)
    stamp_roster(con, roster)

    picker_n = con.execute("SELECT COUNT(*) FROM facts WHERE section='picker_scorecard'").fetchone()[0]
    if picker_n < SCORECARD_MIN:
        raise SystemExit(f"Soft FAIL: picker_scorecard count is {picker_n} after slim (K2)")
    refuse_orphan_chrome(con, picker_n)
    refuse_loss_bind(con)
    refuse_path_store_bind(con, stores_by_ldap)
    refresh_meta(con)
    con.execute("COMMIT")
    con.execute("VACUUM")
    con.close()

    after_bytes = os.path.getsize(path)
    print("after_bytes", after_bytes)

    # K5 is optional. If the company seat still blows 40MB, drop path picker (store-peek via ScoreCard).
    if after_bytes > COMPANY_SEAT_MAX:
        print("over_cap_dropping_optional_pick_path_picker (K5)")
        con = sqlite3.connect(path)
        con.isolation_level = None
        con.execute("BEGIN")
        dropped = drop_section(con, "pick_path_picker")
        print("drop_pick_path_picker", dropped)
        picker_n = con.execute("SELECT COUNT(*) FROM facts WHERE section='picker_scorecard'").fetchone()[0]
        refuse_orphan_chrome(con, picker_n)
        refuse_loss_bind(con)
        refuse_path_store_bind(con, scorecard_store_by_ldap(con))
        refresh_meta(con)
        con.execute("COMMIT")
        con.execute("VACUUM")
        con.close()
        after_bytes = os.path.getsize(path)
        print("after_k5_drop_bytes", after_bytes)

    after_con = sqlite3.connect(path)
    after = print_qc(after_con, "after")
    path_n = after.get("pick_path_picker", 0)
    picker_n = after.get("picker_scorecard", 0)
    refuse_orphan_chrome(after_con, picker_n)
    refuse_loss_bind(after_con)
    refuse_path_store_bind(after_con, scorecard_store_by_ldap(after_con))
    after_con.close()
    print("pick_path_picker", path_n, "picker_scorecard", picker_n)
    if after_bytes > COMPANY_SEAT_MAX:
        raise SystemExit(f"Soft FAIL: thin still too large ({after_bytes}) — company seat cap {COMPANY_SEAT_MAX} (D3)")
    if picker_n < SCORECARD_MIN:
        raise SystemExit("Soft FAIL: picker_scorecard missing after vacuum (K2)")
    print("thin", after_bytes)


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"Usage: {sys.argv[0]} <current.sqlite>")
    path = sys.argv[1]
    if not os.path.isfile(path):
        raise SystemExit(f"Missing pack {path}")
    thin(path)


if __name__ == "__main__":
    main()
