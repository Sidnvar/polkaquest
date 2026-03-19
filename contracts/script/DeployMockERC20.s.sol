// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MockERC20} from "../src/MockERC20.sol";

contract DeployMockERC20 is Script {
    function run() external {
        vm.startBroadcast();

        MockERC20 token = new MockERC20();

        vm.stopBroadcast();

        console.log("MockERC20 deployed at:");
        console.logAddress(address(token));
    }
}