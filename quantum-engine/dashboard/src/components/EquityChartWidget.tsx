import React, { useEffect, useRef, useState, useCallback } from 'react';
import { createChart, ColorType, AreaSeries } from 'lightweight-charts';
import type { IChartApi, ISeriesApi, Time } from 'lightweight-charts';
import axios from 'axios';
import { AreaChart, Clock } from 'lucide-react';
import { API_BASE } from '../config';

interface EquityChartWidgetProps {
    currentAccountStatus?: any;
    authToken: string | null;
    mt4Account: number | null;
    broker: string | null;
}

type TimeRange = '1H' | '4H' | '12H' | '1D' | '3D' | '7D' | 'ALL';

const TIME_RANGE_OPTIONS: { key: TimeRange; label: string; hours: number }[] = [
    { key: '1H', label: '1小时', hours: 1 },
    { key: '4H', label: '4小时', hours: 4 },
    { key: '12H', label: '12小时', hours: 12 },
    { key: '1D', label: '1天', hours: 24 },
    { key: '3D', label: '3天', hours: 72 },
    { key: '7D', label: '7天', hours: 168 },
    { key: 'ALL', label: '全部', hours: 0 },
];

export const EquityChartWidget: React.FC<EquityChartWidgetProps> = ({ currentAccountStatus, authToken, mt4Account, broker }) => {
    const chartContainerRef = useRef<HTMLDivElement>(null);
    const chartRef = useRef<IChartApi | null>(null);
    const balanceSeriesRef = useRef<ISeriesApi<"Area"> | null>(null);
    const equitySeriesRef = useRef<ISeriesApi<"Area"> | null>(null);
    const lastTimeRef = useRef<number>(0);
    const allDataRef = useRef<{ balance: any[]; equity: any[] }>({ balance: [], equity: [] });

    const [isLoaded, setIsLoaded] = useState(false);
    const [timeRange, setTimeRange] = useState<TimeRange>('1D');

    // Initial Setup
    useEffect(() => {
        if (!chartContainerRef.current) return;

        const chart = createChart(chartContainerRef.current, {
            layout: {
                background: { type: ColorType.Solid, color: 'transparent' },
                textColor: '#94a3b8',
            },
            handleScroll: {
                mouseWheel: true,
                pressedMouseMove: true,
                horzTouchDrag: true,
                vertTouchDrag: true,
            },
            handleScale: {
                axisPressedMouseMove: true,
                mouseWheel: true,
                pinch: true,
            },
            grid: {
                vertLines: { color: '#1e293b' },
                horzLines: { color: '#1e293b' },
            },
            crosshair: {
                mode: 1, // CrosshairMode.Normal
                vertLine: {
                    width: 1,
                    color: '#334155',
                    style: 0,
                    labelVisible: true,
                },
                horzLine: {
                    width: 1,
                    color: '#334155',
                    style: 0,
                    labelVisible: true,
                },
            },
            width: chartContainerRef.current.clientWidth,
            height: 200,
            timeScale: {
                rightOffset: 12,
                barSpacing: 3,
                minBarSpacing: 0.1,
                fixLeftEdge: false,
                fixRightEdge: false,
                lockVisibleTimeRangeOnResize: true,
                rightBarStaysOnScroll: true,
                borderVisible: false,
                borderColor: '#1e293b',
                visible: true,
                timeVisible: true,
                secondsVisible: true,
                tickMarkFormatter: (time: number | object) => {
                    const timestamp = typeof time === 'number' ? time : (time as any).value || (time as any).time;
                    const date = new Date(timestamp * 1000);
                    const h = String(date.getUTCHours()).padStart(2, '0');
                    const m = String(date.getUTCMinutes()).padStart(2, '0');
                    return `${h}:${m}`;
                },
            },
            localization: {
                timeFormatter: (timestamp: number) => {
                    const date = new Date(timestamp * 1000);
                    const year = date.getUTCFullYear();
                    const month = String(date.getUTCMonth() + 1).padStart(2, '0');
                    const day = String(date.getUTCDate()).padStart(2, '0');
                    const hours = String(date.getUTCHours()).padStart(2, '0');
                    const minutes = String(date.getUTCMinutes()).padStart(2, '0');
                    const seconds = String(date.getUTCSeconds()).padStart(2, '0');
                    return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
                }
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
            if (!authToken || !mt4Account || !broker) {
                // Clear chart if no account
                balanceSeries.setData([]);
                equitySeries.setData([]);
                return;
            }
            try {
                const res = await axios.get(`${API_BASE}/account/history?mt4_account=${mt4Account}&broker=${encodeURIComponent(broker)}&limit=100000`, {
                    headers: { Authorization: `Bearer ${authToken}` }
                });
                const history = res.data;

                // Map to Series Data and filter nulls, ensure numeric types
                const processData = (data: any[], key: string) => {
                    const mapped = data
                        .filter((h: any) => {
                            if (!h.timestamp || h[key] === undefined || h[key] === null) return false;

                            // 🚀 UTC-based Weekend Filtering
                            // This ensures consistent behavior regardless of the user's local PC timezone.
                            const date = new Date(Number(h.timestamp) * 1000);
                            const day = date.getUTCDay(); // 0 is Sunday, 6 is Saturday
                            if (day === 0 || day === 6) return false;

                            return true;
                        })
                        .map((h: any) => ({
                            time: Number(h.timestamp) as Time,
                            value: Number(h[key])
                        }));

                    // Deduplicate by time (keep last value for each timestamp)
                    const unique = Array.from(
                        mapped.reduce((map, obj) => map.set(obj.time as any, obj), new Map<any, any>()).values()
                    );

                    // Sort by time ascending
                    return unique.sort((a, b) => (a.time as number) - (b.time as number));
                };

                const balanceData = processData(history, 'balance');
                const equityData = processData(history, 'equity');

                // Store all data for later filtering
                allDataRef.current = { balance: balanceData, equity: equityData };

                if (!chartRef.current) return; // Prevent update if unmounted

                console.log("Equity Chart - Data Processed:", {
                    original: history.length,
                    balance: balanceData.length,
                    equity: equityData.length,
                    firstTime: balanceData[0]?.time,
                    lastTime: balanceData[balanceData.length - 1]?.time
                });

                // Apply default time range filter (1D)
                const filterByTimeRange = (data: any[], hours: number) => {
                    if (hours === 0) return data; // ALL
                    const cutoff = Math.floor(Date.now() / 1000) - hours * 3600;
                    return data.filter(d => (d.time as number) >= cutoff);
                };

                const defaultHours = TIME_RANGE_OPTIONS.find(o => o.key === '1D')?.hours || 24;
                const filteredBalance = filterByTimeRange(balanceData, defaultHours);
                const filteredEquity = filterByTimeRange(equityData, defaultHours);

                if (filteredBalance.length > 0) {
                    balanceSeries.setData(filteredBalance);
                }
                if (filteredEquity.length > 0) {
                    equitySeries.setData(filteredEquity);
                }

                // Initialize lastTimeRef with the latest history time
                if (balanceData.length > 0) {
                    lastTimeRef.current = balanceData[balanceData.length - 1].time as number;
                } else if (equityData.length > 0) {
                    lastTimeRef.current = equityData[equityData.length - 1].time as number;
                }

                chart.timeScale().fitContent();
                setIsLoaded(true);
            } catch (e) {
                if (axios.isAxiosError(e) && e.response?.status === 403) {
                    console.warn("EquityChart access forbidden (403). Ignoring.");
                    return;
                }
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
    }, [authToken, mt4Account, broker]);

    // Real-time Updates
    useEffect(() => {
        if (!isLoaded || !currentAccountStatus || !balanceSeriesRef.current || !equitySeriesRef.current) return;

        let time = currentAccountStatus.timestamp
            ? Number(currentAccountStatus.timestamp)
            : Math.floor(Date.now() / 1000);

        if (time === 0) return; // Ignore invalid timestamp

        if (lastTimeRef.current > 0 && time < lastTimeRef.current) {
            return;
        }

        // 1. Detection of market closure: 
        // If the gap between current local time and data timestamp is too large, skip update.
        // This prevents the chart from drawing a line to "now" when the backend stops sending new data.
        const nowLocal = Math.floor(Date.now() / 1000);
        const staleness = nowLocal - time;
        if (staleness > 300) { // 5 minutes threshold
            return;
        }

        // Additional safety for values
        if (currentAccountStatus.balance === undefined || currentAccountStatus.balance === null ||
            currentAccountStatus.equity === undefined || currentAccountStatus.equity === null) {
            return;
        }

        lastTimeRef.current = time;
        const chartTime = time as Time;

        // 2. UTC Weekend Protection for Real-time ticks
        const date = new Date(time * 1000);
        if (date.getUTCDay() === 0 || date.getUTCDay() === 6) {
            return;
        }

        try {
            // Update Series
            balanceSeriesRef.current.update({
                time: chartTime,
                value: Number(currentAccountStatus.balance)
            });

            equitySeriesRef.current.update({
                time: chartTime,
                value: Number(currentAccountStatus.equity)
            });
        } catch (err) {
            console.error("Chart update error:", err, { time: chartTime, balance: currentAccountStatus.balance, equity: currentAccountStatus.equity });
        }

    }, [currentAccountStatus, isLoaded]);

    // Time range change handler
    const handleTimeRangeChange = useCallback((range: TimeRange) => {
        setTimeRange(range);

        if (!chartRef.current || !balanceSeriesRef.current || !equitySeriesRef.current) return;

        const { balance, equity } = allDataRef.current;
        if (balance.length === 0 && equity.length === 0) return;

        const hours = TIME_RANGE_OPTIONS.find(o => o.key === range)?.hours || 0;

        const filterByTimeRange = (data: any[], h: number) => {
            if (h === 0) return data; // ALL
            const cutoff = Math.floor(Date.now() / 1000) - h * 3600;
            return data.filter(d => (d.time as number) >= cutoff);
        };

        const filteredBalance = filterByTimeRange(balance, hours);
        const filteredEquity = filterByTimeRange(equity, hours);

        balanceSeriesRef.current.setData(filteredBalance.length > 0 ? filteredBalance : []);
        equitySeriesRef.current.setData(filteredEquity.length > 0 ? filteredEquity : []);

        chartRef.current.timeScale().fitContent();
    }, []);

    const calculateRiskRatio = () => {
        if (!currentAccountStatus || !currentAccountStatus.balance) return 0;
        const bal = currentAccountStatus.balance;
        const eq = currentAccountStatus.equity;
        // Float = Balance - Equity. if Equity > Balance (profit), this is negative.
        // We only care about Drawdown (Equity < Balance)
        if (eq >= bal) return 0;
        return ((bal - eq) / bal) * 100;
    };

    const riskRatio = calculateRiskRatio();
    const isHighRisk = riskRatio > 30;

    return (
        <div className={`bg-slate-900/50 border rounded-2xl p-4 md:p-6 flex flex-col min-h-[350px] md:h-[280px] transition-colors ${isHighRisk ? 'border-rose-500/50 shadow-[0_0_20px_rgba(244,63,94,0.1)]' : 'border-slate-800'}`}>
            <div className="flex flex-col md:flex-row justify-between items-center gap-4 mb-4">
                {/* Title Section - Mobile: Row with SpaceBetween (Title + Ratio), Desktop: Auto width */}
                <div className="flex justify-between items-center w-full md:w-auto">
                    <h3 className="font-bold text-slate-300 flex items-center gap-2 uppercase tracking-wide text-sm shrink-0">
                        <AreaChart className={`w-4 h-4 ${isHighRisk ? 'text-rose-500 animate-pulse' : 'text-emerald-500'}`} />
                        <span className="truncate">资金曲线 (Equity)</span>
                    </h3>

                    {/* Mobile Only: Risk Label next to Title */}
                    {riskRatio > 0 && (
                        <div className={`md:hidden text-[10px] font-mono font-bold px-2 py-1 rounded border whitespace-nowrap ${isHighRisk ? 'bg-rose-500/10 text-rose-500 border-rose-500/50 animate-pulse' : 'bg-slate-800 text-slate-400 border-slate-700'}`}>
                            DD: {riskRatio.toFixed(2)}%
                        </div>
                    )}
                </div>

                {/* Controls Section - Mobile: Full width, Desktop: Auto */}
                <div className="flex items-center gap-3 w-full md:w-auto justify-between md:justify-end">
                    {/* Time Range Selector */}
                    <div className="flex items-center gap-1 bg-slate-800/50 rounded-lg p-0.5 border border-slate-700/50 overflow-x-auto no-scrollbar flex-1 md:flex-none">
                        <Clock size={12} className="text-slate-500 ml-1.5 shrink-0" />
                        {TIME_RANGE_OPTIONS.map((opt) => (
                            <button
                                key={opt.key}
                                onClick={() => handleTimeRangeChange(opt.key)}
                                className={`px-2 py-0.5 text-[10px] font-bold rounded transition-all whitespace-nowrap ${timeRange === opt.key
                                    ? 'bg-cyan-500/20 text-cyan-400 shadow-inner'
                                    : 'text-slate-500 hover:text-slate-300 hover:bg-slate-700/50'
                                    }`}
                            >
                                {opt.label}
                            </button>
                        ))}
                    </div>

                    {/* Desktop Only: Risk Label in controls area */}
                    {riskRatio > 0 && (
                        <div className={`hidden md:block text-xs font-mono font-bold px-2 py-1 rounded border whitespace-nowrap ${isHighRisk ? 'bg-rose-500/10 text-rose-500 border-rose-500/50 animate-pulse' : 'bg-slate-800 text-slate-400 border-slate-700'}`}>
                            浮亏比: {riskRatio.toFixed(2)}%
                        </div>
                    )}
                </div>
            </div>
            <div ref={chartContainerRef} className="w-full flex-1 min-h-[200px]" />
        </div>
    );
};
