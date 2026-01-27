import React, { useEffect, useMemo, useState } from 'react';
import {
    BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer,
    ScatterChart, Scatter, PieChart, Pie, Cell
} from 'recharts';
import { Layers, Target, Shield, AlertTriangle } from 'lucide-react';
import axios from 'axios';
import { API_BASE } from '../config';

interface StrategyAnalysisPanelProps {
    authToken: string | null;
    mt4Account: number | null;
    broker: string | null;
}

interface Trade {
    ticket: number;
    symbol: string;
    trade_type: 'BUY' | 'SELL';
    open_time: number;
    close_time: number;
    open_price: number;
    close_price: number;
    lots: number;
    profit: number;
    mae: number;
    mfe: number;
    signal_context?: string;
}

interface ContextPoint {
    ticket: number;
    symbol: string;
    profit: number;
    rsi: number;
    atr: number;
}

export const StrategyAnalysisPanel: React.FC<StrategyAnalysisPanelProps> = ({ authToken, mt4Account, broker }) => {
    const [trades, setTrades] = useState<Trade[]>([]);
    const [loading, setLoading] = useState(false);

    useEffect(() => {
        if (!authToken || !mt4Account || !broker) return;

        const fetchData = async () => {
            setLoading(true);
            try {
                // Fetch sufficient history for analysis
                const res = await axios.get(`${API_BASE}/trade_history?mt4_account=${mt4Account}&broker=${encodeURIComponent(broker)}&limit=5000`, {
                    headers: { Authorization: `Bearer ${authToken}` }
                });
                const data = Array.isArray(res.data) ? res.data : (res.data.data || []);
                setTrades(data);
            } catch (err) {
                console.error("Strategy Analysis Fetch Error", err);
            } finally {
                setLoading(false);
            }
        };

        fetchData();
    }, [authToken, mt4Account, broker]);

    // --- Analytics Logic ---

    // 1. Grid Layer Distribution
    const layerStats = useMemo(() => {
        if (!trades.length) return [];

        const sorted = [...trades].sort((a, b) => a.open_time - b.open_time);

        const layerCounts: Record<number, number> = {};
        const openPositions: Record<string, Trade[]> = {}; // Key: "SYMBOL_SIDE"

        sorted.forEach(t => {
            const key = `${t.symbol}_${t.trade_type}`;
            if (!openPositions[key]) openPositions[key] = [];

            // Clean up closed positions (those that closed before this one opened)
            openPositions[key] = openPositions[key].filter(op => op.close_time > t.open_time);

            const currentLayer = openPositions[key].length + 1;

            if (!layerCounts[currentLayer]) layerCounts[currentLayer] = 0;
            layerCounts[currentLayer]++;

            openPositions[key].push(t);
        });

        return Object.entries(layerCounts)
            .map(([layer, count]) => ({ layer: `L${layer}`, count, layerNum: Number(layer) }))
            .sort((a, b) => a.layerNum - b.layerNum)
            .slice(0, 20); // Top 20 layers only
    }, [trades]);

    // 2. MAE vs MFE
    const riskRewardData = useMemo(() => {
        return trades
            .filter(t => t.mae !== undefined && t.mfe !== undefined)
            .map(t => ({
                ticket: t.ticket,
                mae: Math.abs(t.mae), // MAE is often negative, visualize as magnitude
                mfe: Math.abs(t.mfe),
                profit: t.profit,
                status: t.profit >= 0 ? 'Profit' : 'Loss'
            }));
    }, [trades]);

    // 3. Hedging Analysis (Simultaneous Closes)
    const hedgingStats = useMemo(() => {
        // Group by close time (rounded to 2 seconds)
        const groups: Record<string, Trade[]> = {};
        trades.forEach(t => {
            const timeKey = Math.floor(t.close_time / 2) * 2; // 2s buckets
            if (!groups[timeKey]) groups[timeKey] = [];
            groups[timeKey].push(t);
        });

        let trendProtectCount = 0;   // Net Positive Close
        let reverseProtectCount = 0; // Net Negative/Small Close (Rescue)
        let singleStatsCount = 0;

        Object.values(groups).forEach(group => {
            if (group.length > 1) {
                // Multi-close event (Grid Close)
                const netPL = group.reduce((sum, t) => sum + t.profit, 0);
                if (netPL > 0) {
                    trendProtectCount++; // Likely Take Profit or Trend Protect
                } else {
                    reverseProtectCount++; // Risk Protect / Stop Loss interaction
                }
            } else {
                singleStatsCount++;
            }
        });

        return [
            { name: '顺势/止盈 (Win)', value: trendProtectCount, color: '#10b981' },
            { name: '逆势/风控 (Rescue)', value: reverseProtectCount, color: '#f43f5e' },
        ];
    }, [trades]);

    // 4. Entry Context (RSI vs ATR)
    const contextData = useMemo(() => {
        const points: ContextPoint[] = [];
        trades.forEach(t => {
            if (t.signal_context) {
                try {
                    const ctx = JSON.parse(t.signal_context);
                    if (ctx.rsi && ctx.atr) {
                        points.push({
                            ticket: t.ticket,
                            symbol: t.symbol,
                            profit: t.profit,
                            rsi: ctx.rsi,
                            atr: ctx.atr
                        });
                    }
                } catch (e) {
                    // ignore invalid json
                }
            }
        });
        return points;
    }, [trades]);


    if (loading && trades.length === 0) {
        return <div className="p-8 text-center text-slate-500 animate-pulse">Loading Strategy Analysis...</div>;
    }

    return (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">

            {/* 1. Grid Layer Distribution */}
            <div className="bg-slate-900/50 border border-slate-800 rounded-2xl p-6 flex flex-col h-[350px]">
                <div className="flex justify-between items-center mb-4">
                    <h3 className="font-bold text-slate-300 flex items-center gap-2 uppercase tracking-wide text-sm">
                        <Layers className="w-4 h-4 text-cyan-500" />
                        网格层级分布 (Layer Distribution)
                    </h3>
                </div>
                <div className="flex-1 min-w-0">
                    <ResponsiveContainer width="100%" height="100%">
                        <BarChart data={layerStats} margin={{ top: 5, right: 20, bottom: 5, left: 0 }}>
                            <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" vertical={false} />
                            <XAxis dataKey="layer" stroke="#64748b" fontSize={10} tickLine={false} />
                            <YAxis stroke="#64748b" fontSize={10} tickLine={false} />
                            <Tooltip
                                contentStyle={{ backgroundColor: '#0f172a', borderColor: '#1e293b', color: '#f1f5f9' }}
                                cursor={{ fill: '#1e293b', opacity: 0.4 }}
                            />
                            <Bar dataKey="count" fill="#06b6d4" radius={[4, 4, 0, 0]} name="成交次数" />
                        </BarChart>
                    </ResponsiveContainer>
                </div>
                <div className="mt-2 text-[10px] text-slate-500">
                    * 如果高层级 (L5+) 频繁出现，建议检查 FirstOrderDistance 或 GridStep 设置。
                </div>
            </div>

            {/* 2. MAE vs MFE Risk Analysis */}
            <div className="bg-slate-900/50 border border-slate-800 rounded-2xl p-6 flex flex-col h-[350px]">
                <div className="flex justify-between items-center mb-4">
                    <h3 className="font-bold text-slate-300 flex items-center gap-2 uppercase tracking-wide text-sm">
                        <Target className="w-4 h-4 text-rose-500" />
                        风险收益分析 (MAE vs MFE)
                    </h3>
                </div>
                <div className="flex-1 min-w-0">
                    <ResponsiveContainer width="100%" height="100%">
                        <ScatterChart margin={{ top: 10, right: 10, bottom: 10, left: 0 }}>
                            <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" />
                            <XAxis type="number" dataKey="mfe" name="MFE (浮盈)" unit="pts" stroke="#64748b" fontSize={10} />
                            <YAxis type="number" dataKey="mae" name="MAE (浮亏)" unit="pts" stroke="#64748b" fontSize={10} />
                            <Tooltip
                                cursor={{ strokeDasharray: '3 3' }}
                                content={({ active, payload }) => {
                                    if (active && payload && payload.length) {
                                        const data = payload[0].payload;
                                        return (
                                            <div className="bg-slate-900 border border-slate-800 p-2 rounded shadow-xl text-xs">
                                                <div className={`font-bold ${data.profit >= 0 ? 'text-emerald-500' : 'text-rose-500'}`}>
                                                    Ticket: {data.ticket} ({data.profit >= 0 ? 'Win' : 'Loss'})
                                                </div>
                                                <div>MFE: {data.mfe.toFixed(0)}</div>
                                                <div>MAE: {data.mae.toFixed(0)}</div>
                                                <div>Profit: ${data.profit.toFixed(2)}</div>
                                            </div>
                                        );
                                    }
                                    return null;
                                }}
                            />
                            <Scatter name="Trades" data={riskRewardData} fill="#8884d8">
                                {riskRewardData.map((entry, index) => (
                                    <Cell key={`cell-${index}`} fill={entry.profit >= 0 ? '#10b981' : '#f43f5e'} opacity={0.6} />
                                ))}
                            </Scatter>
                        </ScatterChart>
                    </ResponsiveContainer>
                </div>
                <div className="mt-2 text-[10px] text-slate-500">
                    * 左上角区域 (高 MAE, 低 MFE) 为危险区域: 扛单严重且收益微薄。
                </div>
            </div>

            {/* 3. Hedging Trigger Stats */}
            <div className="bg-slate-900/50 border border-slate-800 rounded-2xl p-6 flex flex-col h-[350px]">
                <div className="flex justify-between items-center mb-4">
                    <h3 className="font-bold text-slate-300 flex items-center gap-2 uppercase tracking-wide text-sm">
                        <Shield className="w-4 h-4 text-emerald-500" />
                        多单对冲/平仓逻辑触发 (Batch Close)
                    </h3>
                </div>
                <div className="flex-1 min-w-0 flex items-center justify-center">
                    <div className="w-full h-full flax items-center justify-center">
                        <ResponsiveContainer width="100%" height="100%">
                            <PieChart>
                                <Pie
                                    data={hedgingStats}
                                    cx="50%"
                                    cy="50%"
                                    innerRadius={60}
                                    outerRadius={90}
                                    paddingAngle={5}
                                    dataKey="value"
                                    stroke="none"
                                >
                                    {hedgingStats.map((entry, index) => (
                                        <Cell key={`cell-${index}`} fill={entry.color} />
                                    ))}
                                </Pie>
                                <Tooltip
                                    contentStyle={{ backgroundColor: '#020617', borderColor: '#334155', color: '#f8fafc', borderRadius: '8px', boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1)' }}
                                    itemStyle={{ color: '#f8fafc' }}
                                />
                                <Legend verticalAlign="bottom" height={36} />
                            </PieChart>
                        </ResponsiveContainer>
                    </div>
                </div>
                <div className="mt-2 text-[10px] text-slate-500">
                    * 统计同时平仓(打包平仓)的事件。红色代表逆势救单/止损平仓，绿色代表整体获利平仓。
                </div>
            </div>

            {/* 4. Entry Context Analysis (RSI vs ATR) */}
            <div className="bg-slate-900/50 border border-slate-800 rounded-2xl p-6 flex flex-col h-[350px]">
                <div className="flex justify-between items-center mb-4">
                    <h3 className="font-bold text-slate-300 flex items-center gap-2 uppercase tracking-wide text-sm">
                        <Target className="w-4 h-4 text-purple-500" />
                        入场环境热力 (RSI vs ATR)
                    </h3>
                </div>
                <div className="flex-1 min-w-0">
                    <ResponsiveContainer width="100%" height="100%">
                        <ScatterChart margin={{ top: 10, right: 10, bottom: 10, left: 0 }}>
                            <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" />
                            <XAxis type="number" dataKey="rsi" name="RSI" domain={[0, 100]} stroke="#64748b" fontSize={10} tickCount={11} />
                            <YAxis type="number" dataKey="atr" name="ATR" stroke="#64748b" fontSize={10} />
                            <Tooltip
                                cursor={{ strokeDasharray: '3 3' }}
                                content={({ active, payload }) => {
                                    if (active && payload && payload.length) {
                                        const data = payload[0].payload;
                                        return (
                                            <div className="bg-slate-900 border border-slate-800 p-2 rounded shadow-xl text-xs">
                                                <div className={`font-bold ${data.profit >= 0 ? 'text-emerald-500' : 'text-rose-500'}`}>
                                                    {data.symbol} #{data.ticket}
                                                </div>
                                                <div>RSI: {data.rsi.toFixed(1)}</div>
                                                <div>ATR: {data.atr.toFixed(5)}</div>
                                                <div>Profit: ${data.profit.toFixed(2)}</div>
                                            </div>
                                        );
                                    }
                                    return null;
                                }}
                            />
                            {/* Reference Lines for RSI Zones */}
                            <Scatter name="Context" data={contextData} fill="#8884d8" shape="circle">
                                {contextData.map((entry, index) => (
                                    <Cell key={`cell-${index}`} fill={entry.profit >= 0 ? '#10b981' : '#f43f5e'} opacity={0.7} />
                                ))}
                            </Scatter>
                        </ScatterChart>
                    </ResponsiveContainer>
                </div>
                <div className="mt-2 text-[10px] text-slate-500">
                    * X轴: RSI强弱 (30/70为界), Y轴: ATR波动率. 观察亏损单是否集中在特定区域 (如高ATR或极端RSI).
                </div>
            </div>

            {/* 5. Insight Summary */}
            <div className="bg-slate-900/50 border border-slate-800 rounded-2xl p-6 flex flex-col h-[350px] lg:col-span-2">
                <div className="flex justify-between items-center mb-4">
                    <h3 className="font-bold text-slate-300 flex items-center gap-2 uppercase tracking-wide text-sm">
                        <AlertTriangle className="w-4 h-4 text-amber-500" />
                        EA 优化建议 (AI Insights)
                    </h3>
                </div>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm text-slate-400">
                    <div className="p-3 bg-slate-800/30 rounded-lg">
                        <div className="font-bold text-slate-200 mb-1">层级健康度</div>
                        {layerStats.length > 0 && layerStats[layerStats.length - 1].layerNum > 5 ? (
                            <p className="text-amber-500">警告: 存在高层级网格 ({layerStats[layerStats.length - 1].layer}). 建议增大 GridStep 或检查入场信号。</p>
                        ) : (
                            <p className="text-emerald-500">健康: 网格主要集中在低层级 (L1-L{layerStats.length > 0 ? layerStats.length : 0}), 入场逻辑良好。</p>
                        )}
                    </div>

                    <div className="p-3 bg-slate-800/30 rounded-lg">
                        <div className="font-bold text-slate-200 mb-1">风控效率 (Rescues)</div>
                        <p>
                            逆势保护触发了 <span className="text-rose-400 font-mono font-bold">{hedgingStats.find(s => s.name.includes('逆势'))?.value || 0}</span> 次。
                            {(hedgingStats.find(s => s.name.includes('逆势'))?.value || 0) > (hedgingStats.find(s => s.name.includes('顺势'))?.value || 0)
                                ? ' 此时段 EA 主要在进行救单操作，行情可能不适配当前参数。'
                                : ' 此时段 EA 运行平稳，主要以顺势止盈为主。'
                            }
                        </p>
                    </div>

                    <div className="p-3 bg-slate-800/30 rounded-lg">
                        <div className="font-bold text-slate-200 mb-1">盈亏比质量</div>
                        <p>
                            数据点聚集在 {
                                riskRewardData.filter(t => t.mae > t.mfe * 2).length > riskRewardData.length * 0.3
                                    ? <span className="text-rose-500">左上区域 (高风险/低收益) - 需要优化离场逻辑。</span>
                                    : <span className="text-emerald-500">对角线下方 (收益覆盖风险) - 策略预期正常。</span>
                            }
                        </p>
                    </div>

                    <div className="p-3 bg-slate-800/30 rounded-lg">
                        <div className="font-bold text-slate-200 mb-1">RSI/ATR 环境分析</div>
                        <p>
                            {(() => {
                                const highAtrLosses = contextData.filter(d => d.atr > 0.0020 && d.profit < 0).length;
                                const extremeRsiLosses = contextData.filter(d => (d.rsi > 70 || d.rsi < 30) && d.profit < 0).length;
                                if (highAtrLosses > contextData.length * 0.1) return <span className="text-rose-500">高波动 (ATR&gt;20) 下亏损较多，建议增加网格间距。</span>;
                                if (extremeRsiLosses > contextData.length * 0.1) return <span className="text-rose-500">极端 RSI 逆势入场亏损较多，建议过滤极端行情。</span>;
                                return <span className="text-emerald-500">不同波动率与 RSI 区间下表现相对均衡。</span>;
                            })()}
                        </p>
                    </div>
                </div>
            </div>

        </div>
    );
};
