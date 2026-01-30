mod config;
mod connectors;
mod oms;
mod strategy;
mod risk;
mod ipc;
mod data_models;

#[tokio::main]
async fn main() {
    // Load environment variables
    dotenvy::dotenv().ok();
    
    // Initialize logging
    tracing_subscriber::fmt::init();

    tracing::info!("core_engine bootstrapping...");

    let database_url = std::env::var("TIMESCALE_URL").expect("TIMESCALE_URL must be set");
    let pool = sqlx::postgres::PgPoolOptions::new()
        .max_connections(5)
        .connect(&database_url)
        .await
        .expect("Failed to connect to Postgres");

    // Initialize tables if they don't exist
    sqlx::query(
        "CREATE TABLE IF NOT EXISTS market_data (
            id BIGSERIAL PRIMARY KEY,
            symbol TEXT NOT NULL,
            timestamp BIGINT NOT NULL,
            open DOUBLE PRECISION,
            high DOUBLE PRECISION,
            low DOUBLE PRECISION,
            close DOUBLE PRECISION,
            bid DOUBLE PRECISION,
            ask DOUBLE PRECISION
        )"
    )
    .execute(&pool)
    .await
    .expect("Failed to create market_data table");

    // Migration: Add mt4_account and broker to market_data if not exist
    // (Optional, market data often global, but let's support it)
    let _ = sqlx::query("ALTER TABLE market_data ADD COLUMN IF NOT EXISTS mt4_account BIGINT").execute(&pool).await;
    let _ = sqlx::query("ALTER TABLE market_data ADD COLUMN IF NOT EXISTS broker TEXT").execute(&pool).await;

    sqlx::query(
        "CREATE TABLE IF NOT EXISTS account_status (
            id BIGSERIAL PRIMARY KEY,
            balance DOUBLE PRECISION,
            equity DOUBLE PRECISION,
            margin DOUBLE PRECISION,
            free_margin DOUBLE PRECISION,
            floating_profit DOUBLE PRECISION,
            timestamp BIGINT NOT NULL,
            positions_snapshot TEXT
        )"
    )
    .execute(&pool)
    .await
    .expect("Failed to create account_status table");
    
    // Migration: Add mt4_account and broker
    let _ = sqlx::query("ALTER TABLE account_status ADD COLUMN IF NOT EXISTS mt4_account BIGINT").execute(&pool).await;
    let _ = sqlx::query("ALTER TABLE account_status ADD COLUMN IF NOT EXISTS broker TEXT").execute(&pool).await;

    // Migration: Ensure positions_snapshot column exists for existing tables
    let _ = sqlx::query("ALTER TABLE account_status ADD COLUMN IF NOT EXISTS positions_snapshot TEXT")
        .execute(&pool)
        .await;

    // Migration: Add Risk Analysis Fields
    let _ = sqlx::query("ALTER TABLE account_status ADD COLUMN IF NOT EXISTS contract_size DOUBLE PRECISION DEFAULT 100.0").execute(&pool).await;
    let _ = sqlx::query("ALTER TABLE account_status ADD COLUMN IF NOT EXISTS tick_value DOUBLE PRECISION DEFAULT 0.0").execute(&pool).await;
    let _ = sqlx::query("ALTER TABLE account_status ADD COLUMN IF NOT EXISTS stop_level INTEGER DEFAULT 0").execute(&pool).await;
    let _ = sqlx::query("ALTER TABLE account_status ADD COLUMN IF NOT EXISTS margin_so_level DOUBLE PRECISION DEFAULT 0.0").execute(&pool).await;

    sqlx::query(
        "CREATE TABLE IF NOT EXISTS trade_history (
            ticket INTEGER PRIMARY KEY,
            symbol TEXT NOT NULL,
            open_time BIGINT NOT NULL,
            close_time BIGINT NOT NULL,
            open_price DOUBLE PRECISION,
            close_price DOUBLE PRECISION,
            lots DOUBLE PRECISION,
            profit DOUBLE PRECISION,
            trade_type TEXT NOT NULL,
            magic INTEGER
        )"
    )
    .execute(&pool)
    .await
    .expect("Failed to create trade_history table");

    // Migration: Add mt4_account and broker
    let _ = sqlx::query("ALTER TABLE trade_history ADD COLUMN IF NOT EXISTS mt4_account BIGINT").execute(&pool).await;
    let _ = sqlx::query("ALTER TABLE trade_history ADD COLUMN IF NOT EXISTS broker TEXT").execute(&pool).await;

    // Initialize users table
    sqlx::query(
        "CREATE TABLE IF NOT EXISTS users (
            id SERIAL PRIMARY KEY,
            username TEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL,
            role TEXT NOT NULL DEFAULT 'viewer'
        )"
    )
    .execute(&pool)
    .await
    .expect("Failed to create users table");

    // Initialize user_accounts table (Direct binding: User <-> MT4/Broker)
    sqlx::query(
        "CREATE TABLE IF NOT EXISTS user_accounts (
            user_id INTEGER NOT NULL REFERENCES users(id),
            mt4_account BIGINT NOT NULL,
            broker TEXT NOT NULL,
            account_name TEXT,
            permission TEXT DEFAULT 'read_write',
            created_at BIGINT NOT NULL,
            PRIMARY KEY (user_id, mt4_account, broker)
        )"
    )
    .execute(&pool)
    .await
    .expect("Failed to create user_accounts table");

    // Performance Optimization: Indices
    // 1. market_data: used for candles (symbol, timestamp)
    let _ = sqlx::query("CREATE INDEX IF NOT EXISTS idx_market_data_symbol_time ON market_data (symbol, timestamp DESC)").execute(&pool).await;
    
    // 2. account_status: used for equity charts (mt4_account, timestamp)
    let _ = sqlx::query("CREATE INDEX IF NOT EXISTS idx_account_status_account_time ON account_status (mt4_account, timestamp DESC)").execute(&pool).await;

    // 3. trade_history: used for analysis (mt4_account, close_time) and (mt4_account, symbol)
    let _ = sqlx::query("CREATE INDEX IF NOT EXISTS idx_trade_history_account_close ON trade_history (mt4_account, close_time DESC)").execute(&pool).await;
    let _ = sqlx::query("CREATE INDEX IF NOT EXISTS idx_trade_history_account_symbol ON trade_history (mt4_account, symbol)").execute(&pool).await;

    // ========== Smart Exit System Migrations ==========
    // 1. Add tick_volume to market_data for RVOL calculation
    let _ = sqlx::query("ALTER TABLE market_data ADD COLUMN IF NOT EXISTS tick_volume BIGINT DEFAULT 0").execute(&pool).await;

    // 2. Create price_velocity table for real-time momentum tracking
    sqlx::query(
        "CREATE TABLE IF NOT EXISTS price_velocity (
            id BIGSERIAL PRIMARY KEY,
            symbol TEXT NOT NULL,
            timestamp BIGINT NOT NULL,
            price_1m_ago DOUBLE PRECISION,
            velocity_m1 DOUBLE PRECISION,
            avg_tick_volume_24h DOUBLE PRECISION,
            current_tick_volume BIGINT,
            rvol DOUBLE PRECISION
        )"
    )
    .execute(&pool)
    .await
    .expect("Failed to create price_velocity table");

    let _ = sqlx::query("CREATE INDEX IF NOT EXISTS idx_velocity_symbol_time ON price_velocity (symbol, timestamp DESC)").execute(&pool).await;

    // 3. Add feature engineering fields to trade_history for ML optimization
    let _ = sqlx::query("ALTER TABLE trade_history ADD COLUMN IF NOT EXISTS liq_dist_at_open DOUBLE PRECISION").execute(&pool).await;
    let _ = sqlx::query("ALTER TABLE trade_history ADD COLUMN IF NOT EXISTS max_v_m1 DOUBLE PRECISION").execute(&pool).await;
    let _ = sqlx::query("ALTER TABLE trade_history ADD COLUMN IF NOT EXISTS rvol_at_open DOUBLE PRECISION").execute(&pool).await;
    let _ = sqlx::query("ALTER TABLE trade_history ADD COLUMN IF NOT EXISTS score_at_close DOUBLE PRECISION").execute(&pool).await;

    // Start HTTP server for MT4 data ingestion
    ipc::http_server::start_server(pool).await;
}
