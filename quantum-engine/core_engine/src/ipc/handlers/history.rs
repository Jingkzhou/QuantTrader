use axum::{extract::State, Json};
use std::sync::Arc;
use std::collections::HashMap;
use serde::Serialize;
use crate::ipc::state::{CombinedState, Claims};
use crate::data_models::{AccountHistory, TradeHistory};

// Pagination Response Structure
#[derive(Serialize)]
pub struct TradeHistoryResponse {
    pub data: Vec<TradeHistory>,
    pub total: i64,
    pub page: i64,
    pub limit: i64,
}

pub async fn get_account_history(
    State(state): State<Arc<CombinedState>>,
    claims: Claims,
    axum::extract::Query(params): axum::extract::Query<HashMap<String, String>>,
) -> Result<Json<Vec<AccountHistory>>, (axum::http::StatusCode, String)> {
    let mt4_account = params.get("mt4_account").and_then(|id| id.parse::<i64>().ok())
        .ok_or((axum::http::StatusCode::BAD_REQUEST, "Missing mt4_account".to_string()))?;
    // Verify ownership
    let _ = sqlx::query!(
        "SELECT 1 as \"exists!\" FROM user_accounts WHERE user_id = $1 AND mt4_account = $2",
        claims.user_id, mt4_account
    )
    .fetch_optional(&state.db)
    .await
    .map_err(|e| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
    .ok_or((axum::http::StatusCode::FORBIDDEN, "Access denied".to_string()))?;

    let limit = params.get("limit").and_then(|s| s.parse::<i64>().ok()).unwrap_or(200);
    
    let history = sqlx::query_as!(
        AccountHistory,
        "SELECT timestamp, COALESCE(balance, 0.0) as \"balance!\", COALESCE(equity, 0.0) as \"equity!\", mt4_account as \"mt4_account!\", broker as \"broker!\" FROM account_status WHERE mt4_account = $1 ORDER BY timestamp DESC LIMIT $2",
        mt4_account, limit
    )
    .fetch_all(&state.db)
    .await
    .unwrap_or_default();

    let mut asc_history = history;
    asc_history.reverse();

    Ok(Json(asc_history))
}

pub async fn handle_trade_history(State(state): State<Arc<CombinedState>>, Json(payload): Json<Vec<TradeHistory>>) {
    tracing::info!("Received {} trade history records", payload.len());

    for trade in payload {
        let res = sqlx::query(
            "INSERT INTO trade_history (ticket, symbol, open_time, close_time, open_price, close_price, lots, profit, trade_type, magic, mae, mfe, signal_context, mt4_account, broker) 
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
             ON CONFLICT (ticket) DO UPDATE SET 
                mae = CASE WHEN trade_history.mfe < $12 THEN $11 ELSE trade_history.mae END,
                mfe = CASE WHEN trade_history.mfe < $12 THEN $12 ELSE trade_history.mfe END,
                signal_context = COALESCE(trade_history.signal_context, $13),
                mt4_account = $14,
                broker = $15"
        )
        .bind(trade.ticket)
        .bind(&trade.symbol)
        .bind(trade.open_time as i64)
        .bind(trade.close_time as i64)
        .bind(trade.open_price)
        .bind(trade.close_price)
        .bind(trade.lots)
        .bind(trade.profit)
        .bind(&trade.trade_type)
        .bind(trade.magic)
        .bind(trade.mae)
        .bind(trade.mfe)
        .bind(&trade.signal_context)
        .bind(trade.mt4_account)
        .bind(&trade.broker)
        .execute(&state.db)
        .await;

        if let Err(e) = res {
            tracing::error!("DB Error (history): {}", e);
        }
    }
}

pub async fn get_trade_history(
    State(state): State<Arc<CombinedState>>,
    claims: Claims,
    axum::extract::Query(params): axum::extract::Query<HashMap<String, String>>,
) -> Result<Json<TradeHistoryResponse>, (axum::http::StatusCode, String)> {
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

    // Parse pagination params
    let page = params.get("page").and_then(|p| p.parse::<i64>().ok()).unwrap_or(1);
    let limit = params.get("limit").and_then(|l| l.parse::<i64>().ok()).unwrap_or(100);
    let offset = (page - 1) * limit;
    let symbol = params.get("symbol").cloned();

    // Get Total Count and Data with optional symbol filtering
    let (total, trades) = if let Some(ref sym) = symbol {
        let total_record = sqlx::query!(
            "SELECT count(*) as count FROM trade_history WHERE mt4_account = $1 AND symbol = $2",
            mt4_account, sym
        )
        .fetch_one(&state.db)
        .await
        .map_err(|e| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

        let trades = sqlx::query_as!(
            TradeHistory,
            r#"
            SELECT 
                ticket as "ticket!", 
                symbol as "symbol!", 
                open_time as "open_time!", 
                close_time as "close_time!", 
                COALESCE(open_price, 0.0) as "open_price!", 
                COALESCE(close_price, 0.0) as "close_price!", 
                COALESCE(lots, 0.0) as "lots!", 
                COALESCE(profit, 0.0) as "profit!", 
                trade_type as "trade_type!", 
                COALESCE(magic, 0) as "magic!", 
                COALESCE(mae, 0.0) as "mae!", 
                COALESCE(mfe, 0.0) as "mfe!", 
                signal_context, 
                mt4_account as "mt4_account!", 
                broker as "broker!" 
            FROM trade_history 
            WHERE mt4_account = $1 AND symbol = $2
            ORDER BY close_time DESC 
            LIMIT $3 OFFSET $4
            "#,
            mt4_account, sym, limit, offset
        )
        .fetch_all(&state.db)
        .await
        .map_err(|e| {
            tracing::error!("DB Error trade_history: {}", e);
            (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string())
        })?;
        (total_record.count.unwrap_or(0), trades)
    } else {
        let total_record = sqlx::query!(
            "SELECT count(*) as count FROM trade_history WHERE mt4_account = $1",
            mt4_account
        )
        .fetch_one(&state.db)
        .await
        .map_err(|e| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

        let trades = sqlx::query_as!(
            TradeHistory,
            r#"
            SELECT 
                ticket as "ticket!", 
                symbol as "symbol!", 
                open_time as "open_time!", 
                close_time as "close_time!", 
                COALESCE(open_price, 0.0) as "open_price!", 
                COALESCE(close_price, 0.0) as "close_price!", 
                COALESCE(lots, 0.0) as "lots!", 
                COALESCE(profit, 0.0) as "profit!", 
                trade_type as "trade_type!", 
                COALESCE(magic, 0) as "magic!", 
                COALESCE(mae, 0.0) as "mae!", 
                COALESCE(mfe, 0.0) as "mfe!", 
                signal_context, 
                mt4_account as "mt4_account!", 
                broker as "broker!" 
            FROM trade_history 
            WHERE mt4_account = $1
            ORDER BY close_time DESC 
            LIMIT $2 OFFSET $3
            "#,
            mt4_account, limit, offset
        )
        .fetch_all(&state.db)
        .await
        .map_err(|e| {
            tracing::error!("DB Error trade_history: {}", e);
            (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string())
        })?;
        (total_record.count.unwrap_or(0), trades)
    };
    
    Ok(Json(TradeHistoryResponse {
        data: trades,
        total,
        page,
        limit
    }))
}
