use std::sync::Arc;
use sqlx::Row;
use crate::ipc::state::CombinedState;
use crate::data_models::Candle;
use crate::risk::calculator as risk_calc;
use super::types::{EAAlertMetrics, MetricsInput};

/// 计算完整的 EA 警戒指标
pub async fn calculate_ea_alert_metrics(
    state: &Arc<CombinedState>,
    input: MetricsInput,
) -> EAAlertMetrics {
    // 1. 获取市场指标 (ATR, Velocity, RVOL, RSI)
    let (atr, velocity, rvol, rsi) = get_symbol_metrics(state, &input.symbol).await;
    
    // 2. 计算净手数
    let buy_lots: f64 = input.positions.iter().filter(|p| p.side == "BUY").map(|p| p.lots).sum();
    let sell_lots: f64 = input.positions.iter().filter(|p| p.side == "SELL").map(|p| p.lots).sum();
    let net_lots = buy_lots - sell_lots;
    
    // 3. 计算回撤
    let drawdown = if input.balance > 0.0 {
        ((input.balance - input.equity) / input.balance) * 100.0
    } else { 0.0 };

    // 4. 计算生存距离
    let survival_distance = risk_calc::calculate_survival_distance(
        input.equity, 
        input.margin, 
        input.margin_so_level, 
        net_lots, 
        input.contract_size
    );

    // 5. 计算强平价格
    let liq = risk_calc::calculate_liquidation_price_v2(
        input.equity,
        input.margin,
        input.margin_so_level,
        buy_lots,
        sell_lots,
        input.contract_size,
        input.current_bid,
        input.current_ask
    );

    // 6. 计算综合风险评分
    let metrics = risk_calc::calculate_integrated_risk_score(
        survival_distance, 
        atr, 
        velocity, 
        rvol, 
        &input.positions, 
        drawdown
    );
    
    // 7. 计算 RSI 信号
    let rsi_signal = if rsi >= 70.0 { "SELL".to_string() }
                     else if rsi <= 30.0 { "BUY".to_string() }
                     else { "NEUTRAL".to_string() };

    // 8. 组装返回
    EAAlertMetrics {
        liquidation_price: liq.effective_liquidation_price,
        survival_distance,
        risk_score: metrics.risk_score,
        layer_score: metrics.layer_score,
        drawdown_score: metrics.drawdown_score,
        drawdown,
        distance_score: metrics.distance_score,
        velocity_score: metrics.velocity_score,
        velocity_m1: velocity,
        rvol,
        rsi_14: rsi,
        rsi_signal,
        exit_trigger: metrics.exit_trigger,
        trigger_reason: metrics.trigger_reason,
        is_velocity_warning: metrics.is_velocity_warning,
        is_rvol_warning: metrics.is_rvol_warning,
        symbol: input.symbol,
        timestamp: chrono::Utc::now().timestamp(),
    }
}

async fn get_symbol_metrics(state: &Arc<CombinedState>, symbol: &str) -> (f64, f64, f64, f64) {
    let now = chrono::Utc::now().timestamp();
    
    // 1. Get/Calc ATR (Cached)
    let mut atr = 0.0;
    {
        let mem = state.memory.read().unwrap();
        if let Some(m) = mem.symbol_metrics.get(symbol) {
             // ATR D1 is slow moving, cache for 5 minutes (300s)
            if now - m.last_update < 300 {
                atr = m.atr_d1;
            }
        }
    }

    if atr == 0.0 {
        let start_ts = now - (30 * 86400); 
        let candles_query = sqlx::query_as!(
            Candle,
            "SELECT 
             COALESCE((timestamp / 86400) * 86400, 0) as \"time!\",
             (array_agg(bid ORDER BY timestamp ASC))[1] as \"open!\",
             MAX(bid) as \"high!\",
             MIN(bid) as \"low!\",
             (array_agg(bid ORDER BY timestamp DESC))[1] as \"close!\"
             FROM market_data 
             WHERE symbol = $1 AND timestamp > $2
             GROUP BY 1 
             ORDER BY 1 DESC 
             LIMIT 30",
             symbol,
             start_ts
        )
        .fetch_all(&state.db)
        .await;

        if let Ok(mut candles) = candles_query {
            candles.reverse();
            atr = risk_calc::calculate_atr(&candles, 14);
            
            // 🛡️ ATR Sanity Check: XAUUSD daily ATR typically 30-50, max ~80
            if symbol.contains("XAU") && atr > 80.0 {
                tracing::warn!("ATR capped: {} raw={:.2} -> 50.0 (tick aggregation bias)", symbol, atr);
                atr = 50.0; 
            }
            
            // Update Cache
            {
                let mut mem = state.memory.write().unwrap();
                let cached = mem.symbol_metrics.entry(symbol.to_string()).or_default();
                cached.atr_d1 = atr;
                cached.last_update = now;
            }
        }
    }

    // 2. Calculate Velocity & RVOL (Real-time, No Cache)
    // Find Latest TS
    let max_ts_row = sqlx::query!(
        "SELECT MAX(timestamp) as max_ts FROM market_data WHERE symbol = $1",
        symbol
    )
    .fetch_optional(&state.db)
    .await
    .unwrap_or(None);

    let latest_ts = max_ts_row.and_then(|r| r.max_ts).unwrap_or(now);

    // Velocity M1
    let velocity_result = sqlx::query(
        "SELECT 
            (array_agg(bid ORDER BY timestamp DESC))[1] as current_price,
            (array_agg(bid ORDER BY timestamp ASC))[1] as old_price
         FROM market_data 
         WHERE symbol = $1 AND timestamp >= $2 AND timestamp <= $3"
    )
    .bind(symbol)
    .bind(latest_ts - 61)
    .bind(latest_ts)
    .fetch_optional(&state.db)
    .await;

    let velocity_m1 = if let Ok(Some(row)) = velocity_result {
        let current: f64 = row.try_get("current_price").unwrap_or(0.0);
        let old: f64 = row.try_get("old_price").unwrap_or(0.0);
        if old > 0.0 { current - old } else { 0.0 }
    } else {
        0.0
    };

    // RVOL
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
    .bind(symbol)
    .bind(latest_ts - 3600)
    .bind(latest_ts)
    .bind(latest_ts - 86400)
    .fetch_optional(&state.db)
    .await;

    let rvol = if let Ok(Some(row)) = rvol_result {
        let current_ticks: i64 = row.try_get("tick_count").unwrap_or(0);
        let avg_ticks: Option<f64> = row.try_get("avg_ticks").ok();
        
        let c_ticks = current_ticks as f64;
        let a_ticks = avg_ticks.unwrap_or(0.0);
        
        if a_ticks > 0.0 { c_ticks / a_ticks } else { 1.0 }
    } else {
        1.0
    };

    // RSI Calculation (M1)
    let rsi_candles_query = sqlx::query_as!(
        Candle,
        "SELECT 
            (timestamp / 60) * 60 as \"time!\",
            (array_agg(bid ORDER BY timestamp ASC))[1] as \"open!\",
            MAX(bid) as \"high!\",
            MIN(bid) as \"low!\",
            (array_agg(bid ORDER BY timestamp DESC))[1] as \"close!\"
        FROM market_data
        WHERE symbol = $1 AND timestamp >= $2
        GROUP BY 1
        ORDER BY 1 DESC
        LIMIT 20",
        symbol,
        latest_ts - (25 * 60)
    )
    .fetch_all(&state.db)
    .await;

    let rsi = if let Ok(mut candles) = rsi_candles_query {
        candles.reverse();
        risk_calc::calculate_rsi(&candles, 14)
    } else {
        50.0
    };

    if atr == 0.0 || velocity_m1 == 0.0 {
        tracing::warn!("[Metrics] {} ATR={:.2} Vel={:.2} RVOL={:.2} RSI={:.2} (Time diff: {}s)", 
            symbol, atr, velocity_m1, rvol, rsi, now - latest_ts);
    }

    (atr, velocity_m1, rvol, rsi)
}
