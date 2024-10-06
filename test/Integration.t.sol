// solhint-disable ordering
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./Base.t.sol";
import "./Proxy/StakingV2.sol";

contract IntegrationTest is Base, ERC1967UpgradeUpgradeable {
    // contract already running for 155 days
    // alice - 2 stakes (276 days and 35 days)
    // bob -   1 stake (275 days)

    function testMultipleStakers() public {
        _ensureMaxStakingCap();
        uint16 alicePeriod1 = 276;
        uint256 aliceAmount1 = ONE_TOKEN * 1e5;

        uint16 alicePeriod2 = 35;
        uint256 aliceAmount2 = ONE_TOKEN * 1e7;

        uint16 bobPeriod1 = 275;
        uint256 bobAmount1 = ONE_TOKEN * 1e3;

        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 bobBalanceBefore = token.balanceOf(bob);

        _fastforward(155 days);

        uint256 aliceStake1Id = _stakeTokens(alice, NODE_1_ID, aliceAmount1, alicePeriod1);
        uint256 aliceStake2Id = _stakeTokens(alice, NODE_1_ID, aliceAmount2, alicePeriod2);
        uint256 bobStake1Id = _stakeTokens(bob, NODE_1_ID, bobAmount1, bobPeriod1);

        /// @dev need to wait until full epoch ends (276 days ends in a middle of epoch)
        _fastforward(293 days);

        uint16 toEpoch = (155 + 293) / EPOCH_PERIOD_DAYS;
        uint16 fromEpoch = 155 / EPOCH_PERIOD_DAYS;
        for (uint16 epoch = fromEpoch + 1; epoch <= toEpoch; epoch += 1) {
            _addMeasurement(
                epoch,
                NODE_1_ID,
                ((25 * epoch - 1) % 1000) + 25,
                epoch % 29,
                StakingUtils.NodeSlaLevel.Diamond
            );
        }

        uint256 aliceStake1Rewards = 3470048960287488158967;
        uint256 aliceStake2Rewards = 347004896028748815896773;

        vm.expectEmit(true, true, true, true, address(staking));
        emit TokensClaimed(address(alice), aliceStake1Id, aliceStake1Rewards, toEpoch);
        vm.prank(alice);
        staking.claim(aliceStake1Id);

        vm.expectEmit(true, true, true, true, address(staking));
        emit TokensClaimed(address(alice), aliceStake2Id, aliceStake2Rewards, toEpoch);
        vm.prank(alice);
        staking.claim(aliceStake2Id);

        /// @dev due to unlimited epochs everybody will get the same percentage increase

        vm.prank(alice);
        staking.unstakeTokens(aliceStake1Id);

        vm.prank(alice);
        staking.unstakeTokens(aliceStake2Id);

        vm.prank(bob);
        staking.unstakeTokens(bobStake1Id);

        uint256 bobStake1Rewards = 34700489602874881589;

        uint256 contractFinalBalance = CONTRACT_INITIAL_BALANCE -
            aliceStake2Rewards -
            aliceStake1Rewards -
            bobStake1Rewards;

        assertEq(token.balanceOf(address(staking)), contractFinalBalance, "Contract final balance");
        assertEq(
            token.balanceOf(alice),
            aliceBalanceBefore + aliceStake2Rewards + aliceStake1Rewards,
            "Alice final balance"
        );
        assertEq(token.balanceOf(bob), bobBalanceBefore + bobStake1Rewards, "Bob final balance");
    }

    /// Full integration Gnosis Safe - Timelock - {StakingSettings, Staking}
    /// Contract upgrade

    function testUpgradeToNewStaking() public {
        StakingV2 stakingV2 = new StakingV2();

        /// @dev Encode call to staking proxy in order to upgrade
        bytes memory upgradeCalldata = abi.encodeWithSignature("upgradeTo(address)", address(stakingV2));

        /// @dev Encode call to timelock contract in order to schedule upgrade
        bytes memory scheduleCalldata = abi.encodeWithSignature(
            "schedule(address,uint256,bytes,bytes32,bytes32,uint256)",
            address(staking),
            0,
            upgradeCalldata,
            0x0,
            0x0,
            TWO_DAYS_IN_SECONDS
        );

        /// @dev Get 2 out of 3 signatures to approve the schedule upgrade call
        bytes memory signatures = _multisigApprove2of3(address(timelockAdmin), scheduleCalldata, 0);

        /// @dev Schedule the upgrade call
        _multisigExecute(address(timelockAdmin), scheduleCalldata, 0, signatures);

        /// @dev Encode call to timelock contract in order to execute the upgrade
        bytes memory executeCalldata = abi.encodeWithSignature(
            "execute(address,uint256,bytes,bytes32,bytes32)",
            address(staking),
            0,
            upgradeCalldata,
            0x0,
            0x0
        );

        /// @dev Time travel 48 hours
        _fastforward(2 days);

        /// @dev Get 2 of of 3 signature to approve the execute upgrade call
        signatures = _multisigApprove2of3(address(timelockAdmin), executeCalldata, 0);

        vm.expectEmit(true, true, true, true, address(staking));
        emit UpgradeAuthorized(admin, address(staking), address(stakingV2));
        vm.expectEmit(true, false, false, true, address(staking));
        emit Upgraded(address(stakingV2));

        /// @dev Execute the upgrade call
        _multisigExecute(address(timelockAdmin), executeCalldata, 0, signatures);

        /// @dev Make sure upgrade was successful by calling a method that exists only in new implementation
        stakingV2 = StakingV2(address(proxy));
        assertEq(stakingV2.newMethod(), 1);
    }

    /// Full integration Gnosis Safe - Timelock - {StakingSettings, Staking}
    /// Simulate supervisor compromise, revoke malicious supervisor, add new supervisor and override bad measurements

    function testRevokeSupervisorAndOverrideWrongMeasurements() public {
        /// @dev measurements prerequisites - add stake and fast forward one epoch
        _stakeTokens(alice, NODE_1_ID, 1e21, 28);
        _fastforward(28 days);

        uint256 epoch = 1;
        uint24[] memory rps = new uint24[](1);
        uint16[] memory penaltyDays = new uint16[](1);
        uint8[] memory sla = new uint8[](1);
        bytes32[] memory nodeIds = new bytes32[](1);
        nodeIds[0] = NODE_1_ID;

        bytes memory signatures;

        /// @dev Simulate supervisor compromise that submits fake measurement values
        {
            vm.prank(supervisor);
            rps[0] = MAX_RPS;
            penaltyDays[0] = 0;
            sla[0] = uint8(StakingUtils.NodeSlaLevel.Diamond);
            staking.addMeasurements(epoch, nodeIds, rps, penaltyDays, sla);
        }

        /// @dev Admin detected above scenario and starts revoking supervisor
        /// @dev Encode call to staking proxy in order to revokeRole
        bytes memory revokeRoleCalldata = abi.encodeWithSignature(
            "revokeRole(bytes32,address)",
            SUPERVISOR_ROLE,
            supervisor
        );
        /// @dev Encode call to staking proxy in order to grantRole
        bytes memory grantRoleCalldata = abi.encodeWithSignature(
            "grantRole(bytes32,address)",
            SUPERVISOR_ROLE,
            newSupervisor
        );

        /// @dev Schedule revokeRole call
        {
            /// @dev Encode call to timelock contract in order to schedule revokeRole
            bytes memory scheduleRevokeCalldata = abi.encodeWithSignature(
                "schedule(address,uint256,bytes,bytes32,bytes32,uint256)",
                address(staking),
                0,
                revokeRoleCalldata,
                0x0,
                0x0,
                TWO_DAYS_IN_SECONDS
            );

            /// @dev Get 2 out of 3 signatures to approve the schedule revokeRole call
            signatures = _multisigApprove2of3(address(timelockAdmin), scheduleRevokeCalldata, 0);

            /// @dev Schedule the revokeRole call
            _multisigExecute(address(timelockAdmin), scheduleRevokeCalldata, 0, signatures);
        }

        /// @dev Schedule grantRole call
        {
            /// @dev Encode call to timelock contract in order to schedule grantRole
            bytes memory scheduleGrantCalldata = abi.encodeWithSignature(
                "schedule(address,uint256,bytes,bytes32,bytes32,uint256)",
                address(staking),
                0,
                grantRoleCalldata,
                0x0,
                0x0,
                TWO_DAYS_IN_SECONDS
            );

            signatures = _multisigApprove2of3(address(timelockAdmin), scheduleGrantCalldata, 0);
            /// @dev Schedule the grantRole call
            _multisigExecute(address(timelockAdmin), scheduleGrantCalldata, 0, signatures);
        }

        /// @dev Time travel 48 hours
        _fastforward(2 days);

        /// @dev Execute revokeRole call
        {
            /// @dev Encode call to timelock contract in order to execute the revokeRole call
            bytes memory executeRevokeCalldata = abi.encodeWithSignature(
                "execute(address,uint256,bytes,bytes32,bytes32)",
                address(staking),
                0,
                revokeRoleCalldata,
                0x0,
                0x0
            );

            /// @dev Get 2 of of 3 signature to approve the execute revokeRole call
            signatures = _multisigApprove2of3(address(timelockAdmin), executeRevokeCalldata, 0);

            vm.expectEmit(true, true, true, true, address(staking));
            emit RoleRevoked(SUPERVISOR_ROLE, supervisor, address(timelockAdmin));

            /// @dev Execute the revokeRole call
            _multisigExecute(address(timelockAdmin), executeRevokeCalldata, 0, signatures);
        }

        /// @dev Execute grantRole call
        {
            /// @dev Encode call to timelock contract in order to execute the grantRole call
            bytes memory executeGrantCalldata = abi.encodeWithSignature(
                "execute(address,uint256,bytes,bytes32,bytes32)",
                address(staking),
                0,
                grantRoleCalldata,
                0x0,
                0x0
            );

            /// @dev Get 2 of of 3 signature to approve the execute grantRole call
            signatures = _multisigApprove2of3(address(timelockAdmin), executeGrantCalldata, 0);

            vm.expectEmit(true, true, true, true, address(staking));
            emit RoleGranted(SUPERVISOR_ROLE, newSupervisor, address(timelockAdmin));

            /// @dev Execute the grantRole call
            _multisigExecute(address(timelockAdmin), executeGrantCalldata, 0, signatures);
        }

        /// @dev Make sure old supervisor can't submit any more measurements
        vm.prank(supervisor);
        vm.expectRevert("Caller is not a supervisor");
        staking.addMeasurements(epoch, nodeIds, rps, penaltyDays, sla);

        /// @dev Now override with the correct measurements from new supervisor
        {
            vm.prank(newSupervisor);
            uint24[] memory newRps = new uint24[](1);
            newRps[0] = 100;
            uint16[] memory newPenaltyDays = new uint16[](1);
            newPenaltyDays[0] = 5;
            uint8[] memory newSla = new uint8[](1);
            newSla[0] = uint8(StakingUtils.NodeSlaLevel.Silver);
            vm.expectEmit(true, true, true, true, address(staking));
            emit NodeMeasurementSlaChanged(
                NODE_1_ID,
                StakingUtils.NodeSlaLevel(sla[0]),
                StakingUtils.NodeSlaLevel(newSla[0]),
                epoch
            );
            vm.expectEmit(true, true, true, true, address(staking));
            emit NodeMeasurementRpsChanged(NODE_1_ID, rps[0], newRps[0], epoch);
            vm.expectEmit(true, true, true, true, address(staking));
            emit NodeMeasurementPenaltyDaysChanged(NODE_1_ID, penaltyDays[0], newPenaltyDays[0], epoch);
            vm.expectEmit(true, true, true, true, address(staking));
            emit NodeMeasured(NODE_1_ID, newRps[0], newPenaltyDays[0], StakingUtils.NodeSlaLevel(newSla[0]), epoch);
            staking.addMeasurements(epoch, nodeIds, newRps, newPenaltyDays, newSla);
        }
    }
}
