# Project notes

Updated 24 October 2026.

The repository includes ten SQL analyses, three notebooks, the source customer CSV, seven dashboard exports, and a four-page Power BI report. The [dashboard PDF](../powerbi/ProductPulse-Dashboard.pdf) and four PNG screenshots are included in the README.

## Verification

| Check | Result |
|---|---|
| Saved notebooks, CSVs, theme, and report package | Offline validation passes |
| Four PDF report pages | Rendered and reviewed for readable charts, labels, and notes |
| README screenshots | Included for all four pages |
| Live snapshot-boundary audit | Detects post-snapshot dates; source correction remains open |
| Fresh installation and full notebook execution | Not yet verified |
| Desktop data refresh and interactive filtering | Not verified by the static PDF |

## Data and modelling limits

The source provides customer attributes and a churn label, not observed product events or complete billing histories. Channels and usage are generated using churn outcomes. Model scores and channel differences therefore describe this simulation and cannot establish production predictive performance or marketing recommendations.

The generator can place some paid dates and product events after the snapshot. Report filters exclude the affected dates, but the generator still needs explicit bounds and recent-trial censoring. Regenerate the database, CSV exports, and report together after correcting it. Investigate the activity spike near the cutoff as part of that work.

Subscriptions store current state rather than full lifecycle history. Model eligibility can use current status or payments after the prediction cutoff, excluding some users who were active at that cutoff. Independent subscription histories are needed for a prospective evaluation.

Exact-day activity retention does not measure permanent churn. Plan-dependent simulated usage also confounds engagement and revenue comparisons.

## Remaining work

Follow the [validation and release checklist](FINISHING_CHECKLIST.md) for commands, checks,
and the order of the remaining steps.

- Test the report's refresh and interactions in Power BI Desktop. Update the PDF and images after changing its data or layout.
- Complete a fresh installation and end-to-end run. Saved notebook outputs and CSVs alone do not verify that process.
- Correct the generator's temporal boundaries and reconcile regenerated outputs.
- Make database loading atomic. The current notebook commits truncation and each table load separately, so a failed import can leave a partial database.
- Evaluate the model on independently observed usage and subscription histories before making predictive claims.
