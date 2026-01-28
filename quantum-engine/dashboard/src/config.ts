// 优先从环境变量获取 API 地址（Vite 会在构建时注入 VITE_API_URL）
// 如果没有环境变量，则根据当前域名自动推导，并默认为 3001 端口
const DEFAULT_API_HOST = window.location.hostname;
const DEFAULT_API_PORT = '3001';

export const API_BASE = import.meta.env.VITE_API_URL ||
    `${window.location.protocol}//${DEFAULT_API_HOST}${DEFAULT_API_PORT ? `:${DEFAULT_API_PORT}` : ''}/api/v1`;
