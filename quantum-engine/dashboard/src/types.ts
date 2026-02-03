export interface MarketData {
    symbol: string;
    bid: number;
    ask: number;
    close: number;
}

export interface Position {
    ticket: number;
    symbol: string;
    side: 'BUY' | 'SELL';
    lots: number;
    open_price: number;
    open_time: number;
    profit: number;
    swap: number;
    commission: number;
    mae?: number;
    mfe?: number;
}

export interface AccountStatus {
    balance: number;
    equity: number;
    floating_profit: number;
    margin: number;
    free_margin: number;
    timestamp: number;
    mt4_account?: number;
    broker?: string;
    // Risk Fields
    contract_size?: number;
    tick_value?: number;
    stop_level?: number;
    margin_so_level?: number;
    positions: Position[];
}

export interface LogEntry {
    timestamp: number;
    level: string;
    message: string;
}

export interface TradeHistory {
    ticket: number;
    symbol: string;
    open_time: number;
    close_time: number;
    open_price: number;
    close_price: number;
    lots: number;
    profit: number;
    trade_type: string;
    mae?: number;
    mfe?: number;
    signal_context?: string;
}

export interface AccountRecord {
    mt4_account: number;
    broker: string;
    account_name: string | null;
}

export interface AuthState {
    token: string | null;
    username: string | null;
    role: string | null;
}

export interface SmartExitMetrics {
    survival_distance: number;
    liquidation_price: number;
    velocity_m1: number;
    rvol: number;
    risk_score: number;
    distance_score: number;
    velocity_score: number;
    layer_score: number;
    drawdown_score: number;
    exit_trigger: string;
    trigger_reason: string;
    is_velocity_warning: boolean;
    is_rvol_warning: boolean;
    is_martingale_pattern: boolean;
    martingale_warning: string;
    rsi_14?: number;
    rsi_signal?: string;
}

export interface RiskControlState {
    mt4_account: number;
    block_buy: boolean;
    block_sell: boolean;
    block_all: boolean;
    risk_level: string; // "SAFE" | "WARNING" | "CRITICAL"
    updated_at: number;
    risk_score: number; // 0-100 Integrated Risk Score
    exit_trigger: string; // "NONE" | "LAYER_LOCK" | "TACTICAL_EXIT" | "FORCE_EXIT"
    velocity_block: boolean; // True if velocity triggered a block
    enabled: boolean;
    fingerprint_enabled: boolean;
    metrics?: SmartExitMetrics;
}
