
import React, { useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { createChart, ColorType, CandlestickSeries, LineSeries } from 'lightweight-charts';
import type { IChartApi as IChartApiType, ISeriesApi as ISeriesApiType, SeriesMarker, Time } from 'lightweight-charts';
import axios from 'axios';
import { Activity, ChevronUp, Eye, EyeOff, History, Settings, Maximize2, Minimize2 } from 'lucide-react';
import { QuickTradePanel } from './QuickTradePanel';
import { API_BASE } from '../config';
import type { AccountStatus } from '../types';
import { calculateLiquidationPriceV2 as calculateLiquidationPrice, calculateSurvivalDistance, calculateRiskLevel, calculateATR } from '../utils/smartExitCalculations';

interface ChartWidgetProps {
    symbol: string;
    currentData: any;
    authToken: string | null;
    history?: any[];
    positions?: any[];
    accountStatus?: AccountStatus;
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

export const ChartWidget: React.FC<ChartWidgetProps> = ({ symbol, currentData, authToken, history = [], positions = [], accountStatus }) => {
    const chartContainerRef = useRef<HTMLDivElement>(null);
    const fullScreenContainerRef = useRef<HTMLDivElement>(null);
    const canvasRef = useRef<HTMLCanvasElement>(null);
    const chartRef = useRef<IChartApiType | null>(null);
    const seriesRef = useRef<ISeriesApiType<"Candlestick"> | null>(null);
    const maSeriesRef = useRef<ISeriesApiType<"Line"> | null>(null);
    const lastCandleRef = useRef<{ time: number, open: number, high: number, low: number, close: number } | null>(null);
    const allCandlesRef = useRef<any[]>([]); // Store all candles for MA calc
    const liquidationLineRef = useRef<any>(null); // Reference for liquidation price line


    const [timeframe, setTimeframe] = useState(() => localStorage.getItem('chart_timeframe') || 'M1');
    const [showHistory, setShowHistory] = useState(false);
    const [showPositions, setShowPositions] = useState(false);
    const [showMA, setShowMA] = useState(false);
    const [isToolbarOpen, setIsToolbarOpen] = useState(false); // Collapsible for mobile
    const [isFullScreen, setIsFullScreen] = useState(false);

    // Toggle Full Screen with CSS + Native Fallback
    const toggleFullScreen = () => {
        const nextState = !isFullScreen;
        setIsFullScreen(nextState);

        if (nextState) {
            // Attempt Native Fullscreen if supported
            if (fullScreenContainerRef.current?.requestFullscreen) {
                fullScreenContainerRef.current.requestFullscreen().catch(err => {
                    console.warn("Native fullscreen failed or blocked, falling back to CSS overlay:", err);
                });
            }
        } else {
            // Exit Native Fullscreen if active
            if (document.fullscreenElement) {
                document.exitFullscreen().catch(() => { });
            }
        }
    };

    // Listen for Native Full Screen changes (e.g. via ESC key)
    useEffect(() => {
        const handleFullScreenChange = () => {
            // Only sync if native fullscreen is exited externally (like ESC)
            // If we are in CSS fullscreen mode but not native, this won't fire.
            // If we are native and user presses ESC, this fires and document.fullscreenElement becomes null.
            if (!document.fullscreenElement && isFullScreen) {
                setIsFullScreen(false);
            }
        };

        document.addEventListener('fullscreenchange', handleFullScreenChange);
        // Webkit prefix for iOS/Safari just in case (though standardized now mostly)
        // @ts-ignore
        document.addEventListener('webkitfullscreenchange', handleFullScreenChange);

        return () => {
            document.removeEventListener('fullscreenchange', handleFullScreenChange);
            // @ts-ignore
            document.removeEventListener('webkitfullscreenchange', handleFullScreenChange);
        };
    }, [isFullScreen]);

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
            height: chartContainerRef.current.clientHeight || 400,
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
                chart.applyOptions({
                    width: chartContainerRef.current.clientWidth,
                    height: chartContainerRef.current.clientHeight
                });
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
    }, [isFullScreen]);

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

    // Update Liquidation Price Line
    useEffect(() => {
        if (!seriesRef.current || !accountStatus || !currentData) return;

        const symbolInfo = {
            contractSize: accountStatus.contract_size || 100,
            stopOutLevel: accountStatus.margin_so_level || 50,
            tickValue: accountStatus.tick_value || 1
        };

        const buyLots = accountStatus.positions.filter(p => p.side === 'BUY').reduce((acc, p) => acc + p.lots, 0);
        const sellLots = accountStatus.positions.filter(p => p.side === 'SELL').reduce((acc, p) => acc + p.lots, 0);

        const liqResult = calculateLiquidationPrice(
            accountStatus.equity,
            accountStatus.margin,
            symbolInfo.stopOutLevel,
            buyLots,
            sellLots,
            symbolInfo.contractSize,
            currentData.bid || currentData.close,
            currentData.ask || currentData.close
        );
        const liqPrice = liqResult.effectiveLiquidationPrice;

        // Calculate ATR for Risk Coloring
        let riskColor = '#ef4444'; // Default Red
        let lineWidth: 1 | 2 | 3 | 4 = 1;
        let lineStyle = 2; // Dashed

        if (allCandlesRef.current.length > 14) {
            const atr = calculateATR(allCandlesRef.current, 14);
            const netLots = accountStatus.positions.reduce((acc, p) => acc + (p.side === 'BUY' ? p.lots : -p.lots), 0);

            const dist = calculateSurvivalDistance(
                accountStatus.equity,
                accountStatus.margin,
                symbolInfo.stopOutLevel,
                netLots,
                symbolInfo.contractSize
            );

            const level = calculateRiskLevel(dist, atr);

            if (level === 'SAFE') {
                riskColor = '#10b981'; // Emerald 500
                lineStyle = 2; // Dashed
                lineWidth = 1;
            } else if (level === 'WARNING') {
                riskColor = '#f59e0b'; // Amber 500
                lineStyle = 2; // Dashed
                lineWidth = 2;
            } else { // CRITICAL
                riskColor = '#ef4444'; // Red 500
                lineStyle = 0; // Solid
                lineWidth = 2;
            }
        }

        if (liqPrice > 0 && isFinite(liqPrice)) {
            if (liquidationLineRef.current) {
                liquidationLineRef.current.applyOptions({
                    price: liqPrice,
                    color: riskColor,
                    lineWidth: lineWidth,
                    lineStyle: lineStyle,
                    title: `Liquidation @ ${liqPrice.toFixed(2)}`,
                });
            } else {
                liquidationLineRef.current = seriesRef.current.createPriceLine({
                    price: liqPrice,
                    color: riskColor,
                    lineWidth: lineWidth,
                    lineStyle: lineStyle, // Dashed
                    axisLabelVisible: true,
                    title: `Liquidation @ ${liqPrice.toFixed(2)}`,
                });
            }
        } else {
            // Remove if invalid or safe
            if (liquidationLineRef.current) {
                seriesRef.current.removePriceLine(liquidationLineRef.current);
                liquidationLineRef.current = null;
            }
        }

    }, [accountStatus, currentData, symbol]);

    // Fetch Data
    useEffect(() => {
        const fetchData = async () => {
            if (!symbol || !seriesRef.current) return;
            try {
                const response = await axios.get(`${API_BASE}/candles`, {
                    params: { symbol, timeframe },
                    headers: { Authorization: authToken ? `Bearer ${authToken}` : '' }
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

        // 1. 检测停市：如果最后一根K线的时间距离当前超过阈值，认为停市
        if (lastCandleRef.current) {
            const nowLocal = Math.floor(Date.now() / 1000);
            const staleness = nowLocal - (lastCandleRef.current.time as number);
            // 如果数据延迟超过 3 个周期，认为停市
            if (staleness > intervalSeconds * 3) {
                return; // 跳过更新
            }
        }

        const candleTime = Math.floor(now / intervalSeconds) * intervalSeconds;

        let newCandle;

        if (lastCandleRef.current) {
            // Guard: Prevent updating with older time (Lightweight Charts Error 136)
            if (candleTime < lastCandleRef.current.time) {
                console.warn(`[ChartWidget] Skipping update: New time ${candleTime} < Last time ${lastCandleRef.current.time}`);
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


    const content = (
        <div
            ref={fullScreenContainerRef}
            className={`
                bg-slate-900/50 border border-slate-800 rounded-2xl flex flex-col group transition-all duration-300 
                ${isFullScreen
                    ? 'fixed inset-0 z-[9999] bg-slate-950 p-4 rounded-none border-0 overscroll-none portrait:w-[100dvh] portrait:h-[100dvw] portrait:rotate-90 portrait:origin-center portrait:top-1/2 portrait:left-1/2 portrait:-translate-x-1/2 portrait:-translate-y-1/2'
                    : 'relative p-4 md:p-6 h-[320px] md:h-[500px]'
                }
            `}
        >
            <div className={isFullScreen ? 'hidden' : ''}>
                <QuickTradePanel symbol={symbol} />
            </div>

            {/* Header & Toolbar */}
            <div className={`flex flex-col lg:flex-row justify-between items-start lg:items-center gap-3 lg:gap-0 ${isFullScreen ? 'mb-1' : 'mb-4'}`}>

                {/* Top Row: Title + Bid/Ask + Mobile Toggle */}
                <div className="flex items-center justify-between w-full lg:w-auto gap-3">
                    <div className="flex flex-wrap items-center gap-3">
                        <h3 className="font-bold text-slate-300 flex items-center gap-2 uppercase tracking-wide text-sm whitespace-nowrap">
                            <History className="w-4 h-4 text-cyan-500" />
                            <span className="hidden sm:inline">K线图</span>
                            <span className="sm:hidden">Chart</span>
                            ({timeframe})
                        </h3>

                        {currentData && (
                            <div className="flex items-center gap-2 bg-slate-900/50 px-2 py-1 rounded-lg border border-slate-700/50">
                                <div className="flex flex-col items-end leading-none">
                                    <span className="text-[8px] text-slate-500 font-bold tracking-wider">BID</span>
                                    <span className="text-emerald-500 font-mono text-xs sm:text-sm font-bold">{currentData.bid}</span>
                                </div>
                                <div className="h-3 w-px bg-slate-700" />
                                <div className="flex flex-col items-start leading-none">
                                    <span className="text-[8px] text-slate-500 font-bold tracking-wider">ASK</span>
                                    <span className="text-rose-500 font-mono text-xs sm:text-sm font-bold">{currentData.ask}</span>
                                </div>
                            </div>
                        )}
                    </div>

                    {/* Mobile Menu Toggle Button */}
                    <button
                        onClick={() => setIsToolbarOpen(!isToolbarOpen)}
                        className={`lg:hidden p-1.5 bg-slate-800 border border-slate-700 rounded-lg text-slate-400 hover:text-cyan-400 transition-colors shadow-lg active:scale-95 ${isFullScreen ? 'hidden' : ''}`}
                    >
                        {isToolbarOpen ? <ChevronUp className="w-5 h-5" /> : <Settings className="w-5 h-5" />}
                    </button>
                </div>

                {/* Toolbar Content: Hidden on mobile unless toggled, always visible in FS */}
                <div className={`${isToolbarOpen || isFullScreen ? 'flex animate-in slide-in-from-top-2 duration-200' : 'hidden'} lg:flex ${isFullScreen ? 'flex-row justify-between' : 'flex-col lg:flex-row'} items-center w-full lg:w-auto gap-4`}>

                    {/* Display Controls (Hist/POS/MA) */}
                    <div className={`flex items-center gap-2 lg:w-auto justify-end ${isFullScreen ? 'w-auto' : 'w-full'}`}>
                        {/* History Toggle */}
                        <button
                            onClick={() => setShowHistory(!showHistory)}
                            className={`flex items-center justify-center h-8 px-3 rounded text-[10px] font-bold uppercase tracking-wider transition-colors ${showHistory ? 'bg-cyan-500/20 text-cyan-400 border border-cyan-500/30' : 'bg-slate-800 text-slate-500 border border-slate-700'
                                }`}
                            title="显示历史交易标记"
                        >
                            {showHistory ? <Eye className="w-3.5 h-3.5" /> : <EyeOff className="w-3.5 h-3.5" />}
                            <span className="ml-1.5">Hist</span>
                        </button>

                        {/* Positions Toggle */}
                        <button
                            onClick={() => setShowPositions(!showPositions)}
                            className={`flex items-center justify-center h-8 px-3 rounded text-[10px] font-bold uppercase tracking-wider transition-colors ${showPositions ? 'bg-cyan-500/20 text-cyan-400 border border-cyan-500/30' : 'bg-slate-800 text-slate-500 border border-slate-700'
                                }`}
                            title="显示当前持仓线"
                        >
                            {showPositions ? <Eye className="w-3.5 h-3.5" /> : <EyeOff className="w-3.5 h-3.5" />}
                            <span className="ml-1.5">POS</span>
                        </button>

                        {/* MA Toggle */}
                        <button
                            onClick={() => setShowMA(!showMA)}
                            className={`flex items-center justify-center h-8 px-3 rounded text-[10px] font-bold uppercase tracking-wider transition-colors ${showMA ? 'bg-amber-500/20 text-amber-400 border border-amber-500/30' : 'bg-slate-800 text-slate-500 border border-slate-700'
                                }`}
                            title="显示 SMA(20) 均线"
                        >
                            <Activity className="w-3.5 h-3.5" />
                            <span className="ml-1.5">MA</span>
                        </button>

                        {/* Full Screen Toggle */}
                        <button
                            onClick={toggleFullScreen}
                            className={`flex items-center justify-center h-8 px-3 rounded text-[10px] font-bold uppercase tracking-wider transition-colors ${isFullScreen ? 'bg-indigo-500/20 text-indigo-400 border border-indigo-500/30' : 'bg-slate-800 text-slate-500 border border-slate-700'
                                }`}
                            title={isFullScreen ? "退出全屏" : "全屏显示"}
                        >
                            {isFullScreen ? <Minimize2 className="w-3.5 h-3.5" /> : <Maximize2 className="w-3.5 h-3.5" />}
                            <span className="ml-1.5 hidden sm:inline">{isFullScreen ? "Exit" : "Full"}</span>
                        </button>
                    </div>

                    {/* Timeframes Scrollable Area */}
                    <div className={`lg:w-auto overflow-x-auto pb-1 lg:pb-0 no-scrollbar ${isFullScreen ? 'w-auto' : 'w-full'}`}>
                        <div className="flex bg-slate-800 rounded-lg p-1 gap-1 min-w-max">
                            {TIMEFRAMES.map((tf) => (
                                <button
                                    key={tf.value}
                                    onClick={() => handleTimeframeChange(tf.value)}
                                    className={`px-3 py-1.5 text-[10px] sm:text-xs font-bold rounded transition-colors whitespace-nowrap ${timeframe === tf.value
                                        ? 'bg-cyan-600 text-white shadow-sm'
                                        : 'text-slate-400 hover:text-slate-200 hover:bg-slate-700'
                                        }`}
                                >
                                    {tf.label}
                                </button>
                            ))}
                        </div>
                    </div>
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

    if (isFullScreen) {
        return createPortal(content, document.body);
    }
    return content;
};
