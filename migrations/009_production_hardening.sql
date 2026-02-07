-- 009_production_hardening.sql
-- H4: trigram search indexes for faster ILIKE queries
-- H6: counter decrement triggers for story deletions
-- M7: soft-delete column on users

-- H4: Trigram indexes for search
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_users_handle_trgm
    ON users USING gin (handle gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_users_display_name_trgm
    ON users USING gin (display_name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_posts_caption_trgm
    ON posts USING gin (caption gin_trgm_ops);

-- H6: Counter decrement triggers for story child-table deletions
-- When story_views rows are deleted (e.g. cascading from story delete or manual cleanup),
-- decrement the parent stories.view_count accordingly.
CREATE OR REPLACE FUNCTION trg_decrement_story_view_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE stories
       SET view_count = GREATEST(view_count - 1, 0)
     WHERE id = OLD.story_id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS story_views_decrement ON story_views;
CREATE TRIGGER story_views_decrement
    AFTER DELETE ON story_views
    FOR EACH ROW
    EXECUTE FUNCTION trg_decrement_story_view_count();

-- Same pattern for story_reactions
CREATE OR REPLACE FUNCTION trg_decrement_story_reaction_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE stories
       SET reaction_count = GREATEST(reaction_count - 1, 0)
     WHERE id = OLD.story_id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS story_reactions_decrement ON story_reactions;
CREATE TRIGGER story_reactions_decrement
    AFTER DELETE ON story_reactions
    FOR EACH ROW
    EXECUTE FUNCTION trg_decrement_story_reaction_count();

-- M7: Soft-delete column on users
ALTER TABLE users ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
