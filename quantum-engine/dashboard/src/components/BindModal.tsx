import React from 'react';

interface BindModalProps {
    onClose: () => void;
    onBind: (e: React.FormEvent) => void;
    form: {
        mt4_account: string;
        broker: string;
        name: string;
    };
    setForm: (form: any) => void;
}

export const BindModal: React.FC<BindModalProps> = ({ onClose, onBind, form, setForm }) => {
    const commonBrokers = [
        "D Prime Vanuatu Limited", "Exness", "IC Markets", "XM", "Tickmill",
        "Vantage", "Doo Prime", "EightCap", "Pepperstone", "FBS", "OctaFX",
        "RoboForex", "HFM", "FXTM", "Admiral Markets", "GemForex",
        "ThinkMarkets", "Axi", "Swissquote", "OANDA", "IG Markets",
        "FXCM", "AETOS", "VT Markets"
    ];

    return (
        <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm animate-in fade-in duration-300">
            <div className="bg-slate-900 border border-slate-800 w-full max-w-md rounded-3xl p-8 shadow-2xl animate-in zoom-in-95 duration-200">
                <div className="flex justify-between items-center mb-6">
                    <h3 className="text-xl font-bold text-white">绑定 MT4 交易账号</h3>
                    <button onClick={onClose} className="text-slate-500 hover:text-white transition-colors">&times;</button>
                </div>
                <form onSubmit={onBind} className="space-y-6">
                    <div>
                        <label className="block text-xs font-bold uppercase tracking-widest text-slate-500 mb-2">MT4 账号</label>
                        <input
                            type="number"
                            value={form.mt4_account}
                            onChange={(e) => setForm({ ...form, mt4_account: e.target.value })}
                            className="w-full bg-slate-950 border border-slate-800 rounded-xl py-3 px-4 text-slate-200 focus:outline-none focus:border-cyan-500/50"
                            placeholder="例: 1234567"
                            required
                        />
                    </div>
                    <div>
                        <label className="block text-xs font-bold uppercase tracking-widest text-slate-500 mb-2">券商名称 (Broker)</label>
                        <input
                            type="text"
                            list="broker-list"
                            value={form.broker}
                            onChange={(e) => setForm({ ...form, broker: e.target.value })}
                            className="w-full bg-slate-950 border border-slate-800 rounded-xl py-3 px-4 text-slate-200 focus:outline-none focus:border-cyan-500/50"
                            placeholder="搜索或输入券商名称"
                            required
                        />
                        <datalist id="broker-list">
                            {commonBrokers.map(broker => (
                                <option key={broker} value={broker} />
                            ))}
                        </datalist>
                    </div>
                    <div>
                        <label className="block text-xs font-bold uppercase tracking-widest text-slate-500 mb-2">备注名称 (可选)</label>
                        <input
                            type="text"
                            value={form.name}
                            onChange={(e) => setForm({ ...form, name: e.target.value })}
                            className="w-full bg-slate-950 border border-slate-800 rounded-xl py-3 px-4 text-slate-200 focus:outline-none focus:border-cyan-500/50"
                            placeholder="例: 麒麟 1 号实盘"
                        />
                    </div>
                    <button
                        type="submit"
                        className="w-full bg-cyan-600 hover:bg-cyan-500 text-white font-bold py-4 rounded-xl shadow-lg transition-all active:scale-[0.98]"
                    >
                        确认绑定
                    </button>
                </form>
            </div>
        </div>
    );
};
