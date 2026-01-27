use axum::{
    extract::{State, FromRef},
    routing::{get, post},
    Json, Router,
};
use crate::data_models::{MarketData, AccountStatus, LogEntry, Command, Candle, TradeHistory, AccountHistory};
use std::net::SocketAddr;
use std::sync::{Arc, RwLock};
use serde::{Serialize, Deserialize};
use tower_http::cors::{Any, CorsLayer};
use tower_http::trace::TraceLayer;
use sqlx::PgPool;

use std::collections::HashMap;
use jsonwebtoken::{encode, decode, Header, Algorithm, Validation, EncodingKey, DecodingKey};
use bcrypt::{hash, verify, DEFAULT_COST};

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
    pub active_symbols: Vec<String>,
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
    let broker = params.get("broker").map(|s| s.clone());

    let mut app_state = AppState::default();
    
    // Fill global memory state (Market Data & Active Symbols)
    {
        let s = state.memory.read().unwrap();
        app_state.market_data = s.market_data.clone();
        app_state.active_symbols = s.active_symbols.clone();
    }

    // Use if let to handle optional account context
    if let (Some(mt4), Some(brk)) = (mt4_account, broker) {
        // Verify ownership
        let _ = sqlx::query!(
            "SELECT 1 as \"exists!\" FROM user_accounts WHERE user_id = $1 AND mt4_account = $2 AND broker = $3",
            claims.user_id, mt4, brk
        )
        .fetch_optional(&state.db)
        .await
        .map_err(|e: sqlx::Error| {
            tracing::error!("Ownership verification error: {}", e);
            (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string())
        })?
        .ok_or_else(|| {
            tracing::error!("Access denied for user {} on account {}:{}", claims.user_id, mt4, brk);
            (axum::http::StatusCode::FORBIDDEN, "Access denied".to_string())
        })?;

        // Fetch latest snapshot for this account
        let status_row = sqlx::query!(
            "SELECT balance, equity, margin, free_margin, floating_profit, timestamp, mt4_account, broker, positions_snapshot FROM account_status WHERE mt4_account = $1 AND broker = $2 ORDER BY timestamp DESC LIMIT 1",
            mt4, brk
        )
        .fetch_optional(&state.db)
        .await
        .map_err(|e: sqlx::Error| {
            tracing::error!("Fetch account status error: {}", e);
            (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string())
        })?;
        
        // Fill from DB snapshot if exists
        if let Some(row) = status_row {
            app_state.account_status.balance = row.balance.unwrap_or(0.0);
            app_state.account_status.equity = row.equity.unwrap_or(0.0);
            app_state.account_status.margin = row.margin.unwrap_or(0.0);
            app_state.account_status.free_margin = row.free_margin.unwrap_or(0.0);
            app_state.account_status.floating_profit = row.floating_profit.unwrap_or(0.0);
            app_state.account_status.timestamp = row.timestamp;
            app_state.account_status.mt4_account = row.mt4_account.unwrap_or(0);
            app_state.account_status.broker = row.broker.unwrap_or_default();
            
            if let Some(ps_json) = row.positions_snapshot {
                app_state.account_status.positions = serde_json::from_str(&ps_json).unwrap_or_default();
            }
        }

        // Overlay real-time memory state for this account
        {
            let s = state.memory.read().unwrap();
            let key = format!("{}:{}", mt4, brk);
            
            // Use real-time status from memory if available
            if let Some(real_time_status) = s.account_statuses.get(&key) {
                app_state.account_status = real_time_status.clone();
            }

            // Filter logs for this account
            if let Some(logs) = s.recent_logs.get(&key) {
                app_state.recent_logs = logs.clone();
            }
        }
    }

    Ok(Json(app_state))
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
    }

    let positions_json = serde_json::to_string(&payload.positions).unwrap_or_default();
    let timestamp = if payload.timestamp > 0 { payload.timestamp } else { chrono::Utc::now().timestamp() };

    let res = sqlx::query(
        "INSERT INTO account_status (balance, equity, margin, free_margin, floating_profit, timestamp, positions_snapshot, mt4_account, broker) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)"
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
    .execute(&state.db)
    .await;

    if let Err(e) = res {
        tracing::error!("DB Error (account): {}", e);
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
    let broker = params.get("broker").ok_or((axum::http::StatusCode::BAD_REQUEST, "Missing broker".to_string()))?;

    // Verify ownership
    let _ = sqlx::query!(
        "SELECT 1 as \"exists!\" FROM user_accounts WHERE user_id = $1 AND mt4_account = $2 AND broker = $3",
        claims.user_id, mt4_account, broker
    )
    .fetch_optional(&state.db)
    .await
    .map_err(|e: sqlx::Error| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
    .ok_or((axum::http::StatusCode::FORBIDDEN, "Access denied".to_string()))?;

    let limit = params.get("limit").and_then(|s| s.parse::<i64>().ok()).unwrap_or(200);
    
    let history = sqlx::query_as!(
        AccountHistory,
        "SELECT timestamp, COALESCE(balance, 0.0) as \"balance!\", COALESCE(equity, 0.0) as \"equity!\", mt4_account as \"mt4_account!\", broker as \"broker!\" FROM account_status WHERE mt4_account = $1 AND broker = $2 ORDER BY timestamp DESC LIMIT $3",
        mt4_account, broker, limit
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
    let broker = params.get("broker").ok_or((axum::http::StatusCode::BAD_REQUEST, "Missing broker".to_string()))?;

    // Verify ownership
    let _ = sqlx::query!(
        "SELECT 1 as \"exists!\" FROM user_accounts WHERE user_id = $1 AND mt4_account = $2 AND broker = $3",
        claims.user_id, mt4_account, broker
    )
    .fetch_optional(&state.db)
    .await
    .map_err(|e: sqlx::Error| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
    .ok_or((axum::http::StatusCode::FORBIDDEN, "Access denied".to_string()))?;

    // Parse pagination params
    let page = params.get("page").and_then(|p| p.parse::<i64>().ok()).unwrap_or(1);
    let limit = params.get("limit").and_then(|l| l.parse::<i64>().ok()).unwrap_or(100);
    let offset = (page - 1) * limit;

    // Get Total Count
    let total_record = sqlx::query!(
        "SELECT count(*) as count FROM trade_history WHERE mt4_account = $1 AND broker = $2",
        mt4_account, broker
    )
    .fetch_one(&state.db)
    .await
    .map_err(|e| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    let total = total_record.count.unwrap_or(0);

    // Get Paginated Data
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
        WHERE mt4_account = $1 AND broker = $2
        ORDER BY close_time DESC 
        LIMIT $3 OFFSET $4
        "#,
        mt4_account, broker, limit, offset
    )
    .fetch_all(&state.db)
    .await
    .map_err(|e| {
        tracing::error!("DB Error trade_history: {}", e);
        e
    })
    .unwrap_or_default();
    
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
    let broker = params.get("broker").ok_or((axum::http::StatusCode::BAD_REQUEST, "Missing broker".to_string()))?;

    // Verify ownership
    let _ = sqlx::query!(
        "SELECT 1 as \"exists!\" FROM user_accounts WHERE user_id = $1 AND mt4_account = $2 AND broker = $3",
        claims.user_id, mt4_account, broker
    )
    .fetch_optional(&state.db)
    .await
    .map_err(|e: sqlx::Error| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
    .ok_or((axum::http::StatusCode::FORBIDDEN, "Access denied".to_string()))?;

    let key = format!("{}:{}", mt4_account, broker);
    let mut s = state.memory.write().unwrap();
    let commands = s.pending_commands.get(&key).cloned().unwrap_or_default();
    s.pending_commands.remove(&key); // Consume commands
    Ok(Json(commands))
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
