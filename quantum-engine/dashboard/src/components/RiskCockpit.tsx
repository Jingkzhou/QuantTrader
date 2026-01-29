import React, { useState, useEffect } from 'react';
import { Info, TrendingDown, Activity, HelpCircle } from 'lucide-react';
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

    // Close when clicking outside - simplified for this component by just using a backdrop or self-toggle
    // For simplicity, we just toggle. Clicking elsewhere won't close it unless we add a specific listener, 
    // but a backdrop is easier for mobile-friendly "modal-like" behavior.

    return (
        <div className="relative flex items-center gap-1 z-30">
            <div onClick={() => setIsVisible(!isVisible)} className="cursor-pointer active:scale-95 transition-transform">
                {children}
            </div>
            {isVisible && (
                <>
                    <div className="fixed inset-0 z-40" onClick={() => setIsVisible(false)} />
                    <div className="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 w-56 md:w-64 p-3 bg-slate-800 border border-slate-700 rounded-lg text-xs leading-relaxed text-slate-300 shadow-xl animate-in fade-in zoom-in-95 duration-200 z-50">
                        {content}
                        <div className="absolute top-full left-1/2 -translate-x-1/2 border-8 border-transparent border-t-slate-800" />
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
        <div className="bg-slate-900/50 border border-slate-800 rounded-2xl p-4 md:p-5 relative overflow-hidden h-full flex flex-col justify-center">
            <div className="flex items-center justify-between mb-4">
                <h3 className="text-base font-bold text-white flex items-center gap-2">
                    <Activity className="w-4 h-4 text-cyan-500" />
                    风控驾驶舱 <span className="text-[10px] font-mono text-slate-500 ml-1 bg-slate-950 px-1.5 py-0.5 rounded border border-slate-800">24H RISK</span>
                </h3>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 md:gap-6 items-center flex-1">
                {/* Left: Gauge & Score */}
                <div className="flex flex-row md:flex-col items-center justify-between md:justify-center gap-4">
                    <div className="relative w-24 h-24 md:w-32 md:h-32 shrink-0">
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
                            <span className={`text-2xl md:text-3xl font-bold font-mono ${getScoreColor(riskScore)}`}>
                                {Math.round(riskScore)}
                            </span>
                            <Tooltip content={
                                <div>
                                    <div className="font-bold mb-1 text-slate-200">综合风险评分</div>
                                    <ul className="list-disc pl-3 text-slate-400 space-y-1">
                                        <li>40% 爆仓距离</li>
                                        <li>30% 波动率冲击</li>
                                        <li>20% 持仓层数</li>
                                        <li>10% 隔夜息费</li>
                                    </ul>
                                </div>
                            }>
                                <div className="text-[10px] uppercase text-slate-500 font-bold tracking-wider flex items-center gap-1 cursor-pointer hover:text-cyan-500 transition-colors">
                                    SCORE <HelpCircle className="w-3 h-3" />
                                </div>
                            </Tooltip>
                        </div>
                    </div>

                    <div className="grid grid-cols-1 gap-2 w-full max-w-[180px]">
                        <div className="bg-slate-950/50 rounded-lg p-2 text-center border border-slate-800/50 flex items-center justify-between px-3">
                            <Tooltip content="基于当前市场波动率(ATR)推算的理论生存时间。">
                                <div className="text-[10px] text-slate-500 flex items-center gap-1 cursor-pointer hover:text-slate-300">生存期 <Info className="w-3 h-3" /></div>
                            </Tooltip>
                            <div className="text-xs font-mono font-bold text-rose-400">{timeToDeath}</div>
                        </div>
                        <div className="bg-slate-950/50 rounded-lg p-2 text-center border border-slate-800/50 flex items-center justify-between px-3">
                            <Tooltip content="当账户净值下跌至预付款比例(StopOut)时触发强平的价格。">
                                <div className="text-[10px] text-slate-500 flex items-center gap-1 cursor-pointer hover:text-slate-300">强平价 <Info className="w-3 h-3" /></div>
                            </Tooltip>
                            <div className="text-xs font-mono font-bold text-rose-500">{liquidationPrice > 0 ? liquidationPrice.toFixed(2) : '---'}</div>
                        </div>
                    </div>
                </div>

                {/* Right: Simulation */}
                <div className="space-y-3">
                    <Tooltip content="推演假设市场不利移动时，账户各项指标的变化。">
                        <div className="flex justify-between items-center text-[10px] font-bold uppercase tracking-widest text-slate-500 cursor-pointer hover:text-cyan-500 transition-colors">
                            <span className="flex items-center gap-1">压力测试 (Sim) <Info className="w-3 h-3" /></span>
                            <TrendingDown className="w-3 h-3" />
                        </div>
                    </Tooltip>

                    <div className="bg-slate-950 rounded-lg p-3 border border-slate-800">
                        <div className="flex justify-between mb-1 text-xs">
                            <span className="text-slate-400">假设波动</span>
                            <span className="font-mono font-bold text-cyan-400">${simulationDrop}</span>
                        </div>
                        <input
                            type="range"
                            min="0" max="50" step="1"
                            value={simulationDrop}
                            onChange={(e) => setSimulationDrop(Number(e.target.value))}
                            className="w-full h-1 bg-slate-800 rounded-lg appearance-none cursor-pointer accent-cyan-500"
                        />
                    </div>

                    {/* Compact Metrics */}
                    <div className="grid grid-cols-2 gap-2">
                        <div className="p-2 rounded bg-slate-800/20 text-[10px] flex flex-col gap-1">
                            <span className="text-slate-400">预计亏损</span>
                            <span className="font-mono text-rose-400 text-xs font-bold">
                                -${(Math.abs(
                                    accountStatus.positions.reduce((acc, p) => acc + (p.side === 'BUY' ? p.lots : -p.lots), 0)
                                ) * (symbolInfo.contractSize || 100) * simulationDrop).toFixed(0)}
                            </span>
                        </div>
                        <div className="p-2 rounded bg-slate-800/20 text-[10px] flex flex-col gap-1">
                            <span className="text-slate-400">预后保证金</span>
                            <span className={`font-mono text-xs font-bold ${simulationDrop > 20 ? 'text-rose-500' : 'text-emerald-500'}`}>
                                {accountStatus.margin > 0 ? ((accountStatus.equity - (Math.abs(
                                    accountStatus.positions.reduce((acc, p) => acc + (p.side === 'BUY' ? p.lots : -p.lots), 0)
                                ) * (symbolInfo.contractSize || 100) * simulationDrop)) / accountStatus.margin * 100).toFixed(0) : 0}%
                            </span>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
};
