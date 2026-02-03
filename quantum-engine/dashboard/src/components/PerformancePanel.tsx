import React, { useMemo } from 'react';
import { TrendingUp, Activity, Clock, Zap, ShieldCheck } from 'lucide-react';
import type { TradeHistory, AccountStatus } from '../types';

interface PerformancePanelProps {
    trades: TradeHistory[];
    selectedSymbol: string;
    maxDrawdown: number;      // Session Max Drawdown %
    accountStatus?: AccountStatus;
    gridClass?: string;
}

export const PerformancePanel: React.FC<PerformancePanelProps> = ({
    trades, selectedSymbol, maxDrawdown, accountStatus, gridClass
}) => {

    const stats = useMemo(() => {
        // Filter trades
        const filteredTrades = trades.filter(t => !selectedSymbol || t.symbol === selectedSymbol);

        if (filteredTrades.length === 0) {
            return {
                recoveryFactor: 0,
                profitFactor: 0,
                sortinoRatio: 0,
                maxDDDuration: 0,
                safetyBuffer: 0,
                netProfit: 0
            };
        }

        // 1. Basic profit/loss sums
        let grossProfit = 0;
        let grossLoss = 0;
        let netProfit = 0;
        const profits: number[] = [];

        filteredTrades.forEach(t => {
            // NOTE: TradeHistory.profit already includes swap + commission from MQ4/Backend logic
            const p = t.profit;
            profits.push(p);
            netProfit += p;
            if (p > 0) grossProfit += p;
            else grossLoss += Math.abs(p);
        });

        // 2. Profit Factor (> 1.5 Good, > 2.0 Excellent)
        const profitFactor = grossLoss === 0 ? (grossProfit > 0 ? 99.99 : 0) : grossProfit / grossLoss;

        // 3. Recovery Factor (Net Profit / Max Drawdown Amount)
        // Estimate Max DD Amount from Equity & MaxDD%
        const currentEquity = accountStatus?.equity || 0;
        // Conservative Peak Estimate: Equity / (1 - MaxDD/100)
        // Avoid division by zero
        const divisor = (1 - (maxDrawdown / 100));
        const peakEquityEst = currentEquity / (divisor > 0.01 ? divisor : 1);
        const maxDDAmount = peakEquityEst * (maxDrawdown / 100);

        // If maxDDAmount is tiny, use a cap to avoid infinite RF
        const recoveryFactor = (maxDDAmount > 1) ? (netProfit / maxDDAmount) : (netProfit > 0 ? 99.99 : 0);

        // 4. Sortino Ratio (Only Downside Volatility)
        // Mean Return / Downside Deviation
        const avgReturn = netProfit / (filteredTrades.length || 1);
        const downsideSqSum = profits.filter(p => p < 0).reduce((sum, p) => sum + (p * p), 0);
        const downsideDev = Math.sqrt(downsideSqSum / (filteredTrades.length || 1));
        const sortinoRatio = downsideDev > 0.001 ? avgReturn / downsideDev : (avgReturn > 0 ? 99.99 : 0);

        // 5. Max Drawdown Duration (Time "Under Water")
        // Sort by close time
        const sortedTrades = [...filteredTrades].sort((a, b) => a.close_time - b.close_time);
        let cumProfit = 0;
        let hwm = -999999;
        let hwmTime = sortedTrades[0]?.close_time || 0;
        let maxDurationSecs = 0;
        let inDD = false;

        sortedTrades.forEach(t => {
            cumProfit += t.profit;
            if (cumProfit >= hwm) {
                if (inDD) {
                    // Recovered
                    const duration = t.close_time - hwmTime;
                    if (duration > maxDurationSecs) maxDurationSecs = duration;
                    inDD = false;
                }
                hwm = cumProfit;
                hwmTime = t.close_time;
            } else {
                inDD = true;
                // Update duration for current DD
                const duration = t.close_time - hwmTime;
                if (duration > maxDurationSecs) maxDurationSecs = duration;
            }
        });
        const maxDDDays = maxDurationSecs / 86400;


        // 6. Safety Buffer (Margin Level)
        // If margin is 0 (no positions), level is infinite (or 0 if handle safe).
        let safetyBuffer = 0;
        if (accountStatus?.margin && accountStatus.margin > 0) {
            safetyBuffer = (accountStatus.equity / accountStatus.margin) * 100;
        }

        return {
            recoveryFactor,
            profitFactor,
            sortinoRatio,
            maxDDDuration: maxDDDays,
            safetyBuffer,
            netProfit
        };
    }, [trades, selectedSymbol, maxDrawdown, accountStatus]);


    const MetricCard = ({ label, value, subValue, icon: Icon, color, tip }: any) => (
        <div className="bg-slate-900/50 rounded-xl p-4 flex items-center justify-between border border-slate-800 transition-all hover:border-slate-700 group relative">
            <div>
                <div className="text-slate-500 text-[10px] font-bold uppercase tracking-wider mb-1 flex items-center gap-1">
                    {label}
                </div>
                <div className={`text-xl font-mono font-bold ${color}`}>{value}</div>
                {subValue && <div className="text-[10px] text-slate-500 font-medium mt-1">{subValue}</div>}
            </div>
            <div className={`p-3 rounded-lg bg-slate-800/50 ${color.replace('text-', 'text-opacity-50 ')}`}>
                <Icon className="w-5 h-5" />
            </div>

            {/* Tooltip */}
            {tip && (
                <div className="absolute opacity-0 group-hover:opacity-100 transition-opacity bottom-full left-1/2 -translate-x-1/2 mb-2 w-48 bg-slate-800 text-xs text-slate-300 p-2 rounded shadow-xl pointer-events-none z-10 border border-slate-700 px-3 py-2 leading-relaxed whitespace-normal min-w-[200px]">
                    {tip}
                </div>
            )}
        </div>
    );

    // Grid Columns Layout
    // We have 5 cards. Standard grid-cols-4 leaves one hanging.
    // Adjust to grid-cols-5 for large screens or flexible wrapping?
    // User requested gridClass pass-through.
    // Default to grid-cols-1 sm:grid-cols-2 lg:grid-cols-5

    return (
        <div className={`grid gap-4 mb-6 ${gridClass || 'grid-cols-1 sm:grid-cols-2 lg:grid-cols-5'}`}>
            <MetricCard
                label="恢复因子 (RF)"
                value={stats.recoveryFactor.toFixed(2)}
                subValue={stats.recoveryFactor < 3 ? "⚠️ 回血缓慢" : "✅ 恢复力强"}
                icon={Zap}
                color={stats.recoveryFactor >= 3 ? "text-emerald-400" : "text-rose-400"}
                tip="净利润 / 最大回撤。反映系统从打击中恢复的能力。建议 > 3.0"
            />

            <MetricCard
                label="获利因子 (PF)"
                value={stats.profitFactor.toFixed(2)}
                subValue={stats.profitFactor > 2 ? "Excellent" : (stats.profitFactor > 1.5 ? "Good" : "Weak")}
                icon={TrendingUp}
                color={stats.profitFactor > 1.5 ? "text-blue-400" : "text-amber-400"}
                tip="总盈利 / 总亏损。> 1.5 合格, > 2.0 优秀。反映每投入$1风险的回报。"
            />

            <MetricCard
                label="索提诺比率"
                value={stats.sortinoRatio.toFixed(2)}
                subValue="基于下行波动"
                icon={Activity}
                color={stats.sortinoRatio > 2 ? "text-purple-400" : "text-slate-400"}
                tip="衡量承担单位下行风险获得的超额收益。比夏普比率更适合评估EA的抗风险能力。"
            />

            <MetricCard
                label="最长回撤期"
                value={`${stats.maxDDDuration.toFixed(0)} 天`}
                subValue="资金被套时长"
                icon={Clock}
                color={stats.maxDDDuration < 14 ? "text-emerald-400" : "text-rose-400"}
                tip="历史上最长一次回撤持续的时间。若超过20天需评估资金压力。"
            />

            <MetricCard
                label="安全缓冲 (Buffer)"
                value={`${stats.safetyBuffer.toFixed(0)}%`}
                subValue="< 120% 报警"
                icon={ShieldCheck}
                color={stats.safetyBuffer > 150 ? "text-emerald-400" : (stats.safetyBuffer > 120 ? "text-amber-400" : "text-rose-500")}
                tip="当前净值 / 维持保证金。这是账号的生命线，低于120%极度危险。"
            />
        </div>
    );
};
