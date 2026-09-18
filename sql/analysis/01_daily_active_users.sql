-- ============================================================
-- Daily Active Users (DAU)
-- ============================================================
-- One row per calendar day: how many distinct users generated at
-- least one product event that day, plus day-over-day change.

WITH daily AS (
    SELECT
        DATE_TRUNC('day', event_timestamp)::DATE AS activity_date,
        COUNT(DISTINCT user_id)                   AS dau
    FROM events
    GROUP BY 1
)
SELECT
    activity_date,
    dau,
    LAG(dau) OVER (ORDER BY activity_date)          AS prev_day_dau,
    dau - LAG(dau) OVER (ORDER BY activity_date)     AS day_over_day_change,
    ROUND(
        100.0 * (dau - LAG(dau) OVER (ORDER BY activity_date))
        / NULLIF(LAG(dau) OVER (ORDER BY activity_date), 0), 2
    ) AS day_over_day_pct_change
FROM daily
ORDER BY activity_date;
