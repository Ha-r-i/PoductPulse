# Project notes

Updated 24 October 2026.

The repository includes the SQL analyses, three notebooks, source customer CSV, seven dashboard exports, and a four-page Power BI report. The report package and saved artifacts pass offline validation. Desktop rendering and final screenshots remain pending.

## Completed

- Added the Power BI report, theme, date slicer, cohort heatmap formatting, explanatory notes, and corrected total/display settings.
- Limited report dates to the 31 August 2026 snapshot.
- Changed notebook configuration loading so rerunning a connection cell reads updated `.env` credentials.
- Added portable Windows setup instructions and offline validation.

## Data and modelling limits

The source provides customer attributes and a churn label, not observed product events or complete billing histories. Channels and usage are generated using churn outcomes. Model scores and channel differences therefore describe this simulation and cannot establish production predictive performance or marketing recommendations.

The generator can place some trial, paid, and activation dates after the snapshot. Report filters exclude the affected dates, but the generator still needs explicit bounds and recent-trial censoring. Regenerate the database, CSV exports, and report together after correcting it. Investigate the activity spike near the cutoff as part of that work.

Subscriptions store current state rather than full lifecycle history. Model eligibility can use current status or payments after the prediction cutoff, excluding some users who were active at that cutoff. Independent subscription histories are needed for a prospective evaluation.

Exact-day activity retention does not measure permanent churn. Plan-dependent simulated usage also confounds engagement and revenue comparisons.

## Remaining work

- Open and inspect the revised report in Power BI Desktop, test its interactions, and capture the four final screenshots.
- Complete a fresh installation and end-to-end run. Saved notebook outputs and CSVs alone do not verify that process.
- Correct the generator's temporal boundaries and reconcile regenerated outputs.
- Make database loading atomic. The current notebook commits truncation and each table load separately, so a failed import can leave a partial database.
- Evaluate the model on independently observed usage and subscription histories before making predictive claims.
