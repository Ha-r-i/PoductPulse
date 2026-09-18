-- ============================================================
-- Monthly Active Users (MAU) + DAU/MAU Stickiness
-- ============================================================
-- MAU by calendar month, month-over-month change, and the
-- standard "stickiness" ratio (avg DAU that month / MAU that
-- month) — a common read on how habitual usage actually is,
-- not just how many people touched the product at all.

WITH daily AS (
    SELECT
        DATE_TRUNC('day', event_timestamp)::DATE   AS activity_date,
        COUNT(DISTINCT user_id)                     AS dau
    FROM events
    GROUP BY 1
),
avg_dau_by_month AS (
    SELECT
        DATE_TRUNC('month', activity_date)::DATE AS activity_month,
        AVG(dau)                                  AS avg_dau
    FROM daily
    GROUP BY 1
),
monthly AS (
    SELECT
        DATE_TRUNC('month', event_timestamp)::DATE AS activity_month,
        COUNT(DISTINCT user_id)                     AS mau
    FROM events
    GROUP BY 1
)
SELECT
    m.activity_month,
    m.mau,
    LAG(m.mau) OVER (ORDER BY m.activity_month)                                AS prev_month_mau,
    ROUND(
        100.0 * (m.mau - LAG(m.mau) OVER (ORDER BY m.activity_month))
        / NULLIF(LAG(m.mau) OVER (ORDER BY m.activity_month), 0), 2
    )                                                                          AS mom_pct_change,
    ROUND(a.avg_dau, 1)                                                        AS avg_dau,
    ROUND(100.0 * a.avg_dau / NULLIF(m.mau, 0), 2)                             AS stickiness_pct
FROM monthly m
JOIN avg_dau_by_month a USING (activity_month)
ORDER BY m.activity_month;
