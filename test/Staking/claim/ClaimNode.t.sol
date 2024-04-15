// solhint-disable ordering
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./ClaimBase.t.sol";

/// @notice claiming when both penalty and reward is applied
contract ClaimNodeTest is ClaimBase {
    function _getWalletNodeId(address wallet, uint96 id) private pure returns (bytes32) {
        uint256 uNodeId = uint256(uint160(wallet)) << 96;
        uNodeId += id;

        return bytes32(uNodeId);
    }

    function testRevertIfNonOwnerClaim() public {
        bytes32 nodeId = _getWalletNodeId(bob, 999999999999999999999999);

        vm.prank(alice);
        vm.expectRevert("Not owner");
        staking.claim(nodeId);
    }

    function testRevertIfNothingToClaim() public {
        bytes32 nodeId = _getWalletNodeId(alice, 999999999999999999999999);
        vm.prank(alice);
        vm.expectRevert("Nothing to claim");
        staking.claim(nodeId);
    }

    function testClaim() public {
        bytes32 nodeId = _getWalletNodeId(alice, 999999999999999999999999);

        uint256 stakeAmount = ONE_TOKEN * 1e4;
        uint16 period = 28;
        uint256 nodeOwnerBalanceBefore = token.balanceOf(alice);

        vm.prank(admin);
        settings.setNodeOwnerRewardPercent(30);

        uint256 stakeId = _stakeTokens(bob, nodeId, stakeAmount, period);
        _fastforward(period * 1 days);

        _addMeasurement(1, nodeId, 1000, 0, StakingUtils.NodeSlaLevel.Diamond);

        vm.prank(bob);
        staking.claim(stakeId);

        uint256 claimAmount = 33004063699226748000;

        vm.expectEmit(true, true, true, true, address(staking));
        emit NodeTokensClaimed(alice, nodeId, claimAmount);

        vm.prank(alice);
        staking.claim(nodeId);
        assertEq(token.balanceOf(alice), claimAmount + nodeOwnerBalanceBefore);
    }

    function testPenaltyNodeClaimableUnchanged() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28 * 2;

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(56 days);

        _addMeasurement(1, NODE_1_ID, 1000, 28, StakingUtils.NodeSlaLevel.Diamond);

        vm.prank(alice);
        staking.claim(stakeId);

        uint256 nodeClaimableAmount;
        (, nodeClaimableAmount) = staking.getNode(NODE_1_ID);

        assertEq(nodeClaimableAmount, 0);
    }

    function testRewardNodeClaimableIncreased() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;

        vm.prank(admin);
        settings.setNodeOwnerRewardPercent(30);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(period * 1 days);

        _addMeasurement(1, NODE_1_ID, 1000, 0, StakingUtils.NodeSlaLevel.Diamond);

        vm.prank(alice);
        staking.claim(stakeId);

        uint256 claimAmount = (uint256(110013545664089160000000) * NODE_REWARD_PERCENT) / 100;

        uint256 nodeClaimableAmount;
        (, nodeClaimableAmount) = staking.getNode(NODE_1_ID);

        assertEq(nodeClaimableAmount, claimAmount);
    }

    function testMixedRewardNodeClaimableIncreased() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;

        vm.prank(admin);
        settings.setNodeOwnerRewardPercent(30);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(period * 1 days);

        _addMeasurement(1, NODE_1_ID, 1000, 14, StakingUtils.NodeSlaLevel.Diamond);

        vm.prank(alice);
        staking.claim(stakeId);

        uint256 penaltyAmount = 19654799409112110000000;
        uint256 rewardAmount = 54856312083274330000000;
        uint256 claimAmount = ((rewardAmount - penaltyAmount) * NODE_REWARD_PERCENT) / 100;

        uint256 nodeClaimableAmount;
        (, nodeClaimableAmount) = staking.getNode(NODE_1_ID);

        assertEq(nodeClaimableAmount, claimAmount);
    }

    function testResetClaimableAmountAfterClaim() public {
        bytes32 nodeId = _getWalletNodeId(alice, 999999999999999999999999);

        uint256 stakeAmount = ONE_TOKEN * 1e4;
        uint16 period = 28;

        vm.prank(admin);
        settings.setNodeOwnerRewardPercent(30);

        uint256 stakeId = _stakeTokens(bob, nodeId, stakeAmount, period);
        _fastforward(period * 1 days);

        _addMeasurement(1, nodeId, 1000, 0, StakingUtils.NodeSlaLevel.Diamond);

        vm.prank(bob);
        staking.claim(stakeId);

        vm.prank(alice);
        staking.claim(nodeId);

        uint256 nodeClaimableAmount;
        (, nodeClaimableAmount) = staking.getNode(NODE_1_ID);

        assertEq(nodeClaimableAmount, 0);
    }

    function testRevertNothingToClaimIfPercent0() public {
        vm.prank(admin);
        settings.setNodeOwnerRewardPercent(0);

        bytes32 nodeId = _getWalletNodeId(alice, 999999999999999999999999);

        uint256 stakeAmount = ONE_TOKEN * 1e4;
        uint16 period = 28;

        uint256 stakeId = _stakeTokens(bob, nodeId, stakeAmount, period);
        _fastforward(period * 1 days);

        _addMeasurement(1, nodeId, 1000, 0, StakingUtils.NodeSlaLevel.Diamond);

        vm.prank(bob);
        staking.claim(stakeId);

        vm.prank(alice);
        vm.expectRevert("Nothing to claim");
        staking.claim(nodeId);
    }

    function testRevertSmallMinStakingPoorRps() public {
        uint256 stakeAmount = 1;
        uint16 period = 28;
        bytes32 nodeId = _getWalletNodeId(alice, 999999999999999999999999);

        vm.prank(admin);
        settings.setMinStakingAmount(stakeAmount);

        uint256 stakeId = _stakeTokens(bob, nodeId, stakeAmount, period);
        _fastforward(uint256(period) * 1 days);

        _addMeasurementsEpochInterval(1, 1, nodeId, 25, 0, StakingUtils.NodeSlaLevel.Diamond);

        vm.prank(bob);
        staking.claim(stakeId);

        vm.prank(alice);
        vm.expectRevert("Nothing to claim");
        staking.claim(nodeId);
    }
}
