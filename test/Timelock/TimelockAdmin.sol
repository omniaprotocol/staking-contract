// solhint-disable ordering
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../Base.t.sol";

contract AdminTest is Base, IStakingSettingsEvents {
    function testRevertInvalidAddress() public {
        vm.prank(alice);
        /// @dev Try deploy timelock with EOA as proposal/executor/canceller
        address[] memory proposersExecutorsCancellers = new address[](1);
        proposersExecutorsCancellers[0] = alice;
        vm.expectRevert("Proposer/Executor/Canceller must be a live contract");
        new TimelockAdmin(proposersExecutorsCancellers);
    }

    function testDeployWithGnosisAsProposer() public {
        address gnosiSafeAdmin = address(adminMultiSig);
        /// @dev Try deploy timelock with Gnosis Safe as proposal/executor/canceller
        address[] memory proposersExecutorsCancellers = new address[](1);
        proposersExecutorsCancellers[0] = gnosiSafeAdmin;
        /// @dev Ensure proper min delay was set
        vm.expectEmit(true, true, false, true);
        emit MinDelayChange(0, TWO_DAYS_IN_SECONDS);
        TimelockAdmin timelock = new TimelockAdmin(proposersExecutorsCancellers);

        /// @dev Ensure proper roles have been set
        assertTrue(timelock.hasRole(PROPOSER_ROLE, gnosiSafeAdmin));
        assertTrue(timelock.hasRole(EXECUTOR_ROLE, gnosiSafeAdmin));
        assertTrue(timelock.hasRole(CANCELLER_ROLE, gnosiSafeAdmin));
    }

    function testEnsureTimelockIsSelfAdministrating() public {
        address gnosiSafeAdmin = address(adminMultiSig);
        address[] memory proposersExecutorsCancellers = new address[](1);
        proposersExecutorsCancellers[0] = gnosiSafeAdmin;
        /// Deploy timelock
        TimelockAdmin timelock = new TimelockAdmin(proposersExecutorsCancellers);

        /// Ensure proposers/executors/cancellers have TIMELOCK_ADMIN_ROLE as admin
        assertEq(TIMELOCK_ADMIN_ROLE, timelock.getRoleAdmin(PROPOSER_ROLE));
        assertEq(TIMELOCK_ADMIN_ROLE, timelock.getRoleAdmin(EXECUTOR_ROLE));
        assertEq(TIMELOCK_ADMIN_ROLE, timelock.getRoleAdmin(CANCELLER_ROLE));

        // Ensure TIMELOCK_ADMIN_ROLE is the contract itself
        assertTrue(timelock.hasRole(TIMELOCK_ADMIN_ROLE, address(timelock)));
    }

    function testRevertProposalInvalidDelay() public {
        bytes memory emptyPayload;
        uint256 delay = 1 days;
        vm.prank(address(adminMultiSig));
        vm.expectRevert("TimelockController: insufficient delay");
        _timelockSchedule(address(staking), emptyPayload, delay);
    }

    function testPerformSensitiveOperation() public {
        /// @dev Try change min stake amount on stake settings
        uint256 newMinAmount = ONE_TOKEN * 2e4;
        bytes memory payload = abi.encodeWithSignature("setMinStakingAmount(uint256)", newMinAmount);
        vm.prank(address(adminMultiSig));
        _timelockSchedule(address(settings), payload, 2 days);
        _fastforward(2 days);
        vm.prank(address(adminMultiSig));
        vm.expectEmit(true, true, false, true, address(settings));
        emit MinStakingAmountChanged(address(timelockAdmin), newMinAmount);
        _timelockExecute(address(settings), payload);
    }

    function testRevertExecuteTooEarly() public {
        /// @dev Try change min stake amount
        uint256 newMinAmount = ONE_TOKEN * 2e4;
        bytes memory payload = abi.encodeWithSignature("setMinStakingAmount(uint256)", newMinAmount);
        vm.prank(address(adminMultiSig));
        _timelockSchedule(address(settings), payload, 2 days);
        /// @dev fast forward only 1 day
        _fastforward(1 days);
        vm.prank(address(adminMultiSig));
        vm.expectRevert("TimelockController: operation is not ready");
        _timelockExecute(address(settings), payload);
    }
}
