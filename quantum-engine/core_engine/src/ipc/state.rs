use std::collections::HashMap;
use std::sync::{Arc, RwLock};
use serde::{Serialize, Deserialize};
use sqlx::PgPool;
use jsonwebtoken::{decode, DecodingKey, Validation};
use axum::extract::FromRef;
use crate::data_models::{MarketData, AccountStatus, LogEntry, Command, RiskControlState, SmartExitMetrics};

#[derive(Debug, Serialize, Deserialize, Clone, Default)]
pub struct AppState {
    pub market_data: HashMap<String, MarketData>,
    pub account_status: AccountStatus,
    pub recent_logs: Vec<LogEntry>,
    pub active_symbols: Vec<String>,
}

#[derive(Debug, Clone, Default)]
pub struct CachedSymbolMetric {
    pub atr_d1: f64,
    pub velocity_m1: f64,
    pub rvol: f64,
    pub last_update: i64,
}

#[derive(Debug, Clone, Default)]
pub struct InternalState {
    pub market_data: HashMap<String, MarketData>,
    pub account_statuses: HashMap<String, AccountStatus>, // Key: "mt4_account:broker"
    pub recent_logs: HashMap<String, Vec<LogEntry>>,     // Key: "mt4_account:broker"
    pub pending_commands: HashMap<String, Vec<Command>>, // Key: "mt4_account:broker"
    pub risk_controls: HashMap<i64, RiskControlState>,   // Key: mt4_account
    pub risk_details: HashMap<i64, SmartExitMetrics>,    // Key: mt4_account
    pub symbol_metrics: HashMap<String, CachedSymbolMetric>, // Key: symbol (e.g. "XAUUSD")
    pub active_symbols: Vec<String>,
}

pub struct CombinedState {
    pub db: PgPool,
    pub memory: Arc<RwLock<InternalState>>,
    pub jwt_secret: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Claims {
    pub sub: String, // username
    pub user_id: i32,
    pub role: String,
    pub exp: usize,
}

#[axum::async_trait]
impl<S> axum::extract::FromRequestParts<S> for Claims
where
    Arc<CombinedState>: axum::extract::FromRef<S>,
    S: Send + Sync,
{
    type Rejection = (axum::http::StatusCode, String);

    async fn from_request_parts(parts: &mut axum::http::request::Parts, state: &S) -> Result<Self, Self::Rejection> {
        let auth_header = parts.headers.get(axum::http::header::AUTHORIZATION)
            .and_then(|h| h.to_str().ok())
            .ok_or((axum::http::StatusCode::UNAUTHORIZED, "Missing authorization header".to_string()))?;

        if !auth_header.starts_with("Bearer ") {
            return Err((axum::http::StatusCode::UNAUTHORIZED, "Invalid authorization header".to_string()));
        }

        let token = &auth_header[7..];
        let shared_state = Arc::<CombinedState>::from_ref(state);

        let token_data = decode::<Claims>(
            token,
            &DecodingKey::from_secret(shared_state.jwt_secret.as_ref()),
            &Validation::default(),
        )
        .map_err(|e| (axum::http::StatusCode::UNAUTHORIZED, format!("Invalid token: {}", e)))?;

        Ok(token_data.claims)
    }
}
