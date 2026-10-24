-- Churn-model features and a 90-day target.
-- Features use activity observed by the cutoff. Eligibility also uses snapshot
-- status or later payments, so population selection is not prospective.
-- Usage is simulated using known churn outcomes. See docs/project_review.md.

WITH cutoff AS (
    SELECT (SELECT MAX(event_timestamp) FROM events) - INTERVAL '90 days' AS cutoff_date
),
eligible AS (
    -- Eligibility uses current status or post-cutoff payments.
    SELECT s.user_id, s.plan, s.status, s.paid_date, u.acquisition_channel, u.country, u.signup_date
    FROM subscriptions s
    JOIN users u USING (user_id)
    CROSS JOIN cutoff c
    WHERE s.paid_date IS NOT NULL
      AND s.paid_date <= c.cutoff_date
      AND (
            s.status = 'active'
            OR EXISTS (SELECT 1 FROM payments p WHERE p.user_id = s.user_id AND p.payment_date > c.cutoff_date)
          )
),
pre_cutoff_activity AS (
    SELECT
        e.user_id,
        COUNT(*) FILTER (WHERE e.event_timestamp > c.cutoff_date - INTERVAL '30 days')  AS events_last_30d,
        COUNT(*) FILTER (WHERE e.event_timestamp > c.cutoff_date - INTERVAL '90 days')  AS events_last_90d,
        COUNT(DISTINCT e.session_id) FILTER (WHERE e.event_timestamp > c.cutoff_date - INTERVAL '90 days') AS sessions_last_90d,
        COUNT(DISTINCT e.feature_name) FILTER (WHERE e.event_name = 'feature_used')     AS distinct_features_used,
        MAX(e.event_timestamp)                                                          AS last_event_before_cutoff
    FROM events e
    CROSS JOIN cutoff c
    WHERE e.event_timestamp <= c.cutoff_date
    GROUP BY e.user_id
),
pre_cutoff_revenue AS (
    SELECT p.user_id, COUNT(*) AS payments_before_cutoff, SUM(p.amount) AS revenue_before_cutoff
    FROM payments p
    CROSS JOIN cutoff c
    WHERE p.payment_date <= c.cutoff_date
    GROUP BY p.user_id
)
SELECT
    el.user_id,
    el.plan,
    el.acquisition_channel,
    el.country,
    EXTRACT(DAY FROM (c.cutoff_date - el.signup_date::timestamp))::INT                                        AS tenure_days_at_cutoff,
    EXTRACT(DAY FROM (c.cutoff_date - COALESCE(a.last_event_before_cutoff, el.signup_date::timestamp)))::INT  AS recency_days_at_cutoff,
    COALESCE(a.events_last_30d, 0)             AS events_last_30d,
    COALESCE(a.events_last_90d, 0)             AS events_last_90d,
    COALESCE(a.sessions_last_90d, 0)           AS sessions_last_90d,
    COALESCE(a.distinct_features_used, 0)      AS distinct_features_used,
    COALESCE(r.payments_before_cutoff, 0)      AS payments_before_cutoff,
    COALESCE(r.revenue_before_cutoff, 0)::NUMERIC AS revenue_before_cutoff,
    (el.status = 'churned')::INT               AS churned_after_cutoff   -- the label
FROM eligible el
CROSS JOIN cutoff c
LEFT JOIN pre_cutoff_activity a ON a.user_id = el.user_id
LEFT JOIN pre_cutoff_revenue r ON r.user_id = el.user_id;
