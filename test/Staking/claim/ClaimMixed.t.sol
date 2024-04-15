// solhint-disable ordering
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./ClaimBase.t.sol";

/// @notice claiming when both penalty and reward is applied
contract ClaimMixedTest is ClaimBase {
    /// @dev more epochs to be claim, but claim only measured
    function testOnlyMeasured() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28 * 2;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(56 days);

        _addMeasurement(1, NODE_1_ID, 1000, 14, StakingUtils.NodeSlaLevel.Diamond);

        uint256 penaltyAmount = 19654799409112110000000;
        uint256 rewardAmount = 54856312083274330000000;
        uint256 claimAmount = rewardAmount - penaltyAmount;

        _expectClaimEvents(alice, stakeId, true, claimAmount, 1, 1);

        vm.prank(alice);
        staking.claim(stakeId);

        _expectBalances(alice, stakeId, CONTRACT_INITIAL_BALANCE, stakerBalanceBefore, stakeAmount, true, claimAmount);
    }

    function testManyEpochsLaterStart() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        _fastforward(336 days);
        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(28 days);
        _addMeasurement(13, NODE_1_ID, 1000, 14, StakingUtils.NodeSlaLevel.Diamond);

        uint256 penaltyAmount = 19654799409112110000000;
        uint256 rewardAmount = 54856312083274330000000;
        uint256 claimAmount = rewardAmount - penaltyAmount;

        _expectClaimEvents(alice, stakeId, true, claimAmount, 13, 13);

        vm.prank(alice);
        staking.claim(stakeId);

        _expectBalances(alice, stakeId, CONTRACT_INITIAL_BALANCE, stakerBalanceBefore, stakeAmount, true, claimAmount);
    }

    function testMidEpochStartClaimHalf() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        _fastforward(14 days);
        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(14 days);
        _addMeasurement(1, NODE_1_ID, 1000, 14, StakingUtils.NodeSlaLevel.Diamond);

        uint256 claimAmount = 17585294208459970000000;
        _expectClaimEvents(alice, stakeId, true, claimAmount, 1, 1);

        vm.prank(alice);
        staking.claim(stakeId);

        _expectBalances(alice, stakeId, CONTRACT_INITIAL_BALANCE, stakerBalanceBefore, stakeAmount, true, claimAmount);
    }

    function testMidEpochStartClaimAllAtOnce() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        _fastforward(14 days);
        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(42 days);
        _addMeasurement(1, NODE_1_ID, 1000, 14, StakingUtils.NodeSlaLevel.Diamond);
        _addMeasurement(2, NODE_1_ID, 1000, 14, StakingUtils.NodeSlaLevel.Diamond);

        uint256 claimAmount = 52848709778317987511840;
        _expectClaimEvents(alice, stakeId, true, claimAmount, 1, 2);

        vm.prank(alice);
        staking.claim(stakeId);

        _expectBalances(alice, stakeId, CONTRACT_INITIAL_BALANCE, stakerBalanceBefore, stakeAmount, true, claimAmount);
    }

    /// @dev should claim if more measurements are submitted
    function testClaimExtraMeasurements() public {
        uint256 aliceAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, aliceAmount, period);
        _fastforward(56 days);

        _addMeasurementsEpochInterval(1, 2, NODE_1_ID, 1000, 14, StakingUtils.NodeSlaLevel.Diamond);

        uint256 claimAmount = 70526939997779360340904;

        _expectClaimEvents(alice, stakeId, true, claimAmount, 1, 2);

        vm.prank(alice);
        staking.claim(stakeId);

        _expectBalances(
            alice,
            stakeId,
            CONTRACT_INITIAL_BALANCE, // + bobAmount,
            stakerBalanceBefore,
            aliceAmount,
            true,
            claimAmount
        );
    }

    function testSingleEpoch() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(28 days);

        _addMeasurement(1, NODE_1_ID, 1000, 14, StakingUtils.NodeSlaLevel.Diamond);

        uint256 penaltyAmount = 19654799409112110000000;
        uint256 rewardAmount = 54856312083274330000000;
        uint256 claimAmount = rewardAmount - penaltyAmount;

        _expectClaimEvents(alice, stakeId, true, claimAmount, 1, 1);

        vm.prank(alice);
        staking.claim(stakeId);

        uint256 stakerFinalBalance = stakerBalanceBefore - stakeAmount + claimAmount;

        uint256 contractFinalBalance = CONTRACT_INITIAL_BALANCE + stakeAmount - claimAmount;
        assertEq(token.balanceOf(alice), stakerFinalBalance);
        assertEq(token.balanceOf(address(staking)), contractFinalBalance);
        assertEq(staking.getStake(stakeId).amount, stakeAmount);
    }

    /// @notice claim rewards in two separate claims
    function testMidEpochStartSeparateBothEpoch() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        _fastforward(14 days);
        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(14 days);
        _addMeasurement(1, NODE_1_ID, 1000, 14, StakingUtils.NodeSlaLevel.Diamond);

        /// @notice First claim

        uint256 claimAmount = 17585294208459970000000;
        _expectClaimEvents(alice, stakeId, true, claimAmount, 1, 1);

        vm.prank(alice);
        staking.claim(stakeId);

        /// @notice Second claim

        _fastforward(28 days);
        _addMeasurement(2, NODE_1_ID, 1000, 14, StakingUtils.NodeSlaLevel.Diamond);

        uint256 claimAmount2 = 35201512674162220000000;
        _expectClaimEvents(alice, stakeId, true, claimAmount2, 2, 2);

        vm.prank(alice);
        staking.claim(stakeId);

        _expectBalances(
            alice,
            stakeId,
            CONTRACT_INITIAL_BALANCE,
            stakerBalanceBefore,
            stakeAmount,
            true,
            claimAmount + claimAmount2
        );
    }

    function testMultipleEpochs() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28 * 12;
        uint256 epochCount = (uint256(period) * 1 days) / EPOCH_PERIOD_SECONDS;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(uint256(period) * 1 days);

        /// @dev APY is at max 15.33%
        _addMeasurementsEpochInterval(1, epochCount, NODE_1_ID, 1000, 14, StakingUtils.NodeSlaLevel.Diamond);

        uint256 claimAmount = 430693246945343107337685;

        _expectClaimEvents(alice, stakeId, true, claimAmount, 1, 12);

        vm.prank(alice);
        staking.claim(stakeId);

        _expectBalances(alice, stakeId, CONTRACT_INITIAL_BALANCE, stakerBalanceBefore, stakeAmount, true, claimAmount);
    }

    function testMultiplePoorRpsEpochs() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28 * 12;
        uint256 epochCount = (uint256(period) * 1 days) / EPOCH_PERIOD_SECONDS;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(uint256(period) * 1 days);

        /// @dev APY is at min 3.0502%
        _addMeasurementsEpochInterval(1, epochCount, NODE_1_ID, 25, 14, StakingUtils.NodeSlaLevel.Diamond);

        uint256 absClaimAmount = 97048839250432841550024;

        _expectClaimEvents(alice, stakeId, false, absClaimAmount, 1, 12);

        vm.prank(alice);
        staking.claim(stakeId);

        _expectBalances(
            alice,
            stakeId,
            CONTRACT_INITIAL_BALANCE,
            stakerBalanceBefore,
            stakeAmount,
            false,
            absClaimAmount
        );
    }

    function testSmallMinStakingPoorRps() public {
        uint256 stakeAmount = 1;
        uint16 period = 28;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        vm.prank(admin);
        settings.setMinStakingAmount(stakeAmount);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(uint256(period) * 1 days);

        _addMeasurementsEpochInterval(1, 1, NODE_1_ID, 25, 14, StakingUtils.NodeSlaLevel.Diamond);

        uint256 claimAmount = 0;
        _expectClaimEvents(alice, stakeId, true, claimAmount, 1, 1);

        vm.prank(alice);
        staking.claim(stakeId);

        _expectBalances(alice, stakeId, CONTRACT_INITIAL_BALANCE, stakerBalanceBefore, stakeAmount, true, claimAmount);
    }
}
