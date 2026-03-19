// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract PolkaQuest is Ownable, EIP712 {
    using ECDSA for bytes32;

    bytes32 public constant CLAIM_TYPEHASH =
        keccak256(
            "Claim(address user,uint256 campaignId,uint256 amount,uint256 nonce,uint256 deadline)"
        );

    struct Campaign {
        address rewardToken;
        uint256 rewardAmount;
        uint256 totalFunded;
        uint256 totalClaimed;
        bool active;
    }

    struct Claim {
        address user;
        uint256 campaignId;
        uint256 amount;
        uint256 nonce;
        uint256 deadline;
    }

    uint256 public nextCampaignId;
    address public signer;

    mapping(uint256 => Campaign) public campaigns;
    mapping(bytes32 => bool) public usedClaims;
    mapping(uint256 => mapping(address => bool)) public hasClaimed;

    error InvalidRewardToken();
    error InvalidRewardAmount();
    error InvalidCampaign();
    error InvalidFundingAmount();
    error CampaignInactive();
    error TransferFailed();
    error InvalidSignature();
    error AlreadyClaimed();
    error ClaimAlreadyUsed();
    error ClaimExpired();
    error InvalidAmount();
    error InsufficientCampaignBalance();
    error ClaimTransferFailed();
    error InvalidSigner();

    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed rewardToken,
        uint256 rewardAmount
    );
    event CampaignFunded(uint256 indexed campaignId, uint256 amount);
    event CampaignStatusUpdated(uint256 indexed campaignId, bool isActive);
    event RewardClaimed(
        uint256 indexed campaignId,
        address indexed user,
        uint256 amount,
        uint256 nonce
    );
    event SignerUpdated(address indexed oldSigner, address indexed newSigner);

    constructor(address initialOwner, address initialSigner)
        Ownable(initialOwner)
        EIP712("PolkaQuest", "1")
    {
        signer = initialSigner;
    }

    function createCampaign(address _rewardToken, uint256 _rewardAmount)
        external
        onlyOwner
        returns (uint256)
    {
        if (_rewardToken == address(0)) revert InvalidRewardToken();
        if (_rewardAmount == 0) revert InvalidRewardAmount();

        uint256 campaignId = nextCampaignId;

        campaigns[campaignId] = Campaign({
            rewardToken: _rewardToken,
            rewardAmount: _rewardAmount,
            totalFunded: 0,
            totalClaimed: 0,
            active: true
        });

        emit CampaignCreated(campaignId, _rewardToken, _rewardAmount);

        nextCampaignId++;
        return campaignId;
    }

    function fundCampaign(uint256 _campaignId, uint256 _amount)
        external
        onlyOwner
    {
        if (_campaignId >= nextCampaignId) revert InvalidCampaign();
        if (_amount == 0) revert InvalidFundingAmount();

        Campaign storage campaign = campaigns[_campaignId];
        if (!campaign.active) revert CampaignInactive();

        bool success = IERC20(campaign.rewardToken).transferFrom(
            msg.sender,
            address(this),
            _amount
        );
        if (!success) revert TransferFailed();

        campaign.totalFunded += _amount;

        emit CampaignFunded(_campaignId, _amount);
    }

    function setCampaignActive(uint256 _campaignId, bool isActive)
        external
        onlyOwner
    {
        if (_campaignId >= nextCampaignId) revert InvalidCampaign();

        Campaign storage campaign = campaigns[_campaignId];
        campaign.active = isActive;

        emit CampaignStatusUpdated(_campaignId, isActive);
    }

    function claimReward(Claim calldata _claim, bytes calldata _signature)
        external
    {
        _validateCampaign(_claim.campaignId);
        _validateClaimBasic(_claim);

        bytes32 claimHash = _hashClaim(_claim);

        _validateClaimState(_claim, claimHash);

        bool verified = _verifySignature(_claim, _signature);
        if (!verified) revert InvalidSignature();

        Campaign storage campaign = campaigns[_claim.campaignId];

        _checkCampaignBalance(campaign, _claim.amount);

        _transferReward(campaign.rewardToken, _claim.user, _claim.amount);

        campaign.totalClaimed += _claim.amount;
        usedClaims[claimHash] = true;
        hasClaimed[_claim.campaignId][_claim.user] = true;

        emit RewardClaimed(
            _claim.campaignId,
            _claim.user,
            _claim.amount,
            _claim.nonce
        );
    }

    function setSigner(address newSigner) external onlyOwner {
        if (newSigner == address(0)) revert InvalidSigner();

        address oldSigner = signer;
        signer = newSigner;

        emit SignerUpdated(oldSigner, newSigner);
    }

    function _validateCampaign(uint256 _campaignId)
        internal
        view
        returns (Campaign storage campaign)
    {
        if (_campaignId >= nextCampaignId) revert InvalidCampaign();

        campaign = campaigns[_campaignId];
        if (!campaign.active) revert CampaignInactive();

        return campaign;
    }

    function _hashClaim(Claim calldata _claim)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                CLAIM_TYPEHASH,
                _claim.user,
                _claim.campaignId,
                _claim.amount,
                _claim.nonce,
                _claim.deadline
            )
        );
    }

    function _validateClaimBasic(Claim calldata _claim) internal view {
        if (_claim.amount == 0) revert InvalidAmount();
        if (block.timestamp > _claim.deadline) revert ClaimExpired();
        if (_claim.user != msg.sender) revert InvalidSignature();
    }

    function _validateClaimState(Claim calldata _claim, bytes32 _claimHash)
        internal
        view
    {
        if (hasClaimed[_claim.campaignId][_claim.user]) revert AlreadyClaimed();
        if (usedClaims[_claimHash]) revert ClaimAlreadyUsed();
    }

    function _checkCampaignBalance(Campaign storage _campaign, uint256 _amount)
        internal
        view
    {
        uint256 remaining = _campaign.totalFunded - _campaign.totalClaimed;
        if (remaining < _amount) revert InsufficientCampaignBalance();
    }

    function _transferReward(address token, address to, uint256 amount)
        internal
    {
        bool success = IERC20(token).transfer(to, amount);
        if (!success) revert ClaimTransferFailed();
    }

    function _verifySignature(Claim calldata _claim, bytes calldata _signature)
        internal
        view
        returns (bool)
    {
        bytes32 claimHash = _hashClaim(_claim);
        bytes32 digest = _hashTypedDataV4(claimHash);
        address recoveredSigner = ECDSA.recover(digest, _signature);
        return recoveredSigner == signer;
    }

    function verifyClaim(Claim calldata claim, bytes calldata sig)
        external
        view
        returns (address)
    {
        bytes32 claimHash = _hashClaim(claim);
        bytes32 digest = _hashTypedDataV4(claimHash);
        return ECDSA.recover(digest, sig);
    }

    function getClaimDigest(Claim calldata claim)
        external
        view
        returns (bytes32)
    {
        bytes32 claimHash = _hashClaim(claim);
        return _hashTypedDataV4(claimHash);
    }

    function getSignerAddress()
        external
        view
        returns(address)
    {
        return signer;
    }
}