// solhint-disable ordering
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./ClaimBase.t.sol";

/// @notice claiming using claim(stakeId, epochs) method
contract ClaimLimitedEpochsTest is ClaimBase {
    function testClaimOneAndOneAvailable() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28 * 1;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(28 days);

        _addMeasurement(1, NODE_1_ID, 1000, 0, StakingUtils.NodeSlaLevel.Diamond);

        uint256 claimAmount = 110013545664089160000000;
        _expectClaimEvents(alice, stakeId, true, claimAmount, 1, 1);

        vm.prank(alice);
        staking.claim(stakeId, 1);

        _expectBalances(alice, stakeId, CONTRACT_INITIAL_BALANCE, stakerBalanceBefore, stakeAmount, true, claimAmount);
    }

    function testOnlyMeasured() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28 * 2;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(56 days);

        _addMeasurement(1, NODE_1_ID, 1000, 0, StakingUtils.NodeSlaLevel.Diamond);

        uint256 claimAmount = 110013545664089160000000;
        _expectClaimEvents(alice, stakeId, true, claimAmount, 1, 1);

        vm.prank(alice);
        staking.claim(stakeId, 1);

        _expectBalances(alice, stakeId, CONTRACT_INITIAL_BALANCE, stakerBalanceBefore, stakeAmount, true, claimAmount);
    }

    function testManyEpochsLaterStart() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        _fastforward(336 days);
        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(28 days);
        _addMeasurement(13, NODE_1_ID, 1000, 0, StakingUtils.NodeSlaLevel.Diamond);

        uint256 claimAmount = 110013545664089160000000;
        _expectClaimEvents(alice, stakeId, true, claimAmount, 13, 13);

        vm.prank(alice);
        staking.claim(stakeId, 1);

        _expectBalances(alice, stakeId, CONTRACT_INITIAL_BALANCE, stakerBalanceBefore, stakeAmount, true, claimAmount);
    }

    function testMidEpochStartClaimHalf() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        _fastforward(14 days);
        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(14 days);
        _addMeasurement(1, NODE_1_ID, 1000, 0, StakingUtils.NodeSlaLevel.Diamond);

        // perfect precision  54856312083277046086630
        uint256 claimAmount = 54856312083274330000000;
        _expectClaimEvents(alice, stakeId, true, claimAmount, 1, 1);

        vm.prank(alice);
        staking.claim(stakeId, 1);

        _expectBalances(alice, stakeId, CONTRACT_INITIAL_BALANCE, stakerBalanceBefore, stakeAmount, true, claimAmount);
    }

    function testMidEpochStartClaimAllAtOnce() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        _fastforward(14 days);
        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(42 days);
        _addMeasurement(1, NODE_1_ID, 1000, 0, StakingUtils.NodeSlaLevel.Diamond);
        _addMeasurement(2, NODE_1_ID, 1000, 0, StakingUtils.NodeSlaLevel.Diamond);

        uint256 claimAmount = 165473351486797172646287;
        _expectClaimEvents(alice, stakeId, true, claimAmount, 1, 2);

        vm.prank(alice);
        staking.claim(stakeId, 2);

        _expectBalances(alice, stakeId, CONTRACT_INITIAL_BALANCE, stakerBalanceBefore, stakeAmount, true, claimAmount);
    }

    function testClaimOnlyFirstEpochButMoreAvailable() public {
        uint256 aliceAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, aliceAmount, period);
        _fastforward(56 days);

        _addMeasurementsEpochInterval(1, 2, NODE_1_ID, 1000, 0, StakingUtils.NodeSlaLevel.Diamond);

        uint256 claimAmount = 110013545664089160000000;
        _expectClaimEvents(alice, stakeId, true, claimAmount, 1, 1);

        vm.prank(alice);
        staking.claim(stakeId, 1);

        _expectBalances(alice, stakeId, CONTRACT_INITIAL_BALANCE, stakerBalanceBefore, aliceAmount, true, claimAmount);
    }
}
