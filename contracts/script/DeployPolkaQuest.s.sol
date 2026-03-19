// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {PolkaQuest} from "../src/PolkaQuest.sol";

contract DeployPolkaQuest is Script {
    function run() external {
        address owner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        address signer = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

        vm.startBroadcast();
        PolkaQuest polkaQuest = new PolkaQuest(owner, signer);
        vm.stopBroadcast();

        console.log("PolkaQuest deployed at:");
        console.logAddress(address(polkaQuest));
    }
}