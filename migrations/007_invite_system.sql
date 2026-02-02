-- Phase 3: Invite-Only Signup System
-- Migration: 007_invite_system.sql

-- Invite codes table
CREATE TABLE IF NOT EXISTS invite_codes (
    code VARCHAR(16) PRIMARY KEY,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    used_by UUID REFERENCES users(id) ON DELETE SET NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    used_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ NOT NULL,

    is_valid BOOLEAN NOT NULL DEFAULT TRUE,

    -- Metadata
    invite_type TEXT NOT NULL DEFAULT 'standard',  -- 'standard', 'admin', 'beta'
    max_uses INT NOT NULL DEFAULT 1,
    use_count INT NOT NULL DEFAULT 0,

    -- Optional metadata
    metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_invite_codes_creator ON invite_codes(created_by);
CREATE INDEX IF NOT EXISTS idx_invite_codes_valid ON invite_codes(is_valid, expires_at) WHERE is_valid = TRUE;
CREATE INDEX IF NOT EXISTS idx_invite_codes_expires ON invite_codes(expires_at);

-- Track invite trees (who invited whom)
CREATE TABLE IF NOT EXISTS invite_relationships (
    inviter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invitee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invite_code VARCHAR(16) NOT NULL,
    invited_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (inviter_id, invitee_id)
);

CREATE INDEX IF NOT EXISTS idx_invite_tree_inviter ON invite_relationships(inviter_id);
CREATE INDEX IF NOT EXISTS idx_invite_tree_invitee ON invite_relationships(invitee_id);
CREATE INDEX IF NOT EXISTS idx_invite_tree_code ON invite_relationships(invite_code);

-- Add invite tracking to user_trust_scores
ALTER TABLE user_trust_scores
ADD COLUMN IF NOT EXISTS invites_sent INT NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS successful_invites INT NOT NULL DEFAULT 0;

-- Function to clean up expired invites (run periodically)
CREATE OR REPLACE FUNCTION cleanup_expired_invites()
RETURNS INT AS $$
DECLARE
    deleted_count INT;
BEGIN
    WITH deleted AS (
        DELETE FROM invite_codes
        WHERE expires_at < NOW() - INTERVAL '30 days'
          AND is_valid = FALSE
        RETURNING 1
    )
    SELECT COUNT(*) INTO deleted_count FROM deleted;

    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;
