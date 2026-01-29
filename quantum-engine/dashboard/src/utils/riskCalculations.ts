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
