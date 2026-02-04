
import React from 'react';
import { ArrowUpCircle, ArrowDownCircle, Clock } from 'lucide-react';
import type { Position } from '../types';

interface PendingOrdersWidgetProps {
    positions: Position[];
    currentPrice: number | null;
    selectedSymbol: string;
}

export const PendingOrdersWidget: React.FC<PendingOrdersWidgetProps> = ({
    positions,
    currentPrice,
    selectedSymbol
}) => {
    // 过滤出挂单
    const pendingOrders = positions.filter(p =>
        p.symbol === selectedSymbol &&
        ['BUY_LIMIT', 'SELL_LIMIT', 'BUY_STOP', 'SELL_STOP'].includes(p.type)
    );

    const buyPendings = pendingOrders.filter(p => p.side === 'BUY').sort((a, b) => b.open_price - a.open_price);
    const sellPendings = pendingOrders.filter(p => p.side === 'SELL').sort((a, b) => a.open_price - b.open_price);

    const renderOrderList = (orders: Position[], isBuy: boolean) => (
        <div className="flex-1 space-y-2">
            <div className={`flex items-center gap-2 mb-3 pb-2 border-b border-slate-800/50`}>
                {isBuy ? <ArrowUpCircle size={14} className="text-emerald-500" /> : <ArrowDownCircle size={14} className="text-rose-500" />}
                <span className={`text-[11px] font-bold uppercase tracking-wider ${isBuy ? 'text-emerald-400' : 'text-rose-400'}`}>
                    {isBuy ? '多头挂单' : '空头挂单'}
                </span>
                <span className="ml-auto text-[10px] text-slate-500 font-mono">COUNT: {orders.length}</span>
            </div>

            <div className="max-h-[200px] overflow-y-auto space-y-2 pr-1 custom-scrollbar">
                {orders.map(order => {
                    const distance = currentPrice ? Math.abs(order.open_price - currentPrice) : 0;

                    return (
                        <div key={order.ticket} className="bg-slate-900/40 rounded-lg p-2.5 border border-slate-800/50 hover:border-slate-700 transition-colors">
                            <div className="flex justify-between items-start mb-1">
                                <span className={`text-[10px] font-bold ${isBuy ? 'text-emerald-500/80' : 'text-rose-500/80'}`}>
                                    {order.type.replace('_', ' ')}
                                </span>
                                <span className="text-[11px] font-mono font-bold text-slate-200">
                                    {order.lots.toFixed(2)} Lots
                                </span>
                            </div>
                            <div className="flex justify-between items-end">
                                <div className="flex flex-col">
                                    <span className="text-[12px] font-mono font-bold text-slate-300">
                                        @{order.open_price.toFixed(order.symbol.includes('XAU') ? 2 : 5)}
                                    </span>
                                    <span className="text-[9px] text-slate-500 font-mono">
                                        #{order.ticket}
                                    </span>
                                </div>
                                <div className="text-right">
                                    <span className={`text-[10px] font-bold font-mono ${distance > 0 ? 'text-cyan-400' : 'text-slate-500'}`}>
                                        {currentPrice ? `${(distance).toFixed(order.symbol.includes('XAU') ? 2 : 4)}` : '--'}
                                    </span>
                                    <div className="text-[8px] text-slate-600 uppercase tracking-tighter">Distance</div>
                                </div>
                            </div>
                        </div>
                    );
                })}
                {orders.length === 0 && (
                    <div className="py-8 text-center border border-dashed border-slate-800/50 rounded-lg text-slate-600 text-[10px] italic">
                        暂无挂单
                    </div>
                )}
            </div>
        </div>
    );

    return (
        <div className="bg-slate-950/60 backdrop-blur-xl rounded-2xl border border-slate-800 shadow-2xl p-4 flex flex-col gap-4">
            <div className="flex items-center gap-2 mb-1">
                <Clock size={16} className="text-cyan-500" />
                <h3 className="text-xs font-bold text-slate-300 uppercase tracking-widest">挂单实时监控</h3>
                <div className="ml-auto flex gap-1">
                    <div className="w-1.5 h-1.5 rounded-full bg-cyan-500 animate-pulse" />
                </div>
            </div>

            <div className="flex flex-col md:flex-row gap-6">
                {renderOrderList(buyPendings, true)}
                {renderOrderList(sellPendings, false)}
            </div>
        </div>
    );
};
