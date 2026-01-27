import React, { useEffect, useRef, useState } from 'react';
import { createChart, ColorType, AreaSeries } from 'lightweight-charts';
import type { IChartApi, ISeriesApi, Time } from 'lightweight-charts';
import axios from 'axios';
import { AreaChart } from 'lucide-react';

interface EquityChartWidgetProps {
    currentAccountStatus?: any;
}

const API_BASE = 'http://127.0.0.1:3001/api/v1';

export const EquityChartWidget: React.FC<EquityChartWidgetProps> = ({ currentAccountStatus }) => {
    const chartContainerRef = useRef<HTMLDivElement>(null);
    const chartRef = useRef<IChartApi | null>(null);
    const balanceSeriesRef = useRef<ISeriesApi<"Area"> | null>(null);
    const equitySeriesRef = useRef<ISeriesApi<"Area"> | null>(null);
    const lastTimeRef = useRef<number>(0);

    const [isLoaded, setIsLoaded] = useState(false);

    // Initial Setup
    useEffect(() => {
        if (!chartContainerRef.current) return;

        const chart = createChart(chartContainerRef.current, {
            layout: {
                background: { type: ColorType.Solid, color: 'transparent' },
                textColor: '#94a3b8',
            },
            grid: {
                vertLines: { color: '#1e293b' },
                horzLines: { color: '#1e293b' },
            },
            width: chartContainerRef.current.clientWidth,
            height: 200,
            timeScale: {
                timeVisible: true,
                secondsVisible: true,
            },
        });

        const balanceSeries = chart.addSeries(AreaSeries, {
            lineColor: '#64748b',
            topColor: 'rgba(100, 116, 139, 0.4)',
            bottomColor: 'rgba(100, 116, 139, 0.0)',
            lineWidth: 2,
        });

        const equitySeries = chart.addSeries(AreaSeries, {
            lineColor: '#10b981',
            topColor: 'rgba(10, 185, 129, 0.4)',
            bottomColor: 'rgba(10, 185, 129, 0.0)',
            lineWidth: 2,
        });

        chartRef.current = chart;
        balanceSeriesRef.current = balanceSeries;
        equitySeriesRef.current = equitySeries;

        // Fetch History
        const fetchHistory = async () => {
            try {
                const res = await axios.get(`${API_BASE}/account/history?limit=500`);
                const history = res.data;

                // Map to Series Data
                const balanceData = history.map((h: any) => ({
                    time: h.timestamp as Time,
                    value: h.balance
                }));
                const equityData = history.map((h: any) => ({
                    time: h.timestamp as Time,
                    value: h.equity
                }));

                // Deduplicate and Sort
                balanceSeries.setData(balanceData);
                equitySeries.setData(equityData);

                // Initialize lastTimeRef with the latest history time
                if (history.length > 0) {
                    // History is ascending (from backend)
                    lastTimeRef.current = history[history.length - 1].timestamp;
                }

                chart.timeScale().fitContent();
                setIsLoaded(true);
            } catch (e) {
                console.error("Failed to fetch equity history", e);
            }
        };

        fetchHistory();

        const handleResize = () => {
            if (chartContainerRef.current) {
                chart.applyOptions({ width: chartContainerRef.current.clientWidth });
            }
        };

        window.addEventListener('resize', handleResize);

        return () => {
            window.removeEventListener('resize', handleResize);
            chart.remove();
        };
    }, []);

    // Real-time Updates
    useEffect(() => {
        if (!isLoaded || !currentAccountStatus || !balanceSeriesRef.current || !equitySeriesRef.current) return;

        // Use server timestamp if available, otherwise fallback to local time (but dangerous if mixed)
        // Ensure strictly increasing time for chart updates
        let time = currentAccountStatus.timestamp
            ? (currentAccountStatus.timestamp as number)
            : Math.floor(Date.now() / 1000);

        // Guard: If new time is not greater than last update time, skip or clamp?
        // Lightweight charts `update` allows replacing the *current* bar (same time), but not older.
        // So time >= lastTimeRef.current is required.

        // HOWEVER, if we just fetched history, lastWait... history might end at T=100.
        // If we try to update at T=99, it errors.
        // We need to track the latest time in the chart.

        // On load, we should set lastTimeRef to the last history point.
        // But we didn't save it. 
        // Let's rely on the incoming timestamp being correct (it comes from the same source as history).

        // If getting duplicate timestamp (same second), it's an update to the current candle/point -> Allowed.
        // If getting older timestamp -> Ignore.

        if (lastTimeRef.current > 0 && time < lastTimeRef.current) {
            // console.warn("Skipping out-of-order update", time, lastTimeRef.current);
            return;
        }

        lastTimeRef.current = time;

        const chartTime = time as Time;

        // Update Series
        balanceSeriesRef.current.update({
            time: chartTime,
            value: currentAccountStatus.balance
        });

        equitySeriesRef.current.update({
            time: chartTime,
            value: currentAccountStatus.equity
        });

    }, [currentAccountStatus, isLoaded]);

    return (
        <div className="bg-slate-900/50 border border-slate-800 rounded-2xl p-6 flex flex-col h-[280px]">
            <div className="flex justify-between items-center mb-4">
                <h3 className="font-bold text-slate-300 flex items-center gap-2 uppercase tracking-wide text-sm">
                    <AreaChart className="w-4 h-4 text-emerald-500" />
                    资金曲线
                </h3>
            </div>
            <div ref={chartContainerRef} className="w-full flex-1" />
        </div>
    );
};
