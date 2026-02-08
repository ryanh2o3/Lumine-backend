-- Allow admin-only moderation actions without a linked user
ALTER TABLE moderation_actions ALTER COLUMN actor_id DROP NOT NULL;
