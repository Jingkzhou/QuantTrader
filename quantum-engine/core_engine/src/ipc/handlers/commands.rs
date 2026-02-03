use axum::{extract::State, Json};
use std::sync::Arc;
use std::collections::HashMap;
use crate::ipc::state::{CombinedState, Claims};
use crate::data_models::Command;

pub async fn handle_command(State(state): State<Arc<CombinedState>>, Json(payload): Json<Command>) {
    tracing::info!("Received Command: {:?} on {}", payload.action, payload.symbol);
    
    // Add to pending queue (in-memory simple queue)
    {
        let mut s = state.memory.write().unwrap();
        let key = format!("{}:{}", payload.mt4_account, payload.broker);
        s.pending_commands.entry(key).or_insert_with(Vec::new).push(payload);
    }
}

pub async fn get_commands(
    State(state): State<Arc<CombinedState>>,
    claims: Claims,
    axum::extract::Query(params): axum::extract::Query<HashMap<String, String>>,
) -> Result<Json<Vec<Command>>, (axum::http::StatusCode, String)> {
    let mt4_account = params.get("mt4_account").and_then(|id| id.parse::<i64>().ok())
        .ok_or((axum::http::StatusCode::BAD_REQUEST, "Missing mt4_account".to_string()))?;
    // Verify ownership
    let _ = sqlx::query!(
        "SELECT 1 as \"exists!\" FROM user_accounts WHERE user_id = $1 AND mt4_account = $2",
        claims.user_id, mt4_account
    )
    .fetch_optional(&state.db)
    .await
    .map_err(|e: sqlx::Error| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
    .ok_or((axum::http::StatusCode::FORBIDDEN, "Access denied".to_string()))?;

    let mut s = state.memory.write().unwrap();
    // Similar to logs, we need to find the command queue for this account
    // Since broker is part of key, we iterate.
    let mut found_commands = Vec::new();
    let mut key_to_remove = None;
    
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
    
    Ok(Json(found_commands))
}
