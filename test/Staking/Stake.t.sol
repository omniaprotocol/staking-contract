// solhint-disable ordering
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../Base.t.sol";

contract StakingTest is Base {
    function testRevertWhenStakeNotEnoughTokens() public {
        uint256 amount = MIN_STAKING_AMOUNT - 1;
        uint16 period = EPOCH_PERIOD_DAYS;

        vm.startPrank(alice);
        token.approve(address(staking), amount);

        vm.expectRevert("Amount too small");
        staking.stakeTokens(NODE_1_ID, amount, period);
    }

    function testStakeMinTokens() public {
        uint256 amount = MIN_STAKING_AMOUNT;
        uint16 period = EPOCH_PERIOD_DAYS;

        _stakeTokens(alice, NODE_1_ID, amount, period);
    }

    function testRevertWhenLessThanMinPeriod() public {
        uint256 amount = ONE_TOKEN * 1000;
        uint16 period = EPOCH_PERIOD_DAYS - 1;

        vm.startPrank(alice);
        token.approve(address(staking), amount);

        vm.expectRevert("Period too short");
        staking.stakeTokens(NODE_1_ID, amount, period);
    }

    function testStakeMinPeriod() public {
        uint256 amount = ONE_TOKEN * 1000;
        uint16 period = EPOCH_PERIOD_DAYS;

        _stakeTokens(alice, NODE_1_ID, amount, period);
    }

    function testStakeTwice() public {
        uint256 amount = ONE_TOKEN * 1000;
        uint16 period = EPOCH_PERIOD_DAYS;

        uint256 stakeId1 = _stakeTokens(alice, NODE_1_ID, amount, period);
        uint256 stakeId2 = _stakeTokens(bob, NODE_1_ID, amount, period);
        assertEq(stakeId1, 1);
        assertEq(stakeId2, 2);
    }

    function testRevertWhenStakeNotEnoughAllowance() public {
        uint256 amount = ONE_TOKEN * 1000;
        uint16 period = EPOCH_PERIOD_DAYS;

        vm.startPrank(alice);
        token.approve(address(staking), amount - 1);

        vm.expectRevert("Not enough allowance");
        staking.stakeTokens(NODE_1_ID, amount, period);
    }

    function testRevertIfAboveNodeMaxTokens() public {
        uint256 amount = MAX_NODE_STAKING_AMOUNT + 1;
        uint16 period = EPOCH_PERIOD_DAYS;

        vm.startPrank(alice);
        token.approve(address(staking), amount);

        vm.expectRevert("Node max amount reached");
        staking.stakeTokens(NODE_1_ID, amount, period);
    }

    function testNodeStakeAmountUpdated() public {
        uint256 amount = ONE_TOKEN * 1000;
        uint16 period = EPOCH_PERIOD_DAYS;

        _stakeTokens(alice, NODE_1_ID, amount, period);

        uint256 nodeStakedAmount;
        (nodeStakedAmount, ) = staking.getNode(NODE_1_ID);

        assertEq(nodeStakedAmount, amount);
    }

    function testMultipleNodeStakeAmountUpdates() public {
        uint256 amount = ONE_TOKEN * 1000;
        uint16 period = EPOCH_PERIOD_DAYS;

        _stakeTokens(alice, NODE_1_ID, amount, period);
        _stakeTokens(bob, NODE_1_ID, amount, period);

        uint256 nodeStakedAmount;
        (nodeStakedAmount, ) = staking.getNode(NODE_1_ID);

        assertEq(nodeStakedAmount, 2 * amount);
    }

    /// @notice if previous stake was unstaked
    function testCanStakeAgainAfterUnstake() public {
        uint256 amount = MAX_NODE_STAKING_AMOUNT;
        uint16 period = EPOCH_PERIOD_DAYS;

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, amount, period);
        _fastforward(period * 1 days);
        _addMeasurementsEpochInterval(1, 1, NODE_1_ID, 1000, 0, StakingUtils.NodeSlaLevel.Diamond);

        vm.prank(alice);
        staking.unstakeTokens(stakeId);

        _stakeTokens(alice, NODE_1_ID, amount, period);

        uint256 nodeStakedAmount;
        (nodeStakedAmount, ) = staking.getNode(NODE_1_ID);

        assertEq(nodeStakedAmount, amount);
    }

    /// @dev A shift of a seconds should push start timestamp to next day and keep period duration
    function testStartTimestampShift1Second() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;

        uint256 timestampBefore = block.timestamp;
        _fastforward(1);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);

        assertEq(staking.getStake(stakeId).startTimestamp, timestampBefore + 1 days);
    }

    function testStartTimestampShift86399Seconds() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;

        uint256 timestampBefore = block.timestamp;
        _fastforward(86399);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);

        assertEq(staking.getStake(stakeId).startTimestamp, timestampBefore + 1 days);
    }

    function testNoStartTimestampShift() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;

        uint256 timestampBefore = block.timestamp;

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);

        assertEq(staking.getStake(stakeId).startTimestamp, timestampBefore);
    }

    function testStakeTokens() public {
        uint256 amount = ONE_TOKEN * 1000;
        uint16 period = EPOCH_PERIOD_DAYS;
        uint256 stakerAmountBefore = token.balanceOf(alice);
        uint256 contractAmountBefore = token.balanceOf(address(staking));
        uint256 expectedStakeId = 1;

        vm.startPrank(alice);
        token.approve(address(staking), amount);

        vm.expectEmit(true, true, true, true, address(token));
        emit Transfer(alice, address(staking), amount);

        vm.expectEmit(true, true, true, true, address(staking));
        emit TokensStaked(alice, expectedStakeId, NODE_1_ID, amount, period);

        uint256 stakeId = staking.stakeTokens(NODE_1_ID, amount, period);
        assertEq(stakeId, expectedStakeId);

        StakingUtils.Stake memory stake = staking.getStake(stakeId);
        assertEq(stake.nodeId, NODE_1_ID);
        assertEq(stake.amount, amount);
        assertEq(stake.lastClaimedEpoch, 0);
        assertEq(stake.startTimestamp, block.timestamp);
        assertEq(stake.withdrawnTimestamp, 0);
        assertEq(stake.staker, alice);
        assertEq(stake.stakingDays, period);
        assertEq(token.balanceOf(alice), stakerAmountBefore - amount);
        assertEq(token.balanceOf(address(staking)), contractAmountBefore + amount);

        assertEq(staking.getStakeCount(alice), 1);
        assertEq(staking.getStakeId(alice, 0), expectedStakeId);

        uint256 fetchedStakeId = staking.getStakeId(alice, 0);
        assertEq(fetchedStakeId, expectedStakeId);
    }

    function testRevertTestTokensForInvalidAddress() public {
        vm.startPrank(alice);
        token.approve(address(staking), ONE_TOKEN);
        vm.expectRevert("Invalid address");
        staking.stakeTokensFor(address(0), NODE_1_ID, ONE_TOKEN, EPOCH_PERIOD_DAYS);
    }

    function testStakeTokensForOthers() public {
        // Alice will stake for Bob
        uint256 amount = ONE_TOKEN * 1000;
        uint16 period = EPOCH_PERIOD_DAYS;
        uint256 payerAmountBefore = token.balanceOf(alice);
        uint256 contractAmountBefore = token.balanceOf(address(staking));
        uint256 expectedStakeId = 1;

        vm.startPrank(alice);
        token.approve(address(staking), amount);

        vm.expectEmit(true, true, true, true, address(token));
        emit Transfer(alice, address(staking), amount);

        vm.expectEmit(true, true, true, true, address(staking));
        emit TokensStaked(bob, expectedStakeId, NODE_1_ID, amount, period);

        uint256 stakeId = staking.stakeTokensFor(bob, NODE_1_ID, amount, period);
        assertEq(stakeId, expectedStakeId);

        StakingUtils.Stake memory stake = staking.getStake(stakeId);
        assertEq(stake.nodeId, NODE_1_ID);
        assertEq(stake.amount, amount);
        assertEq(stake.lastClaimedEpoch, 0);
        assertEq(stake.startTimestamp, block.timestamp);
        assertEq(stake.withdrawnTimestamp, 0);
        assertEq(stake.staker, bob);
        assertEq(stake.stakingDays, period);
        assertEq(token.balanceOf(alice), payerAmountBefore - amount);
        assertEq(token.balanceOf(address(staking)), contractAmountBefore + amount);

        assertEq(staking.getStakeCount(bob), 1);
        assertEq(staking.getStakeId(bob, 0), expectedStakeId);

        uint256 fetchedStakeId = staking.getStakeId(bob, 0);
        assertEq(fetchedStakeId, expectedStakeId);
    }

    function testFuzzStakeTokensForOthers(uint256 amount, uint16 period, bytes32 nodeId) public {
        vm.assume(amount > MIN_STAKING_AMOUNT && amount <= MAX_NODE_STAKING_AMOUNT);
        vm.assume(period >= EPOCH_PERIOD_DAYS);

        // Alice will stake for Bob
        uint256 payerAmountBefore = token.balanceOf(alice);
        uint256 contractAmountBefore = token.balanceOf(address(staking));
        uint256 expectedStakeId = 1;

        vm.startPrank(alice);
        token.approve(address(staking), amount);

        vm.expectEmit(true, true, true, true, address(token));
        emit Transfer(alice, address(staking), amount);

        vm.expectEmit(true, true, true, true, address(staking));
        emit TokensStaked(bob, expectedStakeId, nodeId, amount, period);

        uint256 stakeId = staking.stakeTokensFor(bob, nodeId, amount, period);
        assertEq(stakeId, expectedStakeId);

        StakingUtils.Stake memory stake = staking.getStake(stakeId);
        assertEq(stake.nodeId, nodeId);
        assertEq(stake.amount, amount);
        assertEq(stake.lastClaimedEpoch, 0);
        assertEq(stake.startTimestamp, block.timestamp);
        assertEq(stake.withdrawnTimestamp, 0);
        assertEq(stake.staker, bob);
        assertEq(stake.stakingDays, period);
        assertEq(token.balanceOf(alice), payerAmountBefore - amount);
        assertEq(token.balanceOf(address(staking)), contractAmountBefore + amount);

        assertEq(staking.getStakeCount(bob), 1);
        assertEq(staking.getStakeId(bob, 0), expectedStakeId);

        uint256 fetchedStakeId = staking.getStakeId(bob, 0);
        assertEq(fetchedStakeId, expectedStakeId);
    }

    function testFuzzStakeTokens(uint256 amount, uint16 period, bytes32 nodeId) public {
        vm.assume(amount > MIN_STAKING_AMOUNT && amount <= MAX_NODE_STAKING_AMOUNT);
        vm.assume(period >= EPOCH_PERIOD_DAYS);

        uint256 stakerAmountBefore = token.balanceOf(alice);
        uint256 contractAmountBefore = token.balanceOf(address(staking));
        uint256 expectedStakeId = 1;

        vm.startPrank(alice);
        token.approve(address(staking), amount);

        vm.expectEmit(true, true, true, true, address(token));
        emit Transfer(alice, address(staking), amount);

        vm.expectEmit(true, true, true, true, address(staking));
        emit TokensStaked(alice, expectedStakeId, nodeId, amount, period);

        uint256 stakeId = staking.stakeTokens(nodeId, amount, period);
        assertEq(stakeId, expectedStakeId);

        StakingUtils.Stake memory stake = staking.getStake(stakeId);
        assertEq(stake.nodeId, nodeId);
        assertEq(stake.amount, amount);
        assertEq(stake.lastClaimedEpoch, 0);
        assertEq(stake.startTimestamp, block.timestamp);
        assertEq(stake.withdrawnTimestamp, 0);
        assertEq(stake.staker, alice);
        assertEq(stake.stakingDays, period);
        assertEq(token.balanceOf(alice), stakerAmountBefore - amount);
        assertEq(token.balanceOf(address(staking)), contractAmountBefore + amount);

        assertEq(staking.getStakeCount(alice), 1);
        assertEq(staking.getStakeId(alice, 0), expectedStakeId);

        uint256 stakerStakeId = staking.getStakeId(alice, 0);
        assertEq(stakerStakeId, stakeId);
    }
}
