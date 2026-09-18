-- ============================================================
-- Feature Adoption
-- ============================================================
-- Which features reach the widest share of the user base, and
-- how does that shift by plan tier (useful for upsell targeting:
-- a feature that's a Basic-tier favorite but rare on Enterprise
-- is a different conversation than the reverse).

WITH feature_usage AS (
    SELECT
        feature_name,
        COUNT(*)                   AS total_uses,
        COUNT(DISTINCT user_id)    AS unique_users
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
    ROUND(100.0 * unique_users / t.n, 2)            AS adoption_pct,
    ROUND(total_uses::NUMERIC / unique_users, 1)     AS avg_uses_per_adopter,
    RANK() OVER (ORDER BY unique_users DESC)         AS adoption_rank,
    CASE
        WHEN 100.0 * unique_users / t.n >= 50 THEN 'Core'
        WHEN 100.0 * unique_users / t.n >= 20 THEN 'Growth'
        ELSE 'Niche'
    END AS adoption_tier
FROM feature_usage, total_users t
ORDER BY adoption_rank;

-- ---- Bonus: feature adoption by plan tier ----
WITH plan_totals AS (
    SELECT plan, COUNT(*) AS plan_users FROM subscriptions GROUP BY plan
),
feature_by_plan AS (
    SELECT s.plan, e.feature_name, COUNT(DISTINCT e.user_id) AS adopters
    FROM events e
    JOIN subscriptions s USING (user_id)
    WHERE e.event_name = 'feature_used'
    GROUP BY s.plan, e.feature_name
)
SELECT
    f.plan,
    f.feature_name,
    f.adopters,
    pt.plan_users,
    ROUND(100.0 * f.adopters / pt.plan_users, 2)                AS adoption_pct_within_plan,
    RANK() OVER (PARTITION BY f.plan ORDER BY f.adopters DESC)  AS rank_within_plan
FROM feature_by_plan f
JOIN plan_totals pt USING (plan)
ORDER BY f.plan, rank_within_plan;
