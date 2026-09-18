-- ============================================================
-- Paying User Growth
-- ============================================================
-- Net growth of the paying base over time. Deliberately built
-- from each user's FIRST payment (via ROW_NUMBER), not "had any
-- payment this month" — a customer on their 20th consecutive
-- month isn't growth, they're retention (that's MRR's job, see
-- 03_monthly_recurring_revenue.sql).

WITH first_payment AS (
    SELECT
        user_id,
        payment_date,
        ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY payment_date) AS payment_seq
    FROM payments
),
new_paying_by_month AS (
    SELECT
        DATE_TRUNC('month', payment_date)::DATE AS conversion_month,
        COUNT(*)                                 AS new_paying_users
    FROM first_payment
    WHERE payment_seq = 1
    GROUP BY 1
)
SELECT
    conversion_month,
    new_paying_users,
    SUM(new_paying_users) OVER (ORDER BY conversion_month)                     AS cumulative_paying_users,
    LAG(new_paying_users) OVER (ORDER BY conversion_month)                     AS prev_month_new_paying_users,
    ROUND(
        100.0 * (new_paying_users - LAG(new_paying_users) OVER (ORDER BY conversion_month))
        / NULLIF(LAG(new_paying_users) OVER (ORDER BY conversion_month), 0), 2
    ) AS mom_growth_pct
FROM new_paying_by_month
ORDER BY conversion_month;

-- ---- Bonus: current (point-in-time) paying users by plan tier ----
SELECT
    plan,
    COUNT(*)                                AS paying_users,
    RANK() OVER (ORDER BY COUNT(*) DESC)    AS plan_rank
FROM subscriptions
WHERE status = 'active'
GROUP BY plan
ORDER BY paying_users DESC;
