-- Initial Schema for QuantTrader (TimescaleDB / PostgreSQL)
-- This script creates the necessary tables for core_engine to compile and run.

-- [PATCH] Update existing trade_history if it exists
ALTER TABLE trade_history ADD COLUMN IF NOT EXISTS mae DOUBLE PRECISION DEFAULT 0.0;
ALTER TABLE trade_history ADD COLUMN IF NOT EXISTS mfe DOUBLE PRECISION DEFAULT 0.0;
ALTER TABLE trade_history ADD COLUMN IF NOT EXISTS signal_context TEXT;
CREATE INDEX IF NOT EXISTS idx_trade_history_magic ON trade_history(magic);

-- 1. market_data: Stores real-time and historical price data
CREATE TABLE IF NOT EXISTS market_data (
    id BIGSERIAL PRIMARY KEY,
    symbol TEXT NOT NULL,
    timestamp BIGINT NOT NULL,
    open DOUBLE PRECISION,
    high DOUBLE PRECISION,
    low DOUBLE PRECISION,
    close DOUBLE PRECISION,
    bid DOUBLE PRECISION,
    ask DOUBLE PRECISION,
    mt4_account BIGINT,
    broker TEXT
);

-- 2. account_status: Stores account metrics like balance and equity
CREATE TABLE IF NOT EXISTS account_status (
    id BIGSERIAL PRIMARY KEY,
    balance DOUBLE PRECISION,
    equity DOUBLE PRECISION,
    margin DOUBLE PRECISION,
    free_margin DOUBLE PRECISION,
    floating_profit DOUBLE PRECISION,
    timestamp BIGINT NOT NULL,
    positions_snapshot TEXT,
    mt4_account BIGINT,
    broker TEXT
);

-- 3. trade_history: Stores closed trade records
CREATE TABLE IF NOT EXISTS trade_history (
    ticket INTEGER PRIMARY KEY,
    symbol TEXT NOT NULL,
    open_time BIGINT NOT NULL,
    close_time BIGINT NOT NULL,
    open_price DOUBLE PRECISION,
    close_price DOUBLE PRECISION,
    lots DOUBLE PRECISION,
    profit DOUBLE PRECISION,
    trade_type TEXT NOT NULL,
    magic INTEGER,
    mae DOUBLE PRECISION DEFAULT 0.0,
    mfe DOUBLE PRECISION DEFAULT 0.0,
    signal_context TEXT,
    mt4_account BIGINT,
    broker TEXT
);

-- 4. users: Base user table for authentication and authorization
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'viewer'
);

-- 5. user_accounts: Direct binding between internal users and MT4 accounts/brokers
CREATE TABLE IF NOT EXISTS user_accounts (
    user_id INTEGER NOT NULL REFERENCES users(id),
    mt4_account BIGINT NOT NULL,
    broker TEXT NOT NULL,
    account_name TEXT,
    permission TEXT DEFAULT 'read_write',
    created_at BIGINT NOT NULL,
    PRIMARY KEY (user_id, mt4_account, broker)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_market_data_symbol_ts ON market_data(symbol, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_account_status_mt4 ON account_status(mt4_account, broker, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_trade_history_mt4 ON trade_history(mt4_account, broker, close_time DESC);
CREATE INDEX IF NOT EXISTS idx_trade_history_magic ON trade_history(magic);
