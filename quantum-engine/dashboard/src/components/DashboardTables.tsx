import React, { useState } from 'react';
import { formatServerTime } from '../utils/dateUtils';
import type { TradeHistory } from '../types';

interface DashboardTablesProps {
    positions: any[];
    history: TradeHistory[];
    selectedSymbol: string;
    pagination: { page: number; limit: number; total: number };
    setPagination: React.Dispatch<React.SetStateAction<{ page: number; limit: number; total: number }>>;
    onExport?: () => void;
}

export const DashboardTables: React.FC<DashboardTablesProps> = ({
    positions,
    history,
    selectedSymbol,
    pagination,
    setPagination,
    onExport
}) => {
    const [activeTab, setActiveTab] = useState<'positions' | 'history'>('positions');
    const [isExporting, setIsExporting] = useState(false);

    const filteredPositions = positions
        .filter((p: any) => (!selectedSymbol || p.symbol === selectedSymbol) && ['BUY', 'SELL'].includes(p.side));
    const filteredHistory = history.filter((t: TradeHistory) => !selectedSymbol || t.symbol === selectedSymbol);

    const handleExportClick = async () => {
        if (!onExport) return;
        setIsExporting(true);
        try {
            await onExport();
        } finally {
            setIsExporting(false);
        }
    };

    return (
        <div className="bg-slate-900/50 border border-slate-800 rounded-2xl overflow-hidden mt-6 flex flex-col h-[500px]">
            {/* Tab Header */}
            <div className="flex border-b border-slate-800 justify-between items-center pr-4">
                <div className="flex">
                    <button
                        onClick={() => setActiveTab('positions')}
                        className={`px-6 py-4 text-sm font-bold uppercase tracking-wide transition-colors ${activeTab === 'positions'
                            ? 'text-cyan-500 border-b-2 border-cyan-500 bg-slate-800/50'
                            : 'text-slate-500 hover:text-slate-300 hover:bg-slate-800/30'
                            }`}
                    >
                        活跃持仓 <span className="ml-2 text-xs px-2 py-0.5 bg-slate-800 rounded text-slate-400">{filteredPositions.length}</span>
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
                {activeTab === 'history' && onExport && (
                    <button
                        onClick={handleExportClick}
                        disabled={isExporting}
                        className="px-3 py-1.5 bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-bold rounded border border-slate-700 transition-colors flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                        {isExporting ? (
                            <>
                                <span className="w-3 h-3 border-2 border-slate-400 border-t-cyan-500 rounded-full animate-spin"></span>
                                导出中...
                            </>
                        ) : (
                            <>
                                <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>
                                导出 CSV
                            </>
                        )}
                    </button>
                )}
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
                            {filteredPositions.map((pos: any) => (
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
                            {filteredPositions.length === 0 && (
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
                            {filteredHistory.map((t: TradeHistory) => (
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
                                        {formatServerTime(t.close_time)}
                                    </td>
                                </tr>
                            ))}
                            {filteredHistory.length === 0 && (
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
    );
};
