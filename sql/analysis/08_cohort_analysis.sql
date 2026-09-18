-- ============================================================
-- Cohort Analysis (retention heatmap)
-- ============================================================
-- Long-format cohort_month x period_number retention matrix —
-- feeds a Power BI matrix visual directly (rows = cohort_month,
-- columns = period_number, values = retention_pct) for the
-- classic cohort heatmap. period_number = months since the
-- cohort's own signup month (0 = signup month itself).

WITH cohort AS (
    SELECT user_id, DATE_TRUNC('month', signup_date)::DATE AS cohort_month
    FROM users
),
activity_month AS (
    SELECT DISTINCT user_id, DATE_TRUNC('month', event_timestamp)::DATE AS active_month
    FROM events
),
cohort_activity AS (
    SELECT
        c.user_id,
        c.cohort_month,
        (EXTRACT(YEAR FROM a.active_month) - EXTRACT(YEAR FROM c.cohort_month)) * 12
            + (EXTRACT(MONTH FROM a.active_month) - EXTRACT(MONTH FROM c.cohort_month)) AS period_number
    FROM cohort c
    JOIN activity_month a
        ON a.user_id = c.user_id
       AND a.active_month >= c.cohort_month
),
cohort_size AS (
    SELECT cohort_month, COUNT(*) AS cohort_size
    FROM cohort
    GROUP BY cohort_month
)
SELECT
    ca.cohort_month,
    ca.period_number::INT                                                AS period_number,
    cs.cohort_size,
    COUNT(DISTINCT ca.user_id)                                           AS active_users,
    ROUND(100.0 * COUNT(DISTINCT ca.user_id) / cs.cohort_size, 2)        AS retention_pct
FROM cohort_activity ca
JOIN cohort_size cs USING (cohort_month)
WHERE ca.period_number BETWEEN 0 AND 12   -- first year of a cohort's life is the standard heatmap window
GROUP BY ca.cohort_month, ca.period_number, cs.cohort_size
ORDER BY ca.cohort_month, ca.period_number;
