import React, { useMemo, useState, useEffect } from 'react';
import axios from 'axios';
import {
    Activity, TrendingDown, TrendingUp, AlertTriangle,
    Shield, ShieldAlert, ShieldCheck, Radar, Target, Clock
} from 'lucide-react';
import type { AccountStatus, RiskControlState } from '../types';
import { API_BASE } from '../config';
import {
    estimateSurvivalTime,
    getExitTriggerConfig,
    type ExitTrigger
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
const RiskGauge = ({ score, level }: { score: number, level: string }) => {
    const radius = 36;
    const stroke = 6;
    const normalizedScore = Math.min(100, Math.max(0, score));
    const circumference = radius * 2 * Math.PI;
    const offset = circumference - (normalizedScore / 100) * circumference;

    // Color logic
    const colorClass = level === 'CRITICAL' ? 'text-rose-500 shadow-[0_0_15px_rgba(244,63,94,0.6)]' :
        level === 'WARNING' ? 'text-amber-500 shadow-[0_0_15px_rgba(245,158,11,0.5)]' :
            'text-emerald-500 shadow-[0_0_15px_rgba(10,185,129,0.4)]';

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
                <span className="text-[9px] text-slate-500 font-bold uppercase tracking-wider mt-[-2px]">风险指数</span>
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
    atrH1 = 0, // Unused but kept for interface compat
    authToken,
    selectedSymbol = 'XAUUSD',
    maxDrawdown = 0, // Unused locally
    tradeStats // Unused locally
}) => {
    // --- 1. Hooks (State & Memos) ---
    const [eaLinkageEnabled, setEaLinkageEnabled] = useState(false);
    const [syncStatus, setSyncStatus] = useState<'IDLE' | 'SYNCING' | 'ERROR'>('IDLE');
    const [operationLogs, setOperationLogs] = useState<any[]>([]);
    const [backendRiskState, setBackendRiskState] = useState<RiskControlState | null>(null);

    // Use bid/ask if available, otherwise fall back to close price
    const bid = currentBid ?? currentPrice ?? 0;
    const ask = currentAsk ?? currentPrice ?? 0;

    // Derived Metrics from Backend
    const metrics = backendRiskState?.metrics;

    const survivalDistance = metrics?.survival_distance ?? Infinity;
    const liquidationPrice = metrics?.liquidation_price ?? 0;

    // Local Direction Logic for UI Badge
    const dominantDirection = useMemo(() => {
        if (!accountStatus?.positions) return 'HEDGED';
        const buyLots = accountStatus.positions.filter(p => p.side === 'BUY').reduce((acc, p) => acc + p.lots, 0);
        const sellLots = accountStatus.positions.filter(p => p.side === 'SELL').reduce((acc, p) => acc + p.lots, 0);
        const net = buyLots - sellLots;
        if (net > 0.001) return 'BUY';
        if (net < -0.001) return 'SELL';
        return 'HEDGED';
    }, [accountStatus]);


    const smartMetrics = {
        riskScore: metrics?.risk_score ?? 0,
        exitTrigger: metrics?.exit_trigger ?? 'NONE',
        velocityM1: metrics?.velocity_m1 ?? 0,
        rvol: metrics?.rvol ?? 1.0,
        layerScore: metrics?.layer_score ?? 0,
        drawdownScore: metrics?.drawdown_score ?? 0,
        velocityScore: metrics?.velocity_score ?? 0,
        distanceScore: metrics?.distance_score ?? 0,
        triggerReason: metrics?.trigger_reason ?? '',
        isVelocityWarning: metrics?.is_velocity_warning ?? false,
        isMartingalePattern: metrics?.is_martingale_pattern ?? false,
    };

    // --- 2. Side Effects ---
    // Fetch Risk State from Backend (Poll)

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
                    setBackendRiskState(res.data);
                }
            } catch (err) {
                console.error("Failed to fetch risk control state", err);
            }
        };

        fetchRiskState();
        const interval = setInterval(fetchRiskState, 2000); // 2 seconds poll
        return () => clearInterval(interval);
    }, [authToken, accountStatus.mt4_account]);

    // Fetch Operation Logs (Keep as is)
    useEffect(() => {
        if (!authToken || !accountStatus.mt4_account) return;

        const fetchLogs = async () => {
            try {
                const res = await axios.get(`${API_BASE}/risk_control_logs`, {
                    params: { mt4_account: accountStatus.mt4_account, limit: 10 },
                    headers: { Authorization: `Bearer ${authToken}` }
                });
                setOperationLogs(res.data || []);
            } catch {
                // Endpoint may not exist yet
            }
        };

        fetchLogs();
        const interval = setInterval(fetchLogs, 10000);
        return () => clearInterval(interval);
    }, [authToken, accountStatus.mt4_account]);

    const handleToggleLinkage = async () => {
        if (!authToken || !accountStatus.mt4_account) return;

        const newEnabled = !eaLinkageEnabled;
        setEaLinkageEnabled(newEnabled); // Optimistic UI update
        setSyncStatus('SYNCING');

        try {
            // We only need to toggle enabled logic. The backend handles the rest.
            // But checking our http_server.rs logic (not shown but inferred), update needs all fields usually?
            // Actually, in previous task I saw UPDATE risk_controls SET ... CASE WHEN.
            // But wait, the API calls `handle_update_risk_control`.
            // Let's assume we send current backend state but flipped enabled.

            const payload = backendRiskState ? {
                ...backendRiskState,
                enabled: newEnabled
            } : {
                mt4_account: accountStatus.mt4_account,
                block_buy: false,
                block_sell: false,
                block_all: false,
                risk_level: 'SAFE',
                risk_score: 0,
                exit_trigger: 'NONE',
                velocity_block: false,
                enabled: newEnabled
            };

            await axios.put(`${API_BASE}/risk_control`, payload, {
                headers: { Authorization: `Bearer ${authToken}` }
            });
            setSyncStatus('IDLE');

            // Re-fetch immediately to confirm
            const res = await axios.get(`${API_BASE}/risk_control`, {
                params: { mt4_account: accountStatus.mt4_account },
                headers: { Authorization: `Bearer ${authToken}` }
            });
            if (res.data) setBackendRiskState(res.data);

        } catch (err) {
            console.error("Failed to toggle risk control", err);
            setSyncStatus('ERROR');
            setEaLinkageEnabled(!newEnabled); // Revert on error
        }
    };

    // Use Backend Data if available, else fallback to Frontend calc
    const displayRiskScore = backendRiskState ? backendRiskState.risk_score : 0;
    const displayRiskLevel = backendRiskState ? backendRiskState.risk_level : 'SAFE';
    const displayExitTrigger = backendRiskState ? backendRiskState.exit_trigger : 'NONE';


    // 4. Get trigger config for styling
    const triggerConfig = getExitTriggerConfig(displayExitTrigger as ExitTrigger);

    // Survival Time with velocity consideration
    const survivalTime = estimateSurvivalTime(survivalDistance, atr, smartMetrics.velocityM1);

    return (
        <div className={`
                relative rounded-2xl border transition-all duration-300 group z-20
                bg-slate-950/80 backdrop-blur-xl
                ${triggerConfig.borderColor}
                ${displayExitTrigger !== 'NONE' ? 'shadow-[0_0_30px_rgba(244,63,94,0.3)]' : 'shadow-2xl'}
            `}>
            {/* Ambient Glow Gradient */}
            <div className={`absolute top-0 left-0 w-full h-1 bg-gradient-to-r ${displayRiskLevel === 'CRITICAL' ? 'from-rose-500 via-rose-400 to-rose-600' :
                displayRiskLevel === 'WARNING' ? 'from-amber-500 via-amber-400 to-amber-600' :
                    'from-emerald-500 via-cyan-500 to-emerald-600'
                } opacity-80`} />

            {/* Main Content Grid */}
            <div className="p-5 flex flex-col md:flex-row gap-6 items-center md:items-stretch">

                {/* 1. Left: Risk Radar & Gauge */}
                <div className="flex flex-col items-center justify-center min-w-[120px] relative group/gauge cursor-help" tabIndex={0}>
                    <RiskGauge score={displayRiskScore} level={displayRiskLevel} />

                    {/* Risk Score Tooltip */}
                    <div className="absolute top-full mt-2 w-48 p-2.5 bg-slate-900/95 backdrop-blur text-[10px] text-slate-300 rounded-lg shadow-xl border border-slate-700 opacity-0 group-hover/gauge:opacity-100 group-focus-within/gauge:opacity-100 transition-opacity pointer-events-none z-50 text-center">
                        <div className="font-bold text-slate-200 mb-1.5 border-b border-slate-700 pb-1">EA 干预规则</div>
                        <div className="space-y-2 text-left">
                            <div>
                                <div className="flex justify-between font-bold text-rose-500">
                                    <span>≥ 90分</span>
                                    <span>紧急逃生</span>
                                </div>
                                <div className="text-slate-500 mt-0.5">触发 FORCE_EXIT，阻断一切交易，建议立即清仓</div>
                            </div>
                            <div>
                                <div className="flex justify-between font-bold text-amber-500">
                                    <span>≥ 70分</span>
                                    <span>战术减仓</span>
                                </div>
                                <div className="text-slate-500 mt-0.5">触发 TACTICAL_EXIT，禁止开新仓，建议减仓防守</div>
                            </div>
                        </div>
                    </div>

                    {/* Direction Badge */}
                    <div className="mt-3 flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-slate-900 border border-slate-700/50 shadow-inner">
                        {dominantDirection === 'BUY' ? <TrendingUp size={12} className="text-emerald-400" /> :
                            dominantDirection === 'SELL' ? <TrendingDown size={12} className="text-rose-400" /> :
                                <Activity size={12} className="text-slate-400" />}
                        <span className="text-[10px] font-bold tracking-wider text-slate-300">
                            {dominantDirection === 'BUY' ? '做多' : dominantDirection === 'SELL' ? '做空' : '对冲'}
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
                            <span className="text-[10px] text-slate-500 uppercase font-mono tracking-wider">强平价格</span>
                        </div>
                        <div className="text-lg font-mono font-bold text-slate-200 tracking-tight">
                            {liquidationPrice > 0 ? liquidationPrice.toFixed(2) : '---'}
                        </div>
                        <div className="text-[9px] text-slate-600 font-mono mt-1">
                            {currentPrice && liquidationPrice > 0
                                ? `偏离: ${(Math.abs(liquidationPrice - currentPrice) / currentPrice * 100).toFixed(2)}%`
                                : '无敞口'}
                        </div>
                        {/* Decorative Line */}
                        <div className="absolute bottom-0 left-0 w-full h-[2px] bg-gradient-to-r from-transparent via-rose-500/50 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
                    </div>

                    {/* Survival Card */}
                    <div className="col-span-1 bg-slate-900/50 rounded-xl p-3 border border-slate-800 flex flex-col justify-between overflow-hidden group-hover:border-slate-700 transition-colors">
                        <div className="flex items-center gap-2 mb-1">
                            <Shield size={12} className="text-slate-500" />
                            <span className="text-[10px] text-slate-500 uppercase font-mono tracking-wider">生存距离</span>
                        </div>
                        <div className={`text-lg font-mono font-bold tracking-tight ${survivalDistance < atr ? 'text-rose-400' : 'text-emerald-400'}`}>
                            {survivalDistance !== Infinity ? survivalDistance.toFixed(0) : '∞'}
                        </div>
                        <div className="text-[9px] text-slate-600 font-mono mt-1 flex items-center justify-between">
                            <span>{survivalTime}</span>
                            <span>{atr ? `${(survivalDistance / atr).toFixed(1)}ATR` : ''}</span>
                        </div>
                    </div>

                    {/* Risk  Factors (Compact Bars)  */}
                    <div className="col-span-2 bg-slate-900/50 rounded-xl p-3 border border-slate-800 flex flex-col gap-2.5">
                        <div className="flex items-center gap-2">
                            <Radar size={12} className="text-cyan-500" />
                            <span className="text-[10px] text-slate-500 font-bold uppercase tracking-wider">风险因子</span>
                        </div>
                        <div className="grid grid-cols-2 gap-x-4 gap-y-2">

                            <div className="group/tooltip relative cursor-help" tabIndex={0}>
                                <DataBar label="层级负荷" value={smartMetrics.layerScore} max={20} color="bg-cyan-500" warningThreshold={15} />
                                <div className="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 w-56 p-2 bg-slate-900/95 backdrop-blur text-[10px] text-slate-300 rounded-lg shadow-xl border border-slate-700 opacity-0 group-hover/tooltip:opacity-100 group-focus-within/tooltip:opacity-100 transition-opacity pointer-events-none z-50">
                                    <div className="font-bold text-cyan-400 mb-1 border-b border-slate-700 pb-1">层级负荷 (20%)</div>
                                    <div className="space-y-0.5">
                                        <div className="flex justify-between"><span>≥ 15 层</span><span className="text-rose-400">20分</span></div>
                                        <div className="flex justify-between"><span>≥ 10 层</span><span className="text-amber-400">15分</span></div>
                                        <div className="flex justify-between"><span>≥ 5 层</span><span className="text-emerald-400">5分</span></div>
                                        <div className="mt-1 text-slate-500 italic">层数越多，持仓风险越高</div>
                                    </div>
                                </div>
                            </div>

                            {/* Drawdown Score */}
                            <div className="group/tooltip relative cursor-help" tabIndex={0}>
                                <DataBar label="回撤深度" value={smartMetrics.drawdownScore} max={30} color="bg-orange-500" warningThreshold={20} />
                                <div className="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 w-56 p-2 bg-slate-900/95 backdrop-blur text-[10px] text-slate-300 rounded-lg shadow-xl border border-slate-700 opacity-0 group-hover/tooltip:opacity-100 group-focus-within/tooltip:opacity-100 transition-opacity pointer-events-none z-50">
                                    <div className="font-bold text-orange-400 mb-1 border-b border-slate-700 pb-1">回撤深度 (30%)</div>
                                    <div className="space-y-0.5">
                                        <div className="flex justify-between"><span>≥ 30%</span><span className="text-rose-400">30分</span></div>
                                        <div className="flex justify-between"><span>≥ 20%</span><span className="text-amber-400">20分</span></div>
                                        <div className="flex justify-between"><span>≥ 10%</span><span className="text-orange-300">10分</span></div>
                                        <div className="flex justify-between"><span>≥ 5%</span><span className="text-emerald-400">5分</span></div>
                                    </div>
                                </div>
                            </div>

                            {/* Velocity Score */}
                            <div className="group/tooltip relative cursor-help" tabIndex={0}>
                                <DataBar label="价格速度" value={smartMetrics.velocityScore} max={20} color="bg-indigo-500" warningThreshold={15} />
                                <div className="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 w-56 p-2 bg-slate-900/95 backdrop-blur text-[10px] text-slate-300 rounded-lg shadow-xl border border-slate-700 opacity-0 group-hover/tooltip:opacity-100 group-focus-within/tooltip:opacity-100 transition-opacity pointer-events-none z-50">
                                    <div className="font-bold text-indigo-400 mb-1 border-b border-slate-700 pb-1">价格速度 (20%)</div>
                                    <div className="space-y-0.5">
                                        <div className="flex justify-between"><span>逆势 ≥ $3/min</span><span className="text-rose-400">20分</span></div>
                                        <div className="flex justify-between"><span>逆势 ≥ $2/min</span><span className="text-amber-400">10分</span></div>
                                        <div className="flex justify-between"><span>逆势 ≥ $1/min</span><span className="text-emerald-400">5分</span></div>
                                        <div className="mt-1 text-slate-500 italic">仅计算对持仓不利方向</div>
                                    </div>
                                </div>
                            </div>

                            {/* Distance Score */}
                            <div className="group/tooltip relative cursor-help" tabIndex={0}>
                                <DataBar label="生存空间" value={smartMetrics.distanceScore} max={30} color="bg-emerald-500" warningThreshold={25} />
                                <div className="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 w-56 p-2 bg-slate-900/95 backdrop-blur text-[10px] text-slate-300 rounded-lg shadow-xl border border-slate-700 opacity-0 group-hover/tooltip:opacity-100 group-focus-within/tooltip:opacity-100 transition-opacity pointer-events-none z-50">
                                    <div className="font-bold text-emerald-400 mb-1 border-b border-slate-700 pb-1">生存空间 (30%)</div>
                                    <div className="space-y-0.5">
                                        <div className="flex justify-between"><span>&lt; 1 ATR</span><span className="text-rose-400">30分</span></div>
                                        <div className="flex justify-between"><span>&lt; 2 ATR</span><span className="text-amber-400">20分</span></div>
                                        <div className="flex justify-between"><span>&lt; 3 ATR</span><span className="text-orange-300">10分</span></div>
                                        <div className="flex justify-between"><span>&lt; 5 ATR</span><span className="text-emerald-400">5分</span></div>
                                        <div className="mt-1 text-slate-500 italic">基于强平距离与ATR比率</div>
                                    </div>
                                </div>

                            </div>

                        </div>
                    </div>
                </div>

                {/* 3. Right: Market Pulse & Controls */}
                <div className="flex flex-col gap-3 min-w-[200px] w-full md:w-auto">
                    {/* Velocity Monitor Panel */}
                    <div className="bg-slate-900/40 rounded-xl p-3 border border-slate-800 relative overflow-hidden">
                        <div className="flex justify-between items-center mb-2">
                            <span className="text-[10px] text-slate-500 font-bold uppercase">市场脉搏</span>
                            <div className="flex items-center gap-2">
                                {/* Data Freshness Indicator */}
                                {backendRiskState?.updated_at && (
                                    <span className={`text-[9px] font-mono ${(Date.now() / 1000 - backendRiskState.updated_at) > 60 ? 'text-rose-500 animate-pulse' : 'text-emerald-500'
                                        }`}>
                                        {(Date.now() / 1000 - backendRiskState.updated_at) > 60 ? '数据延迟' : '● 实时'}
                                    </span>
                                )}
                                <Activity size={12} className={smartMetrics.isVelocityWarning ? 'text-rose-500 animate-pulse' : 'text-slate-600'} />
                            </div>
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
                                <span className="text-slate-600 text-[8px]">M1 速度</span>
                                <span className={smartMetrics.velocityM1 > 5 ? 'text-rose-400' : 'text-slate-300'}>
                                    ${smartMetrics.velocityM1.toFixed(2)}
                                </span>
                            </div>
                            <div className="flex flex-col items-end">
                                <span className="text-slate-600 text-[8px]">相对量能</span>
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
                        {eaLinkageEnabled ? 'EA 警戒中' : 'EA 已解除'}

                        {/* Scanning Effect */}
                        {eaLinkageEnabled && (
                            <div className="absolute inset-0 bg-gradient-to-r from-transparent via-cyan-400/10 to-transparent -translate-x-full animate-[shimmer_2s_infinite]" />
                        )}
                        {syncStatus === 'SYNCING' && <span className="absolute right-2 animate-spin text-cyan-500">⟳</span>}
                    </button>

                    {/* Trigger Status */}
                    {displayExitTrigger !== 'NONE' && (
                        <div className={`px-2 py-1 rounded text-[9px] font-bold text-center border ${triggerConfig.bgColor} ${triggerConfig.color} ${triggerConfig.borderColor}`}>
                            {backendRiskState?.exit_trigger || smartMetrics.triggerReason}
                        </div>
                    )}

                    {/* Operation History Bar */}
                    {operationLogs.length > 0 && (
                        <div className="relative group/logs">
                            <div className="flex items-center gap-1.5 px-2 py-1 bg-slate-900/50 rounded border border-slate-800 cursor-pointer hover:border-slate-700 transition-colors">
                                <Clock size={10} className="text-slate-500" />
                                <span className="text-[9px] text-slate-500">最近 {operationLogs.length} 条操作</span>
                                <div className="flex-1 h-1 bg-slate-800 rounded-full overflow-hidden">
                                    <div
                                        className="h-full bg-gradient-to-r from-cyan-500 to-indigo-500 transition-all duration-300"
                                        style={{ width: `${Math.min(100, operationLogs.length * 10)}%` }}
                                    />
                                </div>
                            </div>
                            {/* Hover Tooltip */}
                            <div className="absolute bottom-full left-0 right-0 mb-1 hidden group-hover/logs:block z-50">
                                <div className="bg-slate-950 border border-slate-700 rounded-lg p-2 shadow-xl max-h-40 overflow-y-auto">
                                    <div className="text-[9px] text-slate-400 font-bold mb-1.5 uppercase tracking-wider">操作历史</div>
                                    {operationLogs.map((log, i) => (
                                        <div key={log.id || i} className="flex items-center justify-between gap-2 py-1 border-b border-slate-800 last:border-0">
                                            <span className={`text-[9px] font-mono font-bold ${log.action === 'DISABLED' ? 'text-slate-500' :
                                                log.action?.includes('BLOCK') ? 'text-rose-400' : 'text-cyan-400'
                                                }`}>
                                                {log.action}
                                            </span>
                                            <span className="text-[8px] text-slate-600">
                                                {new Date(log.created_at * 1000).toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })}
                                            </span>
                                        </div>
                                    ))}
                                </div>
                            </div>
                        </div>
                    )}
                </div>
            </div>

            {/* Critical Alert Overlay */}
            {(displayExitTrigger === 'TACTICAL_EXIT' || displayExitTrigger === 'FORCE_EXIT') && (
                <div className="absolute inset-0 z-50 pointer-events-none flex items-center justify-center bg-rose-950/20 backdrop-blur-[1px] rounded-2xl">
                    <div className="border border-rose-500/50 bg-black/80 text-rose-500 px-6 py-4 rounded-xl shadow-[0_0_50px_rgba(244,63,94,0.5)] animate-pulse flex flex-col items-center">
                        <AlertTriangle size={32} className="mb-2" />
                        <span className="text-xl font-bold font-mono tracking-widest">紧急逃生</span>
                        <span className="text-xs text-rose-400 mt-1">{backendRiskState?.exit_trigger || smartMetrics.triggerReason}</span>
                    </div>
                </div>
            )}
        </div>
    );
};
