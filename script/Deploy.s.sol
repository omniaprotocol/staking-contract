// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Staking} from "src/Staking.sol";
import {ERC20} from "src/Token.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployDevelopment is Script {
    function run() public {
        vm.startBroadcast();
        ERC20 token = new ERC20();
        Staking staking = new Staking();
        ERC1967Proxy proxy = new ERC1967Proxy(address(staking), "");

        staking = Staking(address(proxy));
        staking.initialize(address(token));
        vm.stopBroadcast();
    }
}
