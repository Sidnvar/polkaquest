# 🚀 PolkaQuest

PolkaQuest 是一个 Web3 Reward Campaign dApp，用户完成链下任务后，通过后端签名的 EIP-712 claim，在链上领取 ERC20 奖励。

---

## 🧠 项目简介

PolkaQuest 将“任务验证”与“奖励发放”解耦：

- 🧾 后端：判断用户是否有资格领取奖励，并生成签名
- 🔐 合约：验证签名并发放 ERC20 奖励

核心机制：**EIP-712 签名 + 链上验证**

---

## 🔄 Claim 流程

1. 用户完成链下任务
2. 前端请求 `/claim`
3. 后端校验资格并生成签名
4. 返回 `claim + signature`
5. 前端调用：

```ts
claimReward(claim, signature)
```

6. 合约验证并发放奖励

---

## 🧱 项目结构

```text
polkaquest/
├── contract/     # Solidity + Foundry
├── backend/      # Express + ethers
├── frontend/     # Next.js + ethers v6
└── README.md
```

---

## ⛓️ 智能合约

### 功能

- `createCampaign`
- `fundCampaign`
- `setCampaignActive`
- `claimReward`

### Claim 结构

```solidity
struct Claim {
    address user;
    uint256 campaignId;
    uint256 amount;
    uint256 nonce;
    uint256 deadline;
}
```

### 安全机制

- EIP-712 签名验证
- 防重复领取：`hasClaimed`
- 防重放：`usedClaims`
- 防过期：`deadline`
- 奖励余额检查

---

## 🖥️ 后端 API

### 技术栈

- Express
- ethers
- EIP-712 签名

### 接口

#### 获取活动
`GET /getCampaign?campaignId=0`

#### 剩余奖励
`GET /getRemainingReward?campaignId=0`

#### 是否已领取
`GET /hasUserClaimed?campaignId=0&user=0x...`

#### 生成 claim（核心）
`POST /claim`

请求：

```json
{
  "user": "0xUserAddress",
  "campaignId": "0"
}
```

返回：

```json
{
  "ok": true,
  "data": {
    "claim": { "...": "..." },
    "signature": "0x..."
  }
}
```

### 后端校验逻辑

签名前会检查：

- 活动是否激活
- 用户是否已领取
- 奖励是否充足

### 错误格式

```json
{
  "ok": false,
  "message": "User has already claimed"
}
```

---

## 🌐 前端

### 技术栈

- Next.js
- ethers v6
- MetaMask

### 功能

- 钱包连接
- 获取活动
- 请求 claim
- 调用合约领取奖励
- 交易状态管理
- 错误提示

### Claim 流程

```text
1. 请求 /claim
2. claimReward(claim, signature)
3. 等待确认
4. 刷新数据
```

### 状态阶段

- Requesting claim signature...
- Submitting transaction...
- Waiting for confirmation...

---

## ⚙️ 环境变量

### Frontend `.env.local`

```env
NEXT_PUBLIC_API_URL=http://localhost:3001
NEXT_PUBLIC_CONTRACT_ADDRESS=0xYourContractAddress
NEXT_PUBLIC_CHAIN_ID=31337
```

### Backend `.env`

```env
PORT=3001
RPC_URL=http://127.0.0.1:8545
PRIVATE_KEY=0xYourAnvilPrivateKey
CONTRACT_ADDRESS=0xYourContractAddress
CHAIN_ID=31337
TOKEN_ADDRESS=0xYourTokenAddress
```

### Contract / Foundry `.env`

```env
PRIVATE_KEY=0xYourAnvilPrivateKey
RPC_URL=http://127.0.0.1:8545
ETHERSCAN_API_KEY=dummy
```

---

## 🧪 本地开发环境搭建

下面是一套推荐的本地联调流程：**Anvil + Foundry + Express + Next.js**

### 1. 安装依赖

确保本地已安装：

- Node.js 18+
- npm 或 pnpm
- Foundry
- MetaMask

安装 Foundry：

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

确认版本：

```bash
forge --version
anvil --version
```

---

## 🔗 启动本地链（Anvil）

启动 Anvil：

```bash
anvil
```

默认信息：

- RPC URL: `http://127.0.0.1:8545`
- Chain ID: `31337`

Anvil 启动后会输出一组测试账户和私钥，你需要：

1. 选一个账户作为部署者 / 后端 signer
2. 复制它的私钥到 `.env`
3. 把该账户导入 MetaMask 方便前端测试

### MetaMask 添加本地网络

手动添加网络：

- Network Name: `Anvil Local`
- RPC URL: `http://127.0.0.1:8545`
- Chain ID: `31337`
- Currency Symbol: `ETH`

然后把 Anvil 给出的测试私钥导入 MetaMask。

---

## 📦 合约本地部署

进入合约目录：

```bash
cd contract
forge install
```

编译：

```bash
forge build
```

测试：

```bash
forge test
```

如果你有部署脚本，例如：

```bash
script/Deploy.s.sol
```

可以这样部署到本地 Anvil：

```bash
forge script script/Deploy.s.sol:DeployScript   --rpc-url http://127.0.0.1:8545   --private-key $PRIVATE_KEY   --broadcast
```

如果你的项目里先部署 ERC20，再部署 Reward Campaign 合约，顺序通常是：

1. 部署 ERC20 测试代币
2. 部署 PolkaQuest / RewardCampaign 合约
3. 将代币地址传给 RewardCampaign
4. 创建 campaign
5. 给 campaign 注入奖励资金

部署完成后，记下：

- `TOKEN_ADDRESS`
- `CONTRACT_ADDRESS`

并同步更新到前后端环境变量中。

---

## 🪙 本地准备测试数据

一个完整本地流程通常需要：

### 1. 创建 campaign

由管理员账户调用：

- `createCampaign`

### 2. 给 campaign 注资

先确保管理员持有 ERC20 测试代币，然后：

- ERC20 `approve(CONTRACT_ADDRESS, amount)`
- RewardCampaign `fundCampaign(campaignId, amount)`

### 3. 激活活动

调用：

- `setCampaignActive(campaignId, true)`

这样前端才能正常 claim。

---

## 🖥️ 启动后端

进入后端目录：

```bash
cd backend
npm install
npm run dev
```

确保后端 `.env` 至少配置好：

- `RPC_URL=http://127.0.0.1:8545`
- `PRIVATE_KEY=Anvil 测试私钥`
- `CONTRACT_ADDRESS=本地部署后的合约地址`
- `CHAIN_ID=31337`

后端职责：

- 查询链上 campaign
- 校验用户是否可领取
- 生成并签名 EIP-712 claim

---

## 🌐 启动前端

进入前端目录：

```bash
cd frontend
npm install
npm run dev
```

确保前端 `.env.local` 至少配置好：

- `NEXT_PUBLIC_API_URL=http://localhost:3001`
- `NEXT_PUBLIC_CONTRACT_ADDRESS=本地部署后的合约地址`
- `NEXT_PUBLIC_CHAIN_ID=31337`

然后：

1. 打开浏览器访问前端页面
2. 连接 MetaMask
3. 切换到 Anvil Local 网络
4. 使用导入的测试账户进行 claim 测试

---

## ✅ 推荐本地联调顺序

推荐按下面顺序启动：

```text
1. anvil
2. forge script 部署合约
3. backend
4. frontend
5. MetaMask 切到 Anvil 网络
6. 测试 create / fund / activate / claim
```

---

## 🧪 本地联调检查清单

如果 claim 流程不通，优先检查：

### 1. 网络是否一致
- MetaMask 是否切到 `31337`
- 前端 `NEXT_PUBLIC_CHAIN_ID` 是否是 `31337`
- 后端 `CHAIN_ID` 是否是 `31337`

### 2. 合约地址是否一致
- 前端 `NEXT_PUBLIC_CONTRACT_ADDRESS`
- 后端 `CONTRACT_ADDRESS`
- EIP-712 domain 里的 `verifyingContract`

必须全部一致。

### 3. signer 私钥是否正确
后端 `PRIVATE_KEY` 必须是你希望用于签名的账户私钥。

### 4. campaign 是否可 claim
- 已创建
- 已注资
- 已激活
- 奖励余额足够
- 用户未领取过

### 5. EIP-712 domain 是否一致
前后端与合约必须保证以下参数一致：

- `name: PolkaQuest`
- `version: 1`
- `chainId: 31337`
- `verifyingContract: CONTRACT_ADDRESS`

---

## 🧪 常用本地命令

### 启动本地链
```bash
anvil
```

### 编译合约
```bash
forge build
```

### 运行测试
```bash
forge test -vv
```

### 部署脚本
```bash
forge script script/Deploy.s.sol:DeployScript   --rpc-url http://127.0.0.1:8545   --private-key $PRIVATE_KEY   --broadcast
```

### 启动后端
```bash
cd backend && npm run dev
```

### 启动前端
```bash
cd frontend && npm run dev
```

---

## 🔐 安全说明

- 后端私钥仅用于签名，生产环境必须妥善保管
- 合约为最终校验层
- `deadline` 防止长期有效签名
- `nonce` 防止重放攻击
- 本地开发可使用 Anvil 测试私钥，生产环境绝不能这样做

---

## 🚧 当前开发重点

- claim 流程完善
- 前端状态管理
- 错误处理统一
- 数据刷新逻辑
- 本地联调体验优化

---

## 🔮 后续计划

- claim 历史（事件索引）
- 管理后台
- 多任务系统
- nonce 优化
- 多链支持

---

## 📄 License

MIT
