const CONTRACT_ABI = [
  "function createCampaign(address _rewardToken, uint256 _rewardAmount) returns (uint256)",
  "function fundCampaign(uint256 campaignId, uint256 amount)",
  "function setCampaignActive(uint256 campaignId, bool isActive)",
  "function campaigns(uint256) view returns (address rewardToken, uint256 rewardAmount, uint256 totalFunded, uint256 totalClaimed, bool active)",
  "function nextCampaignId() view returns (uint256)",
  "function getSignerAddress() view returns (address)"
];

export { CONTRACT_ABI };