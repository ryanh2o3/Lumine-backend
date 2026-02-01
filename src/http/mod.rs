use axum::Router;

use crate::AppState;

mod auth;
mod error;
mod handlers;
mod routes;

pub use error::AppError;
pub use auth::AuthUser;

pub fn router(state: AppState) -> Router {
    Router::new()
        .merge(routes::health())
        .merge(routes::auth())
        .merge(routes::users())
        .merge(routes::posts())
        .merge(routes::feed())
        .merge(routes::media())
        .merge(routes::notifications())
        .merge(routes::moderation())
        .merge(routes::search())
        .with_state(state)
}

