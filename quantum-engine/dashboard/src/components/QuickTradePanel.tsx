import React, { useState } from 'react';
import axios from 'axios';
import { TrendingUp, TrendingDown, XCircle } from 'lucide-react';

interface QuickTradePanelProps {
    symbol: string;
}

const API_BASE = 'http://127.0.0.1:3001/api/v1';

export const QuickTradePanel: React.FC<QuickTradePanelProps> = ({ symbol }) => {
    const [lots, setLots] = useState(0.01);
    const [isExpanded, setIsExpanded] = useState(false);
    const [isSubmitting, setIsSubmitting] = useState(false);

    const sendCommand = async (action: 'OPEN_BUY' | 'OPEN_SELL' | 'CLOSE_ALL') => {
        if (isSubmitting) return;
        setIsSubmitting(true);
        try {
            await axios.post(`${API_BASE}/command`, {
                id: crypto.randomUUID(),
                action,
                symbol,
                lots,
                status: 'PENDING',
                timestamp: Math.floor(Date.now() / 1000)
            });
            // Optional: Show success toast
            console.log("Command Sent:", action);
        } catch (e) {
            console.error("Command failed", e);
        } finally {
            // Add a small delay to prevent double clicking
            setTimeout(() => setIsSubmitting(false), 500);
        }
    };

    return (
        <div className={`absolute top-20 left-6 z-10 bg-slate-900/90 backdrop-blur-md border border-slate-700 rounded-xl shadow-2xl transition-all duration-300 overflow-hidden ${isExpanded ? 'w-56 p-4' : 'w-32 p-2'}`}>
            <div
                className="flex items-center justify-between cursor-pointer"
                onClick={() => setIsExpanded(!isExpanded)}
            >
                <div className="flex flex-col">
                    <span className="text-xs font-bold text-slate-400 uppercase tracking-wider flex items-center gap-1">
                        {isExpanded ? '快速交易' : '交易面板'}
                    </span>
                    {!isExpanded && <span className="text-[10px] text-slate-600 font-mono">{symbol}</span>}
                </div>
                <button className="text-slate-500 hover:text-slate-300 transition-colors">
                    {isExpanded ? (
                        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polyline points="18 15 12 9 6 15"></polyline></svg>
                    ) : (
                        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polyline points="6 9 12 15 18 9"></polyline></svg>
                    )}
                </button>
            </div>

            {isExpanded && (
                <div className="mt-3 animate-in fade-in slide-in-from-top-2 duration-200">
                    <div className="text-[10px] text-slate-600 font-mono mb-2 text-right">{symbol}</div>

                    {/* Lots Input */}
                    <div className="flex items-center justify-between bg-slate-800 rounded-lg p-1 mb-4 border border-slate-700">
                        <button
                            onClick={() => setLots(Math.max(0.01, Number((lots - 0.01).toFixed(2))))}
                            className="w-8 h-8 flex items-center justify-center text-slate-400 hover:text-white hover:bg-slate-700 rounded transition-colors"
                        >
                            -
                        </button>
                        <input
                            type="number"
                            value={lots}
                            onChange={(e) => setLots(parseFloat(e.target.value))}
                            className="bg-transparent text-center font-mono font-bold text-white w-20 focus:outline-none"
                            step="0.01"
                        />
                        <button
                            onClick={() => setLots(Math.max(0.01, Number((lots + 0.01).toFixed(2))))}
                            className="w-8 h-8 flex items-center justify-center text-slate-400 hover:text-white hover:bg-slate-700 rounded transition-colors"
                        >
                            +
                        </button>
                    </div>

                    {/* Action Buttons */}
                    <div className="grid grid-cols-2 gap-2 mb-3">
                        <button
                            onClick={() => sendCommand('OPEN_BUY')}
                            disabled={isSubmitting}
                            className="bg-emerald-500/20 hover:bg-emerald-500/30 border border-emerald-500/50 text-emerald-500 rounded-lg py-3 flex flex-col items-center gap-1 transition-all active:scale-95 disabled:opacity-50"
                        >
                            <TrendingUp className="w-5 h-5" />
                            <span className="text-xs font-bold">买入</span>
                        </button>
                        <button
                            onClick={() => sendCommand('OPEN_SELL')}
                            disabled={isSubmitting}
                            className="bg-rose-500/20 hover:bg-rose-500/30 border border-rose-500/50 text-rose-500 rounded-lg py-3 flex flex-col items-center gap-1 transition-all active:scale-95 disabled:opacity-50"
                        >
                            <TrendingDown className="w-5 h-5" />
                            <span className="text-xs font-bold">卖出</span>
                        </button>
                    </div>

                    <button
                        onClick={() => {
                            if (confirm('确定要平掉所有持仓吗？')) sendCommand('CLOSE_ALL');
                        }}
                        disabled={isSubmitting}
                        className="w-full bg-slate-800 hover:bg-red-900/30 text-slate-400 hover:text-red-400 border border-transparent hover:border-red-900/50 rounded-lg py-2 text-xs font-mono flex items-center justify-center gap-2 transition-all"
                    >
                        <XCircle className="w-3 h-3" /> 平仓所有
                    </button>
                </div>
            )}
        </div>
    );
};
