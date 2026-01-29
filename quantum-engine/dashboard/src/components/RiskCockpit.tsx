import React, { useState, useEffect } from 'react';
import { TrendingDown, Activity } from 'lucide-react';
import type { AccountStatus } from '../types';
import { calculateLiquidationPrice, calculateRiskScore } from '../utils/riskCalculations';

interface RiskCockpitProps {
    accountStatus: AccountStatus;
    currentPrice: number | null;
    symbolInfo: { contractSize: number; stopOutLevel: number; tickValue: number };
    atr: number; // Daily ATR
}

// Click-to-Toggle Tooltip Component
const Tooltip = ({ content, children }: { content: React.ReactNode; children: React.ReactNode }) => {
    const [isVisible, setIsVisible] = useState(false);

    return (
        <div className="relative flex items-center gap-1 z-30">
            <div onClick={() => setIsVisible(!isVisible)} className="cursor-pointer active:scale-95 transition-transform">
                {children}
            </div>
            {isVisible && (
                <>
                    <div className="fixed inset-0 z-40" onClick={() => setIsVisible(false)} />
                    <div className="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 w-56 md:w-64 p-3 bg-slate-900 border border-slate-700 rounded-lg text-xs leading-relaxed text-slate-300 shadow-xl animate-in fade-in zoom-in-95 duration-200 z-50">
                        {content}
                        <div className="absolute top-100 left-1/2 -translate-x-1/2 border-4 border-transparent border-t-slate-900" />
                    </div>
                </>
            )}
        </div>
    );
};

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

    // Color logic
    const getScoreColor = (score: number) => {
        if (score < 40) return 'text-emerald-500';
        if (score < 70) return 'text-yellow-500';
        if (score < 90) return 'text-orange-500';
        return 'text-rose-600 animate-pulse';
    };

    return (
        <div className="bg-slate-900/50 border border-slate-800 rounded-2xl p-4 flex flex-col h-full relative overflow-hidden">
            {/* Header */}
            <div className="flex items-center justify-between mb-4 shrink-0 z-10">
                <h3 className="text-base font-bold text-white flex items-center gap-2">
                    <Activity className="w-4 h-4 text-cyan-500" />
                    风控驾驶舱 <span className="text-[10px] font-mono text-slate-500 ml-1 bg-slate-950 px-1.5 py-0.5 rounded border border-slate-800">24H RISK</span>
                </h3>
            </div>

            <div className="flex-1 flex flex-col gap-3 relative z-10 overflow-y-auto">
                {/* SECTION 1: Status Card - Compact Horizontal Layout */}
                <div className="bg-slate-950/40 rounded-xl p-3 border border-slate-800/50 flex items-center gap-4">
                    {/* Gauge - Left */}
                    <div className="relative w-20 h-20 shrink-0">
                        <svg className="w-full h-full transform -rotate-90" viewBox="0 0 100 100">
                            <circle cx="50" cy="50" r="45" fill="none" stroke="#1e293b" strokeWidth="8" />
                            <circle cx="50" cy="50" r="45" fill="none" stroke="currentColor" strokeWidth="8"
                                strokeDasharray={`${riskScore * 2.83} 283`}
                                strokeLinecap="round"
                                className={`${getScoreColor(riskScore)} transition-all duration-1000 ease-out`}
                            />
                        </svg>
                        <div className="absolute inset-0 flex flex-col items-center justify-center">
                            <span className={`text-2xl font-bold font-mono ${getScoreColor(riskScore)}`}>
                                {Math.round(riskScore)}
                            </span>
                            <Tooltip content="综合风险评分 (0-100)">
                                <div className="text-[8px] uppercase text-slate-500 font-bold tracking-wider cursor-pointer">SCORE</div>
                            </Tooltip>
                        </div>
                    </div>

                    {/* Metrics - Right Summary */}
                    <div className="flex-1 grid grid-cols-1 gap-2">
                        <div className="flex justify-between items-center text-xs border-b border-slate-800/50 pb-1">
                            <Tooltip content="理论存活时间">
                                <span className="text-slate-500 cursor-pointer border-b border-dotted border-slate-700">生存期</span>
                            </Tooltip>
                            <span className="font-mono font-bold text-rose-400">{timeToDeath}</span>
                        </div>
                        <div className="flex justify-between items-center text-xs">
                            <Tooltip content="预估强平价格">
                                <span className="text-slate-500 cursor-pointer border-b border-dotted border-slate-700">强平价</span>
                            </Tooltip>
                            <span className="font-mono font-bold text-rose-500">{liquidationPrice > 0 ? liquidationPrice.toFixed(2) : '---'}</span>
                        </div>
                    </div>
                </div>

                {/* SECTION 2: Simulation Card - Compact */}
                <div className="bg-slate-950/40 rounded-xl p-3 border border-slate-800/50 flex-1 flex flex-col justify-center">
                    <div className="flex justify-between items-center mb-2">
                        <Tooltip content="模拟下跌压力测试">
                            <div className="text-xs font-bold text-slate-400 flex items-center gap-1 cursor-pointer">
                                压力测试 (SIM) <TrendingDown className="w-3 h-3" />
                            </div>
                        </Tooltip>
                        <span className="font-mono text-cyan-400 text-xs font-bold">-${simulationDrop}</span>
                    </div>

                    <input
                        type="range"
                        min="0" max="50" step="1"
                        value={simulationDrop}
                        onChange={(e) => setSimulationDrop(Number(e.target.value))}
                        className="w-full h-1 bg-slate-800 rounded-lg appearance-none cursor-pointer accent-cyan-500 mb-4"
                    />

                    <div className="grid grid-cols-2 gap-3">
                        <div className="bg-slate-900/50 rounded p-2 text-center">
                            <div className="text-[10px] text-slate-500 mb-1">预计浮亏</div>
                            <div className="text-xs font-mono font-bold text-rose-400">
                                -${(Math.abs(
                                    accountStatus.positions.reduce((acc, p) => acc + (p.side === 'BUY' ? p.lots : -p.lots), 0)
                                ) * (symbolInfo.contractSize || 100) * simulationDrop).toFixed(0)}
                            </div>
                        </div>
                        <div className="bg-slate-900/50 rounded p-2 text-center">
                            <div className="text-[10px] text-slate-500 mb-1">预后保证金</div>
                            <div className={`text-xs font-mono font-bold ${simulationDrop > 20 ? 'text-rose-500' : 'text-emerald-500'}`}>
                                {accountStatus.margin > 0 ? ((accountStatus.equity - (Math.abs(
                                    accountStatus.positions.reduce((acc, p) => acc + (p.side === 'BUY' ? p.lots : -p.lots), 0)
                                ) * (symbolInfo.contractSize || 100) * simulationDrop)) / accountStatus.margin * 100).toFixed(0) : 0}%
                            </div>
                        </div>
                    </div>
                </div>

                {/* Warning Text - If High Risk */}
                <div className={`text-[10px] text-yellow-500/80 bg-yellow-500/5 p-2 rounded border border-yellow-500/10 transition-opacity duration-300 ${atr > 0 ? 'opacity-100' : 'opacity-0'}`}>
                    <span className="font-bold mr-1">!</span>
                    当前ATR: {atr?.toFixed(2)}。若4H内下挫 ${(atr * 0.5).toFixed(1)} 可能触警。
                </div>
            </div>
        </div>
    );
};
