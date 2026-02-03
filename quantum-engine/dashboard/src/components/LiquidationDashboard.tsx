import React, { useMemo, useState, useEffect } from 'react';
import axios from 'axios';
import { ShieldAlert, ShieldCheck, AlertTriangle, Zap, ZapOff } from 'lucide-react';
import type { AccountStatus } from '../types';
import { API_BASE } from '../config';
import {
    calculateSurvivalDistance,
    calculateRiskOccupancy,
    calculateLiquidationPriceV2,
    calculateRiskLevel,
    type RiskLevel
} from '../utils/smartExitCalculations';

interface LiquidationDashboardProps {
    accountStatus: AccountStatus;
    currentPrice: number | null;
    currentBid?: number | null;
    currentAsk?: number | null;
    symbolInfo: { contractSize: number; stopOutLevel: number; tickValue: number };
    atr: number;
    atrH1?: number;
    authToken?: string; // Add Auth token
}

export const LiquidationDashboard: React.FC<LiquidationDashboardProps> = ({
    accountStatus,
    currentPrice,
    currentBid,
    currentAsk,
    symbolInfo,
    atr,
    atrH1 = 0,
    authToken
}) => {
    // EA Linkage State
    const [eaLinkageEnabled, setEaLinkageEnabled] = useState(false);
    const [syncStatus, setSyncStatus] = useState<'IDLE' | 'SYNCING' | 'ERROR'>('IDLE');

    // Use bid/ask if available, otherwise fall back to close price
    const bid = currentBid ?? currentPrice ?? 0;
    const ask = currentAsk ?? currentPrice ?? 0;

    // 1. Calculate Core Metrics using V2
    const {
        netLots,
        survivalDistance,
        riskOccupancy,
        riskLevel,
        liquidationPrice,
        dominantDirection,
        isAccelerated
    } = useMemo(() => {
        if (!accountStatus || accountStatus.positions.length === 0) {
            return {
                netLots: 0,
                survivalDistance: Infinity,
                riskOccupancy: 0,
                riskLevel: 'SAFE' as RiskLevel,
                liquidationPrice: 0,
                dominantDirection: 'HEDGED' as const,
                isAccelerated: false
            };
        }

        const buyLots = accountStatus.positions.filter(p => p.side === 'BUY').reduce((acc, p) => acc + p.lots, 0);
        const sellLots = accountStatus.positions.filter(p => p.side === 'SELL').reduce((acc, p) => acc + p.lots, 0);
        const net = buyLots - sellLots;

        const liqV2 = calculateLiquidationPriceV2(
            accountStatus.equity,
            accountStatus.margin,
            symbolInfo.stopOutLevel,
            buyLots,
            sellLots,
            symbolInfo.contractSize,
            bid,
            ask
        );

        const dist = calculateSurvivalDistance(
            accountStatus.equity,
            accountStatus.margin,
            symbolInfo.stopOutLevel,
            net,
            symbolInfo.contractSize
        );

        const occ = calculateRiskOccupancy(dist, atr);

        const level = atrH1 > 0
            ? calculateRiskLevel(dist, atr) // Simplified to legacy helper for now
            : calculateRiskLevel(dist, atr);

        const baseLevel = calculateRiskLevel(dist, atr);
        const accelerated = level !== baseLevel;

        return {
            netLots: net,
            survivalDistance: dist,
            riskOccupancy: occ,
            riskLevel: level,
            liquidationPrice: liqV2.effectiveLiquidationPrice,
            dominantDirection: liqV2.dominantDirection,
            isAccelerated: accelerated
        };
    }, [accountStatus, bid, ask, symbolInfo, atr, atrH1]);

    // 2. Sync Risk State to EA
    useEffect(() => {
        if (!eaLinkageEnabled || !authToken || !accountStatus.mt4_account) return;

        const syncToBackend = async () => {
            setSyncStatus('SYNCING');
            try {
                let blockBuy = false;
                let blockSell = false;
                let blockAll = false;

                // Logic: 
                // SAFE: Allow All
                // WARNING: Block Trend Following (Prevent adding to losers if grid logic, or prevent adding risk)
                // For simplicity: WARNING blocks adding same direction. CRITICAL blocks all.

                if (riskLevel === 'WARNING') {
                    if (dominantDirection === 'BUY') blockBuy = true;
                    if (dominantDirection === 'SELL') blockSell = true;
                } else if (riskLevel === 'CRITICAL') {
                    blockAll = true;
                    blockBuy = true;
                    blockSell = true;
                }

                await axios.put(`${API_BASE}/risk_control`, {
                    mt4_account: accountStatus.mt4_account,
                    block_buy: blockBuy,
                    block_sell: blockSell,
                    block_all: blockAll,
                    risk_level: riskLevel,
                    updated_at: 0 // Backend fills this
                }, {
                    headers: { Authorization: `Bearer ${authToken}` }
                });
                setSyncStatus('IDLE');
            } catch (err) {
                console.error("Failed to sync risk control", err);
                setSyncStatus('ERROR');
            }
        };

        syncToBackend();
        // Debounce? For now just run on riskLevel change
    }, [riskLevel, dominantDirection, eaLinkageEnabled, accountStatus.mt4_account, authToken]);


    // 3. Risk Level Configuration
    const riskConfig = {
        SAFE: {
            color: 'text-emerald-500',
            bgColor: 'bg-emerald-500/10',
            borderColor: 'border-emerald-500/20',
            icon: ShieldCheck,
            label: 'NORMAL',
            statusColor: 'text-emerald-400'
        },
        WARNING: {
            color: 'text-yellow-500',
            bgColor: 'bg-yellow-500/10',
            borderColor: 'border-yellow-500/20',
            icon: AlertTriangle,
            label: 'WARNING',
            statusColor: 'text-yellow-400'
        },
        CRITICAL: {
            color: 'text-rose-500',
            bgColor: 'bg-rose-500/10',
            borderColor: 'border-rose-500/20',
            icon: ShieldAlert,
            label: 'BLOCKED',
            statusColor: 'text-rose-500'
        }
    };

    const config = riskConfig[riskLevel as keyof typeof riskConfig] || riskConfig.SAFE;
    const Icon = config.icon;

    // 4. Status Text Logic
    const getStatusText = () => {
        if (!eaLinkageEnabled) return '⚠️ 联动未开启';
        if (riskLevel === 'SAFE') return '✅ 策略正常运行';
        if (riskLevel === 'WARNING') return '⛔️ 静默禁止加仓';
        return '🚫 触发熔断保护';
    };

    // Survival Time Estimate
    const getSurvivalTime = () => {
        if (!atr || survivalDistance === Infinity) return '> 24h';
        const atrPerHour = atr / 24;
        const hours = survivalDistance / (atrPerHour * 2);
        if (hours > 24) return '> 24h';
        if (hours < 1) return '< 1h';
        return `~${hours.toFixed(1)}h`;
    };

    return (
        <div className={`
            relative overflow-hidden rounded-xl border p-4 transition-all duration-300
            ${config.borderColor} ${config.bgColor}
            ${riskLevel === 'CRITICAL' ? 'shadow-[0_0_15px_rgba(244,63,94,0.15)] animate-pulse-border' : ''}
        `}>
            {/* Header */}
            <div className="flex justify-between items-start mb-4">
                <div className="flex items-center gap-2">
                    <div className={`p-1.5 rounded-lg bg-slate-900 border border-slate-700 ${config.color}`}>
                        <Icon size={18} />
                    </div>
                    <div>
                        <h3 className="text-sm font-bold text-slate-200">24H 生存仪表盘</h3>
                        <p className="text-[10px] text-slate-500 font-mono">
                            XAUUSD • {dominantDirection === 'BUY' ? '📈 多头主导' : dominantDirection === 'SELL' ? '📉 空头主导' : '⚖️ 对冲'}
                        </p>
                    </div>
                </div>

                <div className="flex flex-col items-end">
                    <button
                        onClick={() => setEaLinkageEnabled(!eaLinkageEnabled)}
                        className={`
                            flex items-center gap-1.5 px-2 py-1 rounded text-[10px] font-bold border transition-colors
                            ${eaLinkageEnabled
                                ? 'bg-cyan-500/10 border-cyan-500/30 text-cyan-400 hover:bg-cyan-500/20'
                                : 'bg-slate-800 border-slate-700 text-slate-500 hover:text-slate-400'}
                        `}
                    >
                        {eaLinkageEnabled ? <Zap size={10} className="fill-current" /> : <ZapOff size={10} />}
                        {eaLinkageEnabled ? 'EA LINKED' : 'UNLINKED'}
                        {syncStatus === 'SYNCING' && <span className="animate-spin ml-1">⟳</span>}
                    </button>

                    {isAccelerated && (
                        <span className="text-[10px] font-bold text-amber-500 mt-1 animate-pulse">
                            ⚡ H1 波动加速
                        </span>
                    )}
                </div>
            </div>

            {/* Metrics Grid */}
            <div className="grid grid-cols-3 gap-4 mb-4">
                {/* 1. Dead Line */}
                <div className="flex flex-col">
                    <span className="text-[10px] text-slate-500 mb-0.5">当前死线价 (Liq)</span>
                    <span className={`text-lg font-mono font-bold ${config.color}`}>
                        {liquidationPrice > 0 ? liquidationPrice.toFixed(2) : '---'}
                    </span>
                    <span className="text-[9px] text-slate-600 font-mono">
                        {currentPrice && liquidationPrice > 0
                            ? `▼ 現價 ${(liquidationPrice - currentPrice).toFixed(1)}`
                            : '---'}
                    </span>
                </div>

                {/* 2. Survival Distance */}
                <div className="flex flex-col">
                    <span className="text-[10px] text-slate-500 mb-0.5">剩余点距 (Safety)</span>
                    <span className={`text-lg font-mono font-bold ${survivalDistance < atr ? 'text-rose-500' : 'text-emerald-400'
                        }`}>
                        {survivalDistance !== Infinity ? `$${survivalDistance.toFixed(2)}` : '∞'}
                    </span>
                    <span className="text-[9px] text-slate-600 font-mono">
                        {atr ? `${(survivalDistance / atr).toFixed(1)}x ATR` : '---'}
                    </span>
                </div>

                {/* 3. Status */}
                <div className="flex flex-col items-end">
                    <span className="text-[10px] text-slate-500 mb-0.5">系统拦截状态</span>
                    <span className={`text-sm font-bold ${config.statusColor}`}>
                        {config.label}
                    </span>
                    <span className="text-[9px] text-slate-400 text-right mt-0.5">
                        {getStatusText()}
                    </span>
                </div>
            </div>

            {/* Progress Bar & Footer */}
            <div className="space-y-2">
                <div className="flex justify-between text-[10px] text-slate-500 font-mono">
                    <span>RISK OCCUPANCY</span>
                    <span>{riskOccupancy > 100 ? '>100%' : `${riskOccupancy.toFixed(1)}%`}</span>
                </div>

                <div className="h-1.5 w-full bg-slate-800 rounded-full overflow-hidden">
                    <div
                        className={`h-full rounded-full transition-all duration-500 ${riskLevel === 'CRITICAL' ? 'bg-rose-500' :
                            riskLevel === 'WARNING' ? 'bg-yellow-500' : 'bg-emerald-500'
                            }`}
                        style={{ width: `${Math.min(100, riskOccupancy)}%` }}
                    />
                </div>

                <div className="flex justify-between items-center pt-2 border-t border-slate-800/50 mt-3">
                    <div className="flex gap-3 text-[10px] font-mono text-slate-500">
                        <span>ATR(D1): <span className="text-slate-300">${atr ? atr.toFixed(1) : '--'}</span></span>
                        <span>NET: <span className={netLots > 0 ? 'text-emerald-400' : 'text-rose-400'}>
                            {netLots.toFixed(2)}
                        </span></span>
                    </div>
                    <span className="text-[10px] text-slate-400 font-mono">
                        Est. Time: <span className="text-slate-300">{getSurvivalTime()}</span>
                    </span>
                </div>
            </div>

            {/* Red Flash Overlay for Critical */}
            {riskLevel === 'CRITICAL' && (
                <div className="absolute inset-0 bg-rose-500/5 pointer-events-none animate-pulse" />
            )}
        </div>
    );
};
