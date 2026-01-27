
import React, { useState } from 'react';
import { LayoutDashboard, Settings, History, BarChart2, User, LogOut, Menu, X } from 'lucide-react';

interface NavbarProps {
    currentUser: {
        username: string | null;
        role: string | null;
    };
    onLogout: () => void;
    activePage: string;
    onNavigate: (page: string) => void;
}

export const Navbar: React.FC<NavbarProps> = ({ currentUser, onLogout, activePage, onNavigate }) => {
    const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);

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

                {/* Desktop Navigation */}
                <div className="hidden md:flex items-center gap-2 bg-slate-900/50 p-1 rounded-2xl border border-slate-800/50">
                    <NavItem id="dashboard" label="交易监控" icon={<LayoutDashboard className="w-4 h-4" />} />
                    <NavItem id="analysis" label="数据分析" icon={<BarChart2 className="w-4 h-4" />} />
                    <NavItem id="history" label="历史记录" icon={<History className="w-4 h-4" />} />
                    <NavItem id="settings" label="系统设置" icon={<Settings className="w-4 h-4" />} />
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
                <div className="md:hidden border-t border-slate-800 bg-slate-950 absolute w-full left-0 px-4 py-4 shadow-2xl space-y-4 animate-in slide-in-from-top-2">
                    <div className="flex flex-col gap-2">
                        <NavItem id="dashboard" label="交易监控" icon={<LayoutDashboard className="w-4 h-4" />} />
                        <NavItem id="analysis" label="数据分析" icon={<BarChart2 className="w-4 h-4" />} />
                        <NavItem id="history" label="历史记录" icon={<History className="w-4 h-4" />} />
                        <NavItem id="settings" label="系统设置" icon={<Settings className="w-4 h-4" />} />
                    </div>
                    <div className="border-t border-slate-800 pt-4 flex items-center justify-between">
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
