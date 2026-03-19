#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTRACTS_DIR="$ROOT_DIR/contracts"
WEB_DIR="$ROOT_DIR/apps/web"

RPC_URL="http://127.0.0.1:8545"
CHAIN_ID="31337"
PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

DEPLOY_SCRIPT="script/DeployPolkaQuest.s.sol:DeployPolkaQuest"
BROADCAST_JSON="$CONTRACTS_DIR/broadcast/DeployPolkaQuest.s.sol/$CHAIN_ID/run-latest.json"
ENV_FILE="$WEB_DIR/.env.local"
ANVIL_LOG="$ROOT_DIR/.anvil.log"

echo "[1/6] 检查目录..."
[ -d "$CONTRACTS_DIR" ] || { echo "缺少目录: $CONTRACTS_DIR"; exit 1; }
[ -d "$WEB_DIR" ] || { echo "缺少目录: $WEB_DIR"; exit 1; }
[ -f "$CONTRACTS_DIR/script/DeployPolkaQuest.s.sol" ] || { echo "缺少部署脚本: $CONTRACTS_DIR/script/DeployPolkaQuest.s.sol"; exit 1; }

echo "[2/6] 检查 Anvil..."
if ! cast block-number --rpc-url "$RPC_URL" >/dev/null 2>&1; then
  echo "Anvil 未启动，正在后台启动..."
  nohup anvil > "$ANVIL_LOG" 2>&1 &
  sleep 2
fi

cast block-number --rpc-url "$RPC_URL" >/dev/null 2>&1 || {
  echo "无法连接到 Anvil: $RPC_URL"
  exit 1
}

echo "[3/6] 部署合约..."
cd "$CONTRACTS_DIR"
forge script "$DEPLOY_SCRIPT" \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --broadcast

[ -f "$BROADCAST_JSON" ] || {
  echo "未找到广播结果文件: $BROADCAST_JSON"
  exit 1
}

echo "[4/6] 读取部署地址..."
CONTRACT_ADDRESS="$(python3 - <<PY
import json
with open("$BROADCAST_JSON", "r") as f:
    data = json.load(f)

addr = None
for tx in reversed(data.get("transactions", [])):
    if tx.get("contractName") == "PolkaQuest" and tx.get("contractAddress"):
        addr = tx["contractAddress"]
        break

if not addr:
    raise SystemExit(1)

print(addr)
PY
)"

[ -n "$CONTRACT_ADDRESS" ] || {
  echo "无法从广播文件中解析部署地址"
  exit 1
}

echo "[5/6] 验证链上代码..."
CODE="$(cast code "$CONTRACT_ADDRESS" --rpc-url "$RPC_URL")"
[ "$CODE" != "0x" ] || {
  echo "部署地址上没有代码: $CONTRACT_ADDRESS"
  exit 1
}

echo "写入前端环境变量..."
mkdir -p "$WEB_DIR"
if [ -f "$ENV_FILE" ]; then
  grep -v '^NEXT_PUBLIC_CONTRACT_ADDRESS=' "$ENV_FILE" > "$ENV_FILE.tmp" || true
  mv "$ENV_FILE.tmp" "$ENV_FILE"
fi
echo "NEXT_PUBLIC_CONTRACT_ADDRESS=$CONTRACT_ADDRESS" >> "$ENV_FILE"

echo "[6/6] 完成"
echo "CONTRACT_ADDRESS=$CONTRACT_ADDRESS"
echo "已写入: $ENV_FILE"
echo
echo "下一步："
echo "  cd \"$WEB_DIR\" && npm run dev"