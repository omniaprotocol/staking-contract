// solhint-disable ordering
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../Base.t.sol";
import "./StakingV2.sol";

contract UpgradeTest is Base, ERC1967UpgradeUpgradeable {
    function testRevertUpgradeIfNotAdmin() public {
        StakingV2 stakingV2 = new StakingV2();
        vm.prank(alice);
        vm.expectRevert();
        staking.upgradeTo(address(stakingV2));
    }

    function testUpgradeToNewStakingFromMultisig() public {
        StakingV2 stakingV2 = new StakingV2();

        bytes memory calldata_ = abi.encodeWithSignature("upgradeTo(address)", address(stakingV2));
        vm.prank(multisig);
        _timelockSchedule(address(staking), calldata_, TWO_DAYS_IN_SECONDS);
        _fastforward(TWO_DAYS_IN_SECONDS);

        vm.expectEmit(true, true, true, true, address(staking));
        emit UpgradeAuthorized(admin, address(staking), address(stakingV2));
        vm.expectEmit(true, false, false, true, address(staking));
        emit Upgraded(address(stakingV2));
        vm.prank(multisig);
        _timelockExecute(address(staking), calldata_);

        stakingV2 = StakingV2(address(proxy));
        assertEq(stakingV2.newMethod(), 1);
    }

    function testUpgradeToNewStakingFromAdmin() public {
        StakingV2 stakingV2 = new StakingV2();
        vm.prank(admin);
        vm.expectEmit(true, true, true, true, address(staking));
        emit UpgradeAuthorized(admin, address(staking), address(stakingV2));
        vm.expectEmit(true, false, false, true, address(staking));
        emit Upgraded(address(stakingV2));
        staking.upgradeTo(address(stakingV2));

        stakingV2 = StakingV2(address(proxy));
        assertEq(stakingV2.newMethod(), 1);
    }
}
