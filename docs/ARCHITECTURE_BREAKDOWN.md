# Ciel Architecture Breakdown

## Overview

Ciel is a Rust-based backend service designed for a social media platform. This document provides a comprehensive architectural breakdown of the system, including all routes, their purposes, and the underlying components.

## High-Level Architecture

Ciel follows a modular architecture with the following main components:

- **HTTP Layer**: Handles incoming requests and routing
- **Application Layer**: Contains business logic organized by domain
- **Domain Layer**: Defines core domain models and types
- **Infrastructure Layer**: Manages external dependencies (database, cache, storage, queue)
- **Jobs Layer**: Background processing tasks

## Directory Structure

```
src/
├── app/              # Application layer - business logic
├── domain/           # Domain models and types
├── http/             # HTTP layer - routing and middleware
├── infra/            # Infrastructure layer - external services
├── jobs/             # Background jobs
└── main.rs           # Application entry point
```

## HTTP Layer

### Middleware

The HTTP layer includes middleware for:

- **Rate Limiting**: Controls request rates per user/IP
- **Authentication**: Validates user sessions using PASETO tokens
- **Error Handling**: Standardizes error responses

### Routes

All routes are defined in `src/http/routes.rs` and organized by functional area.

#### Story Routes (Photo-Only with Reactions)

**POST /stories**
- Purpose: Create a new photo story
- Handler: `stories::create_story_handler`
- Input: Photo image, optional caption, visibility settings
- Output: Created story data
- Authentication: Required (valid token)

**GET /users/:user_id/stories**
- Purpose: Get user's active photo stories
- Handler: `stories::get_user_stories_handler`
- Input: User ID parameter, pagination params
- Output: List of active stories (last 24h)
- Authentication: Required (public stories visible to all authenticated users)

**GET /stories/:story_id**
- Purpose: Get a specific photo story
- Handler: `stories::get_story_handler`
- Input: Story ID parameter
- Output: Story data with photo URL
- Authentication: Required (must have access based on visibility settings)

**DELETE /stories/:story_id**
- Purpose: Delete a photo story
- Handler: `stories::delete_story_handler`
- Input: Story ID parameter
- Output: Success confirmation
- Authentication: Required (must be owner or admin)

**GET /stories/:story_id/viewers**
- Purpose: Get story viewers (who viewed this story)
- Handler: `stories::get_story_viewers_handler`
- Input: Story ID parameter, pagination params
- Output: List of viewer profiles
- Authentication: Required (must be owner)

**POST /stories/:story_id/reactions**
- Purpose: Add reaction to story (emoji only)
- Handler: `stories::add_reaction_handler`
- Input: Story ID parameter, reaction emoji
- Output: Success confirmation
- Authentication: Required (valid token)

**GET /stories/:story_id/reactions**
- Purpose: Get story reactions
- Handler: `stories::get_story_reactions_handler`
- Input: Story ID parameter
- Output: List of reactions with user info
- Authentication: Required (must have access to story)

**DELETE /stories/:story_id/reactions**
- Purpose: Remove reaction from story
- Handler: `stories::remove_reaction_handler`
- Input: Story ID parameter
- Output: Success confirmation
- Authentication: Required (must be reactor)

**POST /stories/:story_id/seen**
- Purpose: Mark story as seen (viewed)
- Handler: `stories::mark_story_seen_handler`
- Input: Story ID parameter
- Output: Success confirmation
- Authentication: Required (valid token)

**GET /feed/stories**
- Purpose: Get active stories from followed users (photo stories feed)
- Handler: `stories::get_stories_feed_handler`
- Input: Pagination params, optional filters
- Output: List of stories from followed users
- Authentication: Required (valid token)

**GET /stories/:story_id/metrics**
- Purpose: Get story metrics for author (view counts, reactions)
- Handler: `stories::get_story_metrics_handler`
- Input: Story ID parameter
- Output: Engagement metrics
- Authentication: Required (must be owner)

**POST /stories/:story_id/highlights**
- Purpose: Save story to highlights (permanent collection)
- Handler: `stories::add_to_highlights_handler`
- Input: Story ID parameter, highlight name
- Output: Success confirmation
- Authentication: Required (must be owner)

**GET /users/:user_id/highlights**
- Purpose: Get user's story highlights
- Handler: `stories::get_user_highlights_handler`
- Input: User ID parameter
- Output: List of highlight collections
- Authentication: Required (public highlights visible to all)

**POST /stories/media/upload**
- Purpose: Upload story photo
- Handler: `stories::upload_story_media_handler`
- Input: Photo image file
- Output: Media metadata and temporary URL
- Authentication: Required (valid token)

**GET /stories/media/:media_id**
- Purpose: Get story photo
- Handler: `stories::get_story_media_handler`
- Input: Media ID parameter
- Output: Photo file or redirect URL
- Authentication: Required (must have access to story)

#### Authentication Routes

**POST /api/auth/register**
- Purpose: Register a new user
- Handler: `auth::register_handler`
- Input: User registration details (username, email, password)
- Output: Authentication token and user profile
- Authentication: None (public route)

**POST /api/auth/login**
- Purpose: Authenticate existing user
- Handler: `auth::login_handler`
- Input: Credentials (email/username + password)
- Output: Authentication token and user profile
- Authentication: None (public route)

**POST /api/auth/logout**
- Purpose: Invalidate current session
- Handler: `auth::logout_handler`
- Input: None
- Output: Success confirmation
- Authentication: Required (valid token)

**POST /api/auth/refresh**
- Purpose: Refresh authentication token
- Handler: `auth::refresh_handler`
- Input: Refresh token
- Output: New authentication token
- Authentication: Required (valid refresh token)

**GET /api/auth/me**
- Purpose: Get current user profile
- Handler: `auth::me_handler`
- Input: None
- Output: User profile data
- Authentication: Required (valid token)

#### User Management Routes

**GET /api/users/:user_id**
- Purpose: Get user profile by ID
- Handler: `users::get_user_handler`
- Input: User ID parameter
- Output: User profile data
- Authentication: Required (valid token)

**PUT /api/users/:user_id**
- Purpose: Update user profile
- Handler: `users::update_user_handler`
- Input: User ID parameter, updated profile data
- Output: Updated user profile
- Authentication: Required (valid token, must be owner or admin)

**GET /api/users/:user_id/posts**
- Purpose: Get user's posts
- Handler: `users::get_user_posts_handler`
- Input: User ID parameter, pagination params
- Output: List of posts by user
- Authentication: Required (valid token)

**GET /api/users/:user_id/followers**
- Purpose: Get user's followers
- Handler: `users::get_user_followers_handler`
- Input: User ID parameter, pagination params
- Output: List of follower profiles
- Authentication: Required (valid token)

**GET /api/users/:user_id/following**
- Purpose: Get users that this user follows
- Handler: `users::get_user_following_handler`
- Input: User ID parameter, pagination params
- Output: List of profiles that user follows
- Authentication: Required (valid token)

#### Post Management Routes

**POST /api/posts**
- Purpose: Create a new post
- Handler: `posts::create_post_handler`
- Input: Post content, media attachments
- Output: Created post data
- Authentication: Required (valid token)

**GET /api/posts/:post_id**
- Purpose: Get a specific post
- Handler: `posts::get_post_handler`
- Input: Post ID parameter
- Output: Post data with author info
- Authentication: Required (valid token)

**PUT /api/posts/:post_id**
- Purpose: Update a post
- Handler: `posts::update_post_handler`
- Input: Post ID parameter, updated content
- Output: Updated post data
- Authentication: Required (valid token, must be author or admin)

**DELETE /api/posts/:post_id**
- Purpose: Delete a post
- Handler: `posts::delete_post_handler`
- Input: Post ID parameter
- Output: Success confirmation
- Authentication: Required (valid token, must be author or admin)

**POST /api/posts/:post_id/like**
- Purpose: Like a post
- Handler: `engagement::like_post_handler`
- Input: Post ID parameter
- Output: Success confirmation
- Authentication: Required (valid token)

**DELETE /api/posts/:post_id/like**
- Purpose: Unlike a post
- Handler: `engagement::unlike_post_handler`
- Input: Post ID parameter
- Output: Success confirmation
- Authentication: Required (valid token)

**POST /api/posts/:post_id/comment**
- Purpose: Add a comment to a post
- Handler: `engagement::comment_post_handler`
- Input: Post ID parameter, comment content
- Output: Created comment data
- Authentication: Required (valid token)

**GET /api/posts/:post_id/comments**
- Purpose: Get comments for a post
- Handler: `engagement::get_post_comments_handler`
- Input: Post ID parameter, pagination params
- Output: List of comments
- Authentication: Required (valid token)

#### Social Graph Routes

**POST /api/users/:user_id/follow**
- Purpose: Follow a user
- Handler: `social::follow_user_handler`
- Input: User ID parameter
- Output: Success confirmation
- Authentication: Required (valid token)

**DELETE /api/users/:user_id/follow**
- Purpose: Unfollow a user
- Handler: `social::unfollow_user_handler`
- Input: User ID parameter
- Output: Success confirmation
- Authentication: Required (valid token)

**GET /api/users/:user_id/follow-status**
- Purpose: Check follow status
- Handler: `social::get_follow_status_handler`
- Input: User ID parameter
- Output: Follow status (following, not_following, pending)
- Authentication: Required (valid token)

#### Feed Routes

**GET /api/feed**
- Purpose: Get personalized feed
- Handler: `feed::get_feed_handler`
- Input: Pagination params, optional filters
- Output: List of posts for user's feed
- Authentication: Required (valid token)

**GET /api/feed/explore**
- Purpose: Get explore/discovery feed
- Handler: `feed::get_explore_feed_handler`
- Input: Pagination params
- Output: List of trending/popular posts
- Authentication: Required (valid token)

#### Media Routes

**POST /api/media/upload**
- Purpose: Upload media file
- Handler: `media::upload_media_handler`
- Input: Media file (image/video)
- Output: Media metadata and URL
- Authentication: Required (valid token)

**GET /api/media/:media_id**
- Purpose: Get media metadata
- Handler: `media::get_media_handler`
- Input: Media ID parameter
- Output: Media metadata
- Authentication: Required (valid token)

**DELETE /api/media/:media_id**
- Purpose: Delete media
- Handler: `media::delete_media_handler`
- Input: Media ID parameter
- Output: Success confirmation
- Authentication: Required (valid token, must be owner or admin)

#### Notification Routes

**GET /api/notifications**
- Purpose: Get user notifications
- Handler: `notifications::get_notifications_handler`
- Input: Pagination params
- Output: List of notifications
- Authentication: Required (valid token)

**POST /api/notifications/read**
- Purpose: Mark notifications as read
- Handler: `notifications::mark_notifications_read_handler`
- Input: List of notification IDs
- Output: Success confirmation
- Authentication: Required (valid token)

**POST /api/notifications/read-all**
- Purpose: Mark all notifications as read
- Handler: `notifications::mark_all_notifications_read_handler`
- Input: None
- Output: Success confirmation
- Authentication: Required (valid token)

#### Search Routes

**GET /api/search/users**
- Purpose: Search for users
- Handler: `search::search_users_handler`
- Input: Query string, pagination params
- Output: List of matching user profiles
- Authentication: Required (valid token)

**GET /api/search/posts**
- Purpose: Search for posts
- Handler: `search::search_posts_handler`
- Input: Query string, pagination params
- Output: List of matching posts
- Authentication: Required (valid token)

#### Moderation Routes

**POST /api/moderation/report**
- Purpose: Report content or user
- Handler: `moderation::report_handler`
- Input: Report details (target type, ID, reason)
- Output: Success confirmation
- Authentication: Required (valid token)

**POST /api/moderation/appeal**
- Purpose: Appeal a moderation decision
- Handler: `moderation::appeal_handler`
- Input: Appeal details (decision ID, explanation)
- Output: Success confirmation
- Authentication: Required (valid token)

#### Invite System Routes

**POST /api/invites**
- Purpose: Create an invite code
- Handler: `invites::create_invite_handler`
- Input: Invite details (uses, expiration)
- Output: Invite code
- Authentication: Required (valid token, admin or trusted user)

**POST /api/invites/redeem**
- Purpose: Redeem an invite code
- Handler: `invites::redeem_invite_handler`
- Input: Invite code
- Output: Success confirmation
- Authentication: Required (valid token)

**GET /api/invites**
- Purpose: Get user's invites
- Handler: `invites::get_user_invites_handler`
- Input: Pagination params
- Output: List of invite codes created by user
- Authentication: Required (valid token)

#### Trust System Routes

**POST /api/trust/verify**
- Purpose: Verify trust status
- Handler: `trust::verify_trust_handler`
- Input: Verification details
- Output: Trust verification result
- Authentication: Required (valid token)

**GET /api/trust/status**
- Purpose: Get trust status
- Handler: `trust::get_trust_status_handler`
- Input: None
- Output: Current trust status and metrics
- Authentication: Required (valid token)

## Application Layer

The application layer contains the core business logic organized by domain:

### Modules

**auth.rs**
- Handles user authentication and authorization
- Manages token generation and validation
- Implements password hashing and verification

**stories.rs** (NEW)
- Photo story creation and management
- Story visibility and access control
- Story lifecycle management (24h expiration)
- Story metrics and analytics
- Story highlight management
- Reaction handling and processing
- Story viewer tracking

**users.rs**
- User profile management
- User creation, updates, and deletion
- User lookup and search functionality

**posts.rs**
- Post creation, retrieval, update, and deletion
- Post visibility and access control
- Post metadata management

**engagement.rs**
- Likes, comments, and other engagement features
- Engagement metrics and analytics
- Comment threads and replies

**social.rs**
- Follow/unfollow functionality
- Social graph management
- Relationship status tracking

**feed.rs**
- Feed generation algorithms
- Personalized content ranking
- Explore/discovery feed logic

**media.rs**
- Media upload and processing
- Media metadata management
- Media URL generation and access control

**notifications.rs**
- Notification generation and delivery
- Notification types and templates
- Notification read status management

**search.rs**
- Search indexing and querying
- Search result ranking
- Search filters and facets

**moderation.rs**
- Content reporting and review
- Moderation actions and decisions
- Appeal process management

**invites.rs**
- Invite code generation and validation
- Invite redemption tracking
- Invite system administration

**trust.rs**
- Trust score calculation
- Trust verification processes
- Trust-based access control

**rate_limiter.rs**
- Rate limiting logic
- Request quota management
- Rate limit enforcement

**fingerprint.rs**
- Device/browser fingerprinting
- Fraud detection
- Anomaly detection

## Domain Layer

The domain layer defines the core data models and types:

### Models

**user.rs**
- User: Main user entity with profile information
- UserProfile: Public profile data
- UserCredentials: Authentication credentials
- UserSettings: User preferences and settings

**story.rs** (NEW)
- Story: Photo story entity with metadata
- StoryMedia: Story photo metadata and processing status
- StoryReaction: Emoji reactions to stories
- StoryView: Story view tracking and analytics
- StoryHighlight: Permanent story collections
- StoryVisibility: Visibility settings (Public, FriendsOnly, CloseFriendsOnly)
- StoryMetrics: Engagement metrics (views, reactions)

**post.rs**
- Post: Main post entity with content and metadata
- PostContent: Structured post content
- PostVisibility: Visibility settings (public, friends, private)
- PostMetrics: Engagement metrics (likes, comments, views)

**social_graph.rs**
- FollowRelationship: Follow status and metadata
- SocialConnection: Connection between users
- RelationshipStatus: Current relationship state

**media.rs**
- Media: Media file metadata
- MediaType: Type of media (image, video, etc.)
- MediaProcessingStatus: Processing state

**engagement.rs**
- Like: Like action on content
- Comment: Comment on post
- EngagementMetrics: Aggregated engagement data

**notification.rs**
- Notification: Notification message
- NotificationType: Type of notification
- NotificationStatus: Read/unread status

**moderation.rs**
- Report: Content/user report
- ModerationAction: Action taken by moderators
- Appeal: Appeal of moderation decision

## Infrastructure Layer

The infrastructure layer manages external dependencies:

### Components

**db.rs**
- Database connection management
- Transaction handling
- Query execution
- Uses SQLx for async PostgreSQL access

**cache.rs**
- Redis cache management
- Caching strategies
- Cache invalidation

**storage.rs**
- Object storage (S3-compatible)
- File upload/download
- Storage URL generation

**queue.rs**
- Background job queue (Redis-based)
- Job enqueueing and processing
- Job retry and error handling

## Jobs Layer

Background processing tasks:

### media_processor.rs
- Processes uploaded media files
- Generates thumbnails and previews
- Extracts metadata (EXIF, dimensions, etc.)
- Performs content analysis

## Configuration

Configuration is managed in `src/config/`:

**mod.rs**
- Main configuration structure
- Environment variable parsing
- Configuration validation

**rate_limits.rs**
- Rate limiting configuration
- Endpoint-specific rate limits
- User tier-based limits

## Error Handling

Centralized error handling in `src/http/error.rs`:

- Standardized error responses
- Error classification
- Error logging
- Custom error types for different domains

## Middleware

Middleware components in `src/http/middleware/`:

**rate_limit.rs**
- Rate limiting middleware
- Token bucket algorithm
- IP and user-based rate limiting
- Rate limit headers

## Security Features

- **Authentication**: PASETO tokens for stateless auth
- **Authorization**: Role-based access control
- **Rate Limiting**: Protection against abuse
- **Input Validation**: Comprehensive request validation
- **Content Security**: Media scanning and analysis
- **Trust System**: Reputation-based access control

## Performance Considerations

- **Caching**: Heavy use of Redis caching for frequent queries
- **Database**: Optimized PostgreSQL queries with proper indexing
- **Async**: Full async/await architecture using Tokio
- **Batch Processing**: Bulk operations for efficiency
- **Connection Pooling**: Database and Redis connection pooling

## Scalability Features

- **Horizontal Scaling**: Stateless design for easy scaling
- **Background Jobs**: Offload processing to worker queues
- **Microservice-Ready**: Modular design for potential service split
- **Configurable**: Environment-based configuration

## Monitoring and Observability

- **Logging**: Structured logging throughout
- **Metrics**: Prometheus metrics endpoints
- **Tracing**: Distributed tracing support
- **Health Checks**: Endpoint for service health monitoring

## Deployment Architecture

The system is designed for containerized deployment:

- **API Service**: Main HTTP service (stateless)
- **Worker Service**: Background job processing
- **Database**: PostgreSQL for primary data storage
- **Cache**: Redis for caching and rate limiting
- **Storage**: S3-compatible object storage for media
- **Queue**: Redis-based queue for background jobs

## Key Technical Stack

- **Language**: Rust (stable)
- **Web Framework**: Axum
- **Database**: PostgreSQL with SQLx
- **Cache**: Redis
- **Storage**: S3-compatible object storage
- **Async Runtime**: Tokio
- **Authentication**: PASETO tokens
- **Configuration**: Config + environment variables
- **Logging**: Tracing + structured logging
- **Metrics**: Prometheus client

## Development Workflow

- **Testing**: Unit and integration tests
- **CI/CD**: GitHub Actions for testing and deployment
- **Migration**: SQL migration files for database schema changes
- **Docker**: Containerized development environment
- **Terraform**: Infrastructure as code for deployment

## Error Response Format

All API errors follow a consistent format:

```json
{
  "error": {
    "code": "error_code",
    "message": "Human-readable message",
    "details": {}
  }
}
```

## Rate Limiting

The system implements comprehensive rate limiting:

- **Global Limits**: Apply to all endpoints
- **Endpoint-Specific Limits**: Custom limits per route
- **User Tier Limits**: Different limits based on trust/trust level
- **IP-based Limits**: Protection against unauthenticated abuse
- **Token Bucket Algorithm**: Smooth rate limiting with bursts allowed

## Authentication Flow

1. User registers or logs in
2. Server generates PASETO token with claims
3. Token signed with server secret key
4. Client includes token in Authorization header
5. Middleware validates token on each request
6. Token claims available in request context

## Media Processing Flow

1. User uploads media file
2. File stored in temporary location
3. Background job processes file
4. Metadata extracted and stored
5. Thumbnails/previews generated
6. Content analysis performed
7. File moved to permanent storage
8. User notified of completion

## Feed Generation

The feed system uses multiple algorithms:

- **Chronological Feed**: Simple time-based ordering
- **Ranked Feed**: Engagement-based ranking
- **Explore Feed**: Popular/trending content discovery
- **Personalized Feed**: Machine learning-based recommendations

## Notification System

Notifications are generated for various events:

- New followers
- Likes on posts
- Comments on posts
- Mentions in posts/comments
- Direct messages
- Moderation actions
- System announcements

## Search Implementation

Search functionality includes:

- Full-text search on posts and user profiles
- Filtering by content type, date ranges, etc.
- Result ranking based on relevance and engagement
- Autocomplete suggestions
- Search history and personalization

## Moderation System

Comprehensive content moderation:

- User reporting system
- Automated content analysis
- Manual review workflow
- Appeal process
- Trust-based moderation privileges
- Content visibility controls

## Trust System

The trust system implements:

- Reputation scoring based on behavior
- Trust levels with different privileges
- Verification processes
- Anti-abuse measures
- Progressive access to features

## Rate Limiting Implementation

Sophisticated rate limiting includes:

- Different limits for authenticated vs unauthenticated users
- Progressive limits based on trust level
- Burst capacity with token bucket algorithm
- Clear rate limit headers in responses
- Graceful degradation when limits exceeded

## Security Architecture

Multi-layered security approach:

- Transport security (TLS)
- Authentication and authorization
- Input validation and sanitization
- Rate limiting and abuse prevention
- Content scanning and analysis
- Secure token handling
- Database security measures

## Performance Optimization

Key performance optimizations:

- Database query optimization
- Comprehensive caching strategy
- Efficient media processing
- Background job processing
- Connection pooling
- Batch operations
- Lazy loading where appropriate

## Future Architecture Evolution

The system is designed for future growth:

- Microservice decomposition paths identified
- Scalable data partitioning strategies
- Multi-region deployment considerations
- Advanced caching strategies
- Machine learning integration points
- Real-time features foundation

This comprehensive architecture provides a solid foundation for Ciel's social media platform, with careful attention to performance, security, and scalability requirements.