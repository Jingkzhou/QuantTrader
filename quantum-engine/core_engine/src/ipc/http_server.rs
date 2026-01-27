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
use tower_http::trace::TraceLayer;
use sqlx::PgPool;

use std::collections::HashMap;

#[derive(Debug, Serialize, Deserialize, Clone, Default)]
pub struct AppState {
    pub market_data: HashMap<String, MarketData>,
    pub account_status: AccountStatus,
    pub positions_map: HashMap<String, Vec<crate::data_models::Position>>,
    pub recent_logs: Vec<LogEntry>,
    pub pending_commands: Vec<Command>,
    pub active_symbols: Vec<String>,
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
        .route("/api/v1/account/history", get(get_account_history))
        .route("/api/v1/logs", post(handle_logs))
        .route("/api/v1/history", post(handle_trade_history))
        .route("/api/v1/candles", get(get_candles))
        .route("/api/v1/trades", get(get_trade_history))
        .route("/api/v1/command", post(handle_command))
        .route("/api/v1/commands", get(get_commands))
        .layer(cors)
        .layer(TraceLayer::new_for_http())
        .with_state(shared_state);

    let addr = SocketAddr::from(([0, 0, 0, 0], 3001)); // Changed to 0.0.0.0 to allow external connections
    tracing::info!("Starting HTTP server on {}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

async fn get_state(State(state): State<Arc<CombinedState>>) -> Json<AppState> {
    let s = state.memory.read().unwrap();
    tracing::debug!("Get State: Active Symbols: {:?}", s.active_symbols);
    Json(s.clone())
}

async fn handle_market_data(State(state): State<Arc<CombinedState>>, Json(payload): Json<MarketData>) {
    tracing::info!("Market Data: {} Bid:{} Ask:{}", payload.symbol, payload.bid, payload.ask);
    
    // Update Memory
    {
        let mut s = state.memory.write().unwrap();
        s.market_data.insert(payload.symbol.clone(), payload.clone());
        if !s.active_symbols.contains(&payload.symbol) {
            s.active_symbols.push(payload.symbol.clone());
        }
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
        
        // Update global account status info
        s.account_status.balance = payload.balance;
        s.account_status.equity = payload.equity;
        s.account_status.margin = payload.margin;
        s.account_status.free_margin = payload.free_margin;
        s.account_status.floating_profit = payload.floating_profit;
        s.account_status.timestamp = payload.timestamp;

        // Update positions for this symbol specifically
        // Assume all positions in this payload are for the same symbol (MQL4 reports per chart)
        if let Some(first_pos) = payload.positions.first() {
            let sym = first_pos.symbol.clone();
            s.positions_map.insert(sym, payload.positions.clone());
        } else {
             // If payload is empty, we don't know which symbol it's for, 
             // but EA usually sends an empty list for the symbol it's running on.
             // This is a limitation of the current endpoint. 
             // Ideally the payload should include the reporting symbol.
        }

        // Re-merge all positions for the global view
        let all_positions: Vec<_> = s.positions_map.values().flatten().cloned().collect();
        s.account_status.positions = all_positions;

        // Debug: Log if positions have open_price
        if let Some(pos) = payload.positions.first() {
             tracing::debug!("Position Ticket: {} OpenPrice: {}", pos.ticket, pos.open_price);
        }
    }

    // Persist to DB
    let positions_json = serde_json::to_string(&payload.positions).unwrap_or_default();
    
    let timestamp = if payload.timestamp > 0 { payload.timestamp } else { chrono::Utc::now().timestamp() };

    let res = sqlx::query(
        "INSERT INTO account_status (balance, equity, margin, free_margin, floating_profit, timestamp, positions_snapshot) VALUES ($1, $2, $3, $4, $5, $6, $7)"
    )
    .bind(payload.balance)
    .bind(payload.equity)
    .bind(payload.margin)
    .bind(payload.free_margin)
    .bind(payload.floating_profit)
    .bind(timestamp as i64)
    .bind(positions_json)
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



use crate::data_models::{TradeHistory, AccountHistory};

async fn get_account_history(
    State(state): State<Arc<CombinedState>>,
    axum::extract::Query(params): axum::extract::Query<std::collections::HashMap<String, String>>,
) -> Json<Vec<AccountHistory>> {
    let limit = params.get("limit").and_then(|s| s.parse::<i64>().ok()).unwrap_or(200);

    // Downsample strategy: 
    // If we have too many points, we might want to aggregate. 
    // For now, simple LIMIT query sorted by time.
    
    let history = sqlx::query_as::<_, AccountHistory>(
        "SELECT timestamp, balance, equity FROM account_status ORDER BY timestamp DESC LIMIT $1"
    )
    .bind(limit)
    .fetch_all(&state.db)
    .await
    .unwrap_or_default();

    let mut asc_history = history;
    asc_history.reverse();

    Json(asc_history)
}

async fn handle_trade_history(State(state): State<Arc<CombinedState>>, Json(payload): Json<Vec<TradeHistory>>) {
    tracing::info!("Received {} trade history records", payload.len());

    for trade in payload {
        let res = sqlx::query(
            "INSERT INTO trade_history (ticket, symbol, open_time, close_time, open_price, close_price, lots, profit, trade_type, magic) 
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
             ON CONFLICT (ticket) DO NOTHING"
        )
        .bind(trade.ticket)
        .bind(&trade.symbol)
        .bind(trade.open_time as i64)
        .bind(trade.close_time as i64)
        .bind(trade.open_price)
        .bind(trade.close_price)
        .bind(trade.lots)
        .bind(trade.profit)
        .bind(&trade.trade_type)
        .bind(trade.magic)
        .execute(&state.db)
        .await;

        if let Err(e) = res {
            tracing::error!("DB Error (history): {}", e);
        }
    }
}

async fn get_trade_history(State(state): State<Arc<CombinedState>>) -> Json<Vec<TradeHistory>> {
    let trades = sqlx::query_as::<_, TradeHistory>("SELECT * FROM trade_history ORDER BY close_time DESC LIMIT 50")
        .fetch_all(&state.db)
        .await
        .unwrap_or_default();
    
    Json(trades)
}

use crate::data_models::{Candle, Command};

async fn get_candles(
    State(state): State<Arc<CombinedState>>,
    axum::extract::Query(params): axum::extract::Query<std::collections::HashMap<String, String>>,
) -> Json<Vec<Candle>> {
    let timeframe = params.get("timeframe").map(|s| s.as_str()).unwrap_or("M1");
    let symbol = params.get("symbol").unwrap_or(&"".to_string()).clone();

    // Mapping timeframe to SQL interval bucket
    let bucket_interval = match timeframe {
        "M1" => 60,
        "M5" => 300,
        "M15" => 900,
        "M30" => 1800,
        "H1" => 3600,
        "H4" => 14400,
        "D1" => 86400,
        "W1" => 604800,
        "MN" => 2592000, 
        _ => 60,
    };

    let limit = 1000;

    let query = format!(
        "SELECT 
            (timestamp / {0}) * {0} as time,
            (array_agg(bid ORDER BY timestamp ASC))[1] as open,
            MAX(bid) as high,
            MIN(bid) as low,
            (array_agg(bid ORDER BY timestamp DESC))[1] as close
         FROM market_data 
         WHERE symbol = $1
         GROUP BY 1
         ORDER BY 1 DESC
         LIMIT {1}",
        bucket_interval, limit
    );

    let candles = sqlx::query_as::<_, Candle>(&query)
        .bind(symbol)
        .fetch_all(&state.db)
        .await
        .unwrap_or_default();
    
    let mut asc_candles = candles;
    asc_candles.reverse();
    
    Json(asc_candles)
}
    
// --- Command Handling ---

async fn handle_command(State(state): State<Arc<CombinedState>>, Json(payload): Json<Command>) {
    tracing::info!("Received Command: {:?} on {}", payload.action, payload.symbol);
    
    // Add to pending queue (in-memory simple queue)
    {
        let mut s = state.memory.write().unwrap();
        // Since we don't have pending_commands in AppState struct yet, need to add it there first. 
        // But wait, replace_file_content replaces block. I need a MultiReplace to update struct definition AND handlers.
        // For now, assume struct is updated or use a separate DB table.
        // Actually, simple in-memory queue attached to AppState is best.
        s.pending_commands.push(payload);
    }
}

async fn get_commands(State(state): State<Arc<CombinedState>>) -> Json<Vec<Command>> {
    let mut s = state.memory.write().unwrap();
    let commands = s.pending_commands.clone();
    s.pending_commands.clear(); // Consume commands once fetched (simple polling)
    Json(commands)
}
