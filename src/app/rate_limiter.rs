use anyhow::Result;
use redis::AsyncCommands;
use uuid::Uuid;

use crate::config::rate_limits::{current_window, RateLimits, RateWindow, TrustLevel};
use crate::infra::cache::RedisCache;

#[derive(Clone)]
pub struct RateLimiter {
    cache: RedisCache,
}

impl RateLimiter {
    pub fn new(cache: RedisCache) -> Self {
        Self { cache }
    }

    /// Check if action is rate limited, returns true if limit exceeded
    pub async fn check_rate_limit(
        &self,
        user_id: Uuid,
        action: &str,
        trust_level: TrustLevel,
    ) -> Result<bool> {
        let limits = RateLimits::for_trust_level(trust_level);

        // Check both hourly and daily limits where applicable
        let checks = match action {
            "post" => vec![
                (limits.posts_per_hour, RateWindow::Hour),
                (limits.posts_per_day, RateWindow::Day),
            ],
            "follow" => vec![
                (limits.follows_per_hour, RateWindow::Hour),
                (limits.follows_per_day, RateWindow::Day),
            ],
            "unfollow" => vec![(limits.unfollows_per_day, RateWindow::Day)],
            "like" => vec![(limits.likes_per_hour, RateWindow::Hour)],
            "comment" => vec![(limits.comments_per_hour, RateWindow::Hour)],
            "login" => vec![(limits.login_attempts_per_hour, RateWindow::Hour)],
            _ => return Ok(false), // Unknown action, don't rate limit
        };

        let mut conn = self.cache.client().get_multiplexed_async_connection().await?;

        // Check all applicable windows
        for (limit, window) in checks {
            let window_seconds = window.seconds();
            let key = format!(
                "ratelimit:{}:{}:{}",
                user_id,
                action,
                current_window(window_seconds)
            );

            let count: u32 = conn.get(&key).await.unwrap_or(0);

            if count >= limit {
                tracing::debug!(
                    user_id = %user_id,
                    action = action,
                    window = ?window,
                    count = count,
                    limit = limit,
                    "Rate limit exceeded"
                );
                return Ok(true); // Rate limited
            }
        }

        Ok(false)
    }

    /// Increment rate limit counter for an action
    pub async fn increment(
        &self,
        user_id: Uuid,
        action: &str,
    ) -> Result<()> {
        let windows = match action {
            "post" => vec![RateWindow::Hour, RateWindow::Day],
            "follow" => vec![RateWindow::Hour, RateWindow::Day],
            "unfollow" => vec![RateWindow::Day],
            "like" | "comment" | "login" => vec![RateWindow::Hour],
            _ => return Ok(()), // Unknown action, skip
        };

        let mut conn = self.cache.client().get_multiplexed_async_connection().await?;

        for window in windows {
            let window_seconds = window.seconds();
            let key = format!(
                "ratelimit:{}:{}:{}",
                user_id,
                action,
                current_window(window_seconds)
            );

            // Get current count
            let count: u32 = conn.get(&key).await.unwrap_or(0);

            // Increment
            let _: () = conn.incr(&key, 1).await?;

            // Set expiration on first increment
            if count == 0 {
                let _: () = conn.expire(&key, window_seconds as i64).await?;
            }
        }

        Ok(())
    }

    /// Get remaining quota for an action
    pub async fn get_remaining(
        &self,
        user_id: Uuid,
        action: &str,
        trust_level: TrustLevel,
    ) -> Result<u32> {
        let limits = RateLimits::for_trust_level(trust_level);

        let (limit, window) = match action {
            "post" => (limits.posts_per_hour, RateWindow::Hour),
            "follow" => (limits.follows_per_hour, RateWindow::Hour),
            "like" => (limits.likes_per_hour, RateWindow::Hour),
            "comment" => (limits.comments_per_hour, RateWindow::Hour),
            _ => return Ok(0),
        };

        let window_seconds = window.seconds();
        let key = format!(
            "ratelimit:{}:{}:{}",
            user_id,
            action,
            current_window(window_seconds)
        );

        let mut conn = self.cache.client().get_multiplexed_async_connection().await?;
        let count: u32 = conn.get(&key).await.unwrap_or(0);

        Ok(limit.saturating_sub(count))
    }

    /// Check rate limit by IP address (for unauthenticated requests)
    pub async fn check_ip_rate_limit(
        &self,
        ip: &str,
        action: &str,
        limit: u32,
        window: RateWindow,
    ) -> Result<bool> {
        let window_seconds = window.seconds();
        let key = format!("ratelimit:ip:{}:{}:{}", ip, action, current_window(window_seconds));

        let mut conn = self.cache.client().get_multiplexed_async_connection().await?;

        let count: u32 = conn.get(&key).await.unwrap_or(0);

        if count >= limit {
            tracing::debug!(
                ip = ip,
                action = action,
                count = count,
                limit = limit,
                "IP rate limit exceeded"
            );
            return Ok(true); // Rate limited
        }

        Ok(false)
    }

    /// Increment IP-based rate limit counter
    pub async fn increment_ip(&self, ip: &str, action: &str, window: RateWindow) -> Result<()> {
        let window_seconds = window.seconds();
        let key = format!("ratelimit:ip:{}:{}:{}", ip, action, current_window(window_seconds));

        let mut conn = self.cache.client().get_multiplexed_async_connection().await?;

        let count: u32 = conn.get(&key).await.unwrap_or(0);
        let _: () = conn.incr(&key, 1).await?;

        if count == 0 {
            let _: () = conn.expire(&key, window_seconds as i64).await?;
        }

        Ok(())
    }
}
