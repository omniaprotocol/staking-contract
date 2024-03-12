// solhint-disable ordering
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../Base.t.sol";

contract UnstakeTest is Base {
    function testUnstake() public {
        uint256 amount = ONE_TOKEN * 1e7; // 10M tokens
        uint16 period = 28;
        uint256 stakerAmountBefore = token.balanceOf(alice);
        uint256 contractAmountBefore = token.balanceOf(address(staking));

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, amount, period);
        _fastforward(28 days);

        _addMeasurement(1, NODE_1_ID, 1000, 0, Staking.NodeSlaLevel.Diamond);

        vm.prank(alice);
        staking.unstakeTokens(stakeId);

        assertGe(token.balanceOf(alice), stakerAmountBefore);
        assertLe(token.balanceOf(address(staking)), contractAmountBefore);

        Staking.Stake memory stake = staking.getStake(stakeId);
        assertEq(stake.withdrawnTimestamp, block.timestamp);
    }

    /// @notice due to rounding to next day, will need to stake for more days
    function testNeedsTwoMeasurements() public {
        uint256 amount = ONE_TOKEN * 1e7; // 10M tokens
        uint16 period = 28;
        uint256 stakerAmountBefore = token.balanceOf(alice);
        uint256 contractAmountBefore = token.balanceOf(address(staking));

        _fastforward(1);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, amount, period);
        _fastforward(56 days - 1);

        _addMeasurement(1, NODE_1_ID, 1000, 0, Staking.NodeSlaLevel.Diamond);
        _addMeasurement(2, NODE_1_ID, 1000, 0, Staking.NodeSlaLevel.Diamond);

        vm.prank(alice);
        staking.unstakeTokens(stakeId);

        assertGe(token.balanceOf(alice), stakerAmountBefore);
        assertLe(token.balanceOf(address(staking)), contractAmountBefore);

        Staking.Stake memory stake = staking.getStake(stakeId);
        assertEq(stake.withdrawnTimestamp, block.timestamp);
    }

    function testUnstakePenalty() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(28 days);

        _addMeasurement(1, NODE_1_ID, 1000, 28, Staking.NodeSlaLevel.Diamond);

        uint256 penaltyAmount = 39270967704245690000000;

        vm.prank(alice);
        staking.unstakeTokens(stakeId);
        assertEq(token.balanceOf(alice), stakerBalanceBefore - penaltyAmount);
    }

    function testUnstakeAfterPenaltyClaim() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28 * 2;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        _fastforward(1 days);
        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(27 days + 28 days + 28 days);

        _addMeasurement(1, NODE_1_ID, 1000, 28, Staking.NodeSlaLevel.Diamond);
        _addMeasurement(2, NODE_1_ID, 1000, 28, Staking.NodeSlaLevel.Diamond);
        _addMeasurement(3, NODE_1_ID, 1000, 28, Staking.NodeSlaLevel.Diamond);

        vm.prank(alice);
        staking.claim(stakeId);

        /// @dev nothing claimed
        assertEq(token.balanceOf(alice), stakerBalanceBefore - stakeAmount);

        vm.prank(alice);
        staking.unstakeTokens(stakeId);
        assertEq(token.balanceOf(alice), stakerBalanceBefore - 115961944020868931296388);
    }

    function testNodeStakeAmountShouldReset() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(28 days);

        _addMeasurement(1, NODE_1_ID, 1000, 28, Staking.NodeSlaLevel.Diamond);

        vm.prank(alice);
        staking.unstakeTokens(stakeId);

        uint256 nodeStakedAmount;
        (nodeStakedAmount, ) = staking.getNode(NODE_1_ID);

        assertEq(nodeStakedAmount, 0);
    }
}
