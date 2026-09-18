-- ============================================================
-- 7-Day Retention
-- ============================================================
-- Of users who signed up in a given month, what % came back and
-- generated at least one event on exactly day 7 after their own
-- signup date? (The standard "Day-N retention" definition.)
--
-- Cohorts that haven't had 7 days to mature yet as of the most
-- recent data are excluded — otherwise they'd show artificially
-- low retention just for being too new to measure.

WITH bounds AS (
    SELECT MAX(event_timestamp)::DATE AS max_observed_date FROM events
),
cohort AS (
    SELECT u.user_id, u.signup_date, DATE_TRUNC('month', u.signup_date)::DATE AS cohort_month
    FROM users u, bounds b
    WHERE u.signup_date + 7 <= b.max_observed_date
),
day7_active AS (
    SELECT DISTINCT c.user_id
    FROM cohort c
    JOIN events e
        ON e.user_id = c.user_id
       AND e.event_timestamp::DATE = c.signup_date + 7
)
SELECT
    c.cohort_month,
    COUNT(DISTINCT c.user_id)                                             AS cohort_size,
    COUNT(DISTINCT d.user_id)                                             AS retained_day7,
    ROUND(100.0 * COUNT(DISTINCT d.user_id) / COUNT(DISTINCT c.user_id), 2) AS day7_retention_pct
FROM cohort c
LEFT JOIN day7_active d ON d.user_id = c.user_id
GROUP BY c.cohort_month
ORDER BY c.cohort_month;
