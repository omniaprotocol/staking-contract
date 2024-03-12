// solhint-disable ordering
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../Base.t.sol";

contract UnstakeFailTest is Base {
    event TokensUnstaked(address indexed sender, uint256 indexed stakeId, bytes32 nodeId, uint256 amount);

    function testRevertIfNoStake() public {
        vm.prank(alice);
        vm.expectRevert("Not authorized");
        staking.unstakeTokens(1);
    }

    function testRevertIfNotOwner() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);

        vm.prank(bob);
        vm.expectRevert("Not authorized");
        staking.unstakeTokens(stakeId);
        assertEq(token.balanceOf(alice), stakerBalanceBefore - stakeAmount);
    }

    function testRevertIfAlreadyUstaked() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(28 days);

        _addMeasurement(1, NODE_1_ID, 1000, 0, Staking.NodeSlaLevel.Diamond);
        vm.prank(alice);

        vm.expectEmit(true, true, true, true, address(staking));
        emit TokensUnstaked(alice, stakeId, NODE_1_ID, stakeAmount);

        staking.unstakeTokens(stakeId);

        uint256 claimAmount = 110013545664089160000000;

        vm.prank(alice);
        vm.expectRevert("Already withdrawn");
        staking.unstakeTokens(stakeId);
        assertEq(token.balanceOf(alice), stakerBalanceBefore + claimAmount);
    }

    function testRevertIfASecondTooEarly() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(28 days - 1);

        vm.prank(alice);
        vm.expectRevert("Too early");
        staking.unstakeTokens(stakeId);
        assertEq(token.balanceOf(alice), stakerBalanceBefore - stakeAmount);
    }

    function testRevertIfNoMeasurement() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(28 days);

        vm.prank(alice);
        vm.expectRevert("Too early");
        staking.unstakeTokens(stakeId);
        assertEq(token.balanceOf(alice), stakerBalanceBefore - stakeAmount);
    }

    function testRevertIfNoMeasurementStartedLater() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        /// @dev staking so measurements could be submitted
        _stakeTokens(alice, NODE_1_ID, stakeAmount, 56);

        _fastforward(56 days);
        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);

        _addMeasurement(1, NODE_1_ID, 1000, 28, Staking.NodeSlaLevel.Diamond);
        _addMeasurement(2, NODE_1_ID, 1000, 28, Staking.NodeSlaLevel.Diamond);

        _fastforward(28 days);

        vm.prank(alice);
        vm.expectRevert("Too early");
        staking.unstakeTokens(stakeId);
        assertEq(token.balanceOf(alice), stakerBalanceBefore - 2 * stakeAmount);
    }

    function testRevertIfNeedsTwoMeasurements() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        _fastforward(1);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(28 days - 1);

        _addMeasurement(1, NODE_1_ID, 1000, 28, Staking.NodeSlaLevel.Diamond);

        vm.prank(alice);
        vm.expectRevert("Too early");
        staking.unstakeTokens(stakeId);
        assertEq(token.balanceOf(alice), stakerBalanceBefore - stakeAmount);
    }
}
