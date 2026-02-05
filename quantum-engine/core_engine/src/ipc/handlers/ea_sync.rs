use axum::{extract::State, Json};
use std::sync::Arc;
use std::collections::HashMap;
use crate::ipc::state::{CombinedState, Claims};
use crate::data_models::{EASyncResponse, VelocityData, RiskControlState};
use sqlx::Row;

// Unified EA Sync Handler
pub async fn handle_ea_sync(
    State(state): State<Arc<CombinedState>>,
    axum::extract::Query(params): axum::extract::Query<HashMap<String, String>>,
) -> Result<Json<EASyncResponse>, (axum::http::StatusCode, String)> {
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

    Ok(Json(EASyncResponse {
        commands,
        risk_control,
    }))
}

/// Get velocity data for smart exit calculations
/// Calculates 1-min price velocity and relative volume vs 24h average
pub async fn get_velocity(
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
