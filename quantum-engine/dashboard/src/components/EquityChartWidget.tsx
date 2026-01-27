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
            topColor: 'rgba(16, 185, 129, 0.4)',
            bottomColor: 'rgba(16, 185, 129, 0.0)',
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
                // Assuming backend returns sorted, but just in case
                balanceSeries.setData(balanceData);
                equitySeries.setData(equityData);
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

        // Using a global or provided timestamp if available, else local
        const time = Math.floor(Date.now() / 1000) as Time;

        // Update Series
        balanceSeriesRef.current.update({
            time: time,
            value: currentAccountStatus.balance
        });

        equitySeriesRef.current.update({
            time: time,
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
