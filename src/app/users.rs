use anyhow::Result;
use sqlx::Row;
use uuid::Uuid;

use crate::domain::user::User;
use crate::infra::db::Db;

#[derive(Clone)]
pub struct UserService {
    db: Db,
}

impl UserService {
    pub fn new(db: Db) -> Self {
        Self { db }
    }

    pub async fn get_user(&self, _user_id: Uuid) -> Result<Option<User>> {
        let row = sqlx::query(
            "SELECT id, handle, email, display_name, bio, avatar_key, created_at \
             FROM users WHERE id = $1 AND deleted_at IS NULL",
        )
        .bind(_user_id)
        .fetch_optional(self.db.pool())
        .await?;

        let user = row.map(|row| User {
            id: row.get("id"),
            handle: row.get("handle"),
            email: row.get("email"),
            display_name: row.get("display_name"),
            bio: row.get("bio"),
            avatar_key: row.get("avatar_key"),
            avatar_url: None,
            created_at: row.get("created_at"),
        });

        Ok(user)
    }


    pub async fn get_public_user_with_counts(&self, user_id: Uuid) -> Result<Option<(User, i64, i64, i64)>> {
        let row = sqlx::query(
            "SELECT u.id, u.handle, u.email, u.display_name, u.bio, u.avatar_key, u.created_at, \
                    (SELECT COUNT(*) FROM follows WHERE followee_id = u.id) AS followers_count, \
                    (SELECT COUNT(*) FROM follows WHERE follower_id = u.id) AS following_count, \
                    (SELECT COUNT(*) FROM posts WHERE owner_id = u.id) AS posts_count \
             FROM users u WHERE u.id = $1 AND u.deleted_at IS NULL",
        )
        .bind(user_id)
        .fetch_optional(self.db.pool())
        .await?;

        let result = row.map(|row| {
            let user = User {
                id: row.get("id"),
                handle: row.get("handle"),
                email: row.get("email"),
                display_name: row.get("display_name"),
                bio: row.get("bio"),
                avatar_key: row.get("avatar_key"),
                avatar_url: None,
                created_at: row.get("created_at"),
            };
            let followers_count: i64 = row.get("followers_count");
            let following_count: i64 = row.get("following_count");
            let posts_count: i64 = row.get("posts_count");
            (user, followers_count, following_count, posts_count)
        });

        Ok(result)
    }

    pub async fn update_profile(
        &self,
        user_id: Uuid,
        display_name: Option<String>,
        bio: Option<String>,
        avatar_key: Option<String>,
    ) -> Result<Option<User>> {
        let row = sqlx::query(
            "UPDATE users \
             SET display_name = COALESCE($2, display_name), \
                 bio = COALESCE($3, bio), \
                 avatar_key = COALESCE($4, avatar_key) \
             WHERE id = $1 AND deleted_at IS NULL \
             RETURNING id, handle, email, display_name, bio, avatar_key, created_at",
        )
        .bind(user_id)
        .bind(display_name)
        .bind(bio)
        .bind(avatar_key)
        .fetch_optional(self.db.pool())
        .await?;

        let user = row.map(|row| User {
            id: row.get("id"),
            handle: row.get("handle"),
            email: row.get("email"),
            display_name: row.get("display_name"),
            bio: row.get("bio"),
            avatar_key: row.get("avatar_key"),
            avatar_url: None,
            created_at: row.get("created_at"),
        });

        Ok(user)
    }

    /// Soft-delete user account (GDPR/CCPA compliance)
    /// Sets deleted_at timestamp and cleans up related data that previously relied on CASCADE.
    pub async fn delete_account(&self, user_id: Uuid) -> Result<bool> {
        let mut tx = self.db.pool().begin().await?;

        // Soft-delete the user
        let result = sqlx::query(
            "UPDATE users SET deleted_at = now() WHERE id = $1 AND deleted_at IS NULL",
        )
        .bind(user_id)
        .execute(&mut *tx)
        .await?;

        if result.rows_affected() == 0 {
            tx.rollback().await?;
            return Ok(false);
        }

        // Revoke all refresh tokens
        sqlx::query(
            "UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL",
        )
        .bind(user_id)
        .execute(&mut *tx)
        .await?;

        // Remove all follow relationships (both directions)
        sqlx::query("DELETE FROM follows WHERE follower_id = $1 OR followee_id = $1")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;

        // Remove all block relationships (both directions)
        sqlx::query("DELETE FROM blocks WHERE blocker_id = $1 OR blocked_id = $1")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;

        tx.commit().await?;

        Ok(true)
    }
}

