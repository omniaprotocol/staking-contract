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
}
