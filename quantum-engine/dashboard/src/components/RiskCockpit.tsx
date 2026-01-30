import React, { useState, useEffect } from 'react';
import { Activity } from 'lucide-react';
import type { AccountStatus } from '../types';
import { calculateLiquidationPrice, calculateRiskScore, calculateSurvivalDistance } from '../utils/riskCalculations';

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

            // Time to death estimation using new Survival Distance
            const buyLots = accountStatus.positions.filter(p => p.side === 'BUY').reduce((acc, p) => acc + p.lots, 0);
            const sellLots = accountStatus.positions.filter(p => p.side === 'SELL').reduce((acc, p) => acc + p.lots, 0);
            const netLots = buyLots - sellLots;

            const dist = calculateSurvivalDistance(
                accountStatus.equity,
                accountStatus.margin,
                symbolInfo.stopOutLevel,
                netLots,
                symbolInfo.contractSize
            );

            if (isFinite(dist) && atr > 0) {
                const atrPerHour = atr / 24;
                const hours = dist / (atrPerHour * 1.5); // 1.5x accelerated
                if (hours < 1) setTimeToDeath(`< ${Math.ceil(hours * 60)}m`);
                else if (hours > 24) setTimeToDeath('> 24h');
                else setTimeToDeath(`~${hours.toFixed(1)}h`);
            } else {
                setTimeToDeath('> 24h');
            }
        }
    }, [accountStatus, currentPrice, symbolInfo, atr]);
    // Color logic
    const getScoreColor = (score: number) => {
        if (score < 40) return 'text-emerald-500';
        if (score < 70) return 'text-yellow-500';
        if (score < 90) return 'text-orange-500';
        return 'text-rose-600 animate-pulse';
    };

    return (
        <div className="bg-slate-900/50 border border-slate-800 rounded-xl p-2.5 flex flex-col gap-2 relative overflow-hidden">
            {/* Header / Title inline */}
            <div className="flex items-center justify-between">
                <div className="flex items-center gap-1.5 min-w-0">
                    <Activity className="w-3.5 h-3.5 text-cyan-500 shrink-0" />
                    <span className="text-xs font-bold text-white truncate">风控驾驶舱</span>
                    <span className="text-[9px] font-mono text-slate-500 bg-slate-950 px-1 rounded border border-slate-800 shrink-0">24H</span>
                </div>
                {/* Visual Score Pill for quick reference */}
                <div className={`px-2 py-0.5 rounded text-[10px] font-bold font-mono bg-slate-950 border border-slate-800 ${getScoreColor(riskScore)}`}>
                    RISK: {Math.round(riskScore)}
                </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 items-center">
                {/* Left: Key Metrics Group */}
                <div className="flex items-center gap-3 bg-slate-950/30 rounded-lg p-2 border border-slate-800/30">
                    <div className="relative w-12 h-12 shrink-0">
                        <svg className="w-full h-full transform -rotate-90" viewBox="0 0 100 100">
                            <circle cx="50" cy="50" r="45" fill="none" stroke="#1e293b" strokeWidth="12" />
                            <circle cx="50" cy="50" r="45" fill="none" stroke="currentColor" strokeWidth="12"
                                strokeDasharray={`${riskScore * 2.83} 283`}
                                strokeLinecap="round"
                                className={`${getScoreColor(riskScore)} transition-all duration-1000 ease-out`}
                            />
                        </svg>
                    </div>
                    <div className="flex-1 grid grid-cols-2 gap-x-3 gap-y-1">
                        <div className="flex flex-col">
                            <span className="text-[9px] text-slate-500">生存期</span>
                            <span className="text-[11px] font-mono font-bold text-rose-400">{timeToDeath}</span>
                        </div>
                        <div className="flex flex-col border-l border-slate-800 pl-3">
                            <span className="text-[9px] text-slate-500">强平价</span>
                            <span className="text-[11px] font-mono font-bold text-rose-500">{liquidationPrice > 0 ? liquidationPrice.toFixed(0) : '---'}</span>
                        </div>
                    </div>
                </div>

                {/* Right: Simulation Quick Control */}
                <div className="bg-slate-950/30 rounded-lg p-2 border border-slate-800/30">
                    <div className="flex justify-between items-center mb-1.5">
                        <span className="text-[9px] font-bold text-slate-500 uppercase tracking-tighter">压力测试 (SIM)</span>
                        <span className="font-mono text-cyan-400 text-[10px] font-bold">-${simulationDrop}</span>
                    </div>
                    <input
                        type="range" min="0" max="50" step="1"
                        value={simulationDrop}
                        onChange={(e) => setSimulationDrop(Number(e.target.value))}
                        className="w-full h-1 bg-slate-800 rounded-lg appearance-none cursor-pointer accent-cyan-500"
                    />
                    <div className="flex justify-between mt-1.5">
                        <div className="text-[9px] flex gap-1">
                            <span className="text-slate-600">损:</span>
                            <span className="text-rose-400 font-mono">-${(Math.abs(accountStatus.positions.reduce((acc, p) => acc + (p.side === 'BUY' ? p.lots : -p.lots), 0)) * (symbolInfo.contractSize || 100) * simulationDrop).toFixed(0)}</span>
                        </div>
                        <div className="text-[9px] flex gap-1">
                            <span className="text-slate-600">保:</span>
                            <span className={`font-mono font-bold ${simulationDrop > 20 ? 'text-rose-500' : 'text-emerald-500'}`}>
                                {accountStatus.margin > 0 ? ((accountStatus.equity - (Math.abs(accountStatus.positions.reduce((acc, p) => acc + (p.side === 'BUY' ? p.lots : -p.lots), 0)) * (symbolInfo.contractSize || 100) * simulationDrop)) / accountStatus.margin * 100).toFixed(0) : 0}%
                            </span>
                        </div>
                    </div>
                </div>
            </div>

            {/* Sticky Warning - Only one line, absolute bottom if helpful but here just tight */}
            {atr > 0 && riskScore > 50 && (
                <div className="text-[8px] text-yellow-500/60 flex items-center gap-1.5 px-1">
                    <span className="shrink-0 active:scale-125 transition-transform">⚠️</span>
                    <span className="truncate">ATR {atr.toFixed(2)}。4H波幅 {(atr * 0.5).toFixed(1)} 即存风险。</span>
                </div>
            )}
        </div>
    );
};
