# QuantumEngine Monorepo

This monorepo hosts the Rust execution layer and Python intelligence layer,
coordinated by Redis, a message bus, and TimescaleDB.

## 项目描述
QuantumEngine 是一套控制面与数据面分离的量化交易系统：
- Rust 负责执行层（私钥、下单、硬风控），强调稳定与低延迟。
- Python 负责智能层（数据分析、模型推理、参数生成），强调迭代与扩展。
- Redis 用于共享状态与策略参数热更新。
- TimescaleDB 持久化行情与交易日志，供盘后训练与回测。

## Architecture (Control Plane vs Data Plane)
- Rust: execution, private keys, hard risk checks
- Python: analytics, models, parameter generation
- Redis: shared state and parameter updates
- TimescaleDB: tick data and trading logs

## Directory Layout
- `core_engine/`: Rust execution engine
- `ai_brain/`: Python AI control plane
- `deploy/`: Dockerfiles and helper scripts

## 项目需求
### 功能需求
- 控制面与数据面分离：Rust 执行层只负责下单、私钥管理与硬风控；Python 智能层负责分析与参数生成。
- 行情接入：Rust 通过交易所 WebSocket 获取行情，具备断线重连与心跳保活能力，并通过消息总线（ZeroMQ/NATS）广播。
- 下单通道：Rust 通过 REST 接口签名下单，具备防抖与重试逻辑。
- 风控防火墙：下单前必须经过 V4 风控检查（熔断、单日止损、技术性断裂）。
- 状态共享：Python 把策略参数写入 Redis；Rust 每 100ms（或更短）读取并热更新。
- 数据持久化：Rust 异步写入 Tick 与交易日志到 TimescaleDB，供 Python 训练/回测。
- AI 推理：Python 读取历史与外部信息，生成参数（如 grid_spacing、risk_mode），写回 Redis。

### 非功能需求
- 稳定性：断线自恢复、崩溃可复用、服务独立重启。
- 低延迟：行情解析与下单路径尽量减少内存拷贝与阻塞。
- 可观测性：日志可追踪，Grafana 可视化关键指标。
- 安全性：密钥与数据库连接信息仅通过 `.env` 注入，不写入代码。

## 使用方法
### 前置依赖
- Docker + Docker Compose
- Rust toolchain (cargo)
- Python 3.10+ (建议搭配 Poetry)

### 启动基础设施
```bash
cd quantum-engine
docker-compose up -d
```

### 一键启动
```bash
cd quantum-engine
./deploy/scripts/start_all.sh
```

### 运行 Rust 执行层
```bash
cd core_engine
cargo build
cargo run
```

### 运行 Python 智能层
```bash
cd ai_brain
python -m venv venv
source venv/bin/activate
pip install poetry
poetry install
python src/main.py
```

### 环境变量
基础配置在 `.env` 中，默认包含 Redis 与 TimescaleDB 的本地连接信息。
生产环境请替换为安全凭据与私有网络地址。

## Quick Start
- Start infrastructure: `docker-compose up -d`
- Build Rust: `cd core_engine && cargo build`
- Run Python: `cd ai_brain && python src/main.py`

## Notes
- The Rust and Python modules are placeholders to be implemented.
- Update `.env` for production credentials.
