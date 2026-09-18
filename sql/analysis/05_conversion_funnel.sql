-- ============================================================
-- Conversion Funnel
-- ============================================================
-- The brief's "Visitor -> Signup -> Trial -> Paid" funnel can't be
-- built from this schema exactly as specified: there's no pre-signup
-- traffic data in these four tables (see docs/data_dictionary.md,
-- "Known deviation"). Real product databases have the same gap —
-- that data lives in a separate web-analytics tool, not here.
--
-- Adapted to four stages this schema CAN measure:
--   Signed Up -> Activated -> Paid -> Retained (active today)
-- "Trial Started" is dropped too: trial_start always equals
-- signup_date in this model (the trial begins immediately), so it
-- would just repeat the Signed Up count with no new information.
-- "Activated" (used >=1 feature during the 14-day trial) is a
-- standard, more useful product-led-growth substitute.

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
),
funnel_stages AS (
    SELECT 1 AS stage_order, 'Signed Up'                           AS stage, signed_up      AS users FROM funnel_counts
    UNION ALL
    SELECT 2, 'Activated (used a feature in trial)', activated FROM funnel_counts
    UNION ALL
    SELECT 3, 'Paid',                     paid            FROM funnel_counts
    UNION ALL
    SELECT 4, 'Retained (active today)',  retained_active FROM funnel_counts
)
SELECT
    stage,
    users,
    ROUND(100.0 * users / FIRST_VALUE(users) OVER (ORDER BY stage_order), 2) AS pct_of_signups,
    ROUND(100.0 * users / LAG(users) OVER (ORDER BY stage_order), 2)         AS pct_of_prev_stage
FROM funnel_stages
ORDER BY stage_order;

-- ---- Bonus: which acquisition channel converts trial -> paid best? ----
WITH channel_funnel AS (
    SELECT
        u.acquisition_channel,
        COUNT(*)                                          AS signed_up,
        COUNT(*) FILTER (WHERE s.paid_date IS NOT NULL)    AS paid
    FROM users u
    JOIN subscriptions s USING (user_id)
    GROUP BY u.acquisition_channel
)
SELECT
    acquisition_channel,
    signed_up,
    paid,
    ROUND(100.0 * paid / signed_up, 2)                          AS conversion_pct,
    RANK() OVER (ORDER BY (paid::NUMERIC / signed_up) DESC)     AS conversion_rank
FROM channel_funnel
ORDER BY conversion_rank;
