use serde::{Deserialize, Serialize};
use crate::data_models::Position;

/// EA 警戒指标汇总结构
#[derive(Debug, Serialize, Deserialize, Clone, Default)]
pub struct EAAlertMetrics {
    // 核心指标
    pub liquidation_price: f64,       // 强平价格
    pub survival_distance: f64,       // 生存距离 (USD)
    pub risk_score: f64,              // 综合风险指数 (0-100)
    
    // 评分分解
    pub layer_score: f64,             // 层级负荷分数
    pub drawdown_score: f64,          // 回撤深度分数
    pub drawdown: f64,                // 实际回撤比例 (%)
    pub distance_score: f64,          // 生存空间分数
    pub velocity_score: f64,          // 速度分数
    
    // 动态指标
    pub velocity_m1: f64,             // M1 速度 ($/分钟)
    pub rvol: f64,                    // 相对成交量
    
    // 进场指纹
    pub rsi_14: f64,                  // RSI(14)
    pub rsi_signal: String,           // "BUY" / "SELL" / "NEUTRAL"
    
    // 触发器
    pub exit_trigger: String,         // 出场触发器类型
    pub trigger_reason: String,       // 触发原因描述
    
    // 辅助状态
    pub is_velocity_warning: bool,
    pub is_rvol_warning: bool,
    pub symbol: String,
    pub timestamp: i64,
}

/// 指标计算输入参数
pub struct MetricsInput {
    pub equity: f64,
    pub margin: f64,
    pub margin_so_level: f64,
    pub positions: Vec<Position>,
    pub symbol: String,
    pub current_bid: f64,
    pub current_ask: f64,
    pub balance: f64,
    pub contract_size: f64, // Added
}
