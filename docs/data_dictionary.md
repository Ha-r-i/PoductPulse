# ProductPulse — Data Dictionary & Source Mapping

## Approach

ProductPulse blends **real subscription/billing/churn data** with a **calibrated
synthetic event log**. No public dataset pairs row-level product usage with real
subscription billing for the same users — that combination is commercially
sensitive and isn't released publicly. Rather than fabricate every number, only
the pieces that genuinely don't exist anywhere in public data are simulated —
and they're simulated *from* the real data's actual tenure/charge/churn
patterns, not from scratch.

**Real source:** IBM Telco Customer Churn dataset — 7,043 customers, 21 columns,
originally published by IBM, mirrored on Kaggle:
https://www.kaggle.com/datasets/blastchar/telco-customer-churn

| Data | Source |
|---|---|
| `users` signup timing | Derived from real `tenure` |
| `subscriptions` plan / status | Derived from real `MonthlyCharges` / `Churn` |
| `payments` billing history | Reconstructed from real `MonthlyCharges` / `TotalCharges` |
| `events` usage log | Fully synthetic, calibrated to each real user's tenure & churn outcome |
| `country`, `acquisition_channel` | Fully synthetic (Telco has no geography/marketing fields) |

## Reference constants (implemented in Module 3)

- `SNAPSHOT_DATE = 2026-08-31` — the fictional "as of" date the dataset is generated against.
- `TRIAL_LENGTH_DAYS = 14`
- `NON_CONVERTER_RATE = 0.30` — synthetic trial drop-offs added as 30% of the real
  (already-paying) Telco base, giving an implied trial → paid conversion of **~77%**.
  Telco only contains existing customers, so a realistic top-of-funnel has to be added
  deliberately rather than assumed away. 77% is high for a self-serve trial but
  plausible for a guided/sales-assisted B2B trial, which fits a product managers use
  for decision-making — that's the framing used here rather than a pure self-serve
  PLG benchmark (which would run closer to 15-25% and would have meant tripling the
  synthetic population relative to the real one, diluting the "grounded in real data"
  story for no analytical benefit).

## `users`

| Column | Type | Source | Notes |
|---|---|---|---|
| user_id | VARCHAR(20) PK | Real (`customerID`) | e.g. `7590-VHVEG` |
| signup_date | DATE | Derived | `SNAPSHOT_DATE − tenure months` (real `tenure`), ± a few random days |
| country | VARCHAR | Synthetic | Weighted distribution across a realistic SaaS market mix (US-heavy; UK, India, Canada, Australia, Germany, etc.) |
| acquisition_channel | VARCHAR | Synthetic | Organic Search, Paid Search, Paid Social, Referral, Partner, Email — weighted, with a mild realistic skew (referral/organic churn a little less than paid channels) |

## `events`

| Column | Type | Source | Notes |
|---|---|---|---|
| event_id | BIGSERIAL PK | Generated | |
| user_id | FK → users | — | |
| event_name | VARCHAR | Synthetic | `login`, `feature_used` (no `logout` — real telemetry rarely logs those reliably either, so omitting it is more authentic than inventing one) |
| feature_name | VARCHAR, nullable | Synthetic | Populated only when `event_name='feature_used'`; drawn from a 10-feature catalog with a power-law popularity skew |
| event_timestamp | TIMESTAMP | Synthetic, **calibrated** | Per-user session frequency depends on real plan tier (from `MonthlyCharges`) and real churn outcome — churned users' sessions taper off over their final 3 weeks before their real churn date. Generated across each user's **entire** tenure, not a trailing calendar window, so every cohort — not just recent ones — keeps its early-lifecycle events for retention/cohort analysis. This is what makes retention, feature adoption, and the churn model meaningful instead of random noise. |

**Post-generation invariant:** `paid_date` for real users comes straight from
Telco, independent of the simulated session draw — at low session rates,
~2,000 real paying customers randomly landed zero sessions in their 14-day
trial window. The notebook detects this and seeds one activation event
(login + feature_used) for any paying user missing one, then asserts the
invariant holds before loading. Without this, the conversion funnel would show
more "Paid" users than "Activated" users, which is impossible — and no real
company charges someone who never opened the product anyway.
| session_id | VARCHAR(40) | Synthetic | Groups events into sessions |

## `subscriptions`

| Column | Type | Source | Notes |
|---|---|---|---|
| user_id | VARCHAR(20) PK, FK → users | — | One row per user (snapshot, not a change-history table — deliberate scope for a 1-2 week project) |
| plan | VARCHAR, CHECK IN (Basic/Pro/Enterprise) | Derived | Tercile of real `MonthlyCharges` (low/mid/high) mapped to Basic/Pro/Enterprise |
| status | VARCHAR, CHECK IN (trialing/active/churned) | Derived | Real `Churn` (Yes→churned, No→active); synthetic non-converters end as `churned` with `paid_date IS NULL` — this is how downstream SQL tells "churned after paying" apart from "dropped out during trial" without needing a 4th status value |
| trial_start | DATE | Derived | = `signup_date` |
| paid_date | DATE, nullable | Derived | = `trial_start + 14 days` for converters; `NULL` for non-converters |

## `payments`

| Column | Type | Source | Notes |
|---|---|---|---|
| payment_id | BIGSERIAL PK | Generated | |
| user_id | FK → users | — | |
| amount | NUMERIC(10,2) | Real (`MonthlyCharges`) | Same real charge repeated across the user's real billing history |
| payment_date | DATE | Derived | One row per elapsed month from `paid_date` to churn/snapshot date, spaced monthly |

**QA check (run in `notebooks/01_data_cleaning_and_generation.ipynb`):**
`SUM(payments.amount)` per user reconciles against Telco's real `TotalCharges`
column at **r = 0.9996**. The small remaining gap is expected — real Telco
billing reflects mid-contract rate changes and promos this dataset can't see,
so a flat `MonthlyCharges × months` reconstruction can't match it to the cent.

## Known deviation to flag now

The brief's Power BI funnel page is *Visitor → Signup → Trial → Paid*. Our
schema has no pre-signup "visitor" data — no public dataset pairs anonymous
web traffic with this kind of billing data, and at a real company that data
usually lives in a separate web-analytics tool anyway, not the product
database. When we build that page (Module 8), I'll propose
*Signup → Trial Started → Activated → Paid* instead — swapping "Visitor" for
"Activated" (used ≥1 key feature during the trial), which is both honest to
what we can actually measure from these four tables and a more standard
product-led-growth metric. Flagging it here so it isn't a surprise later.
