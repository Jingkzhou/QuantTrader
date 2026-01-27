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

    const StatRow = ({ label, value, color }: { label: string, value: string | number, color?: string }) => (
        <div className="flex justify-between items-center py-1 border-b border-slate-800/30 last:border-0">
            <span className="text-slate-500 text-xs">{label}:</span>
            <span className={`font-mono text-sm font-bold ${color || 'text-slate-300'}`}>{value}</span>
        </div>
    );

    return (
        /* 3-Column Layout: Long | Short | Account */
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {/* BUY Panel (Chinese Red Theme) */}
            <div className="bg-rose-500/5 border border-rose-500/10 rounded-xl overflow-hidden shadow-lg shadow-rose-950/10">
                <div className="bg-rose-500/10 px-4 py-2 border-b border-rose-500/10 flex justify-center items-center gap-2">
                    <span className="text-rose-500 font-black text-xs tracking-widest">
                        ::: 多头 ({(!selectedSymbol || selectedSymbol === 'ALL') ? '全品种' : selectedSymbol}) :::
                    </span>
                </div>
                <div className="p-4 space-y-1">
                    <StatRow label="持仓单数" value={buyStats.count} />
                    <StatRow label="持仓手数" value={buyStats.totalLots.toFixed(2)} />
                    <StatRow label="持仓均价" value={buyStats.avgPrice.toFixed(5)} color="text-rose-400" />
                    <StatRow label="保本价格" value={buyStats.bep.toFixed(5)} color="text-rose-400" />
                    <StatRow label="隔夜利息" value={buyStats.totalSwap.toFixed(2)} />
                    <StatRow label="当前浮盈" value={buyStats.totalProfit.toFixed(2)} color={buyStats.totalProfit >= 0 ? 'text-emerald-500' : 'text-rose-500'} />
                </div>
            </div>

            {/* SELL Panel (Chinese Green Theme) */}
            <div className="bg-emerald-500/5 border border-emerald-500/10 rounded-xl overflow-hidden shadow-lg shadow-emerald-950/10">
                <div className="bg-emerald-500/10 px-4 py-2 border-b border-emerald-500/10 flex justify-center items-center gap-2">
                    <span className="text-emerald-500 font-black text-xs tracking-widest">
                        ::: 空头 ({(!selectedSymbol || selectedSymbol === 'ALL') ? '全品种' : selectedSymbol}) :::
                    </span>
                </div>
                <div className="p-4 space-y-1">
                    <StatRow label="持仓单数" value={sellStats.count} />
                    <StatRow label="持仓手数" value={sellStats.totalLots.toFixed(2)} />
                    <StatRow label="持仓均价" value={sellStats.avgPrice.toFixed(5)} color="text-emerald-400" />
                    <StatRow label="保本价格" value={sellStats.bep.toFixed(5)} color="text-emerald-400" />
                    <StatRow label="隔夜利息" value={sellStats.totalSwap.toFixed(2)} />
                    <StatRow label="当前浮盈" value={sellStats.totalProfit.toFixed(2)} color={sellStats.totalProfit >= 0 ? 'text-emerald-500' : 'text-rose-500'} />
                </div>
            </div>

            {/* Account Stats Panel (Vertical) */}
            <div className="bg-amber-500/5 border border-amber-500/10 rounded-xl overflow-hidden shadow-lg shadow-amber-950/10">
                <div className="bg-amber-500/10 px-4 py-2 border-b border-amber-500/10 flex justify-center items-center gap-2">
                    <span className="text-amber-500 font-black text-xs tracking-widest">
                        ::: 账户风控 :::
                    </span>
                </div>
                <div className="p-4 space-y-1">
                    <StatRow
                        label="预付款比例"
                        value={`${marginLevel.toFixed(0)}%`}
                        color="text-amber-500"
                    />
                    <StatRow
                        label="当前回撤"
                        value={`${currentDrawdown.toFixed(2)}%`}
                        color={currentDrawdown > 5 ? 'text-rose-500' : 'text-slate-300'}
                    />
                    <StatRow
                        label="今日盈亏"
                        value={`$${todayProfit.toFixed(2)}`}
                        color={todayProfit >= 0 ? 'text-emerald-500' : 'text-rose-500'}
                    />
                    <StatRow
                        label="最大回撤"
                        value={`${maxDrawdown.toFixed(2)}%`}
                        color="text-amber-500"
                    />
                    <div className="mt-2 pt-2 border-t border-slate-800/30 flex justify-between">
                        <span className="text-slate-500 text-xs">净值:</span>
                        <span className="font-mono text-sm font-bold text-slate-200">${accountStatus?.equity?.toFixed(2)}</span>
                    </div>
                    <div className="flex justify-between">
                        <span className="text-slate-500 text-xs">余额:</span>
                        <span className="font-mono text-sm font-bold text-slate-400">${accountStatus?.balance?.toFixed(2)}</span>
                    </div>
                </div>
            </div>
        </div>
    );
};
