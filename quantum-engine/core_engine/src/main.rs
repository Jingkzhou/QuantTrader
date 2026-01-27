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

    // Start HTTP server for MT4 data ingestion
    ipc::http_server::start_server(pool).await;
}
