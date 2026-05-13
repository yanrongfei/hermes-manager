# Hermes Server Docker 部署计划

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans to implement.

**Goal:** 为 hermes-server 添加 Docker 部署支持

**Architecture:** 将 hermes-server 打包为 Docker 容器，支持本地开发和生产部署

---

## Task 1: 创建 Dockerfile

**Files:**
- Create: `hermes-server/Dockerfile`

- [ ] **Step 1: 创建 Dockerfile**

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app/ ./app/

# Create data directory for SQLite
RUN mkdir -p /app/data

# Environment variables
ENV PYTHONUNBUFFERED=1
ENV DATABASE_URL=sqlite+aiosqlite:///./data/hermes.db

# Expose port
EXPOSE 8000

# Run the application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

- [ ] **Step 2: 创建 .dockerignore**

```dockerignore
__pycache__
*.pyc
*.pyo
*.pyd
.Python
*.so
*.egg
*.egg-info
dist
build
.pytest_cache
.coverage
htmlcov
.git
.gitignore
*.md
tests/
```

- [ ] **Step 3: 提交**

```bash
git add hermes-server/Dockerfile hermes-server/.dockerignore
git commit -m "feat(server): add Dockerfile for container deployment"
```

---

## Task 2: 创建 docker-compose.yml

**Files:**
- Create: `docker-compose.yml` (在项目根目录)

- [ ] **Step 1: 创建 docker-compose.yml**

```yaml
version: '3.8'

services:
  hermes-server:
    build:
      context: ./hermes-server
      dockerfile: Dockerfile
    container_name: hermes-server
    ports:
      - "8000:8000"
    volumes:
      - hermes-data:/app/data
    environment:
      - JWT_SECRET_KEY=${JWT_SECRET_KEY:-your-secret-key-change-in-production}
      - DEBUG=false
    restart: unless-stopped

volumes:
  hermes-data:
```

- [ ] **Step 2: 创建 .env.example**

```env
# JWT Configuration
JWT_SECRET_KEY=your-super-secret-key-change-in-production

# Server Configuration
DEBUG=false
```

- [ ] **Step 3: 提交**

```bash
git add docker-compose.yml .env.example
git commit -m "feat(server): add docker-compose for deployment"
```

---

## Task 3: 添加健康检查

**Modify:**
- Modify: `hermes-server/app/main.py`

- [ ] **Step 1: 添加 liveness 和 readiness probes**

在 docker-compose.yml 中添加健康检查：

```yaml
services:
  hermes-server:
    # ... existing config ...
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
```

---

## Task 4: 本地开发优化 (可选)

**Files:**
- Create: `hermes-server/docker-compose.dev.yml`

- [ ] **Step 1: 创建开发用 compose**

```yaml
version: '3.8'

services:
  hermes-server:
    build:
      context: ./hermes-server
      dockerfile: Dockerfile.dev
    container_name: hermes-server-dev
    ports:
      - "8000:8000"
    volumes:
      - ./hermes-server:/app
    environment:
      - DEBUG=true
    command: uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

- [ ] **Step 2: 创建 Dockerfile.dev**

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Install hot reload
RUN pip install --no-cache-dir h11

# Copy application code
COPY app/ ./app/

ENV PYTHONUNBUFFERED=1
ENV DATABASE_URL=sqlite+aiosqlite:///./data/hermes.db

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
```

---

## 部署检查清单

- [ ] Task 1: Dockerfile
- [ ] Task 2: docker-compose.yml
- [ ] Task 3: 健康检查
- [ ] Task 4: 开发环境配置（可选）

---

## 使用方法

**开发环境：**
```bash
docker-compose -f docker-compose.dev.yml up --build
```

**生产环境：**
```bash
cp .env.example .env
# 编辑 .env 设置 JWT_SECRET_KEY
docker-compose up --build -d
```

**停止服务：**
```bash
docker-compose down
```

---

**Plan saved to:** `docs/superpowers/plans/2026-05-13-hermes-server-docker-deployment.md`
