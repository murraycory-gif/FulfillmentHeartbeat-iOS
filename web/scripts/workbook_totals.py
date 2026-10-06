#!/usr/bin/env python3
"""Read each sheet Total row into home.workbookTotal.

The cells are the workbook source values. A percent stored as a fraction
stays a fraction. PPH's company total is the row whose column A is Total.
"""

from __future__ import annotations

import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
CELL = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}c"
ROW = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}row"
VALUE = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}v"

# section -> sheet, fixed Total row, field -> column. pph finds column A == Total.
TOTALS = {
    "sales": {
        "sheet": "Sales",
        "row": 2863,
        "fields": {"sales_dollars": "CH", "yoy_pct": "CI", "orders_yoy_pct": "CK"},
    },
    "lost_revenue": {
        "sheet": "Loss Revenue",
        "row": 2169,
        "fields": {
            "ecomm_dollars": "C",
            "lost_dollars": "D",
            "post_sub_dollars": "J",
            "refund_dollars": "M",
            "missed_dollars": "V",
            "cancel_dollars": "Y",
            "kill_dollars": "AC",
        },
    },
    "labor": {
        "sheet": "Labor",
        "row": 2171,
        "fields": {
            "schedule_efficiency_pct": "B",
            "act_cost_dollars": "I",
            "cost_trgt_pct": "J",
            "uplh_impact_pct": "K",
            "wage_impact_pct": "L",
            "aiv_impact_pct": "M",
            "act_cost_pct": "N",
            "target_vs_actual_pct": "O",
        },
    },
    "missing_items": {"sheet": "MI", "row": 2427, "fields": {"missing_rate": "U"}},
    "pre_sub_oos": {"sheet": "Pre-Sub OOS", "row": 2170, "fields": {"pre_sub_rate": "P"}},
    "schedule_quality": {
        "sheet": "Schedule Quality",
        "row": 2206,
        "fields": {
            "schedule_efficiency_pct": "D",
            "under_schedule_pct": "E",
            "over_schedule_pct": "F",
            "staffing_efficiency_pct": "J",
        },
    },
    "pick_path": {"sheet": "Pick Path", "row": 2148, "fields": {"compliance_pct": "E", "pph": "G"}},
    "dynacap": {"sheet": "Dynacap", "row": 2166, "fields": {"pieces_per_hour": "D", "utilization_pct": "G"}},
    "pph": {"sheet": "PPH", "find_total": "A", "column": "T", "field": "pph"},
}


def _col_row(ref: str) -> tuple[str, int]:
    col = ""
    row = ""
    for ch in ref:
        if ch.isalpha():
            col += ch
        else:
            row += ch
    return col, int(row) if row else 0


class WorkbookCells:
    def __init__(self, path: Path):
        self.path = Path(path)
        self.zip = zipfile.ZipFile(self.path)
        self.strings = self._shared_strings()
        self.sheets = self._sheet_paths()

    def close(self) -> None:
        self.zip.close()

    def _shared_strings(self) -> list[str]:
        root = ET.fromstring(self.zip.read("xl/sharedStrings.xml"))
        out = []
        for item in root.findall("m:si", NS):
            texts = [node.text or "" for node in item.iter("{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t")]
            out.append("".join(texts))
        return out

    def _sheet_paths(self) -> dict[str, str]:
        book = ET.fromstring(self.zip.read("xl/workbook.xml"))
        rels = ET.fromstring(self.zip.read("xl/_rels/workbook.xml.rels"))
        targets = {rel.attrib.get("Id"): rel.attrib.get("Target") for rel in rels}
        found = {}
        for sheet in book.findall("m:sheets/m:sheet", NS):
            rid = sheet.attrib.get("{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id")
            target = targets.get(rid) or ""
            if target and not target.startswith("xl/"):
                target = "xl/" + target.lstrip("/")
            found[sheet.attrib.get("name") or ""] = target
        return found

    def _cell_value(self, cell) -> str:
        kind = cell.attrib.get("t")
        node = cell.find(VALUE)
        if kind == "s" and node is not None and node.text:
            return self.strings[int(node.text)]
        if node is not None and node.text is not None:
            return node.text
        return ""

    def rows(self, sheet: str, wanted: set[int] | None = None) -> dict[int, dict[str, str]]:
        path = self.sheets.get(sheet)
        if not path:
            raise SystemExit(f"workbook total: sheet {sheet} is missing")
        out: dict[int, dict[str, str]] = {}
        with self.zip.open(path) as handle:
            for _event, elem in ET.iterparse(handle, events=("end",)):
                if elem.tag != ROW:
                    continue
                number = int(elem.attrib.get("r", "0"))
                if wanted is None or number in wanted:
                    cells = {}
                    for cell in elem.findall(CELL):
                        col, _row = _col_row(cell.attrib.get("r") or "")
                        cells[col] = self._cell_value(cell)
                    out[number] = cells
                elem.clear()
                if wanted is not None and wanted.issubset(out.keys()) and number > max(wanted):
                    break
        return out

    def column_a_total(self, sheet: str) -> tuple[int, dict[str, str]]:
        path = self.sheets.get(sheet)
        if not path:
            raise SystemExit(f"workbook total: sheet {sheet} is missing")
        with self.zip.open(path) as handle:
            for _event, elem in ET.iterparse(handle, events=("end",)):
                if elem.tag != ROW:
                    continue
                number = int(elem.attrib.get("r", "0"))
                cells = {}
                label = ""
                for cell in elem.findall(CELL):
                    col, _row = _col_row(cell.attrib.get("r") or "")
                    value = self._cell_value(cell)
                    cells[col] = value
                    if col == "A":
                        label = value
                elem.clear()
                if str(label).strip().lower() == "total":
                    return number, cells
        raise SystemExit(f"workbook total: {sheet} has no Total row in column A")


def read_workbook_totals(path: str | Path) -> dict:
    book = WorkbookCells(Path(path))
    try:
        totals = {}
        for section, spec in TOTALS.items():
            if spec.get("find_total"):
                _row, cells = book.column_a_total(spec["sheet"])
                raw = cells.get(spec["column"], "")
                totals[section] = {spec["field"]: float(raw)}
                continue
            rows = book.rows(spec["sheet"], {spec["row"]})
            cells = rows.get(spec["row"]) or {}
            label = str(cells.get("A") or "").strip().lower()
            if label != "total":
                raise SystemExit(f"workbook total: {spec['sheet']}!A{spec['row']} is {cells.get('A')!r}")
            fields = {}
            for name, col in spec["fields"].items():
                raw = cells.get(col, "")
                if raw == "":
                    raise SystemExit(f"workbook total: {spec['sheet']}!{col}{spec['row']} is blank")
                fields[name] = float(raw)
            totals[section] = fields
        return totals
    finally:
        book.close()


def labor_store_ids(path: str | Path) -> list[str]:
    """Store numbers on the Labor sheet, including two-digit ids."""
    book = WorkbookCells(Path(path))
    try:
        path_xml = book.sheets.get("Labor")
        if not path_xml:
            raise SystemExit("workbook total: Labor sheet is missing")
        stores = []
        with book.zip.open(path_xml) as handle:
            for _event, elem in ET.iterparse(handle, events=("end",)):
                if elem.tag != CELL:
                    if elem.tag == ROW:
                        elem.clear()
                    continue
                ref = elem.attrib.get("r") or ""
                col, row = _col_row(ref)
                if col == "A" and row > 1:
                    value = str(book._cell_value(elem)).strip()
                    if value.isdigit() and not (200_000 <= int(value) < 210_000):
                        stores.append(value)
                if elem.tag == CELL and col != "A":
                    elem.clear()
        return stores
    finally:
        book.close()
