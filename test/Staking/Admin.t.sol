// solhint-disable ordering
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../Base.t.sol";

contract AdminTest is Base, IStakingSettingsEvents {
    // getters
    function testGetGlobalStakeCounter() public {
        assertEq(staking.getStakeCount(), 0);
        _stakeTokens(alice, NODE_1_ID, MIN_STAKING_AMOUNT, EPOCH_PERIOD_DAYS);
        assertEq(staking.getStakeCount(), 1);
        _stakeTokens(bob, NODE_1_ID, MIN_STAKING_AMOUNT, EPOCH_PERIOD_DAYS);
        assertEq(staking.getStakeCount(), 2);
    }

    // pausable/unpausable
    function testEmergencyPause() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, true, address(staking));
        emit EmergencyPause(admin);
        staking.emergencyPause();
        assertEq(staking.paused(), true);
    }

    function testEmergencyResume() public {
        vm.startPrank(admin);
        staking.emergencyPause();
        vm.expectEmit(true, false, false, true, address(staking));
        emit EmergencyResume(admin);
        staking.emergencyResume();
        assertEq(staking.paused(), false);
    }

    function testRevertNonAdminPause() public {
        vm.expectRevert("Caller is not an admin");
        staking.emergencyPause();
    }

    function testRevertNonAdminResume() public {
        vm.prank(admin);
        staking.emergencyPause();
        vm.prank(mallory);
        vm.expectRevert("Caller is not an admin");
        staking.emergencyResume();
    }

    function testRevertStakeWhenPaused() public {
        vm.prank(admin);
        staking.emergencyPause();
        vm.startPrank(alice);
        uint256 amount = ONE_TOKEN * 1000; // 1k tokens
        token.approve(address(staking), amount);
        vm.expectRevert("Pausable: paused");
        staking.stakeTokens(NODE_1_ID, amount, EPOCH_PERIOD_DAYS);
    }

    function testRevertStakeForWhenPaused() public {
        vm.prank(admin);
        staking.emergencyPause();
        vm.startPrank(alice);
        uint256 amount = ONE_TOKEN * 1000; // 1k tokens
        token.approve(address(staking), amount);
        vm.expectRevert("Pausable: paused");
        staking.stakeTokensFor(bob, NODE_1_ID, amount, EPOCH_PERIOD_DAYS);
    }

    function testRevertAddMeasurementWhenPaused() public {
        uint256 amount = ONE_TOKEN * 1000; // 1k tokens
        _stakeTokens(alice, NODE_1_ID, amount, EPOCH_PERIOD_DAYS);

        bytes32[] memory nodesArray = new bytes32[](1);
        uint24[] memory rpsArray = new uint24[](1);
        uint16[] memory penaltyArray = new uint16[](1);
        uint8[] memory slaLevels = new uint8[](1);

        nodesArray[0] = NODE_1_ID;
        rpsArray[0] = 500;
        penaltyArray[0] = 0;
        slaLevels[0] = uint8(StakingUtils.NodeSlaLevel.Gold);

        vm.prank(admin);
        staking.emergencyPause();
        vm.prank(supervisor);
        _fastforward(5 * EPOCH_PERIOD_SECONDS);
        vm.expectRevert("Pausable: paused");
        staking.addMeasurements(1, nodesArray, rpsArray, penaltyArray, slaLevels);
    }

    function testRevertClaimWhenPaused() public {
        uint256 amount = ONE_TOKEN * 1000; // 1k tokens
        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, amount, EPOCH_PERIOD_DAYS);
        _fastforward(2 * EPOCH_PERIOD_SECONDS);
        _addMeasurement(1, NODE_1_ID, 100, 0, StakingUtils.NodeSlaLevel.Gold);
        vm.prank(admin);
        staking.emergencyPause();
        vm.prank(alice);
        vm.expectRevert("Pausable: paused");
        staking.claim(stakeId);
    }

    function testRevertUnstakeWhenPaused() public {
        uint256 amount = ONE_TOKEN * 1000; // 1k tokens
        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, amount, EPOCH_PERIOD_DAYS);
        _fastforward(EPOCH_PERIOD_SECONDS);
        _addMeasurement(1, NODE_1_ID, 100, 0, StakingUtils.NodeSlaLevel.Gold);
        vm.prank(admin);
        staking.emergencyPause();
        vm.prank(alice);
        vm.expectRevert("Pausable: paused");
        staking.unstakeTokens(stakeId);
    }

    // Emergency withdrawn

    function testRevertEmergencyWithdrawWhileActive() public {
        vm.prank(admin);
        vm.expectRevert("Pausable: not paused");
        bytes32 reason = 0x00;
        staking.emergencyWithdraw(ONE_TOKEN * 1e6 * 5, reason); // 5M tokens
    }

    function testRevertNonAdminEmergencyWithdraw() public {
        vm.prank(admin);
        staking.emergencyPause();
        vm.prank(mallory);
        vm.expectRevert("Caller is not an admin");
        bytes32 reason = 0x00;
        staking.emergencyWithdraw(ONE_TOKEN * 1e6 * 5, reason); // 5M tokens
    }

    function testEmergencyWithdraw() public {
        vm.startPrank(admin);
        staking.emergencyPause();
        uint256 balanceBefore = token.balanceOf(admin);
        bytes32 reason = 0x00;
        staking.emergencyWithdraw(ONE_TOKEN * 1e6 * 5, reason); // 5M tokens
        assertEq(token.balanceOf(admin), balanceBefore + uint256(ONE_TOKEN * 1e6 * 5));
    }

    // max apy

    function testRevertIfNotAdminSetMaxApy() public {
        vm.expectRevert("Caller is not an admin");
        settings.setMaxApy(StakingUtils.NodeSlaLevel.Silver, 100);
    }

    function testRevertIfNotAdminSetMaxRps() public {
        vm.expectRevert("Caller is not an admin");
        settings.setMaxRps(MAX_RPS);
    }

    function testRevertIfApyExceedMaxSetMaxApy() public {
        uint256 newApy = MAX_APY + 1;
        StakingUtils.NodeSlaLevel sla = StakingUtils.NodeSlaLevel.Silver;

        vm.prank(admin);
        vm.expectRevert("Invalid APY");
        settings.setMaxApy(sla, newApy);
    }

    function testRevertIfApyBelowMinSetMaxApy() public {
        uint256 newApy = 0;
        StakingUtils.NodeSlaLevel sla = StakingUtils.NodeSlaLevel.Silver;

        vm.prank(admin);
        vm.expectRevert("Invalid APY");
        settings.setMaxApy(sla, newApy);
    }

    function testSetMaxApyToMin() public {
        uint256 newApy = 1;
        StakingUtils.NodeSlaLevel sla = StakingUtils.NodeSlaLevel.Silver;

        vm.prank(admin);
        settings.setMaxApy(sla, newApy);
    }

    function testSetMaxApyToMax() public {
        uint256 newApy = MAX_APY;
        StakingUtils.NodeSlaLevel sla = StakingUtils.NodeSlaLevel.Silver;

        vm.prank(admin);
        settings.setMaxApy(sla, newApy);
    }

    function testFuzzSetMaxApy(uint256 apy) public {
        vm.assume(1 <= apy && apy <= MAX_APY);
        vm.expectEmit(true, true, false, true, address(settings));
        StakingUtils.NodeSlaLevel sla = StakingUtils.NodeSlaLevel.Silver;
        emit MaxApyChanged(admin, sla, apy);

        vm.prank(admin);
        settings.setMaxApy(sla, apy);
    }

    // supervisor management

    function testRevertIfNotRoleAdminAddSupervisor() public {
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(address(0x0000000000000000000000000000000000000001)),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(DEFAULT_ADMIN_ROLE), 32)
            )
        );
        vm.prank(address(1));
        staking.grantRole(SUPERVISOR_ROLE, alice);
    }

    function testRevertIfNotRoleAdminRemoveSupervisor() public {
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(address(0x0000000000000000000000000000000000000001)),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(DEFAULT_ADMIN_ROLE), 32)
            )
        );
        vm.prank(address(1));
        staking.revokeRole(SUPERVISOR_ROLE, alice);
    }

    function testRevertAdminCantGrantSupervisor() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(admin),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(DEFAULT_ADMIN_ROLE), 32)
            )
        );
        staking.grantRole(SUPERVISOR_ROLE, alice);
    }

    function testRevertAdminCantRevokeSupervisor() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(admin),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(DEFAULT_ADMIN_ROLE), 32)
            )
        );
        staking.revokeRole(SUPERVISOR_ROLE, alice);
    }

    function testGrantSupervisor() public {
        vm.prank(roleAdmin);
        staking.grantRole(SUPERVISOR_ROLE, alice);
        assertEq(staking.hasRole(SUPERVISOR_ROLE, alice), true);
    }

    function testRevokeSupervisor() public {
        vm.prank(roleAdmin);
        staking.revokeRole(SUPERVISOR_ROLE, supervisor);
        assertEq(staking.hasRole(SUPERVISOR_ROLE, supervisor), false);
    }

    // min staking

    function testRevertIfNotAdminSetMinStaking() public {
        vm.expectRevert("Caller is not an admin");
        settings.setMinStakingAmount(100);
    }

    function testRevertIfNotAdminSetMinRps() public {
        vm.expectRevert("Caller is not an admin");
        settings.setMinRps(MIN_RPS);
    }

    function testFuzzSetMinStaking(uint256 amount) public {
        /// @dev max staking per node default
        vm.assume(amount <= 1e8 * 1e18 && amount > 0);

        vm.expectEmit(true, true, false, true, address(settings));
        emit MinStakingAmountChanged(admin, amount);
        vm.prank(admin);
        settings.setMinStakingAmount(amount);
        uint16 period = EPOCH_PERIOD_DAYS;

        _stakeTokens(alice, NODE_1_ID, amount, period);
    }

    // max staking per node

    function testFuzzSetMaxStakingAmountPerNode(uint256 amount) public {
        // default min staking and max token
        vm.assume(amount >= 1000 * ONE_TOKEN && amount < 100e6 ether);

        vm.expectEmit(true, true, false, true, address(settings));
        emit MaxStakingPerNodeChanged(admin, amount);
        vm.prank(admin);
        settings.setMaxStakingAmountPerNode(amount);
        uint16 period = EPOCH_PERIOD_DAYS;

        _stakeTokens(alice, NODE_1_ID, amount, period);
    }

    // min/max rps

    function testRevertIfMinRpsBelow1() public {
        uint24 minRps = 0;

        vm.prank(admin);
        vm.expectRevert("Exceeds max RPS or below 1");
        settings.setMinRps(minRps);
    }

    function testRevertIfMinRpsAboveMaxSetMinRps() public {
        uint24 minRps = MAX_RPS + 1;

        vm.prank(admin);
        vm.expectRevert("Exceeds max RPS or below 1");
        settings.setMinRps(minRps);
    }

    function testSetMinRps() public {
        uint24 minRps = MIN_RPS - 1;
        uint256 epoch = 1;
        uint16 penaltyDays = 0;
        StakingUtils.NodeSlaLevel sla = StakingUtils.NodeSlaLevel.Diamond;

        vm.prank(admin);
        settings.setMinRps(minRps);

        _stakeTokens(alice, NODE_1_ID, 1e21, 28);

        _fastforward(30 days);
        _addMeasurement(epoch, NODE_1_ID, minRps, penaltyDays, sla);
    }

    function testRevertMinRpsEqualMaxRps() public {
        uint24 rps = 100;
        vm.startPrank(admin);
        settings.setMinRps(rps);
        vm.expectRevert("Below min RPS");
        settings.setMaxRps(rps);
        rps = 200;
        settings.setMaxRps(rps);
        vm.expectRevert("Exceeds max RPS or below 1");
        settings.setMinRps(rps);
        vm.stopPrank();
    }

    function testFuzzSetMinRps(uint24 rps) public {
        vm.assume(1 <= rps && rps < MAX_RPS);

        vm.prank(admin);
        settings.setMaxRps(MAX_RPS);

        vm.expectEmit(true, true, false, true, address(settings));
        emit MinRpsChanged(admin, rps);
        vm.prank(admin);
        settings.setMinRps(rps);
    }

    function testRevertIfMaxRpsBelowMinSetMaxRps() public {
        uint24 maxRps = MIN_RPS - 1;

        vm.prank(admin);
        vm.expectRevert("Below min RPS");
        settings.setMaxRps(maxRps);
    }

    function testSetMaxRps() public {
        uint24 maxRps = 2 ** 24 - 1;
        uint256 epoch = 1;
        uint16 penaltyDays = 0;
        StakingUtils.NodeSlaLevel sla = StakingUtils.NodeSlaLevel.Diamond;

        vm.prank(admin);
        settings.setMaxRps(maxRps);

        _stakeTokens(alice, NODE_1_ID, 1e21, 28);

        _fastforward(30 days);
        _addMeasurement(epoch, NODE_1_ID, maxRps, penaltyDays, sla);
    }

    function testFuzzSetMaxRps(uint24 rps) public {
        vm.assume(2 <= rps && rps <= MAX_RPS);
        vm.prank(admin);
        settings.setMinRps(1);

        vm.expectEmit(true, true, false, true, address(settings));
        emit MaxRpsChanged(admin, rps);
        vm.prank(admin);
        settings.setMaxRps(rps);
    }

    // penalty rate

    function testRevertSetPenaltyRateOutOfBounds() public {
        vm.prank(admin);
        vm.expectRevert("Rate exceeds limit");
        settings.setPenaltyRate(1e4);
    }

    function testSetPenaltyRateToMax() public {
        vm.prank(admin);
        settings.setPenaltyRate(1e4 - 1);
    }

    function testSetPenaltyRateToZero() public {
        vm.prank(admin);
        settings.setPenaltyRate(0);
    }

    function testFuzzSetPenaltyRate(uint256 penaltyRate) public {
        vm.assume(penaltyRate <= 9999);
        vm.expectEmit(true, true, false, true, address(settings));
        emit PenaltyRateChanged(admin, penaltyRate);
        vm.prank(admin);
        settings.setPenaltyRate(penaltyRate);
    }

    // node owner reward percent

    function testSetNodeOwnerRewardPercentToZero() public {
        vm.prank(admin);
        settings.setNodeOwnerRewardPercent(0);
    }

    function testSetNodeOwnerRewardPercentToMax() public {
        vm.prank(admin);
        settings.setNodeOwnerRewardPercent(1e2);
    }

    function testFuzzSetNodeOwnerRewardPercent(uint16 percent) public {
        vm.assume(percent <= 1e2);
        vm.expectEmit(true, true, false, true, address(settings));
        emit NodeOwnerRewardPercentChanged(admin, percent);
        vm.prank(admin);
        settings.setNodeOwnerRewardPercent(percent);
    }

    function testRevertSetNodeOwnerRewardPercentIfAboveMax() public {
        vm.prank(admin);
        vm.expectRevert("Exceeds limit");
        settings.setNodeOwnerRewardPercent(1e2 + 1);
    }

    // APY Boost for stake Long

    function testFuzzSetApyBoostMinPercent(uint16 percent) public {
        vm.assume(percent <= 1e2);
        vm.expectEmit(true, true, false, true, address(settings));
        emit StakeLongApyMinBoostChanged(admin, percent);
        vm.prank(admin);
        settings.setApyBoostMinPercent(percent);
    }

    function testFuzzSetApyBoostDeltaPercent(uint16 percent) public {
        vm.assume(percent <= 1e3);
        vm.expectEmit(true, true, false, true, address(settings));
        emit StakeLongApyDeltaBoostChanged(admin, percent);
        vm.prank(admin);
        settings.setApyBoostDeltaPercent(percent);
    }

    function testFuzzSetApyBoostMaxDays(uint16 maxDays) public {
        vm.assume(maxDays >= 366 && maxDays <= 1825);
        vm.expectEmit(true, true, false, true, address(settings));
        emit StakeLongApyBoostMaxDaysChanged(admin, maxDays);
        vm.prank(admin);
        settings.setApyBoostMaxDays(maxDays);
    }

    // other

    function testDefaultAdminStaking() public {
        assertEq(staking.hasRole(ADMIN_ROLE, admin), true);
    }

    function testDefaultAdminSettings() public {
        assertEq(settings.hasRole(ADMIN_ROLE, admin), true);
    }

    function testVerifyStartEpoch() public {
        assertEq(staking.getContractStartTimestamp(), deployTimestamp);
    }
}
