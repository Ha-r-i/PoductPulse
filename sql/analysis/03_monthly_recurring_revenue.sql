-- ============================================================
-- Monthly Recurring Revenue (MRR)
-- ============================================================
-- Total MRR by month, month-over-month growth, and a simple
-- New vs. Retained decomposition (CASE WHEN classifying each
-- user-month against their own prior month via LAG). There's no
-- Expansion/Contraction component here because this schema has
-- no mid-life plan-change history — every user pays one flat
-- amount for their whole lifetime, so the only two things that
-- can move MRR are someone starting or someone stopping.

WITH user_monthly AS (
    SELECT
        user_id,
        DATE_TRUNC('month', payment_date)::DATE AS revenue_month,
        SUM(amount)                              AS user_mrr
    FROM payments
    GROUP BY 1, 2
),
with_prev AS (
    SELECT
        user_id,
        revenue_month,
        user_mrr,
        LAG(revenue_month) OVER (PARTITION BY user_id ORDER BY revenue_month) AS prev_month
    FROM user_monthly
),
monthly_mrr AS (
    SELECT
        revenue_month,
        SUM(user_mrr) AS mrr,
        SUM(CASE WHEN prev_month IS NULL THEN user_mrr ELSE 0 END)                                   AS new_mrr,
        SUM(CASE WHEN prev_month = revenue_month - INTERVAL '1 month' THEN user_mrr ELSE 0 END)      AS retained_mrr
    FROM with_prev
    GROUP BY 1
)
SELECT
    revenue_month,
    mrr,
    new_mrr,
    retained_mrr,
    LAG(mrr) OVER (ORDER BY revenue_month)                                    AS prev_month_mrr,
    ROUND(
        100.0 * (mrr - LAG(mrr) OVER (ORDER BY revenue_month))
        / NULLIF(LAG(mrr) OVER (ORDER BY revenue_month), 0), 2
    ) AS mom_growth_pct
FROM monthly_mrr
ORDER BY revenue_month;
