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
            timestamp BIGINT NOT NULL
        )"
    )
    .execute(&pool)
    .await
    .expect("Failed to create account_status table");

    // Start HTTP server for MT4 data ingestion
    ipc::http_server::start_server(pool).await;
}
