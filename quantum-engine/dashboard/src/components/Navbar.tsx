
import React from 'react';
import { LayoutDashboard, Settings, History, BarChart2, User, LogOut } from 'lucide-react';

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

    const NavItem = ({ id, label, icon }: { id: string, label: string, icon: React.ReactNode }) => (
        <button
            onClick={() => onNavigate(id)}
            className={`flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-bold transition-all duration-200 ${activePage === id
                    ? 'bg-cyan-600/10 text-cyan-400 border border-cyan-500/20'
                    : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/50'
                }`}
        >
            {icon}
            <span>{label}</span>
        </button>
    );

    return (
        <div className="h-16 border-b border-slate-800 bg-slate-950/80 backdrop-blur-md sticky top-0 z-50 flex items-center justify-between px-6">
            {/* Logo Section */}
            <div className="flex items-center gap-3">
                <div className="bg-gradient-to-br from-cyan-600 to-blue-600 p-2 rounded-lg shadow-lg shadow-cyan-900/20">
                    <LayoutDashboard className="text-white w-5 h-5" />
                </div>
                <h1 className="text-lg font-bold tracking-tight text-white">
                    QuantTrader <span className="text-cyan-500">PRO</span>
                </h1>
            </div>

            {/* Navigation Links */}
            <div className="hidden md:flex items-center gap-2 bg-slate-900/50 p-1 rounded-2xl border border-slate-800/50">
                <NavItem id="dashboard" label="交易监控" icon={<LayoutDashboard className="w-4 h-4" />} />
                <NavItem id="analysis" label="数据分析" icon={<BarChart2 className="w-4 h-4" />} />
                <NavItem id="history" label="历史记录" icon={<History className="w-4 h-4" />} />
                <NavItem id="settings" label="系统设置" icon={<Settings className="w-4 h-4" />} />
            </div>

            {/* User Section */}
            <div className="flex items-center gap-4">
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
    );
};
