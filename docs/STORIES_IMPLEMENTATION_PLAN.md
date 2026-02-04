# Photo Stories Implementation Plan

## Overview

This document provides a detailed implementation plan for adding photo-only stories with reactions to Ciel, following existing architectural patterns and best practices.

## Implementation Strategy

The implementation will follow Ciel's established architectural patterns:

1. **Modular Design**: Separate concerns across layers
2. **Async Processing**: Use Tokio for asynchronous operations
3. **Database Abstraction**: Use SQLx for database access
4. **Error Handling**: Consistent error handling patterns
5. **Configuration**: Environment-based configuration
6. **Testing**: Comprehensive unit and integration tests

## Phase 1: Database Schema Changes

### New Tables Required

```sql
-- Stories table
CREATE TABLE stories (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    media_id UUID NOT NULL REFERENCES media(id) ON DELETE CASCADE,
    caption TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    visibility VARCHAR(20) NOT NULL DEFAULT 'public',
    view_count INTEGER NOT NULL DEFAULT 0,
    reaction_count INTEGER NOT NULL DEFAULT 0,
    is_highlight BOOLEAN NOT NULL DEFAULT FALSE,
    highlight_name TEXT
);

-- Story views table
CREATE TABLE story_views (
    id UUID PRIMARY KEY,
    story_id UUID NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
    viewer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    viewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(story_id, viewer_id)
);

-- Story reactions table
CREATE TABLE story_reactions (
    id UUID PRIMARY KEY,
    story_id UUID NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    emoji VARCHAR(10) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(story_id, user_id)
);

-- Story highlights table
CREATE TABLE story_highlights (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(50) NOT NULL,
    cover_story_id UUID REFERENCES stories(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, name)
);

-- Story highlight items (stories in highlights)
CREATE TABLE story_highlight_items (
    id UUID PRIMARY KEY,
    highlight_id UUID NOT NULL REFERENCES story_highlights(id) ON DELETE CASCADE,
    story_id UUID NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
    position INTEGER NOT NULL,
    added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(highlight_id, story_id)
);

-- Indexes for performance
CREATE INDEX idx_stories_user_id ON stories(user_id);
CREATE INDEX idx_stories_expires_at ON stories(expires_at);
CREATE INDEX idx_stories_created_at ON stories(created_at);
CREATE INDEX idx_story_views_story_id ON story_views(story_id);
CREATE INDEX idx_story_views_viewer_id ON story_views(viewer_id);
CREATE INDEX idx_story_reactions_story_id ON story_reactions(story_id);
CREATE INDEX idx_story_highlights_user_id ON story_highlights(user_id);
```

### Database Migration

Create a new migration file `migrations/008_stories.sql` with the above schema.

## Phase 2: Domain Layer Implementation

### Create `src/domain/story.rs`

```rust
use uuid::Uuid;
use time::OffsetDateTime;
use serde::{Serialize, Deserialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Story {
    pub id: Uuid,
    pub user_id: Uuid,
    pub media_id: Uuid,
    pub caption: Option<String>,
    pub created_at: OffsetDateTime,
    pub expires_at: OffsetDateTime,
    pub visibility: StoryVisibility,
    pub view_count: i32,
    pub reaction_count: i32,
    pub is_highlight: bool,
    pub highlight_name: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StoryMedia {
    pub id: Uuid,
    pub user_id: Uuid,
    pub file_path: String,
    pub thumbnail_path: String,
    pub width: u32,
    pub height: u32,
    pub file_size: u64,
    pub content_type: String,
    pub status: MediaStatus,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StoryReaction {
    pub id: Uuid,
    pub story_id: Uuid,
    pub user_id: Uuid,
    pub emoji: String,
    pub created_at: OffsetDateTime,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StoryView {
    pub id: Uuid,
    pub story_id: Uuid,
    pub viewer_id: Uuid,
    pub viewed_at: OffsetDateTime,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StoryHighlight {
    pub id: Uuid,
    pub user_id: Uuid,
    pub name: String,
    pub cover_story_id: Option<Uuid>,
    pub created_at: OffsetDateTime,
    pub updated_at: OffsetDateTime,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "story_visibility", rename_all = "snake_case")]
pub enum StoryVisibility {
    Public,
    FriendsOnly,
    CloseFriendsOnly,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StoryMetrics {
    pub view_count: i32,
    pub reaction_count: i32,
    pub reactions_by_emoji: Vec<(String, i32)>,
    pub viewer_ids: Vec<Uuid>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateStoryRequest {
    pub media_id: Uuid,
    pub caption: Option<String>,
    pub visibility: StoryVisibility,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AddReactionRequest {
    pub emoji: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateHighlightRequest {
    pub name: String,
    pub story_ids: Vec<Uuid>,
}
```

## Phase 3: Application Layer Implementation

### Create `src/app/stories.rs`

```rust
use crate::domain::story::*;
use crate::infra::db::DbPool;
use crate::infra::cache::Cache;
use crate::infra::storage::Storage;
use crate::AppError;
use uuid::Uuid;
use time::OffsetDateTime;

pub struct StoryService {
    db: DbPool,
    cache: Cache,
    storage: Storage,
}

impl StoryService {
    pub fn new(db: DbPool, cache: Cache, storage: Storage) -> Self {
        Self { db, cache, storage }
    }

    /// Create a new photo story
    pub async fn create_story(
        &self,
        user_id: Uuid,
        request: CreateStoryRequest,
    ) -> Result<Story, AppError> {
        // Validate media belongs to user
        // Create story record
        // Set expiration (24h from now)
        // Return created story
        todo!()
    }

    /// Get user's active stories
    pub async fn get_user_stories(
        &self,
        user_id: Uuid,
        viewer_id: Uuid,
        limit: i64,
        cursor: Option<String>,
    ) -> Result<Vec<Story>, AppError> {
        // Check visibility permissions
        // Get active stories (not expired)
        // Apply pagination
        // Return stories
        todo!()
    }

    /// Get specific story
    pub async fn get_story(
        &self,
        story_id: Uuid,
        viewer_id: Uuid,
    ) -> Result<Story, AppError> {
        // Check story exists
        // Verify access permissions
        // Mark as viewed if first view
        // Return story
        todo!()
    }

    /// Delete story
    pub async fn delete_story(
        &self,
        story_id: Uuid,
        user_id: Uuid,
    ) -> Result<(), AppError> {
        // Verify ownership
        // Delete story and related data
        // Clean up media if not used elsewhere
        todo!()
    }

    /// Add reaction to story
    pub async fn add_reaction(
        &self,
        story_id: Uuid,
        user_id: Uuid,
        request: AddReactionRequest,
    ) -> Result<(), AppError> {
        // Validate emoji
        // Check if already reacted
        // Create reaction record
        // Update story reaction count
        // Send notification
        todo!()
    }

    /// Remove reaction from story
    pub async fn remove_reaction(
        &self,
        story_id: Uuid,
        user_id: Uuid,
    ) -> Result<(), AppError> {
        // Delete reaction record
        // Update story reaction count
        todo!()
    }

    /// Mark story as viewed
    pub async fn mark_story_seen(
        &self,
        story_id: Uuid,
        viewer_id: Uuid,
    ) -> Result<(), AppError> {
        // Check if already viewed
        // Create view record
        // Update story view count
        todo!()
    }

    /// Get stories feed (from followed users)
    pub async fn get_stories_feed(
        &self,
        user_id: Uuid,
        limit: i64,
        cursor: Option<String>,
    ) -> Result<Vec<Story>, AppError> {
        // Get followed users
        // Get their active stories
        // Apply visibility filters
        // Sort by creation time
        // Apply pagination
        todo!()
    }

    /// Get story metrics
    pub async fn get_story_metrics(
        &self,
        story_id: Uuid,
        user_id: Uuid,
    ) -> Result<StoryMetrics, AppError> {
        // Verify ownership
        // Get view count
        // Get reaction count
        // Get reactions by emoji
        // Get viewer list
        todo!()
    }

    /// Create story highlight
    pub async fn create_highlight(
        &self,
        user_id: Uuid,
        request: CreateHighlightRequest,
    ) -> Result<StoryHighlight, AppError> {
        // Validate stories belong to user
        // Create highlight
        // Add stories to highlight
        // Set cover story
        todo!()
    }

    /// Get user's highlights
    pub async fn get_user_highlights(
        &self,
        user_id: Uuid,
    ) -> Result<Vec<StoryHighlight>, AppError> {
        // Get highlights
        // Include cover story info
        // Return highlights
        todo!()
    }

    /// Clean up expired stories (background job)
    pub async fn cleanup_expired_stories(&self) -> Result<usize, AppError> {
        // Find expired stories
        // Delete stories and related data
        // Return count of deleted stories
        todo!()
    }
}
```

## Phase 4: HTTP Layer Implementation

### Add to `src/http/routes.rs`

```rust
pub fn stories() -> Router<AppState> {
    Router::new()
        .route("/stories", post(handlers::create_story))
        .route("/users/:user_id/stories", get(handlers::get_user_stories))
        .route("/stories/:story_id", get(handlers::get_story))
        .route("/stories/:story_id", delete(handlers::delete_story))
        .route("/stories/:story_id/viewers", get(handlers::get_story_viewers))
        .route("/stories/:story_id/reactions", post(handlers::add_reaction))
        .route("/stories/:story_id/reactions", get(handlers::get_reactions))
        .route("/stories/:story_id/reactions", delete(handlers::remove_reaction))
        .route("/stories/:story_id/seen", post(handlers::mark_story_seen))
        .route("/feed/stories", get(handlers::get_stories_feed))
        .route("/stories/:story_id/metrics", get(handlers::get_story_metrics))
        .route("/stories/:story_id/highlights", post(handlers::add_to_highlights))
        .route("/users/:user_id/highlights", get(handlers::get_user_highlights))
        .route("/stories/media/upload", post(handlers::upload_story_media))
        .route("/stories/media/:media_id", get(handlers::get_story_media))
}
```

### Add to `src/http/handlers.rs`

```rust
// Add story handlers
pub async fn create_story(
    State(state): State<AppState>,
    AuthUser(user_id): AuthUser,
    Json(request): Json<CreateStoryRequest>,
) -> Result<Json<Story>, AppError> {
    let story = state.stories.create_story(user_id, request).await?;
    Ok(Json(story))
}

pub async fn get_user_stories(
    State(state): State<AppState>,
    Path(user_id): Path<Uuid>,
    AuthUser(viewer_id): AuthUser,
    Query(pagination): Query<PaginationQuery>,
) -> Result<Json<ListResponse<Story>>, AppError> {
    let stories = state.stories.get_user_stories(user_id, viewer_id, pagination.limit, pagination.cursor).await?;
    Ok(Json(ListResponse { items: stories, next_cursor: None }))
}

// Implement other handlers following same pattern...
```

## Phase 5: Infrastructure Integration

### Update `src/infra/storage.rs`

Add story-specific storage methods:

```rust
impl Storage {
    /// Upload story photo with optimization
    pub async fn upload_story_photo(&self, user_id: Uuid, file_data: Vec<u8>) -> Result<StoryMedia, AppError> {
        // Validate image format
        // Optimize for web (resize, compress)
        // Generate thumbnail
        // Upload to storage
        // Return media metadata
        todo!()
    }

    /// Get story photo URL
    pub async fn get_story_photo_url(&self, media_id: Uuid) -> Result<String, AppError> {
        // Generate signed URL
        // Return URL
        todo!()
    }
}
```

### Update `src/infra/cache.rs`

Add story caching methods:

```rust
impl Cache {
    /// Cache story data
    pub async fn cache_story(&self, story: &Story) -> Result<(), AppError> {
        // Cache story with TTL (24h)
        todo!()
    }

    /// Get cached story
    pub async fn get_cached_story(&self, story_id: Uuid) -> Result<Option<Story>, AppError> {
        // Get story from cache
        todo!()
    }

    /// Cache stories feed
    pub async fn cache_stories_feed(&self, user_id: Uuid, stories: &[Story]) -> Result<(), AppError> {
        // Cache feed with short TTL
        todo!()
    }
}
```

## Phase 6: Background Jobs

### Update `src/jobs/mod.rs`

Add story cleanup job:

```rust
pub async fn cleanup_expired_stories_job(state: AppState) -> Result<(), AppError> {
    let count = state.stories.cleanup_expired_stories().await?;
    log::info!("Cleaned up {} expired stories", count);
    Ok(())
}
```

### Schedule in main.rs

```rust
// Add to background job scheduler
tokio::spawn(async move {
    let mut interval = tokio::time::interval(Duration::from_secs(3600)); // Run hourly
    loop {
        interval.tick().await;
        if let Err(e) = cleanup_expired_stories_job(app_state.clone()).await {
            log::error!("Error cleaning up expired stories: {}", e);
        }
    }
});
```

## Phase 7: Error Handling

### Update `src/http/error.rs`

Add story-specific errors:

```rust
#[derive(Debug, thiserror::Error)]
pub enum AppError {
    // ... existing errors ...
    #[error("Story not found")]
    StoryNotFound,
    
    #[error("Story access denied")]
    StoryAccessDenied,
    
    #[error("Story expired")]
    StoryExpired,
    
    #[error("Invalid story visibility")]
    InvalidStoryVisibility,
    
    #[error("Story already reacted")]
    StoryAlreadyReacted,
    
    #[error("Invalid reaction emoji")]
    InvalidReactionEmoji,
}
```

## Phase 8: Configuration

### Update `src/config/mod.rs`

Add story-specific configuration:

```rust
#[derive(Debug, Clone, Deserialize)]
pub struct StoryConfig {
    pub max_caption_length: usize,
    pub max_image_size_mb: usize,
    pub allowed_image_types: Vec<String>,
    pub cleanup_interval_hours: u64,
    pub cache_ttl_seconds: u64,
}
```

## Phase 9: Testing

### Unit Tests

Create `tests/stories.rs`:

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::*;

    #[tokio::test]
    async fn test_create_story() {
        let app = TestApp::new().await;
        let user = app.create_test_user().await;
        let media = app.upload_test_media(user.id).await;

        let request = CreateStoryRequest {
            media_id: media.id,
            caption: Some("Test story".to_string()),
            visibility: StoryVisibility::Public,
        };

        let story = app.stories.create_story(user.id, request).await;
        assert!(story.is_ok());
    }

    // Add more tests...
}
```

### Integration Tests

Add API integration tests:

```rust
#[tokio::test]
async fn test_story_creation_flow() {
    let app = spawn_app().await;
    
    // Login
    let auth = app.login_test_user().await;
    
    // Upload media
    let media_response = app
        .post("/stories/media/upload")
        .bearer_auth(&auth.access_token)
        .multipart(...)
        .send()
        .await;
    
    assert_eq!(media_response.status(), StatusCode::OK);
    
    // Create story
    let story_response = app
        .post("/stories")
        .bearer_auth(&auth.access_token)
        .json(&CreateStoryRequest {
            media_id: media_id,
            caption: Some("Test".to_string()),
            visibility: StoryVisibility::Public,
        })
        .send()
        .await;
    
    assert_eq!(story_response.status(), StatusCode::OK);
}
```

## Phase 10: Deployment Considerations

### Database Migration
- Run migration before deploying new code
- Test migration on staging environment

### Feature Flags
- Consider feature flag for gradual rollout
- Monitor performance impact

### Monitoring
- Add Prometheus metrics for story operations
- Set up alerts for story creation failures
- Monitor story cleanup job execution

### Performance Optimization
- Implement proper caching strategies
- Optimize image delivery with CDN
- Consider lazy loading for story feeds

## Implementation Timeline

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| 1. Database Schema | 1-2 days | None |
| 2. Domain Layer | 2-3 days | Phase 1 |
| 3. Application Layer | 3-5 days | Phase 2 |
| 4. HTTP Layer | 2-3 days | Phase 3 |
| 5. Infrastructure | 2 days | Phase 3 |
| 6. Background Jobs | 1 day | Phase 3 |
| 7. Error Handling | 1 day | Phase 3 |
| 8. Configuration | 1 day | None |
| 9. Testing | 3-5 days | All phases |
| 10. Deployment | 1 day | All phases |

**Total Estimated Duration**: 2-3 weeks

## Best Practices Followed

1. **Separation of Concerns**: Clear layer separation
2. **Async Processing**: Non-blocking I/O operations
3. **Error Handling**: Comprehensive error handling
4. **Configuration**: Environment-based settings
5. **Testing**: Unit and integration tests
6. **Performance**: Caching and optimization
7. **Security**: Proper access control
8. **Documentation**: Complete API documentation
9. **Monitoring**: Metrics and logging
10. **Maintainability**: Clean, modular code

## Integration with Existing Features

- **Authentication**: Uses existing PASETO token system
- **Media**: Reuses existing media infrastructure
- **Notifications**: Integrates with notification system
- **Social Graph**: Uses existing follow relationships
- **Rate Limiting**: Applies existing rate limiting
- **Caching**: Uses existing Redis caching

This implementation plan ensures that photo stories with reactions are added to Ciel following established architectural patterns and best practices, maintaining consistency with the existing codebase while providing a robust and scalable feature.