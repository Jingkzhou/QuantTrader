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
    pub account_statuses: HashMap<i32, AccountStatus>,
    pub recent_logs: HashMap<i32, Vec<LogEntry>>,
    pub pending_commands: HashMap<i32, Vec<Command>>,
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

async fn get_or_create_account(pool: &sqlx::PgPool, mt4_acc: i64, broker: &str) -> Option<i32> {
    // Check if account exists
    let row = sqlx::query!(
        "SELECT id, owner_id, mt4_account_number, broker_name, account_name, COALESCE(is_active, true) as \"is_active!\" FROM accounts WHERE mt4_account_number = $1 AND broker_name = $2", 
        mt4_acc, broker
    )
    .fetch_optional(pool)
    .await
    .ok()
    .flatten();

    if let Some(r) = row {
        Some(r.id)
    } else {
        // Auto-register (owner_id is None initially until a user claims it)
        let res = sqlx::query!(
            "INSERT INTO accounts (mt4_account_number, broker_name) VALUES ($1, $2) RETURNING id",
            mt4_acc, broker
        )
        .fetch_one(pool)
        .await
        .ok()?;
        Some(res.id)
    }
}

async fn get_state(
    State(state): State<Arc<CombinedState>>,
    claims: Claims,
    axum::extract::Query(params): axum::extract::Query<HashMap<String, String>>,
) -> Result<Json<AppState>, (axum::http::StatusCode, String)> {
    let account_id = params.get("account_id").and_then(|id| id.parse::<i32>().ok());

    let mut app_state = AppState::default();
    
    // Fill global memory state (Market Data & Active Symbols)
    {
        let s = state.memory.read().unwrap();
        app_state.market_data = s.market_data.clone();
        app_state.active_symbols = s.active_symbols.clone();
    }

    // Use if let to handle optional account_id
    if let Some(id) = account_id {
        // Verify ownership
        let acc = sqlx::query!("SELECT id FROM accounts WHERE id = $1 AND owner_id = $2", id, claims.user_id)
            .fetch_optional(&state.db)
            .await
            .map_err(|e: sqlx::Error| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
            .ok_or((axum::http::StatusCode::FORBIDDEN, "Access denied".to_string()))?;

        // Fetch latest snapshot for this account
        let status_row = sqlx::query!("SELECT * FROM account_status WHERE account_uuid = $1 ORDER BY timestamp DESC LIMIT 1", acc.id)
            .fetch_optional(&state.db)
            .await
            .map_err(|e: sqlx::Error| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
        
        // Fill from DB snapshot if exists
        if let Some(row) = status_row {
            app_state.account_status.balance = row.balance.unwrap_or(0.0);
            app_state.account_status.equity = row.equity.unwrap_or(0.0);
            app_state.account_status.margin = row.margin.unwrap_or(0.0);
            app_state.account_status.free_margin = row.free_margin.unwrap_or(0.0);
            app_state.account_status.floating_profit = row.floating_profit.unwrap_or(0.0);
            app_state.account_status.timestamp = row.timestamp;
            
            if let Some(ps_json) = row.positions_snapshot {
                app_state.account_status.positions = serde_json::from_str(&ps_json).unwrap_or_default();
            }
        }

        // Overlay real-time memory state for this account
        {
            let s = state.memory.read().unwrap();
            
            // Use real-time status from memory if available
            if let Some(real_time_status) = s.account_statuses.get(&acc.id) {
                app_state.account_status = real_time_status.clone();
            }

            // Filter logs for this account
            if let Some(logs) = s.recent_logs.get(&acc.id) {
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
    let account_uuid = get_or_create_account(&state.db, 0, "").await; // Market data is often global, but could be linked. For now, leave as None.

    let res = sqlx::query(
        "INSERT INTO market_data (symbol, timestamp, open, high, low, close, bid, ask, account_uuid) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)"
    )
    .bind(&payload.symbol)
    .bind(payload.timestamp as i64)
    .bind(payload.open)
    .bind(payload.high)
    .bind(payload.low)
    .bind(payload.close)
    .bind(payload.bid)
    .bind(payload.ask)
    .bind(account_uuid)
    .execute(&state.db)
    .await;

    if let Err(e) = res {
        tracing::error!("DB Error (market): {}", e);
    }
}

async fn handle_account_status(State(state): State<Arc<CombinedState>>, Json(payload): Json<AccountStatus>) {
    tracing::info!("Account Status Update: Equity:{} Acc:{} Broker:{}", payload.equity, payload.mt4_account, payload.broker);
    
    // Persist to DB first to get/create account_uuid
    let account_uuid = get_or_create_account(&state.db, payload.mt4_account, &payload.broker).await;
    
    // Update Memory
    if let Some(account_id) = account_uuid {
        let mut s = state.memory.write().unwrap();
        let status = s.account_statuses.entry(account_id).or_insert_with(AccountStatus::default);
        
        status.balance = payload.balance;
        status.equity = payload.equity;
        status.margin = payload.margin;
        status.free_margin = payload.free_margin;
        status.floating_profit = payload.floating_profit;
        status.timestamp = payload.timestamp;
        status.positions = payload.positions.clone();
    }

    let positions_json = serde_json::to_string(&payload.positions).unwrap_or_default();
    let timestamp = if payload.timestamp > 0 { payload.timestamp } else { chrono::Utc::now().timestamp() };

    let res = sqlx::query(
        "INSERT INTO account_status (balance, equity, margin, free_margin, floating_profit, timestamp, positions_snapshot, account_uuid) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)"
    )
    .bind(payload.balance)
    .bind(payload.equity)
    .bind(payload.margin)
    .bind(payload.free_margin)
    .bind(payload.floating_profit)
    .bind(timestamp as i64)
    .bind(positions_json)
    .bind(account_uuid)
    .execute(&state.db)
    .await;

    if let Err(e) = res {
        tracing::error!("DB Error (account): {}", e);
    }
}

async fn handle_logs(State(state): State<Arc<CombinedState>>, Json(payload): Json<LogEntry>) {
    tracing::info!("Log [{}]: {}", payload.level, payload.message);
    
    let account_id = get_or_create_account(&state.db, payload.mt4_account, &payload.broker).await;
    
    if let Some(id) = account_id {
        let mut s = state.memory.write().unwrap();
        let logs = s.recent_logs.entry(id).or_insert_with(Vec::new);
        logs.insert(0, payload);
        if logs.len() > 100 {
            logs.truncate(100);
        }
    }
}




async fn get_account_history(
    State(state): State<Arc<CombinedState>>,
    claims: Claims,
    axum::extract::Query(params): axum::extract::Query<std::collections::HashMap<String, String>>,
) -> Result<Json<Vec<AccountHistory>>, (axum::http::StatusCode, String)> {
    let account_id = params.get("account_id").and_then(|id| id.parse::<i32>().ok())
        .ok_or((axum::http::StatusCode::BAD_REQUEST, "Missing account_id".to_string()))?;

    // Verify ownership
    let _ = sqlx::query!("SELECT id FROM accounts WHERE id = $1 AND owner_id = $2", account_id, claims.user_id)
        .fetch_optional(&state.db)
        .await
        .map_err(|e: sqlx::Error| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        .ok_or((axum::http::StatusCode::FORBIDDEN, "Access denied".to_string()))?;

    let limit = params.get("limit").and_then(|s| s.parse::<i64>().ok()).unwrap_or(200);
    
    let history = sqlx::query_as::<_, AccountHistory>(
        "SELECT timestamp, balance, equity FROM account_status WHERE account_uuid = $1 ORDER BY timestamp DESC LIMIT $2"
    )
    .bind(account_id)
    .bind(limit)
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
        let account_uuid = get_or_create_account(&state.db, trade.mt4_account, &trade.broker).await;

        let res = sqlx::query(
            "INSERT INTO trade_history (ticket, symbol, open_time, close_time, open_price, close_price, lots, profit, trade_type, magic, mae, mfe, signal_context, account_uuid) 
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
             ON CONFLICT (ticket) DO UPDATE SET 
                mae = CASE WHEN trade_history.mfe < $12 THEN $11 ELSE trade_history.mae END,
                mfe = CASE WHEN trade_history.mfe < $12 THEN $12 ELSE trade_history.mfe END,
                signal_context = COALESCE(trade_history.signal_context, $13),
                account_uuid = $14"
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
        .bind(account_uuid)
        .execute(&state.db)
        .await;

        if let Err(e) = res {
            tracing::error!("DB Error (history): {}", e);
        }
    }
}

async fn get_trade_history(
    State(state): State<Arc<CombinedState>>,
    claims: Claims,
    axum::extract::Query(params): axum::extract::Query<HashMap<String, String>>,
) -> Result<Json<Vec<TradeHistory>>, (axum::http::StatusCode, String)> {
    let account_id = params.get("account_id").and_then(|id| id.parse::<i32>().ok())
        .ok_or((axum::http::StatusCode::BAD_REQUEST, "Missing account_id".to_string()))?;

    // Verify ownership
    let _ = sqlx::query!("SELECT id FROM accounts WHERE id = $1 AND owner_id = $2", account_id, claims.user_id)
        .fetch_optional(&state.db)
        .await
        .map_err(|e: sqlx::Error| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        .ok_or((axum::http::StatusCode::FORBIDDEN, "Access denied".to_string()))?;

    let trades = sqlx::query_as::<_, TradeHistory>("SELECT * FROM trade_history WHERE account_uuid = $1 ORDER BY close_time DESC LIMIT 100")
        .bind(account_id)
        .fetch_all(&state.db)
        .await
        .unwrap_or_default();
    
    Ok(Json(trades))
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
        s.pending_commands.entry(payload.mt4_account as i32).or_insert_with(Vec::new).push(payload);
    }
}

async fn get_commands(
    State(state): State<Arc<CombinedState>>,
    claims: Claims,
    axum::extract::Query(params): axum::extract::Query<HashMap<String, String>>,
) -> Result<Json<Vec<Command>>, (axum::http::StatusCode, String)> {
    let account_id = params.get("account_id").and_then(|id| id.parse::<i32>().ok())
        .ok_or((axum::http::StatusCode::BAD_REQUEST, "Missing account_id".to_string()))?;

    // Verify ownership
    let _ = sqlx::query!("SELECT id FROM accounts WHERE id = $1 AND owner_id = $2", account_id, claims.user_id)
        .fetch_optional(&state.db)
        .await
        .map_err(|e: sqlx::Error| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        .ok_or((axum::http::StatusCode::FORBIDDEN, "Access denied".to_string()))?;

    let mut s = state.memory.write().unwrap();
    let commands = s.pending_commands.get(&account_id).cloned().unwrap_or_default();
    s.pending_commands.remove(&account_id); // Consume commands
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
        "SELECT id, owner_id, mt4_account_number, broker_name, account_name, COALESCE(is_active, true) as \"is_active!\" FROM accounts WHERE owner_id = $1",
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
    // 1. Find if the account exists (auto-registered by EA)
    let account = sqlx::query_as!(
        crate::data_models::AccountRecord,
        "SELECT id, owner_id, mt4_account_number, broker_name, account_name, COALESCE(is_active, true) as \"is_active!\" FROM accounts WHERE mt4_account_number = $1 AND broker_name = $2",
        payload.mt4_account, payload.broker
    )
    .fetch_optional(&state.db)
    .await
    .map_err(|e: sqlx::Error| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    if let Some(mut acc) = account {
        if acc.owner_id.is_some() && acc.owner_id != Some(claims.user_id) {
            return Err((axum::http::StatusCode::FORBIDDEN, "Account already owned by another user".to_string()));
        }

        // Bind it
        sqlx::query!(
            "UPDATE accounts SET owner_id = $1, account_name = $2 WHERE id = $3",
            claims.user_id, payload.account_name, acc.id
        )
        .execute(&state.db)
        .await
        .map_err(|e: sqlx::Error| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

        acc.owner_id = Some(claims.user_id);
        acc.account_name = payload.account_name;
        Ok(Json(acc))
    } else {
        // Create it manually if it hasn't connected yet
        let acc = sqlx::query_as!(
            crate::data_models::AccountRecord,
            "INSERT INTO accounts (owner_id, mt4_account_number, broker_name, account_name) VALUES ($1, $2, $3, $4) RETURNING id, owner_id, mt4_account_number, broker_name, account_name, COALESCE(is_active, true) as \"is_active!\"",
            claims.user_id, payload.mt4_account, payload.broker, payload.account_name
        )
        .fetch_one(&state.db)
        .await
        .map_err(|e: sqlx::Error| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

        Ok(Json(acc))
    }
}
