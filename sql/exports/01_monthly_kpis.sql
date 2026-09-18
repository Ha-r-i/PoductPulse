-- ============================================================
-- Export: Monthly KPIs (Power BI — Executive Overview page)
-- ============================================================
-- One row per month: MRR, MAU, paying users, monthly churn rate.
-- Deliberately pre-aggregated rather than handing Power BI the raw
-- events/payments tables — a dashboard should read from a small
-- summary table, not recompute a full table scan on every visual.

WITH mrr AS (
    SELECT DATE_TRUNC('month', payment_date)::DATE AS month, SUM(amount) AS mrr
    FROM payments
    GROUP BY 1
),
mau AS (
    SELECT DATE_TRUNC('month', event_timestamp)::DATE AS month, COUNT(DISTINCT user_id) AS mau
    FROM events
    GROUP BY 1
),
paying AS (
    SELECT DATE_TRUNC('month', payment_date)::DATE AS month, COUNT(DISTINCT user_id) AS paying_users
    FROM payments
    GROUP BY 1
),
user_last_payment AS (
    SELECT user_id, MAX(DATE_TRUNC('month', payment_date))::DATE AS last_payment_month
    FROM payments
    GROUP BY user_id
),
bounds AS (
    SELECT MAX(DATE_TRUNC('month', payment_date))::DATE AS max_month FROM payments
),
churn_events AS (
    SELECT (last_payment_month + INTERVAL '1 month')::DATE AS churn_month, user_id
    FROM user_last_payment, bounds
    WHERE last_payment_month < max_month
),
churn AS (
    SELECT
        a.month,
        ROUND(
            100.0 * COALESCE(c.churned_users, 0)
            / NULLIF(LAG(a.paying_users) OVER (ORDER BY a.month), 0), 2
        ) AS churn_rate_pct
    FROM paying a
    LEFT JOIN (SELECT churn_month, COUNT(*) AS churned_users FROM churn_events GROUP BY 1) c
        ON c.churn_month = a.month
)
SELECT
    COALESCE(mrr.month, mau.month, paying.month) AS month,
    mrr.mrr,
    mau.mau,
    paying.paying_users,
    churn.churn_rate_pct
FROM mrr
FULL JOIN mau USING (month)
FULL JOIN paying USING (month)
LEFT JOIN churn USING (month)
ORDER BY month;
