import React, { useMemo } from 'react';
import { Target, TrendingUp, AlertOctagon, BarChart2 } from 'lucide-react';

interface Trade {
    profit: number;
    symbol: string;
}

interface PerformancePanelProps {
    trades: Trade[];
    selectedSymbol: string;
    gridClass?: string;
}

export const PerformancePanel: React.FC<PerformancePanelProps> = ({ trades, selectedSymbol, gridClass }) => {

    const stats = useMemo(() => {
        // Filter trades by selected symbol
        const filteredTrades = trades.filter(t => !selectedSymbol || t.symbol === selectedSymbol);

        if (filteredTrades.length === 0) {
            return {
                winRate: 0,
                profitFactor: 0,
                totalTrades: 0,
                netProfit: 0,
                avgProfit: 0
            };
        }

        let wins = 0;
        let grossProfit = 0;
        let grossLoss = 0;
        let net = 0;

        filteredTrades.forEach(t => {
            if (t.profit > 0) {
                wins++;
                grossProfit += t.profit;
            } else {
                grossLoss += Math.abs(t.profit);
            }
            net += t.profit;
        });

        const winRate = (wins / filteredTrades.length) * 100;
        const profitFactor = grossLoss === 0 ? grossProfit : grossProfit / grossLoss;
        const avgProfit = net / filteredTrades.length;

        return {
            winRate,
            profitFactor,
            totalTrades: filteredTrades.length,
            netProfit: net,
            avgProfit
        };
    }, [trades, selectedSymbol]);

    const MetricCard = ({ label, value, subValue, icon: Icon, color }: any) => (
        <div className="bg-slate-900/50 rounded-xl p-4 flex items-center justify-between border border-slate-800 transition-all hover:border-slate-700">
            <div>
                <div className="text-slate-500 text-[10px] font-bold uppercase tracking-wider mb-1">{label}</div>
                <div className={`text-xl font-mono font-bold ${color}`}>{value}</div>
                {subValue && <div className="text-[10px] text-slate-500 font-medium">{subValue}</div>}
            </div>
            <div className={`p-3 rounded-lg bg-slate-800/50 ${color.replace('text-', 'text-opacity-50 ')}`}>
                <Icon className="w-5 h-5" />
            </div>
        </div>
    );

    return (
        <div className={`grid gap-4 mb-6 ${gridClass || 'grid-cols-1 sm:grid-cols-2 lg:grid-cols-4'}`}>
            <MetricCard
                label={`胜率 (${stats.totalTrades}笔)`}
                value={`${stats.winRate.toFixed(1)}%`}
                subValue={selectedSymbol ? `${selectedSymbol} 表现` : "全品种统计"}
                icon={Target}
                color={stats.winRate >= 50 ? "text-emerald-400" : "text-rose-400"}
            />
            <MetricCard
                label="盈亏比"
                value={stats.profitFactor.toFixed(2)}
                subValue={stats.profitFactor > 1.5 ? "良好" : "一般"}
                icon={BarChart2}
                color={stats.profitFactor >= 1.5 ? "text-blue-400" : "text-amber-400"}
            />
            <MetricCard
                label={`净利润 (${stats.totalTrades}笔)`}
                value={`$${stats.netProfit.toFixed(2)}`}
                subValue={selectedSymbol ? `仅限 ${selectedSymbol}` : "全部记录"}
                icon={TrendingUp}
                color={stats.netProfit >= 0 ? "text-emerald-400" : "text-rose-400"}
            />
            <MetricCard
                label="期望收益"
                value={`${stats.avgProfit.toFixed(2)}`}
                subValue="平均单笔盈利"
                icon={AlertOctagon}
                color="text-purple-400"
            />
        </div>
    );
};
