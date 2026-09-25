# Project review — 2026-09-25

The SQL, three notebooks, source dataset, and seven dashboard exports are present. The project is suitable for publishing as a work-in-progress portfolio project, but is not yet a verified end-to-end deliverable.

## Completion checklist

- Build and visually verify the four Power BI pages; commit the `.pbix` and screenshots. Only the CSVs, theme, and instructions currently exist.
- Run a fresh dependency installation and all notebooks against PostgreSQL. The local database was unreachable during this review; live SQL and notebook execution were not verified.
- Correct temporal boundaries in notebook 01: adding 14 days to recent signups can put paid dates after the snapshot; seeded activation events can also exceed it. Define recent-trial censoring, enforce bounds, and regenerate tables and exports together.
- Replace model eligibility based on current status or post-cutoff payments with explicit subscription history. The current query can exclude users who were active at cutoff but churned before their next payment.
- Treat the churn model as a simulation exercise. Channels are assigned using churn labels, and sessions taper near generated churn dates. Restricting feature timestamps does not remove this outcome dependence. Validate on independently observed histories before claiming predictive performance.
- Make the database refresh atomic. Notebook 01 currently commits truncation and each table load separately, so a failed COPY can leave a partial database.
- Reconcile regenerated CSVs with SQL output and update notebook narratives. Exact-day activity retention does not establish permanent churn timing, and plan-dependent synthetic usage confounds engagement/revenue comparisons.

## Preparation changes

The README now discloses missing deliverables and limits the model/business claims. Windows setup instructions were added. Notebook database URLs now handle special characters in passwords, and synthetic IDs are sorted to avoid set-order variation between processes.

Saved notebook outputs and dashboard CSVs predate this review and were not regenerated. Earlier notebook interpretations and supporting PDFs must be read with these limitations. The local interview PDFs are not part of the tracked project deliverable.
