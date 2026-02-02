use crate::data_models::{AccountStatus, Candle, DirectionalLiquidationPrice, Position, SmartExitMetrics};
use std::f64;

// 常量配置 (对应 SMART_EXIT_CONFIG)
const VELOCITY_WARNING_THRESHOLD: f64 = 2.0;
const VELOCITY_CRITICAL_THRESHOLD: f64 = 3.0;
const VELOCITY_EXTREME_THRESHOLD: f64 = 5.0;

const RVOL_WARNING_THRESHOLD: f64 = 2.0;
const RVOL_CRITICAL_THRESHOLD: f64 = 3.0;

const DEFAULT_MAX_LAYER: usize = 15;

/// Calculate ATR from candles (Wilder's Smoothing)
pub fn calculate_atr(candles: &[Candle], period: usize) -> f64 {
    if candles.len() < 2 {
        return 0.0;
    }

    let effective_period = std::cmp::min(period, candles.len() - 1);
    if effective_period < 1 {
        return 0.0;
    }

    let mut trs = Vec::with_capacity(candles.len());
    
    // Note: candles[0] is oldest or newest?
    // In http_server.rs, get_candles output: ORDER BY timestamp ASC.
    // So candles[0] is oldest.
    // Loop from 1 to end
    for i in 1..candles.len() {
        let high = candles[i].high;
        let low = candles[i].low;
        let prev_close = candles[i-1].close;
        
        let tr = (high - low).max((high - prev_close).abs()).max((low - prev_close).abs());
        trs.push(tr);
    }
    
    if trs.is_empty() { return 0.0; }
    
    // First ATR: simple average
    let first_slice = &trs[0..effective_period];
    let mut atr = first_slice.iter().sum::<f64>() / effective_period as f64;
    
    // Remaining ATRs: (ATR * (n-1) + TR) / n
    for i in effective_period..trs.len() {
        atr = (atr * (effective_period as f64 - 1.0) + trs[i]) / effective_period as f64;
    }
    
    atr
}

/// Calculate Survival Distance (USD)
pub fn calculate_survival_distance(
    equity: f64,
    margin: f64,
    stop_out_level: f64,
    net_lots: f64,
    contract_size: f64,
) -> f64 {
    if net_lots.abs() < 0.001 || contract_size <= 0.0 {
        return f64::INFINITY;
    }

    let mut stop_out_ratio = stop_out_level;
    if stop_out_ratio > 1.0 {
        stop_out_ratio /= 100.0;
    }

    let numerator = equity - (margin * stop_out_ratio);
    if numerator <= 0.0 {
        return 0.0;
    }

    numerator / (net_lots.abs() * contract_size)
}

/// Calculate Liquidation Price V2
pub fn calculate_liquidation_price_v2(
    equity: f64,
    margin: f64,
    stop_out_level: f64,
    buy_lots: f64,
    sell_lots: f64,
    contract_size: f64,
    current_bid: f64,
    current_ask: f64,
) -> DirectionalLiquidationPrice {
    let net_lots = buy_lots - sell_lots;
    let surv_dist = calculate_survival_distance(equity, margin, stop_out_level, net_lots, contract_size);
    
    let mut dom_dir = "HEDGED".to_string();
    if net_lots > 0.001 { dom_dir = "BUY".to_string(); }
    else if net_lots < -0.001 { dom_dir = "SELL".to_string(); }
    
    let buy_liq = if surv_dist.is_finite() && buy_lots > 0.0 {
        current_bid - surv_dist
    } else { 0.0 };
    
    let sell_liq = if surv_dist.is_finite() && sell_lots > 0.0 {
        current_ask + surv_dist
    } else { 0.0 };
    
    let effective_liq = if dom_dir == "BUY" {
        current_bid - surv_dist
    } else if dom_dir == "SELL" {
        current_ask + surv_dist
    } else {
        0.0
    };
    
    DirectionalLiquidationPrice {
        buy_liquidation_price: buy_liq,
        sell_liquidation_price: sell_liq,
        dominant_direction: dom_dir,
        effective_liquidation_price: if effective_liq.is_finite() { effective_liq } else { 0.0 },
    }
}

/// Calculate Integrated Risk Score
pub fn calculate_integrated_risk_score(
    survival_distance: f64,
    atr_d1: f64,
    velocity_m1: f64,
    rvol: f64,
    positions: &[Position],
    max_drawdown: f64,
) -> SmartExitMetrics {
    // Basic Info
    let buy_positions: Vec<&Position> = positions.iter().filter(|p| p.side == "BUY").collect();
    let sell_positions: Vec<&Position> = positions.iter().filter(|p| p.side == "SELL").collect();
    let buy_lots: f64 = buy_positions.iter().map(|p| p.lots).sum();
    let sell_lots: f64 = sell_positions.iter().map(|p| p.lots).sum();
    let net_lots = buy_lots - sell_lots;

    let dominant_direction = if net_lots > 0.001 { "BUY" } 
    else if net_lots < -0.001 { "SELL" } 
    else { "HEDGED" };

    // 1. Distance Score (30%)
    // < 1 ATR => 30 pts; < 2 ATR => 20 pts; < 3 ATR => 10 pts
    let mut dist_score = 0.0;
    if survival_distance.is_finite() && atr_d1 > 0.0 {
        let ratio = survival_distance / atr_d1;
        if ratio < 1.0 { dist_score = 30.0; }
        else if ratio < 2.0 { dist_score = 20.0; }
        else if ratio < 3.0 { dist_score = 10.0; }
        else if ratio < 5.0 { dist_score = 5.0; }
    } else if survival_distance <= 0.0 {
        dist_score = 30.0; // Already blown up?
    }

    // 2. Velocity Score (20%)
    // Only if Adverse Velocity
    let mut velocity_score = 0.0;
    let is_velocity_warning = velocity_m1.abs() > VELOCITY_WARNING_THRESHOLD;
    
    let is_adverse = match dominant_direction {
        "BUY" => velocity_m1 < 0.0, // Drop is bad for BUY
        "SELL" => velocity_m1 > 0.0, // Rise is bad for SELL
        _ => velocity_m1.abs() > VELOCITY_EXTREME_THRESHOLD, // HEDGED but huge move
    };

    if is_adverse {
        let v_abs = velocity_m1.abs();
        if v_abs >= VELOCITY_CRITICAL_THRESHOLD { velocity_score = 20.0; }
        else if v_abs >= VELOCITY_WARNING_THRESHOLD { velocity_score = 10.0; }
        else if v_abs >= 1.0 { velocity_score = 5.0; }
    }

    // 3. Layer Score (20%)
    let mut layer_score = 0.0;
    let max_layer = buy_positions.len().max(sell_positions.len());
    if max_layer >= DEFAULT_MAX_LAYER { layer_score = 20.0; }
    else if max_layer >= 10 { layer_score = 15.0; }
    else if max_layer >= 5 { layer_score = 5.0; }

    // 4. Drawdown Score (30%)
    let mut drawdown_score = 0.0;
    if max_drawdown >= 30.0 { drawdown_score = 30.0; }
    else if max_drawdown >= 20.0 { drawdown_score = 20.0; }
    else if max_drawdown >= 10.0 { drawdown_score = 10.0; }
    else if max_drawdown >= 5.0 { drawdown_score = 5.0; }

    let total_risk_score: f64 = dist_score + velocity_score + layer_score + drawdown_score;

    // Trigger Logic
    let mut exit_trigger = "NONE".to_string();
    let mut trigger_reason = String::new();

    // Force Exit Conditions
    if total_risk_score >= 90.0 {
        exit_trigger = "FORCE_EXIT".to_string();
        trigger_reason = "综合风险分极高 (>90)".to_string();
    } else if survival_distance.is_finite() && atr_d1 > 0.0 && survival_distance < (0.3 * atr_d1) && survival_distance < 50.0 {
        // 双重保护：必须同时小于 0.3 ATR 且绝对距离小于 50 美元
        exit_trigger = "FORCE_EXIT".to_string();
        trigger_reason = "生存空间极度不足 (<0.3 ATR)".to_string();
    } 
    // Tactical Exit Conditions
    else if total_risk_score >= 70.0 {
        exit_trigger = "TACTICAL_EXIT".to_string();
        trigger_reason = "风险分较高 (>70)".to_string();
    } else if is_velocity_warning && is_adverse && survival_distance < (2.0 * atr_d1) {
        exit_trigger = "TACTICAL_EXIT".to_string();
        trigger_reason = "逆势加速且空间不足".to_string();
    }
    // Layer Lock
    else if max_layer >= DEFAULT_MAX_LAYER {
        exit_trigger = "LAYER_LOCK".to_string();
        trigger_reason = "达到最大层级限制".to_string();
    }

    SmartExitMetrics {
        survival_distance,
        liquidation_price: 0.0, // Calculated separately or passed in? 
                                // TS passes it separately, here we return struct. 
                                // Caller should set it if needed, or we compute simple version.
        velocity_m1,
        rvol,
        risk_score: total_risk_score.min(100.0f64),
        distance_score: dist_score,
        velocity_score,
        layer_score,
        drawdown_score,
        exit_trigger,
        trigger_reason,
        is_velocity_warning,
        is_rvol_warning: rvol > RVOL_WARNING_THRESHOLD,
        is_martingale_pattern: false, // Not implemented yet
        martingale_warning: String::new(),
    }
}
