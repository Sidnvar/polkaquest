# 🚀 PolkaQuest

PolkaQuest 是一个 Web3 Reward Campaign dApp，用户完成链下任务后，通过后端签名的 EIP-712 claim，在链上领取 ERC20 奖励。

---

## 🧠 项目简介

PolkaQuest 将"任务验证"与"奖励发放"解耦：

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

```
polkaquest/
├── contracts/         # Solidity + Foundry
├── apps/
│   ├── api/          # Express + ethers 后端
│   └── web/          # Next.js + ethers v6 前端
├── packages/         # 共享包
├── scripts/          # 部署脚本
└── prisma/           # 数据库（预留）
```

---

## ⛓️ 智能合约

### 功能

- `createCampaign` - 创建活动
- `fundCampaign` - 资助活动
- `setCampaignActive` - 激活/停用活动
- `claimReward` - 领取奖励

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

---

### 接口

#### 管理端点

- `POST /admin/createCampaign` - 创建活动
- `POST /admin/fundCampaign` - 资助活动
- `POST /admin/setCampaignActive` - 激活/停用活动
- `GET /admin/campaigns` - 获取所有活动

#### 客户端点

- `GET /campaigns` - 获取活动列表
- `GET /campaign/:id` - 获取单个活动详情
- `POST /claim` - 生成 claim 签名（核心）

#### Claim 请求

```json
{
  "user": "0xUserAddress",
  "campaignId": "0"
}
```

#### Claim 返回

```json
{
  "ok": true,
  "data": {
    "claim": {
      "user": "0x...",
      "campaignId": "0",
      "amount": "1000000000000000000",
      "nonce": "1",
      "deadline": "1234567890"
    },
    "signature": "0x..."
  }
}
```

---

### 后端校验逻辑

签名前会检查：

- 活动是否激活  
- 用户是否已领取  
- 奖励是否充足  

---

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

- Next.js 15  
- ethers v6  
- Tailwind CSS
- TypeScript

---

### 页面

- `/` - 首页
- `/client` - 用户端（查看活动、领取奖励）
- `/admin` - 管理端（创建活动、资助、激活/停用）

---

### 功能

#### 用户端
- 钱包连接（MetaMask）
- 查看活动列表
- 查看活动详情
- 请求 claim 签名
- 调用合约领取奖励
- 交易状态管理
- 错误提示

#### 管理端
- 创建新活动
- 资助活动（新增功能）
- 激活/停用活动
- 查看活动状态

---

### Claim 流程

```ts
1. 用户点击"领取奖励"
2. 前端请求 /claim
3. 后端返回 claim + signature
4. 前端调用 claimReward(claim, signature)
5. 等待交易确认
6. 刷新活动数据
```

---

### 状态阶段

- Requesting claim signature...  
- Submitting transaction...  
- Waiting for confirmation...  
- Success / Error

---

## ⚙️ 环境变量

### Frontend (.env.local)

```env
NEXT_PUBLIC_API_URL=http://localhost:3001
NEXT_PUBLIC_CONTRACT_ADDRESS=0x...
NEXT_PUBLIC_CHAIN_ID=31337
```

---

### Backend (.env)

```env
PORT=3001
RPC_URL=http://127.0.0.1:8545
PRIVATE_KEY=0x...
CONTRACT_ADDRESS=0x...
CHAIN_ID=31337
TOKEN_ADDRESS=0x...
```

---

## 🧪 本地运行

### 1. 启动本地链 + 部署合约

```bash
# 使用开发脚本一键启动
./scripts/dev-up.sh

# 或手动执行
anvil  # 启动本地链
./scripts/dev-deploy.sh  # 部署合约
```

### 2. 启动后端

```bash
cd apps/api
npm install
npm run dev
```

### 3. 启动前端

```bash
cd apps/web
npm install
npm run dev
```

访问：
- 前端：http://localhost:3000
- 后端：http://localhost:3001

---

## 🔐 安全说明

- 后端私钥仅用于签名，不持有资金
- 合约为最终校验层  
- deadline 防止长期有效签名  
- nonce 防止重放攻击
- 用户只能领取一次奖励

---

## 🎯 核心特性

### 已实现
- ✅ EIP-712 签名验证
- ✅ 活动创建与管理
- ✅ 活动资助功能
- ✅ 活动激活/停用
- ✅ 用户领取奖励
- ✅ 防重复领取
- ✅ 管理后台界面
- ✅ 用户端界面

### 开发中
- 🔄 Claim 历史记录
- 🔄 事件索引
- 🔄 数据持久化

---

## 🔮 后续计划

- 多任务系统  
- Nonce 优化  
- 多链支持  
- 活动统计面板
- 用户积分系统

---

## 📦 技术栈

### 智能合约
- Solidity 0.8.28
- Foundry
- OpenZeppelin

### 后端
- Node.js
- Express
- ethers.js v6
- TypeScript

### 前端
- Next.js 15
- React 19
- ethers.js v6
- Tailwind CSS
- TypeScript

---

## 📄 License

MIT

---

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

---

## 📞 联系方式

- GitHub: [Sidnvar/polkaquest](https://github.com/Sidnvar/polkaquest)
