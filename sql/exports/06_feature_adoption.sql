-- ============================================================
-- Export: Feature Adoption (Power BI — User Behaviour page)
-- ============================================================
WITH feature_usage AS (
    SELECT
        feature_name,
        COUNT(*)                AS total_uses,
        COUNT(DISTINCT user_id) AS unique_users
    FROM events
    WHERE event_name = 'feature_used'
    GROUP BY feature_name
),
total_users AS (
    SELECT COUNT(*) AS n FROM users
)
SELECT
    feature_name,
    unique_users,
    total_uses,
    ROUND(100.0 * unique_users / t.n, 2) AS adoption_pct
FROM feature_usage, total_users t
ORDER BY unique_users DESC;
