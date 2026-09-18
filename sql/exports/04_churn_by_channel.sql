-- ============================================================
-- Export: Lifetime Churn Rate by Acquisition Channel (Power BI — Retention page)
-- ============================================================
SELECT
    u.acquisition_channel,
    COUNT(*) FILTER (WHERE s.paid_date IS NOT NULL)                        AS ever_paid,
    COUNT(*) FILTER (WHERE s.paid_date IS NOT NULL AND s.status = 'churned') AS churned,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE s.paid_date IS NOT NULL AND s.status = 'churned')
        / NULLIF(COUNT(*) FILTER (WHERE s.paid_date IS NOT NULL), 0), 2
    ) AS churn_rate_pct
FROM users u
JOIN subscriptions s USING (user_id)
GROUP BY u.acquisition_channel
ORDER BY churn_rate_pct DESC;
