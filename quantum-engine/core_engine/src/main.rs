mod config;
mod connectors;
mod oms;
mod strategy;
mod risk;
mod ipc;
mod data_models;

#[tokio::main]
async fn main() {
    // Initialize logging
    tracing_subscriber::fmt::init();

    tracing::info!("core_engine bootstrapping...");

    // Start HTTP server for MT4 data ingestion
    ipc::http_server::start_server().await;
}
