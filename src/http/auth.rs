use axum::extract::FromRequestParts;
use axum::http::header;
use axum::http::request::Parts;

use crate::app::auth::AuthService;
use crate::http::AppError;
use crate::AppState;

#[derive(Debug, Clone)]
pub struct AuthUser {
    pub user_id: uuid::Uuid,
}

#[axum::async_trait]
impl FromRequestParts<AppState> for AuthUser {
    type Rejection = AppError;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &AppState,
    ) -> Result<Self, Self::Rejection> {
        let auth_header = parts
            .headers
            .get(header::AUTHORIZATION)
            .and_then(|value| value.to_str().ok())
            .ok_or_else(|| AppError::unauthorized("missing Authorization header"))?;

        let token = auth_header
            .strip_prefix("Bearer ")
            .ok_or_else(|| AppError::unauthorized("invalid Authorization header"))?;

        let app_state = state;

        let service = AuthService::new(
            app_state.db.clone(),
            app_state.paseto_access_key,
            app_state.paseto_refresh_key,
            app_state.access_ttl_minutes,
            app_state.refresh_ttl_days,
        );
        let session = service
            .authenticate_access_token(token)
            .await
            .map_err(|_| AppError::internal("failed to authenticate"))?;

        let session = session.ok_or_else(|| AppError::unauthorized("invalid token"))?;
        Ok(AuthUser {
            user_id: session.user_id,
        })
    }
}
