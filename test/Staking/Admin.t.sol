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

    function testEmergencyPauseFromMultisig() public {
        bytes memory calldata_ = abi.encodeWithSignature("emergencyPause()");
        vm.prank(multisig);
        _timelockSchedule(address(staking), calldata_, TWO_DAYS_IN_SECONDS);
        _fastforward(TWO_DAYS_IN_SECONDS);

        vm.expectEmit(true, false, false, true, address(staking));
        emit EmergencyPause(admin);
        vm.prank(multisig);
        _timelockExecute(address(staking), calldata_);
        assertEq(staking.paused(), true);
    }

    function testEmergencyPauseFromAdmin() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, true, address(staking));
        emit EmergencyPause(admin);
        staking.emergencyPause();
        assertEq(staking.paused(), true);
    }

    function testEmergencyResumeFromMultisig() public {
        // Pre-requisites
        vm.prank(admin);
        staking.emergencyPause();

        bytes memory calldata_ = abi.encodeWithSignature("emergencyResume()");
        vm.prank(multisig);
        _timelockSchedule(address(staking), calldata_, TWO_DAYS_IN_SECONDS);
        _fastforward(TWO_DAYS_IN_SECONDS);

        vm.expectEmit(true, false, false, true, address(staking));
        emit EmergencyResume(admin);
        vm.prank(multisig);
        _timelockExecute(address(staking), calldata_);
        assertEq(staking.paused(), false);
    }

    function testEmergencyResumeFromAdmin() public {
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

    function testFuzzEmergencyWithdrawFromMultisig(uint256 amount) public {
        vm.assume(ONE_TOKEN < amount && amount <= ONE_TOKEN * 1e6 * 5);

        // Pre-requisites
        vm.prank(admin);
        staking.emergencyPause();

        uint256 balanceBefore = token.balanceOf(admin);
        bytes32 reason = 0x00;

        bytes memory calldata_ = abi.encodeWithSignature("emergencyWithdraw(uint256,bytes32)", amount, reason);
        vm.prank(multisig);
        _timelockSchedule(address(staking), calldata_, TWO_DAYS_IN_SECONDS);
        _fastforward(TWO_DAYS_IN_SECONDS);

        vm.prank(multisig);
        vm.expectEmit(true, true, true, true, address(staking));
        emit EmergencyTokenWithdraw(admin, reason, amount);
        _timelockExecute(address(staking), calldata_);

        // Make sure balances reflect that
        assertEq(token.balanceOf(admin), balanceBefore + amount);
    }

    function testFuzzEmergencyWithdrawFromAdmin(uint256 amount) public {
        vm.assume(ONE_TOKEN < amount && amount <= ONE_TOKEN * 1e6 * 5);
        vm.startPrank(admin);
        staking.emergencyPause();
        uint256 balanceBefore = token.balanceOf(admin);
        bytes32 reason = 0x00;
        vm.expectEmit(true, true, true, true, address(staking));
        emit EmergencyTokenWithdraw(admin, reason, amount);
        staking.emergencyWithdraw(amount, reason); // 5M tokens

        // Make sure balances reflect that
        assertEq(token.balanceOf(admin), balanceBefore + amount);
    }

    // supervisor management

    function testRevertIfNotAdminAddSupervisor() public {
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(address(0x0000000000000000000000000000000000000001)),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(STAKING_ADMIN_ROLE), 32)
            )
        );
        vm.prank(address(1));
        staking.grantRole(SUPERVISOR_ROLE, alice);
    }

    function testRevertIfNotAdminRemoveSupervisor() public {
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(address(0x0000000000000000000000000000000000000001)),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(STAKING_ADMIN_ROLE), 32)
            )
        );
        vm.prank(address(1));
        staking.revokeRole(SUPERVISOR_ROLE, alice);
    }

    function testRevertStakingCantGrantOtherAdmins() public {
        vm.prank(address(timelockAdmin));
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(address(timelockAdmin)),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(DEFAULT_ADMIN_ROLE), 32)
            )
        );
        staking.grantRole(STAKING_ADMIN_ROLE, alice);
    }

    function testAdminCanRevokeSupervisor() public {
        /// @notice admin is the same as address(timelockAdmin)
        vm.prank(address(timelockAdmin));
        vm.expectEmit(true, true, true, true, address(staking));
        emit RoleRevoked(SUPERVISOR_ROLE, supervisor, address(timelockAdmin));
        staking.revokeRole(SUPERVISOR_ROLE, supervisor);
    }

    function testAdminCanGrantSupervisor() public {
        vm.prank(address(timelockAdmin));
        vm.expectEmit(true, true, true, true, address(staking));
        emit RoleGranted(SUPERVISOR_ROLE, alice, address(timelockAdmin));
        staking.grantRole(SUPERVISOR_ROLE, alice);
        assertEq(staking.hasRole(SUPERVISOR_ROLE, alice), true);
    }

    // min staking

    function testFuzzSetMinStakingFromMultisig(uint256 amount) public {
        /// @dev max staking per node default
        vm.assume(amount <= 1e8 * 1e18 && amount > 0);

        bytes memory calldata_ = abi.encodeWithSignature("setMinStakingAmount(uint256)", amount);
        vm.prank(multisig);
        _timelockSchedule(address(settings), calldata_, TWO_DAYS_IN_SECONDS);
        _fastforward(TWO_DAYS_IN_SECONDS);

        vm.expectEmit(true, true, false, true, address(settings));
        emit MinStakingAmountChanged(admin, amount);
        vm.prank(multisig);
        _timelockExecute(address(settings), calldata_);

        uint16 period = EPOCH_PERIOD_DAYS;
        _stakeTokens(alice, NODE_1_ID, amount, period);
    }

    function testFuzzSetMinStakingFromAdmin(uint256 amount) public {
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

    // other

    function testDefaultAdminStaking() public {
        assertEq(staking.hasRole(STAKING_ADMIN_ROLE, address(timelockAdmin)), true);
    }

    function testVerifyStartEpoch() public {
        assertEq(staking.getContractStartTimestamp(), deployTimestamp);
    }
}
