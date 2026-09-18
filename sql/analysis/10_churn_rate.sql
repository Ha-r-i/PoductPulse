-- ============================================================
-- Churn Rate
-- ============================================================
-- Standard SaaS monthly churn rate: customers who stopped paying
-- this month, as a % of customers who were paying last month
-- (LAG supplies the denominator). A user's "churn month" is the
-- month after their last recorded payment.

WITH user_last_payment AS (
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
    WHERE last_payment_month < max_month   -- still paying as of the last observed month = not churned yet
),
active_by_month AS (
    SELECT DATE_TRUNC('month', payment_date)::DATE AS activity_month, COUNT(DISTINCT user_id) AS active_paying_users
    FROM payments
    GROUP BY 1
),
churned_by_month AS (
    SELECT churn_month, COUNT(*) AS churned_users
    FROM churn_events
    GROUP BY churn_month
)
SELECT
    a.activity_month,
    a.active_paying_users,
    COALESCE(c.churned_users, 0)                                                        AS churned_users,
    LAG(a.active_paying_users) OVER (ORDER BY a.activity_month)                          AS prior_month_base,
    ROUND(
        100.0 * COALESCE(c.churned_users, 0)
        / NULLIF(LAG(a.active_paying_users) OVER (ORDER BY a.activity_month), 0), 2
    ) AS monthly_churn_rate_pct
FROM active_by_month a
LEFT JOIN churned_by_month c ON c.churn_month = a.activity_month
ORDER BY a.activity_month;

-- ---- Bonus: overall (lifetime) churn rate among everyone who ever paid ----
SELECT
    COUNT(*) FILTER (WHERE paid_date IS NOT NULL)                     AS ever_paid,
    COUNT(*) FILTER (WHERE paid_date IS NOT NULL AND status = 'churned') AS churned_after_paying,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE paid_date IS NOT NULL AND status = 'churned')
        / COUNT(*) FILTER (WHERE paid_date IS NOT NULL), 2
    ) AS lifetime_churn_rate_pct
FROM subscriptions;
