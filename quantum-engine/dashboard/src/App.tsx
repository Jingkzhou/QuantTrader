
import React, { useState, useEffect, useMemo } from 'react';
import axios from 'axios';
import { Activity } from 'lucide-react';
import { Navbar } from './components/Navbar';
import { ChartWidget } from './components/ChartWidget';
import { PerformancePanel } from './components/PerformancePanel';
import { EquityChartWidget } from './components/EquityChartWidget';
import { AccountStatistics } from './components/AccountStatistics';
import { RiskAnalysisPanel } from './components/RiskAnalysisPanel';
import { StrategyAnalysisPanel } from './components/StrategyAnalysisPanel';
import { SmartExitDashboard } from './components/SmartExitDashboard';
import { LoginPage } from './components/LoginPage';
import { BindModal } from './components/BindModal';
import { DashboardTables } from './components/DashboardTables';
import { PendingOrdersWidget } from './components/PendingOrdersWidget';
import { RealtimeLogs } from './components/RealtimeLogs';
import { API_BASE } from './config';
import type { AuthState, MarketData, AccountStatus, LogEntry, TradeHistory, AccountRecord } from './types';
import { calculateATR } from './utils/smartExitCalculations';

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
  const [selectedSymbol, setSelectedSymbol] = useState<string>('');
  const [atr, setAtr] = useState<number>(0);

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
    localStorage.removeItem('token');
    localStorage.removeItem('username');
    localStorage.removeItem('role');
    setAuth({ token: null, username: null, role: null });
  };

  // Global Axios Interceptor for Auto-Logout on 401/403
  useEffect(() => {
    const interceptor = axios.interceptors.response.use(
      (response) => response,
      (error) => {
        if (error.response && (error.response.status === 401 || error.response.status === 403)) {
          handleLogout();
        }
        return Promise.reject(error);
      }
    );

    return () => {
      axios.interceptors.response.eject(interceptor);
    };
  }, []);

  // Persistence: Save Preferences
  useEffect(() => {
    if (selectedSymbol) localStorage.setItem('lastSymbol', selectedSymbol);
  }, [selectedSymbol]);

  useEffect(() => {
    if (selectedAccount) localStorage.setItem('lastAccount', JSON.stringify(selectedAccount));
  }, [selectedAccount]);

  // Fetch ATR (D1)
  useEffect(() => {
    const fetchATR = async () => {
      if (!selectedSymbol || !auth.token) return;
      try {
        // Fetch 20 days of D1 data for ATR(14) calculation
        const response = await axios.get(`${API_BASE}/candles`, {
          params: { symbol: selectedSymbol, timeframe: 'D1' },
          headers: { Authorization: `Bearer ${auth.token}` }
        });
        const candles = response.data;
        if (candles && candles.length > 1) {
          const val = calculateATR(candles, 14);
          setAtr(val);
        } else {
          setAtr(0); // Reset if not enough data
        }
      } catch (e) {
        console.error("Failed to fetch ATR data", e);
        setAtr(0);
      }
    };
    fetchATR();
    const interval = setInterval(fetchATR, 60000 * 5); // Refresh every 5 min
    return () => clearInterval(interval);
  }, [selectedSymbol, auth.token]);

  const fetchData = async () => {
    if (!auth.token) return;
    try {
      const stateUrl = selectedAccount
        ? `${API_BASE}/state?mt4_account=${selectedAccount.mt4_account}`
        : `${API_BASE}/state`;

      // Parallelize Requests: State, History, AccountHistory
      const requests: Promise<any>[] = [
        axios.get(stateUrl, { headers: { Authorization: `Bearer ${auth.token}` } })
      ];

      // If account selected, add history fetches
      if (selectedAccount) {
        requests.push(
          axios.get(`${API_BASE}/trade_history?mt4_account=${selectedAccount.mt4_account}&page=${pagination.page}&limit=${pagination.limit}&symbol=${selectedSymbol}`, {
            headers: { Authorization: `Bearer ${auth.token}` }
          }).catch(e => ({ error: e }))
        );
        requests.push(
          axios.get(`${API_BASE}/account/history?mt4_account=${selectedAccount.mt4_account}&limit=1000`, {
            headers: { Authorization: `Bearer ${auth.token}` }
          }).catch(e => ({ error: e }))
        );
      }

      const results = await Promise.all(requests);
      const stateRes = results[0];
      const newState = stateRes.data;
      setData(newState);

      if (!selectedSymbol && newState.active_symbols && newState.active_symbols.length > 0) {
        // Try restoring last symbol
        const lastSymbol = localStorage.getItem('lastSymbol');
        if (lastSymbol && newState.active_symbols.includes(lastSymbol)) {
          setSelectedSymbol(lastSymbol);
        } else {
          // Default: Prefer symbol with active positions
          const posSymbols = newState.account_status?.positions?.map((p: any) => p.symbol) || [];
          const preferredSymbol = newState.active_symbols.find((s: string) => posSymbols.includes(s)) || newState.active_symbols[0];
          setSelectedSymbol(preferredSymbol);
        }
      }

      if (selectedAccount && results.length >= 3) {
        // Handle History Result
        const histRes = results[1];
        if (!histRes.error) {
          if (histRes.data && Array.isArray(histRes.data.data)) {
            setHistory(histRes.data.data);
            setPagination((prev) => ({ ...prev, total: histRes.data.total }));
          } else if (Array.isArray(histRes.data)) {
            setHistory(histRes.data);
          }
        }

        // Handle Account Drawdown Result
        const accHistRes = results[2];
        if (!accHistRes.error) {
          const accHist = accHistRes.data;
          if (Array.isArray(accHist) && accHist.length > 0) {
            let peak = 0; let maxDD = 0; let currentDD = 0;
            const sorted = [...accHist].sort((a: any, b: any) => a.timestamp - b.timestamp);
            sorted.forEach((h: any) => {
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
        }
      } else {
        if (!selectedAccount) {
          setHistory([]);
          setDrawdown({ current: 0, max: 0 });
        }
      }
    } catch (err) {
      console.error("Fetch error:", err);
    }
  };

  useEffect(() => {
    if (!auth.token) return;
    fetchData(); // Initial fetch
    const interval = setInterval(fetchData, 2000);
    return () => clearInterval(interval);
  }, [selectedSymbol, auth.token, selectedAccount, pagination.page]);

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
          // Restore last account
          const lastAccountStr = localStorage.getItem('lastAccount');
          let targetAccount = res.data[0];

          if (lastAccountStr) {
            try {
              const saved = JSON.parse(lastAccountStr);
              const found = res.data.find((a: any) => a.mt4_account == saved.mt4_account);
              if (found) targetAccount = found;
            } catch (e) { }
          }
          setSelectedAccount({ mt4_account: targetAccount.mt4_account, broker: targetAccount.broker });
        }
      } catch (e) { console.error(e); }
    };
    fetchAccounts();
    const interval = setInterval(fetchAccounts, 5000);
    return () => clearInterval(interval);
  }, [auth.token]);

  // Memoized Sort active symbols
  const sortedActiveSymbols = useMemo(() => {
    if (!data?.active_symbols) return [];
    return [...data.active_symbols].sort((a, b) => {
      const hasPosA = (data?.account_status?.positions || []).some((p: any) => p.symbol === a);
      const hasPosB = (data?.account_status?.positions || []).some((p: any) => p.symbol === b);

      if (hasPosA && !hasPosB) return -1;
      if (!hasPosA && hasPosB) return 1;
      return a.localeCompare(b);
    });
  }, [data?.active_symbols, data?.account_status?.positions]);

  // 🆕 计算交易统计 (用于马丁策略检测)
  const tradeStats = useMemo(() => {
    if (!history || history.length === 0) return undefined;

    // 过滤当前品种的交易
    const filteredTrades = selectedSymbol
      ? history.filter(t => t.symbol === selectedSymbol)
      : history;

    if (filteredTrades.length < 5) return undefined; // 样本太少不计算

    const wins = filteredTrades.filter(t => t.profit > 0);
    const losses = filteredTrades.filter(t => t.profit < 0);

    const winRate = (wins.length / filteredTrades.length) * 100;
    const grossProfit = wins.reduce((acc, t) => acc + t.profit, 0);
    const grossLoss = Math.abs(losses.reduce((acc, t) => acc + t.profit, 0));
    const profitFactor = grossLoss > 0 ? grossProfit / grossLoss : grossProfit > 0 ? 999 : 0;
    const avgWin = wins.length > 0 ? grossProfit / wins.length : 0;
    const avgLoss = losses.length > 0 ? grossLoss / losses.length : 0;

    return { winRate, profitFactor, avgWin, avgLoss };
  }, [history, selectedSymbol]);

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

  const handleUnbindAccount = async (mt4_account: number, broker: string) => {
    try {
      await axios.delete(`${API_BASE}/accounts`, {
        data: { mt4_account, broker },
        headers: { Authorization: `Bearer ${auth.token}` }
      });
      const updatedAccounts = accounts.filter(a => !(a.mt4_account === mt4_account && a.broker === broker));
      setAccounts(updatedAccounts);

      // If deleted account was selected, switch to another one
      if (selectedAccount?.mt4_account === mt4_account && selectedAccount?.broker === broker) {
        if (updatedAccounts.length > 0) {
          setSelectedAccount({ mt4_account: updatedAccounts[0].mt4_account, broker: updatedAccounts[0].broker });
        } else {
          setSelectedAccount(null);
        }
      }
    } catch (err) {
      console.error("Unbind failed:", err);
      alert("解除绑定失败，请稍后重试");
    }
  };

  const handleExportHistory = async () => {
    if (!auth.token || !selectedAccount) return;

    try {
      // 1. Fetch ALL data (limit=100000)
      const res = await axios.get(`${API_BASE}/trade_history`, {
        params: {
          mt4_account: selectedAccount.mt4_account,
          limit: 100000, // Fetch all for export
          page: 1,
          symbol: selectedSymbol
        },
        headers: { Authorization: `Bearer ${auth.token}` }
      });

      let trades: TradeHistory[] = [];
      if (res.data && Array.isArray(res.data.data)) {
        trades = res.data.data;
      } else if (Array.isArray(res.data)) {
        trades = res.data;
      }

      if (trades.length === 0) {
        alert("没有可导出的数据");
        return;
      }

      // 2. Convert to CSV
      const headers = ["订单号", "品种", "方向", "手数", "开仓价格", "平仓价格", "开仓时间", "平仓时间", "利润", "MAE", "MFE", "信号上下文"];
      const csvContent = [
        headers.join(","),
        ...trades.map(t => {
          const openTime = new Date(t.open_time * 1000).toLocaleString().replace(/,/g, ' ');
          let closeTimeStr = '';
          if (typeof t.close_time === 'number') {
            closeTimeStr = new Date(t.close_time * 1000).toLocaleString().replace(/,/g, ' ');
          } else {
            closeTimeStr = String(t.close_time).replace(/,/g, ' ');
          }

          const ctx = t.signal_context ? t.signal_context.replace(/"/g, '""') : '';

          return [
            t.ticket,
            t.symbol,
            t.trade_type,
            t.lots,
            t.open_price,
            t.close_price,
            openTime,
            closeTimeStr,
            t.profit,
            t.mae || 0,
            t.mfe || 0,
            `"${ctx}"`
          ].join(",");
        })
      ].join("\n");

      const blob = new Blob(["\ufeff" + csvContent], { type: 'text/csv;charset=utf-8;' });
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.setAttribute("href", url);
      link.setAttribute("download", `trade_history_${selectedAccount.mt4_account}_${new Date().toISOString().slice(0, 10)}.csv`);
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);

    } catch (err) {
      console.error("Export failed:", err);
      alert("导出失败，请稍后重试");
    }
  };

  // 3. Render Logic (Early Returns)
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

  const currentMarketData = selectedSymbol && data?.market_data ? data.market_data[selectedSymbol] : null;

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
        onUnbindAccount={handleUnbindAccount}
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

                {/* 24H Smart Exit Dashboard */}
                <SmartExitDashboard
                  accountStatus={data?.account_status || { balance: 0, equity: 0, floating_profit: 0, margin: 0, free_margin: 0, timestamp: 0, positions: [], contract_size: 100, tick_value: 1, stop_level: 0, margin_so_level: 50 }}
                  currentPrice={currentMarketData ? currentMarketData.close : null}
                  currentBid={currentMarketData?.bid}
                  currentAsk={currentMarketData?.ask}
                  symbolInfo={{
                    contractSize: data?.account_status?.contract_size || 100,
                    stopOutLevel: data?.account_status?.margin_so_level || 50,
                    tickValue: data?.account_status?.tick_value || 1
                  }}
                  atr={atr}
                  authToken={auth.token || undefined}
                  selectedSymbol={selectedSymbol}
                  maxDrawdown={drawdown.current}
                  tradeStats={tradeStats}
                />

                <PendingOrdersWidget
                  positions={data?.account_status?.positions || []}
                  currentPrice={currentMarketData ? currentMarketData.close : null}
                  selectedSymbol={selectedSymbol}
                />


                {/* Main Center Chart */}
                <div className="flex-1 min-h-0">
                  <ChartWidget
                    symbol={selectedSymbol}
                    currentData={currentMarketData}
                    authToken={auth.token}
                    history={history}
                    positions={data?.account_status?.positions || []}
                    accountStatus={data?.account_status}
                  />
                </div>

                {/* Dashboard Tables */}
                <DashboardTables
                  positions={data?.account_status?.positions || []}
                  history={history}
                  selectedSymbol={selectedSymbol}
                  pagination={pagination}
                  setPagination={setPagination}
                  onExport={handleExportHistory}
                  mt4Account={selectedAccount?.mt4_account}
                  authToken={auth.token || undefined}
                  onRefresh={fetchData}
                />
              </div>

              {/* Right Column: Account & Logs */}
              <div className="space-y-6">
                <EquityChartWidget
                  currentAccountStatus={data?.account_status || { balance: 0, equity: 0, floating_profit: 0, margin: 0, free_margin: 0, timestamp: 0, positions: [] }}
                  authToken={auth.token}
                  mt4Account={selectedAccount?.mt4_account || null}
                  broker={selectedAccount?.broker || null}
                />

                <PerformancePanel
                  trades={history}
                  selectedSymbol={selectedSymbol}
                  maxDrawdown={drawdown.max}
                  accountStatus={data?.account_status}
                  gridClass="grid-cols-2 lg:grid-cols-2 gap-3"
                />

                <RealtimeLogs logs={data?.recent_logs || []} />
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

      {isBindModalOpen && <BindModal
        onClose={() => setIsBindModalOpen(false)}
        onBind={handleBindAccount}
        form={newAccount}
        setForm={setNewAccount}
      />}
    </div>
  );
};

export default App;
