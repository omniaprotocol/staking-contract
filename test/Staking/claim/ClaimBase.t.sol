// solhint-disable ordering
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../Base.t.sol";

contract ClaimBase is Base {
    function _expectClaimEvents(
        address staker,
        uint256 stakeId,
        bool isGain,
        uint256 claimAmount,
        uint16 fromEpoch,
        uint16 toEpoch
    ) internal {
        for (uint16 epoch = fromEpoch; epoch <= toEpoch; epoch += 1) {
            vm.expectEmit(true, true, true, true, address(staking));
            emit EpochClaimed(staker, stakeId, epoch);
        }

        if (isGain) {
            vm.expectEmit(true, true, true, true, address(staking));
            emit TokensClaimed(staker, stakeId, claimAmount, toEpoch);
        } else {
            vm.expectEmit(true, true, true, true, address(staking));
            emit PenaltyApplied(staker, stakeId, claimAmount);
        }
    }

    function _expectBalances(
        address staker,
        uint256 stakeId,
        uint256 contractInitialBalance,
        uint256 stakerInitialBalance,
        uint256 stakeAmount,
        bool isGain,
        uint256 claimAmount
    ) internal {
        uint256 stakerFinalBalance = stakerInitialBalance - stakeAmount + (isGain ? claimAmount : 0);
        uint256 contractFinalBalance = contractInitialBalance + stakeAmount - (isGain ? claimAmount : 0);
        uint256 stakeFinalBalance = isGain ? stakeAmount : stakeAmount - claimAmount;

        assertEq(token.balanceOf(staker), stakerFinalBalance);
        assertEq(token.balanceOf(address(staking)), contractFinalBalance);
        assertEq(staking.getStake(stakeId).amount, stakeFinalBalance);
    }

    function testFuzzSimulateClaimRewards(uint256 amount, uint16 extraDays) public {
        _ensureMaxStakingCap();
        vm.assume(amount > MIN_STAKING_AMOUNT && amount <= MAX_NODE_STAKING_AMOUNT);
        vm.assume(extraDays >= 0 && extraDays < EPOCH_PERIOD_DAYS);

        uint256 epochCountForThisTest = 15;

        uint16 period = uint16(epochCountForThisTest) * EPOCH_PERIOD_DAYS + extraDays;

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, amount, period);
        _fastforward(EPOCH_PERIOD_SECONDS);
        for (uint256 epoch = 1; epoch < epochCountForThisTest; epoch++) {
            _fastforward(EPOCH_PERIOD_SECONDS);
            _addMeasurement(epoch, NODE_1_ID, 1000, 0, StakingUtils.NodeSlaLevel.Diamond);
        }

        uint16 lastMeasuredEpoch = uint16(epochCountForThisTest - 1);

        _fastforward(EPOCH_PERIOD_SECONDS);

        int256 simulatedReward = staking.simulateClaim(stakeId);

        _expectClaimEvents(alice, stakeId, true, uint256(simulatedReward), 1, lastMeasuredEpoch);
        vm.prank(alice);
        staking.claim(stakeId);
    }

    function testFuzzSimulateClaimPenalty(uint256 amount, uint16 extraDays) public {
        _ensureMaxStakingCap();
        vm.assume(amount > MIN_STAKING_AMOUNT && amount <= MAX_NODE_STAKING_AMOUNT);
        vm.assume(extraDays >= 0 && extraDays < EPOCH_PERIOD_DAYS);

        uint256 epochCountForThisTest = 15;

        uint16 period = uint16(epochCountForThisTest) * EPOCH_PERIOD_DAYS + extraDays;

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, amount, period);
        _fastforward(EPOCH_PERIOD_SECONDS);
        for (uint256 epoch = 1; epoch < epochCountForThisTest; epoch++) {
            _fastforward(EPOCH_PERIOD_SECONDS);
            // only 100 RPS, 20 penalty days and only silver SLA
            _addMeasurement(epoch, NODE_1_ID, 100, 20, StakingUtils.NodeSlaLevel.Silver);
        }

        uint16 lastMeasuredEpoch = uint16(epochCountForThisTest - 1);

        _fastforward(EPOCH_PERIOD_SECONDS);

        int256 simulatedReward = staking.simulateClaim(stakeId);

        _expectClaimEvents(alice, stakeId, false, uint256(-1 * simulatedReward), 1, lastMeasuredEpoch);

        vm.prank(alice);
        staking.claim(stakeId);
    }
}
