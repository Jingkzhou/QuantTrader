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
use sqlx::PgPool;

#[derive(Debug, Serialize, Deserialize, Clone, Default)]
pub struct AppState {
    pub market_data: MarketData,
    pub account_status: AccountStatus,
    pub recent_logs: Vec<LogEntry>,
}

pub struct CombinedState {
    pub memory: Arc<RwLock<AppState>>,
    pub db: PgPool,
}

pub async fn start_server(db_pool: PgPool) {
    let memory_state = Arc::new(RwLock::new(AppState::default()));
    let shared_state = Arc::new(CombinedState {
        memory: memory_state,
        db: db_pool,
    });

    // Add CORS for development
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
        .with_state(shared_state);

    let addr = SocketAddr::from(([127, 0, 0, 1], 3001)); // Changed to 3001
    tracing::info!("Starting HTTP server on {}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

async fn get_state(State(state): State<Arc<CombinedState>>) -> Json<AppState> {
    let s = state.memory.read().unwrap();
    Json(s.clone())
}

async fn handle_market_data(State(state): State<Arc<CombinedState>>, Json(payload): Json<MarketData>) {
    tracing::info!("Market Data: {} Bid:{} Ask:{}", payload.symbol, payload.bid, payload.ask);
    
    // Update Memory
    {
        let mut s = state.memory.write().unwrap();
        s.market_data = payload.clone();
    }

    // Persist to DB
    let res = sqlx::query(
        "INSERT INTO market_data (symbol, timestamp, open, high, low, close, bid, ask) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)"
    )
    .bind(&payload.symbol)
    .bind(payload.timestamp as i64)
    .bind(payload.open)
    .bind(payload.high)
    .bind(payload.low)
    .bind(payload.close)
    .bind(payload.bid)
    .bind(payload.ask)
    .execute(&state.db)
    .await;

    if let Err(e) = res {
        tracing::error!("DB Error (market): {}", e);
    }
}

async fn handle_account_status(State(state): State<Arc<CombinedState>>, Json(payload): Json<AccountStatus>) {
    tracing::info!("Account Status Update: Equity:{}", payload.equity);
    
    // Update Memory
    {
        let mut s = state.memory.write().unwrap();
        s.account_status = payload.clone();
    }

    // Persist to DB
    let res = sqlx::query(
        "INSERT INTO account_status (balance, equity, margin, free_margin, floating_profit, timestamp) VALUES ($1, $2, $3, $4, $5, $6)"
    )
    .bind(payload.balance)
    .bind(payload.equity)
    .bind(payload.margin)
    .bind(payload.free_margin)
    .bind(payload.floating_profit)
    .bind(chrono::Utc::now().timestamp())
    .execute(&state.db)
    .await;

    if let Err(e) = res {
        tracing::error!("DB Error (account): {}", e);
    }
}

async fn handle_logs(State(state): State<Arc<CombinedState>>, Json(payload): Json<LogEntry>) {
    tracing::info!("Log [{}]: {}", payload.level, payload.message);
    
    // Update Memory
    {
        let mut s = state.memory.write().unwrap();
        s.recent_logs.insert(0, payload);
        if s.recent_logs.len() > 50 {
            s.recent_logs.truncate(50);
        }
    }
}
