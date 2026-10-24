# ProductPulse

ProductPulse connects customer accounts, product activity, subscriptions, and payments in a PostgreSQL analytics project. It includes ten SQL analyses, three Python notebooks, a demonstration churn model, and a four-page Power BI report.

[Open the Power BI report](powerbi/ProductPulse_Updated.pbix) ? [Report guide](powerbi/BUILD_GUIDE.md) ? [Data dictionary](docs/data_dictionary.md)

## What it answers

- How many customers use the product each day and month?
- How do recurring revenue and the number of paying customers change over time?
- Where do users drop out of the signup-to-paid funnel?
- How does activity retention vary across signup cohorts?
- Which features are used, and how do customer segments differ?

## Data

The source is the [IBM Telco Customer Churn dataset](https://www.kaggle.com/datasets/blastchar/telco-customer-churn): 7,043 customers with tenure, charges, contract details, and churn labels. The CSV is included in `data/raw/`.

Product events, trial signups, acquisition channels, and geography are simulated. Payment histories and churn dates are reconstructed from the customer snapshot. The generated dataset has 9,156 accounts and more than three million events. The [data dictionary](docs/data_dictionary.md) explains the mapping and assumptions.

The reporting snapshot is **31 August 2026**.

## Dashboard

Open [ProductPulse_Updated.pbix](powerbi/ProductPulse_Updated.pbix) in Power BI Desktop.

| Page | Contents |
|---|---|
| Executive Overview | August KPI cards and monthly revenue, activity, and paying-user trends |
| User Behaviour | Daily users and sessions, a date-range slicer, feature adoption, and country summaries |
| Retention | Cohort heatmap, average activity retention, and churn by acquisition channel |
| Conversion Funnel | Signed Up ? Activated ? Paid ? Retained, with exact stage counts |

The August exports contain these values:

| Metric | Value |
|---|---:|
| Monthly recurring revenue | 319,394.60 |
| Monthly active users | 4,732 |
| Paying users | 5,199 |
| Monthly churn rate | 1.25% |
| Revenue growth from July | 1.21% |

The report includes the ProductPulse theme, an activity date slicer, heatmap colours, and notes on the simulated data. Its report definitions and archive pass offline checks. Reopening and checking the revised file in Power BI Desktop, and capturing the final screenshots, are still pending. See the [report guide](powerbi/BUILD_GUIDE.md).

## Stack and structure

PostgreSQL stores the four core tables. SQL produces the analyses and dashboard summaries. Python uses pandas, NumPy, scikit-learn, matplotlib, and seaborn for generation, exploration, and modelling.

```text
ProductPulse/
??? data/raw/       Source customer CSV
??? data/processed/ Generated tables; kept out of Git
??? sql/ddl/        Table definitions and indexes
??? sql/analysis/   Ten business analyses
??? sql/features/   User and churn-model features
??? sql/exports/    Dashboard summary queries
??? notebooks/     Generation, exploration, and churn model
??? powerbi/        Report, theme, exports, and build guide
??? scripts/        Validation and report-formatting tools
??? docs/           Data dictionary and project notes
```

```mermaid
flowchart LR
    A[Customer CSV] --> B[Python cleaning and generation]
    B --> C[(PostgreSQL)]
    C --> D[SQL analyses and summary exports]
    C --> E[Python exploration and churn model]
    D --> F[Power BI]
```

## Data model

```mermaid
erDiagram
    USERS ||--o{ EVENTS : generates
    USERS ||--|| SUBSCRIPTIONS : has
    USERS ||--o{ PAYMENTS : makes
    USERS {
        varchar user_id PK
        date signup_date
        varchar country
        varchar acquisition_channel
    }
    EVENTS {
        bigint event_id PK
        varchar user_id FK
        varchar event_name
        varchar feature_name
        timestamp event_timestamp
        varchar session_id
    }
    SUBSCRIPTIONS {
        varchar user_id PK, FK
        varchar plan
        varchar status
        date trial_start
        date paid_date
    }
    PAYMENTS {
        bigint payment_id PK
        varchar user_id FK
        numeric amount
        date payment_date
    }
```

The [schema](sql/ddl/01_create_tables.sql) defines primary and foreign keys, checks on plan and subscription status, and indexes for the analysis queries.

## Run locally on Windows

Install Python and PostgreSQL, then open PowerShell in the project folder. Python 3.14 is used by the documented Windows setup. PostgreSQL's `bin` directory must be on PATH to use `createdb` and `psql`.

1. Create a Python environment:

   ```powershell
   python -m venv .venv-local
   .\.venv-local\Scripts\python.exe -m pip install -r requirements.txt
   ```

2. Create `.env` from `.env.example` if it does not already exist, then enter your local PostgreSQL credentials:

   ```dotenv
   PGHOST=localhost
   PGPORT=5432
   PGDATABASE=productpulse
   PGUSER=postgres
   PGPASSWORD="your_password"
   ```

3. Create a dedicated database and its tables:

   ```powershell
   createdb -h localhost -U postgres productpulse
   psql -h localhost -U postgres -d productpulse -v ON_ERROR_STOP=1 -f sql/ddl/01_create_tables.sql
   ```

   The schema script recreates the project tables. Notebook 01 replaces their data, so use a database reserved for this project.

4. Start Jupyter from the notebook directory:

   ```powershell
   cd notebooks
   ..\.venv-local\Scripts\python.exe -m jupyter lab
   ```

   Run `01_data_cleaning_and_generation.ipynb`, then `02_exploratory_analysis.ipynb`, then `03_churn_model.ipynb`. Their relative paths assume the working directory is `notebooks/`.

5. From the project root, run any analysis query:

   ```powershell
   psql -h localhost -U postgres -d productpulse -f sql/analysis/01_daily_active_users.sql
   ```

6. Refresh the dashboard exports and the Power BI report using the [report guide](powerbi/BUILD_GUIDE.md#refresh-the-csvs).

For macOS or Linux, create a virtual environment with `python3 -m venv .venv` and use `.venv/bin/python` for the equivalent Python commands. Create the same `.env` and PostgreSQL database. Power BI Desktop requires Windows.

## SQL analyses

| Analysis | Query |
|---|---|
| Daily active users | [01_daily_active_users.sql](sql/analysis/01_daily_active_users.sql) |
| Monthly active users and stickiness | [02_monthly_active_users.sql](sql/analysis/02_monthly_active_users.sql) |
| Monthly recurring revenue | [03_monthly_recurring_revenue.sql](sql/analysis/03_monthly_recurring_revenue.sql) |
| Paying-user growth | [04_paying_user_growth.sql](sql/analysis/04_paying_user_growth.sql) |
| Conversion funnel | [05_conversion_funnel.sql](sql/analysis/05_conversion_funnel.sql) |
| Seven-day activity retention | [06_retention_7_day.sql](sql/analysis/06_retention_7_day.sql) |
| Thirty-day activity retention | [07_retention_30_day.sql](sql/analysis/07_retention_30_day.sql) |
| Cohort retention | [08_cohort_analysis.sql](sql/analysis/08_cohort_analysis.sql) |
| Feature adoption | [09_feature_adoption.sql](sql/analysis/09_feature_adoption.sql) |
| Churn rate | [10_churn_rate.sql](sql/analysis/10_churn_rate.sql) |

## Validation and limits

Run the offline checks from the project root:

```powershell
python scripts/validate_project.py
```

These check the notebooks, source IDs, saved exports, theme, and report package. They do not execute the notebooks, query PostgreSQL, or render Power BI visuals.

A few limits matter when reading the results:

- Channels and usage histories are generated using churn outcomes. Differences between channels and model scores reflect these assumptions; they are not evidence for marketing spend or production predictions.
- Cohort retention measures activity in a calendar month. Day-7 and day-30 activity do not establish when a customer permanently churned.
- The generator can create activity after the snapshot. Report filters exclude those dates, but the underlying histories still need correction and regeneration. The late-August activity spike also needs investigation.
- Subscription state is a snapshot rather than a full history. Model eligibility can depend on information observed after the prediction cutoff.
- Database loads commit in separate steps. A failed load can leave partial tables; an atomic refresh is still needed.

Further details are in [project notes](docs/project_review.md).
