-- ============================================================
-- 30-Day Retention
-- ============================================================
-- Same definition as 7-day retention, measured at day 30 instead.
-- Comparing the two side by side is usually the more interesting
-- read: a cohort that holds up well at day 7 but falls off sharply
-- by day 30 points at an onboarding problem, not an acquisition one.

WITH bounds AS (
    SELECT MAX(event_timestamp)::DATE AS max_observed_date FROM events
),
cohort AS (
    SELECT u.user_id, u.signup_date, DATE_TRUNC('month', u.signup_date)::DATE AS cohort_month
    FROM users u, bounds b
    WHERE u.signup_date + 30 <= b.max_observed_date
),
day30_active AS (
    SELECT DISTINCT c.user_id
    FROM cohort c
    JOIN events e
        ON e.user_id = c.user_id
       AND e.event_timestamp::DATE = c.signup_date + 30
)
SELECT
    c.cohort_month,
    COUNT(DISTINCT c.user_id)                                              AS cohort_size,
    COUNT(DISTINCT d.user_id)                                              AS retained_day30,
    ROUND(100.0 * COUNT(DISTINCT d.user_id) / COUNT(DISTINCT c.user_id), 2) AS day30_retention_pct
FROM cohort c
LEFT JOIN day30_active d ON d.user_id = c.user_id
GROUP BY c.cohort_month
ORDER BY c.cohort_month;
