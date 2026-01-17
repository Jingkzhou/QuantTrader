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
