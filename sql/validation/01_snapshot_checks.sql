-- Read-only checks for the 31 August 2026 reporting snapshot.
-- Run with psql -v ON_ERROR_STOP=1 so violations return a failing exit code.

BEGIN READ ONLY;

SELECT 'users after snapshot' AS check_name, COUNT(*) AS violations
FROM users WHERE signup_date > DATE '2026-08-31'
UNION ALL
SELECT 'trial starts after snapshot', COUNT(*)
FROM subscriptions WHERE trial_start > DATE '2026-08-31'
UNION ALL
SELECT 'paid dates after snapshot', COUNT(*)
FROM subscriptions WHERE paid_date > DATE '2026-08-31'
UNION ALL
SELECT 'payments after snapshot', COUNT(*)
FROM payments WHERE payment_date > DATE '2026-08-31'
UNION ALL
SELECT 'events after snapshot', COUNT(*)
FROM events WHERE event_timestamp >= TIMESTAMP '2026-09-01 00:00:00';

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM users WHERE signup_date > DATE '2026-08-31')
       OR EXISTS (SELECT 1 FROM subscriptions WHERE trial_start > DATE '2026-08-31')
       OR EXISTS (SELECT 1 FROM subscriptions WHERE paid_date > DATE '2026-08-31')
       OR EXISTS (SELECT 1 FROM payments WHERE payment_date > DATE '2026-08-31')
       OR EXISTS (SELECT 1 FROM events WHERE event_timestamp >= TIMESTAMP '2026-09-01 00:00:00')
    THEN
        RAISE EXCEPTION 'Snapshot checks failed. Correct the generated dates and reload the project tables.';
    END IF;
END;
$$;

ROLLBACK;
