// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../../src/Staking.sol";

contract StakingV2 is Staking {
    function newMethod() public pure returns (uint256) {
        return 1;
    }
}
