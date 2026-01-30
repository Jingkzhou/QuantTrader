use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, Clone, Default)]
pub struct MarketData {
    pub symbol: String,
    pub timestamp: u64,
    pub open: f64,
    pub high: f64,
    pub low: f64,
    pub close: f64,
    pub bid: f64,
    pub ask: f64,
}

#[derive(Debug, Serialize, Deserialize, Clone, Default)]
pub struct Position {
    pub ticket: i32,
    pub symbol: String,
    pub side: String,
    pub lots: f64,
    #[serde(default)]
    pub open_price: f64,
    #[serde(default)]
    pub open_time: i64,
    pub profit: f64,
    #[serde(default)]
    pub swap: f64,
    #[serde(default)]
    pub commission: f64,
    #[serde(default)]
    pub mae: f64,
    #[serde(default)]
    pub mfe: f64,
}

#[derive(Debug, Serialize, Deserialize, Clone, Default)]
pub struct AccountStatus {
    pub balance: f64,
    pub equity: f64,
    pub margin: f64,
    pub free_margin: f64,
    pub floating_profit: f64,
    pub timestamp: i64, 
    #[serde(default)]
    pub margin_level: f64,
    #[serde(default)]
    pub mt4_account: i64,
    #[serde(default)]
    pub broker: String,
    // Symbol Info for Risk Calc
    #[serde(default)]
    pub contract_size: f64,
    #[serde(default)]
    pub tick_value: f64,
    #[serde(default)]
    pub stop_level: i32,
    #[serde(default)]
    pub margin_so_level: f64,
    pub positions: Vec<Position>,
}

#[derive(Debug, Serialize, Deserialize, Clone, Default, sqlx::FromRow)]
pub struct User {
    pub id: i32,
    pub username: String,
    pub role: String,
}

#[derive(Debug, Serialize, Deserialize, Clone, Default, sqlx::FromRow)]
pub struct UserInternal {
    pub id: i32,
    pub username: String,
    pub password_hash: String,
    pub role: String,
}

#[derive(Debug, Serialize, Deserialize, Clone, Default, sqlx::FromRow)]


pub struct AccountRecord {
    pub mt4_account: i64, // Renamed from mt4_account_number to match DB/JSON naming convention if desired, but let's keep consistency with DB
    pub broker: String, // Renamed from broker_name
    pub account_name: Option<String>,
}

#[derive(Debug, Serialize, Deserialize, Clone, Default, sqlx::FromRow)]
pub struct UserAccount {
    pub user_id: i32,
    pub mt4_account: i64,
    pub broker: String,
    pub account_name: Option<String>,
    pub permission: String,
    pub created_at: i64,
}

#[derive(Debug, Deserialize)]
pub struct BindAccountRequest {
    pub mt4_account: i64,
    pub broker: String,
    pub account_name: Option<String>,
}

#[derive(Debug, Serialize, Deserialize, Clone, Default, sqlx::FromRow)]
pub struct AccountHistory {
    pub timestamp: i64,
    pub balance: f64,
    pub equity: f64,
    pub mt4_account: i64,
    pub broker: String,
}

#[derive(Debug, Serialize, Deserialize, Clone, Default)]
pub struct LogEntry {
    pub timestamp: i64,
    pub level: String,
    pub message: String,
    pub mt4_account: i64,
    pub broker: String,
}

#[derive(Debug, Serialize, Deserialize, Clone, Default, sqlx::FromRow)]
pub struct TradeHistory {
    pub ticket: i32,
    pub symbol: String,
    pub open_time: i64,
    pub close_time: i64,
    pub open_price: f64,
    pub close_price: f64,
    pub lots: f64,
    pub profit: f64,
    pub trade_type: String, // "BUY" or "SELL"
    pub magic: i32,
    #[serde(default)]
    pub mae: f64,
    #[serde(default)]
    pub mfe: f64,
    #[serde(default)]
    pub signal_context: Option<String>,
    #[serde(default)]
    pub mt4_account: i64,
    #[serde(default)]
    pub broker: String,
}

#[derive(Debug, Serialize, Deserialize, Clone, Default, sqlx::FromRow)]
pub struct Candle {
    pub time: i64,
    pub open: f64,
    pub high: f64,
    pub low: f64,
    pub close: f64,
}

#[derive(Debug, Serialize, Deserialize, Clone, Default)]
pub struct Command {
    pub id: String,
    pub action: String, // OPEN_BUY, OPEN_SELL, CLOSE_ALL
    pub symbol: String,
    pub lots: f64,
    pub status: String, // PENDING, SENT
    pub timestamp: i64,
    pub mt4_account: i64,
    pub broker: String,
}

#[derive(Debug, Serialize, Deserialize, Clone, Default)]
pub struct RiskControlState {
    pub mt4_account: i64,
    pub block_buy: bool,
    pub block_sell: bool,
    pub block_all: bool,
    pub risk_level: String, // "SAFE" | "WARNING" | "CRITICAL"
    pub updated_at: i64,
}
