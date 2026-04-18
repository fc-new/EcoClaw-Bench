#!/bin/bash
# 启动 OpenClaw Gateway（无代理模式）
# 用于解决 DMXAPI 连接问题

set -e

echo "Stopping existing gateway..."
pkill openclaw-gateway 2>/dev/null || true
sleep 1

echo "Starting gateway without proxy..."
env -u http_proxy -u https_proxy openclaw gateway --force >/tmp/openclaw_gateway.log 2>&1 &
GATEWAY_PID=$!

echo "Waiting for gateway to be ready..."
for i in {1..10}; do
    if openclaw gateway health >/dev/null 2>&1; then
        echo "✅ Gateway is ready (PID: $GATEWAY_PID)"
        openclaw gateway health
        exit 0
    fi
    sleep 1
done

echo "❌ Gateway failed to start"
exit 1
