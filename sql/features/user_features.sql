-- ============================================================
-- User Feature Table
-- ============================================================
-- One row per user, aggregating identity + behavior + revenue.
-- Shared foundation for the EDA notebook (segmentation, correlation)
-- and the churn model — built once here rather than re-derived
-- separately in each notebook.

WITH bounds AS (
    SELECT MAX(event_timestamp) AS as_of FROM events
),
user_activity AS (
    SELECT
        user_id,
        COUNT(*)                                                              AS total_events,
        COUNT(DISTINCT session_id)                                            AS total_sessions,
        COUNT(DISTINCT feature_name) FILTER (WHERE event_name = 'feature_used') AS distinct_features_used,
        MIN(event_timestamp)                                                  AS first_event_at,
        MAX(event_timestamp)                                                  AS last_event_at
    FROM events
    GROUP BY user_id
),
user_revenue AS (
    SELECT user_id, COUNT(*) AS total_payments, SUM(amount) AS total_revenue
    FROM payments
    GROUP BY user_id
)
SELECT
    u.user_id,
    u.signup_date,
    u.country,
    u.acquisition_channel,
    s.plan,
    s.status,
    (s.paid_date IS NOT NULL)                                            AS converted,
    (s.status = 'churned')                                               AS is_churned,
    COALESCE(r.total_payments, 0)                                        AS total_payments,
    COALESCE(r.total_revenue, 0)::NUMERIC                                AS total_revenue,
    COALESCE(a.total_events, 0)                                          AS total_events,
    COALESCE(a.total_sessions, 0)                                        AS total_sessions,
    COALESCE(a.distinct_features_used, 0)                                AS distinct_features_used,
    EXTRACT(DAY FROM (b.as_of - u.signup_date::timestamp))::INT          AS tenure_days,
    EXTRACT(DAY FROM (b.as_of - COALESCE(a.last_event_at, u.signup_date::timestamp)))::INT AS recency_days
FROM users u
JOIN subscriptions s USING (user_id)
LEFT JOIN user_activity a USING (user_id)
LEFT JOIN user_revenue r USING (user_id)
CROSS JOIN bounds b;
