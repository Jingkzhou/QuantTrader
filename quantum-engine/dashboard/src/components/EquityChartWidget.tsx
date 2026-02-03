import React, { useEffect, useRef, useState } from 'react';
import { createChart, ColorType, AreaSeries } from 'lightweight-charts';
import type { IChartApi, ISeriesApi, Time } from 'lightweight-charts';
import axios from 'axios';
import { AreaChart } from 'lucide-react';
import { API_BASE } from '../config';

interface EquityChartWidgetProps {
    currentAccountStatus?: any;
    authToken: string | null;
    mt4Account: number | null;
    broker: string | null;
}


export const EquityChartWidget: React.FC<EquityChartWidgetProps> = ({ currentAccountStatus, authToken, mt4Account, broker }) => {
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
            handleScroll: true,
            handleScale: true,
            grid: {
                vertLines: { color: '#1e293b' },
                horzLines: { color: '#1e293b' },
            },
            crosshair: {
                mode: 0, // CrosshairMode.Hidden
            },
            width: chartContainerRef.current.clientWidth,
            height: 200,
            timeScale: {
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
                const res = await axios.get(`${API_BASE}/account/history?mt4_account=${mt4Account}&broker=${encodeURIComponent(broker)}&limit=2000`, {
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

                console.log("Equity Chart - Data Processed:", {
                    original: history.length,
                    balance: balanceData.length,
                    equity: equityData.length,
                    firstTime: balanceData[0]?.time,
                    lastTime: balanceData[balanceData.length - 1]?.time
                });

                if (balanceData.length > 0) {
                    balanceSeries.setData(balanceData);
                }
                if (equityData.length > 0) {
                    equitySeries.setData(equityData);
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
        <div className={`bg-slate-900/50 border rounded-2xl p-6 flex flex-col h-[250px] md:h-[280px] transition-colors ${isHighRisk ? 'border-rose-500/50 shadow-[0_0_20px_rgba(244,63,94,0.1)]' : 'border-slate-800'}`}>
            <div className="flex justify-between items-center mb-4">
                <h3 className="font-bold text-slate-300 flex items-center gap-2 uppercase tracking-wide text-sm">
                    <AreaChart className={`w-4 h-4 ${isHighRisk ? 'text-rose-500 animate-pulse' : 'text-emerald-500'}`} />
                    资金曲线 (Equity vs Balance)
                </h3>
                <div className="flex items-center gap-4">
                    {riskRatio > 0 && (
                        <div className={`text-xs font-mono font-bold px-2 py-1 rounded border ${isHighRisk ? 'bg-rose-500/10 text-rose-500 border-rose-500/50 animate-pulse' : 'bg-slate-800 text-slate-400 border-slate-700'}`}>
                            浮亏比: {riskRatio.toFixed(2)}%
                        </div>
                    )}
                </div>
            </div>
            <div ref={chartContainerRef} className="w-full flex-1" />
        </div>
    );
};
