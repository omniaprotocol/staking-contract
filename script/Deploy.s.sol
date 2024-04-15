// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Staking, StakingSettings} from "src/Staking.sol";
import {ERC20Mock} from "src/Token.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployDevelopment is Script {
    function run() public {
        vm.startBroadcast();
        ERC20Mock token = new ERC20Mock();
        StakingSettings settings = new StakingSettings();
        Staking staking = new Staking();
        ERC1967Proxy proxy = new ERC1967Proxy(address(staking), "");

        staking = Staking(address(proxy));
        staking.initialize(address(token), address(settings));
        vm.stopBroadcast();
    }
}
