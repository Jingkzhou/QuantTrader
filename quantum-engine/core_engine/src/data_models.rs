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
    pub profit: f64,
}

#[derive(Debug, Serialize, Deserialize, Clone, Default)]
pub struct AccountStatus {
    pub balance: f64,
    pub equity: f64,
    pub margin: f64,
    pub free_margin: f64,
    pub floating_profit: f64,
    pub positions: Vec<Position>,
}

#[derive(Debug, Serialize, Deserialize, Clone, Default)]
pub struct LogEntry {
    pub timestamp: u64,
    pub level: String,
    pub message: String,
}
