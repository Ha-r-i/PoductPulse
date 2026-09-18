-- ============================================================
-- Export: Daily Activity (Power BI — User Behaviour page)
-- ============================================================
SELECT
    DATE_TRUNC('day', event_timestamp)::DATE AS date,
    COUNT(DISTINCT user_id)                   AS dau,
    COUNT(DISTINCT session_id)                AS sessions
FROM events
GROUP BY 1
ORDER BY 1;
