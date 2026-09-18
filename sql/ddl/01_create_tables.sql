-- ============================================================
-- ProductPulse — Core Schema
-- ============================================================
-- Run against a dedicated database:
--   createdb productpulse
--   psql -d productpulse -f sql/ddl/01_create_tables.sql
--
-- Four production-style tables. See docs/data_dictionary.md for
-- which columns come from the real IBM Telco Customer Churn dataset
-- vs. which are generated (and how).
-- ============================================================

-- Drop in dependency order so this script is safe to re-run during development
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS subscriptions CASCADE;
DROP TABLE IF EXISTS events CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- ------------------------------------------------------------
-- users — one row per customer account. Core identity table
-- every other table references.
-- ------------------------------------------------------------
CREATE TABLE users (
    user_id             VARCHAR(20)  PRIMARY KEY,
    signup_date         DATE         NOT NULL,
    country             VARCHAR(56)  NOT NULL,
    acquisition_channel VARCHAR(30)  NOT NULL
);

COMMENT ON TABLE users IS
    'One row per customer account.';
COMMENT ON COLUMN users.acquisition_channel IS
    'Marketing channel that brought the user in, e.g. Organic Search, Paid Social, Referral.';

-- ------------------------------------------------------------
-- events — product usage / clickstream log. Many rows per user.
-- ------------------------------------------------------------
CREATE TABLE events (
    event_id        BIGSERIAL     PRIMARY KEY,
    user_id         VARCHAR(20)   NOT NULL REFERENCES users(user_id),
    event_name      VARCHAR(50)   NOT NULL,
    feature_name    VARCHAR(50),                 -- NULL for non-feature events (login/logout)
    event_timestamp TIMESTAMP     NOT NULL,
    session_id      VARCHAR(40)   NOT NULL
);

COMMENT ON TABLE events IS
    'Product usage event log — one row per user action (login, feature use, logout).';
COMMENT ON COLUMN events.feature_name IS
    'Populated only when event_name = ''feature_used''; NULL for session/login-level events.';

-- Supports the DAU/MAU, funnel, and retention queries we'll write in Module 4-5
CREATE INDEX idx_events_user_id    ON events(user_id);
CREATE INDEX idx_events_timestamp  ON events(event_timestamp);
CREATE INDEX idx_events_session_id ON events(session_id);

-- ------------------------------------------------------------
-- subscriptions — current subscription lifecycle state.
-- One row per user (this is a snapshot table, not a history table —
-- see docs/data_dictionary.md for why that scope is deliberate).
-- ------------------------------------------------------------
CREATE TABLE subscriptions (
    user_id     VARCHAR(20)  PRIMARY KEY REFERENCES users(user_id),
    plan        VARCHAR(20)  NOT NULL CHECK (plan IN ('Basic', 'Pro', 'Enterprise')),
    status      VARCHAR(20)  NOT NULL CHECK (status IN ('trialing', 'active', 'churned')),
    trial_start DATE         NOT NULL,
    paid_date   DATE                              -- NULL if the user never converted from trial
);

COMMENT ON TABLE subscriptions IS
    'Subscription lifecycle state per user. paid_date IS NULL identifies trial users who never converted.';

-- ------------------------------------------------------------
-- payments — individual billing transactions. Many rows per user.
-- ------------------------------------------------------------
CREATE TABLE payments (
    payment_id   BIGSERIAL     PRIMARY KEY,
    user_id      VARCHAR(20)   NOT NULL REFERENCES users(user_id),
    amount       NUMERIC(10,2) NOT NULL CHECK (amount >= 0),
    payment_date DATE          NOT NULL
);

COMMENT ON TABLE payments IS
    'One row per successful billing charge. Drives MRR and revenue-trend analyses.';

CREATE INDEX idx_payments_user_id      ON payments(user_id);
CREATE INDEX idx_payments_payment_date ON payments(payment_date);
