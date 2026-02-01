use anyhow::Result;
use sqlx::Row;
use time::OffsetDateTime;
use uuid::Uuid;

use crate::domain::post::{Post, PostVisibility};
use crate::infra::db::Db;

#[derive(Clone)]
pub struct PostService {
    db: Db,
}

impl PostService {
    pub fn new(db: Db) -> Self {
        Self { db }
    }

    pub async fn create_post(
        &self,
        owner_id: Uuid,
        media_id: Uuid,
        caption: Option<String>,
    ) -> Result<Post> {
        let row = sqlx::query(
            "INSERT INTO posts (owner_id, media_id, caption, visibility) \
             VALUES ($1, $2, $3, $4::post_visibility) \
             RETURNING id, owner_id, media_id, caption, visibility::text AS visibility, created_at",
        )
        .bind(owner_id)
        .bind(media_id)
        .bind(caption)
        .bind(PostVisibility::Public.as_db())
        .fetch_one(self.db.pool())
        .await?;

        let visibility: String = row.get("visibility");
        let visibility = PostVisibility::from_db(&visibility).ok_or_else(|| {
            anyhow::anyhow!("unknown post visibility: {}", visibility)
        })?;

        Ok(Post {
            id: row.get("id"),
            owner_id: row.get("owner_id"),
            media_id: row.get("media_id"),
            caption: row.get("caption"),
            visibility,
            created_at: row.get("created_at"),
        })
    }

    pub async fn get_post(&self, post_id: Uuid, viewer_id: Option<Uuid>) -> Result<Option<Post>> {
        let row = match viewer_id {
            Some(viewer_id) => {
                sqlx::query(
                    "SELECT id, owner_id, media_id, caption, visibility::text AS visibility, created_at \
                     FROM posts \
                     WHERE id = $1 \
                       AND (visibility = 'public' \
                            OR owner_id = $2 \
                            OR (visibility = 'followers_only' AND EXISTS ( \
                                SELECT 1 FROM follows WHERE follower_id = $2 AND followee_id = owner_id \
                            ))) \
                       AND NOT EXISTS ( \
                           SELECT 1 FROM blocks \
                           WHERE (blocker_id = owner_id AND blocked_id = $2) \
                              OR (blocker_id = $2 AND blocked_id = owner_id) \
                       )",
                )
                .bind(post_id)
                .bind(viewer_id)
                .fetch_optional(self.db.pool())
                .await?
            }
            None => {
                sqlx::query(
                    "SELECT id, owner_id, media_id, caption, visibility::text AS visibility, created_at \
                     FROM posts \
                     WHERE id = $1 AND visibility = 'public'",
                )
                .bind(post_id)
                .fetch_optional(self.db.pool())
                .await?
            }
        };

        let post = match row {
            Some(row) => {
                let visibility: String = row.get("visibility");
                let visibility = PostVisibility::from_db(&visibility)
                    .ok_or_else(|| anyhow::anyhow!("unknown post visibility: {}", visibility))?;
                Some(Post {
                    id: row.get("id"),
                    owner_id: row.get("owner_id"),
                    media_id: row.get("media_id"),
                    caption: row.get("caption"),
                    visibility,
                    created_at: row.get("created_at"),
                })
            }
            None => None,
        };

        Ok(post)
    }

    pub async fn update_caption(
        &self,
        post_id: Uuid,
        owner_id: Uuid,
        caption: Option<String>,
    ) -> Result<Option<Post>> {
        let row = sqlx::query(
            "UPDATE posts \
             SET caption = $3 \
             WHERE id = $1 AND owner_id = $2 \
             RETURNING id, owner_id, media_id, caption, visibility::text AS visibility, created_at",
        )
        .bind(post_id)
        .bind(owner_id)
        .bind(caption)
        .fetch_optional(self.db.pool())
        .await?;

        let post = match row {
            Some(row) => {
                let visibility: String = row.get("visibility");
                let visibility = PostVisibility::from_db(&visibility)
                    .ok_or_else(|| anyhow::anyhow!("unknown post visibility: {}", visibility))?;
                Some(Post {
                    id: row.get("id"),
                    owner_id: row.get("owner_id"),
                    media_id: row.get("media_id"),
                    caption: row.get("caption"),
                    visibility,
                    created_at: row.get("created_at"),
                })
            }
            None => None,
        };

        Ok(post)
    }

    pub async fn delete_post(&self, post_id: Uuid, owner_id: Uuid) -> Result<bool> {
        let result = sqlx::query("DELETE FROM posts WHERE id = $1 AND owner_id = $2")
            .bind(post_id)
            .bind(owner_id)
            .execute(self.db.pool())
            .await?;

        Ok(result.rows_affected() > 0)
    }

    pub async fn list_by_user(
        &self,
        owner_id: Uuid,
        viewer_id: Option<Uuid>,
        cursor: Option<(OffsetDateTime, Uuid)>,
        limit: i64,
    ) -> Result<Vec<Post>> {
        let rows = match viewer_id {
            Some(viewer_id) => match cursor {
                Some((created_at, post_id)) => {
                    sqlx::query(
                        "SELECT id, owner_id, media_id, caption, visibility::text AS visibility, created_at \
                         FROM posts \
                         WHERE owner_id = $1 \
                           AND (visibility = 'public' \
                                OR owner_id = $2 \
                                OR (visibility = 'followers_only' AND EXISTS ( \
                                    SELECT 1 FROM follows WHERE follower_id = $2 AND followee_id = owner_id \
                                ))) \
                           AND NOT EXISTS ( \
                               SELECT 1 FROM blocks \
                               WHERE (blocker_id = owner_id AND blocked_id = $2) \
                                  OR (blocker_id = $2 AND blocked_id = owner_id) \
                           ) \
                           AND (created_at < $3 OR (created_at = $3 AND id < $4)) \
                         ORDER BY created_at DESC, id DESC \
                         LIMIT $5",
                    )
                    .bind(owner_id)
                    .bind(viewer_id)
                    .bind(created_at)
                    .bind(post_id)
                    .bind(limit)
                    .fetch_all(self.db.pool())
                    .await?
                }
                None => {
                    sqlx::query(
                    "SELECT id, owner_id, media_id, caption, visibility::text AS visibility, created_at \
                     FROM posts \
                     WHERE owner_id = $1 \
                       AND (visibility = 'public' \
                            OR owner_id = $2 \
                            OR (visibility = 'followers_only' AND EXISTS ( \
                                SELECT 1 FROM follows WHERE follower_id = $2 AND followee_id = owner_id \
                            ))) \
                       AND NOT EXISTS ( \
                           SELECT 1 FROM blocks \
                           WHERE (blocker_id = owner_id AND blocked_id = $2) \
                              OR (blocker_id = $2 AND blocked_id = owner_id) \
                       ) \
                     ORDER BY created_at DESC, id DESC \
                     LIMIT $3",
                    )
                    .bind(owner_id)
                    .bind(viewer_id)
                    .bind(limit)
                    .fetch_all(self.db.pool())
                    .await?
                }
            },
            None => match cursor {
                Some((created_at, post_id)) => {
                    sqlx::query(
                        "SELECT id, owner_id, media_id, caption, visibility::text AS visibility, created_at \
                         FROM posts \
                         WHERE owner_id = $1 \
                           AND visibility = 'public' \
                           AND (created_at < $2 OR (created_at = $2 AND id < $3)) \
                         ORDER BY created_at DESC, id DESC \
                         LIMIT $4",
                    )
                    .bind(owner_id)
                    .bind(created_at)
                    .bind(post_id)
                    .bind(limit)
                    .fetch_all(self.db.pool())
                    .await?
                }
                None => {
                    sqlx::query(
                        "SELECT id, owner_id, media_id, caption, visibility::text AS visibility, created_at \
                         FROM posts \
                         WHERE owner_id = $1 AND visibility = 'public' \
                         ORDER BY created_at DESC, id DESC \
                         LIMIT $2",
                    )
                    .bind(owner_id)
                    .bind(limit)
                    .fetch_all(self.db.pool())
                    .await?
                }
            },
        };

        let mut posts = Vec::with_capacity(rows.len());
        for row in rows {
            let visibility: String = row.get("visibility");
            let visibility = PostVisibility::from_db(&visibility)
                .ok_or_else(|| anyhow::anyhow!("unknown post visibility: {}", visibility))?;
            posts.push(Post {
                id: row.get("id"),
                owner_id: row.get("owner_id"),
                media_id: row.get("media_id"),
                caption: row.get("caption"),
                visibility,
                created_at: row.get("created_at"),
            });
        }

        Ok(posts)
    }
}
