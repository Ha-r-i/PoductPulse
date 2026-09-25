# ProductPulse — Power BI Build Guide

**Current status:** The Power BI report is not yet included. Billing/churn dates are reconstructed or simulated, and outcome-conditioned synthetic behavior limits model and business interpretations. See [the review](../docs/project_review.md).

This wasn't built on this machine (Power BI Desktop doesn't run natively on
macOS) — this guide plus the files in `powerbi/data/` are everything needed
to build it on Windows/a VM/Power BI Service. Re-run the queries in
`sql/exports/` (plus `sql/analysis/08_cohort_analysis.sql`) any time the
underlying data changes to refresh these CSVs.

## 1. Why flat CSVs, not a live Postgres connection

Power BI Desktop can connect to Postgres directly, but that only works if
Power BI can reach this machine's database over the network — true for a lot
of setups, but not guaranteed for a VM or a separate Windows machine. CSVs
work everywhere, and just as importantly: **the dashboard should read from
small, pre-aggregated summary tables, not the raw 3M-row `events` table.**
That's standard BI practice regardless of connectivity — recomputing DAU from
3M rows on every visual refresh is exactly the kind of thing a semantic layer
exists to avoid. If you do have network access from wherever you're running
Power BI, swap any of these for a live Postgres connection to the same query
— nothing else changes.

## 2. Import the data

`Get Data → Text/CSV`, once per file in `powerbi/data/`:

| File | Grain | Feeds page |
|---|---|---|
| `monthly_kpis.csv` | 1 row/month | Executive Overview |
| `daily_activity.csv` | 1 row/day | User Behaviour |
| `feature_adoption.csv` | 1 row/feature | User Behaviour |
| `users_by_country.csv` | 1 row/country | User Behaviour |
| `cohort_retention.csv` | 1 row/cohort×period | Retention |
| `churn_by_channel.csv` | 1 row/channel | Retention |
| `conversion_funnel.csv` | 1 row/stage | Conversion Funnel |

No relationships needed between them — these are independent, pre-aggregated
marts for different visuals, not a shared fact table. Keeping it flat is
deliberate for a project this size; don't build a star schema these seven
tables don't need.

## 3. Theme

`View → Themes → Browse for themes...` → select `powerbi/theme.json`. Blue/white
executive palette, the same accent colors as the Python notebooks' plots
(`#4C72B0` blue, `#55A868` green, `#C44E52` red) so the whole project reads as
one consistent system, not two disconnected halves.

## 4. Page 1 — Executive Overview

**DAX measures** (add to `monthly_kpis`):
```dax
Current MRR = CALCULATE(SUM(monthly_kpis[mrr]), monthly_kpis[month] = MAX(monthly_kpis[month]))
Current MAU = CALCULATE(SUM(monthly_kpis[mau]), monthly_kpis[month] = MAX(monthly_kpis[month]))
Current Paying Users = CALCULATE(SUM(monthly_kpis[paying_users]), monthly_kpis[month] = MAX(monthly_kpis[month]))
Current Churn Rate % = CALCULATE(AVERAGE(monthly_kpis[churn_rate_pct]), monthly_kpis[month] = MAX(monthly_kpis[month]))

MRR MoM Growth % =
VAR CurrentMRR = [Current MRR]
VAR PriorMRR = CALCULATE(SUM(monthly_kpis[mrr]), monthly_kpis[month] = EDATE(MAX(monthly_kpis[month]), -1))
RETURN DIVIDE(CurrentMRR - PriorMRR, PriorMRR)
```

**Layout:**
- Top row: 4 KPI cards — `Current MRR`, `Current MAU`, `Current Paying Users`, `Current Churn Rate %`. Add `MRR MoM Growth %` as the card's trend indicator if using the new-style Card visual.
- Below: a line chart, Axis = `month`, Values = `mrr` — the headline revenue trend.
- Two smaller line/area charts side by side: `mau` over `month`, and `paying_users` over `month`.

## 5. Page 2 — User Behaviour

**Layout:**
- Line chart: `daily_activity[date]` (Axis) vs. `dau` (Values) — full history is 6 years of daily data, so add a date-range slicer or default to the trailing 12 months so it's readable.
- Second line/column chart on the same axis: `sessions`.
- Bar chart: `feature_adoption`, Axis = `feature_name`, Values = `adoption_pct`, sorted descending — "Top Features".
- Map visual (or a simple bar chart if a live map feels like overkill): `users_by_country[country]` as the location field, `total_revenue` or `users` as the value.

## 6. Page 3 — Retention

**Cohort Heatmap:** Matrix visual — Rows = `cohort_retention[cohort_month]`, Columns = `period_number`, Values = `retention_pct` (Average). Apply conditional formatting (color scale, e.g. white → `#2E5C8A`) to the values so it reads as a heatmap, not just a table of numbers.

**Retention Curve:** Line chart, Axis = `period_number`, Values = `AVERAGE(cohort_retention[retention_pct])` — averages across every cohort into one curve. Add a measure if you want it named cleanly:
```dax
Avg Retention % = AVERAGE(cohort_retention[retention_pct])
```

**Churn by Acquisition Channel:** Bar chart, Axis = `churn_by_channel[acquisition_channel]`, Values = `churn_rate_pct`, sorted descending. Worth a callout on this page: Paid Social and Paid Search show the highest churn rates here — consistent with `05_conversion_funnel.sql`'s finding that they also convert worst, i.e. the same channels underperform at both ends of the customer lifecycle.

## 7. Page 4 — Conversion Funnel

**Funnel visual** (Power BI's native Funnel chart): Category = `stage` (make sure it's sorted by `stage_order`, not alphabetically — right-click the `stage` column → "Sort by column" → `stage_order`), Values = `users`.

Note on the brief's stage naming: this funnel is *Signed Up → Activated → Paid
→ Retained*, not *Visitor → Signup → Trial → Paid* — there's no pre-signup
traffic data in this schema (see `docs/data_dictionary.md`, "Known
deviation"), and "Trial Started" was dropped too since it's structurally
identical to "Signed Up" in this data model (the trial always begins
immediately at signup). Worth a text box on the page explaining that
adaptation rather than leaving a viewer to wonder why it doesn't match a
generic SaaS funnel template.

## 8. Final polish

- Consistent page titles top-left, consistent KPI card style across all four pages.
- A page-level filter/slicer for `plan` where relevant (Executive Overview,
  User Behaviour) lets a viewer immediately compare Basic/Pro/Enterprise
  without rebuilding visuals.
- Export each finished page as an image for the README's screenshots once built.
