# Power BI dashboard guide

Open [ProductPulse_Updated.pbix](ProductPulse_Updated.pbix) in Power BI Desktop. The report has four pages and uses the seven summary CSVs in `data/`. The [PDF](ProductPulse-Dashboard.pdf) and [screenshots](screenshots/README.md) provide a static preview.

The report includes KPI cards, an activity date slicer, a cohort heatmap, and notes on the data assumptions. The supplied PDF has been reviewed and its four pages are included in the README. The package also passes structural checks. Data refresh and interactive filtering require verification in Desktop.

## Pages and data

| Page | CSVs |
|---|---|
| Executive Overview | `monthly_kpis.csv` |
| User Behaviour | `daily_activity.csv`, `feature_adoption.csv`, `users_by_country.csv` |
| Retention | `cohort_retention.csv`, `churn_by_channel.csv` |
| Conversion Funnel | `conversion_funnel.csv` |

These tables are independent summaries. A date slicer on `daily_activity` filters the two daily charts. Feature adoption and country summaries have no date field and remain all-time views. The exports do not contain `plan`, so a plan slicer would require additional data and model changes.

## Reporting dates

The snapshot is **31 August 2026**. All five Executive Overview cards are filtered to August. The monthly CSV also has a September row with 7 MAU and no billing KPIs; it is excluded from the report's monthly trends.

The packaged report's default User Behaviour range is **1 September 2025 to 31 August 2026**. The screenshot captures a different user-selected range. The page filter prevents dates after the snapshot from appearing. The Retention page filters cohort periods to the same observation boundary.

These filters exclude six daily rows and one cohort-period row beyond the snapshot. They do not repair the generator. The late-August activity spike and drop remain visible and should be treated as simulation artefacts until investigated.

## Refresh the CSVs

Run the notebooks against PostgreSQL first. From the project root, export the dashboard summaries:

```powershell
Get-ChildItem .\sql\exports\*.sql | ForEach-Object {
    $csvName = ($_.BaseName -replace '^\d+_', '') + '.csv'
    psql -X -h localhost -U postgres -d productpulse --csv -P footer=off -v ON_ERROR_STOP=1 -f $_.FullName -o ".\powerbi\data\$csvName"
    if ($LASTEXITCODE -ne 0) { throw "Export failed: $($_.Name)" }
}

psql -X -h localhost -U postgres -d productpulse --csv -P footer=off -v ON_ERROR_STOP=1 -f .\sql\analysis\08_cohort_analysis.sql -o .\powerbi\data\cohort_retention.csv
```

In Desktop, update the CSV locations through **Transform data > Data source settings > Change source**, then select **Refresh**. If rebuilding the model, use **Get data > Text/CSV** for each file.

Keep month, date, and cohort-month columns as Date; use whole numbers for counts and period numbers. Percentage columns such as `retention_pct` and `churn_rate_pct` use a 0-100 scale.

## KPI cards

The supplied cards show:

| Card | August value |
|---|---:|
| MRR | 319,394.60 |
| MAU | 4,732 |
| Paying users | 5,199 |
| Monthly churn rate | 1.25% |
| MRR growth | 1.21% |

July MRR is 315,589.40, giving `(319394.60 / 315589.40 - 1) * 100 = 1.21%` after rounding. Churn measures displayed with Percentage formatting must divide the raw 0-100 value by 100 exactly once.

Keep card titles and filters on the same month. When changing the reporting month, check that MRR, MAU, paying users, and churn are all available for it.

## Theme and chart formatting

The [theme.json](theme.json) file provides a light base theme. The PDF gallery uses a dark presentation. To import a theme manually, use **Design > Import theme**, or **View > Themes > Browse for themes** in earlier Desktop versions. Existing visual overrides may need resetting. See [Microsoft's theme instructions](https://learn.microsoft.com/en-us/power-bi/create-reports/desktop-report-themes).

The retention matrix uses:

- Rows: `cohort_month`, formatted `MMM yyyy` and sorted chronologically.
- Columns: `period_number`, from 0 to 12.
- Values: Average of `retention_pct`.
- Background gradient: 0 = `#FFFFFF`; 100 = `#8FAADC`, with dark text.
- Blank cells unfilled; row and column totals disabled.

Period 0 measures activity during the signup calendar month, so it need not equal 100%. The retention curve is an unweighted average across the available cohorts. See [Microsoft's matrix formatting instructions](https://learn.microsoft.com/en-us/power-bi/create-reports/desktop-conditional-table-formatting).

The funnel uses exact counts: **9,156 -> 7,419 -> 7,043 -> 5,174**. Its stage-table total is disabled because the stages contain overlapping users. The final stage reaches 56.51% of signups. There is no visitor stage because the source has no pre-signup traffic data.

Keep the report notes visible. Customer attributes come from the source CSV, while usage and lifecycle histories are reconstructed or simulated. Channel differences reflect generator assumptions and do not establish causes.

## Check and save

1. Open the report and inspect each page for missing visuals, errors, clipped labels, and unreadable text.
2. Confirm that both daily charts respond to the date slicer and that the all-time feature and country summaries stay unchanged. Restore the saved date range afterward.
3. Check the five card values, heatmap colours, cohort labels, and exact funnel labels. Confirm that misleading totals are absent.
4. Save the report from Desktop, close it, and reopen it once more.
5. If the report or data changed, update the [PDF and all four screenshots](screenshots/README.md) together. Keep the notes visible and use the existing filenames.
6. Review the [validation and release checklist](../docs/FINISHING_CHECKLIST.md) before publishing regenerated data.

Local `.pbix.bak` backups are excluded from Git. Retain a working backup before editing the report package.

## Report-formatting script

`scripts/finish_powerbi_report.py` updates the saved PBIR definitions inside the report package. It preserves the embedded model and the archive components outside `Report/`. It does not execute DAX, refresh data, or render visuals.

To stage a separate copy:

```powershell
python scripts/finish_powerbi_report.py --output powerbi/ProductPulse_Review.pbix
```

Without `--output`, it updates the current report and creates a local backup on the first run. Close the report in Desktop before replacing its file. Reopening in Desktop is required after every package edit.

The report declares visual schema 2.14.0. Structural checks during the update used the latest available public 2.13.0 schema; the file's original schema declarations were retained. This is a compatibility limit of the offline check.
