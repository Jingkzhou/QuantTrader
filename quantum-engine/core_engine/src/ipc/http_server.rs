use axum::{
    extract::State,
    routing::{get, post},
    Json, Router,
};
use crate::data_models::{MarketData, AccountStatus, LogEntry};
use std::net::SocketAddr;
use std::sync::{Arc, RwLock};
use serde::{Serialize, Deserialize};
use tower_http::cors::{Any, CorsLayer};

#[derive(Debug, Serialize, Deserialize, Clone, Default)]
pub struct AppState {
    pub market_data: MarketData,
    pub account_status: AccountStatus,
    pub recent_logs: Vec<LogEntry>,
}

pub type SharedState = Arc<RwLock<AppState>>;

pub async fn start_server() {
    let state = SharedState::default();

    // Add CORS for development (allowing localhost access from browser)
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    let app = Router::new()
        .route("/api/v1/state", get(get_state))
        .route("/api/v1/market", post(handle_market_data))
        .route("/api/v1/account", post(handle_account_status))
        .route("/api/v1/logs", post(handle_logs))
        .layer(cors)
        .with_state(state);

    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    tracing::info!("Starting HTTP server on {}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

async fn get_state(State(state): State<SharedState>) -> Json<AppState> {
    let s = state.read().unwrap();
    Json(s.clone())
}

async fn handle_market_data(State(state): State<SharedState>, Json(payload): Json<MarketData>) {
    tracing::info!("Market Data: {} Bid:{} Ask:{}", payload.symbol, payload.bid, payload.ask);
    let mut s = state.write().unwrap();
    s.market_data = payload;
}

async fn handle_account_status(State(state): State<SharedState>, Json(payload): Json<AccountStatus>) {
    tracing::info!("Account Status: Equity:{} Floating:{}", payload.equity, payload.floating_profit);
    let mut s = state.write().unwrap();
    s.account_status = payload;
}

async fn handle_logs(State(state): State<SharedState>, Json(payload): Json<LogEntry>) {
    tracing::info!("Log [{}]: {}", payload.level, payload.message);
    let mut s = state.write().unwrap();
    s.recent_logs.insert(0, payload);
    if s.recent_logs.len() > 50 {
        s.recent_logs.truncate(50);
    }
}
