// solhint-disable ordering
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../Base.t.sol";
import "./StakingV2.sol";

contract UpgradeTest is Base {
    function testRevertUpgradeIfNotAdmin() public {
        StakingV2 stakingV2 = new StakingV2();
        vm.prank(alice);
        vm.expectRevert();
        staking.upgradeTo(address(stakingV2));
    }

    function testUpgradeToNewStaking() public {
        StakingV2 stakingV2 = new StakingV2();
        vm.prank(admin);
        staking.upgradeTo(address(stakingV2));

        stakingV2 = StakingV2(address(proxy));
        assertEq(stakingV2.newMethod(), 1);
    }
}
