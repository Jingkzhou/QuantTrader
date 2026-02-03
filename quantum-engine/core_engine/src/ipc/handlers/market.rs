use axum::{extract::State, Json};
use std::sync::Arc;
use chrono::Datelike;
use crate::ipc::state::CombinedState;
use crate::data_models::MarketData;

pub async fn handle_market_data(State(state): State<Arc<CombinedState>>, Json(payload): Json<MarketData>) {
    process_market_data(&state, payload).await;
}

pub async fn handle_market_data_batch(State(state): State<Arc<CombinedState>>, Json(payload): Json<Vec<MarketData>>) {
    // tracing::info!("Received batch of {} market data points", payload.len());
    for data in payload {
        process_market_data(&state, data).await;
    }
}

pub async fn process_market_data(state: &Arc<CombinedState>, payload: MarketData) {
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
