#!/usr/bin/env python
"""
Hermes Server 启动脚本
用于在 PyCharm 或其他 IDE 中直接运行
"""
import subprocess
import sys
import time
import uvicorn


def kill_process_on_port(port: int):
    """查找并终止占用指定端口的进程"""
    try:
        # 使用 lsof 查找占用端口的进程
        result = subprocess.run(
            ["lsof", "-ti", f":{port}"],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        if result.returncode == 0 and result.stdout.strip():
            pids = result.stdout.strip().split('\n')
            print(f"检测到端口 {port} 被以下进程占用: {', '.join(pids)}")
            
            # 终止所有占用端口的进程
            for pid in pids:
                pid = pid.strip()
                if pid:
                    print(f"正在终止进程 {pid}...")
                    subprocess.run(["kill", "-9", pid], timeout=5)
                    print(f"进程 {pid} 已终止")
            
            # 等待一小段时间确保端口释放
            time.sleep(1)
            print(f"端口 {port} 已释放")
            return True
        else:
            print(f"端口 {port} 未被占用")
            return False
    except subprocess.TimeoutExpired:
        print("警告: 检查端口超时")
        return False
    except Exception as e:
        print(f"检查端口时出错: {e}")
        return False


if __name__ == "__main__":
    PORT = 3002
    
    # 检查并清理端口
    kill_process_on_port(PORT)
    
    # 启动服务
    print(f"\n正在启动 Hermes Server on port {PORT}...")
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=PORT,
        reload=True,
        log_level="info"
    )
