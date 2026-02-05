use axum::extract::{Request, State};
use axum::middleware::Next;
use axum::response::Response;

use crate::app::trust::TrustService;
use crate::http::{AppError, AuthUser};
use crate::AppState;

/// Global ban check for authenticated requests.
pub async fn ban_check_middleware(
    State(state): State<AppState>,
    auth: Option<AuthUser>,
    request: Request,
    next: Next,
) -> Result<Response, AppError> {
    if let Some(auth_user) = auth {
        let trust_service = TrustService::new(state.db.clone());
        let is_banned = trust_service
            .is_banned(auth_user.user_id)
            .await
            .map_err(|err| {
                tracing::error!(error = ?err, "failed to check ban status");
                AppError::internal("failed to check ban status")
            })?;

        if is_banned {
            return Err(AppError::forbidden(
                "Your account has been temporarily suspended",
            ));
        }
    }

    Ok(next.run(request).await)
}
