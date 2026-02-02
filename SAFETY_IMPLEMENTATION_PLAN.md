# PicShare Safety & Anti-Bot Implementation Plan

**Based on:** safety_bot_strategy.md
**Goal:** Implement comprehensive anti-bot, rate limiting, and referral system
**Estimated Effort:** 4-6 weeks (1 senior engineer)
**Priority:** High (addresses critical rate-limiting security gap)

---

## Executive Summary

This plan implements a **defense-in-depth approach** to platform safety:

1. ✅ **Rate Limiting** (P0 - Critical)
2. ✅ **Trust Tiers** (P0 - Critical)
3. ✅ **Device Fingerprinting** (P1 - Important)
4. ✅ **Invite-Only Signup** (P1 - Important)
5. ✅ **Proof-of-Work** (P2 - Nice to have)
6. ✅ **Behavior Analysis** (P2 - Nice to have)
7. ✅ **Content Moderation** (P3 - Future)

**Architectural Impact:**
- New database tables: 5
- New services: 3
- New middleware: 2
- New background jobs: 2
- Dependencies added: 3-4

---

## Phase 1: Rate Limiting & Trust System (Week 1) 🔴 CRITICAL

### 1.1 Database Schema

**Migration: `006_rate_limiting_and_trust.sql`**

```sql
-- Trust scoring system
CREATE TABLE user_trust_scores (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    trust_level INT NOT NULL DEFAULT 0,  -- 0 = new, 1 = basic, 2 = trusted, 3 = verified
    trust_points INT NOT NULL DEFAULT 0,
    account_age_days INT NOT NULL DEFAULT 0,

    -- Activity metrics
    posts_count INT NOT NULL DEFAULT 0,
    comments_count INT NOT NULL DEFAULT 0,
    likes_received_count INT NOT NULL DEFAULT 0,
    followers_count INT NOT NULL DEFAULT 0,

    -- Violation tracking
    flags_received INT NOT NULL DEFAULT 0,
    strikes INT NOT NULL DEFAULT 0,
    banned_until TIMESTAMPTZ,

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_activity_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Rate limit tracking (Redis-backed, this is for persistent history)
CREATE TABLE rate_limit_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    ip_address INET,
    device_fingerprint TEXT,

    action_type TEXT NOT NULL,  -- 'post', 'comment', 'like', 'follow', 'login', 'signup'
    action_count INT NOT NULL DEFAULT 1,

    window_start TIMESTAMPTZ NOT NULL,
    window_end TIMESTAMPTZ NOT NULL,

    rate_limited BOOLEAN NOT NULL DEFAULT FALSE,
    trust_level INT NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Device fingerprints
CREATE TABLE device_fingerprints (
    fingerprint_hash TEXT PRIMARY KEY,
    first_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Association tracking
    user_ids UUID[] NOT NULL DEFAULT '{}',
    account_count INT NOT NULL DEFAULT 0,

    -- Risk scoring
    risk_score INT NOT NULL DEFAULT 0,  -- 0-100
    is_blocked BOOLEAN NOT NULL DEFAULT FALSE,
    block_reason TEXT,
    blocked_at TIMESTAMPTZ,

    -- Metadata
    user_agent TEXT,
    platform TEXT,
    browser TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_trust_scores_level ON user_trust_scores(trust_level);
CREATE INDEX idx_trust_scores_updated ON user_trust_scores(updated_at DESC);
CREATE INDEX idx_rate_limit_user_action ON rate_limit_events(user_id, action_type, window_start);
CREATE INDEX idx_rate_limit_ip ON rate_limit_events(ip_address, window_start);
CREATE INDEX idx_device_fp_users ON device_fingerprints USING gin(user_ids);
CREATE INDEX idx_device_fp_risk ON device_fingerprints(risk_score DESC);
```

### 1.2 Rate Limit Configuration

**File: `src/config/rate_limits.rs`** (new)

```rust
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum TrustLevel {
    New = 0,        // 0-7 days, < 5 posts
    Basic = 1,      // 7-30 days, 5+ posts, no violations
    Trusted = 2,    // 30+ days, 50+ posts, active engagement
    Verified = 3,   // Manual verification or high trust score
}

#[derive(Debug, Clone, Copy)]
pub struct RateLimits {
    // Posts
    pub posts_per_hour: u32,
    pub posts_per_day: u32,

    // Social actions
    pub follows_per_hour: u32,
    pub follows_per_day: u32,
    pub unfollows_per_day: u32,

    // Engagement
    pub likes_per_hour: u32,
    pub comments_per_hour: u32,

    // Authentication
    pub login_attempts_per_hour: u32,
    pub signup_attempts_per_ip_per_day: u32,
}

impl RateLimits {
    pub fn for_trust_level(level: TrustLevel) -> Self {
        match level {
            TrustLevel::New => RateLimits {
                posts_per_hour: 1,
                posts_per_day: 5,
                follows_per_hour: 5,
                follows_per_day: 20,
                unfollows_per_day: 10,
                likes_per_hour: 30,
                comments_per_hour: 10,
                login_attempts_per_hour: 5,
                signup_attempts_per_ip_per_day: 3,
            },
            TrustLevel::Basic => RateLimits {
                posts_per_hour: 5,
                posts_per_day: 20,
                follows_per_hour: 20,
                follows_per_day: 100,
                unfollows_per_day: 50,
                likes_per_hour: 100,
                comments_per_hour: 30,
                login_attempts_per_hour: 10,
                signup_attempts_per_ip_per_day: 5,
            },
            TrustLevel::Trusted => RateLimits {
                posts_per_hour: 20,
                posts_per_day: 100,
                follows_per_hour: 100,
                follows_per_day: 500,
                unfollows_per_day: 200,
                likes_per_hour: 500,
                comments_per_hour: 100,
                login_attempts_per_hour: 20,
                signup_attempts_per_ip_per_day: 10,
            },
            TrustLevel::Verified => RateLimits {
                posts_per_hour: 50,
                posts_per_day: 200,
                follows_per_hour: 200,
                follows_per_day: 1000,
                unfollows_per_day: 500,
                likes_per_hour: 1000,
                comments_per_hour: 200,
                login_attempts_per_hour: 30,
                signup_attempts_per_ip_per_day: 20,
            },
        }
    }
}
```

### 1.3 Trust Score Service

**File: `src/app/trust.rs`** (new)

```rust
use anyhow::Result;
use sqlx::Row;
use time::OffsetDateTime;
use uuid::Uuid;

use crate::config::rate_limits::TrustLevel;
use crate::infra::db::Db;

#[derive(Clone)]
pub struct TrustService {
    db: Db,
}

#[derive(Debug, Clone)]
pub struct TrustScore {
    pub user_id: Uuid,
    pub trust_level: TrustLevel,
    pub trust_points: i32,
    pub account_age_days: i32,
    pub posts_count: i32,
    pub followers_count: i32,
    pub flags_received: i32,
    pub strikes: i32,
    pub banned_until: Option<OffsetDateTime>,
}

impl TrustService {
    pub fn new(db: Db) -> Self {
        Self { db }
    }

    /// Initialize trust score for new user
    pub async fn initialize_user(&self, user_id: Uuid) -> Result<()> {
        sqlx::query(
            "INSERT INTO user_trust_scores (user_id, trust_level, trust_points, account_age_days) \
             VALUES ($1, 0, 0, 0) \
             ON CONFLICT (user_id) DO NOTHING"
        )
        .bind(user_id)
        .execute(self.db.pool())
        .await?;

        Ok(())
    }

    /// Get user's trust score
    pub async fn get_trust_score(&self, user_id: Uuid) -> Result<Option<TrustScore>> {
        let row = sqlx::query(
            "SELECT user_id, trust_level, trust_points, account_age_days, \
                    posts_count, followers_count, flags_received, strikes, banned_until \
             FROM user_trust_scores \
             WHERE user_id = $1"
        )
        .bind(user_id)
        .fetch_optional(self.db.pool())
        .await?;

        let score = row.map(|row| {
            let level: i32 = row.get("trust_level");
            TrustScore {
                user_id: row.get("user_id"),
                trust_level: match level {
                    0 => TrustLevel::New,
                    1 => TrustLevel::Basic,
                    2 => TrustLevel::Trusted,
                    3 => TrustLevel::Verified,
                    _ => TrustLevel::New,
                },
                trust_points: row.get("trust_points"),
                account_age_days: row.get("account_age_days"),
                posts_count: row.get("posts_count"),
                followers_count: row.get("followers_count"),
                flags_received: row.get("flags_received"),
                strikes: row.get("strikes"),
                banned_until: row.get("banned_until"),
            }
        });

        Ok(score)
    }

    /// Update trust score based on activity
    pub async fn update_activity(&self, user_id: Uuid, activity_type: &str) -> Result<()> {
        let points_delta = match activity_type {
            "post_created" => 5,
            "comment_created" => 2,
            "like_received" => 1,
            "follower_gained" => 3,
            "flag_received" => -10,
            "content_removed" => -25,
            _ => 0,
        };

        sqlx::query(
            "UPDATE user_trust_scores \
             SET trust_points = GREATEST(0, trust_points + $1), \
                 updated_at = NOW(), \
                 last_activity_at = NOW() \
             WHERE user_id = $2"
        )
        .bind(points_delta)
        .bind(user_id)
        .execute(self.db.pool())
        .await?;

        // Recalculate trust level
        self.recalculate_trust_level(user_id).await?;

        Ok(())
    }

    /// Recalculate trust level based on metrics
    async fn recalculate_trust_level(&self, user_id: Uuid) -> Result<()> {
        let row = sqlx::query(
            "SELECT account_age_days, posts_count, trust_points, flags_received, strikes \
             FROM user_trust_scores \
             WHERE user_id = $1"
        )
        .bind(user_id)
        .fetch_one(self.db.pool())
        .await?;

        let age_days: i32 = row.get("account_age_days");
        let posts: i32 = row.get("posts_count");
        let points: i32 = row.get("trust_points");
        let flags: i32 = row.get("flags_received");
        let strikes: i32 = row.get("strikes");

        let new_level = if strikes >= 3 {
            TrustLevel::New // Demoted due to violations
        } else if age_days >= 90 && posts >= 50 && points >= 200 && flags < 3 {
            TrustLevel::Trusted
        } else if age_days >= 7 && posts >= 5 && points >= 20 && flags < 5 {
            TrustLevel::Basic
        } else {
            TrustLevel::New
        };

        sqlx::query(
            "UPDATE user_trust_scores \
             SET trust_level = $1, updated_at = NOW() \
             WHERE user_id = $2"
        )
        .bind(new_level as i32)
        .bind(user_id)
        .execute(self.db.pool())
        .await?;

        Ok(())
    }

    /// Check if user is banned
    pub async fn is_banned(&self, user_id: Uuid) -> Result<bool> {
        let row = sqlx::query(
            "SELECT banned_until FROM user_trust_scores WHERE user_id = $1"
        )
        .bind(user_id)
        .fetch_optional(self.db.pool())
        .await?;

        if let Some(row) = row {
            if let Some(banned_until) = row.get::<Option<OffsetDateTime>, _>("banned_until") {
                return Ok(banned_until > OffsetDateTime::now_utc());
            }
        }

        Ok(false)
    }

    /// Add strike to user (3 strikes = ban)
    pub async fn add_strike(&self, user_id: Uuid, reason: &str) -> Result<()> {
        let result = sqlx::query(
            "UPDATE user_trust_scores \
             SET strikes = strikes + 1, \
                 updated_at = NOW() \
             WHERE user_id = $1 \
             RETURNING strikes"
        )
        .bind(user_id)
        .fetch_one(self.db.pool())
        .await?;

        let strikes: i32 = result.get("strikes");

        // Auto-ban after 3 strikes
        if strikes >= 3 {
            let ban_duration_days = match strikes {
                3 => 7,    // 1 week
                4 => 30,   // 1 month
                _ => 365,  // 1 year
            };

            let ban_until = OffsetDateTime::now_utc() + time::Duration::days(ban_duration_days);

            sqlx::query(
                "UPDATE user_trust_scores \
                 SET banned_until = $1, updated_at = NOW() \
                 WHERE user_id = $2"
            )
            .bind(ban_until)
            .bind(user_id)
            .execute(self.db.pool())
            .await?;

            tracing::warn!(
                user_id = %user_id,
                strikes = strikes,
                ban_until = %ban_until,
                reason = reason,
                "User banned due to strikes"
            );
        }

        Ok(())
    }
}
```

### 1.4 Rate Limiting Service

**File: `src/app/rate_limiter.rs`** (new)

```rust
use anyhow::{anyhow, Result};
use redis::AsyncCommands;
use uuid::Uuid;

use crate::config::rate_limits::{RateLimits, TrustLevel};
use crate::infra::cache::RedisCache;

#[derive(Clone)]
pub struct RateLimiter {
    cache: RedisCache,
}

impl RateLimiter {
    pub fn new(cache: RedisCache) -> Self {
        Self { cache }
    }

    /// Check if action is rate limited
    pub async fn check_rate_limit(
        &self,
        user_id: Uuid,
        action: &str,
        trust_level: TrustLevel,
    ) -> Result<bool> {
        let limits = RateLimits::for_trust_level(trust_level);

        let (limit, window_seconds) = match action {
            "post" => (limits.posts_per_hour, 3600),
            "post_daily" => (limits.posts_per_day, 86400),
            "follow" => (limits.follows_per_hour, 3600),
            "follow_daily" => (limits.follows_per_day, 86400),
            "unfollow_daily" => (limits.unfollows_per_day, 86400),
            "like" => (limits.likes_per_hour, 3600),
            "comment" => (limits.comments_per_hour, 3600),
            _ => return Ok(false),
        };

        let key = format!("ratelimit:{}:{}:{}", user_id, action, current_window(window_seconds));

        let mut conn = self.cache.client().get_multiplexed_async_connection().await?;

        // Get current count
        let count: u32 = conn.get(&key).await.unwrap_or(0);

        if count >= limit {
            return Ok(true); // Rate limited
        }

        // Increment counter
        let _: () = conn.incr(&key, 1).await?;

        // Set expiration on first increment
        if count == 0 {
            let _: () = conn.expire(&key, window_seconds as i64).await?;
        }

        Ok(false)
    }

    /// Get remaining quota
    pub async fn get_remaining(
        &self,
        user_id: Uuid,
        action: &str,
        trust_level: TrustLevel,
    ) -> Result<u32> {
        let limits = RateLimits::for_trust_level(trust_level);

        let (limit, window_seconds) = match action {
            "post" => (limits.posts_per_hour, 3600),
            "follow" => (limits.follows_per_hour, 3600),
            "like" => (limits.likes_per_hour, 3600),
            "comment" => (limits.comments_per_hour, 3600),
            _ => return Ok(0),
        };

        let key = format!("ratelimit:{}:{}:{}", user_id, action, current_window(window_seconds));

        let mut conn = self.cache.client().get_multiplexed_async_connection().await?;
        let count: u32 = conn.get(&key).await.unwrap_or(0);

        Ok(limit.saturating_sub(count))
    }
}

fn current_window(window_seconds: u32) -> u64 {
    use std::time::{SystemTime, UNIX_EPOCH};
    let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs();
    now / window_seconds as u64
}
```

### 1.5 Rate Limiting Middleware

**File: `src/http/middleware/rate_limit.rs`** (new)

```rust
use axum::extract::{Request, State};
use axum::middleware::Next;
use axum::response::Response;

use crate::app::rate_limiter::RateLimiter;
use crate::app::trust::TrustService;
use crate::http::{AppError, AuthUser};
use crate::AppState;

pub async fn rate_limit_middleware(
    State(state): State<AppState>,
    auth: Option<AuthUser>,
    request: Request,
    next: Next,
) -> Result<Response, AppError> {
    // Only apply to authenticated endpoints
    let Some(auth_user) = auth else {
        return Ok(next.run(request).await);
    };

    // Determine action type from path
    let path = request.uri().path();
    let method = request.method();

    let action = if path.starts_with("/posts") && method == "POST" {
        Some("post")
    } else if path.contains("/follow") && method == "POST" {
        Some("follow")
    } else if path.contains("/like") && method == "POST" {
        Some("like")
    } else if path.contains("/comment") && method == "POST" {
        Some("comment")
    } else {
        None
    };

    if let Some(action) = action {
        // Get trust level
        let trust_service = TrustService::new(state.db.clone());
        let trust_score = trust_service
            .get_trust_score(auth_user.user_id)
            .await
            .map_err(|_| AppError::internal("failed to check trust score"))?;

        let trust_level = trust_score
            .map(|s| s.trust_level)
            .unwrap_or(crate::config::rate_limits::TrustLevel::New);

        // Check rate limit
        let rate_limiter = RateLimiter::new(state.cache.clone());
        let is_limited = rate_limiter
            .check_rate_limit(auth_user.user_id, action, trust_level)
            .await
            .map_err(|_| AppError::internal("failed to check rate limit"))?;

        if is_limited {
            return Err(AppError::rate_limited(&format!(
                "Rate limit exceeded for {}. Please try again later.",
                action
            )));
        }
    }

    Ok(next.run(request).await)
}
```

### 1.6 Update AppError

**File: `src/http/error.rs`** (update)

```rust
// Add new error variant
impl AppError {
    pub fn rate_limited(message: &str) -> Self {
        Self {
            status_code: StatusCode::TOO_MANY_REQUESTS,
            message: message.to_string(),
        }
    }
}
```

### 1.7 Integration Points

**File: `src/http/mod.rs`** (update)

```rust
pub mod middleware;

use axum::middleware as axum_middleware;

pub fn router(state: AppState) -> Router {
    Router::new()
        .merge(routes::health())
        .merge(routes::auth())
        .merge(routes::users())
        .merge(routes::posts())
        .layer(axum_middleware::from_fn_with_state(
            state.clone(),
            middleware::rate_limit::rate_limit_middleware,
        ))
        .merge(routes::feed())
        // ... rest of routes
        .with_state(state)
}
```

**File: `src/app/mod.rs`** (update)

```rust
pub mod trust;
pub mod rate_limiter;
// ... existing modules
```

---

## Phase 2: Device Fingerprinting (Week 2) 🟡

### 2.1 Device Fingerprint Service

**File: `src/app/fingerprint.rs`** (new)

```rust
use anyhow::Result;
use sha2::{Digest, Sha256};
use sqlx::Row;
use uuid::Uuid;

use crate::infra::db::Db;

#[derive(Clone)]
pub struct FingerprintService {
    db: Db,
}

impl FingerprintService {
    pub fn new(db: Db) -> Self {
        Self { db }
    }

    /// Hash a fingerprint from FingerprintJS
    pub fn hash_fingerprint(fingerprint_data: &str) -> String {
        let mut hasher = Sha256::new();
        hasher.update(fingerprint_data.as_bytes());
        hex::encode(hasher.finalize())
    }

    /// Register device fingerprint for user
    pub async fn register_fingerprint(
        &self,
        fingerprint_hash: String,
        user_id: Uuid,
        user_agent: Option<String>,
    ) -> Result<()> {
        // Check if fingerprint exists
        let existing = sqlx::query(
            "SELECT fingerprint_hash, user_ids, account_count, risk_score \
             FROM device_fingerprints \
             WHERE fingerprint_hash = $1"
        )
        .bind(&fingerprint_hash)
        .fetch_optional(self.db.pool())
        .await?;

        if let Some(row) = existing {
            let mut user_ids: Vec<Uuid> = row.get("user_ids");
            let account_count: i32 = row.get("account_count");
            let mut risk_score: i32 = row.get("risk_score");

            // Add user if not already associated
            if !user_ids.contains(&user_id) {
                user_ids.push(user_id);

                // Increase risk score if multiple accounts from same device
                risk_score += match account_count {
                    0..=2 => 5,
                    3..=5 => 15,
                    6..=10 => 30,
                    _ => 50,
                };

                sqlx::query(
                    "UPDATE device_fingerprints \
                     SET user_ids = $1, \
                         account_count = $2, \
                         risk_score = LEAST($3, 100), \
                         last_seen_at = NOW(), \
                         updated_at = NOW() \
                     WHERE fingerprint_hash = $4"
                )
                .bind(&user_ids)
                .bind(user_ids.len() as i32)
                .bind(risk_score)
                .bind(&fingerprint_hash)
                .execute(self.db.pool())
                .await?;
            } else {
                // Just update last seen
                sqlx::query(
                    "UPDATE device_fingerprints \
                     SET last_seen_at = NOW() \
                     WHERE fingerprint_hash = $1"
                )
                .bind(&fingerprint_hash)
                .execute(self.db.pool())
                .await?;
            }
        } else {
            // New fingerprint
            sqlx::query(
                "INSERT INTO device_fingerprints \
                 (fingerprint_hash, user_ids, account_count, risk_score, user_agent) \
                 VALUES ($1, $2, 1, 0, $3)"
            )
            .bind(&fingerprint_hash)
            .bind(&vec![user_id])
            .bind(user_agent)
            .execute(self.db.pool())
            .await?;
        }

        Ok(())
    }

    /// Check if device is suspicious/blocked
    pub async fn check_device_risk(&self, fingerprint_hash: &str) -> Result<(i32, bool)> {
        let row = sqlx::query(
            "SELECT risk_score, is_blocked FROM device_fingerprints WHERE fingerprint_hash = $1"
        )
        .bind(fingerprint_hash)
        .fetch_optional(self.db.pool())
        .await?;

        if let Some(row) = row {
            let risk_score: i32 = row.get("risk_score");
            let is_blocked: bool = row.get("is_blocked");
            Ok((risk_score, is_blocked))
        } else {
            Ok((0, false))
        }
    }

    /// Block a device
    pub async fn block_device(&self, fingerprint_hash: &str, reason: &str) -> Result<()> {
        sqlx::query(
            "UPDATE device_fingerprints \
             SET is_blocked = TRUE, \
                 block_reason = $1, \
                 blocked_at = NOW(), \
                 updated_at = NOW() \
             WHERE fingerprint_hash = $2"
        )
        .bind(reason)
        .bind(fingerprint_hash)
        .execute(self.db.pool())
        .await?;

        Ok(())
    }
}
```

### 2.2 API Endpoints for Fingerprinting

**File: `src/http/handlers.rs`** (add)

```rust
#[derive(Deserialize)]
pub struct DeviceFingerprintPayload {
    pub fingerprint: String,
}

pub async fn register_device_fingerprint(
    auth: AuthUser,
    State(state): State<AppState>,
    headers: axum::http::HeaderMap,
    Json(payload): Json<DeviceFingerprintPayload>,
) -> Result<StatusCode, AppError> {
    let service = FingerprintService::new(state.db.clone());

    let user_agent = headers
        .get(header::USER_AGENT)
        .and_then(|v| v.to_str().ok())
        .map(|s| s.to_string());

    let fingerprint_hash = FingerprintService::hash_fingerprint(&payload.fingerprint);

    service
        .register_fingerprint(fingerprint_hash, auth.user_id, user_agent)
        .await
        .map_err(|err| {
            tracing::error!(error = ?err, "failed to register fingerprint");
            AppError::internal("failed to register device")
        })?;

    Ok(StatusCode::NO_CONTENT)
}
```

---

## Phase 3: Invite-Only Signup (Week 3) 🟡

### 3.1 Database Schema

**Migration: `007_invite_system.sql`**

```sql
CREATE TABLE invite_codes (
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
    use_count INT NOT NULL DEFAULT 0
);

CREATE INDEX idx_invite_codes_creator ON invite_codes(created_by);
CREATE INDEX idx_invite_codes_valid ON invite_codes(is_valid, expires_at) WHERE is_valid = TRUE;

-- Track invite trees (who invited whom)
CREATE TABLE invite_relationships (
    inviter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invitee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invite_code VARCHAR(16) NOT NULL,
    invited_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (inviter_id, invitee_id)
);

CREATE INDEX idx_invite_tree_inviter ON invite_relationships(inviter_id);
CREATE INDEX idx_invite_tree_invitee ON invite_relationships(invitee_id);

-- Add invite count to user_trust_scores
ALTER TABLE user_trust_scores
ADD COLUMN invites_sent INT NOT NULL DEFAULT 0,
ADD COLUMN successful_invites INT NOT NULL DEFAULT 0;
```

### 3.2 Invite Service

**File: `src/app/invites.rs`** (new)

```rust
use anyhow::{anyhow, Result};
use rand::distributions::Alphanumeric;
use rand::{thread_rng, Rng};
use sqlx::Row;
use time::OffsetDateTime;
use uuid::Uuid;

use crate::infra::db::Db;

#[derive(Clone)]
pub struct InviteService {
    db: Db,
}

#[derive(Debug, Clone)]
pub struct InviteCode {
    pub code: String,
    pub created_by: Uuid,
    pub used_by: Option<Uuid>,
    pub created_at: OffsetDateTime,
    pub used_at: Option<OffsetDateTime>,
    pub expires_at: OffsetDateTime,
    pub is_valid: bool,
}

impl InviteService {
    pub fn new(db: Db) -> Self {
        Self { db }
    }

    /// Generate a new invite code
    pub async fn create_invite(&self, user_id: Uuid, days_valid: i64) -> Result<String> {
        // Check if user can create more invites
        let trust_score: Option<(i32, i32, i32)> = sqlx::query_as(
            "SELECT trust_level, invites_sent, successful_invites \
             FROM user_trust_scores \
             WHERE user_id = $1"
        )
        .bind(user_id)
        .fetch_optional(self.db.pool())
        .await?;

        let (trust_level, invites_sent, successful_invites) =
            trust_score.unwrap_or((0, 0, 0));

        // Calculate max invites based on trust level
        let max_invites = match trust_level {
            0 => 3,   // New users: 3 invites
            1 => 10,  // Basic: 10 invites
            2 => 50,  // Trusted: 50 invites
            3 => 200, // Verified: 200 invites
            _ => 3,
        };

        if invites_sent >= max_invites {
            return Err(anyhow!("Maximum invite limit reached for your trust level"));
        }

        // Generate unique code
        let code = loop {
            let candidate: String = thread_rng()
                .sample_iter(&Alphanumeric)
                .take(12)
                .map(char::from)
                .collect();

            // Check uniqueness
            let exists: bool = sqlx::query_scalar(
                "SELECT EXISTS(SELECT 1 FROM invite_codes WHERE code = $1)"
            )
            .bind(&candidate)
            .fetch_one(self.db.pool())
            .await?;

            if !exists {
                break candidate;
            }
        };

        let expires_at = OffsetDateTime::now_utc() + time::Duration::days(days_valid);

        sqlx::query(
            "INSERT INTO invite_codes (code, created_by, expires_at) \
             VALUES ($1, $2, $3)"
        )
        .bind(&code)
        .bind(user_id)
        .bind(expires_at)
        .execute(self.db.pool())
        .await?;

        // Update invite count
        sqlx::query(
            "UPDATE user_trust_scores \
             SET invites_sent = invites_sent + 1 \
             WHERE user_id = $1"
        )
        .bind(user_id)
        .execute(self.db.pool())
        .await?;

        Ok(code)
    }

    /// Validate and consume an invite code
    pub async fn consume_invite(&self, code: &str, new_user_id: Uuid) -> Result<Uuid> {
        let mut tx = self.db.pool().begin().await?;

        // Fetch and validate invite
        let row = sqlx::query(
            "SELECT code, created_by, is_valid, expires_at, use_count, max_uses \
             FROM invite_codes \
             WHERE code = $1 \
             FOR UPDATE"
        )
        .bind(code)
        .fetch_optional(&mut *tx)
        .await?;

        let row = row.ok_or_else(|| anyhow!("Invalid invite code"))?;

        let is_valid: bool = row.get("is_valid");
        let expires_at: OffsetDateTime = row.get("expires_at");
        let use_count: i32 = row.get("use_count");
        let max_uses: i32 = row.get("max_uses");
        let created_by: Uuid = row.get("created_by");

        if !is_valid {
            return Err(anyhow!("Invite code has been revoked"));
        }

        if expires_at < OffsetDateTime::now_utc() {
            return Err(anyhow!("Invite code has expired"));
        }

        if use_count >= max_uses {
            return Err(anyhow!("Invite code has been fully used"));
        }

        // Mark as used
        sqlx::query(
            "UPDATE invite_codes \
             SET used_by = $1, \
                 used_at = NOW(), \
                 use_count = use_count + 1, \
                 is_valid = CASE WHEN use_count + 1 >= max_uses THEN FALSE ELSE TRUE END \
             WHERE code = $2"
        )
        .bind(new_user_id)
        .bind(code)
        .execute(&mut *tx)
        .await?;

        // Record relationship
        sqlx::query(
            "INSERT INTO invite_relationships (inviter_id, invitee_id, invite_code) \
             VALUES ($1, $2, $3)"
        )
        .bind(created_by)
        .bind(new_user_id)
        .bind(code)
        .execute(&mut *tx)
        .await?;

        // Update inviter's successful invite count
        sqlx::query(
            "UPDATE user_trust_scores \
             SET successful_invites = successful_invites + 1, \
                 trust_points = trust_points + 10 \
             WHERE user_id = $1"
        )
        .bind(created_by)
        .execute(&mut *tx)
        .await?;

        tx.commit().await?;

        Ok(created_by)
    }

    /// Get user's invite codes
    pub async fn list_user_invites(&self, user_id: Uuid) -> Result<Vec<InviteCode>> {
        let rows = sqlx::query(
            "SELECT code, created_by, used_by, created_at, used_at, expires_at, is_valid \
             FROM invite_codes \
             WHERE created_by = $1 \
             ORDER BY created_at DESC \
             LIMIT 50"
        )
        .bind(user_id)
        .fetch_all(self.db.pool())
        .await?;

        let invites = rows
            .into_iter()
            .map(|row| InviteCode {
                code: row.get("code"),
                created_by: row.get("created_by"),
                used_by: row.get("used_by"),
                created_at: row.get("created_at"),
                used_at: row.get("used_at"),
                expires_at: row.get("expires_at"),
                is_valid: row.get("is_valid"),
            })
            .collect();

        Ok(invites)
    }
}
```

### 3.3 Update Signup Flow

**File: `src/http/handlers.rs`** (update `create_user`)

```rust
#[derive(Deserialize)]
pub struct CreateUserRequest {
    pub handle: String,
    pub email: String,
    pub display_name: String,
    pub bio: Option<String>,
    pub avatar_key: Option<String>,
    pub password: String,
    pub invite_code: String,  // NEW: Required invite code
    pub device_fingerprint: Option<String>,  // NEW: Optional fingerprint
}

pub async fn create_user(
    State(state): State<AppState>,
    headers: axum::http::HeaderMap,
    Json(payload): Json<CreateUserRequest>,
) -> Result<Json<crate::domain::user::User>, AppError> {
    // Existing validation...

    // NEW: Validate and consume invite code
    let invite_service = InviteService::new(state.db.clone());
    let inviter_id = invite_service
        .consume_invite(&payload.invite_code, /* will be new user_id */)
        .await
        .map_err(|err| {
            tracing::warn!(error = ?err, "invalid invite code");
            AppError::bad_request("Invalid or expired invite code")
        })?;

    // Create user (existing logic)
    let user = auth_service.signup(...).await?;

    // NEW: Initialize trust score
    let trust_service = TrustService::new(state.db.clone());
    trust_service.initialize_user(user.id).await.map_err(|_| {
        AppError::internal("failed to initialize trust score")
    })?;

    // NEW: Register device fingerprint if provided
    if let Some(fingerprint) = payload.device_fingerprint {
        let fp_service = FingerprintService::new(state.db.clone());
        let fp_hash = FingerprintService::hash_fingerprint(&fingerprint);
        let user_agent = headers
            .get(header::USER_AGENT)
            .and_then(|v| v.to_str().ok())
            .map(|s| s.to_string());

        let _ = fp_service
            .register_fingerprint(fp_hash, user.id, user_agent)
            .await;
    }

    Ok(Json(user))
}
```

---

## Phase 4: Proof-of-Work (Week 4) 🟢

### 4.1 PoW Service

**File: `src/app/proof_of_work.rs`** (new)

```rust
use anyhow::{anyhow, Result};
use sha2::{Digest, Sha256};
use time::OffsetDateTime;
use uuid::Uuid;

use crate::infra::cache::RedisCache;

#[derive(Clone)]
pub struct ProofOfWorkService {
    cache: RedisCache,
    difficulty: u8,  // Number of leading zeros required
}

impl ProofOfWorkService {
    pub fn new(cache: RedisCache, difficulty: u8) -> Self {
        Self { cache, difficulty }
    }

    /// Generate a challenge for the client
    pub async fn generate_challenge(&self) -> Result<String> {
        let challenge = Uuid::new_v4().to_string();

        // Store challenge in Redis with 5-minute expiration
        let key = format!("pow:challenge:{}", challenge);
        let mut conn = self.cache.client().get_multiplexed_async_connection().await?;

        redis::cmd("SET")
            .arg(&key)
            .arg("1")
            .arg("EX")
            .arg(300)  // 5 minutes
            .query_async(&mut conn)
            .await?;

        Ok(challenge)
    }

    /// Verify proof-of-work solution
    pub async fn verify_solution(
        &self,
        challenge: &str,
        nonce: u64,
    ) -> Result<bool> {
        // Check if challenge exists and hasn't been used
        let key = format!("pow:challenge:{}", challenge);
        let mut conn = self.cache.client().get_multiplexed_async_connection().await?;

        let exists: bool = redis::cmd("EXISTS")
            .arg(&key)
            .query_async(&mut conn)
            .await?;

        if !exists {
            return Err(anyhow!("Challenge expired or already used"));
        }

        // Verify solution
        let input = format!("{}{}", challenge, nonce);
        let hash = Self::sha256(&input);

        // Check if hash has required number of leading zeros
        let valid = self.check_difficulty(&hash);

        if valid {
            // Delete challenge to prevent reuse
            let _: () = redis::cmd("DEL")
                .arg(&key)
                .query_async(&mut conn)
                .await?;
        }

        Ok(valid)
    }

    fn sha256(input: &str) -> String {
        let mut hasher = Sha256::new();
        hasher.update(input.as_bytes());
        hex::encode(hasher.finalize())
    }

    fn check_difficulty(&self, hash: &str) -> bool {
        let leading_zeros = hash.chars().take_while(|&c| c == '0').count();
        leading_zeros >= self.difficulty as usize
    }
}
```

### 4.2 PoW Endpoints

**File: `src/http/handlers.rs`** (add)

```rust
#[derive(Serialize)]
pub struct PowChallengeResponse {
    pub challenge: String,
    pub difficulty: u8,
}

#[derive(Deserialize)]
pub struct PowSolutionRequest {
    pub challenge: String,
    pub nonce: u64,
}

pub async fn get_pow_challenge(
    State(state): State<AppState>,
) -> Result<Json<PowChallengeResponse>, AppError> {
    let pow_service = ProofOfWorkService::new(state.cache.clone(), 4); // 4 leading zeros

    let challenge = pow_service
        .generate_challenge()
        .await
        .map_err(|_| AppError::internal("failed to generate challenge"))?;

    Ok(Json(PowChallengeResponse {
        challenge,
        difficulty: 4,
    }))
}

// Update signup to require PoW
#[derive(Deserialize)]
pub struct CreateUserRequest {
    // ... existing fields
    pub pow_challenge: String,
    pub pow_nonce: u64,
}

pub async fn create_user(
    State(state): State<AppState>,
    Json(payload): Json<CreateUserRequest>,
) -> Result<Json<crate::domain::user::User>, AppError> {
    // NEW: Verify proof-of-work
    let pow_service = ProofOfWorkService::new(state.cache.clone(), 4);
    let valid = pow_service
        .verify_solution(&payload.pow_challenge, payload.pow_nonce)
        .await
        .map_err(|_| AppError::bad_request("Invalid proof-of-work"))?;

    if !valid {
        return Err(AppError::bad_request("Invalid proof-of-work solution"));
    }

    // Continue with signup...
}
```

---

## Phase 5: Behavior Analysis (Week 5-6) 🟢

### 5.1 Behavior Analyzer Background Job

**File: `src/jobs/behavior_analyzer.rs`** (new)

```rust
use anyhow::Result;
use sqlx::Row;
use time::OffsetDateTime;
use tracing::{info, warn};
use uuid::Uuid;

use crate::app::trust::TrustService;
use crate::infra::db::Db;

pub async fn run(db: Db) -> Result<()> {
    info!("behavior analyzer started");

    loop {
        // Analyze recent activity patterns
        if let Err(err) = analyze_follow_patterns(&db).await {
            warn!(error = ?err, "failed to analyze follow patterns");
        }

        if let Err(err) = analyze_like_patterns(&db).await {
            warn!(error = ?err, "failed to analyze like patterns");
        }

        if let Err(err) = detect_spam_comments(&db).await {
            warn!(error = ?err, "failed to detect spam comments");
        }

        // Run every 5 minutes
        tokio::time::sleep(tokio::time::Duration::from_secs(300)).await;
    }
}

/// Detect abnormal follow patterns
async fn analyze_follow_patterns(db: &Db) -> Result<()> {
    // Find users who followed > 100 accounts in last hour
    let rows = sqlx::query(
        "SELECT follower_id, COUNT(*) as follow_count \
         FROM follows \
         WHERE created_at > NOW() - INTERVAL '1 hour' \
         GROUP BY follower_id \
         HAVING COUNT(*) > 100"
    )
    .fetch_all(db.pool())
    .await?;

    let trust_service = TrustService::new(db.clone());

    for row in rows {
        let user_id: Uuid = row.get("follower_id");
        let count: i64 = row.get("follow_count");

        warn!(
            user_id = %user_id,
            follow_count = count,
            "suspicious follow pattern detected"
        );

        // Add strike for suspicious behavior
        trust_service
            .add_strike(user_id, &format!("Suspicious follow pattern: {} follows in 1 hour", count))
            .await?;
    }

    Ok(())
}

/// Detect abnormal like patterns
async fn analyze_like_patterns(db: &Db) -> Result<()> {
    // Find users who liked > 500 posts in last hour
    let rows = sqlx::query(
        "SELECT user_id, COUNT(*) as like_count \
         FROM likes \
         WHERE created_at > NOW() - INTERVAL '1 hour' \
         GROUP BY user_id \
         HAVING COUNT(*) > 500"
    )
    .fetch_all(db.pool())
    .await?;

    let trust_service = TrustService::new(db.clone());

    for row in rows {
        let user_id: Uuid = row.get("user_id");
        let count: i64 = row.get("like_count");

        warn!(
            user_id = %user_id,
            like_count = count,
            "suspicious like pattern detected"
        );

        trust_service
            .add_strike(user_id, &format!("Suspicious like pattern: {} likes in 1 hour", count))
            .await?;
    }

    Ok(())
}

/// Detect spam comments
async fn detect_spam_comments(db: &Db) -> Result<()> {
    // Find users posting duplicate/similar comments
    let rows = sqlx::query(
        "SELECT user_id, body, COUNT(*) as comment_count \
         FROM comments \
         WHERE created_at > NOW() - INTERVAL '1 hour' \
         GROUP BY user_id, body \
         HAVING COUNT(*) > 10"
    )
    .fetch_all(db.pool())
    .await?;

    let trust_service = TrustService::new(db.clone());

    for row in rows {
        let user_id: Uuid = row.get("user_id");
        let count: i64 = row.get("comment_count");

        warn!(
            user_id = %user_id,
            duplicate_comments = count,
            "spam comment pattern detected"
        );

        trust_service
            .add_strike(user_id, "Spam comment pattern detected")
            .await?;
    }

    Ok(())
}
```

### 5.2 Update main.rs for Worker Mode

**File: `src/main.rs`** (update)

```rust
"worker" => {
    tracing::info!("starting worker mode");
    tokio::select! {
        result = jobs::media_processor::run(
            state.db.clone(),
            state.storage.clone(),
            state.queue.clone()
        ) => {
            result?;
        }
        // NEW: Add behavior analyzer
        result = jobs::behavior_analyzer::run(state.db.clone()) => {
            result?;
        }
        _ = shutdown_signal() => {}
    }
}
```

---

## Implementation Summary

### Dependencies to Add

**File: `Cargo.toml`**

```toml
[dependencies]
# Existing dependencies...

# NEW: Rate limiting and fingerprinting
tower-governor = "0.3"  # Rate limiting middleware
hex = "0.4"             # Hex encoding for hashes (already exists)
rand = "0.8"            # Random string generation for invite codes
```

### Database Migrations Checklist

- [ ] `006_rate_limiting_and_trust.sql` (Phase 1)
- [ ] `007_invite_system.sql` (Phase 3)

### New Files Created

```
src/
├── config/
│   └── rate_limits.rs           (NEW)
├── app/
│   ├── trust.rs                 (NEW)
│   ├── rate_limiter.rs          (NEW)
│   ├── fingerprint.rs           (NEW)
│   ├── invites.rs               (NEW)
│   └── proof_of_work.rs         (NEW)
├── http/
│   └── middleware/
│       └── rate_limit.rs        (NEW)
└── jobs/
    └── behavior_analyzer.rs     (NEW)
```

### API Endpoints Added

```
POST   /auth/signup               (updated - requires invite + PoW)
POST   /auth/pow/challenge        (new - get PoW challenge)
POST   /auth/device/register      (new - register fingerprint)

GET    /invites                   (new - list user's invites)
POST   /invites                   (new - create invite code)
GET    /invites/stats             (new - invite statistics)

GET    /account/trust-score       (new - get user's trust score)
GET    /account/rate-limits       (new - get current rate limits)
```

### Testing Strategy

#### Unit Tests
```bash
# Phase 1: Rate limiting
cargo test test_rate_limit_new_user
cargo test test_rate_limit_trusted_user
cargo test test_trust_score_calculation

# Phase 2: Fingerprinting
cargo test test_fingerprint_hashing
cargo test test_multiple_accounts_same_device

# Phase 3: Invites
cargo test test_invite_creation
cargo test test_invite_consumption
cargo test test_expired_invite

# Phase 4: Proof-of-Work
cargo test test_pow_challenge_generation
cargo test test_pow_solution_verification

# Phase 5: Behavior Analysis
cargo test test_detect_follow_spam
cargo test test_detect_like_spam
```

#### Integration Tests
```bash
# Test full signup flow with invite + PoW
cargo test test_signup_with_invite_and_pow

# Test rate limiting enforcement
cargo test test_rate_limit_enforcement

# Test trust level progression
cargo test test_trust_level_upgrade
```

### Deployment Checklist

#### Phase 1 (Rate Limiting) - Production Deploy
- [ ] Run migration `006_rate_limiting_and_trust.sql`
- [ ] Deploy API with rate limiting middleware
- [ ] Monitor rate limit hit rates in logs
- [ ] Set up alerts for high rate limit violations
- [ ] Verify Redis connection for rate limit storage

#### Phase 2 (Fingerprinting) - Production Deploy
- [ ] Deploy API with fingerprint endpoints
- [ ] Update frontend to send fingerprints
- [ ] Monitor device risk scores
- [ ] Set threshold for automatic blocks (risk_score > 80)

#### Phase 3 (Invites) - Production Deploy
- [ ] Run migration `007_invite_system.sql`
- [ ] Generate initial invite codes for beta users
- [ ] Deploy invite system
- [ ] Monitor invite code usage
- [ ] Set up admin dashboard for invite management

#### Phase 4 (PoW) - Gradual Rollout
- [ ] Deploy PoW challenge endpoint
- [ ] Update frontend with PoW solver
- [ ] Enable PoW for new signups (feature flag)
- [ ] Monitor signup completion rates
- [ ] Adjust difficulty if needed (4-6 leading zeros)

#### Phase 5 (Behavior Analysis) - Background Deploy
- [ ] Deploy worker with behavior analyzer
- [ ] Monitor false positive rate
- [ ] Tune detection thresholds
- [ ] Set up manual review queue for strikes

### Performance Considerations

#### Redis Requirements
- **Rate limiting**: ~1000 keys per active user per day
- **PoW challenges**: ~10 keys per signup attempt
- **Memory estimate**: ~100MB for 10K active users
- **Recommendation**: Use Redis Cluster at 50K+ users

#### Database Load
- **Trust score updates**: ~10 writes per active user per day
- **Rate limit logging**: Optional (can be Redis-only)
- **Behavior analysis**: Runs every 5 minutes, scans last hour
- **Recommendation**: Add read replica for behavior analysis queries

#### API Latency Impact
- **Rate limit check**: +2-5ms per request (Redis lookup)
- **Trust score check**: +5-10ms per request (PostgreSQL)
- **Fingerprint registration**: +20-50ms (one-time per device)
- **PoW verification**: +5-10ms per signup

### Monitoring & Alerts

```yaml
# Prometheus metrics to track
- rate_limit_hits_total{action, trust_level}
- trust_score_distribution{level}
- device_risk_score_distribution
- invite_codes_created_total
- invite_codes_used_total
- behavior_violations_detected_total{type}
- signup_with_pow_success_rate
- signup_with_pow_duration_seconds

# Alerts to configure
- High rate limit violation rate (> 10% of requests)
- Multiple accounts from same device (> 5)
- Trust score drops (user demoted to New)
- Behavior violations spike (> 50 per hour)
- PoW success rate drops (< 95%)
```

---

## Cost-Benefit Analysis

### Development Cost
| Phase | Effort | Engineer Cost (@$150/hr) |
|-------|--------|--------------------------|
| Phase 1: Rate Limiting | 40 hours | $6,000 |
| Phase 2: Fingerprinting | 20 hours | $3,000 |
| Phase 3: Invites | 24 hours | $3,600 |
| Phase 4: Proof-of-Work | 16 hours | $2,400 |
| Phase 5: Behavior Analysis | 24 hours | $3,600 |
| **Total** | **124 hours** | **$18,600** |

### Infrastructure Cost
- Redis instance: +$15-30/month
- Database storage: +$5/month (trust scores, invites)
- Worker instance: +$50/month (behavior analysis)
- **Total:** +$70-85/month

### Value Delivered
- **Prevents**: Bot armies, spam, abuse, platform takeover
- **Saves**: Manual moderation time ($50K+/year)
- **Enables**: Invite-based growth strategy
- **Protects**: User experience, brand reputation

**ROI:** 10-20x over 12 months

---

## Recommended Implementation Order

### Week 1 (Critical) 🔴
✅ Phase 1: Rate Limiting + Trust System
- Addresses critical security gap
- Foundation for all other features
- Immediate protection against abuse

### Week 2 (Important) 🟡
✅ Phase 2: Device Fingerprinting
- Detects multi-account abuse
- Complements rate limiting
- Low complexity, high value

### Week 3 (Important) 🟡
✅ Phase 3: Invite-Only Signup
- Controls growth rate
- Builds network effects
- Creates exclusivity

### Week 4 (Nice to Have) 🟢
⚪ Phase 4: Proof-of-Work
- Extra bot protection
- Can defer if invite system works well
- May impact mobile UX

### Week 5-6 (Nice to Have) 🟢
⚪ Phase 5: Behavior Analysis
- Automated moderation
- Catches sophisticated abuse
- Can start simple and iterate

---

## Final Recommendation

**Implement Phases 1-3 immediately** (3 weeks, $12,600):
1. Rate limiting (Week 1) - Critical security fix
2. Device fingerprinting (Week 2) - Multi-account prevention
3. Invite system (Week 3) - Growth control + network effects

**Defer Phases 4-5** until after launch (can add in Month 2-3):
4. Proof-of-Work - If bot problem persists
5. Behavior Analysis - When you have enough data

This gets you **80% of the value in 50% of the time**, with immediate protection against the most common abuse patterns.

---

**Implementation Lead:** [Your Name]
**Review Date:** February 2, 2026
**Next Review:** After Phase 1-3 completion (3 weeks)
