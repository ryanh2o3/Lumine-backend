DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'follows_not_self'
    ) THEN
        ALTER TABLE follows
            ADD CONSTRAINT follows_not_self CHECK (follower_id <> followee_id);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'blocks_not_self'
    ) THEN
        ALTER TABLE blocks
            ADD CONSTRAINT blocks_not_self CHECK (blocker_id <> blocked_id);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_blocks_blocked_blocker ON blocks(blocked_id, blocker_id);
