-- ============================================================
-- Export: Conversion Funnel (Power BI — Conversion Funnel page)
-- ============================================================
-- Single-query export of the main funnel stages from
-- sql/analysis/05_conversion_funnel.sql (kept as one query per file
-- here since Power BI's CSV import expects exactly one result set).

WITH funnel_base AS (
    SELECT
        u.user_id,
        s.trial_start,
        s.paid_date,
        s.status,
        EXISTS (
            SELECT 1
            FROM events e
            WHERE e.user_id = u.user_id
              AND e.event_name = 'feature_used'
              AND e.event_timestamp >= s.trial_start
              AND e.event_timestamp < s.trial_start + INTERVAL '14 days'
        ) AS activated_in_trial
    FROM users u
    JOIN subscriptions s USING (user_id)
),
funnel_counts AS (
    SELECT
        COUNT(*)                                       AS signed_up,
        COUNT(*) FILTER (WHERE activated_in_trial)     AS activated,
        COUNT(*) FILTER (WHERE paid_date IS NOT NULL)  AS paid,
        COUNT(*) FILTER (WHERE status = 'active')      AS retained_active
    FROM funnel_base
)
SELECT 1 AS stage_order, 'Signed Up'                           AS stage, signed_up      AS users FROM funnel_counts
UNION ALL
SELECT 2, 'Activated', activated FROM funnel_counts
UNION ALL
SELECT 3, 'Paid',      paid            FROM funnel_counts
UNION ALL
SELECT 4, 'Retained',  retained_active FROM funnel_counts
ORDER BY stage_order;
