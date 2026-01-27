
import React, { useEffect, useRef, useState } from 'react';
import { createChart, ColorType, CandlestickSeries, LineSeries } from 'lightweight-charts';
import type { IChartApi as IChartApiType, ISeriesApi as ISeriesApiType, SeriesMarker, Time } from 'lightweight-charts';
import axios from 'axios';
import { History, Eye, EyeOff, Activity } from 'lucide-react';
import { QuickTradePanel } from './QuickTradePanel';

const API_BASE = 'http://127.0.0.1:3001/api/v1';


interface ChartWidgetProps {
    symbol: string;
    currentData: any;
    history?: any[];
    positions?: any[];
}

const TIMEFRAMES = [
    { label: 'M1', value: 'M1', seconds: 60 },
    { label: 'M5', value: 'M5', seconds: 300 },
    { label: 'M15', value: 'M15', seconds: 900 },
    { label: 'M30', value: 'M30', seconds: 1800 },
    { label: 'H1', value: 'H1', seconds: 3600 },
    { label: 'H4', value: 'H4', seconds: 14400 },
    { label: 'D1', value: 'D1', seconds: 86400 },
    { label: 'W1', value: 'W1', seconds: 604800 },
    { label: 'MN', value: 'MN', seconds: 2592000 },
];

function calculateSMA(data: any[], period: number) {
    const smaData = [];
    for (let i = 0; i < data.length; i++) {
        if (i < period - 1) continue;
        let sum = 0;
        for (let j = 0; j < period; j++) {
            sum += data[i - j].close;
        }
        smaData.push({
            time: data[i].time,
            value: sum / period,
        });
    }
    return smaData;
}

export const ChartWidget: React.FC<ChartWidgetProps> = ({ symbol, currentData, history = [], positions = [] }) => {
    const chartContainerRef = useRef<HTMLDivElement>(null);
    const canvasRef = useRef<HTMLCanvasElement>(null);
    const chartRef = useRef<IChartApiType | null>(null);
    const seriesRef = useRef<ISeriesApiType<"Candlestick"> | null>(null);
    const maSeriesRef = useRef<ISeriesApiType<"Line"> | null>(null);
    const lastCandleRef = useRef<{ time: number, open: number, high: number, low: number, close: number } | null>(null);
    const allCandlesRef = useRef<any[]>([]); // Store all candles for MA calc


    const [timeframe, setTimeframe] = useState(() => localStorage.getItem('chart_timeframe') || 'M1');
    const [showHistory, setShowHistory] = useState(false);
    const [showPositions, setShowPositions] = useState(false);
    const [showMA, setShowMA] = useState(false);

    // Handle Timeframe Change
    const handleTimeframeChange = (tf: string) => {
        setTimeframe(tf);
        localStorage.setItem('chart_timeframe', tf);
        lastCandleRef.current = null;
        allCandlesRef.current = [];
    };

    // Redraw Trade Lines
    const drawTradeLines = () => {
        const canvas = canvasRef.current;
        const chart = chartRef.current;
        const series = seriesRef.current;
        if (!canvas || !chart || !series) return;

        const ctx = canvas.getContext('2d');
        if (!ctx) return;

        ctx.clearRect(0, 0, canvas.width, canvas.height);

        // 1. Draw Historical Trade Lines
        if (showHistory && history && history.length > 0) {
            const tfObj = TIMEFRAMES.find(t => t.value === timeframe);
            const intervalSeconds = tfObj ? tfObj.seconds : 60;
            const normalizeTime = (t: number) => {
                return (Math.floor(t / intervalSeconds) * intervalSeconds) as Time;
            };

            ctx.setLineDash([4, 4]);
            ctx.lineWidth = 1.5;

            history.forEach(trade => {
                if (!trade.open_time || !trade.close_time) return;

                const nOpenTime = normalizeTime(trade.open_time);
                const nCloseTime = normalizeTime(trade.close_time);

                const xOpen = chart.timeScale().timeToCoordinate(nOpenTime);
                const yOpen = series.priceToCoordinate(trade.open_price);
                const xClose = chart.timeScale().timeToCoordinate(nCloseTime);
                const yClose = series.priceToCoordinate(trade.close_price);

                if (xOpen === null || yOpen === null || xClose === null || yClose === null) return;

                ctx.beginPath();
                ctx.strokeStyle = trade.profit >= 0 ? '#10b981' : '#64748b';
                ctx.moveTo(xOpen, yOpen);
                ctx.lineTo(xClose, yClose);
                ctx.stroke();
            });
        }

        // 2. Draw Active Position Lines (Horizontal)
        if (showPositions && positions && positions.length > 0) {
            ctx.setLineDash([2, 2]);
            ctx.lineWidth = 1;

            positions.forEach(pos => {
                if (pos.symbol !== symbol || !pos.open_price) return;

                const yPos = series.priceToCoordinate(pos.open_price);
                if (yPos === null) return;

                ctx.beginPath();
                ctx.strokeStyle = pos.side === 'BUY' ? '#f43f5e' : '#10b981'; // Red / Green (Buy/Sell)
                ctx.moveTo(0, yPos);
                ctx.lineTo(canvas.width, yPos);
                ctx.stroke();

                // Draw label
                ctx.font = '10px monospace';
                ctx.fillStyle = pos.side === 'BUY' ? '#f43f5e' : '#10b981';
                ctx.fillText(`${pos.side} #${pos.ticket} @ ${pos.open_price.toFixed(5)}`, 10, yPos - 5);
            });
        }
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

        const maSeries = chart.addSeries(LineSeries, {
            color: '#fbbf24', // Amber-400
            lineWidth: 2,
            visible: false,
        });

        chartRef.current = chart;
        seriesRef.current = series;
        maSeriesRef.current = maSeries;

        // Logic for canvas overlay sync
        const updateCanvasSize = () => {
            if (canvasRef.current && chartContainerRef.current) {
                const chartElement = chartContainerRef.current.querySelector('.tv-lightweight-charts');
                if (chartElement) {
                    const rect = chartElement.getBoundingClientRect();
                    canvasRef.current.width = rect.width;
                    canvasRef.current.height = rect.height;
                    // Position the canvas
                    canvasRef.current.style.left = '0px';
                    canvasRef.current.style.top = '0px';
                }
            }
        };

        const handleResize = () => {
            if (chartContainerRef.current) {
                chart.applyOptions({ width: chartContainerRef.current.clientWidth });
                updateCanvasSize();
                drawTradeLines();
            }
        };

        window.addEventListener('resize', handleResize);

        // Initial size sync
        setTimeout(() => {
            updateCanvasSize();
            drawTradeLines();
        }, 100);

        // Subscribe to chart events
        chart.timeScale().subscribeVisibleTimeRangeChange(() => {
            drawTradeLines();
        });

        return () => {
            window.removeEventListener('resize', handleResize);
            chart.remove();
        };
    }, []);

    // Toggle MA Visibility
    useEffect(() => {
        if (maSeriesRef.current) {
            maSeriesRef.current.applyOptions({ visible: showMA });
        }
    }, [showMA]);

    // Update Markers & Lines
    useEffect(() => {
        if (!seriesRef.current) return;

        if (!showHistory || !history || history.length === 0) {
            if (seriesRef.current && (seriesRef.current as any).setMarkers) {
                (seriesRef.current as any).setMarkers([]);
            }
            drawTradeLines();
            return;
        }

        const tfObj = TIMEFRAMES.find(t => t.value === timeframe);
        const intervalSeconds = tfObj ? tfObj.seconds : 60;

        const normalizeTime = (t: number) => {
            return (Math.floor(t / intervalSeconds) * intervalSeconds) as Time;
        };

        const markers: SeriesMarker<Time>[] = [];

        history.forEach((trade) => {
            // Entry Marker
            if (trade.open_time) {
                markers.push({
                    time: normalizeTime(trade.open_time),
                    position: trade.trade_type === 'BUY' ? 'belowBar' : 'aboveBar',
                    color: trade.trade_type === 'BUY' ? '#ef4444' : '#22c55e', // Red / Green (Chinese standard)
                    shape: trade.trade_type === 'BUY' ? 'arrowUp' : 'arrowDown',
                    text: `Open #${trade.ticket}`,
                    size: 1, // default is 1
                });
            }

            // Exit Marker
            if (trade.close_time) {
                markers.push({
                    time: normalizeTime(trade.close_time),
                    position: trade.profit >= 0 ? 'aboveBar' : 'belowBar', // Position doesn't matter much for non-arrow
                    color: trade.profit >= 0 ? '#fbbf24' : '#94a3b8', // Amber (Gold) / Slate (Gray)
                    shape: 'circle',
                    text: `Close #${trade.ticket} (${trade.profit.toFixed(2)})`,
                    size: 1,
                });
            }
        });

        // Markers must be sorted by time
        markers.sort((a, b) => (a.time as number) - (b.time as number));

        if (seriesRef.current && (seriesRef.current as any).setMarkers) {
            (seriesRef.current as any).setMarkers(markers);
        } else {
            console.warn("setMarkers is not defined on series", seriesRef.current);
        }

        drawTradeLines();

    }, [history, showHistory, timeframe, positions, showPositions]); // Added showPositions to deps

    // Fetch Data
    useEffect(() => {
        const fetchData = async () => {
            if (!symbol || !seriesRef.current) return;
            try {
                const response = await axios.get(`${API_BASE}/candles`, {
                    params: { symbol, timeframe }
                });

                const data = response.data.map((d: any) => ({
                    time: d.time,
                    open: d.open,
                    high: d.high,
                    low: d.low,
                    close: d.close
                }));

                if (data.length > 0) {
                    seriesRef.current.setData(data);
                    lastCandleRef.current = data[data.length - 1];
                    allCandlesRef.current = data;

                    // Update MA if enabled
                    if (maSeriesRef.current) {
                        const sma = calculateSMA(data, 20); // SMA 20
                        maSeriesRef.current.setData(sma);
                    }

                    // Redraw lines since data might have changed the Y scale
                    drawTradeLines();
                }
            } catch (err) {
                console.error("Failed to fetch candle data", err);
            }
        };

        fetchData();
        const interval = setInterval(fetchData, 5000);

        return () => clearInterval(interval);
    }, [symbol, timeframe]);

    // Real-time Tick Updates
    useEffect(() => {
        if (!currentData || !seriesRef.current) return;

        const currentPrice = currentData.bid;
        // USE SERVER TIMESTAMP if available (currentData.timestamp assumed to be seconds)
        // Fallback to local time if not available
        const now = currentData.timestamp ? currentData.timestamp : Math.floor(Date.now() / 1000);

        const tfObj = TIMEFRAMES.find(t => t.value === timeframe);
        const intervalSeconds = tfObj ? tfObj.seconds : 60;
        const candleTime = Math.floor(now / intervalSeconds) * intervalSeconds;

        let newCandle;

        if (lastCandleRef.current) {
            // Guard: Prevent updating with older time (Lightweight Charts Error 136)
            if (candleTime < lastCandleRef.current.time) {
                return;
            }

            if (lastCandleRef.current.time === candleTime) {
                // Update existing candle
                newCandle = {
                    ...lastCandleRef.current,
                    high: Math.max(lastCandleRef.current.high, currentPrice),
                    low: Math.min(lastCandleRef.current.low, currentPrice),
                    close: currentPrice,
                };
                // Update local cache for next tick
                lastCandleRef.current = newCandle;
                // Update allCandlesRef last element
                if (allCandlesRef.current.length > 0) {
                    allCandlesRef.current[allCandlesRef.current.length - 1] = newCandle;
                }
            } else {
                // New candle
                newCandle = {
                    time: candleTime,
                    open: currentPrice,
                    high: currentPrice,
                    low: currentPrice,
                    close: currentPrice,
                };
                lastCandleRef.current = newCandle;
                allCandlesRef.current.push(newCandle);
            }
        } else {
            // First candle
            newCandle = {
                time: candleTime,
                open: currentPrice,
                high: currentPrice,
                low: currentPrice,
                close: currentPrice,
            };
            lastCandleRef.current = newCandle;
            allCandlesRef.current = [newCandle];
        }

        seriesRef.current.update(newCandle as any);

        // Update MA Realtime
        if (maSeriesRef.current && allCandlesRef.current.length >= 20) {
            // Calculate SMA for the last point only to be efficient? 
            // Or just recalculate entire SMA for simplicity (array is small usually < 1000)
            // lightweight-charts optimized `setData` or `update`? 
            // For line series, `update` adds a new point.
            // If we updated the current candle (same time), we should update the MA value for that time.

            // Recalculate last MA point
            const data = allCandlesRef.current;
            const period = 20;
            let sum = 0;
            for (let j = 0; j < period; j++) {
                sum += data[data.length - 1 - j].close;
            }
            const maValue = sum / period;

            maSeriesRef.current.update({
                time: newCandle.time as Time,
                value: maValue
            });
        }

        // Redraw lines (though price only changes current non-closed trade lines if we had those)
        drawTradeLines();

    }, [currentData, timeframe]);


    return (
        <div className="bg-slate-900/50 border border-slate-800 rounded-2xl p-6 h-[500px] flex flex-col relative group">
            <QuickTradePanel symbol={symbol} />
            {/* Header & Toolbar */}
            <div className="flex justify-between items-center mb-4">
                <div className="flex items-center gap-4">
                    <h3 className="font-bold text-slate-300 flex items-center gap-2 uppercase tracking-wide text-sm">
                        <History className="w-4 h-4 text-cyan-500" /> K线图 ({timeframe})
                        {currentData && (
                            <span className="ml-2 text-cyan-400 font-mono text-base">
                                {currentData.bid}
                            </span>
                        )}
                    </h3>

                    {/* History Toggle */}
                    <button
                        onClick={() => setShowHistory(!showHistory)}
                        className={`flex items-center gap-1 px-2 py-1 rounded text-[10px] font-bold uppercase tracking-wider transition-colors ${showHistory ? 'bg-cyan-500/20 text-cyan-400 border border-cyan-500/30' : 'bg-slate-800 text-slate-500 border border-slate-700'
                            }`}
                        title="显示历史交易标记"
                    >
                        {showHistory ? <Eye className="w-3 h-3" /> : <EyeOff className="w-3 h-3" />}
                        History
                    </button>

                    {/* Positions Toggle */}
                    <button
                        onClick={() => setShowPositions(!showPositions)}
                        className={`flex items-center gap-1 px-2 py-1 rounded text-[10px] font-bold uppercase tracking-wider transition-colors ${showPositions ? 'bg-cyan-500/20 text-cyan-400 border border-cyan-500/30' : 'bg-slate-800 text-slate-500 border border-slate-700'
                            }`}
                        title="显示当前持仓线"
                    >
                        {showPositions ? <Eye className="w-3 h-3" /> : <EyeOff className="w-3 h-3" />}
                        POS
                    </button>

                    {/* MA Toggle */}
                    <button
                        onClick={() => setShowMA(!showMA)}
                        className={`flex items-center gap-1 px-2 py-1 rounded text-[10px] font-bold uppercase tracking-wider transition-colors ${showMA ? 'bg-amber-500/20 text-amber-400 border border-amber-500/30' : 'bg-slate-800 text-slate-500 border border-slate-700'
                            }`}
                        title="显示 SMA(20) 均线"
                    >
                        <Activity className="w-3 h-3" />
                        MA(20)
                    </button>
                </div>

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
            <div className="w-full flex-1 relative">
                <div ref={chartContainerRef} className="absolute inset-0 z-0" />
                <canvas
                    ref={canvasRef}
                    className="absolute inset-0 z-10 pointer-events-none"
                />
            </div>
        </div>
    );
};
