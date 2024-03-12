// solhint-disable ordering
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./ClaimBase.t.sol";

/// @notice claiming should fail or be reverted
contract ClaimFailTest is ClaimBase {
    function testRevertIfStakeNotExistsClaim() public {
        uint256 stakeId = 1;

        vm.prank(alice);
        vm.expectRevert("Not authorized");
        staking.claim(stakeId);
    }

    function testRevertIfImmediatelyClaim() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);

        vm.prank(alice);
        vm.expectRevert("Nothing to claim");
        staking.claim(stakeId);
    }

    function testRevertIfNotStakerClaim() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(30 days);

        _addMeasurement(1, NODE_1_ID, 1000, 0, Staking.NodeSlaLevel.Diamond);

        vm.prank(bob);
        vm.expectRevert("Not authorized");
        staking.claim(stakeId);
    }

    function testRevertIfAlreadyClaimedClaim() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(28 days);

        _addMeasurement(1, NODE_1_ID, 1000, 0, Staking.NodeSlaLevel.Diamond);

        vm.startPrank(alice);
        staking.claim(stakeId);

        vm.expectRevert("Nothing to claim");
        staking.claim(stakeId);
    }

    function testRevertIfAlreadyUnstakedClaim() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(28 days);

        _addMeasurement(1, NODE_1_ID, 1000, 0, Staking.NodeSlaLevel.Diamond);

        vm.startPrank(alice);
        staking.unstakeTokens(stakeId);

        vm.expectRevert("Already withdrawn");
        staking.claim(stakeId);
    }

    function testRevertIfTooEarlyClaim() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(27 days);

        vm.prank(alice);
        vm.expectRevert("Nothing to claim");
        staking.claim(stakeId);
    }

    function testRevertIfNoMeasurementClaim() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(28 days);

        vm.prank(alice);
        vm.expectRevert("Nothing to claim");
        staking.claim(stakeId);
    }
}
