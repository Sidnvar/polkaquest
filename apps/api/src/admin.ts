import { ethers } from "ethers";
import { adminSigner, polkaQuestContract } from "./blockchain";
import { hash } from "crypto";

const ERC20_ABI = [
  "function approve(address spender, uint256 amount) returns (bool)",
  "function allowance(address owner, address spender) view returns (uint256)",
  "function decimals() view returns (uint8)"
];

const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS as string;

async function _getParseUnits(rewardToken: string, amount: string){
    // 创建一个可交互的代币合约对象
    const token = new ethers.Contract(rewardToken, ERC20_ABI, adminSigner);
    //  查询代币的小数位数
    const decimals = await token.decimals();
    // 将人类可读的金额转换为区块链可处理的wei单位
    const parsedAmount = ethers.parseUnits(amount, decimals);

    return {
        token,
        parsedAmount
    };
}
export async function createCampaign(params: {
  rewardToken: string;
  rewardAmount: string;
}) {
    const { rewardToken, rewardAmount} = params;

    if (!ethers.isAddress(rewardToken)) {
        throw new Error("Invalid reward token address");
    }

    const { parsedAmount, token } = await _getParseUnits(rewardToken, rewardAmount);

    const tx = await polkaQuestContract.createCampaign(
        token,
        parsedAmount
    );
    const receipt = await tx.wait();

    return{
        hash: tx.hash,
        status: receipt?.status
    }
}

export async function fundCampaign(params: {
  campaignId: number | string;
  rewardToken: string;
  amount: string;
}) {
    const { campaignId, rewardToken, amount} = params;
    if (!ethers.isAddress(rewardToken)) {
        throw new Error("Invalid reward token address");
    }

    const { token, parsedAmount } = await _getParseUnits(rewardToken, amount);
    // 检查当前授权额度
    const allowance = await token.allowance(
        adminSigner.address,
        CONTRACT_ADDRESS
    );

    // 检查授权是否足够
    if(allowance < parsedAmount){
        // 重新授权
        const approveTx = await token.approve(
            CONTRACT_ADDRESS,
            parsedAmount
        );
        await approveTx.wait();
    }

    const tx = await polkaQuestContract.fundCampaign(
        BigInt(campaignId),
        parsedAmount
    );
    const receipt = await tx.wait();

    return{
        hash: tx.hash,
        status: receipt?.status
    }
}

export async function setCampaignStatus(params: {
  campaignId: number | string;
  isActive: boolean;
}) {
    const { campaignId, isActive } = params;
    const tx = await polkaQuestContract.setCampaignActive(campaignId, isActive);
    const receipt = await tx.wait();
    return{
        hash: tx.hash,
        active: isActive,
        status: receipt?.status
    }
}
