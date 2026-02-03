use axum::{
    extract::{State, FromRef},
    routing::{get, post},
    Json, Router,
};
use axum::response::IntoResponse;
use crate::data_models::{MarketData, AccountStatus, LogEntry, Command, Candle, TradeHistory, AccountHistory, RiskControlState, VelocityData, SmartExitMetrics};
use std::net::SocketAddr;
use std::sync::{Arc, RwLock};
use serde::{Serialize, Deserialize};
use tower_http::cors::{Any, CorsLayer};
use tower_http::trace::TraceLayer;
use sqlx::PgPool;

use std::collections::HashMap;
use jsonwebtoken::{encode, decode, Header, Validation, EncodingKey, DecodingKey};
use bcrypt::{hash, verify, DEFAULT_COST};
use chrono::Datelike;

#[derive(Debug, Serialize, Deserialize, Clone, Default)]
pub struct AppState {
    pub market_data: HashMap<String, MarketData>,
    pub account_status: AccountStatus,
    pub recent_logs: Vec<LogEntry>,
    pub active_symbols: Vec<String>,
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

#[derive(Debug, Clone, Default)]
pub struct CachedSymbolMetric {
    pub atr_d1: f64,
    pub velocity_m1: f64,
    pub rvol: f64,
    pub last_update: i64,
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

#[derive(Debug, Deserialize)]
pub struct LoginRequest {
    pub username: String,
    pub password: String,
}

#[derive(Debug, Serialize)]
pub struct LoginResponse {
    pub token: String,
    pub username: String,
    pub role: String,
}

// This AppState is for the API response, not the internal mutable state
// #[derive(Debug, Serialize, Deserialize, Clone, Default)]
// pub struct AppState {
//     pub market_data: HashMap<String, MarketData>,
//     pub account_statuses: HashMap<i32, AccountStatus>,
//     pub recent_logs: HashMap<i32, Vec<LogEntry>>,
//     pub pending_commands: HashMap<i32, Vec<Command>>,
//     pub active_symbols: Vec<String>,
// }

pub struct CombinedState {
    pub db: sqlx::PgPool,
    pub memory: Arc<RwLock<InternalState>>,
    pub jwt_secret: String,
}

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
            "SELECT mt4_account, block_buy, block_sell, block_all, risk_level, updated_at, risk_score, exit_trigger, velocity_block, enabled FROM risk_controls"
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
        .route("/api/v1/state", get(get_state))
        .route("/api/v1/market", post(handle_market_data))
        .route("/api/v1/market/batch", post(handle_market_data_batch))
        .route("/api/v1/account", post(handle_account_status))
        .route("/api/v1/account/history", get(get_account_history))
        .route("/api/v1/logs", post(handle_logs))
        .route("/api/v1/history", post(handle_trade_history))
        .route("/api/v1/candles", get(get_candles))
        .route("/api/v1/trade_history", get(get_trade_history))
        .route("/api/v1/command", post(handle_command))
        .route("/api/v1/commands", get(get_commands))
        .route("/api/v1/auth/login", post(handle_login))
        .route("/api/v1/auth/register", post(handle_register))
        .route("/api/v1/accounts", get(list_accounts))
        .route("/api/v1/accounts/bind", post(bind_account))
        .route("/api/v1/risk_control", get(get_risk_control).put(update_risk_control))
        .route("/api/v1/risk_control_logs", get(get_risk_control_logs))
        .route("/api/v1/ea_sync", get(handle_ea_sync))
        .route("/api/v1/velocity", get(get_velocity))
        .layer(cors)
        .layer(TraceLayer::new_for_http())
        .with_state(shared_state);

    let addr = SocketAddr::from(([0, 0, 0, 0], 3001)); // Changed to 0.0.0.0 to allow external connections
    tracing::info!("Starting HTTP server on {}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}



async fn get_state(
    State(state): State<Arc<CombinedState>>,
    claims: Claims,
    axum::extract::Query(params): axum::extract::Query<HashMap<String, String>>,
) -> Result<Json<AppState>, (axum::http::StatusCode, String)> {
    let mt4_account = params.get("mt4_account").and_then(|id| id.parse::<i64>().ok());
    let _broker = params.get("broker").map(|s| s.clone());

    let mut app_state = AppState::default();
    
    // Fill global memory state (Market Data & Active Symbols)
    {
        let s = state.memory.read().unwrap();
        app_state.market_data = s.market_data.clone();
        app_state.active_symbols = s.active_symbols.clone();
    }

    // Use if let to handle optional account context
    if let Some(mt4) = mt4_account {
        // Verify ownership
        let _ = sqlx::query!(
            "SELECT 1 as \"exists!\" FROM user_accounts WHERE user_id = $1 AND mt4_account = $2",
            claims.user_id, mt4
        )
        .fetch_optional(&state.db)
        .await
        .map_err(|e| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        .ok_or((axum::http::StatusCode::FORBIDDEN, "Access denied".to_string()))?;

        // Fetch latest snapshot for this account
        // Fetch latest snapshot for this account
        let status_row = sqlx::query(
            "SELECT balance, equity, margin, free_margin, floating_profit, timestamp, mt4_account, broker, positions_snapshot,
             contract_size, tick_value, stop_level, margin_so_level
             FROM account_status WHERE mt4_account = $1 ORDER BY timestamp DESC LIMIT 1",
        )
        .bind(mt4)
        .fetch_optional(&state.db)
        .await
        .map_err(|e: sqlx::Error| {
            tracing::error!("Fetch account status error: {}", e);
            (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string())
        })?;
        
        // Fill from DB snapshot if exists
        if let Some(row) = status_row {
            use sqlx::Row;
            app_state.account_status.balance = row.try_get("balance").unwrap_or(0.0);
            app_state.account_status.equity = row.try_get("equity").unwrap_or(0.0);
            app_state.account_status.margin = row.try_get("margin").unwrap_or(0.0);
            app_state.account_status.free_margin = row.try_get("free_margin").unwrap_or(0.0);
            app_state.account_status.floating_profit = row.try_get("floating_profit").unwrap_or(0.0);
            app_state.account_status.timestamp = row.try_get("timestamp").unwrap_or(0);
            app_state.account_status.mt4_account = row.try_get("mt4_account").unwrap_or(0);
            app_state.account_status.broker = row.try_get("broker").unwrap_or_default();

            let ps_json: Option<String> = row.try_get("positions_snapshot").unwrap_or(None);
            if let Some(json_str) = ps_json {
                app_state.account_status.positions = serde_json::from_str(&json_str).unwrap_or_default();
            }
            
            // Risk Fields
            app_state.account_status.contract_size = row.try_get("contract_size").unwrap_or(100.0);
            app_state.account_status.tick_value = row.try_get("tick_value").unwrap_or(0.0);
            app_state.account_status.stop_level = row.try_get("stop_level").unwrap_or(0);
            app_state.account_status.margin_so_level = row.try_get("margin_so_level").unwrap_or(0.0);
        }

        // Overlay real-time memory state for this account
        {
            let s = state.memory.read().unwrap();
            
            // 1. Find account status
            for (key, status) in s.account_statuses.iter() {
                if key.starts_with(&format!("{}:", mt4)) {
                    app_state.account_status = status.clone();
                    break;
                }
            }

            // 2. Find logs
            for (key, log_list) in s.recent_logs.iter() {
                if key.starts_with(&format!("{}:", mt4)) {
                    app_state.recent_logs = log_list.clone();
                    break;
                }
            }
        }
    }

    Ok(Json(app_state))
}

async fn handle_market_data(State(state): State<Arc<CombinedState>>, Json(payload): Json<MarketData>) {
    process_market_data(&state, payload).await;
}

async fn handle_market_data_batch(State(state): State<Arc<CombinedState>>, Json(payload): Json<Vec<MarketData>>) {
    // tracing::info!("Received batch of {} market data points", payload.len());
    for data in payload {
        process_market_data(&state, data).await;
    }
}

async fn process_market_data(state: &Arc<CombinedState>, payload: MarketData) {
    // Filter Weekend Data (Professional Standard)
    let dt = chrono::DateTime::from_timestamp(payload.timestamp as i64, 0).unwrap_or_default();
    let weekday = dt.weekday();
    if weekday == chrono::Weekday::Sat || weekday == chrono::Weekday::Sun {
        // tracing::warn!("Skipping weekend data: {} on {:?}", payload.symbol, weekday);
        return;
    }

    // tracing::info!("Market Data: {} Bid:{} Ask:{}", payload.symbol, payload.bid, payload.ask);
    
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
        "INSERT INTO market_data (symbol, timestamp, open, high, low, close, bid, ask, mt4_account, broker) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)"
    )
    .bind(&payload.symbol)
    .bind(payload.timestamp as i64)
    .bind(payload.open)
    .bind(payload.high)
    .bind(payload.low)
    .bind(payload.close)
    .bind(payload.bid)
    .bind(payload.ask)
    .bind(0i64) // Default/Global account
    .bind("")   // Default/Global broker
    .execute(&state.db)
    .await;

    if let Err(e) = res {
        tracing::error!("DB Error (market): {}", e);
    }
}


async fn get_symbol_metrics(state: &Arc<CombinedState>, symbol: &str) -> (f64, f64, f64, f64) {
    let now = chrono::Utc::now().timestamp();
    
    // 1. Get/Calc ATR (Cached)
    let mut atr = 0.0;
    {
        let mem = state.memory.read().unwrap();
        if let Some(m) = mem.symbol_metrics.get(symbol) {
             // ATR D1 is slow moving, cache for 5 minutes (300s)
            if now - m.last_update < 300 {
                atr = m.atr_d1;
            }
        }
    }

    if atr == 0.0 {
        let start_ts = now - (30 * 86400); 
        let candles_query = sqlx::query_as!(
            Candle,
            "SELECT 
             COALESCE((timestamp / 86400) * 86400, 0) as \"time!\",
             (array_agg(bid ORDER BY timestamp ASC))[1] as \"open!\",
             MAX(bid) as \"high!\",
             MIN(bid) as \"low!\",
             (array_agg(bid ORDER BY timestamp DESC))[1] as \"close!\"
             FROM market_data 
             WHERE symbol = $1 AND timestamp > $2
             GROUP BY 1 
             ORDER BY 1 DESC 
             LIMIT 30",
             symbol,
             start_ts
        )
        .fetch_all(&state.db)
        .await;

        if let Ok(mut candles) = candles_query {
            candles.reverse();
            atr = crate::risk::calculator::calculate_atr(&candles, 14);
            
            // 🛡️ ATR Sanity Check: XAUUSD daily ATR typically 30-50, max ~80
            // Tick-aggregated candles often produce inflated ATR due to intraday extremes
            if symbol.contains("XAU") && atr > 80.0 {
                tracing::warn!("ATR capped: {} raw={:.2} -> 50.0 (tick aggregation bias)", symbol, atr);
                atr = 50.0; // Use conservative estimate
            }
            
            // Update Cache
            {
                let mut mem = state.memory.write().unwrap();
                let cached = mem.symbol_metrics.entry(symbol.to_string()).or_default();
                cached.atr_d1 = atr;
                cached.last_update = now;
                // velocity/rvol in cache are ignored/overwritten but structure exists
            }
        }
    }

    // 2. Calculate Velocity & RVOL (Real-time, No Cache)
    // Find Latest TS
    let max_ts_row = sqlx::query!(
        "SELECT MAX(timestamp) as max_ts FROM market_data WHERE symbol = $1",
        symbol
    )
    .fetch_optional(&state.db)
    .await
    .unwrap_or(None);

    let latest_ts = max_ts_row.and_then(|r| r.max_ts).unwrap_or(now);

    // Velocity M1
    let velocity_result = sqlx::query(
        "SELECT 
            (array_agg(bid ORDER BY timestamp DESC))[1] as current_price,
            (array_agg(bid ORDER BY timestamp ASC))[1] as old_price
         FROM market_data 
         WHERE symbol = $1 AND timestamp >= $2 AND timestamp <= $3"
    )
    .bind(symbol)
    .bind(latest_ts - 61)
    .bind(latest_ts)
    .fetch_optional(&state.db)
    .await;

    let velocity_m1 = if let Ok(Some(row)) = velocity_result {
        use sqlx::Row;
        let current: f64 = row.try_get("current_price").unwrap_or(0.0);
        let old: f64 = row.try_get("old_price").unwrap_or(0.0);
        if old > 0.0 { current - old } else { 0.0 }
    } else {
        0.0
    };

    // RVOL
    let rvol_result = sqlx::query(
        "WITH 
         current_period AS (
             SELECT COUNT(*) as tick_count FROM market_data 
             WHERE symbol = $1 AND timestamp >= $2 AND timestamp <= $3
         ),
         avg_period AS (
             SELECT COUNT(*) / 24.0 as avg_hourly_ticks FROM market_data 
             WHERE symbol = $1 AND timestamp >= $4 AND timestamp <= $3
         )
         SELECT 
            cp.tick_count,
            NULLIF(ap.avg_hourly_ticks, 0) as avg_ticks
         FROM current_period cp, avg_period ap"
    )
    .bind(symbol)
    .bind(latest_ts - 3600)
    .bind(latest_ts)
    .bind(latest_ts - 86400)
    .fetch_optional(&state.db)
    .await;

    let rvol = if let Ok(Some(row)) = rvol_result {
        use sqlx::Row;
        let current_ticks: i64 = row.try_get("tick_count").unwrap_or(0);
        let avg_ticks: Option<f64> = row.try_get("avg_ticks").ok();
        
        let c_ticks = current_ticks as f64;
        let a_ticks = avg_ticks.unwrap_or(0.0);
        
        if a_ticks > 0.0 { c_ticks / a_ticks } else { 1.0 }
    } else {
        1.0
    };

    // RSI Calculation (M1)
    let rsi_candles_query = sqlx::query_as!(
        Candle,
        "SELECT 
            (timestamp / 60) * 60 as \"time!\",
            (array_agg(bid ORDER BY timestamp ASC))[1] as \"open!\",
            MAX(bid) as \"high!\",
            MIN(bid) as \"low!\",
            (array_agg(bid ORDER BY timestamp DESC))[1] as \"close!\"
        FROM market_data
        WHERE symbol = $1 AND timestamp >= $2
        GROUP BY 1
        ORDER BY 1 DESC
        LIMIT 20",
        symbol,
        latest_ts - (25 * 60) // Fetch slightly more to ensure 15 candles
    )
    .fetch_all(&state.db)
    .await;

    let rsi = if let Ok(mut candles) = rsi_candles_query {
        candles.reverse();
        crate::risk::calculator::calculate_rsi(&candles, 14)
    } else {
        50.0
    };

    if atr == 0.0 || velocity_m1 == 0.0 {
        tracing::warn!("[Metrics] {} ATR={:.2} Vel={:.2} RVOL={:.2} RSI={:.2} (Time diff: {}s)", 
            symbol, atr, velocity_m1, rvol, rsi, now - latest_ts);
    }

    (atr, velocity_m1, rvol, rsi)
}

async fn handle_account_status(State(state): State<Arc<CombinedState>>, Json(payload): Json<AccountStatus>) {
    let symbols: Vec<String> = payload.positions.iter().map(|p| p.symbol.clone()).collect();
    tracing::info!("Account Status Update: Equity:{} Acc:{} Broker:{} Symbols:{:?}", payload.equity, payload.mt4_account, payload.broker, symbols);
    
    // Update Memory
    {
        let mut s = state.memory.write().unwrap();
        let key = format!("{}:{}", payload.mt4_account, payload.broker);
        let status = s.account_statuses.entry(key).or_insert_with(AccountStatus::default);
        
        status.balance = payload.balance;
        status.equity = payload.equity;
        status.margin = payload.margin;
        status.free_margin = payload.free_margin;
        status.floating_profit = payload.floating_profit;
        status.timestamp = payload.timestamp;
        status.positions = payload.positions.clone();
        status.mt4_account = payload.mt4_account;
        status.broker = payload.broker.clone();
        status.contract_size = payload.contract_size;
        status.tick_value = payload.tick_value;
        status.stop_level = payload.stop_level;
        status.margin_so_level = payload.margin_so_level;
    }

    let positions_json = serde_json::to_string(&payload.positions).unwrap_or_default();
    let timestamp = if payload.timestamp > 0 { payload.timestamp } else { chrono::Utc::now().timestamp() };

    // Filter Weekend Data (Professional Standard)
    let dt = chrono::DateTime::from_timestamp(timestamp as i64, 0).unwrap_or_default();
    let weekday = dt.weekday();
    if weekday == chrono::Weekday::Sat || weekday == chrono::Weekday::Sun {
        // tracing::warn!("Skipping weekend account status persistence for account: {}", payload.mt4_account);
        return;
    }

    let res = sqlx::query(
        "INSERT INTO account_status (balance, equity, margin, free_margin, floating_profit, timestamp, positions_snapshot, mt4_account, broker, contract_size, tick_value, stop_level, margin_so_level) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)"
    )
    .bind(payload.balance)
    .bind(payload.equity)
    .bind(payload.margin)
    .bind(payload.free_margin)
    .bind(payload.floating_profit)
    .bind(timestamp as i64)
    .bind(positions_json)
    .bind(payload.mt4_account)
    .bind(&payload.broker)
    .bind(payload.contract_size)
    .bind(payload.tick_value)
    .bind(payload.stop_level)
    .bind(payload.margin_so_level)
    .execute(&state.db)
    .await;

    if let Err(e) = res {
        tracing::error!("DB Error (account): {}", e);
    }

    // ======== 🆕 Auto Risk Calculation (Backend Enforced V2) ========
    // 1. Calculate Real-time Drawdown
    let drawdown = if payload.balance > 0.0 {
        ((payload.balance - payload.equity) / payload.balance) * 100.0
    } else { 0.0 };

    // 2. Identify Main Symbol
    let main_symbol = payload.positions.first().map(|p| p.symbol.as_str()).unwrap_or("XAUUSD");

    // 3. Get Market Metrics (Async)
    let (atr, velocity, rvol, rsi) = get_symbol_metrics(&state, main_symbol).await;

    // 4. Calculate Net Lots
    let buy_lots: f64 = payload.positions.iter().filter(|p| p.side == "BUY").map(|p| p.lots).sum();
    let sell_lots: f64 = payload.positions.iter().filter(|p| p.side == "SELL").map(|p| p.lots).sum();
    let net_lots = buy_lots - sell_lots;

    // 5. Calculate Survival Distance
    let survival_distance = crate::risk::calculator::calculate_survival_distance(
        payload.equity, payload.margin, payload.margin_so_level, net_lots, payload.contract_size
    );

    // Debug: Log ATR and ratio for distance score investigation
    if atr > 0.0 {
        let ratio = survival_distance / atr;
        tracing::info!("ATR Debug: symbol={} atr={:.2} survival={:.2} ratio={:.2}", main_symbol, atr, survival_distance, ratio);
    } else {
        tracing::warn!("ATR is 0 for symbol {}", main_symbol);
    }

    // 6. Integrated Risk Score
    let mut metrics = crate::risk::calculator::calculate_integrated_risk_score(
        survival_distance, atr, velocity, rvol, &payload.positions, drawdown
    );
    
    // 6.b Populate RSI (Entry Fingerprint)
    metrics.rsi_14 = rsi;
    metrics.rsi_signal = if rsi >= 70.0 { "SELL".to_string() }
                         else if rsi <= 30.0 { "BUY".to_string() }
                         else { "NEUTRAL".to_string() };
    
    // 6.5 Calculate Liquidation Price V2
    let (current_bid, current_ask) = {
        let mem = state.memory.read().unwrap();
        mem.market_data.get(main_symbol)
            .map(|m| (m.bid, m.ask))
            .unwrap_or((0.0, 0.0))
    };

    let liq_v2 = crate::risk::calculator::calculate_liquidation_price_v2(
        payload.equity,
        payload.margin,
        payload.margin_so_level,
        buy_lots,
        sell_lots,
        payload.contract_size,
        current_bid,
        current_ask
    );
    metrics.liquidation_price = liq_v2.effective_liquidation_price;
    
    // 7. Extract Values for Control
    let risk_score = metrics.risk_score;
    let exit_trigger = metrics.exit_trigger.clone();
    let risk_level_str = if risk_score >= 80.0 { "CRITICAL" } 
        else if risk_score >= 60.0 { "WARNING" } 
        else { "SAFE" };
    
    tracing::info!("Account {} Metrics: Score={:.1} Dist={:.1} VelM1={:.2} RVOL={:.2} Liq={:.2}", 
        payload.mt4_account, risk_score, metrics.survival_distance, metrics.velocity_m1, metrics.rvol, metrics.liquidation_price);

    // 8. Determine Block Directives
    let (mut block_buy, mut block_sell, mut block_all) = match exit_trigger.as_str() {
        "FORCE_EXIT" | "TACTICAL_EXIT" => (true, true, true),
        "LAYER_LOCK" => (true, true, false), 
        _ => (false, false, false),
    };
    
    // RSI Entry Fingerprint Control
    if rsi >= 70.0 {
        block_buy = true; // Forbid Buy (Overbought)
    } else if rsi <= 30.0 {
        block_sell = true; // Forbid Sell (Oversold)
    }
    
    tracing::info!("Account {} Metrics: Score={:.1} Dist={:.1} VelM1={:.2} RVOL={:.2} Liq={:.2}", 
        payload.mt4_account, risk_score, metrics.survival_distance, metrics.velocity_m1, metrics.rvol, metrics.liquidation_price);

    // 9. Update Risk Details Cache
    {
        let mut mem = state.memory.write().unwrap();
        mem.risk_details.insert(payload.mt4_account, metrics);
    }
    
    // 4. Auto-Update Risk Controls (UPSERT to ensure record exists)
    // We always update score and levels, but only override directives if enabled=true
    let now_ts = chrono::Utc::now().timestamp();
    
    // Use UPSERT to handle both new and existing records
    let update_res = sqlx::query(
        "INSERT INTO risk_controls (mt4_account, block_buy, block_sell, block_all, risk_score, exit_trigger, risk_level, updated_at, velocity_block, enabled)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, false, false)
         ON CONFLICT (mt4_account) DO UPDATE SET 
            block_buy = CASE WHEN risk_controls.enabled = true THEN $2 ELSE risk_controls.block_buy END, 
            block_sell = CASE WHEN risk_controls.enabled = true THEN $3 ELSE risk_controls.block_sell END,
            block_all = CASE WHEN risk_controls.enabled = true THEN $4 ELSE risk_controls.block_all END,
            exit_trigger = CASE WHEN risk_controls.enabled = true THEN $6 ELSE risk_controls.exit_trigger END,
            risk_score = $5, 
            risk_level = $7, 
            updated_at = $8"
    )
    .bind(payload.mt4_account)
    .bind(block_buy)
    .bind(block_sell)
    .bind(block_all)
    .bind(risk_score)
    .bind(&exit_trigger)
    .bind(risk_level_str)
    .bind(now_ts)
    .execute(&state.db)
    .await;



    if let Err(e) = update_res {
        tracing::error!("Failed to auto-update risk controls: {}", e);
    }
    
    // 🔴 CRITICAL: Also update memory state and detect changes for logging
    let log_event = {
        let mut s = state.memory.write().unwrap();
        let existing = s.risk_controls.get(&payload.mt4_account).cloned();
        
        let was_enabled = existing.as_ref().map(|e| e.enabled).unwrap_or(false);
        let old_trigger = existing.as_ref().map(|e| e.exit_trigger.clone()).unwrap_or_else(|| "NONE".to_string());
        
        // Calculate effective values considering 'enabled' flag
        let new_trigger = if was_enabled { exit_trigger.clone() } else { old_trigger.clone() };
        let new_block_buy = if was_enabled { block_buy } else { existing.as_ref().map(|e| e.block_buy).unwrap_or(false) };
        let new_block_sell = if was_enabled { block_sell } else { existing.as_ref().map(|e| e.block_sell).unwrap_or(false) };
        let new_block_all = if was_enabled { block_all } else { existing.as_ref().map(|e| e.block_all).unwrap_or(false) };

        // Logic: Log if trigger changed (Only if enabled)
        let mut event = None;
        if was_enabled {
            let old_block_buy = existing.as_ref().map(|e| e.block_buy).unwrap_or(false);
            let old_block_sell = existing.as_ref().map(|e| e.block_sell).unwrap_or(false);

            if new_trigger != old_trigger {
                if new_trigger != "NONE" {
                   let t_cn = match new_trigger.as_str() {
                       "FORCE_EXIT" => "紧急逃生",
                       "TACTICAL_EXIT" => "战术减仓",
                       "LAYER_LOCK" => "层级锁",
                       _ => new_trigger.as_str(),
                   };
                   event = Some(format!("自动: 触发 {}", t_cn));
                } else {
                   event = Some("自动: 风险解除".to_string());
                }
            } else if new_block_buy != old_block_buy {
                event = Some(format!("风控: {}买入", if new_block_buy { "禁止" } else { "恢复" }));
            } else if new_block_sell != old_block_sell {
                event = Some(format!("风控: {}卖出", if new_block_sell { "禁止" } else { "恢复" }));
            }
        }

        let risk_state = RiskControlState {
            mt4_account: payload.mt4_account,
            block_buy: new_block_buy,
            block_sell: new_block_sell,
            block_all: new_block_all,
            risk_level: risk_level_str.to_string(),
            updated_at: now_ts,
            risk_score,
            exit_trigger: new_trigger,
            velocity_block: existing.as_ref().map(|e| e.velocity_block).unwrap_or(false),
            enabled: was_enabled,
        };
        s.risk_controls.insert(payload.mt4_account, risk_state);
        event
    };

    // Write log if event occurred (Outside of lock)
    if let Some(action_msg) = log_event {
         let _ = sqlx::query("INSERT INTO risk_control_logs (mt4_account, action, risk_level, risk_score, exit_trigger, created_at) VALUES ($1, $2, $3, $4, $5, $6)")
            .bind(payload.mt4_account)
            .bind(action_msg)
            .bind(risk_level_str)
            .bind(risk_score)
            .bind(&exit_trigger) 
            .bind(now_ts)
            .execute(&state.db)
            .await;
    }
    


    let margin_level = if payload.margin > 0.0 {
        payload.margin_level
    } else {
        0.0
    };
    
    if risk_score >= 60.0 {
        tracing::warn!("⚠️ Auto Risk Alert: Account {} Score={:.1} DD={:.1}% ML={:.0}% Trigger={}", 
            payload.mt4_account, risk_score, drawdown, margin_level, exit_trigger);
    }
}

async fn handle_logs(State(state): State<Arc<CombinedState>>, Json(payload): Json<LogEntry>) {
    tracing::info!("Log [{}]: {}", payload.level, payload.message);
    
    let key = format!("{}:{}", payload.mt4_account, payload.broker);
    let mut s = state.memory.write().unwrap();
    let logs = s.recent_logs.entry(key).or_insert_with(Vec::new);
    logs.insert(0, payload);
    if logs.len() > 100 {
        logs.truncate(100);
    }
}




async fn get_account_history(
    State(state): State<Arc<CombinedState>>,
    claims: Claims,
    axum::extract::Query(params): axum::extract::Query<std::collections::HashMap<String, String>>,
) -> Result<Json<Vec<AccountHistory>>, (axum::http::StatusCode, String)> {
    let mt4_account = params.get("mt4_account").and_then(|id| id.parse::<i64>().ok())
        .ok_or((axum::http::StatusCode::BAD_REQUEST, "Missing mt4_account".to_string()))?;
    // Verify ownership
    let _ = sqlx::query!(
        "SELECT 1 as \"exists!\" FROM user_accounts WHERE user_id = $1 AND mt4_account = $2",
        claims.user_id, mt4_account
    )
    .fetch_optional(&state.db)
    .await
    .map_err(|e| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
    .ok_or((axum::http::StatusCode::FORBIDDEN, "Access denied".to_string()))?;

    let limit = params.get("limit").and_then(|s| s.parse::<i64>().ok()).unwrap_or(200);
    
    let history = sqlx::query_as!(
        AccountHistory,
        "SELECT timestamp, COALESCE(balance, 0.0) as \"balance!\", COALESCE(equity, 0.0) as \"equity!\", mt4_account as \"mt4_account!\", broker as \"broker!\" FROM account_status WHERE mt4_account = $1 ORDER BY timestamp DESC LIMIT $2",
        mt4_account, limit
    )
    .fetch_all(&state.db)
    .await
    .unwrap_or_default();

    let mut asc_history = history;
    asc_history.reverse();

    Ok(Json(asc_history))
}

async fn handle_trade_history(State(state): State<Arc<CombinedState>>, Json(payload): Json<Vec<TradeHistory>>) {
    tracing::info!("Received {} trade history records", payload.len());

    for trade in payload {
        let res = sqlx::query(
            "INSERT INTO trade_history (ticket, symbol, open_time, close_time, open_price, close_price, lots, profit, trade_type, magic, mae, mfe, signal_context, mt4_account, broker) 
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
             ON CONFLICT (ticket) DO UPDATE SET 
                mae = CASE WHEN trade_history.mfe < $12 THEN $11 ELSE trade_history.mae END,
                mfe = CASE WHEN trade_history.mfe < $12 THEN $12 ELSE trade_history.mfe END,
                signal_context = COALESCE(trade_history.signal_context, $13),
                mt4_account = $14,
                broker = $15"
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
        .bind(trade.mae)
        .bind(trade.mfe)
        .bind(&trade.signal_context)
        .bind(trade.mt4_account)
        .bind(&trade.broker)
        .execute(&state.db)
        .await;

        if let Err(e) = res {
            tracing::error!("DB Error (history): {}", e);
        }
    }
}

// Pagination Response Structure
#[derive(serde::Serialize)]
struct TradeHistoryResponse {
    data: Vec<TradeHistory>,
    total: i64,
    page: i64,
    limit: i64,
}

async fn get_trade_history(
    State(state): State<Arc<CombinedState>>,
    claims: Claims,
    axum::extract::Query(params): axum::extract::Query<HashMap<String, String>>,
) -> Result<Json<TradeHistoryResponse>, (axum::http::StatusCode, String)> {
    let mt4_account = params.get("mt4_account").and_then(|id| id.parse::<i64>().ok())
        .ok_or((axum::http::StatusCode::BAD_REQUEST, "Missing mt4_account".to_string()))?;
    // Verify ownership
    let _ = sqlx::query!(
        "SELECT 1 as \"exists!\" FROM user_accounts WHERE user_id = $1 AND mt4_account = $2",
        claims.user_id, mt4_account
    )
    .fetch_optional(&state.db)
    .await
    .map_err(|e: sqlx::Error| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
    .ok_or((axum::http::StatusCode::FORBIDDEN, "Access denied".to_string()))?;

    // Parse pagination params
    let page = params.get("page").and_then(|p| p.parse::<i64>().ok()).unwrap_or(1);
    let limit = params.get("limit").and_then(|l| l.parse::<i64>().ok()).unwrap_or(100);
    let offset = (page - 1) * limit;
    let symbol = params.get("symbol").cloned();

    // Get Total Count and Data with optional symbol filtering
    let (total, trades) = if let Some(ref sym) = symbol {
        let total_record = sqlx::query!(
            "SELECT count(*) as count FROM trade_history WHERE mt4_account = $1 AND symbol = $2",
            mt4_account, sym
        )
        .fetch_one(&state.db)
        .await
        .map_err(|e| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

        let trades = sqlx::query_as!(
            TradeHistory,
            r#"
            SELECT 
                ticket as "ticket!", 
                symbol as "symbol!", 
                open_time as "open_time!", 
                close_time as "close_time!", 
                COALESCE(open_price, 0.0) as "open_price!", 
                COALESCE(close_price, 0.0) as "close_price!", 
                COALESCE(lots, 0.0) as "lots!", 
                COALESCE(profit, 0.0) as "profit!", 
                trade_type as "trade_type!", 
                COALESCE(magic, 0) as "magic!", 
                COALESCE(mae, 0.0) as "mae!", 
                COALESCE(mfe, 0.0) as "mfe!", 
                signal_context, 
                mt4_account as "mt4_account!", 
                broker as "broker!" 
            FROM trade_history 
            WHERE mt4_account = $1 AND symbol = $2
            ORDER BY close_time DESC 
            LIMIT $3 OFFSET $4
            "#,
            mt4_account, sym, limit, offset
        )
        .fetch_all(&state.db)
        .await
        .map_err(|e| {
            tracing::error!("DB Error trade_history: {}", e);
            (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string())
        })?;
        (total_record.count.unwrap_or(0), trades)
    } else {
        let total_record = sqlx::query!(
            "SELECT count(*) as count FROM trade_history WHERE mt4_account = $1",
            mt4_account
        )
        .fetch_one(&state.db)
        .await
        .map_err(|e| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

        let trades = sqlx::query_as!(
            TradeHistory,
            r#"
            SELECT 
                ticket as "ticket!", 
                symbol as "symbol!", 
                open_time as "open_time!", 
                close_time as "close_time!", 
                COALESCE(open_price, 0.0) as "open_price!", 
                COALESCE(close_price, 0.0) as "close_price!", 
                COALESCE(lots, 0.0) as "lots!", 
                COALESCE(profit, 0.0) as "profit!", 
                trade_type as "trade_type!", 
                COALESCE(magic, 0) as "magic!", 
                COALESCE(mae, 0.0) as "mae!", 
                COALESCE(mfe, 0.0) as "mfe!", 
                signal_context, 
                mt4_account as "mt4_account!", 
                broker as "broker!" 
            FROM trade_history 
            WHERE mt4_account = $1
            ORDER BY close_time DESC 
            LIMIT $2 OFFSET $3
            "#,
            mt4_account, limit, offset
        )
        .fetch_all(&state.db)
        .await
        .map_err(|e| {
            tracing::error!("DB Error trade_history: {}", e);
            (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string())
        })?;
        (total_record.count.unwrap_or(0), trades)
    };
    
    Ok(Json(TradeHistoryResponse {
        data: trades,
        total,
        page,
        limit
    }))
}


async fn get_candles(
    State(state): State<Arc<CombinedState>>,
    _claims: Claims, // Require auth
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
    let start_timestamp = chrono::Utc::now().timestamp() - (limit * bucket_interval * 3);

    let query = format!(
        "SELECT 
            (timestamp / {0}) * {0} as time,
            (array_agg(bid ORDER BY timestamp ASC))[1] as open,
            MAX(bid) as high,
            MIN(bid) as low,
            (array_agg(bid ORDER BY timestamp DESC))[1] as close
         FROM market_data 
         WHERE symbol = $1 AND timestamp > $2
         GROUP BY 1
         ORDER BY 1 DESC
         LIMIT {1}",
        bucket_interval, limit
    );

    let candles = sqlx::query_as::<_, Candle>(&query)
        .bind(symbol)
        .bind(start_timestamp)
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
        let key = format!("{}:{}", payload.mt4_account, payload.broker);
        s.pending_commands.entry(key).or_insert_with(Vec::new).push(payload);
    }
}

async fn get_commands(
    State(state): State<Arc<CombinedState>>,
    claims: Claims,
    axum::extract::Query(params): axum::extract::Query<HashMap<String, String>>,
) -> Result<Json<Vec<Command>>, (axum::http::StatusCode, String)> {
    let mt4_account = params.get("mt4_account").and_then(|id| id.parse::<i64>().ok())
        .ok_or((axum::http::StatusCode::BAD_REQUEST, "Missing mt4_account".to_string()))?;
    // Verify ownership
    let _ = sqlx::query!(
        "SELECT 1 as \"exists!\" FROM user_accounts WHERE user_id = $1 AND mt4_account = $2",
        claims.user_id, mt4_account
    )
    .fetch_optional(&state.db)
    .await
    .map_err(|e: sqlx::Error| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
    .ok_or((axum::http::StatusCode::FORBIDDEN, "Access denied".to_string()))?;

    let mut s = state.memory.write().unwrap();
    // Similar to logs, we need to find the command queue for this account
    // Since broker is part of key, we iterate.
    let mut found_commands = Vec::new();
    let mut key_to_remove = None;
    
    for (key, cmds) in s.pending_commands.iter() {
        if key.starts_with(&format!("{}:", mt4_account)) {
            found_commands = cmds.clone();
            key_to_remove = Some(key.clone());
            break;
        }
    }
    
    if let Some(k) = key_to_remove {
        s.pending_commands.remove(&k);
    }
    
    Ok(Json(found_commands))
}

async fn handle_login(
    State(state): State<Arc<CombinedState>>,
    Json(payload): Json<LoginRequest>,
) -> Result<Json<LoginResponse>, (axum::http::StatusCode, String)> {
    let user = sqlx::query_as!(
        crate::data_models::UserInternal,
        "SELECT id, username, password_hash, role FROM users WHERE username = $1", 
        payload.username
    )
    .fetch_optional(&state.db)
    .await
    .map_err(|e: sqlx::Error| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    if let Some(u) = user {
        if verify(&payload.password, &u.password_hash).unwrap_or(false) {
            let expiration = chrono::Utc::now()
                .checked_add_signed(chrono::Duration::hours(24))
                .expect("valid timestamp")
                .timestamp() as usize;
  
            let claims = Claims {
                sub: u.username.clone(),
                user_id: u.id,
                role: u.role.clone(),
                exp: expiration,
            };

            let token = encode(
                &Header::default(),
                &claims,
                &EncodingKey::from_secret(state.jwt_secret.as_ref()),
            )
            .map_err(|e| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

            return Ok(Json(LoginResponse {
                token,
                username: u.username,
                role: u.role,
            }));
        }
    }

    Err((axum::http::StatusCode::UNAUTHORIZED, "Invalid username or password".to_string()))
}

async fn handle_register(
    State(state): State<Arc<CombinedState>>,
    Json(payload): Json<LoginRequest>,
) -> Result<Json<LoginResponse>, (axum::http::StatusCode, String)> {
    // Check if user exists
    let existing = sqlx::query!("SELECT id FROM users WHERE username = $1", payload.username)
        .fetch_optional(&state.db)
        .await
        .map_err(|e: sqlx::Error| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    if existing.is_some() {
        return Err((axum::http::StatusCode::CONFLICT, "Username already exists".to_string()));
    }

    // Hash password
    let password_hash = hash(&payload.password, DEFAULT_COST)
        .map_err(|e| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    // Create user
    let user = sqlx::query!(
        "INSERT INTO users (username, password_hash, role) VALUES ($1, $2, $3) RETURNING id, username, role",
        payload.username, password_hash, "viewer"
    )
    .fetch_one(&state.db)
    .await
    .map_err(|e: sqlx::Error| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    // Generate token
    let expiration = chrono::Utc::now()
        .checked_add_signed(chrono::Duration::hours(24))
        .expect("valid timestamp")
        .timestamp() as usize;

    let claims = Claims {
        sub: user.username.clone(),
        user_id: user.id,
        role: user.role.clone(),
        exp: expiration,
    };

    let token = encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(state.jwt_secret.as_ref()),
    )
    .map_err(|e| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(LoginResponse {
        token,
        username: user.username,
        role: user.role,
    }))
}

async fn list_accounts(
    State(state): State<Arc<CombinedState>>,
    claims: Claims,
) -> Result<Json<Vec<crate::data_models::AccountRecord>>, (axum::http::StatusCode, String)> {
    let accounts = sqlx::query_as!(
        crate::data_models::AccountRecord,
        "SELECT mt4_account, broker, account_name FROM user_accounts WHERE user_id = $1",
        claims.user_id
    )
    .fetch_all(&state.db)
    .await
    .map_err(|e: sqlx::Error| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(accounts))
}

async fn bind_account(
    State(state): State<Arc<CombinedState>>,
    claims: Claims,
    Json(payload): Json<crate::data_models::BindAccountRequest>,
) -> Result<Json<crate::data_models::AccountRecord>, (axum::http::StatusCode, String)> {
    // Upsert binding in user_accounts
    sqlx::query!(
        "INSERT INTO user_accounts (user_id, mt4_account, broker, account_name, created_at) 
         VALUES ($1, $2, $3, $4, $5)
         ON CONFLICT (user_id, mt4_account, broker) 
         DO UPDATE SET account_name = $4",
        claims.user_id, 
        payload.mt4_account, 
        payload.broker, 
        payload.account_name,
        chrono::Utc::now().timestamp()
    )
    .execute(&state.db)
    .await
    .map_err(|e: sqlx::Error| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(crate::data_models::AccountRecord {
        mt4_account: payload.mt4_account,
        broker: payload.broker,
        account_name: payload.account_name,
    }))
}

#[derive(Debug, Serialize)]
struct RiskControlResponse {
    #[serde(flatten)]
    state: RiskControlState,
    #[serde(default)]
    metrics: Option<SmartExitMetrics>,
}

async fn get_risk_control(
    State(state): State<Arc<CombinedState>>,
    axum::extract::Query(params): axum::extract::Query<HashMap<String, String>>,
) -> axum::response::Response {
    let mt4_account = match params.get("mt4_account").and_then(|id| id.parse::<i64>().ok()) {
        Some(id) => id,
        None => return (axum::http::StatusCode::BAD_REQUEST, "Missing mt4_account").into_response(),
    };

    let s = state.memory.read().unwrap();
    
    // Return existing state or default (safe) state
    let control = s.risk_controls.get(&mt4_account).cloned().unwrap_or_else(|| RiskControlState {
        mt4_account,
        block_buy: false,
        block_sell: false,
        block_all: false,
        risk_level: "SAFE".to_string(),
        updated_at: chrono::Utc::now().timestamp(),
        risk_score: 0.0,
        exit_trigger: "NONE".to_string(),
        velocity_block: false,
        enabled: false,
    });

    let metrics = s.risk_details.get(&mt4_account).cloned();

    Json(RiskControlResponse {
        state: control,
        metrics,
    }).into_response()
}

async fn update_risk_control(
    State(state): State<Arc<CombinedState>>,
    claims: Claims,
    Json(payload): Json<RiskControlState>,
) -> axum::response::Response {
    // Verify ownership
    let check_res = sqlx::query(
        "SELECT 1 FROM user_accounts WHERE user_id = $1 AND mt4_account = $2"
    )
    .bind(claims.user_id)
    .bind(payload.mt4_account)
    .fetch_optional(&state.db)
    .await;

    let check = match check_res {
        Ok(c) => c,
        Err(e) => return (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()).into_response(),
    };

    if check.is_none() {
        return (axum::http::StatusCode::FORBIDDEN, "Access denied").into_response();
    }

    let mut updated_payload = payload.clone();
    updated_payload.updated_at = chrono::Utc::now().timestamp();

    // Persist to DB first (outside of lock)
    let db_res = sqlx::query(
        "INSERT INTO risk_controls (mt4_account, block_buy, block_sell, block_all, risk_level, updated_at, risk_score, exit_trigger, velocity_block, enabled)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
         ON CONFLICT (mt4_account) DO UPDATE SET
            block_buy = $2,
            block_sell = $3,
            block_all = $4,
            risk_level = $5,
            updated_at = $6,
            risk_score = $7,
            exit_trigger = $8,
            velocity_block = $9,
            enabled = $10"
    )
    .bind(updated_payload.mt4_account)
    .bind(updated_payload.block_buy)
    .bind(updated_payload.block_sell)
    .bind(updated_payload.block_all)
    .bind(&updated_payload.risk_level)
    .bind(updated_payload.updated_at)
    .bind(updated_payload.risk_score)
    .bind(&updated_payload.exit_trigger)
    .bind(updated_payload.velocity_block)
    .bind(updated_payload.enabled)
    .execute(&state.db)
    .await;

    if let Err(e) = db_res {
        tracing::error!("Failed to persist risk control: {}", e);
    }

    // Update memory state (short lock, no await inside)
    {
        let mut s = state.memory.write().unwrap();
        s.risk_controls.insert(payload.mt4_account, updated_payload.clone());
    }

    tracing::info!("Risk Control Updated for Account {}: Enabled={} Level={} BlockBuy={} BlockSell={}", 
        payload.mt4_account, payload.enabled, payload.risk_level, payload.block_buy, payload.block_sell);

    // Insert operation log ONLY when directives change
    // Get previous state to compare
    let prev_state = {
        let s = state.memory.read().unwrap();
        s.risk_controls.get(&payload.mt4_account).cloned()
    };

    let now = chrono::Utc::now().timestamp();

    if let Some(prev) = &prev_state {
        // Each directive change gets its own log entry
        if !prev.block_buy && payload.block_buy {
            let _ = sqlx::query("INSERT INTO risk_control_logs (mt4_account, action, risk_level, risk_score, exit_trigger, created_at) VALUES ($1, $2, $3, $4, $5, $6)")
                .bind(payload.mt4_account).bind("禁止做多").bind(&payload.risk_level).bind(payload.risk_score).bind(&payload.exit_trigger).bind(now)
                .execute(&state.db).await;
        }
        if prev.block_buy && !payload.block_buy {
            let _ = sqlx::query("INSERT INTO risk_control_logs (mt4_account, action, risk_level, risk_score, exit_trigger, created_at) VALUES ($1, $2, $3, $4, $5, $6)")
                .bind(payload.mt4_account).bind("允许做多").bind(&payload.risk_level).bind(payload.risk_score).bind(&payload.exit_trigger).bind(now)
                .execute(&state.db).await;
        }
        if !prev.block_sell && payload.block_sell {
            let _ = sqlx::query("INSERT INTO risk_control_logs (mt4_account, action, risk_level, risk_score, exit_trigger, created_at) VALUES ($1, $2, $3, $4, $5, $6)")
                .bind(payload.mt4_account).bind("禁止做空").bind(&payload.risk_level).bind(payload.risk_score).bind(&payload.exit_trigger).bind(now)
                .execute(&state.db).await;
        }
        if prev.block_sell && !payload.block_sell {
            let _ = sqlx::query("INSERT INTO risk_control_logs (mt4_account, action, risk_level, risk_score, exit_trigger, created_at) VALUES ($1, $2, $3, $4, $5, $6)")
                .bind(payload.mt4_account).bind("允许做空").bind(&payload.risk_level).bind(payload.risk_score).bind(&payload.exit_trigger).bind(now)
                .execute(&state.db).await;
        }
        if !prev.block_all && payload.block_all {
            let _ = sqlx::query("INSERT INTO risk_control_logs (mt4_account, action, risk_level, risk_score, exit_trigger, created_at) VALUES ($1, $2, $3, $4, $5, $6)")
                .bind(payload.mt4_account).bind("全部禁止").bind(&payload.risk_level).bind(payload.risk_score).bind(&payload.exit_trigger).bind(now)
                .execute(&state.db).await;
        }
        if prev.block_all && !payload.block_all {
            let _ = sqlx::query("INSERT INTO risk_control_logs (mt4_account, action, risk_level, risk_score, exit_trigger, created_at) VALUES ($1, $2, $3, $4, $5, $6)")
                .bind(payload.mt4_account).bind("解除全禁").bind(&payload.risk_level).bind(payload.risk_score).bind(&payload.exit_trigger).bind(now)
                .execute(&state.db).await;
        }
        if prev.exit_trigger != payload.exit_trigger && payload.exit_trigger != "NONE" {
            let trigger_action = match payload.exit_trigger.as_str() {
                "FORCE_EXIT" => "强制退出",
                "TACTICAL_EXIT" => "战术退出",
                "LAYER_LOCK" => "锁定加仓",
                _ => "触发变更"
            };
            let _ = sqlx::query("INSERT INTO risk_control_logs (mt4_account, action, risk_level, risk_score, exit_trigger, created_at) VALUES ($1, $2, $3, $4, $5, $6)")
                .bind(payload.mt4_account).bind(trigger_action).bind(&payload.risk_level).bind(payload.risk_score).bind(&payload.exit_trigger).bind(now)
                .execute(&state.db).await;
        }
    } else if payload.enabled {
        // First time activation
        let _ = sqlx::query("INSERT INTO risk_control_logs (mt4_account, action, risk_level, risk_score, exit_trigger, created_at) VALUES ($1, $2, $3, $4, $5, $6)")
            .bind(payload.mt4_account).bind("系统启动").bind(&payload.risk_level).bind(payload.risk_score).bind(&payload.exit_trigger).bind(now)
            .execute(&state.db).await;
    }

    Json(updated_payload).into_response()
}

// Unified EA Sync Handler
async fn handle_ea_sync(
    State(state): State<Arc<CombinedState>>,
    axum::extract::Query(params): axum::extract::Query<HashMap<String, String>>,
) -> Result<Json<crate::data_models::EASyncResponse>, (axum::http::StatusCode, String)> {
    let mt4_account = params.get("mt4_account").and_then(|id| id.parse::<i64>().ok())
        .ok_or((axum::http::StatusCode::BAD_REQUEST, "Missing mt4_account".to_string()))?;

    // 1. Get Risk Control State (Default to safe if missing)
    let risk_control = {
        let s = state.memory.read().unwrap();
        s.risk_controls.get(&mt4_account).cloned().unwrap_or_else(|| RiskControlState {
            mt4_account,
            block_buy: false,
            block_sell: false,
            block_all: false,
            risk_level: "SAFE".to_string(),
            updated_at: chrono::Utc::now().timestamp(),
            risk_score: 0.0,
            exit_trigger: "NONE".to_string(),
            velocity_block: false, // Default
            enabled: false,
        })
    };

    // 2. Get Pending Commands (and clear queue)
    let commands = {
        let mut s = state.memory.write().unwrap();
        let mut found_commands = Vec::new();
        let mut key_to_remove = None;
        
        // Find queue for this account (ignoring broker part of key)
        for (key, cmds) in s.pending_commands.iter() {
            if key.starts_with(&format!("{}:", mt4_account)) {
                found_commands = cmds.clone();
                key_to_remove = Some(key.clone());
                break;
            }
        }
        
        if let Some(k) = key_to_remove {
            s.pending_commands.remove(&k);
        }
        found_commands
    };

    Ok(Json(crate::data_models::EASyncResponse {
        commands,
        risk_control,
    }))
}

/// Get velocity data for smart exit calculations
/// Calculates 1-min price velocity and relative volume vs 24h average
async fn get_velocity(
    State(state): State<Arc<CombinedState>>,
    _claims: Claims,
    axum::extract::Query(params): axum::extract::Query<HashMap<String, String>>,
) -> Result<Json<VelocityData>, (axum::http::StatusCode, String)> {
    let symbol = params.get("symbol").cloned().unwrap_or_else(|| "XAUUSD".to_string());
    let now = chrono::Utc::now().timestamp();
    
    // 0. Find the LATEST timestamp for this symbol
    let max_ts_row = sqlx::query!(
        "SELECT MAX(timestamp) as max_ts FROM market_data WHERE symbol = $1",
        symbol
    )
    .fetch_optional(&state.db)
    .await
    .map_err(|e| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    // DEBUG LOGS
    tracing::info!("Velocity Debug [{}] Now: {}, MaxTS: {:?}", symbol, now, max_ts_row.as_ref().and_then(|r| r.max_ts));

    let latest_ts = match max_ts_row.and_then(|r| r.max_ts) {
        Some(ts) => ts,
        None => {
            tracing::warn!("Velocity Debug [{}] No market data found!", symbol);
            return Ok(Json(VelocityData { symbol, velocity_m1: 0.0, rvol: 1.0, timestamp: now }));
        },
    };

    if now - latest_ts > 300 {
        tracing::warn!(" Velocity Debug [{}] Data Stale! Latest: {}, Now: {}, Diff: {}", symbol, latest_ts, now, now - latest_ts);
    }

    // 1. Calculate 1-min velocity: (current price - price 1 min ago)
    let velocity_result = sqlx::query(
        "SELECT 
            (array_agg(bid ORDER BY timestamp DESC))[1] as current_price,
            (array_agg(bid ORDER BY timestamp ASC))[1] as old_price
         FROM market_data 
         WHERE symbol = $1 AND timestamp >= $2 AND timestamp <= $3"
    )
    .bind(&symbol)
    .bind(latest_ts - 61) // Start of window
    .bind(latest_ts)      // End of window
    .fetch_optional(&state.db)
    .await
    .map_err(|e| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    let velocity_m1 = if let Some(row) = velocity_result {
        use sqlx::Row;
        let current: Option<f64> = row.try_get("current_price").ok();
        let old: Option<f64> = row.try_get("old_price").ok();
        
        tracing::info!("Velocity Debug [{}] Window: [{}, {}], Current: {:?}, Old: {:?}", symbol, latest_ts - 61, latest_ts, current, old);

        let current_val = current.unwrap_or(0.0);
        let old_val = old.unwrap_or(0.0);
        
        if old_val > 0.0 { current_val - old_val } else { 0.0 }
    } else {
        tracing::warn!("Velocity Debug [{}] Query returned no rows for price window", symbol);
        0.0
    };

    // 2. Calculate RVOL based on the SAME timestamp reference
    let rvol_result = sqlx::query(
        "WITH 
         current_period AS (
             SELECT COUNT(*) as tick_count FROM market_data 
             WHERE symbol = $1 AND timestamp >= $2 AND timestamp <= $3
         ),
         avg_period AS (
             SELECT COUNT(*) / 24.0 as avg_hourly_ticks FROM market_data 
             WHERE symbol = $1 AND timestamp >= $4 AND timestamp <= $3
         )
         SELECT 
            cp.tick_count,
            NULLIF(ap.avg_hourly_ticks, 0) as avg_ticks
         FROM current_period cp, avg_period ap"
    )
    .bind(&symbol)
    .bind(latest_ts - 3600) // Current hour relative to data
    .bind(latest_ts)        // Latest data point
    .bind(latest_ts - 86400) // Last 24 hours relative to data
    .fetch_optional(&state.db)
    .await
    .map_err(|e| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
    
    let rvol = if let Some(row) = rvol_result {
        use sqlx::Row;
        let current_ticks: i64 = row.try_get("tick_count").unwrap_or(0);
        let avg_ticks: Option<f64> = row.try_get("avg_ticks").ok();
        
        tracing::info!("Velocity Debug [{}] RVOL: Ticks: {}, Avg: {:?}", symbol, current_ticks, avg_ticks);
        
        if let Some(avg) = avg_ticks {
            if avg > 0.0 {
                (current_ticks as f64) / avg
            } else {
                1.0
            }
        } else {
            1.0
        }
    } else {
        1.0
    };

    Ok(Json(VelocityData {
        symbol,
        velocity_m1,
        rvol,
        timestamp: latest_ts,
    }))
}

// ========== Risk Control Logs ==========
#[derive(Debug, serde::Serialize, serde::Deserialize, sqlx::FromRow)]
struct RiskControlLog {
    id: i64,
    mt4_account: i64, 
    action: String,
    risk_level: Option<String>,
    risk_score: Option<f64>,
    exit_trigger: Option<String>,
    created_at: i64,
}

async fn get_risk_control_logs(
    State(state): State<Arc<CombinedState>>,
    claims: Claims,
    axum::extract::Query(params): axum::extract::Query<HashMap<String, String>>,
) -> Result<Json<Vec<RiskControlLog>>, (axum::http::StatusCode, String)> {
    let mt4_account = params.get("mt4_account").and_then(|id| id.parse::<i64>().ok())
        .ok_or((axum::http::StatusCode::BAD_REQUEST, "Missing mt4_account".to_string()))?;
    
    // Verify ownership
    let _ = sqlx::query!(
        "SELECT 1 as \"exists!\" FROM user_accounts WHERE user_id = $1 AND mt4_account = $2",
        claims.user_id, mt4_account
    )
    .fetch_optional(&state.db)
    .await
    .map_err(|e: sqlx::Error| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
    .ok_or((axum::http::StatusCode::FORBIDDEN, "Access denied".to_string()))?;

    let limit = params.get("limit").and_then(|l| l.parse::<i64>().ok()).unwrap_or(20);

    let logs = sqlx::query_as::<_, RiskControlLog>(
        "SELECT id, mt4_account, action, risk_level, risk_score, exit_trigger, created_at 
         FROM risk_control_logs 
         WHERE mt4_account = $1 
         ORDER BY created_at DESC 
         LIMIT $2"
    )
    .bind(mt4_account)
    .bind(limit)
    .fetch_all(&state.db)
    .await
    .map_err(|e| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(logs))
}
