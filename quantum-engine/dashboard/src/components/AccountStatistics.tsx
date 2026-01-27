import React from 'react';

interface Position {
    side: string;
    lots: number;
    open_price: number;
    profit: number;
    swap: number;
    commission: number;
    symbol: string;
}

interface AccountStatisticsProps {
    positions: Position[];
    accountStatus: any;
    history: any[];
    selectedSymbol: string;
    currentDrawdown: number;
    maxDrawdown: number;
}

export const AccountStatistics: React.FC<AccountStatisticsProps> = ({
    positions, accountStatus, history, selectedSymbol, currentDrawdown, maxDrawdown
}) => {

    // Calculate per-side stats
    const calculateSideStats = (side: string) => {
        const sidePos = positions.filter(p =>
            p.side === side &&
            (!selectedSymbol || selectedSymbol === 'ALL' || p.symbol === selectedSymbol)
        );
        const count = sidePos.length;
        const totalLots = sidePos.reduce((sum, p) => sum + p.lots, 0);
        const weightedPriceSum = sidePos.reduce((sum, p) => sum + (p.open_price * p.lots), 0);
        const totalProfit = sidePos.reduce((sum, p) => sum + p.profit, 0);
        const totalSwap = sidePos.reduce((sum, p) => sum + (p.swap || 0), 0);
        const totalComm = sidePos.reduce((sum, p) => sum + (p.commission || 0), 0);

        const avgPrice = totalLots > 0 ? weightedPriceSum / totalLots : 0;

        // BEP calculation (simplified)
        const bep = avgPrice;

        return { count, totalLots, avgPrice, totalProfit, totalSwap, totalComm, bep };
    };

    const buyStats = calculateSideStats('BUY');
    const sellStats = calculateSideStats('SELL');

    // Calculate Global Stats
    const today = new Date().setHours(0, 0, 0, 0) / 1000;
    const todayProfit = history
        .filter(t => t.close_time >= today)
        .reduce((sum, t) => sum + t.profit, 0);

    const marginLevel = accountStatus.margin_level || 0;



    return (
        /* Unified Command Center Panel */
        <div className="bg-slate-900/40 border border-slate-800 rounded-2xl overflow-hidden backdrop-blur-sm shadow-2xl relative group">

            {/* Ambient Background Glow */}
            <div className="absolute top-0 left-0 right-0 h-1 bg-gradient-to-r from-emerald-500/50 via-cyan-500/50 to-rose-500/50 opacity-50 group-hover:opacity-100 transition-opacity" />

            {/* Header: Global Account Metrics */}
            <div className="grid grid-cols-2 md:grid-cols-7 gap-4 px-6 py-4 border-b border-slate-800/50 items-center bg-slate-900/20">
                <div className="flex flex-col">
                    <span className="text-slate-500 text-[10px] font-bold uppercase tracking-widest">净值 (Equity)</span>
                    <span className="font-mono text-xl font-bold text-slate-100">${accountStatus?.equity?.toFixed(2)}</span>
                </div>
                <div className="flex flex-col">
                    <span className="text-slate-500 text-[10px] font-bold uppercase tracking-widest">余额 (Balance)</span>
                    <span className="font-mono text-lg font-bold text-slate-400">${accountStatus?.balance?.toFixed(2)}</span>
                </div>
                <div className="flex flex-col">
                    <span className="text-slate-500 text-[10px] font-bold uppercase tracking-widest">持仓利润</span>
                    <span className={`font-mono text-2xl font-black tracking-tighter drop-shadow-lg ${buyStats.totalProfit + sellStats.totalProfit >= 0 ? 'text-emerald-400' : 'text-rose-400'}`}>
                        {(buyStats.totalProfit + sellStats.totalProfit) >= 0 ? '+' : ''}
                        {(buyStats.totalProfit + sellStats.totalProfit).toFixed(2)}
                    </span>
                </div>
                <div className="flex flex-col">
                    <span className="text-slate-500 text-[10px] font-bold uppercase tracking-widest">今日盈亏</span>
                    <span className={`font-mono text-lg font-bold ${todayProfit >= 0 ? 'text-emerald-500' : 'text-rose-500'}`}>
                        {todayProfit >= 0 ? '+' : ''}{todayProfit.toFixed(2)}
                    </span>
                </div>
                <div className="flex flex-col">
                    <span className="text-slate-500 text-[10px] font-bold uppercase tracking-widest">已用预付款</span>
                    <span className="font-mono text-lg font-bold text-slate-300">${accountStatus?.margin?.toFixed(2)}</span>
                </div>
                <div className="flex flex-col">
                    <span className="text-slate-500 text-[10px] font-bold uppercase tracking-widest">预付款比例</span>
                    <span className="font-mono text-lg font-bold text-amber-500">{marginLevel.toFixed(0)}%</span>
                </div>
                <div className="flex flex-col">
                    <span className="text-slate-500 text-[10px] font-bold uppercase tracking-widest">最大回撤</span>
                    <div className="flex items-baseline gap-2">
                        <span className={`font-mono text-lg font-bold ${currentDrawdown > 5 ? 'text-rose-500' : 'text-slate-300'}`}>
                            {currentDrawdown.toFixed(2)}%
                        </span>
                        <span className="text-[10px] text-slate-500 font-mono">Max: {maxDrawdown.toFixed(2)}%</span>
                    </div>
                </div>
            </div>

            {/* Main Body: Long vs Short Split */}
            <div className="grid grid-cols-1 md:grid-cols-2 divide-y md:divide-y-0 md:divide-x divide-slate-800/50">

                {/* BUY Section */}
                <div className="p-4 bg-gradient-to-b from-rose-500/5 to-transparent relative">
                    <div className="absolute top-2 left-2 text-[10px] font-black tracking-widest text-rose-500/20 uppercase pointer-events-none">Long Positions</div>
                    <div className="flex items-center justify-between mb-4">
                        <div className="flex items-center gap-2">
                            <div className="w-1.5 h-1.5 rounded-full bg-rose-500 shadow-[0_0_8px_rgba(244,63,94,0.6)]" />
                            <span className="font-bold text-rose-400 text-sm">多头持仓</span>
                            <span className="text-[10px] bg-rose-500/10 text-rose-500 px-1.5 py-0.5 rounded border border-rose-500/20">
                                {(!selectedSymbol || selectedSymbol === 'ALL') ? 'ALL' : selectedSymbol}
                            </span>
                        </div>
                        <div className="text-right">
                            <div className="text-2xl font-mono font-bold text-rose-500 table-nums">
                                {buyStats.count} <span className="text-sm text-rose-500/50 font-sans font-normal">笔</span>
                            </div>
                        </div>
                    </div>

                    <div className="grid grid-cols-2 gap-x-4 gap-y-2 text-xs">
                        <div className="flex justify-between">
                            <span className="text-slate-500">总手数</span>
                            <span className="font-mono text-slate-300">{buyStats.totalLots.toFixed(2)}</span>
                        </div>
                        <div className="flex justify-between">
                            <span className="text-slate-500">持仓均价</span>
                            <span className="font-mono text-rose-300">{buyStats.avgPrice.toFixed(5)}</span>
                        </div>
                        <div className="flex justify-between">
                            <span className="text-slate-500">隔夜息</span>
                            <span className="font-mono text-slate-400">{buyStats.totalSwap.toFixed(2)}</span>
                        </div>
                        <div className="flex justify-between">
                            <span className="text-slate-500">浮动盈亏</span>
                            <span className={`font-mono font-bold ${buyStats.totalProfit >= 0 ? 'text-emerald-500' : 'text-rose-500'}`}>
                                {buyStats.totalProfit >= 0 ? '+' : ''}{buyStats.totalProfit.toFixed(2)}
                            </span>
                        </div>
                    </div>
                </div>

                {/* SELL Section */}
                <div className="p-4 bg-gradient-to-b from-emerald-500/5 to-transparent relative">
                    <div className="absolute top-2 right-2 text-[10px] font-black tracking-widest text-emerald-500/20 uppercase pointer-events-none">Short Positions</div>
                    <div className="flex items-center justify-between mb-4">
                        <div className="flex items-center gap-2">
                            <div className="w-1.5 h-1.5 rounded-full bg-emerald-500 shadow-[0_0_8px_rgba(16,185,129,0.6)]" />
                            <span className="font-bold text-emerald-400 text-sm">空头持仓</span>
                            <span className="text-[10px] bg-emerald-500/10 text-emerald-500 px-1.5 py-0.5 rounded border border-emerald-500/20">
                                {(!selectedSymbol || selectedSymbol === 'ALL') ? 'ALL' : selectedSymbol}
                            </span>
                        </div>
                        <div className="text-right">
                            <div className="text-2xl font-mono font-bold text-emerald-500 table-nums">
                                {sellStats.count} <span className="text-sm text-emerald-500/50 font-sans font-normal">笔</span>
                            </div>
                        </div>
                    </div>

                    <div className="grid grid-cols-2 gap-x-4 gap-y-2 text-xs">
                        <div className="flex justify-between">
                            <span className="text-slate-500">总手数</span>
                            <span className="font-mono text-slate-300">{sellStats.totalLots.toFixed(2)}</span>
                        </div>
                        <div className="flex justify-between">
                            <span className="text-slate-500">持仓均价</span>
                            <span className="font-mono text-emerald-300">{sellStats.avgPrice.toFixed(5)}</span>
                        </div>
                        <div className="flex justify-between">
                            <span className="text-slate-500">隔夜息</span>
                            <span className="font-mono text-slate-400">{sellStats.totalSwap.toFixed(2)}</span>
                        </div>
                        <div className="flex justify-between">
                            <span className="text-slate-500">浮动盈亏</span>
                            <span className={`font-mono font-bold ${sellStats.totalProfit >= 0 ? 'text-emerald-500' : 'text-rose-500'}`}>
                                {sellStats.totalProfit >= 0 ? '+' : ''}{sellStats.totalProfit.toFixed(2)}
                            </span>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
};
