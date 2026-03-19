// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PolkaQuest} from "../src/PolkaQuest.sol";
import {MockERC20} from "../src/MockERC20.sol";

/**
 * @custom:dev-run-script ./script.sh
 */
contract PolkaQuestTest is Test {
    PolkaQuest public polkaQuest;
    MockERC20 public token;

    uint256 ownerPk;
    uint256 signerPk;
    address owner;
    address signer;
    address user;

    function setUp() public {
        ownerPk = 0xA11CE;
        signerPk = 0xB0B;
        owner = vm.addr(ownerPk);
        signer = vm.addr(signerPk);
        user = address(0x1234);

        vm.startPrank(owner);
        token = new MockERC20();
        polkaQuest = new PolkaQuest(owner, signer);
        vm.stopPrank();
    }

    function createCampaignAndFund(uint256 amount) internal returns (uint256) {
        vm.startPrank(owner);
        uint256 campaignId = polkaQuest.createCampaign(address(token), amount);
        token.approve(address(polkaQuest), amount);
        polkaQuest.fundCampaign(campaignId, amount);
        vm.stopPrank();
        return campaignId;
    }

    function _getDomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes("PolkaQuest")),
                keccak256(bytes("1")),
                block.chainid,
                address(polkaQuest)
            )
        );
    }

    function _getStructHash(PolkaQuest.Claim memory claim) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                polkaQuest.CLAIM_TYPEHASH(),
                claim.user,
                claim.campaignId,
                claim.amount,
                claim.nonce,
                claim.deadline
            )
        );
    }

    function _signClaim(PolkaQuest.Claim memory claim) internal view returns (bytes memory) {
        bytes32 structHash = _getStructHash(claim);
        bytes32 domainSeparator = _getDomainSeparator();

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        return abi.encodePacked(r, s, v);
    }

    function test_CreateCampaign() public {
        vm.prank(owner);
        uint256 campaignId = polkaQuest.createCampaign(address(token), 10 ether);

        (
            address rewardToken,
            uint256 rewardAmount,
            uint256 totalFunded,
            uint256 totalClaimed,
            bool active
        ) = polkaQuest.campaigns(campaignId);

        assertEq(campaignId, 0);
        assertEq(rewardToken, address(token));
        assertEq(rewardAmount, 10 ether);
        assertEq(totalFunded, 0);
        assertEq(totalClaimed, 0);
        assertEq(active, true);
    }

    function test_FundCampaign() public {
        uint256 campaignId = createCampaignAndFund(10 ether);

        (
            address rewardToken,
            uint256 rewardAmount,
            uint256 totalFunded,
            uint256 totalClaimed,
            bool active
        ) = polkaQuest.campaigns(campaignId);

        assertEq(rewardToken, address(token));
        assertEq(rewardAmount, 10 ether);
        assertEq(totalFunded, 10 ether);
        assertEq(totalClaimed, 0);
        assertEq(active, true);
    }

    function test_SetCampaignActive() public {
        vm.startPrank(owner);
        uint256 campaignId = polkaQuest.createCampaign(address(token), 10 ether);
        polkaQuest.setCampaignActive(campaignId, false);
        vm.stopPrank();

        (
            ,
            ,
            ,
            ,
            bool active
        ) = polkaQuest.campaigns(campaignId);

        assertEq(active, false);
    }

    function test_ClaimReward() public {
        uint256 campaignId = createCampaignAndFund(100 ether);

        PolkaQuest.Claim memory claim = PolkaQuest.Claim({
            user: user,
            campaignId: campaignId,
            amount: 10 ether,
            nonce: 1,
            deadline: block.timestamp + 1 days
        });

        bytes memory signature = _signClaim(claim);

        vm.prank(user);
        polkaQuest.claimReward(claim, signature);

        assertEq(token.balanceOf(user), 10 ether);

        (
            ,
            ,
            ,
            uint256 totalClaimed,
            bool active
        ) = polkaQuest.campaigns(campaignId);

        assertEq(totalClaimed, 10 ether);
        assertEq(active, true);

        assertEq(polkaQuest.hasClaimed(campaignId, user), true);
    }

    function test_RevertWhen_NonOwnerCreateCampaign() public {
        vm.prank(user);
        vm.expectRevert();
        polkaQuest.createCampaign(address(token), 10 ether);
    }

    function test_SetSigner() public {
        address newSigner = address(0x9999);

        vm.prank(owner);
        polkaQuest.setSigner(newSigner);

        assertEq(polkaQuest.signer(), newSigner);
    }

    function test_RevertWhen_NonOwnerSetSigner() public {
        vm.prank(user);
        vm.expectRevert();
        polkaQuest.setSigner(address(0x9999));
    }

    function test_RevertWhen_ClaimTwice() public {
        uint256 campaignId = createCampaignAndFund(10 ether);

        PolkaQuest.Claim memory claim = PolkaQuest.Claim({
            user: user,
            campaignId: campaignId,
            amount: 10 ether,
            nonce: 1,
            deadline: block.timestamp + 1 days
        });

        bytes memory signature = _signClaim(claim);

        vm.prank(user);
        polkaQuest.claimReward(claim, signature);

        vm.prank(user);
        vm.expectRevert(PolkaQuest.AlreadyClaimed.selector);
        polkaQuest.claimReward(claim, signature);
    }
}