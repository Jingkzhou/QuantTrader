import { useState, useEffect } from 'react';
import axios from 'axios';
import {
  Activity, Terminal
} from 'lucide-react';
import { Navbar } from './components/Navbar';
import { ChartWidget } from './components/ChartWidget';
import { PerformancePanel } from './components/PerformancePanel';
import { EquityChartWidget } from './components/EquityChartWidget';
import { AccountStatistics } from './components/AccountStatistics';
import { RiskAnalysisPanel } from './components/RiskAnalysisPanel';
import { StrategyAnalysisPanel } from './components/StrategyAnalysisPanel';

import { LoginPage } from './components/LoginPage';
import { API_BASE } from './config';


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
  mt4_account: number;
  broker: string;
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
  const [pagination, setPagination] = useState({ page: 1, limit: 100, total: 0 });
  const [activePage, setActivePage] = useState('dashboard');
  const [drawdown, setDrawdown] = useState({ current: 0, max: 0 });
  const [activeTab, setActiveTab] = useState<'positions' | 'history'>('positions');
  const [selectedSymbol, setSelectedSymbol] = useState<string>('');

  // Account Management States
  const [accounts, setAccounts] = useState<AccountRecord[]>([]);
  const [selectedAccount, setSelectedAccount] = useState<{ mt4_account: number, broker: string } | null>(null);
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
    if (!auth.token) return;
    try {
      const stateUrl = selectedAccount
        ? `${API_BASE}/state?mt4_account=${selectedAccount.mt4_account}`
        : `${API_BASE}/state`;

      const response = await axios.get(stateUrl, {
        headers: { Authorization: `Bearer ${auth.token}` }
      });
      const newState = response.data;
      setData(newState);

      if (!selectedSymbol && newState.active_symbols && newState.active_symbols.length > 0) {
        // Prefer selecting a symbol with active positions if available
        const posSymbols = newState.account_status?.positions?.map((p: any) => p.symbol) || [];
        const preferredSymbol = newState.active_symbols.find((s: string) => posSymbols.includes(s)) || newState.active_symbols[0];
        setSelectedSymbol(preferredSymbol);
      }

      if (selectedAccount) {
        // Fetch History
        try {
          const histRes = await axios.get(`${API_BASE}/trade_history?mt4_account=${selectedAccount.mt4_account}&page=${pagination.page}&limit=${pagination.limit}&symbol=${selectedSymbol}`, {
            headers: { Authorization: `Bearer ${auth.token}` }
          });
          // Handle new response format { data, total, page, limit }
          // Or fallback if API not ready (transitional safety, though we know we updated backend)
          if (histRes.data && Array.isArray(histRes.data.data)) {
            setHistory(histRes.data.data);
            setPagination(prev => ({ ...prev, total: histRes.data.total }));
          } else if (Array.isArray(histRes.data)) {
            // Fallback for old API if needed
            setHistory(histRes.data);
          }
        } catch (err) {
          console.error("Trade History fetch error:", err);
          // Don't clear history on single error to prevent flickering? Or clear?
          // setHistory([]); 
        }

        // Fetch Account Performance
        try {
          const accHistRes = await axios.get(`${API_BASE}/account/history?mt4_account=${selectedAccount.mt4_account}&limit=1000`, {
            headers: { Authorization: `Bearer ${auth.token}` }
          });
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
          console.error("Account History fetch error:", err);
          setDrawdown({ current: 0, max: 0 });
        }
      } else {
        setHistory([]);
        setDrawdown({ current: 0, max: 0 });
      }
    } catch (err) {
      console.error("Fetch error:", err);
    }
  };

  useEffect(() => {
    if (!auth.token) return;
    fetchData(); // Initial fetch

    // Polling interval - only fetch account status frequently
    // const interval = setInterval(fetchData, 1000); 
    // Optimization: Split polling. Account status fast, history slow or manual?
    // For now, keep simple but be aware history is now paginated.
    // Maybe we only poll account status (stateUrl) frequently, and history only on change?
    // But existing code fetches everything. Let's keep it but maybe trade history doesn't need 1s polling if we are on page 2?
    // Actually, if we are paging, polling overwrites the page content? 
    // Yes, fetchData uses current pagination.page.

    const interval = setInterval(fetchData, 2000);
    return () => clearInterval(interval);
  }, [selectedSymbol, auth.token, selectedAccount, pagination.page]); // Depend on page

  // Reset pagination when symbol or account changes
  useEffect(() => {
    setPagination(prev => ({ ...prev, page: 1 }));
  }, [selectedSymbol, selectedAccount?.mt4_account]);

  // Fetch Accounts List
  useEffect(() => {
    if (!auth.token) return;
    const fetchAccounts = async () => {
      try {
        const res = await axios.get(`${API_BASE}/accounts`, {
          headers: { Authorization: `Bearer ${auth.token}` }
        });
        setAccounts(res.data);
        if (res.data.length > 0 && !selectedAccount) {
          setSelectedAccount({ mt4_account: res.data[0].mt4_account, broker: res.data[0].broker });
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
      setSelectedAccount({ mt4_account: res.data.mt4_account, broker: res.data.broker });
      setIsBindModalOpen(false);
      setNewAccount({ mt4_account: '', broker: '', name: '' });
    } catch (err) {
      alert("绑定账户失败，请检查账号和券商是否正确上报。");
    }
  };

  if (!auth.token) {
    return <LoginPage onLogin={handleLogin} />;
  }

  if (!data && selectedAccount) return (
    <div className="min-h-screen bg-slate-950 flex items-center justify-center text-slate-400">
      <div className="flex flex-col items-center gap-4">
        <Activity className="animate-pulse text-cyan-500 w-12 h-12" />
        <p className="font-mono text-lg">正在加载账号数据 (Account: {selectedAccount.mt4_account})...</p>
      </div>
    </div>
  );



  const currentMarketData = selectedSymbol ? data?.market_data[selectedSymbol] : null;

  // Sort active symbols: (1) Has Positions -> (2) Alpha
  const sortedActiveSymbols = [...(data?.active_symbols || [])].sort((a, b) => {
    const hasPosA = (data?.account_status?.positions || []).some((p: any) => p.symbol === a);
    const hasPosB = (data?.account_status?.positions || []).some((p: any) => p.symbol === b);

    if (hasPosA && !hasPosB) return -1;
    if (!hasPosA && hasPosB) return 1;
    return a.localeCompare(b);
  });

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 font-sans">
      <Navbar
        currentUser={auth}
        onLogout={handleLogout}
        activePage={activePage}
        onNavigate={setActivePage}
        accounts={accounts}
        selectedAccount={selectedAccount}
        setSelectedAccount={setSelectedAccount}
        onBindAccount={() => setIsBindModalOpen(true)}
        activeSymbols={sortedActiveSymbols}
        selectedSymbol={selectedSymbol}
        setSelectedSymbol={setSelectedSymbol}
      />

      <main className="p-4 md:p-6 space-y-4 md:space-y-6">
        {activePage === 'dashboard' ? (
          <>
            <AccountStatistics
              positions={data?.account_status?.positions || []}
              accountStatus={data?.account_status || { balance: 0, equity: 0, floating_profit: 0, margin: 0, free_margin: 0, timestamp: 0, positions: [] }}
              history={history}
              selectedSymbol={selectedSymbol}
              currentDrawdown={drawdown.current}
              maxDrawdown={drawdown.max}
            />



            <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">

              {/* Left Column: Market & Chart */}
              <div className="lg:col-span-3 space-y-6">

                {/* Market Ticker (Moved to Right Column) */}

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
                      交易明细 <span className="ml-2 text-xs px-2 py-0.5 bg-slate-800 rounded text-slate-400">{pagination.total}</span>
                    </button>
                  </div>

                  {/* Tab Content */}
                  <div className="flex-1 overflow-auto">
                    {activeTab === 'positions' ? (
                      <table className="w-full text-left min-w-[600px]">
                        <thead className="sticky top-0 z-10 bg-slate-900 shadow-sm">
                          <tr className="text-slate-500 text-xs uppercase font-bold">
                            <th className="px-4 md:px-6 py-3">订单号</th>
                            <th className="px-4 md:px-6 py-3">品种</th>
                            <th className="px-4 md:px-6 py-3">方向</th>
                            <th className="px-4 md:px-6 py-3">手数</th>
                            <th className="px-4 md:px-6 py-3">MAE / MFE</th>
                            <th className="px-4 md:px-6 py-3 text-right">利润</th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-slate-800/50">
                          {(data?.account_status?.positions || [])
                            .filter((pos: any) => !selectedSymbol || pos.symbol === selectedSymbol)
                            .map((pos: any) => (
                              <tr key={pos.ticket} className="hover:bg-slate-800/30 transition-colors">
                                <td className="px-4 md:px-6 py-4 font-mono text-slate-400">{pos.ticket}</td>
                                <td className="px-4 md:px-6 py-4 font-bold">{pos.symbol}</td>
                                <td className="px-4 md:px-6 py-4">
                                  <span className={`px-2 py-0.5 rounded text-[10px] items-center gap-1 inline-flex font-bold ${pos.side === 'BUY' ? 'bg-rose-500/10 text-rose-500' : 'bg-emerald-500/10 text-emerald-500'}`}>
                                    {pos.side}
                                  </span>
                                </td>
                                <td className="px-4 md:px-6 py-4 font-mono">{pos.lots.toFixed(2)}</td>
                                <td className="px-4 md:px-6 py-4 font-mono text-xs">
                                  <span className="text-rose-400">{pos.mae?.toFixed(2) || '0.00'}</span>
                                  <span className="text-slate-600 mx-1">/</span>
                                  <span className="text-emerald-400">{pos.mfe?.toFixed(2) || '0.00'}</span>
                                </td>
                                <td className={`px-4 md:px-6 py-4 text-right font-mono font-bold ${pos.profit >= 0 ? 'text-emerald-500' : 'text-rose-500'}`}>
                                  {pos.profit >= 0 ? '+' : ''}{pos.profit.toFixed(2)}
                                </td>
                              </tr>
                            ))}
                          {(data?.account_status?.positions || []).filter((pos: any) => !selectedSymbol || pos.symbol === selectedSymbol).length === 0 && (
                            <tr>
                              <td colSpan={6} className="px-4 md:px-6 py-12 text-center text-slate-600 italic">该品种暂无活跃订单</td>
                            </tr>
                          )}
                        </tbody>
                      </table>
                    ) : (
                      <table className="w-full text-left min-w-[900px]">
                        <thead className="sticky top-0 z-10 bg-slate-900 shadow-sm">
                          <tr className="text-slate-500 text-xs uppercase font-bold">
                            <th className="px-4 md:px-6 py-3">订单号</th>
                            <th className="px-4 md:px-6 py-3">品种</th>
                            <th className="px-4 md:px-6 py-3">方向</th>
                            <th className="px-4 md:px-6 py-3">手数</th>
                            <th className="px-4 md:px-6 py-3">开仓价</th>
                            <th className="px-4 md:px-6 py-3">平仓价</th>
                            <th className="px-4 md:px-6 py-3">MAE / MFE</th>
                            <th className="px-4 md:px-6 py-3">开仓信号</th>
                            <th className="px-4 md:px-6 py-3 text-right">利润</th>
                            <th className="px-4 md:px-6 py-3 text-right">时间</th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-slate-800/50">
                          {history
                            .filter((t: TradeHistory) => !selectedSymbol || t.symbol === selectedSymbol)
                            .map((t: TradeHistory) => (
                              <tr key={t.ticket} className="hover:bg-slate-800/30 transition-colors pointer-events-none">
                                <td className="px-4 md:px-6 py-3 font-mono text-slate-400 text-xs">{t.ticket}</td>
                                <td className="px-4 md:px-6 py-3 font-bold text-sm">{t.symbol}</td>
                                <td className="px-4 md:px-6 py-3">
                                  <span className={`px-2 py-0.5 rounded text-[10px] items-center gap-1 inline-flex font-bold ${t.trade_type === 'BUY' ? 'bg-rose-500/10 text-rose-500' : 'bg-emerald-500/10 text-emerald-500'}`}>
                                    {t.trade_type}
                                  </span>
                                </td>
                                <td className="px-4 md:px-6 py-3 font-mono text-xs">{t.lots.toFixed(2)}</td>
                                <td className="px-4 md:px-6 py-3 font-mono text-slate-400 text-xs">{t.open_price.toFixed(5)}</td>
                                <td className="px-4 md:px-6 py-3 font-mono text-slate-400 text-xs">{t.close_price.toFixed(5)}</td>
                                <td className="px-4 md:px-6 py-3 font-mono text-[10px]">
                                  <span className="text-rose-400/70">{t.mae?.toFixed(2) || '0.00'}</span>
                                  <span className="text-slate-600 mx-1">/</span>
                                  <span className="text-emerald-400/70">{t.mfe?.toFixed(2) || '0.00'}</span>
                                </td>
                                <td className="px-4 md:px-6 py-3 font-mono text-[10px] text-slate-500 whitespace-nowrap">
                                  {t.signal_context ? (() => {
                                    try {
                                      const ctx = JSON.parse(t.signal_context);
                                      return `R:${ctx.rsi?.toFixed(1)} A:${ctx.atr?.toFixed(4)} S:${ctx.spread}`;
                                    } catch (e) { return '---'; }
                                  })() : '---'}
                                </td>
                                <td className={`px-4 md:px-6 py-3 text-right font-mono font-bold text-sm ${t.profit >= 0 ? 'text-emerald-500' : 'text-rose-500'}`}>
                                  {t.profit >= 0 ? '+' : ''}{t.profit.toFixed(2)}
                                </td>
                                <td className="px-4 md:px-6 py-3 text-right font-mono text-slate-500 text-left text-[10px]">
                                  {new Date(t.close_time * 1000).toLocaleString()}
                                </td>
                              </tr>
                            ))}
                          {history.filter((t: TradeHistory) => !selectedSymbol || t.symbol === selectedSymbol).length === 0 && (
                            <tr>
                              <td colSpan={10} className="px-4 md:px-6 py-12 text-center text-slate-600 italic">该品种暂无历史记录</td>
                            </tr>
                          )}
                        </tbody>
                      </table>
                    )}
                  </div>

                  {/* Pagination Controls */}
                  {activeTab === 'history' && (
                    <div className="border-t border-slate-800 p-4 flex items-center justify-between bg-slate-900/30 shrink-0">
                      <div className="text-xs text-slate-500 font-mono">
                        显示 {(pagination.page - 1) * pagination.limit + 1} - {Math.min(pagination.page * pagination.limit, pagination.total)} 条 / 共 {pagination.total} 条
                      </div>
                      <div className="flex gap-2">
                        <button
                          children="上一页"
                          disabled={pagination.page <= 1}
                          onClick={() => setPagination(prev => ({ ...prev, page: prev.page - 1 }))}
                          className="px-3 py-1.5 rounded bg-slate-800 hover:bg-slate-700 disabled:opacity-50 disabled:cursor-not-allowed text-xs font-bold text-slate-300 transition-colors"
                        />
                        <span className="px-3 py-1.5 text-xs font-mono text-slate-400 bg-slate-900 rounded border border-slate-800">
                          第 {pagination.page} 页
                        </span>
                        <button
                          children="下一页"
                          disabled={pagination.page * pagination.limit >= pagination.total}
                          onClick={() => setPagination(prev => ({ ...prev, page: prev.page + 1 }))}
                          className="px-3 py-1.5 rounded bg-slate-800 hover:bg-slate-700 disabled:opacity-50 disabled:cursor-not-allowed text-xs font-bold text-slate-300 transition-colors"
                        />
                      </div>
                    </div>
                  )}
                </div>
              </div>

              {/* Right Column: Account & Logs */}
              <div className="space-y-6">

                {/* Equity Curve Chart (New) */}
                <EquityChartWidget
                  currentAccountStatus={data?.account_status || { balance: 0, equity: 0, floating_profit: 0, margin: 0, free_margin: 0, timestamp: 0, positions: [] }}
                  authToken={auth.token}
                  mt4Account={selectedAccount?.mt4_account || null}
                  broker={selectedAccount?.broker || null}
                />

                {/* Account Advanced Statistics (Moved to Top) */}

                {/* Performance Metrics (Side) */}
                <PerformancePanel
                  trades={history}
                  selectedSymbol={selectedSymbol}
                  gridClass="grid-cols-2 lg:grid-cols-2 gap-3"
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
          </>
        ) : (
          /* Analysis View */
          <div className="space-y-6">
            <EquityChartWidget
              currentAccountStatus={data?.account_status || { balance: 0, equity: 0, floating_profit: 0, margin: 0, free_margin: 0, timestamp: 0, positions: [] }}
              authToken={auth.token}
              mt4Account={selectedAccount?.mt4_account || null}
              broker={selectedAccount?.broker || null}
            />

            <RiskAnalysisPanel
              authToken={auth.token}
              mt4Account={selectedAccount?.mt4_account || null}
              broker={selectedAccount?.broker || null}
            />

            <StrategyAnalysisPanel
              authToken={auth.token}
              mt4Account={selectedAccount?.mt4_account || null}
              broker={selectedAccount?.broker || null}
            />

            <AccountStatistics
              positions={data?.account_status?.positions || []}
              accountStatus={data?.account_status || { balance: 0, equity: 0, floating_profit: 0, margin: 0, free_margin: 0, timestamp: 0, positions: [] }}
              history={history}
              selectedSymbol={selectedSymbol}
              currentDrawdown={drawdown.current}
              maxDrawdown={drawdown.max}
            />
          </div>
        )}
      </main>

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

const BindModal = ({ onClose, onBind, form, setForm }: any) => {
  const commonBrokers = [
    "D Prime Vanuatu Limited", "Exness", "IC Markets", "XM", "Tickmill",
    "Vantage", "Doo Prime", "EightCap", "Pepperstone", "FBS", "OctaFX",
    "RoboForex", "HFM", "FXTM", "Admiral Markets", "GemForex",
    "ThinkMarkets", "Axi", "Swissquote", "OANDA", "IG Markets",
    "FXCM", "AETOS", "VT Markets"
  ];

  return (
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
              list="broker-list"
              value={form.broker}
              onChange={(e) => setForm({ ...form, broker: e.target.value })}
              className="w-full bg-slate-950 border border-slate-800 rounded-xl py-3 px-4 text-slate-200 focus:outline-none focus:border-cyan-500/50"
              placeholder="搜索或输入券商名称"
              required
            />
            <datalist id="broker-list">
              {commonBrokers.map(broker => (
                <option key={broker} value={broker} />
              ))}
            </datalist>
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
};




export default App;
