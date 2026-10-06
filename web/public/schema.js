// Bump this when home.json gains a key the page reads.
// An older pack still loads, and the page warns.
export const SCHEMA_VERSION = 1;

// Sheet Total-row cells a cook with cookedAt must carry on home.workbookTotal.
// The pinned live cook has no cookedAt and does not carry these fields.
// Values are the source cells. Rates stay fractions when the sheet stores fractions.
export const WORKBOOK_TOTAL_FIELDS = {
  sales: ["sales_dollars", "yoy_pct", "orders_yoy_pct"],
  lost_revenue: ["ecomm_dollars", "lost_dollars", "post_sub_dollars", "refund_dollars", "missed_dollars", "cancel_dollars", "kill_dollars"],
  labor: ["schedule_efficiency_pct", "act_cost_dollars", "cost_trgt_pct", "uplh_impact_pct", "wage_impact_pct", "aiv_impact_pct", "act_cost_pct", "target_vs_actual_pct"],
  missing_items: ["missing_rate"],
  pre_sub_oos: ["pre_sub_rate"],
  schedule_quality: ["schedule_efficiency_pct", "under_schedule_pct", "over_schedule_pct", "staffing_efficiency_pct"],
  pick_path: ["compliance_pct", "pph"],
  dynacap: ["pieces_per_hour", "utilization_pct"],
  pph: ["pph"],
};

export function schemaWarning(home) {
  const version = home && home.metadata ? home.metadata.schemaVersion : undefined;
  if (typeof version === "number" && version >= SCHEMA_VERSION) return "";
  const shown = typeof version === "number" ? String(version) : "missing";
  return `This pack is schema ${shown}. This page expects schema ${SCHEMA_VERSION}.`;
}
