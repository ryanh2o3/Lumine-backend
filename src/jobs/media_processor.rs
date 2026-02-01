use anyhow::{anyhow, Result};
use aws_sdk_s3::primitives::ByteStream;
use image::GenericImageView;
use serde::{Deserialize, Serialize};
use sqlx::Row;
use std::time::Duration;
use uuid::Uuid;
use tracing::{error, info, warn};

use crate::infra::{db::Db, queue::QueueClient, storage::ObjectStorage};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MediaJob {
    pub upload_id: Uuid,
    pub owner_id: Uuid,
    pub original_key: String,
}

const POLL_WAIT_SECONDS: i32 = 10;
const IDLE_SLEEP_MS: u64 = 200;
const ERROR_BACKOFF_MS: u64 = 1000;

enum ProcessingOutcome {
    Completed,
    RetryLater,
}

pub async fn run(db: Db, storage: ObjectStorage, queue: QueueClient) -> Result<()> {
    info!("media processor started");
    loop {
        match queue.receive_media_job(POLL_WAIT_SECONDS).await {
            Ok(Some(message)) => {
                let outcome = match process_job(&db, &storage, &message.job).await {
                    Ok(outcome) => outcome,
                    Err(err) => {
                        error!(
                            error = ?err,
                            upload_id = %message.job.upload_id,
                            "failed to process media job"
                        );
                        let _ = mark_failed(&db, &message.job).await;
                        ProcessingOutcome::Completed
                    }
                };

                if matches!(outcome, ProcessingOutcome::Completed) {
                    if let Err(err) = queue.delete_message(&message.receipt_handle).await {
                        warn!(error = ?err, "failed to delete queue message");
                    }
                }
            }
            Ok(None) => {
                tokio::time::sleep(Duration::from_millis(IDLE_SLEEP_MS)).await;
            }
            Err(err) => {
                warn!(error = ?err, "queue receive failed, backing off");
                tokio::time::sleep(Duration::from_millis(ERROR_BACKOFF_MS)).await;
            }
        }
    }
}

async fn process_job(
    db: &Db,
    storage: &ObjectStorage,
    job: &MediaJob,
) -> Result<ProcessingOutcome> {
    let row = sqlx::query(
        "UPDATE media_uploads \
         SET status = 'processing' \
         WHERE id = $1 AND owner_id = $2 AND status = 'uploaded' \
         RETURNING original_key, content_type, bytes",
    )
    .bind(job.upload_id)
    .bind(job.owner_id)
    .fetch_optional(db.pool())
    .await?;

    let (original_key, content_type, bytes) = match row {
        Some(row) => (
            row.get::<String, _>("original_key"),
            row.get::<String, _>("content_type"),
            row.get::<i64, _>("bytes"),
        ),
        None => {
            let status_row = sqlx::query(
                "SELECT status::text AS status FROM media_uploads WHERE id = $1 AND owner_id = $2",
            )
            .bind(job.upload_id)
            .bind(job.owner_id)
            .fetch_optional(db.pool())
            .await?;

            if let Some(status_row) = status_row {
                let status: String = status_row.get("status");
                if status == "completed" {
                    return Ok(ProcessingOutcome::Completed);
                }
            }
            return Ok(ProcessingOutcome::RetryLater);
        }
    };

    let object = storage
        .client()
        .get_object()
        .bucket(storage.bucket())
        .key(&original_key)
        .send()
        .await?;

    let data = object.body.collect().await?.into_bytes();
    let image = image::load_from_memory(&data)
        .map_err(|err| anyhow!("failed to decode image: {}", err))?;
    let (width, height) = image.dimensions();

    let ext = extension_from_content_type(&content_type)?;
    let thumb_key = format!("media/{}/{}/thumb.{}", job.owner_id, job.upload_id, ext);
    let medium_key = format!("media/{}/{}/medium.{}", job.owner_id, job.upload_id, ext);

    upload_variant(storage, &thumb_key, &content_type, data.clone()).await?;
    upload_variant(storage, &medium_key, &content_type, data.clone()).await?;

    let media_id = Uuid::new_v4();
    sqlx::query(
        "INSERT INTO media (id, owner_id, original_key, thumb_key, medium_key, width, height, bytes) \
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)",
    )
    .bind(media_id)
    .bind(job.owner_id)
    .bind(original_key)
    .bind(thumb_key)
    .bind(medium_key)
    .bind(width as i32)
    .bind(height as i32)
    .bind(bytes)
    .execute(db.pool())
    .await?;

    sqlx::query(
        "UPDATE media_uploads \
         SET status = 'completed', processed_media_id = $1 \
         WHERE id = $2 AND owner_id = $3",
    )
    .bind(media_id)
    .bind(job.upload_id)
    .bind(job.owner_id)
    .execute(db.pool())
    .await?;

    info!(upload_id = %job.upload_id, media_id = %media_id, "media processing completed");
    Ok(ProcessingOutcome::Completed)
}

async fn upload_variant(
    storage: &ObjectStorage,
    key: &str,
    content_type: &str,
    bytes: bytes::Bytes,
) -> Result<()> {
    storage
        .client()
        .put_object()
        .bucket(storage.bucket())
        .key(key)
        .content_type(content_type)
        .body(ByteStream::from(bytes))
        .send()
        .await?;
    Ok(())
}

async fn mark_failed(db: &Db, job: &MediaJob) -> Result<()> {
    sqlx::query(
        "UPDATE media_uploads \
         SET status = 'failed' \
         WHERE id = $1 AND owner_id = $2 AND status = 'processing'",
    )
    .bind(job.upload_id)
    .bind(job.owner_id)
    .execute(db.pool())
    .await?;
    Ok(())
}

fn extension_from_content_type(content_type: &str) -> Result<&'static str> {
    match content_type {
        "image/jpeg" => Ok("jpg"),
        "image/png" => Ok("png"),
        "image/webp" => Ok("webp"),
        _ => Err(anyhow!("unsupported content type")),
    }
}
