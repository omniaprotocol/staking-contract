// solhint-disable ordering
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../Base.t.sol";

contract AdminTest is Base, IStakingSettingsEvents {
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

    function testSetMaxApyToMinFromMultisig() public {
        uint256 newApy = 1;
        StakingUtils.NodeSlaLevel sla = StakingUtils.NodeSlaLevel.Silver;

        bytes memory calldata_ = abi.encodeWithSignature("setMaxApy(uint8,uint256)", sla, newApy);
        vm.startPrank(multisig);
        _timelockSchedule(address(settings), calldata_, TWO_DAYS_IN_SECONDS);
        _fastforward(TWO_DAYS_IN_SECONDS);
        vm.expectEmit(true, true, true, true, address(settings));
        emit MaxApyChanged(admin, sla, newApy);
        _timelockExecute(address(settings), calldata_);
        vm.stopPrank();
    }

    function testSetMaxApyToMinFromAdmin() public {
        uint256 newApy = 1;
        StakingUtils.NodeSlaLevel sla = StakingUtils.NodeSlaLevel.Silver;

        vm.prank(admin);
        vm.expectEmit(true, true, true, true, address(settings));
        emit MaxApyChanged(admin, sla, newApy);
        settings.setMaxApy(sla, newApy);
    }

    function testSetMaxApyToMaxFromMultisig() public {
        uint256 newApy = MAX_APY;
        StakingUtils.NodeSlaLevel sla = StakingUtils.NodeSlaLevel.Silver;

        bytes memory calldata_ = abi.encodeWithSignature("setMaxApy(uint8,uint256)", sla, newApy);

        vm.startPrank(multisig);
        _timelockSchedule(address(settings), calldata_, TWO_DAYS_IN_SECONDS);
        _fastforward(TWO_DAYS_IN_SECONDS);
        vm.expectEmit(true, true, true, true, address(settings));
        emit MaxApyChanged(admin, sla, newApy);
        _timelockExecute(address(settings), calldata_);
        vm.stopPrank();
    }

    function testSetMaxApyToMaxFromAdmin() public {
        uint256 newApy = MAX_APY;
        StakingUtils.NodeSlaLevel sla = StakingUtils.NodeSlaLevel.Silver;

        vm.prank(admin);
        vm.expectEmit(true, true, true, true, address(settings));
        emit MaxApyChanged(admin, sla, newApy);
        settings.setMaxApy(sla, newApy);
    }

    function testFuzzSetMaxApyFromMultisig(uint256 apy) public {
        vm.assume(1 <= apy && apy <= MAX_APY);
        StakingUtils.NodeSlaLevel sla = StakingUtils.NodeSlaLevel.Silver;

        bytes memory calldata_ = abi.encodeWithSignature("setMaxApy(uint8,uint256)", sla, apy);

        vm.startPrank(multisig);
        _timelockSchedule(address(settings), calldata_, TWO_DAYS_IN_SECONDS);
        _fastforward(TWO_DAYS_IN_SECONDS);
        vm.expectEmit(true, true, true, true, address(settings));
        emit MaxApyChanged(admin, sla, apy);

        _timelockExecute(address(settings), calldata_);
        vm.stopPrank();
    }

    function testFuzzSetMaxApyFromAdmin(uint256 apy) public {
        vm.assume(1 <= apy && apy <= MAX_APY);
        vm.expectEmit(true, true, true, true, address(settings));
        StakingUtils.NodeSlaLevel sla = StakingUtils.NodeSlaLevel.Silver;
        emit MaxApyChanged(admin, sla, apy);

        vm.prank(admin);
        settings.setMaxApy(sla, apy);
    }

    // supervisor management

    function testRevertSettingsCantGrantOtherAdmins() public {
        vm.prank(address(timelockAdmin));
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(address(timelockAdmin)),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(DEFAULT_ADMIN_ROLE), 32)
            )
        );
        settings.grantRole(STAKING_ADMIN_ROLE, alice);
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

    function testFuzzSetMinRpsFromMultisig(uint24 rps) public {
        vm.assume(1 <= rps && rps < MAX_RPS);

        bytes memory calldata_ = abi.encodeWithSignature("setMinRps(uint24)", rps);
        vm.prank(multisig);
        _timelockSchedule(address(settings), calldata_, TWO_DAYS_IN_SECONDS);
        _fastforward(TWO_DAYS_IN_SECONDS);

        // Pre-requisites
        vm.prank(admin);
        settings.setMaxRps(MAX_RPS);

        vm.expectEmit(true, true, false, true, address(settings));
        emit MinRpsChanged(admin, rps);
        vm.prank(multisig);
        _timelockExecute(address(settings), calldata_);
    }

    function testFuzzSetMinRpsFromAdmin(uint24 rps) public {
        vm.assume(1 <= rps && rps < MAX_RPS);

        // Pre-requisites
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

    function testFuzzSetMaxRpsFromMultisig(uint24 rps) public {
        vm.assume(2 <= rps && rps <= MAX_RPS);

        // Pre-requisites
        vm.prank(admin);
        settings.setMinRps(1);

        bytes memory calldata_ = abi.encodeWithSignature("setMaxRps(uint24)", rps);
        vm.prank(multisig);
        _timelockSchedule(address(settings), calldata_, TWO_DAYS_IN_SECONDS);
        _fastforward(TWO_DAYS_IN_SECONDS);

        vm.expectEmit(true, true, false, true, address(settings));
        emit MaxRpsChanged(admin, rps);
        vm.prank(multisig);
        _timelockExecute(address(settings), calldata_);
    }

    function testFuzzSetMaxRpsFromAdmin(uint24 rps) public {
        vm.assume(2 <= rps && rps <= MAX_RPS);

        // Pre-requisites
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

    function testFuzzSetPenaltyRateFromMultisig(uint256 penaltyRate) public {
        vm.assume(penaltyRate <= 9999);

        bytes memory calldata_ = abi.encodeWithSignature("setPenaltyRate(uint256)", penaltyRate);
        vm.prank(multisig);
        _timelockSchedule(address(settings), calldata_, TWO_DAYS_IN_SECONDS);
        _fastforward(TWO_DAYS_IN_SECONDS);

        vm.expectEmit(true, true, false, true, address(settings));
        emit PenaltyRateChanged(admin, penaltyRate);
        vm.prank(multisig);
        _timelockExecute(address(settings), calldata_);
    }

    function testFuzzSetPenaltyRateFromAdmin(uint256 penaltyRate) public {
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

    function testFuzzSetNodeOwnerRewardPercentFromMultisig(uint16 percent) public {
        vm.assume(percent <= 1e2);

        bytes memory calldata_ = abi.encodeWithSignature("setNodeOwnerRewardPercent(uint16)", percent);
        vm.prank(multisig);
        _timelockSchedule(address(settings), calldata_, TWO_DAYS_IN_SECONDS);
        _fastforward(TWO_DAYS_IN_SECONDS);

        vm.expectEmit(true, true, false, true, address(settings));
        emit NodeOwnerRewardPercentChanged(admin, percent);
        vm.prank(multisig);
        _timelockExecute(address(settings), calldata_);
    }

    function testFuzzSetNodeOwnerRewardPercentFromAdmin(uint16 percent) public {
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

    function testFuzzSetApyBoostMinPercentFromMultisig(uint16 percent) public {
        vm.assume(percent <= 1e2);

        bytes memory calldata_ = abi.encodeWithSignature("setApyBoostMinPercent(uint16)", percent);
        vm.prank(multisig);
        _timelockSchedule(address(settings), calldata_, TWO_DAYS_IN_SECONDS);
        _fastforward(TWO_DAYS_IN_SECONDS);

        vm.expectEmit(true, true, false, true, address(settings));
        emit StakeLongApyMinBoostChanged(admin, percent);
        vm.prank(multisig);
        _timelockExecute(address(settings), calldata_);
    }

    function testFuzzSetApyBoostMinPercentFromAdmin(uint16 percent) public {
        vm.assume(percent <= 1e2);
        vm.expectEmit(true, true, false, true, address(settings));
        emit StakeLongApyMinBoostChanged(admin, percent);
        vm.prank(admin);
        settings.setApyBoostMinPercent(percent);
    }

    function testFuzzSetApyBoostDeltaPercentFromMultisig(uint16 percent) public {
        vm.assume(percent <= 1e3);

        bytes memory calldata_ = abi.encodeWithSignature("setApyBoostDeltaPercent(uint16)", percent);
        vm.prank(multisig);
        _timelockSchedule(address(settings), calldata_, TWO_DAYS_IN_SECONDS);
        _fastforward(TWO_DAYS_IN_SECONDS);

        vm.expectEmit(true, true, false, true, address(settings));
        emit StakeLongApyDeltaBoostChanged(admin, percent);
        vm.prank(multisig);
        _timelockExecute(address(settings), calldata_);
    }

    function testFuzzSetApyBoostDeltaPercentFromAdmin(uint16 percent) public {
        vm.assume(percent <= 1e3);
        vm.expectEmit(true, true, false, true, address(settings));
        emit StakeLongApyDeltaBoostChanged(admin, percent);
        vm.prank(admin);
        settings.setApyBoostDeltaPercent(percent);
    }

    function testFuzzSetApyBoostMaxDaysFromMultisig(uint16 maxDays) public {
        vm.assume(maxDays >= 366 && maxDays <= 1825);

        bytes memory calldata_ = abi.encodeWithSignature("setApyBoostMaxDays(uint16)", maxDays);
        vm.prank(multisig);
        _timelockSchedule(address(settings), calldata_, TWO_DAYS_IN_SECONDS);
        _fastforward(TWO_DAYS_IN_SECONDS);

        vm.expectEmit(true, true, false, true, address(settings));
        emit StakeLongApyBoostMaxDaysChanged(admin, maxDays);
        vm.prank(multisig);
        _timelockExecute(address(settings), calldata_);
    }

    function testFuzzSetApyBoostMaxDaysFromAdmin(uint16 maxDays) public {
        vm.assume(maxDays >= 366 && maxDays <= 1825);
        vm.expectEmit(true, true, false, true, address(settings));
        emit StakeLongApyBoostMaxDaysChanged(admin, maxDays);
        vm.prank(admin);
        settings.setApyBoostMaxDays(maxDays);
    }

    // Other
    function testDefaultAdminSettings() public {
        assertEq(settings.hasRole(STAKING_SETTINGS_ADMIN_ROLE, address(timelockAdmin)), true);
    }
}
