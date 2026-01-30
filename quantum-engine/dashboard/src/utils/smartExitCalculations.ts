/**
 * Smart Exit Calculations - 智能割肉算法模块
 * 
 * 基于黄金（XAUUSD）量化交易特性的多维风控计算
 * 包含：价格动量、相对成交量、综合评分、割肉触发
 */

import type { Position } from '../types';

// ==================== 类型定义 ====================

export type ExitTrigger = 'NONE' | 'LAYER_LOCK' | 'TACTICAL_EXIT' | 'FORCE_EXIT';

export interface SmartExitMetrics {
    // 基础指标
    survivalDistance: number;      // 生存距离 (USD)
    liquidationPrice: number;      // 死线价格

    // 动态指标
    velocityM1: number;            // 1分钟价格动量 (USD)
    rvol: number;                  // 相对成交量因子

    // 综合评分
    riskScore: number;             // 0-100 综合风险评分
    distanceScore: number;         // 距离分 (40%)
    velocityScore: number;         // 速度分 (30%)
    layerScore: number;            // 层级分 (30%)

    // 触发状态
    exitTrigger: ExitTrigger;
    triggerReason: string;

    // 辅助信息
    isVelocityWarning: boolean;    // Velocity 接近阈值
    isRvolWarning: boolean;        // 放量下跌警告
}

export interface VelocityData {
    symbol: string;
    timestamp: number;
    velocityM1: number;
    price1mAgo: number;
    avgTickVolume24h: number;
    currentTickVolume: number;
    rvol: number;
}

// ==================== 常量配置 ====================

// 阈值配置（基于历史数据分析）
export const SMART_EXIT_CONFIG = {
    // Velocity 阈值
    VELOCITY_WARNING_THRESHOLD: 2.0,      // $2.0 - 接近警告
    VELOCITY_CRITICAL_THRESHOLD: 3.0,     // $3.0 - 强制阻断加仓
    VELOCITY_EXTREME_THRESHOLD: 5.0,      // $5.0 - 极端行情

    // RVOL 阈值
    RVOL_NORMAL: 1.0,                     // 正常成交量
    RVOL_ELEVATED: 1.5,                   // 轻微放量
    RVOL_WARNING: 2.0,                    // 放量警告
    RVOL_CRITICAL: 2.5,                   // 放量下跌确认

    // 评分阈值
    SCORE_LAYER_LOCK: 60,                 // 层级锁死阈值
    SCORE_TACTICAL_EXIT: 80,              // 战术熔断阈值
    SCORE_FORCE_EXIT: 95,                 // 强制平仓阈值

    // 层级配置
    DEFAULT_MAX_LAYER: 15,                // 默认最大层数

    // MAE 阈值（基于数据分析，高风险亏损单的平均 MAE 为 -185 点）
    MAE_WARNING_PIPS: 100,                // 浮亏警告阈值（点数）
    MAE_CRITICAL_PIPS: 150,               // 危险浮亏阈值
};

// ==================== 核心计算函数 ====================

/**
 * 1. 价格动量计算 (1分钟)
 * 公式: V_m1 = Current Price - Price (1 min ago)
 * 
 * @param currentPrice 当前价格
 * @param price1mAgo 1分钟前价格
 * @returns 1分钟动量 (USD)，负值表示下跌
 */
export const calculateVelocityM1 = (currentPrice: number, price1mAgo: number): number => {
    if (!currentPrice || !price1mAgo || price1mAgo <= 0) return 0;
    return currentPrice - price1mAgo;
};

/**
 * 2. 相对成交量因子计算 (RVOL)
 * 公式: RVOL = Current Tick Volume (M1) / Avg Tick Volume (Last 24H)
 * 
 * @param currentVolume 当前 M1 Tick 成交量
 * @param avgVolume24h 过去24小时平均 Tick 成交量
 * @returns RVOL 因子，>1 表示放量
 */
export const calculateRVOL = (currentVolume: number, avgVolume24h: number): number => {
    if (!avgVolume24h || avgVolume24h <= 0) return 1.0; // 无数据默认正常
    if (!currentVolume || currentVolume <= 0) return 0;
    return currentVolume / avgVolume24h;
};

/**
 * 3. 距离评分计算 (40%)
 * 公式: Score = 40 * (1 - dist / (3 * ATR)) when dist < 3*ATR
 * 
 * @param survivalDistance 生存距离 (USD)
 * @param atr 日 ATR
 * @returns 距离分 (0-40)
 */
export const calculateDistanceScore = (survivalDistance: number, atr: number): number => {
    if (!atr || atr <= 0 || survivalDistance === Infinity) return 0;

    const atrBasedDist = survivalDistance / atr;

    // 如果距离 >= 3x ATR，安全，得分为 0
    if (atrBasedDist >= 3) return 0;

    // 线性计算：距离越近，分数越高
    return 40 * (1 - atrBasedDist / 3);
};

/**
 * 4. 速度评分计算 (30%)
 * 公式: Score = 30 * min(1, |velocityM1| / VELOCITY_CRITICAL_THRESHOLD)
 * 
 * @param velocityM1 1分钟动量 (USD)
 * @param dominantDirection 主导方向 ('BUY' | 'SELL' | 'HEDGED')
 * @returns 速度分 (0-30)
 */
export const calculateVelocityScore = (
    velocityM1: number,
    dominantDirection: 'BUY' | 'SELL' | 'HEDGED'
): number => {
    const absVelocity = Math.abs(velocityM1);

    // 评估是否为逆向动量（对持仓不利的方向）
    let isAdverse = false;
    if (dominantDirection === 'BUY' && velocityM1 < 0) isAdverse = true;  // 持多头，价格下跌
    if (dominantDirection === 'SELL' && velocityM1 > 0) isAdverse = true; // 持空头，价格上涨

    // 只有逆向动量才计分
    if (!isAdverse) return 0;

    const ratio = absVelocity / SMART_EXIT_CONFIG.VELOCITY_CRITICAL_THRESHOLD;
    return 30 * Math.min(1, ratio);
};

/**
 * 5. 层级评分计算 (30%)
 * 公式: Score = 30 * (layerCount / maxLayerAllowed)
 * 
 * @param layerCount 当前网格层数（最大单边持仓数）
 * @param maxLayerAllowed 允许的最大层数
 * @returns 层级分 (0-30)
 */
export const calculateLayerScore = (
    layerCount: number,
    maxLayerAllowed: number = SMART_EXIT_CONFIG.DEFAULT_MAX_LAYER
): number => {
    if (maxLayerAllowed <= 0) return 0;
    const ratio = layerCount / maxLayerAllowed;
    return 30 * Math.min(1, ratio);
};

/**
 * 6. 综合风险评分计算
 * 整合三维评分
 */
export const calculateIntegratedRiskScore = (
    survivalDistance: number,
    atr: number,
    velocityM1: number,
    rvol: number,
    positions: Position[],
    maxLayerAllowed: number = SMART_EXIT_CONFIG.DEFAULT_MAX_LAYER
): SmartExitMetrics => {
    // 计算基础信息
    const buyPositions = positions.filter(p => p.side === 'BUY');
    const sellPositions = positions.filter(p => p.side === 'SELL');
    const buyLots = buyPositions.reduce((acc, p) => acc + p.lots, 0);
    const sellLots = sellPositions.reduce((acc, p) => acc + p.lots, 0);
    const netLots = buyLots - sellLots;

    // 确定主导方向
    let dominantDirection: 'BUY' | 'SELL' | 'HEDGED' = 'HEDGED';
    if (netLots > 0.001) dominantDirection = 'BUY';
    else if (netLots < -0.001) dominantDirection = 'SELL';

    // 计算层数（最大单边持仓数）
    const layerCount = Math.max(buyPositions.length, sellPositions.length);

    // 计算三维评分
    const distanceScore = calculateDistanceScore(survivalDistance, atr);
    const velocityScore = calculateVelocityScore(velocityM1, dominantDirection);
    const layerScore = calculateLayerScore(layerCount, maxLayerAllowed);

    // 综合评分
    let riskScore = distanceScore + velocityScore + layerScore;

    // RVOL 加速器：放量时加重评分
    if (rvol >= SMART_EXIT_CONFIG.RVOL_CRITICAL) {
        // 放量下跌确认，评分 * 1.2
        riskScore = Math.min(100, riskScore * 1.2);
    } else if (rvol >= SMART_EXIT_CONFIG.RVOL_WARNING) {
        // 轻微放量，评分 * 1.1
        riskScore = Math.min(100, riskScore * 1.1);
    }

    // 确定触发状态
    const { exitTrigger, triggerReason } = determineExitTrigger(
        riskScore,
        velocityM1,
        rvol,
        dominantDirection
    );

    // 警告状态
    const isVelocityWarning = Math.abs(velocityM1) >= SMART_EXIT_CONFIG.VELOCITY_WARNING_THRESHOLD;
    const isRvolWarning = rvol >= SMART_EXIT_CONFIG.RVOL_WARNING;

    return {
        survivalDistance,
        liquidationPrice: 0, // 由调用方填充
        velocityM1,
        rvol,
        riskScore: Math.round(riskScore * 10) / 10,
        distanceScore: Math.round(distanceScore * 10) / 10,
        velocityScore: Math.round(velocityScore * 10) / 10,
        layerScore: Math.round(layerScore * 10) / 10,
        exitTrigger,
        triggerReason,
        isVelocityWarning,
        isRvolWarning
    };
};

/**
 * 7. 智能割肉触发判定
 */
export const determineExitTrigger = (
    score: number,
    velocityM1: number,
    rvol: number,
    dominantDirection: 'BUY' | 'SELL' | 'HEDGED'
): { exitTrigger: ExitTrigger; triggerReason: string } => {

    // 判断是否为逆向动量
    const isAdverseVelocity = (
        (dominantDirection === 'BUY' && velocityM1 < -SMART_EXIT_CONFIG.VELOCITY_CRITICAL_THRESHOLD) ||
        (dominantDirection === 'SELL' && velocityM1 > SMART_EXIT_CONFIG.VELOCITY_CRITICAL_THRESHOLD)
    );

    // FORCE_EXIT: 极端情况
    if (score >= SMART_EXIT_CONFIG.SCORE_FORCE_EXIT) {
        return {
            exitTrigger: 'FORCE_EXIT',
            triggerReason: '🚨 极端风险，强制全平建议'
        };
    }

    // TACTICAL_EXIT: 战术熔断
    if (score >= SMART_EXIT_CONFIG.SCORE_TACTICAL_EXIT) {
        if (isAdverseVelocity && rvol >= SMART_EXIT_CONFIG.RVOL_WARNING) {
            return {
                exitTrigger: 'TACTICAL_EXIT',
                triggerReason: '⚠️ 放量逆势，建议即刻减仓'
            };
        }
        return {
            exitTrigger: 'TACTICAL_EXIT',
            triggerReason: '⛔️ 综合风险过高，禁止加仓'
        };
    }

    // LAYER_LOCK: 层级锁死
    if (score >= SMART_EXIT_CONFIG.SCORE_LAYER_LOCK) {
        return {
            exitTrigger: 'LAYER_LOCK',
            triggerReason: '🔒 禁止高倍订单，尝试断尾求生'
        };
    }

    // Velocity 单独触发（即使评分不高）
    if (Math.abs(velocityM1) >= SMART_EXIT_CONFIG.VELOCITY_EXTREME_THRESHOLD) {
        return {
            exitTrigger: 'LAYER_LOCK',
            triggerReason: '⚡ 极端动量，禁止加仓'
        };
    }

    // NONE: 正常状态
    return {
        exitTrigger: 'NONE',
        triggerReason: '✅ 策略正常运行'
    };
};

/**
 * 8. 辅助函数：计算预估生存时间
 * 基于 ATR 估算账户能撑多久
 * 
 * @param survivalDistance 生存距离 (USD)
 * @param atrD1 日 ATR
 * @param velocityM1 当前动量（用于加速估算）
 * @returns 生存时间字符串
 */
export const estimateSurvivalTime = (
    survivalDistance: number,
    atrD1: number,
    velocityM1: number = 0
): string => {
    if (!atrD1 || atrD1 <= 0 || survivalDistance === Infinity) return '> 24h';

    // 基础估算：ATR 每小时约为 D1 ATR / 24
    let atrPerHour = atrD1 / 24;

    // 如果当前有逆向动量，加速衰减
    if (Math.abs(velocityM1) > SMART_EXIT_CONFIG.VELOCITY_WARNING_THRESHOLD) {
        // 动量越大，加速越快
        const accelerationFactor = 1 + Math.abs(velocityM1) / atrD1;
        atrPerHour *= accelerationFactor;
    }

    // 保守估算：假设价格以 2x 每小时 ATR 的速度移动
    const hours = survivalDistance / (atrPerHour * 2);

    if (hours > 24) return '> 24h';
    if (hours < 0.5) return '< 30m';
    if (hours < 1) return '< 1h';
    return `~${hours.toFixed(1)}h`;
};

/**
 * 9. 辅助函数：生成风控状态颜色
 */
export const getRiskScoreColor = (score: number): string => {
    if (score >= SMART_EXIT_CONFIG.SCORE_TACTICAL_EXIT) return 'text-rose-500';
    if (score >= SMART_EXIT_CONFIG.SCORE_LAYER_LOCK) return 'text-amber-500';
    if (score >= 40) return 'text-yellow-500';
    return 'text-emerald-500';
};

export const getExitTriggerConfig = (trigger: ExitTrigger) => {
    switch (trigger) {
        case 'FORCE_EXIT':
            return {
                color: 'text-rose-600',
                bgColor: 'bg-rose-500/20',
                borderColor: 'border-rose-500/50',
                icon: '🚨',
                label: 'FORCE EXIT'
            };
        case 'TACTICAL_EXIT':
            return {
                color: 'text-rose-500',
                bgColor: 'bg-rose-500/10',
                borderColor: 'border-rose-500/30',
                icon: '⛔️',
                label: 'TACTICAL'
            };
        case 'LAYER_LOCK':
            return {
                color: 'text-amber-500',
                bgColor: 'bg-amber-500/10',
                borderColor: 'border-amber-500/30',
                icon: '🔒',
                label: 'LAYER LOCK'
            };
        default:
            return {
                color: 'text-emerald-500',
                bgColor: 'bg-emerald-500/10',
                borderColor: 'border-emerald-500/20',
                icon: '✅',
                label: 'NORMAL'
            };
    }
};
