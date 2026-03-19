import cors from "cors";
import dotenv from "dotenv";
import express, { Request, Response, NextFunction } from "express";
import { ethers } from "ethers";
import { CONTRACT_ABI } from "./polkaQuestAbi";
import { createCampaign, fundCampaign, setCampaignStatus } from "./admin";

dotenv.config();

const app = express();
const port = Number(process.env.PORT || 3001);

app.use(cors());
app.use(express.json());

const asyncHandler =
  (fn: (req: Request, res: Response, next: NextFunction) => Promise<any>) =>
  (req: Request, res: Response, next: NextFunction) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };

const rpcUrl = process.env.RPC_URL || "http://127.0.0.1:8545";
const contractAddress = process.env.CONTRACT_ADDRESS;
const signerPrivateKey = process.env.SIGNER_PRIVATE_KEY || '';
const chainId = Number(process.env.CHAIN_ID || 31337);
const signerWallet = new ethers.Wallet(signerPrivateKey);

if (!contractAddress) {
  throw new Error("CONTRACT_ADDRESS is not set");
}

const provider = new ethers.JsonRpcProvider(rpcUrl);

const polkaQuest = new ethers.Contract(
  contractAddress,
  CONTRACT_ABI,
  provider
);

const domain = {
  name: "PolkaQuest",
  version: "1",
  chainId,
  verifyingContract: contractAddress,
};

const CLAIM_TYPEHASH = ethers.keccak256(
  ethers.toUtf8Bytes("Claim(address user,uint256 campaignId,uint256 amount,uint256 nonce,uint256 deadline)")
);

// 1. 添加 CLAIM_TYPEHASH
// const CLAIM_TYPEHASH = ethers.keccak256(
//   ethers.toUtf8Bytes("Claim(address user,uint256 campaignId,uint256 amount,uint256 nonce,uint256 deadline)")
// );

const types = {
  Claim: [
    { name: "user", type: "address" },
    { name: "campaignId", type: "uint256" },
    { name: "amount", type: "uint256" },
    { name: "nonce", type: "uint256" },
    { name: "deadline", type: "uint256" },
  ],
};

app.get("/", (_req, res) => {
  res.json({
    name: "PolkaQuest API",
    status: "running",
  });
});

app.get("/health", (_req, res) => {
  res.json({
    ok: true,
  });
});

app.get(
  "/getCampaign",
  asyncHandler(async (req, res) => {
    const campaignId = parseCampaignId(req.query.campaignId);
    const campaign = await polkaQuest.campaigns(campaignId);

    res.json({
      ok: true,
      data: {
        campaignId: campaignId.toString(),
        rewardToken: campaign.rewardToken,
        rewardAmount: campaign.rewardAmount.toString(),
        totalFunded: campaign.totalFunded.toString(),
        totalClaimed: campaign.totalClaimed.toString(),
        active: campaign.active,
      },
    });
  })
);

app.get(
  "/hasUsedClaimed",
  asyncHandler(async (req, res) => {
    const campaignId = parseCampaignId(req.query.campaignId);
    const user = parseUserAddress(req.query.user);

    const claimed = await polkaQuest.hasClaimed(campaignId, user);

    res.json({
      ok: true,
      data: {
        campaignId: campaignId.toString(),
        user,
        usedClaimed: claimed,
      },
    });
  })
);

app.get(
  "/getRemainingReward",
  asyncHandler(async (req, res) => {
    const campaignId = parseCampaignId(req.query.campaignId);
    const campaign = await polkaQuest.campaigns(campaignId);

    const remainingReward = campaign.totalFunded - campaign.totalClaimed;

    res.json({
      ok: true,
      data: {
        campaignId: campaignId.toString(),
        remainingReward: remainingReward.toString(),
      },
    });
  })
);

app.post(
  "/claim",
  asyncHandler(async (req, res) => {
    const user = parseUserAddress(req.body.user);
    const campaignId = parseCampaignId(req.body.campaignId);
    const campaign = await polkaQuest.campaigns(campaignId);

    // 活动是否激活
    const isActive = campaign.active;
    if (!isActive) {
      throw new Error("Campaign is not active");
    }

    // 是否领取过
    const hasClaimed = await polkaQuest.hasClaimed(campaignId, user);
    if (hasClaimed) {
      throw new Error("User has already claimed");
    }

    // 奖励是否足够
    const remaining = campaign.totalFunded - campaign.totalClaimed;
    if (remaining < campaign.rewardAmount) {
      throw new Error("Insufficient campaign reward");
    }

    // success
    const claim = {
      user,
      campaignId: campaignId.toString(),
      amount: campaign.rewardAmount.toString(),
      nonce: Date.now().toString(),
      deadline: Math.floor(Date.now() / 1000 + 60 * 60).toString(),
    };


    const signature = await signerWallet.signTypedData(domain, types, claim);

    res.json({
      ok: true,
      data: {
        claim,
        signature
      },
    });
  })
)

app.post("/admin/create-campaign", async (req, res) => {
  try {
    const data = await createCampaign(req.body);
    res.json({ ok: true, data });
  } catch (error: any) {
    res.status(500).json({
      ok: false,
      error: error?.shortMessage || error?.reason || error?.message || "Create campaign failed"
    });
  }
});

app.post("/admin/fund-campaign", async (req, res) => {
  try {
    const data = await fundCampaign(req.body);
    res.json({ ok: true, data });
  } catch (error: any) {
    res.status(500).json({
      ok: false,
      error: error?.shortMessage || error?.reason || error?.message || "Fund campaign failed"
    });
  }
});

app.post("/admin/set-campaign-status", async (req, res) => {
  try {
    const data = await setCampaignStatus(req.body);
    res.json({ ok: true, data });
  } catch (error: any) {
    res.status(500).json({
      ok: false,
      error: error?.shortMessage || error?.reason || error?.message || "Set campaign status failed"
    });
  }
});

app.use((err: any, _req: Request, res: Response, _next: NextFunction) => {
  console.error(err);
  res.status(500).json({
    ok: false,
    message: err.message || "Internal server error",
  });
});

app.listen(port, () => {
  console.log(`API listening on http://localhost:${port}`);
});

function parseCampaignId(campaignIdParam: unknown): bigint {
  if (campaignIdParam === undefined) {
    throw new Error("campaignId is required");
  }

  return BigInt(String(campaignIdParam));
}

function parseUserAddress(userParam: unknown): string {
  if (userParam === undefined) {
    throw new Error("user is required");
  }

  const user = String(userParam);

  if (!ethers.isAddress(user)) {
    throw new Error("invalid user address");
  }

  return user;
}