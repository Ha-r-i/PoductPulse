# Data dictionary

## Source and scope

The source CSV is the [IBM Telco Customer Churn dataset](https://www.kaggle.com/datasets/blastchar/telco-customer-churn), with 7,043 customer records. It contains tenure, monthly and total charges, contract attributes, and a churn label. It does not contain product events, signup timestamps, payment transactions, acquisition channels, or geography.

ProductPulse maps this customer snapshot into four analytics tables. Lifecycle dates and payments are reconstructed; product activity and additional trial-only accounts are simulated. The saved dataset contains 9,156 accounts. These histories describe a fictional SaaS product rather than observed Telco operations.

| Table or attribute | Basis |
|---|---|
| Customer IDs, tenure, charges, and churn labels | Source CSV |
| Signup dates and subscription lifecycle dates | Derived from tenure and assumed timing |
| Plan tiers | Monthly-charge terciles mapped to Basic, Pro, and Enterprise |
| Payment records | Monthly charges repeated over reconstructed billing months |
| Product events and session IDs | Simulated usage histories |
| Country and acquisition channel | Sampled categories |
| Trial-only accounts | Additional simulated non-converting users |

## Generation parameters

The parameters are defined in `notebooks/01_data_cleaning_and_generation.ipynb`.

| Parameter | Value | Meaning |
|---|---|---|
| `SNAPSHOT_DATE` | `2026-08-31` | Reporting cutoff |
| `RNG_SEED` | `42` | Random-number seed |
| `TRIAL_LENGTH_DAYS` | `14` | Assumed interval between signup and paid conversion |
| `NON_CONVERTER_RATE` | `0.30` | Additional trial-only accounts as a fraction of the 7,043 source customers |
| `COMPANY_START` | Snapshot minus 72 months | Reference point for reconstructing historical signups |

Adding 2,113 trial-only accounts produces 9,156 total accounts and a 76.92% signup-to-paid ratio. That ratio follows from the population construction; it is not an observed conversion benchmark.

## `users`

One row per account.

| Column | Type | Source and definition |
|---|---|---|
| `user_id` | VARCHAR(20), primary key | Source `customerID`, or a generated unique ID for trial-only accounts |
| `signup_date` | DATE | Reconstructed from tenure and an assumed end date, with random day-level jitter |
| `country` | VARCHAR | Sampled from ten countries using fixed weights |
| `acquisition_channel` | VARCHAR | Organic Search, Paid Search, Paid Social, Referral, Partner, or Email |

Active customers' signup dates are derived backward from the snapshot. Churned customers are assigned earlier end dates before deriving their signups. Trial-only signup dates are sampled from the reconstructed signup distribution.

Channel weights differ according to the churn outcome. Channel-level differences are therefore partly imposed by the generator.

## `events`

One row per product event; multiple events can share a session.

| Column | Type | Source and definition |
|---|---|---|
| `event_id` | BIGSERIAL, primary key | Generated event identifier |
| `user_id` | VARCHAR(20), foreign key | Account in `users` |
| `event_name` | VARCHAR | `login` or `feature_used` |
| `feature_name` | VARCHAR, nullable | Feature used; null for login events |
| `event_timestamp` | TIMESTAMP | Simulated event time within a reconstructed activity history |
| `session_id` | VARCHAR(40) | Generated identifier grouping events into sessions |

Session rates depend on plan and a sampled engagement level. Churned users have reduced activity near their assumed end dates. Features are sampled from a weighted catalog of ten product areas.

The generator adds a trial-period activation session for any paid account that lacks one. The funnel's activated-before-paid ordering is consequently a generation rule, rather than an independently observed finding.

## `subscriptions`

One row per account, representing its snapshot state rather than a complete status history.

| Column | Type | Source and definition |
|---|---|---|
| `user_id` | VARCHAR(20), primary and foreign key | Account in `users` |
| `plan` | VARCHAR | Basic, Pro, or Enterprise; source customers use monthly-charge terciles |
| `status` | VARCHAR | `trialing`, `active`, or `churned` |
| `trial_start` | DATE | Same as `signup_date` |
| `paid_date` | DATE, nullable | Signup plus 14 days for source customers; null for trial-only accounts |

Source `Churn` maps to `active` or `churned`. Trial-only accounts are recorded as `churned` with no paid date. SQL uses `paid_date IS NOT NULL` to distinguish paid customers from trial drop-offs.

The current generator can assign recent customers a paid date beyond the snapshot. Recent-trial censoring remains an open correction; see the [project notes](project_review.md).

## `payments`

One row per reconstructed billing month.

| Column | Type | Source and definition |
|---|---|---|
| `payment_id` | BIGSERIAL, primary key | Generated payment identifier |
| `user_id` | VARCHAR(20), foreign key | Account in `users` |
| `amount` | NUMERIC(10,2) | Source `MonthlyCharges`, held constant across billing months |
| `payment_date` | DATE | Monthly intervals from the derived paid date, bounded by tenure and the snapshot |

Notebook 01 compares reconstructed customer totals with source `TotalCharges`. This is a consistency check; the source does not provide individual invoices, historical price changes, or promotions.

## Metric definitions

- **Activation:** at least one feature event during the 14-day trial.
- **Paid:** a non-null `paid_date`.
- **Retained funnel stage:** accounts with snapshot status `active`.
- **Cohort retention:** users active in a calendar month, divided by the signup cohort size. Period 0 is the signup month and need not equal 100%.
- **Day-7 and day-30 retention:** activity on the exact day after signup, rather than permanent subscription retention.

The dashboard funnel is Signed Up -> Activated -> Paid -> Retained. There is no visitor stage because the schema contains no pre-signup traffic. Trial start coincides with signup, so it is not shown as a separate stage.

## Interpretation

Usage and channel generation depend on the known churn outcome. Subscription history is incomplete, and model eligibility can use information observed after the prediction cutoff. Model scores and segment comparisons apply to this simulation. Independent event and subscription histories would be required for prospective prediction or causal business conclusions.

Report filters exclude dates after the snapshot, but the underlying generator boundaries and database load still require correction. See the [validation and release checklist](FINISHING_CHECKLIST.md).
