use serde::{Deserialize, Serialize};
use time::OffsetDateTime;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct User {
    pub id: Uuid,
    pub handle: String,
    pub email: String,
    pub display_name: String,
    pub bio: Option<String>,
    pub avatar_key: Option<String>,
    #[serde(with = "time::serde::rfc3339")]
    pub created_at: OffsetDateTime,
}

#[derive(Debug, Clone, Serialize)]
pub struct PublicUser {
    pub id: Uuid,
    pub handle: String,
    pub display_name: String,
    pub bio: Option<String>,
    pub avatar_key: Option<String>,
    #[serde(with = "time::serde::rfc3339")]
    pub created_at: OffsetDateTime,
}

impl From<User> for PublicUser {
    fn from(user: User) -> Self {
        Self {
            id: user.id,
            handle: user.handle,
            display_name: user.display_name,
            bio: user.bio,
            avatar_key: user.avatar_key,
            created_at: user.created_at,
        }
    }
}

impl From<&User> for PublicUser {
    fn from(user: &User) -> Self {
        Self {
            id: user.id,
            handle: user.handle.clone(),
            display_name: user.display_name.clone(),
            bio: user.bio.clone(),
            avatar_key: user.avatar_key.clone(),
            created_at: user.created_at,
        }
    }
}
