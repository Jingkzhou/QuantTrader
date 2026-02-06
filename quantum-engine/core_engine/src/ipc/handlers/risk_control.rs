use axum::{extract::State, Json, response::IntoResponse};
use std::sync::Arc;
use std::collections::HashMap;
use serde::Serialize;
use crate::ipc::state::{CombinedState, Claims};
use crate::data_models::{RiskControlState, SmartExitMetrics};

#[derive(Serialize)]
pub struct RiskControlResponse {
    #[serde(flatten)]
    pub state: RiskControlState,
    #[serde(default)]
    pub metrics: Option<SmartExitMetrics>,
}

#[derive(Debug, serde::Serialize, serde::Deserialize, sqlx::FromRow)]
pub struct RiskControlLog {
    pub id: i64,
    pub mt4_account: i64, 
    pub action: String,
    pub risk_level: Option<String>,
    pub risk_score: Option<f64>,
    pub exit_trigger: Option<String>,
    pub created_at: i64,
    // Snapshot Data
    pub balance: Option<f64>,
    pub equity: Option<f64>,
    pub margin: Option<f64>,
    pub free_margin: Option<f64>,
    pub floating_profit: Option<f64>,
    pub drawdown_pct: Option<f64>,
    pub survival_distance: Option<f64>,
    pub velocity_m1: Option<f64>,
    pub rvol: Option<f64>,
    pub positions_snapshot: Option<String>,
    pub trigger_reason: Option<String>,
}

pub async fn get_risk_control(
    State(state): State<Arc<CombinedState>>,
    axum::extract::Query(params): axum::extract::Query<HashMap<String, String>>,
) -> axum::response::Response {
    let mt4_account = match params.get("mt4_account").and_then(|id| id.parse::<i64>().ok()) {
        Some(id) => id,
        None => return (axum::http::StatusCode::BAD_REQUEST, "Missing mt4_account").into_response(),
    };

    let s = state.memory.read().unwrap();
    
    // Return existing state or default (safe) state
    let control = s.risk_controls.get(&mt4_account).cloned().unwrap_or_else(|| RiskControlState {
        mt4_account,
        block_buy: false,
        block_sell: false,
        block_all: false,
        risk_level: "SAFE".to_string(),
        updated_at: chrono::Utc::now().timestamp(),
        risk_score: 0.0,
        exit_trigger: "NONE".to_string(),
        velocity_block: false,
        enabled: false,
    });

    let metrics = s.risk_details.get(&mt4_account).cloned();

    Json(RiskControlResponse {
        state: control,
        metrics,
    }).into_response()
}

pub async fn update_risk_control(
    State(state): State<Arc<CombinedState>>,
    claims: Claims,
    Json(payload): Json<RiskControlState>,
) -> axum::response::Response {
    // Verify ownership
    let check_res = sqlx::query(
        "SELECT 1 FROM user_accounts WHERE user_id = $1 AND mt4_account = $2"
    )
    .bind(claims.user_id)
    .bind(payload.mt4_account)
    .fetch_optional(&state.db)
    .await;

    let check = match check_res {
        Ok(c) => c,
        Err(e) => return (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()).into_response(),
    };

    if check.is_none() {
        return (axum::http::StatusCode::FORBIDDEN, "Access denied").into_response();
    }

    let mut updated_payload = payload.clone();
    updated_payload.updated_at = chrono::Utc::now().timestamp();

    // Persist to DB first (outside of lock)
    let db_res = sqlx::query(
        "INSERT INTO risk_controls (mt4_account, block_buy, block_sell, block_all, risk_level, updated_at, risk_score, exit_trigger, velocity_block, enabled)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
         ON CONFLICT (mt4_account) DO UPDATE SET
            block_buy = $2,
            block_sell = $3,
            block_all = $4,
            risk_level = $5,
            updated_at = $6,
            risk_score = $7,
            exit_trigger = $8,
            velocity_block = $9,
            enabled = $10"
    )
    .bind(updated_payload.mt4_account)
    .bind(updated_payload.block_buy)
    .bind(updated_payload.block_sell)
    .bind(updated_payload.block_all)
    .bind(&updated_payload.risk_level)
    .bind(updated_payload.updated_at)
    .bind(updated_payload.risk_score)
    .bind(&updated_payload.exit_trigger)
    .bind(updated_payload.velocity_block)
    .bind(updated_payload.enabled)
    .execute(&state.db)
    .await;

    if let Err(e) = db_res {
        tracing::error!("Failed to persist risk control: {}", e);
    }

    // Update memory state (short lock, no await inside)
    {
        let mut s = state.memory.write().unwrap();
        s.risk_controls.insert(payload.mt4_account, updated_payload.clone());
    }

    tracing::info!("Risk Control Updated for Account {}: Enabled={} Level={} BlockBuy={} BlockSell={}", 
        payload.mt4_account, payload.enabled, payload.risk_level, payload.block_buy, payload.block_sell);

    // Insert operation log ONLY when directives change or system starts
    // Retrieve Account Snapshot for logging
    let account_snapshot = {
        let s = state.memory.read().unwrap();
        s.account_states.get(&payload.mt4_account).cloned()
    };

    let metrics_snapshot = {
        let s = state.memory.read().unwrap();
        s.risk_details.get(&payload.mt4_account).cloned()
    };

    // Helper to calculate drawdown
    let drawdown = if let Some(acc) = &account_snapshot {
        if let (Some(bal), Some(eq)) = (acc.balance, acc.equity) {
            if bal > 0.0 { ((bal - eq) / bal * 100.0).max(0.0) } else { 0.0 }
        } else { 0.0 }
    } else { 0.0 };

    let (surv, vel, rvol_val) = if let Some(m) = &metrics_snapshot {
        (Some(m.survival_distance), Some(m.velocity_m1), Some(m.rvol))
    } else {
        (None, None, None)
    };

    let pos_snap = if let Some(acc) = &account_snapshot {
        acc.positions.as_ref().map(|p| serde_json::to_string(p).unwrap_or_default())
    } else { None };

    let (bal, eq, mar, fm, fp) = if let Some(acc) = &account_snapshot {
        (acc.balance, acc.equity, acc.margin, acc.free_margin, acc.floating_profit)
    } else {
        (None, None, None, None, None)
    };

    // Get previous state to compare
    let prev_state = {
        let s = state.memory.read().unwrap();
        s.risk_controls.get(&payload.mt4_account).cloned()
    };

    let now = chrono::Utc::now().timestamp();
    
    // Common Insert Query
    // We use a macro-like approach or just repeat the query builder since we have many branches
    let insert_log = |action: &str, trigger: &str, reason: Option<&String>| {
        let trig_reason = reason.cloned().or(metrics_snapshot.as_ref().map(|m| m.trigger_reason.clone()));
        
        // Use sqlx::query directly
        let sql = "INSERT INTO risk_control_logs 
            (mt4_account, action, risk_level, risk_score, exit_trigger, created_at, 
             balance, equity, margin, free_margin, floating_profit, drawdown_pct,
             survival_distance, velocity_m1, rvol, positions_snapshot, trigger_reason) 
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)";
        
        sqlx::query(sql)
            .bind(payload.mt4_account)
            .bind(action)
            .bind(&payload.risk_level)
            .bind(payload.risk_score)
            .bind(trigger)
            .bind(now)
            .bind(bal).bind(eq).bind(mar).bind(fm).bind(fp).bind(drawdown)
            .bind(surv).bind(vel).bind(rvol_val).bind(pos_snap.clone()).bind(trig_reason)
    };


    if let Some(prev) = &prev_state {
        // Each directive change gets its own log entry
        if !prev.block_buy && payload.block_buy {
            let _ = insert_log("禁止做多", &payload.exit_trigger, None).execute(&state.db).await;
        }
        if prev.block_buy && !payload.block_buy {
            let _ = insert_log("允许做多", &payload.exit_trigger, None).execute(&state.db).await;
        }
        if !prev.block_sell && payload.block_sell {
             let _ = insert_log("禁止做空", &payload.exit_trigger, None).execute(&state.db).await;
        }
        if prev.block_sell && !payload.block_sell {
             let _ = insert_log("允许做空", &payload.exit_trigger, None).execute(&state.db).await;
        }
        if !prev.block_all && payload.block_all {
             let _ = insert_log("全部禁止", &payload.exit_trigger, None).execute(&state.db).await;
        }
        if prev.block_all && !payload.block_all {
             let _ = insert_log("解除全禁", &payload.exit_trigger, None).execute(&state.db).await;
        }
        if prev.exit_trigger != payload.exit_trigger && payload.exit_trigger != "NONE" {
            let trigger_action = match payload.exit_trigger.as_str() {
                "FORCE_EXIT" => "强制退出",
                "TACTICAL_EXIT" => "战术退出",
                "LAYER_LOCK" => "锁定加仓",
                _ => "触发变更"
            };
            let _ = insert_log(trigger_action, &payload.exit_trigger, None).execute(&state.db).await;
        }
    } else if payload.enabled {
        // First time activation
        let _ = insert_log("系统启动", &payload.exit_trigger, None).execute(&state.db).await;
    }

    Json(updated_payload).into_response()
}

pub async fn get_risk_control_logs(
    State(state): State<Arc<CombinedState>>,
    claims: Claims,
    axum::extract::Query(params): axum::extract::Query<HashMap<String, String>>,
) -> Result<Json<Vec<RiskControlLog>>, (axum::http::StatusCode, String)> {
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

    let limit = params.get("limit").and_then(|l| l.parse::<i64>().ok()).unwrap_or(20);

    let logs = sqlx::query_as::<_, RiskControlLog>(
        "SELECT id, mt4_account, action, risk_level, risk_score, exit_trigger, created_at,
                balance, equity, margin, free_margin, floating_profit, drawdown_pct,
                survival_distance, velocity_m1, rvol, positions_snapshot, trigger_reason
         FROM risk_control_logs 
         WHERE mt4_account = $1 
         ORDER BY created_at DESC 
         LIMIT $2"
    )
    .bind(mt4_account)
    .bind(limit)
    .fetch_all(&state.db)
    .await
    .map_err(|e| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(logs))
}
