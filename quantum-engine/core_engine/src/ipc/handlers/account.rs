use axum::{extract::State, Json};
use std::sync::Arc;
use chrono::Datelike;
use crate::ipc::state::{CombinedState, Claims};
use crate::data_models::{AccountRecord, BindAccountRequest, AccountStatus, RiskControlState};
use crate::ipc::ea_metrics::{types::MetricsInput, calculator::calculate_ea_alert_metrics};

pub async fn list_accounts(
    State(state): State<Arc<CombinedState>>,
    claims: Claims,
) -> Result<Json<Vec<AccountRecord>>, (axum::http::StatusCode, String)> {
    let accounts = sqlx::query_as!(
        crate::data_models::AccountRecord,
        "SELECT mt4_account, broker, account_name FROM user_accounts WHERE user_id = $1",
        claims.user_id
    )
    .fetch_all(&state.db)
    .await
    .map_err(|e: sqlx::Error| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(accounts))
}

pub async fn bind_account(
    State(state): State<Arc<CombinedState>>,
    claims: Claims,
    Json(payload): Json<BindAccountRequest>,
) -> Result<Json<AccountRecord>, (axum::http::StatusCode, String)> {
    // Upsert binding in user_accounts
    sqlx::query!(
        "INSERT INTO user_accounts (user_id, mt4_account, broker, account_name, created_at) 
         VALUES ($1, $2, $3, $4, $5)
         ON CONFLICT (user_id, mt4_account, broker) 
         DO UPDATE SET account_name = $4",
        claims.user_id, 
        payload.mt4_account, 
        payload.broker, 
        payload.account_name,
        chrono::Utc::now().timestamp()
    )
    .execute(&state.db)
    .await
    .map_err(|e: sqlx::Error| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(AccountRecord {
        mt4_account: payload.mt4_account,
        broker: payload.broker,
        account_name: payload.account_name,
    }))
}

pub async fn unbind_account(
    State(state): State<Arc<CombinedState>>,
    claims: Claims,
    Json(payload): Json<BindAccountRequest>, // Reusing the same struct for simplicity
) -> Result<axum::http::StatusCode, (axum::http::StatusCode, String)> {
    sqlx::query!(
        "DELETE FROM user_accounts WHERE user_id = $1 AND mt4_account = $2 AND broker = $3",
        claims.user_id,
        payload.mt4_account,
        payload.broker
    )
    .execute(&state.db)
    .await
    .map_err(|e: sqlx::Error| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(axum::http::StatusCode::OK)
}

pub async fn handle_account_status(State(state): State<Arc<CombinedState>>, Json(payload): Json<AccountStatus>) {
    let symbols: Vec<String> = payload.positions.iter().map(|p| p.symbol.clone()).collect();
    tracing::info!("Account Status Update: Equity:{} Acc:{} Broker:{} Symbols:{:?}", payload.equity, payload.mt4_account, payload.broker, symbols);
    
    // Update Memory
    {
        let mut s = state.memory.write().unwrap();
        let key = format!("{}:{}", payload.mt4_account, payload.broker);
        let status = s.account_statuses.entry(key).or_insert_with(AccountStatus::default);
        
        status.balance = payload.balance;
        status.equity = payload.equity;
        status.margin = payload.margin;
        status.free_margin = payload.free_margin;
        status.floating_profit = payload.floating_profit;
        status.timestamp = payload.timestamp;
        status.positions = payload.positions.clone();
        status.mt4_account = payload.mt4_account;
        status.broker = payload.broker.clone();
        status.contract_size = payload.contract_size;
        status.tick_value = payload.tick_value;
        status.stop_level = payload.stop_level;
        status.margin_so_level = payload.margin_so_level;
    }

    let positions_json = serde_json::to_string(&payload.positions).unwrap_or_default();
    let timestamp = if payload.timestamp > 0 { payload.timestamp } else { chrono::Utc::now().timestamp() };

    // Filter Weekend Data (Professional Standard)
    let dt = chrono::DateTime::from_timestamp(timestamp as i64, 0).unwrap_or_default();
    let weekday = dt.weekday();
    if weekday == chrono::Weekday::Sat || weekday == chrono::Weekday::Sun {
        // tracing::warn!("Skipping weekend account status persistence for account: {}", payload.mt4_account);
        return;
    }

    let res = sqlx::query(
        "INSERT INTO account_status (balance, equity, margin, free_margin, floating_profit, timestamp, positions_snapshot, mt4_account, broker, contract_size, tick_value, stop_level, margin_so_level) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)"
    )
    .bind(payload.balance)
    .bind(payload.equity)
    .bind(payload.margin)
    .bind(payload.free_margin)
    .bind(payload.floating_profit)
    .bind(timestamp as i64)
    .bind(positions_json)
    .bind(payload.mt4_account)
    .bind(&payload.broker)
    .bind(payload.contract_size)
    .bind(payload.tick_value)
    .bind(payload.stop_level)
    .bind(payload.margin_so_level)
    .execute(&state.db)
    .await;

    if let Err(e) = res {
        tracing::error!("DB Error (account): {}", e);
    }

    // ======== 🆕 Auto Risk Calculation (Backend Enforced V2) ========
    // 1. Identify Main Symbol
    let main_symbol = payload.positions.first().map(|p| p.symbol.clone()).unwrap_or("XAUUSD".to_string());
    
    // 2. Identify Current Price (Bid/Ask)
    let (current_bid, current_ask) = {
        let mem = state.memory.read().unwrap();
        mem.market_data.get(&main_symbol)
            .map(|m| (m.bid, m.ask))
            .unwrap_or((0.0, 0.0))
    };

    let input = MetricsInput {
        equity: payload.equity,
        margin: payload.margin,
        margin_so_level: payload.margin_so_level,
        positions: payload.positions.clone(),
        symbol: main_symbol,
        current_bid,
        current_ask,
        balance: payload.balance,
        contract_size: payload.contract_size,
    };

    let metrics = calculate_ea_alert_metrics(&state, input).await;

    // 7. Extract Values for Control
    let (risk_score, exit_trigger, fingerprint_enabled) = {
        let mem = state.memory.read().unwrap();
        let control = mem.risk_controls.get(&payload.mt4_account);
        (
            metrics.risk_score,
            metrics.exit_trigger.clone(),
            control.map(|c| c.fingerprint_enabled).unwrap_or(true)
        )
    };

    let risk_level_str = if risk_score >= 80.0 { "CRITICAL" } 
        else if risk_score >= 60.0 { "WARNING" } 
        else { "SAFE" };
    
    tracing::info!("Account {} Metrics: Score={:.1} Dist={:.1} VelM1={:.2} RVOL={:.2} Liq={:.2}", 
        payload.mt4_account, risk_score, metrics.survival_distance, metrics.velocity_m1, metrics.rvol, metrics.liquidation_price);

    // 8. Determine Block Directives
    let (mut block_buy, mut block_sell, block_all) = match exit_trigger.as_str() {
        "FORCE_EXIT" | "TACTICAL_EXIT" => (true, true, true),
        "LAYER_LOCK" => (true, true, false), 
        _ => (false, false, false),
    };
    
    // RSI Entry Fingerprint Control
    if fingerprint_enabled {
        if metrics.rsi_14 >= 70.0 {
            block_buy = true; // Forbid Buy (Overbought)
        } else if metrics.rsi_14 <= 30.0 {
            block_sell = true; // Forbid Sell (Oversold)
        }
    }
    
    let smart_exit_metrics = crate::data_models::SmartExitMetrics {
        survival_distance: metrics.survival_distance,
        liquidation_price: metrics.liquidation_price,
        velocity_m1: metrics.velocity_m1,
        rvol: metrics.rvol,
        risk_score: metrics.risk_score,
        distance_score: metrics.distance_score,
        velocity_score: metrics.velocity_score,
        layer_score: metrics.layer_score,
        drawdown_score: metrics.drawdown_score,
        exit_trigger: metrics.exit_trigger.clone(),
        trigger_reason: metrics.trigger_reason.clone(),
        is_velocity_warning: metrics.is_velocity_warning,
        is_rvol_warning: metrics.is_rvol_warning,
        is_martingale_pattern: false, 
        martingale_warning: String::new(),
        rsi_14: metrics.rsi_14,
        rsi_signal: metrics.rsi_signal.clone(),
    };

    {
        let mut mem = state.memory.write().unwrap();
        mem.risk_details.insert(payload.mt4_account, smart_exit_metrics);
    }
    
    // 4. Auto-Update Risk Controls
    let now_ts = chrono::Utc::now().timestamp();
    
    let update_res = sqlx::query(
        "INSERT INTO risk_controls (mt4_account, block_buy, block_sell, block_all, risk_level, updated_at, velocity_block, enabled, risk_score, exit_trigger, fingerprint_enabled)
         VALUES ($1, $2, $3, $4, $5, $6, false, false, $7, $8, true)
         ON CONFLICT (mt4_account) DO UPDATE SET 
            block_buy = CASE WHEN risk_controls.enabled = true THEN $2 ELSE risk_controls.block_buy END, 
            block_sell = CASE WHEN risk_controls.enabled = true THEN $3 ELSE risk_controls.block_sell END,
            block_all = CASE WHEN risk_controls.enabled = true THEN $4 ELSE risk_controls.block_all END,
            exit_trigger = CASE WHEN risk_controls.enabled = true THEN $8 ELSE risk_controls.exit_trigger END,
            risk_score = $7, 
            risk_level = $5, 
            updated_at = $6"
    )
    .bind(payload.mt4_account)
    .bind(block_buy)
    .bind(block_sell)
    .bind(block_all)
    .bind(risk_level_str)
    .bind(now_ts)
    .bind(risk_score)
    .bind(&exit_trigger)
    .execute(&state.db)
    .await;

    if let Err(e) = update_res {
        tracing::error!("Failed to auto-update risk controls: {}", e);
    }
    
    // 🔴 CRITICAL: Also update memory state and detect changes for logging
    let log_event = {
        let mut s = state.memory.write().unwrap();
        let existing = s.risk_controls.get(&payload.mt4_account).cloned();
        
        let was_enabled = existing.as_ref().map(|e| e.enabled).unwrap_or(false);
        let old_trigger = existing.as_ref().map(|e| e.exit_trigger.clone()).unwrap_or_else(|| "NONE".to_string());
        
        // Calculate effective values considering 'enabled' flag
        let new_trigger = if was_enabled { exit_trigger.clone() } else { old_trigger.clone() };
        let new_block_buy = if was_enabled { block_buy } else { existing.as_ref().map(|e| e.block_buy).unwrap_or(false) };
        let new_block_sell = if was_enabled { block_sell } else { existing.as_ref().map(|e| e.block_sell).unwrap_or(false) };
        let new_block_all = if was_enabled { block_all } else { existing.as_ref().map(|e| e.block_all).unwrap_or(false) };

        // Logic: Log if trigger changed (Only if enabled)
        let mut event = None;
        if was_enabled {
            let old_block_buy = existing.as_ref().map(|e| e.block_buy).unwrap_or(false);
            let old_block_sell = existing.as_ref().map(|e| e.block_sell).unwrap_or(false);

            if new_trigger != old_trigger {
                if new_trigger != "NONE" {
                   let t_cn = match new_trigger.as_str() {
                       "FORCE_EXIT" => "紧急逃生",
                       "TACTICAL_EXIT" => "战术减仓",
                       "LAYER_LOCK" => "层级锁",
                       _ => new_trigger.as_str(),
                   };
                   event = Some(format!("自动: 触发 {}", t_cn));
                   
                   // [NEW] Hard Cut: Inject CLOSE_ALL Command if FORCE_EXIT is triggered
                   if new_trigger == "FORCE_EXIT" {
                       let cmd = crate::data_models::Command {
                           id: format!("auto_{}", now_ts),
                           action: "CLOSE_ALL".to_string(),
                           symbol: "XAUUSD".to_string(), // Default or detect from payload?
                           lots: 0.0, // Not applicable for CLOSE_ALL
                           status: "PENDING".to_string(),
                           timestamp: now_ts,
                           mt4_account: payload.mt4_account,
                           broker: payload.broker.clone(),
                       };
                       
                       let cmd_key = format!("{}:{}", payload.mt4_account, payload.broker);
                       s.pending_commands.entry(cmd_key).or_default().push(cmd);
                       tracing::warn!("🚨 HARD CUT TRIGGERED: Injecting CLOSE_ALL command for Account {}", payload.mt4_account);
                   }

                } else {
                   event = Some("自动: 风险解除".to_string());
                }
            } else if new_block_buy != old_block_buy {
                event = Some(format!("风控: {}买入", if new_block_buy { "禁止" } else { "恢复" }));
            } else if new_block_sell != old_block_sell {
                event = Some(format!("风控: {}卖出", if new_block_sell { "禁止" } else { "恢复" }));
            }
        }

        let risk_state = RiskControlState {
            mt4_account: payload.mt4_account,
            block_buy: new_block_buy,
            block_sell: new_block_sell,
            block_all: new_block_all,
            risk_level: risk_level_str.to_string(),
            updated_at: now_ts,
            risk_score,
            exit_trigger: new_trigger,
            velocity_block: existing.as_ref().map(|e| e.velocity_block).unwrap_or(false),
            enabled: was_enabled,
            fingerprint_enabled,
        };
        s.risk_controls.insert(payload.mt4_account, risk_state);
        event
    };

    // Write log if event occurred (Outside of lock)
    if let Some(action_msg) = log_event {
         let _ = sqlx::query("INSERT INTO risk_control_logs (mt4_account, action, risk_level, risk_score, exit_trigger, created_at) VALUES ($1, $2, $3, $4, $5, $6)")
            .bind(payload.mt4_account)
            .bind(action_msg)
            .bind(risk_level_str)
            .bind(risk_score)
            .bind(&exit_trigger) 
            .bind(now_ts)
            .execute(&state.db)
            .await;
    }

    let margin_level = if payload.margin > 0.0 {
        payload.margin_level
    } else {
        0.0
    };
    
    if risk_score >= 60.0 {
        tracing::warn!("⚠️ Auto Risk Alert: Account {} Score={:.1} DD={:.1}% ML={:.0}% Trigger={}", 
            payload.mt4_account, risk_score, metrics.drawdown, margin_level, exit_trigger);
    }
}
