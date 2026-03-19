/* 专门放 provider、admin signer、contract。*/
import dotenv from "dotenv";
import { ethers } from "ethers";
import { CONTRACT_ABI } from "./polkaQuestAbi";

dotenv.config();

console.log(process.env)
const RPC_URL = process.env.RPC_URL as string; // 区块链节点连接地址
const SIGNER_PRIVATE_KEY = process.env.SIGNER_PRIVATE_KEY as string; // 管理员私钥
const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS as string; // 智能合约地址

if (!RPC_URL) throw new Error("Missing RPC_URL");
if (!SIGNER_PRIVATE_KEY) throw new Error("Missing SIGNER_PRIVATE_KEY");
if (!CONTRACT_ADDRESS) throw new Error("Missing CONTRACT_ADDRESS");

export const provider = new ethers.JsonRpcProvider(RPC_URL);
export const adminSigner = new ethers.Wallet(SIGNER_PRIVATE_KEY, provider);

export const polkaQuestContract = new ethers.Contract(
  CONTRACT_ADDRESS,
  CONTRACT_ABI,
  adminSigner
);
