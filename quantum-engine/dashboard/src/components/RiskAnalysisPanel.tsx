import React, { useEffect, useRef, useState } from 'react';
import { createChart, ColorType, HistogramSeries, AreaSeries } from 'lightweight-charts';
import type { IChartApi, ISeriesApi, Time } from 'lightweight-charts';
import axios from 'axios';
import { ShieldAlert, Split } from 'lucide-react';
import { API_BASE } from '../config';

interface RiskAnalysisPanelProps {
    authToken: string | null;
    mt4Account: number | null;
    broker: string | null;
}

export const RiskAnalysisPanel: React.FC<RiskAnalysisPanelProps> = ({ authToken, mt4Account, broker }) => {
    return (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <DrawdownDepthChart authToken={authToken} mt4Account={mt4Account} broker={broker} />
            <NetExposureChart authToken={authToken} mt4Account={mt4Account} broker={broker} />
        </div>
    );
};

// --- Drawdown Depth Chart ---

const DrawdownDepthChart: React.FC<RiskAnalysisPanelProps> = ({ authToken, mt4Account, broker }) => {
    const chartContainerRef = useRef<HTMLDivElement>(null);
    const chartRef = useRef<IChartApi | null>(null);
    const seriesRef = useRef<ISeriesApi<"Area"> | null>(null);
    const [currentDD, setCurrentDD] = useState<number>(0);

    useEffect(() => {
        if (!chartContainerRef.current) return;

        const chart = createChart(chartContainerRef.current, {
            layout: { background: { type: ColorType.Solid, color: 'transparent' }, textColor: '#94a3b8' },
            grid: { vertLines: { color: '#1e293b' }, horzLines: { color: '#1e293b' } },
            width: chartContainerRef.current.clientWidth,
            height: 250,
            timeScale: { timeVisible: true, secondsVisible: true },
        });

        const series = chart.addSeries(AreaSeries, {
            lineColor: '#f43f5e',
            topColor: 'rgba(244, 63, 94, 0.1)',
            bottomColor: 'rgba(244, 63, 94, 0.6)',
            lineWidth: 2,
        });

        chartRef.current = chart;
        seriesRef.current = series;

        const handleResize = () => chart.applyOptions({ width: chartContainerRef.current?.clientWidth || 0 });
        window.addEventListener('resize', handleResize);

        return () => {
            window.removeEventListener('resize', handleResize);
            chart.remove();
        };
    }, []);

    useEffect(() => {
        if (!authToken || !mt4Account || !broker || !seriesRef.current) return;

        const fetchData = async () => {
            try {
                const res = await axios.get(`${API_BASE}/account/history?mt4_account=${mt4Account}&broker=${encodeURIComponent(broker)}&limit=1000`, {
                    headers: { Authorization: `Bearer ${authToken}` }
                });

                const history = res.data.sort((a: any, b: any) => a.timestamp - b.timestamp);
                const ddData: { time: Time, value: number }[] = [];
                let maxEquity = 0;

                history.forEach((h: any) => {
                    if (h.equity > maxEquity) maxEquity = h.equity;
                    let dd = 0;
                    if (maxEquity > 0) {
                        dd = (h.equity - maxEquity) / maxEquity * 100; // Percentage
                    }
                    // Only add points if meaningful to avoid massive noise, but detailed enough for chart
                    ddData.push({ time: Number(h.timestamp) as Time, value: dd });
                });

                // Deduplicate times
                const uniqueData = Array.from(new Map(ddData.map(item => [item.time, item])).values())
                    .sort((a, b) => (a.time as number) - (b.time as number));

                seriesRef.current?.setData(uniqueData);
                if (uniqueData.length > 0) {
                    setCurrentDD(uniqueData[uniqueData.length - 1].value);
                    chartRef.current?.timeScale().fitContent();
                }
            } catch (e) {
                console.error("Auth DD fetch error", e);
            }
        };

        fetchData();
        const interval = setInterval(fetchData, 60000); // 1 min update
        return () => clearInterval(interval);
    }, [authToken, mt4Account, broker]);


    return (
        <div className="bg-slate-900/50 border border-slate-800 rounded-2xl p-6 flex flex-col">
            <div className="flex justify-between items-center mb-4">
                <h3 className="font-bold text-slate-300 flex items-center gap-2 uppercase tracking-wide text-sm">
                    <ShieldAlert className="w-4 h-4 text-rose-500" />
                    最大回撤深度 (Drawdown)
                </h3>
                <div className={`text-xs font-mono font-bold px-2 py-1 rounded border ${currentDD < -20 ? 'bg-rose-500/10 text-rose-500 border-rose-500/50 animate-pulse' : 'bg-slate-800 text-slate-400 border-slate-700'}`}>
                    当前回撤: {currentDD.toFixed(2)}%
                </div>
            </div>
            <div ref={chartContainerRef} className="w-full flex-1" />
            <div className="mt-2 text-[10px] text-slate-600">
                * 此图表展示账户净值的回撤百分比历史 (相对于历史最高点)。深坑越久，恢复能力越弱。
            </div>
        </div>
    );
}

// --- Net Lot Exposure Chart ---

const NetExposureChart: React.FC<RiskAnalysisPanelProps> = ({ authToken, mt4Account, broker }) => {
    const chartContainerRef = useRef<HTMLDivElement>(null);
    const chartRef = useRef<IChartApi | null>(null);
    const seriesRef = useRef<ISeriesApi<"Histogram"> | null>(null);
    const [currentNet, setCurrentNet] = useState<number>(0);

    useEffect(() => {
        if (!chartContainerRef.current) return;

        const chart = createChart(chartContainerRef.current, {
            layout: { background: { type: ColorType.Solid, color: 'transparent' }, textColor: '#94a3b8' },
            grid: { vertLines: { color: '#1e293b' }, horzLines: { color: '#1e293b' } },
            width: chartContainerRef.current.clientWidth,
            height: 250,
            timeScale: { timeVisible: true, secondsVisible: true },
        });

        const series = chart.addSeries(HistogramSeries, {
            color: '#26a69a',
        });

        chartRef.current = chart;
        seriesRef.current = series;

        const handleResize = () => chart.applyOptions({ width: chartContainerRef.current?.clientWidth || 0 });
        window.addEventListener('resize', handleResize);

        return () => {
            window.removeEventListener('resize', handleResize);
            chart.remove();
        };
    }, []);

    useEffect(() => {
        if (!authToken || !mt4Account || !broker || !seriesRef.current) return;

        const fetchData = async () => {
            try {
                // Fetch a reasonable amount of history to reconstruct exposure
                const res = await axios.get(`${API_BASE}/trade_history?mt4_account=${mt4Account}&broker=${encodeURIComponent(broker)}&limit=2000`, {
                    headers: { Authorization: `Bearer ${authToken}` }
                });

                // We need to reconstruct exposure. 
                // Assumption: trade_history contains CLOSED trades. We need open/close times.
                // Reconstructing full historical exposure from closed trades + current positions is complex because "current positions" 
                // only gives us the *now*, and closed trades give us the *past*.
                // A correct approach would be to replay ALL trades (open and close events).
                // However, `trade_history` usually just logs closed trades.
                // If the API returns `open_time` and `close_time` for closed trades, we can reconstruct the overlap.
                // For currently open positions, we would need to merge them in.

                // Let's see what we can do with `res.data.data` (paginated response usually, or array).
                const trades = Array.isArray(res.data) ? res.data : (res.data.data || []);

                // Fetch current active positions to add to the timeline
                const stateRes = await axios.get(`${API_BASE}/state?mt4_account=${mt4Account}&broker=${encodeURIComponent(broker)}`, {
                    headers: { Authorization: `Bearer ${authToken}` }
                });
                const currentPositions = stateRes.data?.account_status?.positions || [];

                // Event Sourcing Reconstruction
                interface ExposureEvent {
                    time: number;
                    change: number;
                    type: 'OPEN' | 'CLOSE';
                }
                const events: ExposureEvent[] = [];

                // 1. Process History (Closed Trades)
                trades.forEach((t: any) => {
                    const lots = t.trade_type === 'BUY' ? t.lots : -t.lots;
                    // Open adds exposure
                    events.push({ time: t.open_time, change: lots, type: 'OPEN' });
                    // Close removes exposure (subtraction of the signed lots)
                    events.push({ time: t.close_time, change: -lots, type: 'CLOSE' });
                });

                // 2. Process Active Positions (Only Open events, as they are not closed yet)
                // Note: If an active position was opened a long time ago, it might be before our history limit?
                // For accurate chart, we hope 2000 trades cover it, or we accept partial data at start.
                currentPositions.forEach((p: any) => {
                    const lots = p.side === 'BUY' ? p.lots : -p.lots;
                    events.push({ time: p.open_time, change: lots, type: 'OPEN' });
                    // It is still open, so no close event.
                    // But we should add a "now" point to extend the chart to the right edge
                });

                // Sort events
                events.sort((a, b) => a.time - b.time);

                const exposureData: { time: Time, value: number, color: string }[] = [];
                let currentNetLots = 0;
                let currentBuyLots = 0;
                let currentSellLots = 0;

                // Replay
                events.forEach(e => {
                    // Update Counts for Overweight Logic
                    if (e.type === 'OPEN') {
                        if (e.change > 0) currentBuyLots += e.change;
                        else currentSellLots += Math.abs(e.change);
                    } else {
                        // Close event: e.change is negative of original lots. 
                        // if original was BUY (lots>0), change is negative. 
                        if (e.change < 0) currentBuyLots += e.change; // e.change is negative
                        else currentSellLots -= e.change; // e.change is positive (reversing a SELL which was neg)
                    }
                    // Safety clamp
                    if (currentBuyLots < 0) currentBuyLots = 0;
                    if (currentSellLots < 0) currentSellLots = 0;

                    currentNetLots += e.change;

                    // Apply Overweight Colour Logic
                    // "g_SellOverweight": Buy > 0 && Sell/Buy > 3.0 && Sell-Buy > 0.2
                    // "g_BuyOverweight": Sell > 0 && Buy/Sell > 3.0 && Buy-Sell > 0.2
                    let color = '#26a69a'; // Default Teal
                    if (currentNetLots < 0) color = '#f43f5e'; // Default Short Red

                    const isSellOverweight = currentBuyLots > 0 && (currentSellLots / currentBuyLots > 3.0) && (currentSellLots - currentBuyLots > 0.2);
                    const isBuyOverweight = currentSellLots > 0 && (currentBuyLots / currentSellLots > 3.0) && (currentBuyLots - currentSellLots > 0.2);

                    if (isSellOverweight || isBuyOverweight) {
                        color = '#fbbf24'; // Amber Warning
                    }

                    // Only add point if time changed from last, or just push all and dedup?
                    // Lightweight charts needs unique times.
                    // Also histograms are usually "per interval". But here we have irregular events.
                    // We can use a Step Line (Area with steps) or Histogram. 
                    // Histogram with explicit times works well for discrete periods.

                    exposureData.push({
                        time: Number(e.time) as Time,
                        value: currentNetLots,
                        color: color
                    });
                });

                // Deduplicate map to keep last state for that second
                const uniqueExposure = Array.from(new Map(exposureData.map(item => [item.time, item])).values())
                    .sort((a, b) => (a.time as number) - (b.time as number));

                if (uniqueExposure.length > 0) {
                    // Add a final point for "Now" if not present, to show current state
                    const now = Math.floor(Date.now() / 1000) as Time;
                    const lastState = uniqueExposure[uniqueExposure.length - 1];
                    if ((lastState.time as number) < (now as number)) {
                        uniqueExposure.push({ ...lastState, time: now });
                    }

                    setCurrentNet(lastState.value);
                    seriesRef.current?.setData(uniqueExposure);
                    chartRef.current?.timeScale().fitContent();
                }

            } catch (e) {
                console.error("Exposure Calc Error", e);
            }
        };

        fetchData();
        const interval = setInterval(fetchData, 60000);
        return () => clearInterval(interval);

    }, [authToken, mt4Account, broker]);

    return (
        <div className="bg-slate-900/50 border border-slate-800 rounded-2xl p-6 flex flex-col">
            <div className="flex justify-between items-center mb-4">
                <h3 className="font-bold text-slate-300 flex items-center gap-2 uppercase tracking-wide text-sm">
                    <Split className="w-4 h-4 text-cyan-500" />
                    多空敞口 (Net Exposure)
                </h3>
                <div className={`text-xs font-mono font-bold px-2 py-1 rounded border ${Math.abs(currentNet) > 0.5 ? 'bg-amber-500/10 text-amber-500 border-amber-500/50' : 'bg-slate-800 text-slate-400 border-slate-700'}`}>
                    净头寸: {currentNet.toFixed(2)} Lot
                </div>
            </div>
            <div ref={chartContainerRef} className="w-full flex-1" />
            <div className="mt-2 text-[10px] text-slate-600 flex items-center gap-2">
                <span className="w-2 h-2 rounded-full bg-amber-500 block"></span> 黄色区域表示触发了“超仓”预警 (单边失衡 &gt; 3倍)
            </div>
        </div>
    );
};
