
import React, { useEffect, useRef, useState } from 'react';
import { createChart, ColorType, CandlestickSeries } from 'lightweight-charts';
import type { IChartApi as IChartApiType, ISeriesApi as ISeriesApiType } from 'lightweight-charts';
import axios from 'axios';
import { History } from 'lucide-react';

const API_BASE = 'http://127.0.0.1:3001/api/v1';

interface ChartWidgetProps {
    symbol: string;
}

const TIMEFRAMES = [
    { label: 'M1', value: 'M1' },
    { label: 'M5', value: 'M5' },
    { label: 'M15', value: 'M15' },
    { label: 'M30', value: 'M30' },
    { label: 'H1', value: 'H1' },
    { label: 'H4', value: 'H4' },
    { label: 'D1', value: 'D1' },
    { label: 'W1', value: 'W1' },
    { label: 'MN', value: 'MN' },
];

export const ChartWidget: React.FC<ChartWidgetProps> = ({ symbol }) => {
    const chartContainerRef = useRef<HTMLDivElement>(null);
    const chartRef = useRef<IChartApiType | null>(null);
    const seriesRef = useRef<ISeriesApiType<"Candlestick"> | null>(null);

    const [timeframe, setTimeframe] = useState(() => localStorage.getItem('chart_timeframe') || 'M1');

    // Handle Timeframe Change
    const handleTimeframeChange = (tf: string) => {
        setTimeframe(tf);
        localStorage.setItem('chart_timeframe', tf);
    };

    // Initialize Chart
    useEffect(() => {
        if (!chartContainerRef.current) return;

        const chart = createChart(chartContainerRef.current, {
            layout: {
                background: { type: ColorType.Solid, color: '#0f172a' }, // Slate 900
                textColor: '#94a3b8',
            },
            grid: {
                vertLines: { color: '#1e293b' },
                horzLines: { color: '#1e293b' },
            },
            width: chartContainerRef.current.clientWidth,
            height: 400,
            timeScale: {
                timeVisible: true,
                secondsVisible: false,
            },
        });

        const series = chart.addSeries(CandlestickSeries, {
            upColor: '#f43f5e', // Rose 500 (Red for Up)
            downColor: '#10b981', // Emerald 500 (Green for Down)
            borderVisible: false,
            wickUpColor: '#f43f5e',
            wickDownColor: '#10b981',
        });

        chartRef.current = chart;
        seriesRef.current = series;

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

    // Fetch Data
    useEffect(() => {
        const fetchData = async () => {
            if (!symbol || !seriesRef.current) return;
            try {
                const response = await axios.get(`${API_BASE}/candles`, {
                    params: { symbol, timeframe }
                });

                // Ensure unique time points and sorted
                const data = response.data.map((d: any) => ({
                    time: d.time,
                    open: d.open,
                    high: d.high,
                    low: d.low,
                    close: d.close
                }));

                if (data.length > 0) {
                    seriesRef.current.setData(data);
                }
            } catch (err) {
                console.error("Failed to fetch candle data", err);
            }
        };

        fetchData(); // Initial load
        const interval = setInterval(fetchData, 2000); // Poll every 2s

        return () => clearInterval(interval);
    }, [symbol, timeframe]);

    return (
        <div className="bg-slate-900/50 border border-slate-800 rounded-2xl p-6 h-[500px] flex flex-col">
            {/* Header & Toolbar */}
            <div className="flex justify-between items-center mb-4">
                <h3 className="font-bold text-slate-300 flex items-center gap-2 uppercase tracking-wide text-sm">
                    <History className="w-4 h-4 text-cyan-500" /> K-Line Chart ({timeframe})
                </h3>

                <div className="flex bg-slate-800 rounded-lg p-1 gap-1">
                    {TIMEFRAMES.map((tf) => (
                        <button
                            key={tf.value}
                            onClick={() => handleTimeframeChange(tf.value)}
                            className={`px-3 py-1 text-xs font-bold rounded transition-colors ${timeframe === tf.value
                                ? 'bg-cyan-600 text-white shadow-sm'
                                : 'text-slate-400 hover:text-slate-200 hover:bg-slate-700'
                                }`}
                        >
                            {tf.label}
                        </button>
                    ))}
                </div>
            </div>

            {/* Chart Container */}
            <div ref={chartContainerRef} className="w-full flex-1" />
        </div>
    );
};
