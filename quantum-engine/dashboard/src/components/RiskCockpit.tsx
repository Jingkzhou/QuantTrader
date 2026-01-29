import React, { useState, useEffect } from 'react';
import { ShieldAlert, Info, TrendingDown, Clock, Activity, Skull } from 'lucide-react';
import type { AccountStatus } from '../types';
import { calculateLiquidationPrice, calculateRiskScore } from '../utils/riskCalculations';

interface RiskCockpitProps {
    accountStatus: AccountStatus;
    currentPrice: number | null;
    symbolInfo: { contractSize: number; stopOutLevel: number; tickValue: number };
    atr: number; // Daily ATR
}

export const RiskCockpit: React.FC<RiskCockpitProps> = ({ accountStatus, currentPrice, symbolInfo, atr }) => {
    const [simulationDrop, setSimulationDrop] = useState(0);
    const [riskScore, setRiskScore] = useState(0);
    const [liquidationPrice, setLiquidationPrice] = useState(0);
    const [timeToDeath, setTimeToDeath] = useState<string>('--');

    useEffect(() => {
        if (currentPrice && accountStatus) {
            const liq = calculateLiquidationPrice(accountStatus, currentPrice, symbolInfo);
            setLiquidationPrice(liq);

            const score = calculateRiskScore(accountStatus, liq, currentPrice, atr, symbolInfo);
            setRiskScore(score);

            // Time to death estimation
            // Speed = ATR / 24h roughly? Or calculate based on recent volatility?
            // Simple heuristic: If price < Liq and trend is down...
            if (liq > 0 && atr > 0) {
                const dist = Math.abs(currentPrice - liq);
                const atrPerHour = atr / 24;
                const hours = dist / (atrPerHour * 1.5); // 1.5x accelerated
                if (hours < 1) setTimeToDeath(`< ${Math.ceil(hours * 60)}m`);
                else if (hours > 24) setTimeToDeath('> 24h');
                else setTimeToDeath(`~${hours.toFixed(1)}h`);
            }
        }
    }, [accountStatus, currentPrice, symbolInfo, atr]);

    // Simulation Logic
    const simulatedPrice = currentPrice ? currentPrice - simulationDrop : 0;
    // TODO: Add full simulation calc logic here or reuse utils

    // Color logic
    const getScoreColor = (score: number) => {
        if (score < 40) return 'text-emerald-500';
        if (score < 70) return 'text-yellow-500';
        if (score < 90) return 'text-orange-500';
        return 'text-rose-600 animate-pulse';
    };

    const getScoreBg = (score: number) => {
        if (score < 40) return 'bg-emerald-500';
        if (score < 70) return 'bg-yellow-500';
        if (score < 90) return 'bg-orange-500';
        return 'bg-rose-600';
    };

    return (
        <div className="bg-slate-900/50 border border-slate-800 rounded-2xl p-6 relative overflow-hidden group">
            <div className="absolute top-0 right-0 p-4 opacity-10 group-hover:opacity-20 transition-opacity">
                <ShieldAlert className="w-24 h-24 text-slate-500" />
            </div>

            <div className="flex items-center justify-between mb-6 relative z-10">
                <h3 className="text-lg font-bold text-white flex items-center gap-2">
                    <Activity className="w-5 h-5 text-cyan-500" />
                    风控驾驶舱 <span className="text-xs font-mono text-slate-500 ml-2 bg-slate-950 px-2 py-0.5 rounded border border-slate-800">24H RISK</span>
                </h3>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-8 relative z-10">
                {/* Left: Gauge & Score */}
                <div className="flex flex-col items-center justify-center relative">
                    <div className="relative w-40 h-40">
                        <svg className="w-full h-full transform -rotate-90" viewBox="0 0 100 100">
                            {/* Track */}
                            <circle cx="50" cy="50" r="45" fill="none" stroke="#1e293b" strokeWidth="8" />
                            {/* Progress */}
                            <circle cx="50" cy="50" r="45" fill="none" stroke="currentColor" strokeWidth="8"
                                strokeDasharray={`${riskScore * 2.83} 283`}
                                strokeLinecap="round"
                                className={`${getScoreColor(riskScore)} transition-all duration-1000 ease-out`}
                            />
                        </svg>
                        <div className="absolute inset-0 flex flex-col items-center justify-center">
                            <span className={`text-4xl font-bold font-mono ${getScoreColor(riskScore)}`}>
                                {Math.round(riskScore)}
                            </span>
                            <span className="text-[10px] uppercase text-slate-500 font-bold tracking-wider">Risk Index</span>
                        </div>
                    </div>

                    <div className="mt-4 grid grid-cols-2 gap-4 w-full">
                        <div className="bg-slate-950/50 rounded-lg p-3 text-center border border-slate-800/50">
                            <div className="text-xs text-slate-500 mb-1">生存倒计时</div>
                            <div className="text-sm font-mono font-bold text-rose-400 flex items-center justify-center gap-1">
                                <Clock className="w-3 h-3" /> {timeToDeath}
                            </div>
                        </div>
                        <div className="bg-slate-950/50 rounded-lg p-3 text-center border border-slate-800/50">
                            <div className="text-xs text-slate-500 mb-1">爆仓价格</div>
                            <div className="text-sm font-mono font-bold text-rose-500 flex items-center justify-center gap-1">
                                <Skull className="w-3 h-3" /> {liquidationPrice > 0 ? liquidationPrice.toFixed(2) : '---'}
                            </div>
                        </div>
                    </div>
                </div>

                {/* Right: Simulation */}
                <div className="space-y-4">
                    <div className="flex justify-between items-center text-xs font-bold uppercase tracking-widest text-slate-500">
                        <span>情景推演 (Simulation)</span>
                        <TrendingDown className="w-4 h-4" />
                    </div>

                    <div className="bg-slate-950 rounded-xl p-4 border border-slate-800">
                        <div className="flex justify-between mb-2 text-sm">
                            <span className="text-slate-400">假设金价下跌</span>
                            <span className="font-mono font-bold text-cyan-400">${simulationDrop}</span>
                        </div>
                        <input
                            type="range"
                            min="0" max="50" step="1"
                            value={simulationDrop}
                            onChange={(e) => setSimulationDrop(Number(e.target.value))}
                            className="w-full h-1 bg-slate-800 rounded-lg appearance-none cursor-pointer accent-cyan-500"
                        />
                        <div className="flex justify-between mt-1 text-[10px] text-slate-600 font-mono">
                            <span>$0</span>
                            <span>$50</span>
                        </div>
                    </div>

                    {/* Simulated Metrics */}
                    <div className="space-y-2">
                        <div className="flex justify-between items-center p-2 rounded bg-slate-800/20 text-xs">
                            <span className="text-slate-400">预计浮亏</span>
                            {/* Simple mockup calc: 1 lot * 100 * drop */}
                            <span className="font-mono text-rose-400">-${(simulationDrop * 100 * 1.5).toFixed(0)} (Est)</span>
                        </div>
                        <div className="flex justify-between items-center p-2 rounded bg-slate-800/20 text-xs">
                            <span className="text-slate-400">预计预付款比例</span>
                            <span className={`font-mono font-bold ${simulationDrop > 20 ? 'text-rose-500' : 'text-emerald-500'}`}>
                                {Math.max(0, 150 - simulationDrop * 2).toFixed(0)}%
                            </span>
                        </div>
                    </div>

                    <div className="p-3 bg-yellow-500/10 border border-yellow-500/20 rounded-lg flex gap-3 items-start">
                        <Info className="w-4 h-4 text-yellow-500 shrink-0 mt-0.5" />
                        <p className="text-[10px] text-yellow-200/70 leading-relaxed">
                            当前波动率 ({atr?.toFixed(2)}) 较高。若未来 4 小时单边下跌 ${(atr * 0.5).toFixed(1)}，您的账户可能面临强平风险。建议关注 2015.50 附近的加仓机会。
                        </p>
                    </div>
                </div>
            </div>
        </div>
    );
};
