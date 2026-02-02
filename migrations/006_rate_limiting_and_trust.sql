-- Phase 1: Rate Limiting and Trust System
-- Migration: 006_rate_limiting_and_trust.sql

-- Trust scoring system
CREATE TABLE IF NOT EXISTS user_trust_scores (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    trust_level INT NOT NULL DEFAULT 0,  -- 0 = new, 1 = basic, 2 = trusted, 3 = verified
    trust_points INT NOT NULL DEFAULT 0,
    account_age_days INT NOT NULL DEFAULT 0,

    -- Activity metrics
    posts_count INT NOT NULL DEFAULT 0,
    comments_count INT NOT NULL DEFAULT 0,
    likes_received_count INT NOT NULL DEFAULT 0,
    followers_count INT NOT NULL DEFAULT 0,

    -- Violation tracking
    flags_received INT NOT NULL DEFAULT 0,
    strikes INT NOT NULL DEFAULT 0,
    banned_until TIMESTAMPTZ,

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_activity_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Device fingerprints for multi-account detection
CREATE TABLE IF NOT EXISTS device_fingerprints (
    fingerprint_hash TEXT PRIMARY KEY,
    first_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Association tracking
    user_ids UUID[] NOT NULL DEFAULT '{}',
    account_count INT NOT NULL DEFAULT 0,

    -- Risk scoring
    risk_score INT NOT NULL DEFAULT 0,  -- 0-100
    is_blocked BOOLEAN NOT NULL DEFAULT FALSE,
    block_reason TEXT,
    blocked_at TIMESTAMPTZ,

    -- Metadata
    user_agent TEXT,
    platform TEXT,
    browser TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_trust_scores_level ON user_trust_scores(trust_level);
CREATE INDEX IF NOT EXISTS idx_trust_scores_updated ON user_trust_scores(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_device_fp_users ON device_fingerprints USING gin(user_ids);
CREATE INDEX IF NOT EXISTS idx_device_fp_risk ON device_fingerprints(risk_score DESC) WHERE risk_score > 50;
CREATE INDEX IF NOT EXISTS idx_device_fp_blocked ON device_fingerprints(is_blocked) WHERE is_blocked = TRUE;

-- Initialize trust scores for existing users
INSERT INTO user_trust_scores (user_id, trust_level, trust_points, account_age_days, created_at)
SELECT
    id,
    0,
    0,
    EXTRACT(DAY FROM (NOW() - created_at))::INT,
    created_at
FROM users
ON CONFLICT (user_id) DO NOTHING;

-- Function to update account age daily
CREATE OR REPLACE FUNCTION update_account_ages()
RETURNS void AS $$
BEGIN
    UPDATE user_trust_scores
    SET account_age_days = EXTRACT(DAY FROM (NOW() - created_at))::INT,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;
