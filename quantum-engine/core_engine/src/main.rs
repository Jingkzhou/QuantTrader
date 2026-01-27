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

    // Initialize accounts table
    sqlx::query(
        "CREATE TABLE IF NOT EXISTS accounts (
            id SERIAL PRIMARY KEY,
            owner_id INTEGER, -- Deprecated in favor of user_accounts, but kept for compatibility during migration
            mt4_account_number BIGINT NOT NULL,
            broker_name TEXT NOT NULL,
            account_name TEXT,
            is_active BOOLEAN DEFAULT TRUE,
            UNIQUE(mt4_account_number, broker_name)
        )"
    )
    .execute(&pool)
    .await
    .expect("Failed to create accounts table");

    // Initialize user_accounts table (Many-to-Many)
    sqlx::query(
        "CREATE TABLE IF NOT EXISTS user_accounts (
            user_id INTEGER NOT NULL REFERENCES users(id),
            account_id INTEGER NOT NULL REFERENCES accounts(id),
            permission TEXT DEFAULT 'read_write',
            created_at BIGINT NOT NULL,
            PRIMARY KEY (user_id, account_id)
        )"
    )
    .execute(&pool)
    .await
    .expect("Failed to create user_accounts table");

    // Start HTTP server for MT4 data ingestion
    ipc::http_server::start_server(pool).await;
}
