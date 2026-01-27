import React, { useState } from 'react';
import axios from 'axios';
import { Lock, User, Activity } from 'lucide-react';

interface LoginPageProps {
    onLogin: (token: string, username: string, role: string) => void;
}

export const LoginPage: React.FC<LoginPageProps> = ({ onLogin }) => {
    const [isRegister, setIsRegister] = useState(false);
    const [username, setUsername] = useState('');
    const [password, setPassword] = useState('');
    const [error, setError] = useState('');
    const [isLoading, setIsLoading] = useState(false);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');
        setIsLoading(true);

        try {
            const endpoint = isRegister ? '/api/v1/auth/register' : '/api/v1/auth/login';
            const response = await axios.post(`http://127.0.0.1:3001${endpoint}`, {
                username,
                password
            });
            const { token, role } = response.data;
            onLogin(token, username, role);
        } catch (err: any) {
            setError(err.response?.data || (isRegister ? '注册失败，请换一个用户名' : '登录失败，请检查用户名或密码'));
        } finally {
            setIsLoading(false);
        }
    };

    return (
        <div className="min-h-screen bg-slate-950 flex items-center justify-center p-4">
            <div className="max-w-md w-full animate-in fade-in zoom-in duration-500">
                {/* Logo */}
                <div className="flex flex-col items-center mb-8">
                    <div className="bg-cyan-600/20 p-4 rounded-2xl border border-cyan-500/30 mb-4">
                        <Activity className="text-cyan-500 w-12 h-12" />
                    </div>
                    <h1 className="text-3xl font-bold tracking-tight text-white">
                        QuantTrader <span className="text-cyan-500">PRO</span>
                    </h1>
                    <p className="text-slate-500 mt-2 font-medium tracking-wide">量化交易终端 · {isRegister ? '新用户注册' : '权限中心'}</p>
                </div>

                {/* Form Card */}
                <div className="bg-slate-900/50 border border-slate-800 rounded-3xl p-8 shadow-2xl backdrop-blur-xl">
                    <form onSubmit={handleSubmit} className="space-y-6">
                        <div>
                            <label className="block text-xs font-bold uppercase tracking-widest text-slate-500 mb-2">用户名</label>
                            <div className="relative">
                                <span className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-500">
                                    <User size={18} />
                                </span>
                                <input
                                    type="text"
                                    value={username}
                                    onChange={(e) => setUsername(e.target.value)}
                                    className="w-full bg-slate-950 border border-slate-800 rounded-xl py-3 pl-12 pr-4 text-slate-200 focus:outline-none focus:border-cyan-500/50 transition-colors"
                                    placeholder="Enter username"
                                    required
                                />
                            </div>
                        </div>

                        <div>
                            <label className="block text-xs font-bold uppercase tracking-widest text-slate-500 mb-2">密码</label>
                            <div className="relative">
                                <span className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-500">
                                    <Lock size={18} />
                                </span>
                                <input
                                    type="password"
                                    value={password}
                                    onChange={(e) => setPassword(e.target.value)}
                                    className="w-full bg-slate-950 border border-slate-800 rounded-xl py-3 pl-12 pr-4 text-slate-200 focus:outline-none focus:border-cyan-500/50 transition-colors"
                                    placeholder="••••••••"
                                    required
                                />
                            </div>
                        </div>

                        {error && (
                            <div className="bg-rose-500/10 border border-rose-500/30 text-rose-400 text-sm p-4 rounded-xl animate-in slide-in-from-top-2">
                                {error}
                            </div>
                        )}

                        <button
                            type="submit"
                            disabled={isLoading}
                            className={`w-full bg-cyan-600 hover:bg-cyan-500 text-white font-bold py-4 rounded-xl shadow-lg shadow-cyan-900/20 transition-all active:scale-[0.98] ${isLoading ? 'opacity-50 cursor-not-allowed' : ''}`}
                        >
                            {isLoading ? '正在处理...' : (isRegister ? '立即注册账号' : '立即登录系统')}
                        </button>
                    </form>

                    <div className="mt-6 text-center">
                        <button
                            onClick={() => {
                                setIsRegister(!isRegister);
                                setError('');
                            }}
                            className="text-sm text-slate-400 hover:text-cyan-500 transition-colors"
                        >
                            {isRegister ? '已有账号？返回登录' : '没有账号？创建新用户'}
                        </button>
                    </div>
                </div>

                <div className="text-center mt-8 text-slate-600 text-sm">
                    © 2026 QuantTrader Engine. All Rights Reserved.
                </div>
            </div>
        </div>
    );
};

