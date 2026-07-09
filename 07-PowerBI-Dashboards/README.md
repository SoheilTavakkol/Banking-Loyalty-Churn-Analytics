# Power BI Dashboards

This folder contains the final reporting layer of the project: a single Power BI file with three audience-specific dashboard pages, all connected live to the `BankingLoyaltyChurn` SSAS Tabular model.

**Status:** ✅ Complete — Executive, Marketing, and CRM & Retention pages delivered inside one `.pbix`. The originally planned Analyst page was descoped (see [Descoped Scope](#descoped-scope) below).

---

## Folder Contents

```
07-PowerBI-Dashboards/
├── Banking-Loyalty-Churn-Dashboards.pbix
├── README.md
└── screenshots/
    ├── executive-dashboard.png
    ├── marketing-dashboard.png
    └── crm-dashboard.png
```

**One `.pbix`, three pages.** The file opens to a common left-hand navigation pane ("Banking Analytics") with three links — Executive Dashboard, Marketing Dashboard, CRM Dashboard — that jump between report pages inside the same file. This isn't three separate deliverables; it's one report with a page per audience, which is why the DAX measures, slicers, and theme are shared and consistent across all three (see [Common Design Patterns](#common-design-patterns-across-all-three-pages) below).

---

## ⚠️ Before You Open the `.pbix` File

The report uses a **Live Connection** to the SSAS Tabular model (`BankingLoyaltyChurn`) — no data is imported or stored inside the `.pbix` file itself. This keeps the file small, but it also means:

- It will **not** show any data until pointed at a running instance of the SSAS model (see [06-SSAS-Tabular](../06-SSAS-Tabular/))
- To open it against your own SQL Server / SSAS instance: **Home → Transform Data → Data Source Settings → Change Source**, and update the server name from `localhost\SSAS_Tabular` to your instance
- If you don't have SSAS running, use the screenshots in `screenshots/` below to see the delivered result — that's exactly what the reader sees when this repo is browsed on GitHub, since GitHub can't render `.pbix` files at all

---

## Page 1 — Executive Dashboard

**Audience:** CEO, CFO, Board — designed for sub-10-second comprehension, no filtering required.

![Executive Dashboard](screenshots/executive-dashboard.png)

| Level | Visuals |
|---|---|
| **1 — KPI Cards** | Total Customers (831.6K) · Active Customers (692.3K) · Avg Loyalty Score (3.2) · Churn Rate (15.76%) · Avg Transaction Amount (₹5.3K) · NPS Score (29.31) — each with a sparkline and a business target |
| **2 — Trend** | Total vs. Active Customers trend (dual line) · Churn Rate vs. Loyalty Score Trend by month (combo, dual axis) · Transaction Volume vs. NPS Trend (dual line) |
| **3 — Breakdown** | Growing vs. Declining Customers by segment (diverging bar) · Complaints Distribution by segment (treemap) · Segment summary table (Customer Count, Total Transaction Amount, Trend sparkline) |

**Business targets** (shown alongside each KPI card): Total Customers 900K · Churn Rate 10% · Avg Loyalty Score 4.0 · Avg Transaction Amount 5,100 · NPS Score 40 · Active Customers 720K.

**Filters:** Year / Month slicers (top right). KPI cards always resolve to the latest available data month regardless of slicer state, via the `[_LastDataDateKey]` anchoring pattern in the SSAS model.

---

## Page 2 — Marketing Dashboard

**Audience:** Marketing team, Regional Managers — organized around the customer lifecycle funnel (Acquisition → Nurture/Conversion → Win-Back).

![Marketing Dashboard](screenshots/marketing-dashboard.png)

| Level | Visuals |
|---|---|
| **1 — KPI Cards** (3 columns, by lifecycle stage) | *Acquisition:* New Customers (55.4K), New Customer Retention Rate (95.25%) · *Nurture:* Potential Loyalists (82.2K), Loyal Conversion Rate (41.53%) · *Win-Back:* Hibernating Customers (33.03K), Hibernating Rate (3.97%) |
| **2 — Trend** | New Customers by State (donut) · Potential Volume & Conversion Rate (combo: Potential Loyalists bar + Loyal Conversion Rate line) · Hibernating Rate Trend (area) |
| **3 — Breakdown** | Loyal Conversions by State (donut) · Potential → Loyal Funnel (82K → 34K, 41.5%) · Hibernating Customers by State (horizontal bar) |

**Note:** the state-level breakdowns on this dashboard (New Customers by State, Loyal Conversions by State, Hibernating Customers by State) are where the originally-planned standalone "Geographic Dashboard" ended up — see [06-SSAS-Tabular/README.md](../06-SSAS-Tabular/README.md#dashboard-mapping--as-actually-delivered-phase-7). Since `Dim_Location[State]` is ~99.7% "Unknown" outside the 23 enriched major cities, these visuals show the top populated states plus an implicit "Other" bucket rather than filtering unknowns out entirely.

**Filters:** Year / Month slicers (top right).

---

## Page 3 — CRM & Retention Dashboard

**Audience:** Head of Retail, CRM Manager — focused on churn early-warning signals, complaint patterns, and geographic risk concentration.

![CRM Dashboard](screenshots/crm-dashboard.png)

| Level | Visuals |
|---|---|
| **1 — KPI Cards** | Total Customers (831.6K) · Churn Rate % (15.76%) · Avg NPS (29.3) · Hibernating Customers (33.0K) · Total Complaints (106.7K) · Complaints per 1K Customers (128) |
| **2 — Trend** | Satisfaction vs. Churn (combo: NPS Score bar + Churn Rate Trend line) · Complaints Volume Trend (area) · Complaints by Segment (donut) |
| **3 — Breakdown** | At-Risk vs. Lost (Churned) Customers trend (dual line) · Churned Customers by State (horizontal bar) · Active Segments Volume Trend (stacked area: Champions, Loyal Customers, Potential Loyalists) |

**Filters:** Year / Month slicers (top right).

---

## Descoped Scope

**Analyst Dashboard page** — originally planned for a fourth audience (Data Analyst, Branch Manager), covering segment-level growth-rate breakdowns and drill-through detail. **Not built.** All required measures already exist in the 45-measure SSAS model, so this would be a pure Power BI visualization exercise if picked up later — just a new page added to the existing `.pbix`, no further ETL, modeling, or DAX work needed. See [Requirements Document, section 4.4](../01-Requirements/Requirements-Document.md) and [06-SSAS-Tabular/README.md](../06-SSAS-Tabular/README.md) for details.

---

## Common Design Patterns Across All Three Pages

Since all three dashboards live in one file, they share a single DAX measure set, theme, and navigation — consistency here isn't a coincidence, it's a side effect of the one-file structure:

- **Three-level layout convention:** every page follows KPI Cards (Level 1) → Trend/Distribution Charts (Level 2) → Deeper Breakdowns (Level 3), top to bottom
- **Canvas KPI Card custom visual** (AppSource) used for every Level-1 KPI, with sparklines showing the trailing trend
- **Shared navigation pane:** the left-hand "Banking Analytics" pane with Executive / Marketing / CRM links is present on every page and uses Power BI's built-in page-navigation buttons, not separate reports
- **Shared slicers:** Year and Month slicers in the top-right corner of every page, wired to the same `Dim_Date` hierarchy — note that slicer selections do **not** carry over between pages by default (Power BI page-level filters), so each page's slicers act independently
- **Percentage-formatted KPI cards use `_disp` measures:** the Canvas KPI Card visual doesn't respect the `FormatString` metadata inherited from live-connected SSAS measures, so Rate-type KPIs (Churn Rate, Hibernating Rate, etc.) use dedicated `_disp` measures (value × 100, with an explicit `0.00"%"` format string applied directly in Power BI) instead of relying on the SSAS-side Percentage format

---

## Key DAX & Design Lessons (Power BI Layer)

These patterns were established while building these three dashboards, on top of the SSAS measure library documented in [06-SSAS-Tabular](../06-SSAS-Tabular/):

- **VAR-first CALCULATE rule:** never reference a measure directly inside a `CALCULATE`/`CALCULATETABLE` filter expression — capture it in a `VAR` first, to avoid context-transition bugs
- **Slicer-responsive date anchor:** local `_SelectedDateKey := MAX(Fact_CustomerSnapshot[DateKey])` measures were added for any visual that must respond to the Year/Month slicers, distinct from the SSAS-side `_LastDataDateKey`, which is reserved for KPI-card headline values that should always show the latest month regardless of slicer state
- **Canvas KPI Card latest-period logic:** Card Value fields require `ALLSELECTED(Dim_Date)` + `MAX(Dim_Date[DateKey])` comparison to correctly isolate the latest selected period
- **Trend/sparkline measures:** implemented as simple pass-through references to the base measure (`Trend := [Base Measure]`) — no explicit date filter needed, since context transition on the sparkline axis already handles it
- **`TREATAS` caveat:** self-referencing `TREATAS` on the same table consistently returned blank in a couple of segment-migration visuals; replaced with `INTERSECT`-based filtering instead
- **Pragmatic metric substitution:** a planned "Win-Back Rate" transition-based measure for the Marketing dashboard proved unreliable during testing and was replaced with the simpler, equally informative Hibernating Rate shown above

---

## Related Documentation

- [SSAS Tabular Model](../06-SSAS-Tabular/) — semantic layer and full 45-measure library behind these dashboards
- [Data Dictionary](../03-Data-Modeling/Data-Dictionary_v1.3.md) — field-level definitions
- [Requirements Document](../01-Requirements/Requirements-Document.md) — KPI-to-dashboard mapping and persona definitions
- [Project README](../README.md)

---

**Version:** 1.0 (Final)
**Last Updated:** July 2026
**Status:** ✅ Complete
**Author:** Soheil Tavakkol
