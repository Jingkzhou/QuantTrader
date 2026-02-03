use axum::{extract::State, Json};
use std::sync::Arc;
use std::collections::HashMap;
use sqlx::Row;
use crate::ipc::state::{CombinedState, Claims, AppState};
use crate::data_models::LogEntry;

pub async fn get_state(
    State(state): State<Arc<CombinedState>>,
    claims: Claims,
    axum::extract::Query(params): axum::extract::Query<HashMap<String, String>>,
) -> Result<Json<AppState>, (axum::http::StatusCode, String)> {
    let mt4_account = params.get("mt4_account").and_then(|id| id.parse::<i64>().ok());

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

pub async fn handle_logs(State(state): State<Arc<CombinedState>>, Json(payload): Json<LogEntry>) {
    tracing::info!("Log [{}]: {}", payload.level, payload.message);
    
    let key = format!("{}:{}", payload.mt4_account, payload.broker);
    let mut s = state.memory.write().unwrap();
    let logs = s.recent_logs.entry(key).or_insert_with(Vec::new);
    logs.insert(0, payload);
    if logs.len() > 100 {
        logs.truncate(100);
    }
}
