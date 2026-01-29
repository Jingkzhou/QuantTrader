import React, { useState, useEffect } from 'react';
import { ShieldAlert, Info, TrendingDown, Clock, Activity, Skull, HelpCircle } from 'lucide-react';
import type { AccountStatus } from '../types';
import { calculateLiquidationPrice, calculateRiskScore } from '../utils/riskCalculations';

interface RiskCockpitProps {
    accountStatus: AccountStatus;
    currentPrice: number | null;
    symbolInfo: { contractSize: number; stopOutLevel: number; tickValue: number };
    atr: number; // Daily ATR
}

// Simple Tooltip Component
const Tooltip = ({ content, children }: { content: React.ReactNode; children: React.ReactNode }) => {
    return (
        <div className="group relative flex items-center gap-1 cursor-help">
            {children}
            <div className="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 w-64 p-3 bg-slate-800 border border-slate-700 rounded-lg text-xs leading-relaxed text-slate-300 shadow-xl opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all z-50 pointer-events-none">
                {content}
                <div className="absolute top-full left-1/2 -translate-x-1/2 border-8 border-transparent border-t-slate-800" />
            </div>
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
        <div className="bg-slate-900/50 border border-slate-800 rounded-2xl p-6 relative overflow-hidden group h-full">
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
                            <Tooltip content={
                                <div>
                                    <div className="font-bold mb-1 text-slate-200">综合风险评分 (0-100)</div>
                                    <ul className="list-disc pl-3 text-slate-400 space-y-1">
                                        <li><span className="text-rose-400">40%</span> - 爆仓距离 (越近越危险)</li>
                                        <li><span className="text-rose-400">30%</span> - 波动率冲击 (1.5倍ATR波动后的净值回撤)</li>
                                        <li><span className="text-rose-400">20%</span> - 持仓层数 (重仓风险)</li>
                                        <li><span className="text-rose-400">10%</span> - 隔夜息费风险</li>
                                    </ul>
                                </div>
                            }>
                                <span className="text-[10px] uppercase text-slate-500 font-bold tracking-wider flex items-center gap-1">
                                    Risk Index <HelpCircle className="w-3 h-3" />
                                </span>
                            </Tooltip>
                        </div>
                    </div>

                    <div className="mt-4 grid grid-cols-2 gap-4 w-full">
                        <div className="bg-slate-950/50 rounded-lg p-3 text-center border border-slate-800/50">
                            <Tooltip content="基于当前市场波动率 (ATR/24h) 推算的理论生存时间。计算公式：当前价格到爆仓价格的距离 ÷ (每小时预估波幅 × 1.5)。">
                                <div className="text-xs text-slate-500 mb-1 flex items-center justify-center gap-1">生存倒计时 <Info className="w-3 h-3" /></div>
                            </Tooltip>
                            <div className="text-sm font-mono font-bold text-rose-400 flex items-center justify-center gap-1">
                                <Clock className="w-3 h-3" /> {timeToDeath}
                            </div>
                        </div>
                        <div className="bg-slate-950/50 rounded-lg p-3 text-center border border-slate-800/50">
                            <Tooltip content="当账户净值下跌至预付款比例 (StopOutLevel) 时触发强平的价格。公式：当前价格 ± (可用保证金亏损额 ÷ 总合约价值)。">
                                <div className="text-xs text-slate-500 mb-1 flex items-center justify-center gap-1">爆仓价格 <Info className="w-3 h-3" /></div>
                            </Tooltip>
                            <div className="text-sm font-mono font-bold text-rose-500 flex items-center justify-center gap-1">
                                <Skull className="w-3 h-3" /> {liquidationPrice > 0 ? liquidationPrice.toFixed(2) : '---'}
                            </div>
                        </div>
                    </div>
                </div>

                {/* Right: Simulation */}
                <div className="space-y-4">
                    <Tooltip content="推演假设市场价格发生单边不利移动时，账户各项风控指标的变化情况。用于提前评估加仓或极端行情下的风险承受力。">
                        <div className="flex justify-between items-center text-xs font-bold uppercase tracking-widest text-slate-500 cursor-help">
                            <span className="flex items-center gap-1">情景推演 (Simulation) <Info className="w-3 h-3" /></span>
                            <TrendingDown className="w-4 h-4" />
                        </div>
                    </Tooltip>

                    <div className="bg-slate-950 rounded-xl p-4 border border-slate-800">
                        <div className="flex justify-between mb-2 text-sm">
                            <span className="text-slate-400">假设不利波动</span>
                            <span className="font-mono font-bold text-cyan-400">${simulationDrop}</span>
                        </div>
                        <input
                            type="range"
                            min="0" max="50" step="1"
                            value={simulationDrop}
                            onChange={(e) => setSimulationDrop(Number(e.target.value))}
                            className="w-full h-1 bg-slate-800 rounded-lg appearance-none cursor-pointer accent-cyan-500 relative z-20"
                        />
                        <div className="flex justify-between mt-1 text-[10px] text-slate-600 font-mono">
                            <span>$0</span>
                            <span>$50</span>
                        </div>
                    </div>

                    {/* Simulated Metrics */}
                    <div className="space-y-2">
                        <div className="flex justify-between items-center p-2 rounded bg-slate-800/20 text-xs">
                            <span className="text-slate-400">预计浮亏增加</span>
                            {/* Simple mockup calc: NetLots * ContractSize * Drop */}
                            <span className="font-mono text-rose-400">
                                -${(Math.abs(
                                    accountStatus.positions.reduce((acc, p) => acc + (p.side === 'BUY' ? p.lots : -p.lots), 0)
                                ) * (symbolInfo.contractSize || 100) * simulationDrop).toFixed(0)}
                            </span>
                        </div>
                        <div className="flex justify-between items-center p-2 rounded bg-slate-800/20 text-xs">
                            <span className="text-slate-400">预计预付款比例</span>
                            {/* Simple estimation of margin level drop */}
                            <span className={`font-mono font-bold ${simulationDrop > 20 ? 'text-rose-500' : 'text-emerald-500'}`}>
                                {accountStatus.margin > 0 ? ((accountStatus.equity - (Math.abs(
                                    accountStatus.positions.reduce((acc, p) => acc + (p.side === 'BUY' ? p.lots : -p.lots), 0)
                                ) * (symbolInfo.contractSize || 100) * simulationDrop)) / accountStatus.margin * 100).toFixed(0) : 0}%
                            </span>
                        </div>
                    </div>

                    <div className="p-3 bg-yellow-500/10 border border-yellow-500/20 rounded-lg flex gap-3 items-start">
                        <Info className="w-4 h-4 text-yellow-500 shrink-0 mt-0.5" />
                        <p className="text-[10px] text-yellow-200/70 leading-relaxed">
                            当前波动率 ({atr?.toFixed(2)}) 较高。若未来 4 小时单边下跌 ${(atr * 0.5).toFixed(1)}，您的账户可能面临强平风险。
                        </p>
                    </div>
                </div>
            </div>
        </div>
    );
};
