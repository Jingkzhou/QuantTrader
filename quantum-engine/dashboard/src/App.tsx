import React, { useState, useEffect } from 'react';
import axios from 'axios';
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer
} from 'recharts';
import {
  TrendingUp, TrendingDown, Wallet, Activity, Terminal, LayoutDashboard,
  ShieldAlert, CheckCircle2, History
} from 'lucide-react';

const API_BASE = 'http://127.0.0.1:3001/api/v1';

interface MarketData {
  symbol: string;
  bid: number;
  ask: number;
  close: number;
}

interface AccountStatus {
  balance: number;
  equity: number;
  floating_profit: number;
  margin: number;
  free_margin: number;
  positions: any[];
}

interface LogEntry {
  timestamp: number;
  level: string;
  message: string;
}

interface AppState {
  market_data: MarketData;
  account_status: AccountStatus;
  recent_logs: LogEntry[];
}

const App = () => {
  const [data, setData] = useState<AppState | null>(null);
  const [priceHistory, setPriceHistory] = useState<any[]>([]);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const response = await axios.get(`${API_BASE}/state`);
        setData(response.data);

        // Update price history chart
        if (response.data.market_data.symbol) {
          setPriceHistory(prev => {
            const newHistory = [...prev, {
              time: new Date().toLocaleTimeString(),
              price: response.data.market_data.bid
            }];
            return newHistory.slice(-20); // Keep last 20 ticks
          });
        }
      } catch (err) {
        console.error("Fetch error:", err);
      }
    };

    const interval = setInterval(fetchData, 1000);
    return () => clearInterval(interval);
  }, []);

  if (!data) return (
    <div className="min-h-screen bg-slate-950 flex items-center justify-center text-slate-400">
      <div className="flex flex-col items-center gap-4">
        <Activity className="animate-pulse text-cyan-500 w-12 h-12" />
        <p className="font-mono text-lg">Waiting for Quantum Engine Connectivity...</p>
      </div>
    </div>
  );

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 p-6 font-sans">
      {/* Header */}
      <div className="flex justify-between items-center mb-8 border-b border-slate-800 pb-4">
        <div className="flex items-center gap-3">
          <div className="bg-cyan-600/20 p-2 rounded-lg border border-cyan-500/30">
            <LayoutDashboard className="text-cyan-500 w-6 h-6" />
          </div>
          <h1 className="text-2xl font-bold tracking-tight">QuantTrader <span className="text-cyan-500">PRO</span></h1>
        </div>
        <div className="flex items-center gap-6">
          <div className="flex flex-col items-end">
            <span className="text-xs text-slate-500 uppercase font-bold tracking-widest">Engine Status</span>
            <span className="flex items-center gap-2 text-emerald-500 text-sm font-mono">
              <span className="w-2 h-2 bg-emerald-500 rounded-full animate-ping" />
              CONNECTED
            </span>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">

        {/* Left Column: Market & Chart */}
        <div className="lg:col-span-3 space-y-6">

          {/* Market Ticker */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <MarketCard
              label="Symbol"
              value={data.market_data.symbol || "---"}
              icon={<Activity className="text-slate-400" />}
            />
            <MarketCard
              label="Bid Price"
              value={data.market_data.bid?.toFixed(5) || "0.00000"}
              icon={<TrendingDown className="text-rose-500" />}
              subValue="Real-time Quote"
            />
            <MarketCard
              label="Ask Price"
              value={data.market_data.ask?.toFixed(5) || "0.00000"}
              icon={<TrendingUp className="text-emerald-500" />}
              subValue="Real-time Quote"
            />
          </div>

          {/* Price Evolution Chart */}
          <div className="bg-slate-900/50 border border-slate-800 rounded-2xl p-6 h-[400px]">
            <div className="flex justify-between items-center mb-6">
              <h3 className="font-bold text-slate-300 flex items-center gap-2 uppercase tracking-wide text-sm">
                <History className="w-4 h-4 text-cyan-500" /> Price Evolution
              </h3>
              <span className="text-xs font-mono text-slate-500 italic">20 tick window</span>
            </div>
            <ResponsiveContainer width="100%" height="85%">
              <LineChart data={priceHistory}>
                <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" vertical={false} />
                <XAxis dataKey="time" hide />
                <YAxis domain={['auto', 'auto']} stroke="#475569" fontSize={10} />
                <Tooltip
                  contentStyle={{ backgroundColor: '#0f172a', border: '1px solid #1e293b', borderRadius: '8px' }}
                  itemStyle={{ color: '#06b6d4' }}
                />
                <Line
                  type="monotone"
                  dataKey="price"
                  stroke="#06b6d4"
                  strokeWidth={2}
                  dot={false}
                  animationDuration={300}
                />
              </LineChart>
            </ResponsiveContainer>
          </div>

          {/* Positions Table */}
          <div className="bg-slate-900/50 border border-slate-800 rounded-2xl overflow-hidden">
            <div className="px-6 py-4 border-b border-slate-800 flex justify-between items-center">
              <h3 className="font-bold text-slate-300 uppercase tracking-wide text-sm">Active Positions</h3>
              <span className="text-xs px-2 py-1 bg-slate-800 rounded text-slate-400">{data.account_status.positions.length} Orders</span>
            </div>
            <div className="overflow-x-auto">
              <table className="w-full text-left">
                <thead>
                  <tr className="bg-slate-900/80 text-slate-500 text-xs uppercase font-bold">
                    <th className="px-6 py-3">Ticket</th>
                    <th className="px-6 py-3">Symbol</th>
                    <th className="px-6 py-3">Side</th>
                    <th className="px-6 py-3">Lots</th>
                    <th className="px-6 py-3 text-right">Profit</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-800/50">
                  {data.account_status.positions.map((pos) => (
                    <tr key={pos.ticket} className="hover:bg-slate-800/30 transition-colors">
                      <td className="px-6 py-4 font-mono text-slate-400">{pos.ticket}</td>
                      <td className="px-6 py-4 font-bold">{pos.symbol}</td>
                      <td className="px-6 py-4">
                        <span className={`px-2 py-0.5 rounded text-[10px] items-center gap-1 inline-flex font-bold ${pos.side === 'BUY' ? 'bg-emerald-500/10 text-emerald-500' : 'bg-rose-500/10 text-rose-500'}`}>
                          {pos.side}
                        </span>
                      </td>
                      <td className="px-6 py-4 font-mono">{pos.lots.toFixed(2)}</td>
                      <td className={`px-6 py-4 text-right font-mono font-bold ${pos.profit >= 0 ? 'text-emerald-500' : 'text-rose-500'}`}>
                        {pos.profit >= 0 ? '+' : ''}{pos.profit.toFixed(2)}
                      </td>
                    </tr>
                  ))}
                  {data.account_status.positions.length === 0 && (
                    <tr>
                      <td colSpan={5} className="px-6 py-12 text-center text-slate-600 italic">No active orders detected.</td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>

        {/* Right Column: Account & Logs */}
        <div className="space-y-6">

          {/* Account Summary */}
          <div className="bg-gradient-to-br from-slate-900 to-slate-950 border border-slate-800 rounded-2xl p-6 shadow-xl">
            <div className="flex items-center gap-2 mb-6 text-slate-400 text-xs font-bold uppercase tracking-wider">
              <Wallet className="w-4 h-4 text-cyan-500" /> Account Summary
            </div>
            <div className="space-y-4">
              <BalanceRow label="Balance" value={data.account_status.balance} />
              <BalanceRow label="Equity" value={data.account_status.equity} highlight />
              <div className="pt-4 border-t border-slate-800 flex justify-between items-center">
                <span className="text-slate-500 text-sm">Floating P/L</span>
                <span className={`font-bold text-lg font-mono ${data.account_status.floating_profit >= 0 ? 'text-emerald-500' : 'text-rose-500'}`}>
                  ${data.account_status.floating_profit.toFixed(2)}
                </span>
              </div>
              <div className="grid grid-cols-2 gap-4 mt-6">
                <div className="bg-slate-900 p-3 rounded-xl border border-slate-800">
                  <span className="text-[10px] text-slate-500 uppercase block mb-1">Margin</span>
                  <span className="font-mono text-sm">${data.account_status.margin.toFixed(0)}</span>
                </div>
                <div className="bg-slate-900 p-3 rounded-xl border border-slate-800">
                  <span className="text-[10px] text-slate-500 uppercase block mb-1">Free Margin</span>
                  <span className="font-mono text-sm">${data.account_status.free_margin.toFixed(0)}</span>
                </div>
              </div>
            </div>
          </div>

          {/* Real-time Logs */}
          <div className="bg-slate-900/50 border border-slate-800 rounded-2xl flex flex-col h-[500px]">
            <div className="px-6 py-4 border-b border-slate-800 flex items-center gap-2 text-slate-400 text-xs font-bold uppercase tracking-wider">
              <Terminal className="w-4 h-4 text-cyan-500" /> Execution Logs
            </div>
            <div className="flex-1 overflow-y-auto p-4 font-mono text-[11px] space-y-2">
              {data.recent_logs.map((log, i) => (
                <div key={i} className="flex gap-2 group">
                  <span className="text-slate-600 shrink-0">[{new Date(log.timestamp * 1000).toLocaleTimeString([], { hour12: false })}]</span>
                  <span className={`uppercase font-bold shrink-0 ${log.level === 'ERROR' ? 'text-rose-500' : log.level === 'SUCCESS' ? 'text-emerald-500' : 'text-slate-500'}`}>
                    {log.level}
                  </span>
                  <span className="text-slate-400 group-hover:text-slate-200 transition-colors">{log.message}</span>
                </div>
              ))}
              {data.recent_logs.length === 0 && (
                <div className="text-slate-700 italic">Waiting for incoming logs...</div>
              )}
            </div>
          </div>

        </div>
      </div>
    </div>
  );
};

const MarketCard = ({ label, value, icon, subValue }: any) => (
  <div className="bg-slate-900/50 border border-slate-800 rounded-2xl p-6 transition-all hover:border-slate-700">
    <div className="flex justify-between items-start mb-2">
      <span className="text-slate-500 text-xs font-bold uppercase tracking-widest">{label}</span>
      {icon}
    </div>
    <div className="text-2xl font-mono font-bold">{value}</div>
    {subValue && <div className="text-[10px] text-slate-600 mt-1 uppercase tracking-tight">{subValue}</div>}
  </div>
);

const BalanceRow = ({ label, value, highlight }: any) => (
  <div className="flex justify-between items-center">
    <span className="text-slate-400 text-sm">{label}</span>
    <span className={`font-mono ${highlight ? 'text-slate-100 font-bold text-lg' : 'text-slate-400'}`}>
      ${value.toLocaleString(undefined, { minimumFractionDigits: 2 })}
    </span>
  </div>
);

export default App;
