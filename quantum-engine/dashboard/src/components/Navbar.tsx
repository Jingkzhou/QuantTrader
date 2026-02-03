
import React, { useState } from 'react';
import { LayoutDashboard, Settings, History, BarChart2, User, LogOut, Menu, X, ChevronDown, Check, Plus, Trash2 } from 'lucide-react';

interface NavbarProps {
    currentUser: {
        username: string | null;
        role: string | null;
    };
    onLogout: () => void;
    activePage: string;
    onNavigate: (page: string) => void;

    // Account Props
    accounts: any[];
    selectedAccount: any;
    setSelectedAccount: (account: any) => void;
    onBindAccount: () => void;
    onUnbindAccount: (mt4_account: number, broker: string) => void;

    // Symbol Props
    activeSymbols: string[];
    selectedSymbol: string;
    setSelectedSymbol: (symbol: string) => void;
}

export const Navbar: React.FC<NavbarProps> = ({
    currentUser, onLogout, activePage, onNavigate,
    accounts, selectedAccount, setSelectedAccount, onBindAccount, onUnbindAccount,
    activeSymbols, selectedSymbol, setSelectedSymbol
}) => {
    const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);

    // Dropdown States
    const [isAccountMenuOpen, setIsAccountMenuOpen] = useState(false);
    const [isSymbolMenuOpen, setIsSymbolMenuOpen] = useState(false);
    const [searchTerm, setSearchTerm] = useState('');

    const NavItem = ({ id, label, icon }: { id: string, label: string, icon: React.ReactNode }) => (
        <button
            onClick={() => {
                onNavigate(id);
                setIsMobileMenuOpen(false);
            }}
            className={`flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-bold transition-all duration-200 w-full md:w-auto ${activePage === id
                ? 'bg-cyan-600/10 text-cyan-400 border border-cyan-500/20'
                : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/50'
                }`}
        >
            {icon}
            <span>{label}</span>
        </button>
    );

    return (
        <div className="border-b border-slate-800 bg-slate-950/80 backdrop-blur-md sticky top-0 z-50">
            <div className="h-16 flex items-center justify-between px-4 md:px-6">

                <div className="flex items-center gap-6">
                    {/* Logo Section */}
                    <div className="flex items-center gap-3">
                        <div className="bg-gradient-to-br from-cyan-600 to-blue-600 p-2 rounded-lg shadow-lg shadow-cyan-900/20">
                            <LayoutDashboard className="text-white w-5 h-5" />
                        </div>
                        <h1 className="text-lg font-bold tracking-tight text-white hidden md:block">
                            QuantTrader <span className="text-cyan-500">PRO</span>
                        </h1>
                        <h1 className="text-lg font-bold tracking-tight text-white md:hidden">
                            QT <span className="text-cyan-500">PRO</span>
                        </h1>
                    </div>

                    <div className="hidden md:block h-6 w-px bg-slate-800"></div>

                    {/* Desktop Selectors */}
                    <div className="hidden md:flex items-center gap-4">
                        {/* Account Switcher */}
                        <div className="relative group z-20">
                            <button
                                onClick={() => setIsAccountMenuOpen(!isAccountMenuOpen)}
                                onBlur={() => setTimeout(() => setIsAccountMenuOpen(false), 200)}
                                className="bg-slate-900 border border-slate-800 rounded-xl px-3 py-1.5 flex items-center gap-3 cursor-pointer hover:border-cyan-500/50 transition-all min-w-[200px] text-left"
                            >
                                <div className="flex flex-col">
                                    <span className="text-[10px] text-slate-500 font-bold uppercase tracking-widest">当前账户</span>
                                    <span className="text-sm font-bold text-cyan-500 truncate max-w-[160px]">
                                        {(() => {
                                            const acc = accounts.find(a => a.mt4_account === selectedAccount?.mt4_account && a.broker === selectedAccount?.broker);
                                            return acc?.account_name || (acc ? `MT4: ${acc.mt4_account}` : "未选择");
                                        })()}
                                    </span>
                                </div>
                                <ChevronDown size={14} className={`text-slate-600 transition-transform ml-auto ${isAccountMenuOpen ? 'rotate-180 text-cyan-500' : ''}`} />
                            </button>

                            <div className={`absolute top-full left-0 mt-2 w-64 bg-slate-900 border border-slate-800 rounded-xl shadow-2xl transition-all z-50 overflow-hidden origin-top ${isAccountMenuOpen ? 'opacity-100 scale-100 visible' : 'opacity-0 scale-95 invisible'}`}>
                                {accounts.map(acc => {
                                    const isActive = selectedAccount?.mt4_account === acc.mt4_account && selectedAccount?.broker === acc.broker;
                                    return (
                                        <div
                                            key={`${acc.mt4_account}:${acc.broker}`}
                                            className={`flex items-center justify-between px-4 py-3 cursor-pointer group/item hover:bg-slate-800 transition-colors ${isActive ? 'bg-cyan-600/10' : ''}`}
                                            onClick={() => { setSelectedAccount({ mt4_account: acc.mt4_account, broker: acc.broker }); setIsAccountMenuOpen(false); }}
                                        >
                                            <div className="flex flex-col">
                                                <span className="text-sm font-bold text-slate-200">{acc.account_name || `MT4: ${acc.mt4_account}`}</span>
                                                <span className="text-[10px] text-slate-500 lowercase">{acc.broker}</span>
                                            </div>
                                            <div className="flex items-center gap-2">
                                                {isActive && <Check size={14} className="text-cyan-500" />}
                                                <button
                                                    onClick={(e) => {
                                                        e.stopPropagation();
                                                        if (window.confirm(`确定要解除绑定账号 ${acc.mt4_account} (${acc.broker}) 吗？`)) {
                                                            onUnbindAccount(acc.mt4_account, acc.broker);
                                                        }
                                                    }}
                                                    className="p-1 px-2 rounded-md transition-all h-6 opacity-0 group-hover/item:opacity-100 hover:bg-rose-500/20 text-slate-600 hover:text-rose-500"
                                                    title="解除绑定"
                                                >
                                                    <Trash2 size={12} />
                                                </button>
                                            </div>
                                        </div>
                                    );
                                })}
                                <div
                                    onClick={onBindAccount}
                                    className="px-4 py-3 border-t border-slate-800 flex items-center gap-2 text-cyan-500 hover:bg-cyan-500/10 cursor-pointer transition-colors"
                                >
                                    <Plus size={14} />
                                    <span className="text-xs font-bold uppercase tracking-widest">绑定新账号</span>
                                </div>
                            </div>
                        </div>

                        {/* Symbol Selector (Optimized Dropdown) */}
                        <div className="relative group z-20">
                            {/* Trigger */}
                            <button
                                onClick={() => {
                                    setIsSymbolMenuOpen(!isSymbolMenuOpen);
                                    if (!isSymbolMenuOpen) setSearchTerm(''); // Reset search on open
                                }}
                                // onBlur handled manually inside dropdown to allow input focus
                                className="bg-slate-900 border border-slate-800 rounded-xl px-3 py-1.5 flex items-center gap-3 cursor-pointer hover:border-cyan-500/50 transition-all min-w-[140px] text-left"
                            >
                                <div className="flex flex-col">
                                    <span className="text-[10px] text-slate-500 font-bold uppercase tracking-widest">交易品种</span>
                                    <span className="text-sm font-bold text-slate-200">
                                        {selectedSymbol || "未选择"}
                                    </span>
                                </div>
                                <ChevronDown size={14} className={`text-slate-600 transition-transform ml-auto ${isSymbolMenuOpen ? 'rotate-180 text-cyan-500' : ''}`} />
                            </button>

                            {/* Dropdown Menu */}
                            {isSymbolMenuOpen && (
                                <>
                                    <div className="fixed inset-0 z-40" onClick={() => setIsSymbolMenuOpen(false)}></div>
                                    <div className="absolute top-full left-0 mt-2 w-56 bg-slate-900 border border-slate-800 rounded-xl shadow-2xl animate-in fade-in zoom-in-95 duration-100 z-50 overflow-hidden">
                                        <div className="p-2 border-b border-slate-800">
                                            <div className="relative">
                                                <input
                                                    type="text"
                                                    placeholder="搜索品种..."
                                                    autoFocus
                                                    className="w-full bg-slate-950 border border-slate-800 rounded-lg py-1.5 pl-8 pr-3 text-xs text-slate-200 focus:outline-none focus:border-cyan-500/50 placeholder:text-slate-600"
                                                    value={searchTerm}
                                                    onChange={(e) => setSearchTerm(e.target.value)}
                                                />
                                                <div className="absolute left-2.5 top-2 text-slate-600">
                                                    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="11" cy="11" r="8" /><path d="m21 21-4.3-4.3" /></svg>
                                                </div>
                                            </div>
                                        </div>

                                        <div className="max-h-[300px] overflow-y-auto p-1 custom-scrollbar">
                                            {(activeSymbols || [])
                                                .filter(s => s.toLowerCase().includes(searchTerm.toLowerCase()))
                                                .map((sym: string) => (
                                                    <div
                                                        key={sym}
                                                        onClick={() => { setSelectedSymbol(sym); setIsSymbolMenuOpen(false); }}
                                                        className={`flex items-center justify-between px-3 py-2 rounded-lg cursor-pointer hover:bg-slate-800 transition-colors ${selectedSymbol === sym ? 'bg-cyan-600/10 text-cyan-400' : 'text-slate-300'}`}
                                                    >
                                                        <span className="text-sm font-bold">{sym}</span>
                                                        {selectedSymbol === sym && <Check size={14} className="text-cyan-500" />}
                                                    </div>
                                                ))}
                                            {(activeSymbols || []).filter(s => s.toLowerCase().includes(searchTerm.toLowerCase())).length === 0 && (
                                                <div className="px-4 py-8 text-xs text-slate-500 italic text-center">
                                                    未找到 "{searchTerm}"
                                                </div>
                                            )}
                                        </div>
                                    </div>
                                </>
                            )}
                        </div>
                    </div>
                </div>

                <div className="flex items-center gap-6">
                    {/* Desktop Navigation */}
                    <div className="hidden md:flex items-center gap-2 bg-slate-900/50 p-1 rounded-2xl border border-slate-800/50">
                        <NavItem id="dashboard" label="交易监控" icon={<LayoutDashboard className="w-4 h-4" />} />
                        <NavItem id="analysis" label="数据分析" icon={<BarChart2 className="w-4 h-4" />} />
                        {/* <NavItem id="history" label="历史记录" icon={<History className="w-4 h-4" />} /> */}
                        {/* <NavItem id="settings" label="系统设置" icon={<Settings className="w-4 h-4" />} /> */}
                    </div>

                    {/* User Section (Desktop) */}
                    <div className="hidden md:flex items-center gap-4">
                        <div className="flex items-center gap-3 pl-4 border-l border-slate-800">
                            <div className="flex flex-col items-end">
                                <span className="text-xs font-bold text-slate-200">{currentUser.username}</span>
                                <span className="text-[10px] text-slate-500 uppercase tracking-wider">{currentUser.role}</span>
                            </div>
                            <div className="w-9 h-9 rounded-full bg-slate-900 border border-slate-800 flex items-center justify-center">
                                <User className="w-4 h-4 text-cyan-500" />
                            </div>
                            <button
                                onClick={onLogout}
                                className="p-2 rounded-lg text-slate-500 hover:text-rose-500 hover:bg-rose-500/10 transition-colors"
                                title="退出登录"
                            >
                                <LogOut className="w-4 h-4" />
                            </button>
                        </div>
                    </div>
                </div>

                {/* Mobile Menu Button */}
                <button
                    onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
                    className="md:hidden p-2 text-slate-400 hover:text-white"
                >
                    {isMobileMenuOpen ? <X size={24} /> : <Menu size={24} />}
                </button>
            </div>

            {/* Mobile Menu Overlay */}
            {isMobileMenuOpen && (
                <div className="md:hidden border-t border-slate-800 bg-slate-950 absolute w-full left-0 px-4 py-4 shadow-2xl space-y-4 animate-in slide-in-from-top-2 h-[calc(100vh-64px)] overflow-y-auto">
                    {/* Mobile Selectors */}
                    <div className="space-y-4 pb-4 border-b border-slate-800">
                        {/* Mobile Account Switcher */}
                        <div className="flex flex-col gap-2">
                            <span className="text-xs text-slate-500 uppercase font-bold tracking-widest">当前账户</span>
                            <div className="grid grid-cols-1 gap-2">
                                {accounts.map(acc => (
                                    <div
                                        key={`${acc.mt4_account}:${acc.broker}`}
                                        className={`group px-4 py-3 rounded-xl flex items-center justify-between border ${selectedAccount?.mt4_account === acc.mt4_account && selectedAccount?.broker === acc.broker ? 'bg-cyan-600/10 border-cyan-500/50 text-cyan-400' : 'bg-slate-900 border-slate-800 text-slate-400'}`}
                                    >
                                        <div
                                            onClick={() => { setSelectedAccount({ mt4_account: acc.mt4_account, broker: acc.broker }); setIsMobileMenuOpen(false); }}
                                            className="flex-1 text-left"
                                        >
                                            <div className="font-bold">{acc.account_name || `MT4: ${acc.mt4_account}`}</div>
                                            <div className="text-[10px] opacity-70">{acc.broker}</div>
                                        </div>
                                        <button
                                            onClick={(e) => {
                                                e.stopPropagation();
                                                if (window.confirm(`确定要解除绑定账号 ${acc.mt4_account} (${acc.broker}) 吗？`)) {
                                                    onUnbindAccount(acc.mt4_account, acc.broker);
                                                }
                                            }}
                                            className="p-2 ml-2 rounded-lg bg-rose-500/10 text-rose-500"
                                        >
                                            <Trash2 size={14} />
                                        </button>
                                    </div>
                                ))}
                                <button onClick={() => { onBindAccount(); setIsMobileMenuOpen(false); }} className="px-4 py-3 rounded-xl border border-dashed border-slate-700 text-slate-500 flex items-center justify-center gap-2">
                                    <Plus size={14} /> 绑定新账号
                                </button>
                            </div>
                        </div>

                        {/* Mobile Symbol Selector */}
                        <div className="flex flex-col gap-2">
                            <span className="text-xs text-slate-500 uppercase font-bold tracking-widest">交易品种</span>
                            <div className="flex flex-wrap gap-2">
                                {(activeSymbols || []).map((sym: string) => (
                                    <button
                                        key={sym}
                                        onClick={() => { setSelectedSymbol(sym); setIsMobileMenuOpen(false); }}
                                        className={`px-3 py-1.5 rounded-lg text-xs font-bold ${selectedSymbol === sym ? 'bg-cyan-600 text-white' : 'bg-slate-900 text-slate-500 border border-slate-800'}`}
                                    >
                                        {sym}
                                    </button>
                                ))}
                            </div>
                        </div>
                    </div>

                    <div className="flex flex-col gap-2">
                        <NavItem id="dashboard" label="交易监控" icon={<LayoutDashboard className="w-4 h-4" />} />
                        <NavItem id="analysis" label="数据分析" icon={<BarChart2 className="w-4 h-4" />} />
                        <NavItem id="history" label="历史记录" icon={<History className="w-4 h-4" />} />
                        <NavItem id="settings" label="系统设置" icon={<Settings className="w-4 h-4" />} />
                    </div>

                    <div className="border-t border-slate-800 pt-4 flex items-center justify-between mt-auto">
                        <div className="flex items-center gap-3">
                            <div className="w-9 h-9 rounded-full bg-slate-900 border border-slate-800 flex items-center justify-center">
                                <User className="w-4 h-4 text-cyan-500" />
                            </div>
                            <div className="flex flex-col">
                                <span className="text-sm font-bold text-slate-200">{currentUser.username}</span>
                                <span className="text-[10px] text-slate-500 uppercase tracking-wider">{currentUser.role}</span>
                            </div>
                        </div>
                        <button
                            onClick={onLogout}
                            className="flex items-center gap-2 px-4 py-2 rounded-lg text-rose-500 bg-rose-500/10 hover:bg-rose-500/20 transition-colors text-sm font-bold"
                        >
                            <LogOut className="w-4 h-4" />
                            退出
                        </button>
                    </div>
                </div>
            )}
        </div>
    );
};

