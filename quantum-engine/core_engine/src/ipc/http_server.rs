use axum::{
    routing::{get, post},
    Router,
};
use std::net::SocketAddr;
use std::sync::{Arc, RwLock};
use tower_http::cors::{Any, CorsLayer};
use tower_http::trace::TraceLayer;
use sqlx::PgPool;

use crate::ipc::state::{InternalState, CombinedState};
use crate::ipc::handlers;

pub async fn start_server(db_pool: PgPool) {
    let memory_state = Arc::new(RwLock::new(InternalState::default()));
    
    // Load existing symbols from database on startup
    let startup_db = db_pool.clone();
    let startup_memory = memory_state.clone();
    tokio::spawn(async move {
        let rows = sqlx::query!("SELECT DISTINCT symbol FROM market_data")
            .fetch_all(&startup_db)
            .await;
        
        match rows {
            Ok(symbols) => {
                let mut s = startup_memory.write().unwrap();
                for row in symbols {
                    if !s.active_symbols.contains(&row.symbol) {
                        s.active_symbols.push(row.symbol);
                    }
                }
                tracing::info!("Loaded {} symbols from database on startup", s.active_symbols.len());
            }
            Err(e) => {
                tracing::error!("Failed to load symbols on startup: {}", e);
            }
        }
    });
    
    // Load existing risk controls from database on startup
    let startup_db_risk = db_pool.clone();
    let startup_memory_risk = memory_state.clone();
    tokio::spawn(async move {
        // Use unchecked query because table might be created in this same run
        let rows = sqlx::query_as::<_, crate::data_models::RiskControlState>(
            "SELECT mt4_account, block_buy, block_sell, block_all, risk_level, updated_at, risk_score, exit_trigger, velocity_block, enabled, fingerprint_enabled FROM risk_controls"
        )
        .fetch_all(&startup_db_risk)
        .await;

        match rows {
            Ok(controls) => {
                let mut s = startup_memory_risk.write().unwrap();
                for c in controls {
                    s.risk_controls.insert(c.mt4_account, c);
                }
                tracing::info!("Loaded {} risk control states from database", s.risk_controls.len());
            }
            Err(e) => {
                tracing::error!("Failed to load risk controls: {}", e);
            }
        }
    });

    let shared_state = Arc::new(CombinedState {
        memory: memory_state,
        db: db_pool,
        jwt_secret: std::env::var("JWT_SECRET").unwrap_or_else(|_| "quantum_secret_key_2026".to_string()),
    });

    // Add CORS for development
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    let app = Router::new()
        .route("/api/v1/state", get(handlers::monitor::get_state))
        .route("/api/v1/market", post(handlers::market::handle_market_data))
        .route("/api/v1/market/batch", post(handlers::market::handle_market_data_batch))
        .route("/api/v1/account", post(handlers::account::handle_account_status))
        .route("/api/v1/account/history", get(handlers::history::get_account_history))
        .route("/api/v1/logs", post(handlers::monitor::handle_logs))
        .route("/api/v1/history", post(handlers::history::handle_trade_history))
        .route("/api/v1/candles", get(handlers::candles::get_candles))
        .route("/api/v1/trade_history", get(handlers::history::get_trade_history).delete(handlers::history::clear_trade_history))
        .route("/api/v1/command", post(handlers::commands::handle_command))
        .route("/api/v1/commands", get(handlers::commands::get_commands))
        .route("/api/v1/auth/login", post(handlers::auth::handle_login))
        .route("/api/v1/auth/register", post(handlers::auth::handle_register))
        .route("/api/v1/accounts", get(handlers::account::list_accounts).delete(handlers::account::unbind_account))
        .route("/api/v1/accounts/bind", post(handlers::account::bind_account))
        .route("/api/v1/risk_control", get(handlers::risk_control::get_risk_control).put(handlers::risk_control::update_risk_control))
        .route("/api/v1/risk_control_logs", get(handlers::risk_control::get_risk_control_logs))
        .route("/api/v1/ea_sync", get(handlers::ea_sync::handle_ea_sync))
        .route("/api/v1/velocity", get(handlers::ea_sync::get_velocity))
        .layer(cors)
        .layer(TraceLayer::new_for_http())
        .with_state(shared_state);

    let addr = SocketAddr::from(([0, 0, 0, 0], 3001)); // Changed to 0.0.0.0 to allow external connections
    tracing::info!("Starting HTTP server on {}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
