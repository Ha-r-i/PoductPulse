-- ============================================================
-- Export: Users & Revenue by Country (Power BI — User Behaviour page)
-- ============================================================
WITH rev AS (
    SELECT user_id, SUM(amount) AS revenue FROM payments GROUP BY user_id
)
SELECT
    u.country,
    COUNT(*)                                       AS users,
    COUNT(*) FILTER (WHERE s.status = 'active')    AS active_users,
    COALESCE(SUM(r.revenue), 0)::NUMERIC           AS total_revenue
FROM users u
JOIN subscriptions s USING (user_id)
LEFT JOIN rev r USING (user_id)
GROUP BY u.country
ORDER BY total_revenue DESC;
