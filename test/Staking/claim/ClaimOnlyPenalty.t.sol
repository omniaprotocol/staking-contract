// solhint-disable ordering
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./ClaimBase.t.sol";

/// @notice claiming when only penalty exists (no rewards - 28 penalty days)
contract ClaimOnlyPenaltyTest is ClaimBase {
    /// @dev more epochs to be claim, but claim only measured
    function testOnlyMeasured() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28 * 2;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(56 days);

        _addMeasurement(1, NODE_1_ID, 1000, 28, StakingUtils.NodeSlaLevel.Diamond);

        uint256 penaltyAmount = 39270967704245690000000;
        _expectClaimEvents(alice, stakeId, false, penaltyAmount, 1, 1);

        vm.prank(alice);
        staking.claim(stakeId);

        _expectBalances(
            alice,
            stakeId,
            CONTRACT_INITIAL_BALANCE,
            stakerBalanceBefore,
            stakeAmount,
            false,
            penaltyAmount
        );
    }

    function testManyEpochsLaterStart() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        _fastforward(336 days);
        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(28 days);
        _addMeasurement(13, NODE_1_ID, 1000, 28, StakingUtils.NodeSlaLevel.Diamond);

        uint256 penaltyAmount = 39270967704245690000000;
        _expectClaimEvents(alice, stakeId, false, penaltyAmount, 13, 13);

        vm.prank(alice);
        staking.claim(stakeId);

        _expectBalances(
            alice,
            stakeId,
            CONTRACT_INITIAL_BALANCE,
            stakerBalanceBefore,
            stakeAmount,
            false,
            penaltyAmount
        );
    }

    function testMidEpochStartClaimHalf() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        _fastforward(14 days);
        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(14 days);
        _addMeasurement(1, NODE_1_ID, 1000, 28, StakingUtils.NodeSlaLevel.Diamond);

        uint256 penaltyAmount = 19654799409111920000000;
        _expectClaimEvents(alice, stakeId, false, penaltyAmount, 1, 1);

        vm.prank(alice);
        staking.claim(stakeId);

        _expectBalances(
            alice,
            stakeId,
            CONTRACT_INITIAL_BALANCE,
            stakerBalanceBefore,
            stakeAmount,
            false,
            penaltyAmount
        );
    }

    function testMidEpochStartClaimAllAtOnce() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        _fastforward(14 days);
        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(42 days);
        _addMeasurement(1, NODE_1_ID, 1000, 28, StakingUtils.NodeSlaLevel.Diamond);
        _addMeasurement(2, NODE_1_ID, 1000, 28, StakingUtils.NodeSlaLevel.Diamond);

        uint256 penaltyAmount = 58848580814074743851869;
        _expectClaimEvents(alice, stakeId, false, penaltyAmount, 1, 2);

        vm.prank(alice);
        staking.claim(stakeId);

        _expectBalances(
            alice,
            stakeId,
            CONTRACT_INITIAL_BALANCE,
            stakerBalanceBefore,
            stakeAmount,
            false,
            penaltyAmount
        );
    }

    /// @dev should claim if more measurements are submitted
    function testClaimExtraMeasurements() public {
        uint256 aliceAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, aliceAmount, period);
        _fastforward(56 days);

        _addMeasurementsEpochInterval(1, 2, NODE_1_ID, 1000, 28, StakingUtils.NodeSlaLevel.Diamond);

        uint256 penaltyAmount = 78387714518048589200027;
        _expectClaimEvents(alice, stakeId, false, penaltyAmount, 1, 1);

        vm.prank(alice);
        staking.claim(stakeId);

        _expectBalances(
            alice,
            stakeId,
            CONTRACT_INITIAL_BALANCE,
            stakerBalanceBefore,
            aliceAmount,
            false,
            penaltyAmount
        );
    }

    function testSingleEpoch() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(30 days);

        _addMeasurement(1, NODE_1_ID, 1000, 28, StakingUtils.NodeSlaLevel.Diamond);

        uint256 penaltyAmount = 39270967704245690000000;
        _expectClaimEvents(alice, stakeId, false, penaltyAmount, 1, 1);

        vm.prank(alice);
        staking.claim(stakeId);

        _expectBalances(
            alice,
            stakeId,
            CONTRACT_INITIAL_BALANCE,
            stakerBalanceBefore,
            stakeAmount,
            false,
            penaltyAmount
        );
    }

    function testMultipleEpochs() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28 * 12;
        uint256 epochCount = (uint256(period) * 1 days) / EPOCH_PERIOD_SECONDS;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(uint256(period) * 1 days);

        _addMeasurementsEpochInterval(1, epochCount, NODE_1_ID, 1000, 28, StakingUtils.NodeSlaLevel.Diamond);

        // exact should be      461205104612707397093815... losing precision due to power
        uint256 penaltyAmount = 461205104612678141898112;
        _expectClaimEvents(alice, stakeId, false, penaltyAmount, 1, 12);

        vm.prank(alice);
        staking.claim(stakeId);

        _expectBalances(
            alice,
            stakeId,
            CONTRACT_INITIAL_BALANCE,
            stakerBalanceBefore,
            stakeAmount,
            false,
            penaltyAmount
        );
    }

    function testMultiplePoorRpsEpochs() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28 * 13;
        uint256 epochCount = (uint256(period) * 1 days) / EPOCH_PERIOD_SECONDS;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(uint256(period) * 1 days);

        /// @dev APY is at min 3.0502%
        _addMeasurementsEpochInterval(1, epochCount, NODE_1_ID, 25, 28, StakingUtils.NodeSlaLevel.Diamond);

        uint256 penaltyAmount = 498664875240096058075954;
        _expectClaimEvents(alice, stakeId, false, penaltyAmount, 1, 13);

        vm.prank(alice);
        staking.claim(stakeId);

        _expectBalances(
            alice,
            stakeId,
            CONTRACT_INITIAL_BALANCE,
            stakerBalanceBefore,
            stakeAmount,
            false,
            penaltyAmount
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

        _addMeasurementsEpochInterval(1, 1, NODE_1_ID, 25, 28, StakingUtils.NodeSlaLevel.Diamond);

        uint256 claimAmount = 0;
        /// @dev 0 amount is considered a reward so no PenaltyApplied event
        _expectClaimEvents(alice, stakeId, true, claimAmount, 1, 1);

        vm.prank(alice);
        staking.claim(stakeId);

        _expectBalances(alice, stakeId, CONTRACT_INITIAL_BALANCE, stakerBalanceBefore, stakeAmount, true, claimAmount);
    }

    function testChangedPenaltyRate() public {
        vm.prank(admin);
        settings.setPenaltyRate(9999);

        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(period * 1 days);

        _addMeasurement(1, NODE_1_ID, 1000, 28, StakingUtils.NodeSlaLevel.Silver);

        uint256 claimAmount = 5066550523681165630000000;
        _expectClaimEvents(alice, stakeId, false, claimAmount, 1, 1);

        vm.prank(alice);
        staking.claim(stakeId);

        _expectBalances(alice, stakeId, CONTRACT_INITIAL_BALANCE, stakerBalanceBefore, stakeAmount, false, claimAmount);
    }

    function testZeroPenaltyRate() public {
        vm.prank(admin);
        settings.setPenaltyRate(0);

        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(period * 1 days);

        _addMeasurement(1, NODE_1_ID, 1000, 28, StakingUtils.NodeSlaLevel.Silver);

        uint256 claimAmount = 0;
        /// @dev 0 amount is considered a reward so no PenaltyApplied event
        _expectClaimEvents(alice, stakeId, true, claimAmount, 1, 1);

        vm.prank(alice);
        staking.claim(stakeId);

        _expectBalances(alice, stakeId, CONTRACT_INITIAL_BALANCE, stakerBalanceBefore, stakeAmount, true, claimAmount);
    }
}
