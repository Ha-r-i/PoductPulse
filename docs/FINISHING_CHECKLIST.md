# Finish ProductPulse

The SQL, notebooks, exports, and four-page report are present. Follow these
steps to finish and verify the portfolio project. Screenshots can be added
now to document the current report; capture them again if regenerated data
changes the visuals.

## 1. Correct the generated observation window

In `notebooks/01_data_cleaning_and_generation.ipynb`, keep the snapshot at
31 August 2026 and check every generated date against it.

- Keep valid recent signups, but leave them as trials if their paid conversion
  would occur after the snapshot. Their `paid_date` should remain null.
- Generate activation and session events within the observed window. Include
  the full final day without creating September events.
- Keep payment dates within the same window.
- Inspect daily activity during the final week. Explain or correct the
  late-August spike and drop at the generator level.

Report filters already hide post-snapshot dates. They do not fix these source
histories. Do not silently drop customers to make the date checks pass.

## 2. Make the database load atomic

Notebook 01 currently commits truncation and each import separately. Use one
database connection and transaction for truncation and all four table loads,
and commit only after the load and its checks succeed. Roll back on failure.
Use a dedicated `productpulse` database because this process replaces data.

## 3. Run the notebooks in a fresh environment

Follow the [Windows setup](../README.md#run-locally-on-windows), including
the local `.env` and schema creation. Install from `requirements.txt`, then
open Jupyter with its working directory set to `notebooks/`.

Run every cell in this order:

1. `01_data_cleaning_and_generation.ipynb`
2. `02_exploratory_analysis.ipynb`
3. `03_churn_model.ipynb`

Alternatively, from `notebooks/`:

```powershell
..\.venv-local\Scripts\python.exe -m jupyter nbconvert --to notebook --execute --inplace --ExecutePreprocessor.timeout=1200 01_data_cleaning_and_generation.ipynb
..\.venv-local\Scripts\python.exe -m jupyter nbconvert --to notebook --execute --inplace --ExecutePreprocessor.timeout=1200 02_exploratory_analysis.ipynb
..\.venv-local\Scripts\python.exe -m jupyter nbconvert --to notebook --execute --inplace --ExecutePreprocessor.timeout=1200 03_churn_model.ipynb
```

Stop at any error and resolve it before continuing. Save the new outputs.
Keep credentials in `.env`; do not paste passwords into notebook cells.

## 4. Check the live database

From the project root:

```powershell
psql -h localhost -U postgres -d productpulse -v ON_ERROR_STOP=1 -f sql/validation/01_snapshot_checks.sql
```

Every violation count must be zero. The script is read-only and returns an
error if dates exceed the snapshot. It is expected to fail against the
current uncorrected histories.

Then run the ten queries in `sql/analysis/` and review their output. Check
row counts, revenue trends, funnel order, and cohort periods. Confirm that
any differences from the old exports follow from the generator corrections.

## 5. Regenerate the seven dashboard exports

Use the [CSV refresh commands](../powerbi/BUILD_GUIDE.md#refresh-the-csvs).
Export all six queries from `sql/exports/` and the cohort analysis query.
Refresh all seven files together so every page uses the same database version.

Run:

```powershell
python scripts/validate_project.py
```

This checks saved artifacts and report structure. It does not replace the
live database checks or the notebook run. If a generator change intentionally
changes a count, reconcile the new result before updating a validation rule.

## 6. Refresh and inspect the Power BI report

Open `powerbi/ProductPulse_Updated.pbix` in Power BI Desktop. Update its CSV
source paths, select Refresh, and inspect every page.

- Reconcile the five cards with the regenerated August row and July MRR.
  The old values were MRR 319,394.60; MAU 4,732; paying users 5,199;
  churn 1.25%; and MRR growth 1.21%. New values may differ after corrections.
- Check the saved daily range: 1 September 2025 to 31 August 2026. Both daily
  charts should respond to the slicer; the all-time summaries should not.
- Check the heatmap colours, chronological cohort labels, blank future
  periods, and absence of row and column totals.
- Check exact funnel counts and stage order. The stage table must not add
  overlapping users into a grand total.
- Check the theme, notes, spacing, and readable labels. Save, close, and
  reopen the report to confirm it still works.

## 7. Add the screenshots

Use the [capture instructions](../powerbi/screenshots/README.md). Provide
four PNGs or one PDF export of all four pages. The images can then be
reviewed, placed in `powerbi/screenshots/`, and embedded in the root README.
Use captures of the revised report rather than the earlier layout.

## 8. Publish the final version

Update the README's KPI values and status after the checks pass. Record the
run date and any remaining limitations in `docs/project_review.md`.

Commit the notebooks, SQL fixes, all seven exports, saved report, screenshots,
and documentation together. Keep `.env`, local environments, processed raw
tables, and backup files out of Git. Push to `main` and check the README
images and report download on GitHub.

## Completion criteria

- [ ] Generator dates stay within the snapshot, including the full final day.
- [ ] Failed loads leave the previous database intact.
- [ ] All three notebooks run successfully from a fresh environment.
- [ ] Live snapshot checks and the ten SQL analyses have been reviewed.
- [ ] All seven exports and the report use the same regenerated dataset.
- [ ] The revised report opens, refreshes, and responds correctly in Desktop.
- [ ] Four clear screenshots are visible in the GitHub README.
- [ ] Documentation matches the final data and the repository is pushed.

The churn model can be complete as a documented simulation exercise. A claim
of production predictive performance would require independently observed
usage and subscription histories, followed by a prospective evaluation.
