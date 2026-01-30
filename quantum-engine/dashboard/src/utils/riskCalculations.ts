import type { AccountStatus, MarketData, Position } from '../types';

export interface RiskMetrics {
    liquidationPrice: number;
    liquidationDistance: number;
    riskScore: number;
    timeToDeath: string; // "45m" or ">24h"
    projectedDrawdown: number;
    nextBuy: { price: number; lots: number };
    nextSell: { price: number; lots: number };
}

/**
 * Calculate Liquidation Price based on Margin Level Stop Out
 * Formula: Equity / Margin = StopOutLevel
 * We need to find the price move that reduces Equity such that this holds.
 * 
 * Equity_new = Equity_current + (Price_move * Net_Lots * Contract_Size)
 * Margin_new approx Margin_current (assuming margin doesn't change linearly with price for simplicity, or we check margin mode)
 * For higher accuracy on Forex, margin changes with price, but for XAUUSD often fixed per lot if leverage fixed. 
 * Let's assume Margin is constant for small moves or worst case.
 * 
 * Target: (Equity_current + Loss) / Margin = StopOutLevel
 * Equity_current + Loss = Margin * StopOutLevel
 * Loss = Margin * StopOutLevel - Equity_current
 * 
 * Loss = Price_move * Net_Lots * Contract_Size
 * Price_move = (Margin * StopOutLevel - Equity_current) / (Net_Lots * Contract_Size)
 * Liq_Price = Current_Price + Price_move
 */
export const calculateLiquidationPrice = (
    account: AccountStatus,
    currentPrice: number,
    symbolInfo: { contractSize: number, stopOutLevel: number, tickValue: number }
): number => {
    if (!account || account.positions.length === 0) return 0;

    const buyLots = account.positions.filter(p => p.side === 'BUY').reduce((acc, p) => acc + p.lots, 0);
    const sellLots = account.positions.filter(p => p.side === 'SELL').reduce((acc, p) => acc + p.lots, 0);
    const netLots = buyLots - sellLots;

    if (Math.abs(netLots) < 0.001) return 0; // Hedged or empty

    // If StopOutLevel is e.g. 50 (%), we treat it as 0.5 ratio if it's > 1 we divide by 100?
    // Usually MT4 reports 50 for 50%. Let's assume logic: if > 1 then / 100.
    let stopOutRatio = symbolInfo.stopOutLevel;
    if (stopOutRatio > 1) stopOutRatio = stopOutRatio / 100.0;

    // Loss needed to hit Stop Out
    // Target Equity = Margin * StopOutRatio
    const targetEquity = account.margin * stopOutRatio;
    const lossNeeded = targetEquity - account.equity; // Should be negative

    const priceMove = lossNeeded / (netLots * symbolInfo.contractSize);

    return currentPrice + priceMove;
};

export const calculateRiskScore = (
    account: AccountStatus,
    liqPrice: number,
    currentPrice: number,
    atr: number,
    symbolInfo: { contractSize: number }
): number => {
    if (!account || account.positions.length === 0) return 0;

    let score = 0;

    // 1. Liquidation Distance Score (40%)
    if (liqPrice > 0) {
        const dist = Math.abs(currentPrice - liqPrice);
        // If dist < 3 * ATR => High Risk
        // Score = 40 * (1 - dist / (3 * ATR))
        if (atr > 0) {
            const atrBasedDist = dist / atr;
            if (atrBasedDist < 3) {
                score += 40 * (1 - atrBasedDist / 3);
            }
        }
    }

    // 2. Volatility Stress (30%)
    // If price moves 1.5 ATR against us
    const buyLots = account.positions.filter(p => p.side === 'BUY').reduce((acc, p) => acc + p.lots, 0);
    const sellLots = account.positions.filter(p => p.side === 'SELL').reduce((acc, p) => acc + p.lots, 0);
    const netLots = buyLots - sellLots;

    if (atr > 0 && Math.abs(netLots) > 0) {
        const stressLoss = Math.abs(netLots) * (1.5 * atr) * symbolInfo.contractSize;
        const equityAfterStress = account.equity - stressLoss;
        const stressImpact = stressLoss / account.equity;

        // If loss > 20% of equity, full 30 points.
        if (stressImpact > 0.2) score += 30;
        else score += 30 * (stressImpact / 0.2);
    }

    // 3. Layer Health (20%)
    // Heuristic: if lots > 0.5 (just a guess for now without MaxLayer from EA)
    // Let's use position count per side.
    const buyCount = account.positions.filter(p => p.side === 'BUY').length;
    const sellCount = account.positions.filter(p => p.side === 'SELL').length;
    const maxLayer = Math.max(buyCount, sellCount);
    const safeLayer = 15; // default max
    if (maxLayer > safeLayer) score += 20;
    else score += 20 * (maxLayer / safeLayer);

    // 4. Swap Risk (10%)
    // Total swap / (Balance * 0.001) ?? Or just negative swap ratio
    const totalSwap = account.positions.reduce((acc, p) => acc + p.swap, 0);
    if (totalSwap < -10) { // arbitrary threshold
        score += 10;
    }

    return Math.min(100, Math.max(0, score));
};

// --- New Risk Modules for Survival Dashboard ---

/**
 * 1. 生存距离计算 (Survival Distance in USD)
 * Formula: Survival Distance = (Equity - (Margin * StopOutLevel)) / (|Net Lots| * Contract Size)
 */
export const calculateSurvivalDistance = (
    equity: number,
    margin: number,
    stopOutLevel: number, // e.g., 50 (%)
    netLots: number,
    contractSize: number
): number => {
    if (Math.abs(netLots) < 0.001 || contractSize <= 0) return Infinity;

    // Convert StopOutLevel (e.g. 50 or 0.5) to ratio
    let stopOutRatio = stopOutLevel;
    if (stopOutRatio > 1) stopOutRatio = stopOutRatio / 100.0;

    const numerator = equity - (margin * stopOutRatio);
    // If numerator < 0, already below stop out!
    if (numerator <= 0) return 0;

    return numerator / (Math.abs(netLots) * contractSize);
};

/**
 * 2. 风险占用率计算 (Risk Occupancy %)
 * Formula: Risk Occupancy % = (2 * ATR(D1)) / Survival Distance * 100%
 */
export const calculateRiskOccupancy = (
    survivalDistance: number,
    atrD1: number
): number => {
    if (survivalDistance <= 0 || !isFinite(survivalDistance)) return 100;
    if (atrD1 <= 0) return 0; // No ATR data, assume 0 risk occupancy? Or max? Let's say 0 to avoid false alarm if data missing.
    return ((2 * atrD1) / survivalDistance) * 100;
};

/**
 * 3. 风险等级判定
 */
export type RiskLevel = 'SAFE' | 'WARNING' | 'CRITICAL';

export const calculateRiskLevel = (
    survivalDistance: number,
    atrD1: number
): RiskLevel => {
    if (survivalDistance === Infinity) return 'SAFE';
    if (atrD1 <= 0) return 'SAFE'; // Fallback

    if (survivalDistance > 2 * atrD1) return 'SAFE';       // 安全区 (> $53.54)
    if (survivalDistance > 1 * atrD1) return 'WARNING';    // 警戒区 (<= $53.54)
    return 'CRITICAL';                                     // 熔断区 (<= $26.77)
};

/**
 * Helper to calculate ATR from candles
 * Uses Simple Moving Average of TR (True Range) for simplicity (often called ATR in trading platforms if period is small, or RMA)
 * Standard ATR uses Wilder's Smoothing (RMA). We will use RMA for standard compatibility.
 * RMA_t = (RMA_{t-1} * (n-1) + TR_t) / n
 */
/**
 * 4. 方向敏感的精确爆仓价计算 (V2)
 * 多头使用 Bid，空头使用 Ask
 * Buy 爆仓价 = Current Bid - SurvivalDistance
 * Sell 爆仓价 = Current Ask + SurvivalDistance
 */
export interface DirectionalLiquidationPrice {
    buyLiquidationPrice: number;   // 多头爆仓价 (价格跌到此处爆仓)
    sellLiquidationPrice: number;  // 空头爆仓价 (价格涨到此处爆仓)
    dominantDirection: 'BUY' | 'SELL' | 'HEDGED';
    effectiveLiquidationPrice: number; // 根据净头寸方向的有效爆仓价
}

export const calculateLiquidationPriceV2 = (
    equity: number,
    margin: number,
    stopOutLevel: number,
    buyLots: number,
    sellLots: number,
    contractSize: number,
    currentBid: number,
    currentAsk: number
): DirectionalLiquidationPrice => {
    const netLots = buyLots - sellLots;

    // 计算生存距离 (绝对值)
    let stopOutRatio = stopOutLevel;
    if (stopOutRatio > 1) stopOutRatio = stopOutRatio / 100.0;

    const numerator = equity - (margin * stopOutRatio);

    let survivalDistance = Infinity;
    if (Math.abs(netLots) >= 0.001 && contractSize > 0 && numerator > 0) {
        survivalDistance = numerator / (Math.abs(netLots) * contractSize);
    }

    // 确定主导方向
    let dominantDirection: 'BUY' | 'SELL' | 'HEDGED' = 'HEDGED';
    if (netLots > 0.001) dominantDirection = 'BUY';
    else if (netLots < -0.001) dominantDirection = 'SELL';

    // 计算双向爆仓价
    // 多头：价格下跌到 Bid - Distance 时爆仓
    // 空头：价格上涨到 Ask + Distance 时爆仓
    const buyLiquidationPrice = isFinite(survivalDistance) && buyLots > 0
        ? currentBid - survivalDistance
        : 0;
    const sellLiquidationPrice = isFinite(survivalDistance) && sellLots > 0
        ? currentAsk + survivalDistance
        : 0;

    // 有效爆仓价（根据净头寸）
    let effectiveLiquidationPrice = 0;
    if (dominantDirection === 'BUY') {
        effectiveLiquidationPrice = currentBid - survivalDistance;
    } else if (dominantDirection === 'SELL') {
        effectiveLiquidationPrice = currentAsk + survivalDistance;
    }

    return {
        buyLiquidationPrice,
        sellLiquidationPrice,
        dominantDirection,
        effectiveLiquidationPrice: isFinite(effectiveLiquidationPrice) ? effectiveLiquidationPrice : 0
    };
};

/**
 * 5. 动态风险等级 (考虑 H1 波动加速)
 * 当 H1 ATR 超过 D1 ATR 的日均分摊时，强制提升风险等级
 * 日均分摊 = ATR(D1) / 24
 * 加速阈值 = 1.5x (H1 波动超过 D1 均值 1.5 倍则升级)
 */
export const calculateDynamicRiskLevel = (
    survivalDistance: number,
    atrD1: number,
    atrH1: number,
    accelerationThreshold: number = 1.5
): RiskLevel => {
    // 基础等级判定
    let baseLevel = calculateRiskLevel(survivalDistance, atrD1);

    // 检测 H1 波动加速
    if (atrD1 > 0 && atrH1 > 0) {
        const expectedHourlyATR = atrD1 / 24;
        const accelerationRatio = atrH1 / expectedHourlyATR;

        // 如果 H1 波动超过预期的 accelerationThreshold 倍，强制升级
        if (accelerationRatio >= accelerationThreshold) {
            if (baseLevel === 'SAFE') return 'WARNING';
            if (baseLevel === 'WARNING') return 'CRITICAL';
        }

        // 极端加速 (3x)：直接进入 CRITICAL
        if (accelerationRatio >= 3.0) {
            return 'CRITICAL';
        }
    }

    return baseLevel;
};

/**
 * Helper to calculate ATR from candles
 * Uses Wilder's Smoothing (RMA) for standard compatibility.
 */
export const calculateATR = (candles: any[], period: number = 14): number => {
    if (!candles || candles.length < period + 1) return 0;

    const trs: number[] = [];
    for (let i = 1; i < candles.length; i++) {
        const high = candles[i].high;
        const low = candles[i].low;
        const prevClose = candles[i - 1].close;

        const tr = Math.max(
            high - low,
            Math.abs(high - prevClose),
            Math.abs(low - prevClose)
        );
        trs.push(tr);
    }

    if (trs.length === 0) return 0;

    // First ATR is simple average of first 'period' TRs
    let atr = trs.slice(0, period).reduce((a, b) => a + b, 0) / period;

    // Remaining ATRs using Wilder's Smoothing
    for (let i = period; i < trs.length; i++) {
        atr = (atr * (period - 1) + trs[i]) / period;
    }

    return atr;
};
