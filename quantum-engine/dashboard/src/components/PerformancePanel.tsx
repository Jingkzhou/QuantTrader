import React, { useEffect, useState } from 'react';
import axios from 'axios';
import { Target, TrendingUp, AlertOctagon, BarChart2 } from 'lucide-react';

const API_BASE = 'http://127.0.0.1:3001/api/v1';

interface Trade {
    profit: number;
    // other fields ignored
}

export const PerformancePanel: React.FC = () => {
    const [stats, setStats] = useState({
        winRate: 0,
        profitFactor: 0,
        totalTrades: 0,
        netProfit: 0,
        maxDrawdown: 0 // Placeholder, hard to calc without full equity history
    });

    useEffect(() => {
        const fetchTrades = async () => {
            try {
                const res = await axios.get(`${API_BASE}/trades?limit=100`);
                const trades: Trade[] = res.data;

                if (trades.length === 0) return;

                let wins = 0;
                let grossProfit = 0;
                let grossLoss = 0;
                let net = 0;

                trades.forEach(t => {
                    if (t.profit > 0) {
                        wins++;
                        grossProfit += t.profit;
                    } else {
                        grossLoss += Math.abs(t.profit);
                    }
                    net += t.profit;
                });

                const winRate = (wins / trades.length) * 100;
                const profitFactor = grossLoss === 0 ? grossProfit : grossProfit / grossLoss;

                setStats({
                    winRate,
                    profitFactor,
                    totalTrades: trades.length,
                    netProfit: net,
                    maxDrawdown: 0
                });
            } catch (e) {
                console.error("Failed to fetch performance stats", e);
            }
        };

        fetchTrades();
        const interval = setInterval(fetchTrades, 5000); // Poll every 5s
        return () => clearInterval(interval);
    }, []);

    const MetricCard = ({ label, value, subValue, icon: Icon, color }: any) => (
        <div className="bg-slate-800/50 rounded-xl p-4 flex items-center justify-between border border-slate-700/50">
            <div>
                <div className="text-slate-400 text-xs font-bold uppercase tracking-wider mb-1">{label}</div>
                <div className={`text-xl font-mono font-bold ${color}`}>{value}</div>
                {subValue && <div className="text-[10px] text-slate-500">{subValue}</div>}
            </div>
            <div className={`p-3 rounded-lg bg-slate-700/30 ${color.replace('text-', 'text-opacity-50 ')}`}>
                <Icon className="w-5 h-5" />
            </div>
        </div>
    );

    return (
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
            <MetricCard
                label="胜率 (100笔)"
                value={`${stats.winRate.toFixed(1)}%`}
                subValue={`${stats.totalTrades} 笔交易`}
                icon={Target}
                color={stats.winRate >= 50 ? "text-emerald-400" : "text-rose-400"}
            />
            <MetricCard
                label="盈亏比"
                value={stats.profitFactor.toFixed(2)}
                subValue={stats.profitFactor > 1.5 ? "良好" : "风险"}
                icon={BarChart2}
                color={stats.profitFactor >= 1.5 ? "text-blue-400" : "text-amber-400"}
            />
            <MetricCard
                label="净利润 (100笔)"
                value={`$${stats.netProfit.toFixed(2)}`}
                subValue="近100笔"
                icon={TrendingUp}
                color={stats.netProfit >= 0 ? "text-emerald-400" : "text-rose-400"}
            />
            <MetricCard
                label="期望收益"
                value={`${(stats.netProfit / stats.totalTrades).toFixed(2)}`}
                subValue="单笔"
                icon={AlertOctagon}
                color="text-purple-400"
            />
        </div>
    );
};
