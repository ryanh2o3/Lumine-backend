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
    pub created_at: OffsetDateTime,
}

