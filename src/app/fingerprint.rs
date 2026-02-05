use anyhow::Result;
use sha2::{Digest, Sha256};
use sqlx::Row;
use uuid::Uuid;

use crate::infra::db::Db;

#[derive(Clone)]
pub struct FingerprintService {
    db: Db,
}

#[derive(Debug, Clone)]
#[allow(dead_code)]
pub struct DeviceInfo {
    pub fingerprint_hash: String,
    pub user_ids: Vec<Uuid>,
    pub account_count: i32,
    pub risk_score: i32,
    pub is_blocked: bool,
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

    /// Register device fingerprint for user (user_id is optional for unauthenticated registration)
    pub async fn register_fingerprint(
        &self,
        fingerprint_hash: String,
        user_id: Option<Uuid>,
        user_agent: Option<String>,
    ) -> Result<DeviceInfo> {
        // Check if fingerprint exists
        let existing = sqlx::query(
            "SELECT fingerprint_hash, user_ids, account_count, risk_score, is_blocked \
             FROM device_fingerprints \
             WHERE fingerprint_hash = $1",
        )
        .bind(&fingerprint_hash)
        .fetch_optional(self.db.pool())
        .await?;

        if let Some(row) = existing {
            let mut user_ids: Vec<Uuid> = row.get("user_ids");
            let account_count: i32 = row.get("account_count");
            let mut risk_score: i32 = row.get("risk_score");
            let is_blocked: bool = row.get("is_blocked");

            // Check if already blocked
            if is_blocked {
                return Ok(DeviceInfo {
                    fingerprint_hash,
                    user_ids,
                    account_count,
                    risk_score,
                    is_blocked: true,
                });
            }

            // Only process user association if user_id is provided
            if let Some(user_id) = user_id {
                // Add user if not already associated
                if !user_ids.contains(&user_id) {
                    user_ids.push(user_id);

                    // Increase risk score based on number of accounts
                    let risk_increase = match account_count {
                        0..=2 => 5,
                        3..=5 => 15,
                        6..=10 => 30,
                        _ => 50,
                    };

                    risk_score = (risk_score + risk_increase).min(100);
                    let new_account_count = user_ids.len() as i32;

                    sqlx::query(
                        "UPDATE device_fingerprints \
                         SET user_ids = $1, \
                             account_count = $2, \
                             risk_score = $3, \
                             last_seen_at = NOW(), \
                             updated_at = NOW() \
                         WHERE fingerprint_hash = $4",
                    )
                    .bind(&user_ids)
                    .bind(new_account_count)
                    .bind(risk_score)
                    .bind(&fingerprint_hash)
                    .execute(self.db.pool())
                    .await?;

                    tracing::info!(
                        fingerprint_hash = &fingerprint_hash[..8],
                        account_count = new_account_count,
                        risk_score = risk_score,
                        "Device fingerprint updated"
                    );

                    return Ok(DeviceInfo {
                        fingerprint_hash,
                        user_ids,
                        account_count: new_account_count,
                        risk_score,
                        is_blocked: false,
                    });
                } else {
                    // Just update last seen
                    sqlx::query(
                        "UPDATE device_fingerprints \
                         SET last_seen_at = NOW() \
                         WHERE fingerprint_hash = $1",
                    )
                    .bind(&fingerprint_hash)
                    .execute(self.db.pool())
                    .await?;

                    return Ok(DeviceInfo {
                        fingerprint_hash,
                        user_ids,
                        account_count,
                        risk_score,
                        is_blocked: false,
                    });
                }
            } else {
                // No user_id provided, just update last seen for existing device
                sqlx::query(
                    "UPDATE device_fingerprints \
                     SET last_seen_at = NOW() \
                     WHERE fingerprint_hash = $1",
                )
                .bind(&fingerprint_hash)
                .execute(self.db.pool())
                .await?;

                return Ok(DeviceInfo {
                    fingerprint_hash,
                    user_ids,
                    account_count,
                    risk_score,
                    is_blocked: false,
                });
            }
        } else {
            // New fingerprint
            if let Some(user_id) = user_id {
                // Authenticated registration - associate with user
                sqlx::query(
                    "INSERT INTO device_fingerprints \
                     (fingerprint_hash, user_ids, account_count, risk_score, user_agent) \
                     VALUES ($1, $2, 1, 0, $3)",
                )
                .bind(&fingerprint_hash)
                .bind(&vec![user_id])
                .bind(user_agent)
                .execute(self.db.pool())
                .await?;

                tracing::info!(
                    fingerprint_hash = &fingerprint_hash[..8],
                    "New device fingerprint registered"
                );

                Ok(DeviceInfo {
                    fingerprint_hash,
                    user_ids: vec![user_id],
                    account_count: 1,
                    risk_score: 0,
                    is_blocked: false,
                })
            } else {
                // Unauthenticated registration - no user association
                sqlx::query(
                    "INSERT INTO device_fingerprints \
                     (fingerprint_hash, user_ids, account_count, risk_score, user_agent) \
                     VALUES ($1, $2, 0, 0, $3)",
                )
                .bind(&fingerprint_hash)
                .bind(&vec![] as &Vec<Uuid>)
                .bind(user_agent)
                .execute(self.db.pool())
                .await?;

                tracing::info!(
                    fingerprint_hash = &fingerprint_hash[..8],
                    "New unauthenticated device fingerprint registered"
                );

                Ok(DeviceInfo {
                    fingerprint_hash,
                    user_ids: vec![],
                    account_count: 0,
                    risk_score: 0,
                    is_blocked: false,
                })
            }
        }
    }

    /// Check if device is suspicious or blocked
    pub async fn check_device_risk(&self, fingerprint_hash: &str) -> Result<(i32, bool)> {
        let row = sqlx::query(
            "SELECT risk_score, is_blocked \
             FROM device_fingerprints \
             WHERE fingerprint_hash = $1",
        )
        .bind(fingerprint_hash)
        .fetch_optional(self.db.pool())
        .await?;

        if let Some(row) = row {
            let risk_score: i32 = row.get("risk_score");
            let is_blocked: bool = row.get("is_blocked");
            Ok((risk_score, is_blocked))
        } else {
            Ok((0, false)) // New device, no risk
        }
    }

    /// Block a device
    #[allow(dead_code)]
    pub async fn block_device(&self, fingerprint_hash: &str, reason: &str) -> Result<()> {
        sqlx::query(
            "UPDATE device_fingerprints \
             SET is_blocked = TRUE, \
                 block_reason = $1, \
                 blocked_at = NOW(), \
                 updated_at = NOW() \
             WHERE fingerprint_hash = $2",
        )
        .bind(reason)
        .bind(fingerprint_hash)
        .execute(self.db.pool())
        .await?;

        tracing::warn!(
            fingerprint_hash = &fingerprint_hash[..8],
            reason = reason,
            "Device fingerprint blocked"
        );

        Ok(())
    }

    /// Unblock a device
    #[allow(dead_code)]
    pub async fn unblock_device(&self, fingerprint_hash: &str) -> Result<()> {
        sqlx::query(
            "UPDATE device_fingerprints \
             SET is_blocked = FALSE, \
                 block_reason = NULL, \
                 blocked_at = NULL, \
                 risk_score = risk_score / 2, \
                 updated_at = NOW() \
             WHERE fingerprint_hash = $1",
        )
        .bind(fingerprint_hash)
        .execute(self.db.pool())
        .await?;

        Ok(())
    }

    /// Get all devices for a user
    pub async fn get_user_devices(&self, user_id: Uuid) -> Result<Vec<DeviceInfo>> {
        let rows = sqlx::query(
            "SELECT fingerprint_hash, user_ids, account_count, risk_score, is_blocked \
             FROM device_fingerprints \
             WHERE $1 = ANY(user_ids) \
             ORDER BY last_seen_at DESC",
        )
        .bind(user_id)
        .fetch_all(self.db.pool())
        .await?;

        let devices = rows
            .into_iter()
            .map(|row| DeviceInfo {
                fingerprint_hash: row.get("fingerprint_hash"),
                user_ids: row.get("user_ids"),
                account_count: row.get("account_count"),
                risk_score: row.get("risk_score"),
                is_blocked: row.get("is_blocked"),
            })
            .collect();

        Ok(devices)
    }

    /// Get high-risk devices (for admin review)
    #[allow(dead_code)]
    pub async fn get_high_risk_devices(&self, min_risk_score: i32) -> Result<Vec<DeviceInfo>> {
        let rows = sqlx::query(
            "SELECT fingerprint_hash, user_ids, account_count, risk_score, is_blocked \
             FROM device_fingerprints \
             WHERE risk_score >= $1 AND is_blocked = FALSE \
             ORDER BY risk_score DESC \
             LIMIT 100",
        )
        .bind(min_risk_score)
        .fetch_all(self.db.pool())
        .await?;

        let devices = rows
            .into_iter()
            .map(|row| DeviceInfo {
                fingerprint_hash: row.get("fingerprint_hash"),
                user_ids: row.get("user_ids"),
                account_count: row.get("account_count"),
                risk_score: row.get("risk_score"),
                is_blocked: row.get("is_blocked"),
            })
            .collect();

        Ok(devices)
    }
}
