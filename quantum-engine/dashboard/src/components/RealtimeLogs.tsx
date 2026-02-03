import React, { memo } from 'react';
import { Terminal } from 'lucide-react';
import type { LogEntry } from '../types';
import { formatServerTimeOnly } from '../utils/dateUtils';

interface RealtimeLogsProps {
    logs: LogEntry[];
}

export const RealtimeLogs: React.FC<RealtimeLogsProps> = memo(({ logs }) => {
    return (
        <div className="bg-slate-900/50 border border-slate-800 rounded-2xl flex flex-col h-[500px]">
            <div className="px-6 py-4 border-b border-slate-800 flex items-center gap-2 text-slate-400 text-xs font-bold uppercase tracking-wider">
                <Terminal className="w-4 h-4 text-cyan-500" /> 执行日志
            </div>
            <div className="flex-1 overflow-y-auto p-4 font-mono text-[11px] space-y-2">
                {logs?.map((log: LogEntry, i: number) => (
                    <div key={i} className="flex gap-2 group">
                        <span className="text-slate-600 shrink-0">[{formatServerTimeOnly(log.timestamp)}]</span>
                        <span className={`uppercase font-bold shrink-0 ${log.level === 'ERROR' ? 'text-rose-500' : log.level === 'SUCCESS' ? 'text-emerald-500' : 'text-slate-500'}`}>
                            {log.level}
                        </span>
                        <span className="text-slate-400 group-hover:text-slate-200 transition-colors">{log.message}</span>
                    </div>
                ))}
                {(!logs || logs.length === 0) && (
                    <div className="text-slate-700 italic">等待日志...</div>
                )}
            </div>
        </div>
    );
});

RealtimeLogs.displayName = 'RealtimeLogs';
