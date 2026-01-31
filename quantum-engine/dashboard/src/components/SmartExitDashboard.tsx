import React, { useMemo, useState, useEffect } from 'react';
import axios from 'axios';
import {
    Activity, TrendingDown, TrendingUp, AlertTriangle,
    Shield, ShieldAlert, ShieldCheck, Radar, Target
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
    maxDrawdown?: number;
    tradeStats?: { winRate: number; profitFactor: number; avgWin: number; avgLoss: number };
}

// ✨ Quantum HUD Components
const RiskGauge = ({ score, level }: { score: number, level: RiskLevel }) => {
    const radius = 36;
    const stroke = 6;
    const normalizedScore = Math.min(100, Math.max(0, score));
    const circumference = radius * 2 * Math.PI;
    const offset = circumference - (normalizedScore / 100) * circumference;

    // Color logic
    const colorClass = level === 'CRITICAL' ? 'text-rose-500 shadow-[0_0_15px_rgba(244,63,94,0.6)]' :
        level === 'WARNING' ? 'text-amber-500 shadow-[0_0_15px_rgba(245,158,11,0.5)]' :
            'text-emerald-500 shadow-[0_0_15px_rgba(16,185,129,0.4)]';

    return (
        <div className="relative w-24 h-24 flex items-center justify-center">
            {/* Background Ring */}
            <svg className="transform -rotate-90 w-full h-full drop-shadow-xl">
                <circle
                    className="text-slate-800"
                    strokeWidth={stroke}
                    stroke="currentColor"
                    fill="transparent"
                    r={radius}
                    cx="50%"
                    cy="50%"
                />
                {/* Progress Ring */}
                <circle
                    className={`${colorClass} transition-all duration-1000 ease-out`}
                    strokeWidth={stroke}
                    strokeDasharray={circumference}
                    strokeDashoffset={offset}
                    strokeLinecap="round"
                    stroke="currentColor"
                    fill="transparent"
                    r={radius}
                    cx="50%"
                    cy="50%"
                />
            </svg>
            {/* Center Text */}
            <div className="absolute inset-0 flex flex-col items-center justify-center z-10">
                <span className={`text-2xl font-bold font-mono tracking-tighter ${level === 'CRITICAL' ? 'text-rose-400' : level === 'WARNING' ? 'text-amber-400' : 'text-emerald-400'
                    }`}>
                    {score.toFixed(0)}
                </span>
                <span className="text-[9px] text-slate-500 font-bold uppercase tracking-wider mt-[-2px]">RISK</span>
            </div>
            {/* Holographic Bloom */}
            <div className={`absolute inset-0 rounded-full blur-xl opacity-20 ${level === 'CRITICAL' ? 'bg-rose-500' : level === 'WARNING' ? 'bg-amber-500' : 'bg-emerald-500'
                }`} />
        </div>
    );
};

const DataBar = ({ label, value, max = 100, color = 'bg-cyan-500', warningThreshold = 80 }: any) => {
    const percent = Math.min(100, Math.max(0, (value / max) * 100));
    const isWarning = percent > warningThreshold;
    const finalColor = isWarning ? 'bg-rose-500' : color;

    return (
        <div className="flex flex-col gap-1 w-full">
            <div className="flex justify-between items-end">
                <span className="text-[10px] text-slate-500 font-mono tracking-wider uppercase">{label}</span>
                <span className={`text-[10px] font-bold font-mono ${isWarning ? 'text-rose-400' : 'text-slate-300'}`}>
                    {value.toFixed(0)}<span className="text-[8px] text-slate-600">/{max}</span>
                </span>
            </div>
            <div className="h-1.5 w-full bg-slate-800/50 rounded-sm overflow-hidden border border-slate-800">
                <div
                    className={`h-full ${finalColor} shadow-[0_0_8px_currentColor] transition-all duration-500`}
                    style={{ width: `${percent}%` }}
                />
            </div>
        </div>
    );
};

export const SmartExitDashboard: React.FC<SmartExitDashboardProps> = ({
    accountStatus,
    currentPrice,
    currentBid,
    currentAsk,
    symbolInfo,
    atr,
    atrH1 = 0,
    authToken,
    selectedSymbol = 'XAUUSD',
    maxDrawdown = 0,
    tradeStats
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
        survivalDistance,
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
            SMART_EXIT_CONFIG.DEFAULT_MAX_LAYER,
            maxDrawdown,
            tradeStats
        );

        return {
            ...metrics,
            liquidationPrice
        };
    }, [survivalDistance, atr, velocityData, accountStatus.positions, liquidationPrice, maxDrawdown, tradeStats]);

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
        if (!hasUserToggled || !authToken || !accountStatus.mt4_account) return;

        const syncToBackend = async () => {
            setSyncStatus('SYNCING');
            try {
                let blockBuy = false;
                let blockSell = false;
                let blockAll = false;

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

    // Survival Time with velocity consideration
    const survivalTime = estimateSurvivalTime(survivalDistance, atr, smartMetrics.velocityM1);

    return (
        <div className={`
                relative overflow-hidden rounded-2xl border transition-all duration-300 group
                bg-slate-950/80 backdrop-blur-xl
                ${triggerConfig.borderColor}
                ${smartMetrics.exitTrigger !== 'NONE' ? 'shadow-[0_0_30px_rgba(244,63,94,0.3)]' : 'shadow-2xl'}
            `}>
            {/* Ambient Glow Gradient */}
            <div className={`absolute top-0 left-0 w-full h-1 bg-gradient-to-r ${riskLevel === 'CRITICAL' ? 'from-rose-500 via-rose-400 to-rose-600' :
                    riskLevel === 'WARNING' ? 'from-amber-500 via-amber-400 to-amber-600' :
                        'from-emerald-500 via-cyan-500 to-emerald-600'
                } opacity-80`} />

            {/* Main Content Grid */}
            <div className="p-5 flex flex-col md:flex-row gap-6 items-center md:items-stretch">

                {/* 1. Left: Risk Radar & Gauge */}
                <div className="flex flex-col items-center justify-center min-w-[120px] relative">
                    <RiskGauge score={smartMetrics.riskScore} level={riskLevel} />

                    {/* Direction Badge */}
                    <div className="mt-3 flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-slate-900 border border-slate-700/50 shadow-inner">
                        {dominantDirection === 'BUY' ? <TrendingUp size={12} className="text-emerald-400" /> :
                            dominantDirection === 'SELL' ? <TrendingDown size={12} className="text-rose-400" /> :
                                <Activity size={12} className="text-slate-400" />}
                        <span className="text-[10px] font-bold tracking-wider text-slate-300">
                            {dominantDirection === 'BUY' ? 'LONG' : dominantDirection === 'SELL' ? 'SHORT' : 'HEDGE'}
                        </span>
                    </div>

                    {/* Martingale Warning Badge */}
                    {smartMetrics.isMartingalePattern && (
                        <div className="absolute -top-2 -right-2 animate-pulse">
                            <div className="bg-amber-950/90 text-amber-500 border border-amber-500/50 p-1 rounded-md shadow-[0_0_10px_rgba(245,158,11,0.3)]">
                                <AlertTriangle size={14} />
                            </div>
                        </div>
                    )}
                </div>

                {/* 2. Middle: Critical Telemetry */}
                <div className="flex-1 w-full grid grid-cols-2 gap-3 min-w-[240px]">
                    {/* Liquidation Card */}
                    <div className="col-span-1 bg-slate-900/50 rounded-xl p-3 border border-slate-800 flex flex-col justify-between relative overflow-hidden group-hover:border-slate-700 transition-colors">
                        <div className="flex items-center gap-2 mb-1">
                            <Target size={12} className="text-slate-500" />
                            <span className="text-[10px] text-slate-500 uppercase font-mono tracking-wider">Liquidation</span>
                        </div>
                        <div className="text-lg font-mono font-bold text-slate-200 tracking-tight">
                            {liquidationPrice > 0 ? liquidationPrice.toFixed(2) : '---'}
                        </div>
                        <div className="text-[9px] text-slate-600 font-mono mt-1">
                            {currentPrice && liquidationPrice > 0
                                ? `Gap: ${(Math.abs(liquidationPrice - currentPrice) / currentPrice * 100).toFixed(2)}%`
                                : 'No Exposure'}
                        </div>
                        {/* Decorative Line */}
                        <div className="absolute bottom-0 left-0 w-full h-[2px] bg-gradient-to-r from-transparent via-rose-500/50 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
                    </div>

                    {/* Survival Card */}
                    <div className="col-span-1 bg-slate-900/50 rounded-xl p-3 border border-slate-800 flex flex-col justify-between overflow-hidden group-hover:border-slate-700 transition-colors">
                        <div className="flex items-center gap-2 mb-1">
                            <Shield size={12} className="text-slate-500" />
                            <span className="text-[10px] text-slate-500 uppercase font-mono tracking-wider">Distance</span>
                        </div>
                        <div className={`text-lg font-mono font-bold tracking-tight ${survivalDistance < atr ? 'text-rose-400' : 'text-emerald-400'}`}>
                            {survivalDistance !== Infinity ? survivalDistance.toFixed(0) : '∞'}
                        </div>
                        <div className="text-[9px] text-slate-600 font-mono mt-1 flex items-center justify-between">
                            <span>{survivalTime}</span>
                            <span>{atr ? `${(survivalDistance / atr).toFixed(1)}ATR` : ''}</span>
                        </div>
                    </div>

                    {/* Risk Factors (Compact Bars) */}
                    <div className="col-span-2 bg-slate-900/50 rounded-xl p-3 border border-slate-800 flex flex-col gap-2.5">
                        <div className="flex items-center gap-2">
                            <Radar size={12} className="text-cyan-500" />
                            <span className="text-[10px] text-slate-500 font-bold uppercase tracking-wider">Risk Factors</span>
                        </div>
                        <div className="grid grid-cols-2 gap-x-4 gap-y-2">
                            <DataBar label="LAYER LOAD" value={smartMetrics.layerScore} max={20} color="bg-cyan-500" warningThreshold={15} />
                            <DataBar label="DRAWDOWN" value={smartMetrics.drawdownScore} max={30} color="bg-orange-500" warningThreshold={20} />
                            <DataBar label="VELOCITY" value={smartMetrics.velocityScore} max={20} color="bg-indigo-500" warningThreshold={15} />
                            <DataBar label="DISTANCE" value={smartMetrics.distanceScore} max={30} color="bg-emerald-500" warningThreshold={25} />
                        </div>
                    </div>
                </div>

                {/* 3. Right: Market Pulse & Controls */}
                <div className="flex flex-col gap-3 min-w-[200px] w-full md:w-auto">
                    {/* Velocity Monitor Panel */}
                    <div className="bg-slate-900/40 rounded-xl p-3 border border-slate-800 relative overflow-hidden">
                        <div className="flex justify-between items-center mb-2">
                            <span className="text-[10px] text-slate-500 font-bold uppercase">Market Pulse</span>
                            <Activity size={12} className={smartMetrics.isVelocityWarning ? 'text-rose-500 animate-pulse' : 'text-slate-600'} />
                        </div>

                        {/* Fake Waveform Visual (CSS) */}
                        <div className="flex items-end justify-between h-8 gap-0.5 opacity-50 mb-2">
                            {[...Array(10)].map((_, i) => (
                                <div key={i}
                                    className={`w-1.5 rounded-t-sm transition-all duration-300 ${smartMetrics.velocityM1 > 0 ? 'bg-emerald-500' : 'bg-rose-500'}`}
                                    style={{ height: `${20 + Math.random() * 60}%` }}
                                />
                            ))}
                        </div>

                        <div className="flex justify-between text-[10px] font-mono border-t border-slate-800/50 pt-1.5">
                            <div className="flex flex-col">
                                <span className="text-slate-600 text-[8px]">M1 Velo</span>
                                <span className={smartMetrics.velocityM1 > 5 ? 'text-rose-400' : 'text-slate-300'}>
                                    ${smartMetrics.velocityM1.toFixed(2)}
                                </span>
                            </div>
                            <div className="flex flex-col items-end">
                                <span className="text-slate-600 text-[8px]">RVOL</span>
                                <span className={smartMetrics.rvol > 2 ? 'text-amber-400' : 'text-slate-300'}>
                                    {smartMetrics.rvol.toFixed(1)}x
                                </span>
                            </div>
                        </div>
                    </div>

                    {/* Action Button (Tactical Switch) */}
                    <button
                        onClick={handleToggleLinkage}
                        className={`
                            relative overflow-hidden w-full py-2.5 rounded-lg border flex items-center justify-center gap-2
                            transition-all duration-300 text-xs font-bold tracking-wider uppercase group/btn
                            ${eaLinkageEnabled
                                ? 'bg-cyan-500/10 border-cyan-500/40 text-cyan-400 shadow-[0_0_15px_rgba(6,182,212,0.15)] hover:bg-cyan-500/20'
                                : 'bg-slate-800 border-slate-700 text-slate-500 hover:bg-slate-800/80 hover:text-slate-400'}
                        `}
                    >
                        {eaLinkageEnabled ? <ShieldCheck size={14} /> : <ShieldAlert size={14} />}
                        {eaLinkageEnabled ? 'EA ARMED' : 'EA DISARMED'}

                        {/* Scanning Effect */}
                        {eaLinkageEnabled && (
                            <div className="absolute inset-0 bg-gradient-to-r from-transparent via-cyan-400/10 to-transparent -translate-x-full animate-[shimmer_2s_infinite]" />
                        )}
                        {syncStatus === 'SYNCING' && <span className="absolute right-2 animate-spin text-cyan-500">⟳</span>}
                    </button>

                    {/* Trigger Status */}
                    {smartMetrics.exitTrigger !== 'NONE' && (
                        <div className={`px-2 py-1 rounded text-[9px] font-bold text-center border ${triggerConfig.bgColor} ${triggerConfig.color} ${triggerConfig.borderColor}`}>
                            {smartMetrics.triggerReason}
                        </div>
                    )}
                </div>
            </div>

            {/* Critical Alert Overlay */}
            {(smartMetrics.exitTrigger === 'TACTICAL_EXIT' || smartMetrics.exitTrigger === 'FORCE_EXIT') && (
                <div className="absolute inset-0 z-50 pointer-events-none flex items-center justify-center bg-rose-950/20 backdrop-blur-[1px]">
                    <div className="border border-rose-500/50 bg-black/80 text-rose-500 px-6 py-4 rounded-xl shadow-[0_0_50px_rgba(244,63,94,0.5)] animate-pulse flex flex-col items-center">
                        <AlertTriangle size={32} className="mb-2" />
                        <span className="text-xl font-bold font-mono tracking-widest">CRITICAL EXIT</span>
                        <span className="text-xs text-rose-400 mt-1">{smartMetrics.triggerReason}</span>
                    </div>
                </div>
            )}
        </div>
    );
};
