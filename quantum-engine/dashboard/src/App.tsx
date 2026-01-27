import { useState, useEffect } from 'react';
import axios from 'axios';
import {
  TrendingUp, TrendingDown, Activity, Terminal, LayoutDashboard, User, Plus, ChevronDown, Check
} from 'lucide-react';
import { ChartWidget } from './components/ChartWidget';
import { PerformancePanel } from './components/PerformancePanel';
import { EquityChartWidget } from './components/EquityChartWidget';
import { AccountStatistics } from './components/AccountStatistics';

import { LoginPage } from './components/LoginPage';

const API_BASE = 'http://127.0.0.1:3001/api/v1';

// Add Interfaces for Auth
interface AuthState {
  token: string | null;
  username: string | null;
  role: string | null;
}

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
  timestamp: number;
  positions: any[];
}

interface LogEntry {
  timestamp: number;
  level: string;
  message: string;
}

interface TradeHistory {
  ticket: number;
  symbol: string;
  open_time: number;
  close_time: number;
  open_price: number;
  close_price: number;
  lots: number;
  profit: number;
  trade_type: string;
  mae?: number;
  mfe?: number;
  signal_context?: string;
}

interface AccountRecord {
  id: number;
  mt4_account_number: number;
  broker_name: string;
  account_name: string | null;
}

interface AppState {
  market_data: Record<string, MarketData>;
  account_status: AccountStatus;
  recent_logs: LogEntry[];
  active_symbols: string[];
}

const App = () => {
  const [auth, setAuth] = useState<AuthState>({
    token: localStorage.getItem('token'),
    username: localStorage.getItem('username'),
    role: localStorage.getItem('role')
  });
  const [data, setData] = useState<AppState | null>(null);
  const [history, setHistory] = useState<TradeHistory[]>([]);
  const [drawdown, setDrawdown] = useState({ current: 0, max: 0 });
  const [activeTab, setActiveTab] = useState<'positions' | 'history'>('positions');
  const [selectedSymbol, setSelectedSymbol] = useState<string>('');

  // Account Management States
  const [accounts, setAccounts] = useState<AccountRecord[]>([]);
  const [selectedAccountId, setSelectedAccountId] = useState<number | null>(null);
  const [isBindModalOpen, setIsBindModalOpen] = useState(false);
  const [newAccount, setNewAccount] = useState({ mt4_account: '', broker: '', name: '' });

  const handleLogin = (token: string, username: string, role: string) => {
    localStorage.setItem('token', token);
    localStorage.setItem('username', username);
    localStorage.setItem('role', role);
    setAuth({ token, username, role });
  };

  const handleLogout = () => {
    localStorage.clear();
    setAuth({ token: null, username: null, role: null });
  };

  const fetchData = async () => {
    if (!selectedAccountId || !auth.token) return;
    try {
      const response = await axios.get(`${API_BASE}/state?account_id=${selectedAccountId}`, {
        headers: { Authorization: `Bearer ${auth.token}` }
      });
      const newState = response.data;
      setData(newState);

      if (!selectedSymbol && newState.active_symbols && newState.active_symbols.length > 0) {
        setSelectedSymbol(newState.active_symbols[0]);
      }

      // Fetch History & Account Performance
      const [histRes, accHistRes] = await Promise.all([
        axios.get(`${API_BASE}/trade_history?account_id=${selectedAccountId}`, {
          headers: { Authorization: `Bearer ${auth.token}` }
        }),
        axios.get(`${API_BASE}/account/history?account_id=${selectedAccountId}&limit=1000`, {
          headers: { Authorization: `Bearer ${auth.token}` }
        })
      ]);
      setHistory(histRes.data);

      const accHist = accHistRes.data;
      if (accHist.length > 0) {
        let peak = 0; let maxDD = 0; let currentDD = 0;
        const sorted = [...accHist].sort((a: any, b: any) => a.timestamp - b.timestamp);
        sorted.forEach(h => {
          const equity = Number(h.equity);
          if (equity > peak) peak = equity;
          if (peak > 0) {
            const dd = (peak - equity) / peak * 100;
            if (dd > maxDD) maxDD = dd;
            currentDD = dd;
          }
        });
        setDrawdown({ current: currentDD, max: maxDD });
      }
    } catch (err) {
      console.error("Fetch error:", err);
    }
  };

  useEffect(() => {
    if (!auth.token) return;
    fetchData();
    const interval = setInterval(fetchData, 1000);
    return () => clearInterval(interval);
  }, [selectedSymbol, auth.token, selectedAccountId]);

  // Fetch Accounts List
  useEffect(() => {
    if (!auth.token) return;
    const fetchAccounts = async () => {
      try {
        const res = await axios.get(`${API_BASE}/accounts`, {
          headers: { Authorization: `Bearer ${auth.token}` }
        });
        setAccounts(res.data);
        if (res.data.length > 0 && !selectedAccountId) {
          setSelectedAccountId(res.data[0].id);
        }
      } catch (e) { console.error(e); }
    };
    fetchAccounts();
    const interval = setInterval(fetchAccounts, 5000);
    return () => clearInterval(interval);
  }, [auth.token]);

  const handleBindAccount = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const res = await axios.post(`${API_BASE}/accounts/bind`, {
        mt4_account: parseInt(newAccount.mt4_account),
        broker: newAccount.broker,
        account_name: newAccount.name
      }, {
        headers: { Authorization: `Bearer ${auth.token}` }
      });
      setAccounts([...accounts, res.data]);
      setSelectedAccountId(res.data.id);
      setIsBindModalOpen(false);
      setNewAccount({ mt4_account: '', broker: '', name: '' });
    } catch (err) {
      alert("绑定账户失败，请检查账号和券商是否正确上报。");
    }
  };

  if (!auth.token) {
    return <LoginPage onLogin={handleLogin} />;
  }

  if (!data && selectedAccountId) return (
    <div className="min-h-screen bg-slate-950 flex items-center justify-center text-slate-400">
      <div className="flex flex-col items-center gap-4">
        <Activity className="animate-pulse text-cyan-500 w-12 h-12" />
        <p className="font-mono text-lg">正在加载账号数据 (ID: {selectedAccountId})...</p>
      </div>
    </div>
  );

  if (!selectedAccountId && accounts.length === 0) return (
    <div className="min-h-screen bg-slate-950 flex flex-col items-center justify-center text-slate-400 p-8 text-center">
      <div className="max-w-md space-y-6">
        <div className="bg-slate-900 border border-slate-800 p-8 rounded-3xl">
          <Activity className="text-cyan-600 w-16 h-16 mx-auto mb-6" />
          <h2 className="text-2xl font-bold text-white mb-2">欢迎来到 QuantTrader</h2>
          <p className="text-slate-500 text-sm mb-8">您尚未绑定任何交易账号。请确保您的 MT4 EA 已启动并成功连接至服务器，然后绑定您的账号。</p>
          <button
            onClick={() => setIsBindModalOpen(true)}
            className="w-full bg-cyan-600 hover:bg-cyan-500 text-white font-bold py-3 px-6 rounded-xl transition-all shadow-lg shadow-cyan-900/20 active:scale-95"
          >
            立即绑定首个账号
          </button>
          <button onClick={handleLogout} className="mt-4 text-xs text-slate-600 hover:text-slate-400 font-bold uppercase tracking-widest">登出当前系统</button>
        </div>
      </div>
      {/* Re-use Binding Modal */}
      {isBindModalOpen && <BindModal
        onClose={() => setIsBindModalOpen(false)}
        onBind={handleBindAccount}
        form={newAccount}
        setForm={setNewAccount}
      />}
    </div>
  );

  const currentMarketData = selectedSymbol ? data?.market_data[selectedSymbol] : null;

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

        {/* Account Switcher */}
        <div className="flex-1 max-w-xs mx-8 relative group">
          <div className="bg-slate-900 border border-slate-800 rounded-xl px-4 py-2 flex items-center justify-between cursor-pointer hover:border-cyan-500/50 transition-all">
            <div className="flex flex-col">
              <span className="text-[10px] text-slate-500 font-bold uppercase tracking-widest">当前账户</span>
              <span className="text-sm font-bold text-cyan-500">
                {accounts.find(a => a.id === selectedAccountId)?.account_name || accounts.find(a => a.id === selectedAccountId)?.mt4_account_number || "未选择"}
              </span>
            </div>
            <ChevronDown size={16} className="text-slate-600 group-hover:text-cyan-500 transition-colors" />
          </div>

          <div className="absolute top-full left-0 right-0 mt-2 bg-slate-900 border border-slate-800 rounded-xl shadow-2xl opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all z-50 overflow-hidden">
            {accounts.map(acc => (
              <div
                key={acc.id}
                onClick={() => setSelectedAccountId(acc.id)}
                className={`flex items-center justify-between px-4 py-3 cursor-pointer hover:bg-slate-800 transition-colors ${selectedAccountId === acc.id ? 'bg-cyan-600/10' : ''}`}
              >
                <div className="flex flex-col">
                  <span className="text-sm font-bold text-slate-200">{acc.account_name || `MT4: ${acc.mt4_account_number}`}</span>
                  <span className="text-[10px] text-slate-500 lowercase">{acc.broker_name}</span>
                </div>
                {selectedAccountId === acc.id && <Check size={14} className="text-cyan-500" />}
              </div>
            ))}
            <div
              onClick={() => setIsBindModalOpen(true)}
              className="px-4 py-3 border-t border-slate-800 flex items-center gap-2 text-cyan-500 hover:bg-cyan-500/10 cursor-pointer transition-colors"
            >
              <Plus size={14} />
              <span className="text-xs font-bold uppercase tracking-widest">绑定新账号</span>
            </div>
          </div>
        </div>

        {/* User Info & Logout */}
        <div className="flex items-center gap-4">
          <div className="bg-slate-900 border border-slate-800 px-4 py-2 rounded-xl flex items-center gap-3">
            <div className="w-8 h-8 rounded-full bg-cyan-600/10 border border-cyan-500/30 flex items-center justify-center">
              <User className="text-cyan-500 w-4 h-4" />
            </div>
            <div className="flex flex-col">
              <span className="text-xs text-slate-500 font-bold uppercase tracking-widest">{auth.role}</span>
              <span className="text-sm font-bold text-slate-200">{auth.username}</span>
            </div>
            <button
              onClick={handleLogout}
              className="ml-4 text-xs text-rose-500 hover:text-rose-400 font-bold uppercase"
            >
              登出
            </button>
          </div>
        </div>

        {/* Symbol Selector */}

        {/* Symbol Selector */}
        <div className="flex items-center gap-2 bg-slate-900 border border-slate-800 p-1 rounded-xl">
          {(data.active_symbols || []).map((sym: string) => (
            <button
              key={sym}
              onClick={() => setSelectedSymbol(sym)}
              className={`px-4 py-2 rounded-lg text-sm font-bold transition-all ${selectedSymbol === sym ? 'bg-cyan-600 text-white shadow-lg shadow-cyan-900/20' : 'text-slate-500 hover:text-slate-300'}`}
            >
              {sym}
            </button>
          ))}
          {(!data.active_symbols || data.active_symbols.length === 0) && (
            <span className="px-4 py-2 text-sm text-slate-600 italic">正在等待 EA 信号...</span>
          )}
        </div>

        <div className="flex items-center gap-6">
          <div className="flex flex-col items-end">
            <span className="text-xs text-slate-500 uppercase font-bold tracking-widest">引擎状态</span>
            <span className="flex items-center gap-2 text-emerald-500 text-sm font-mono">
              <span className="w-2 h-2 bg-emerald-500 rounded-full animate-ping" />
              已连接
            </span>
          </div>
        </div>
      </div>

      {/* Performance Panel */}
      <PerformancePanel trades={history} selectedSymbol={selectedSymbol} />

      <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">

        {/* Left Column: Market & Chart */}
        <div className="lg:col-span-3 space-y-6">

          {/* Market Ticker */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <MarketCard
              label="交易品种"
              value={selectedSymbol || "---"}
              icon={<Activity className="text-slate-400" />}
            />
            <MarketCard
              label="买入价 (Bid)"
              value={currentMarketData?.bid?.toFixed(5) || "0.00000"}
              icon={<TrendingDown className="text-rose-500" />}
              subValue="实时报价"
            />
            <MarketCard
              label="卖出价 (Ask)"
              value={currentMarketData?.ask?.toFixed(5) || "0.00000"}
              icon={<TrendingUp className="text-emerald-500" />}
              subValue="实时报价"
            />
          </div>

          {/* Main Center Chart */}
          <div className="flex-1 min-h-0">
            <ChartWidget
              symbol={selectedSymbol}
              currentData={currentMarketData}
              authToken={auth.token}
              history={history}
              positions={data?.account_status?.positions || []}
            />
          </div>

          {/* Tabbed Interface: Positions & History */}
          <div className="bg-slate-900/50 border border-slate-800 rounded-2xl overflow-hidden mt-6 flex flex-col h-[500px]">
            {/* Tab Header */}
            <div className="flex border-b border-slate-800">
              <button
                onClick={() => setActiveTab('positions')}
                className={`px-6 py-4 text-sm font-bold uppercase tracking-wide transition-colors ${activeTab === 'positions'
                  ? 'text-cyan-500 border-b-2 border-cyan-500 bg-slate-800/50'
                  : 'text-slate-500 hover:text-slate-300 hover:bg-slate-800/30'
                  }`}
              >
                活跃持仓 <span className="ml-2 text-xs px-2 py-0.5 bg-slate-800 rounded text-slate-400">{(data?.account_status?.positions || []).filter((p: any) => !selectedSymbol || p.symbol === selectedSymbol).length}</span>
              </button>
              <button
                onClick={() => setActiveTab('history')}
                className={`px-6 py-4 text-sm font-bold uppercase tracking-wide transition-colors ${activeTab === 'history'
                  ? 'text-cyan-500 border-b-2 border-cyan-500 bg-slate-800/50'
                  : 'text-slate-500 hover:text-slate-300 hover:bg-slate-800/30'
                  }`}
              >
                交易明细 <span className="ml-2 text-xs px-2 py-0.5 bg-slate-800 rounded text-slate-400">{history.filter((t: TradeHistory) => !selectedSymbol || t.symbol === selectedSymbol).length}</span>
              </button>
            </div>

            {/* Tab Content */}
            <div className="flex-1 overflow-auto">
              {activeTab === 'positions' ? (
                <table className="w-full text-left">
                  <thead className="sticky top-0 z-10 bg-slate-900 shadow-sm">
                    <tr className="text-slate-500 text-xs uppercase font-bold">
                      <th className="px-6 py-3">订单号</th>
                      <th className="px-6 py-3">品种</th>
                      <th className="px-6 py-3">方向</th>
                      <th className="px-6 py-3">手数</th>
                      <th className="px-6 py-3">MAE / MFE</th>
                      <th className="px-6 py-3 text-right">利润</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-800/50">
                    {(data?.account_status?.positions || [])
                      .filter((pos: any) => !selectedSymbol || pos.symbol === selectedSymbol)
                      .map((pos: any) => (
                        <tr key={pos.ticket} className="hover:bg-slate-800/30 transition-colors">
                          <td className="px-6 py-4 font-mono text-slate-400">{pos.ticket}</td>
                          <td className="px-6 py-4 font-bold">{pos.symbol}</td>
                          <td className="px-6 py-4">
                            <span className={`px-2 py-0.5 rounded text-[10px] items-center gap-1 inline-flex font-bold ${pos.side === 'BUY' ? 'bg-rose-500/10 text-rose-500' : 'bg-emerald-500/10 text-emerald-500'}`}>
                              {pos.side}
                            </span>
                          </td>
                          <td className="px-6 py-4 font-mono">{pos.lots.toFixed(2)}</td>
                          <td className="px-6 py-4 font-mono text-xs">
                            <span className="text-rose-400">{pos.mae?.toFixed(2) || '0.00'}</span>
                            <span className="text-slate-600 mx-1">/</span>
                            <span className="text-emerald-400">{pos.mfe?.toFixed(2) || '0.00'}</span>
                          </td>
                          <td className={`px-6 py-4 text-right font-mono font-bold ${pos.profit >= 0 ? 'text-emerald-500' : 'text-rose-500'}`}>
                            {pos.profit >= 0 ? '+' : ''}{pos.profit.toFixed(2)}
                          </td>
                        </tr>
                      ))}
                    {(data?.account_status?.positions || []).filter((pos: any) => !selectedSymbol || pos.symbol === selectedSymbol).length === 0 && (
                      <tr>
                        <td colSpan={6} className="px-6 py-12 text-center text-slate-600 italic">该品种暂无活跃订单</td>
                      </tr>
                    )}
                  </tbody>
                </table>
              ) : (
                <table className="w-full text-left">
                  <thead className="sticky top-0 z-10 bg-slate-900 shadow-sm">
                    <tr className="text-slate-500 text-xs uppercase font-bold">
                      <th className="px-6 py-3">订单号</th>
                      <th className="px-6 py-3">品种</th>
                      <th className="px-6 py-3">方向</th>
                      <th className="px-6 py-3">手数</th>
                      <th className="px-6 py-3">开仓价</th>
                      <th className="px-6 py-3">平仓价</th>
                      <th className="px-6 py-3">MAE / MFE</th>
                      <th className="px-6 py-3">开仓信号</th>
                      <th className="px-6 py-3 text-right">利润</th>
                      <th className="px-6 py-3 text-right">时间</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-800/50">
                    {history
                      .filter((t: TradeHistory) => !selectedSymbol || t.symbol === selectedSymbol)
                      .map((t: TradeHistory) => (
                        <tr key={t.ticket} className="hover:bg-slate-800/30 transition-colors pointer-events-none">
                          <td className="px-6 py-3 font-mono text-slate-400 text-xs">{t.ticket}</td>
                          <td className="px-6 py-3 font-bold text-sm">{t.symbol}</td>
                          <td className="px-6 py-3">
                            <span className={`px-2 py-0.5 rounded text-[10px] items-center gap-1 inline-flex font-bold ${t.trade_type === 'BUY' ? 'bg-rose-500/10 text-rose-500' : 'bg-emerald-500/10 text-emerald-500'}`}>
                              {t.trade_type}
                            </span>
                          </td>
                          <td className="px-6 py-3 font-mono text-xs">{t.lots.toFixed(2)}</td>
                          <td className="px-6 py-3 font-mono text-slate-400 text-xs">{t.open_price.toFixed(5)}</td>
                          <td className="px-6 py-3 font-mono text-slate-400 text-xs">{t.close_price.toFixed(5)}</td>
                          <td className="px-6 py-3 font-mono text-[10px]">
                            <span className="text-rose-400/70">{t.mae?.toFixed(2) || '0.00'}</span>
                            <span className="text-slate-600 mx-1">/</span>
                            <span className="text-emerald-400/70">{t.mfe?.toFixed(2) || '0.00'}</span>
                          </td>
                          <td className="px-6 py-3 font-mono text-[10px] text-slate-500 whitespace-nowrap">
                            {t.signal_context ? (() => {
                              try {
                                const ctx = JSON.parse(t.signal_context);
                                return `R:${ctx.rsi?.toFixed(1)} A:${ctx.atr?.toFixed(4)} S:${ctx.spread}`;
                              } catch (e) { return '---'; }
                            })() : '---'}
                          </td>
                          <td className={`px-6 py-3 text-right font-mono font-bold text-sm ${t.profit >= 0 ? 'text-emerald-500' : 'text-rose-500'}`}>
                            {t.profit >= 0 ? '+' : ''}{t.profit.toFixed(2)}
                          </td>
                          <td className="px-6 py-3 text-right font-mono text-slate-500 text-left text-[10px]">
                            {new Date(t.close_time * 1000).toLocaleString()}
                          </td>
                        </tr>
                      ))}
                    {history.filter((t: TradeHistory) => !selectedSymbol || t.symbol === selectedSymbol).length === 0 && (
                      <tr>
                        <td colSpan={10} className="px-6 py-12 text-center text-slate-600 italic">该品种暂无历史记录</td>
                      </tr>
                    )}
                  </tbody>
                </table>
              )}
            </div>
          </div>
        </div>

        {/* Right Column: Account & Logs */}
        <div className="space-y-6">

          {/* Equity Curve Chart (New) */}
          <EquityChartWidget currentAccountStatus={data?.account_status || { balance: 0, equity: 0, floating_profit: 0, margin: 0, free_margin: 0, timestamp: 0, positions: [] }} />

          {/* Account Advanced Statistics (New) */}
          <AccountStatistics
            positions={data?.account_status?.positions || []}
            accountStatus={data?.account_status || { balance: 0, equity: 0, floating_profit: 0, margin: 0, free_margin: 0, timestamp: 0, positions: [] }}
            history={history}
            selectedSymbol={selectedSymbol}
            currentDrawdown={drawdown.current}
            maxDrawdown={drawdown.max}
          />

          {/* Real-time Logs */}
          <div className="bg-slate-900/50 border border-slate-800 rounded-2xl flex flex-col h-[500px]">
            <div className="px-6 py-4 border-b border-slate-800 flex items-center gap-2 text-slate-400 text-xs font-bold uppercase tracking-wider">
              <Terminal className="w-4 h-4 text-cyan-500" /> 执行日志
            </div>
            <div className="flex-1 overflow-y-auto p-4 font-mono text-[11px] space-y-2">
              {data?.recent_logs?.map((log: LogEntry, i: number) => (
                <div key={i} className="flex gap-2 group">
                  <span className="text-slate-600 shrink-0">[{new Date(log.timestamp * 1000).toLocaleTimeString([], { hour12: false })}]</span>
                  <span className={`uppercase font-bold shrink-0 ${log.level === 'ERROR' ? 'text-rose-500' : log.level === 'SUCCESS' ? 'text-emerald-500' : 'text-slate-500'}`}>
                    {log.level}
                  </span>
                  <span className="text-slate-400 group-hover:text-slate-200 transition-colors">{log.message}</span>
                </div>
              ))}
              {(!data?.recent_logs || data.recent_logs.length === 0) && (
                <div className="text-slate-700 italic">等待日志...</div>
              )}
            </div>
          </div>

        </div>
      </div>

      {/* Binding Modal */}
      {isBindModalOpen && <BindModal
        onClose={() => setIsBindModalOpen(false)}
        onBind={handleBindAccount}
        form={newAccount}
        setForm={setNewAccount}
      />}
    </div>
  );
};

const BindModal = ({ onClose, onBind, form, setForm }: any) => (
  <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm animate-in fade-in duration-300">
    <div className="bg-slate-900 border border-slate-800 w-full max-w-md rounded-3xl p-8 shadow-2xl animate-in zoom-in-95 duration-200">
      <div className="flex justify-between items-center mb-6">
        <h3 className="text-xl font-bold text-white">绑定 MT4 交易账号</h3>
        <button onClick={onClose} className="text-slate-500 hover:text-white transition-colors">&times;</button>
      </div>
      <form onSubmit={onBind} className="space-y-6">
        <div>
          <label className="block text-xs font-bold uppercase tracking-widest text-slate-500 mb-2">MT4 账号</label>
          <input
            type="number"
            value={form.mt4_account}
            onChange={(e) => setForm({ ...form, mt4_account: e.target.value })}
            className="w-full bg-slate-950 border border-slate-800 rounded-xl py-3 px-4 text-slate-200 focus:outline-none focus:border-cyan-500/50"
            placeholder="例: 1234567"
            required
          />
        </div>
        <div>
          <label className="block text-xs font-bold uppercase tracking-widest text-slate-500 mb-2">券商名称 (Broker)</label>
          <input
            type="text"
            value={form.broker}
            onChange={(e) => setForm({ ...form, broker: e.target.value })}
            className="w-full bg-slate-950 border border-slate-800 rounded-xl py-3 px-4 text-slate-200 focus:outline-none focus:border-cyan-500/50"
            placeholder="例: IC Markets"
            required
          />
        </div>
        <div>
          <label className="block text-xs font-bold uppercase tracking-widest text-slate-500 mb-2">备注名称 (可选)</label>
          <input
            type="text"
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
            className="w-full bg-slate-950 border border-slate-800 rounded-xl py-3 px-4 text-slate-200 focus:outline-none focus:border-cyan-500/50"
            placeholder="例: 麒麟 1 号实盘"
          />
        </div>
        <button
          type="submit"
          className="w-full bg-cyan-600 hover:bg-cyan-500 text-white font-bold py-4 rounded-xl shadow-lg transition-all active:scale-[0.98]"
        >
          确认绑定
        </button>
      </form>
    </div>
  </div>
);

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


export default App;
