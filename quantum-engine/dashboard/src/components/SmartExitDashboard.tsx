import React, { useMemo, useState, useEffect } from 'react';
import axios from 'axios';
import {
    Zap, ZapOff, Activity, TrendingDown, TrendingUp, AlertTriangle, Gauge
} from 'lucide-react';
import type { AccountStatus } from '../types';
import { API_BASE } from '../config';
import {
    calculateSurvivalDistance,
    calculateRiskOccupancy,
    calculateLiquidationPriceV2,
    calculateDynamicRiskLevel,
    type RiskLevel
} from '../utils/riskCalculations';
import {
    calculateIntegratedRiskScore,
    estimateSurvivalTime,
    getExitTriggerConfig,
    SMART_EXIT_CONFIG,
    type SmartExitMetrics,
    type VelocityData
} from '../utils/smartExitCalculations';

interface SmartExitDashboardProps {
    accountStatus: AccountStatus;
    currentPrice: number | null;
    currentBid?: number | null;
    currentAsk?: number | null;
    symbolInfo: { contractSize: number; stopOutLevel: number; tickValue: number };
    atr: number;
    atrH1?: number;
    authToken?: string;
    selectedSymbol?: string;
}

export const SmartExitDashboard: React.FC<SmartExitDashboardProps> = ({
    accountStatus,
    currentPrice,
    currentBid,
    currentAsk,
    symbolInfo,
    atr,
    atrH1 = 0,
    authToken,
    selectedSymbol = 'XAUUSD'
}) => {
    // --- 1. Hooks (State & Memos) ---
    const [eaLinkageEnabled, setEaLinkageEnabled] = useState(false);
    const [syncStatus, setSyncStatus] = useState<'IDLE' | 'SYNCING' | 'ERROR'>('IDLE');
    const [hasUserToggled, setHasUserToggled] = useState(false);
    const [velocityData, setVelocityData] = useState<VelocityData | null>(null);

    // Use bid/ask if available, otherwise fall back to close price
    const bid = currentBid ?? currentPrice ?? 0;
    const ask = currentAsk ?? currentPrice ?? 0;

    // Core Metrics Memo
    const {
        netLots,
        survivalDistance,
        riskOccupancy,
        riskLevel,
        liquidationPrice,
        dominantDirection
    } = useMemo(() => {
        if (!accountStatus || accountStatus.positions.length === 0) {
            return {
                netLots: 0,
                survivalDistance: Infinity,
                riskOccupancy: 0,
                riskLevel: 'SAFE' as RiskLevel,
                liquidationPrice: 0,
                dominantDirection: 'HEDGED' as const
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
            ? calculateDynamicRiskLevel(dist, atr, atrH1)
            : calculateDynamicRiskLevel(dist, atr, 0);

        return {
            netLots: net,
            survivalDistance: dist,
            riskOccupancy: occ,
            riskLevel: level,
            liquidationPrice: liqV2.effectiveLiquidationPrice,
            dominantDirection: liqV2.dominantDirection
        };
    }, [accountStatus, bid, ask, symbolInfo, atr, atrH1]);

    // Smart Exit Metrics Memo
    const smartMetrics: SmartExitMetrics = useMemo(() => {
        const velocityM1 = velocityData?.velocityM1 ?? 0;
        const rvol = velocityData?.rvol ?? 1.0;

        const metrics = calculateIntegratedRiskScore(
            survivalDistance,
            atr,
            velocityM1,
            rvol,
            accountStatus.positions,
            SMART_EXIT_CONFIG.DEFAULT_MAX_LAYER
        );

        return {
            ...metrics,
            liquidationPrice
        };
    }, [survivalDistance, atr, velocityData, accountStatus.positions, liquidationPrice]);

    // --- 2. Side Effects ---
    // Fetch Velocity Data
    useEffect(() => {
        if (!authToken || !selectedSymbol) return;

        const fetchVelocity = async () => {
            try {
                const res = await axios.get(`${API_BASE}/velocity`, {
                    params: { symbol: selectedSymbol },
                    headers: { Authorization: `Bearer ${authToken}` }
                });
                setVelocityData(res.data);
            } catch {
                // Velocity endpoint may not exist yet, use fallback
                console.debug("Velocity data not available, using fallback");
            }
        };

        fetchVelocity();
        const interval = setInterval(fetchVelocity, 5000);
        return () => clearInterval(interval);
    }, [authToken, selectedSymbol]);

    // 3. Sync Risk State to EA
    // Fetch initial state
    useEffect(() => {
        if (!authToken || !accountStatus.mt4_account) return;

        const fetchRiskState = async () => {
            try {
                const res = await axios.get(`${API_BASE}/risk_control`, {
                    params: { mt4_account: accountStatus.mt4_account },
                    headers: { Authorization: `Bearer ${authToken}` }
                });
                if (res.data) {
                    setEaLinkageEnabled(!!res.data.enabled);
                }
            } catch (err) {
                console.error("Failed to fetch risk control state", err);
            }
        };

        fetchRiskState();
    }, [authToken, accountStatus.mt4_account]);

    const handleToggleLinkage = () => {
        setHasUserToggled(true);
        setEaLinkageEnabled(prev => !prev);
    };

    useEffect(() => {
        // Only sync when user has explicitly toggled, not on initial load
        if (!hasUserToggled || !authToken || !accountStatus.mt4_account) return;

        const syncToBackend = async () => {
            setSyncStatus('SYNCING');
            try {
                let blockBuy = false;
                let blockSell = false;
                let blockAll = false;

                // Only calculate blocks if enabled
                if (eaLinkageEnabled) {
                    if (smartMetrics.exitTrigger === 'FORCE_EXIT' || smartMetrics.exitTrigger === 'TACTICAL_EXIT') {
                        blockAll = true;
                        blockBuy = true;
                        blockSell = true;
                    } else if (smartMetrics.exitTrigger === 'LAYER_LOCK') {
                        if (dominantDirection === 'BUY') blockBuy = true;
                        if (dominantDirection === 'SELL') blockSell = true;
                    } else if (riskLevel === 'WARNING') {
                        if (dominantDirection === 'BUY') blockBuy = true;
                        if (dominantDirection === 'SELL') blockSell = true;
                    } else if (riskLevel === 'CRITICAL') {
                        blockAll = true;
                        blockBuy = true;
                        blockSell = true;
                    }
                }

                await axios.put(`${API_BASE}/risk_control`, {
                    mt4_account: accountStatus.mt4_account,
                    block_buy: blockBuy,
                    block_sell: blockSell,
                    block_all: blockAll,
                    risk_level: riskLevel,
                    risk_score: smartMetrics.riskScore,
                    exit_trigger: smartMetrics.exitTrigger,
                    velocity_block: smartMetrics.isVelocityWarning,
                    enabled: eaLinkageEnabled
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
    }, [eaLinkageEnabled, hasUserToggled, accountStatus.mt4_account, authToken]);

    // 4. Get trigger config for styling
    const triggerConfig = getExitTriggerConfig(smartMetrics.exitTrigger);

    // 5. Velocity bar percentage
    const velocityPercent = Math.min(100, (Math.abs(smartMetrics.velocityM1) / SMART_EXIT_CONFIG.VELOCITY_CRITICAL_THRESHOLD) * 100);
    const rvolPercent = Math.min(100, (smartMetrics.rvol / SMART_EXIT_CONFIG.RVOL_CRITICAL) * 100);

    // Survival Time with velocity consideration
    const survivalTime = estimateSurvivalTime(survivalDistance, atr, smartMetrics.velocityM1);

    return (
        <div className={`
            relative overflow-hidden rounded-xl border p-4 transition-all duration-300
            ${triggerConfig.borderColor} ${triggerConfig.bgColor}
            ${smartMetrics.exitTrigger !== 'NONE' ? 'shadow-[0_0_20px_rgba(244,63,94,0.2)]' : ''}
        `}>
            {/* Header */}
            <div className="flex justify-between items-start mb-4">
                <div className="flex items-center gap-2">
                    <div className={`p-1.5 rounded-lg bg-slate-900 border border-slate-700 ${triggerConfig.color}`}>
                        <Gauge size={18} />
                    </div>
                    <div>
                        <h3 className="text-sm font-bold text-slate-200">24H 智能风控仪表盘</h3>
                        <p className="text-[10px] text-slate-500 font-mono">
                            {selectedSymbol} • {dominantDirection === 'BUY' ? '📈 多头' : dominantDirection === 'SELL' ? '📉 空头' : '⚖️ 对冲'}
                        </p>
                    </div>
                </div>

                <div className="flex flex-col items-end gap-1">
                    <button
                        onClick={handleToggleLinkage}
                        className={`
                            flex items-center gap-1.5 px-2 py-1 rounded text-[10px] font-bold border transition-colors
                            ${eaLinkageEnabled
                                ? 'bg-cyan-500/10 border-cyan-500/30 text-cyan-400 hover:bg-cyan-500/20'
                                : 'bg-slate-800 border-slate-700 text-slate-500 hover:text-slate-400'}
                        `}
                    >
                        {eaLinkageEnabled ? <Zap size={10} className="fill-current" /> : <ZapOff size={10} />}
                        {eaLinkageEnabled ? 'EA联动' : '未联动'}
                        {syncStatus === 'SYNCING' && <span className="animate-spin ml-1">⟳</span>}
                    </button>

                    <span className={`text-[10px] font-bold px-2 py-0.5 rounded ${triggerConfig.bgColor} ${triggerConfig.color}`}>
                        {triggerConfig.icon} {triggerConfig.label}
                    </span>
                </div>
            </div>

            {/* Top Row: Key Metrics */}
            <div className="grid grid-cols-3 gap-3 mb-4">
                <div className="flex flex-col bg-slate-900/50 rounded-lg p-2 border border-slate-800/50">
                    <span className="text-[9px] text-slate-500 mb-0.5">死线价</span>
                    <span className={`text-lg font-mono font-bold ${triggerConfig.color}`}>
                        {liquidationPrice > 0 ? liquidationPrice.toFixed(2) : '---'}
                    </span>
                    <span className="text-[8px] text-slate-600 font-mono">
                        {currentPrice && liquidationPrice > 0
                            ? `${dominantDirection === 'BUY' ? '▼' : '▲'} ${Math.abs(liquidationPrice - currentPrice).toFixed(1)}`
                            : '---'}
                    </span>
                </div>

                <div className="flex flex-col bg-slate-900/50 rounded-lg p-2 border border-slate-800/50">
                    <span className="text-[9px] text-slate-500 mb-0.5">剩余距离</span>
                    <span className={`text-lg font-mono font-bold ${survivalDistance < atr ? 'text-rose-500' : 'text-emerald-400'}`}>
                        {survivalDistance !== Infinity ? `$${survivalDistance.toFixed(1)}` : '∞'}
                    </span>
                    <span className="text-[8px] text-slate-600 font-mono">
                        {atr ? `${(survivalDistance / atr).toFixed(1)}x ATR` : '---'}
                    </span>
                </div>

                <div className="flex flex-col items-center justify-center bg-slate-900/50 rounded-lg p-2 border border-slate-800/50">
                    <span className="text-[9px] text-slate-500 mb-0.5">综合评分</span>
                    <span className={`text-2xl font-mono font-bold ${triggerConfig.color}`}>
                        {smartMetrics.riskScore.toFixed(0)}
                    </span>
                    <span className="text-[8px] text-slate-500">/100</span>
                </div>
            </div>

            {/* Velocity Monitor */}
            <div className="bg-slate-900/30 rounded-lg p-2.5 border border-slate-800/30 mb-3">
                <div className="flex items-center justify-between mb-2">
                    <div className="flex items-center gap-1.5">
                        <Activity size={12} className="text-cyan-500" />
                        <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Velocity Monitor</span>
                    </div>
                    <div className="flex items-center gap-2 text-[10px] font-mono">
                        <span className={`${smartMetrics.velocityM1 < 0 ? 'text-rose-400' : 'text-emerald-400'}`}>
                            {smartMetrics.velocityM1 < 0 ? <TrendingDown size={10} className="inline mr-0.5" /> : <TrendingUp size={10} className="inline mr-0.5" />}
                            ${smartMetrics.velocityM1.toFixed(2)}
                        </span>
                        <span className="text-slate-600">|</span>
                        <span className={smartMetrics.isRvolWarning ? 'text-amber-400' : 'text-slate-400'}>
                            RVOL: {smartMetrics.rvol.toFixed(1)}x
                        </span>
                    </div>
                </div>

                <div className="space-y-1.5">
                    <div className="flex items-center gap-2">
                        <span className="text-[8px] text-slate-500 w-10">动量</span>
                        <div className="flex-1 h-1.5 bg-slate-800 rounded-full overflow-hidden">
                            <div
                                className={`h-full rounded-full transition-all duration-300 ${velocityPercent > 80 ? 'bg-rose-500' :
                                    velocityPercent > 50 ? 'bg-amber-500' : 'bg-cyan-500'
                                    }`}
                                style={{ width: `${velocityPercent}%` }}
                            />
                        </div>
                        <span className="text-[8px] text-slate-500 w-8 text-right">{velocityPercent.toFixed(0)}%</span>
                    </div>

                    <div className="flex items-center gap-2">
                        <span className="text-[8px] text-slate-500 w-10">放量</span>
                        <div className="flex-1 h-1.5 bg-slate-800 rounded-full overflow-hidden">
                            <div
                                className={`h-full rounded-full transition-all duration-300 ${rvolPercent > 80 ? 'bg-rose-500' :
                                    rvolPercent > 50 ? 'bg-amber-500' : 'bg-emerald-500'
                                    }`}
                                style={{ width: `${rvolPercent}%` }}
                            />
                        </div>
                        <span className="text-[8px] text-slate-500 w-8 text-right">{rvolPercent.toFixed(0)}%</span>
                    </div>
                </div>

                {(smartMetrics.isVelocityWarning || smartMetrics.isRvolWarning) && (
                    <div className="mt-2 text-[9px] text-amber-400/80 flex items-center gap-1">
                        <AlertTriangle size={10} />
                        <span>
                            {smartMetrics.isVelocityWarning && smartMetrics.isRvolWarning
                                ? '⚠️ 放量快速移动，高风险'
                                : smartMetrics.isVelocityWarning
                                    ? '动量接近阈值'
                                    : '成交量放大'}
                        </span>
                    </div>
                )}
            </div>

            {/* Score Breakdown */}
            <div className="grid grid-cols-3 gap-2 mb-3">
                <div className="text-center bg-slate-900/30 rounded px-2 py-1.5 border border-slate-800/30">
                    <div className="text-[8px] text-slate-500 mb-0.5">距离分</div>
                    <div className="text-[11px] font-mono font-bold text-slate-300">
                        {smartMetrics.distanceScore.toFixed(0)}<span className="text-slate-600">/40</span>
                    </div>
                </div>
                <div className="text-center bg-slate-900/30 rounded px-2 py-1.5 border border-slate-800/30">
                    <div className="text-[8px] text-slate-500 mb-0.5">速度分</div>
                    <div className="text-[11px] font-mono font-bold text-slate-300">
                        {smartMetrics.velocityScore.toFixed(0)}<span className="text-slate-600">/30</span>
                    </div>
                </div>
                <div className="text-center bg-slate-900/30 rounded px-2 py-1.5 border border-slate-800/30">
                    <div className="text-[8px] text-slate-500 mb-0.5">层级分</div>
                    <div className="text-[11px] font-mono font-bold text-slate-300">
                        {smartMetrics.layerScore.toFixed(0)}<span className="text-slate-600">/30</span>
                    </div>
                </div>
            </div>

            {/* Risk Occupancy Bar */}
            <div className="space-y-1.5 mb-3">
                <div className="flex justify-between text-[10px] text-slate-500 font-mono">
                    <span>RISK OCCUPANCY</span>
                    <span>{riskOccupancy > 100 ? '>100%' : `${riskOccupancy.toFixed(1)}%`}</span>
                </div>
                <div className="h-1.5 w-full bg-slate-800 rounded-full overflow-hidden">
                    <div
                        className={`h-full rounded-full transition-all duration-500 ${smartMetrics.exitTrigger !== 'NONE' ? 'bg-rose-500' :
                            riskLevel === 'WARNING' ? 'bg-yellow-500' : 'bg-emerald-500'
                            }`}
                        style={{ width: `${Math.min(100, riskOccupancy)}%` }}
                    />
                </div>
            </div>

            {/* Footer */}
            <div className="flex justify-between items-center pt-2 border-t border-slate-800/50">
                <div className="flex gap-3 text-[10px] font-mono text-slate-500">
                    <span>ATR: <span className="text-slate-300">${atr ? atr.toFixed(1) : '--'}</span></span>
                    <span>NET: <span className={netLots > 0 ? 'text-emerald-400' : netLots < 0 ? 'text-rose-400' : 'text-slate-400'}>
                        {netLots.toFixed(2)}
                    </span></span>
                </div>
                <span className="text-[10px] text-slate-400 font-mono">
                    Est: <span className="text-slate-300">{survivalTime}</span>
                </span>
            </div>

            {/* Trigger Reason Bar */}
            {smartMetrics.exitTrigger !== 'NONE' && (
                <div className={`mt-3 px-3 py-2 rounded-lg text-[10px] font-medium ${triggerConfig.bgColor} ${triggerConfig.color} border ${triggerConfig.borderColor}`}>
                    {smartMetrics.triggerReason}
                </div>
            )}

            {/* Pulse Overlay for Critical States */}
            {(smartMetrics.exitTrigger === 'TACTICAL_EXIT' || smartMetrics.exitTrigger === 'FORCE_EXIT') && (
                <div className="absolute inset-0 bg-rose-500/5 pointer-events-none animate-pulse" />
            )}
        </div>
    );
};
