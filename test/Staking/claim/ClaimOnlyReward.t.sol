// solhint-disable ordering
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./ClaimBase.t.sol";

/// @notice claiming when only rewards exists (0 penalty days)
contract ClaimOnlyRewardTest is ClaimBase {
    function testSetMaxApyToMin() public {
        uint256 newApy = 1;
        Staking.NodeSlaLevel sla = Staking.NodeSlaLevel.Silver;

        vm.prank(admin);
        staking.setMaxApy(sla, newApy);

        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(period * 1 days);

        _addMeasurement(1, NODE_1_ID, 1000, 0, Staking.NodeSlaLevel.Silver);
        ///         should be 76708787616773832035... limits of accuracy when very low interest
        uint256 claimAmount = 76708787613910000000;
        vm.expectEmit(true, true, true, true, address(staking));
        emit TokensClaimed(alice, stakeId, claimAmount, 1);

        vm.prank(alice);
        staking.claim(stakeId);

        _expectBalances(alice, stakeId, CONTRACT_INITIAL_BALANCE, stakerBalanceBefore, stakeAmount, true, claimAmount);
    }

    function testSetMaxApyToMax() public {
        uint256 newApy = MAX_APY;
        Staking.NodeSlaLevel sla = Staking.NodeSlaLevel.Silver;

        vm.prank(admin);
        staking.setMaxApy(sla, newApy);

        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(period * 1 days);

        _addMeasurement(1, NODE_1_ID, 1000, 0, Staking.NodeSlaLevel.Silver);

        uint256 claimAmount = 546120080444046580000000;
        vm.expectEmit(true, true, true, true, address(staking));
        emit TokensClaimed(alice, stakeId, claimAmount, 1);

        vm.prank(alice);
        staking.claim(stakeId);

        _expectBalances(alice, stakeId, CONTRACT_INITIAL_BALANCE, stakerBalanceBefore, stakeAmount, true, claimAmount);
    }

    /// @dev more epochs to be claim, but claim only measured
    function testOnlyMeasured() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28 * 2;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(56 days);

        _addMeasurement(1, NODE_1_ID, 1000, 0, Staking.NodeSlaLevel.Diamond);

        uint256 claimAmount = 110013545664089160000000;
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
        _addMeasurement(13, NODE_1_ID, 1000, 0, Staking.NodeSlaLevel.Diamond);

        uint256 claimAmount = 110013545664089160000000;
        _expectClaimEvents(alice, stakeId, true, claimAmount, 13, 13);

        vm.prank(alice);
        staking.claim(stakeId);

        _expectBalances(alice, stakeId, CONTRACT_INITIAL_BALANCE, stakerBalanceBefore, stakeAmount, true, claimAmount);
    }

    /// @dev claim half tokens after started mid epoch and claim after first epoch
    function testMidEpochStartClaimHalf() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        _fastforward(14 days);
        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(14 days);
        _addMeasurement(1, NODE_1_ID, 1000, 0, Staking.NodeSlaLevel.Diamond);

        // perfect precision  54856312083277046086630
        uint256 claimAmount = 54856312083274330000000;
        _expectClaimEvents(alice, stakeId, true, claimAmount, 1, 1);

        vm.prank(alice);
        staking.claim(stakeId);

        _expectBalances(alice, stakeId, CONTRACT_INITIAL_BALANCE, stakerBalanceBefore, stakeAmount, true, claimAmount);
    }

    /// @dev claim all tokens after started mid epoch and ends mid epoch
    function testMidEpochStartClaimAllAtOnce() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        _fastforward(14 days);
        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(42 days);
        _addMeasurement(1, NODE_1_ID, 1000, 0, Staking.NodeSlaLevel.Diamond);
        _addMeasurement(2, NODE_1_ID, 1000, 0, Staking.NodeSlaLevel.Diamond);

        uint256 claimAmount = 165473351486797172646287;
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

        _addMeasurementsEpochInterval(1, 2, NODE_1_ID, 1000, 0, Staking.NodeSlaLevel.Diamond);

        uint256 claimAmount = 221237389351136783081635;
        _expectClaimEvents(alice, stakeId, true, claimAmount, 1, 2);

        vm.prank(alice);
        staking.claim(stakeId);

        _expectBalances(alice, stakeId, CONTRACT_INITIAL_BALANCE, stakerBalanceBefore, aliceAmount, true, claimAmount);
    }

    function testSingleEpoch() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(uint256(period) * 1 days);

        _addMeasurement(1, NODE_1_ID, 1000, 0, Staking.NodeSlaLevel.Diamond);

        uint256 claimAmount = 110013545664089160000000;
        _expectClaimEvents(alice, stakeId, true, claimAmount, 1, 1);

        vm.prank(alice);
        staking.claim(stakeId);

        _expectBalances(alice, stakeId, CONTRACT_INITIAL_BALANCE, stakerBalanceBefore, stakeAmount, true, claimAmount);
    }

    function testMultipleEpochs() public {
        uint256 stakeAmount = ONE_TOKEN * 1e7;
        uint16 period = 28 * 12;
        uint256 epochCount = (uint256(period) * 1 days) / EPOCH_PERIOD_SECONDS;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(uint256(period) * 1 days);

        /// @dev APY is at max 15.33%
        _addMeasurementsEpochInterval(1, epochCount, NODE_1_ID, 1000, 0, Staking.NodeSlaLevel.Diamond);

        // exact should be    1403045300875211215497437... losing precision due compound limits
        uint256 claimAmount = 1403045300875174388806742;
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
        _addMeasurementsEpochInterval(1, epochCount, NODE_1_ID, 25, 0, Staking.NodeSlaLevel.Diamond);

        // exact should be    280449909517994442091182... due compound limits
        uint256 claimAmount = 280449901585290879541442;
        _expectClaimEvents(alice, stakeId, true, claimAmount, 1, 12);

        vm.prank(alice);
        staking.claim(stakeId);

        _expectBalances(alice, stakeId, CONTRACT_INITIAL_BALANCE, stakerBalanceBefore, stakeAmount, true, claimAmount);
    }

    function testSmallMinStakingPoorRps() public {
        uint256 stakeAmount = 1;
        uint16 period = 28;
        uint256 stakerBalanceBefore = token.balanceOf(alice);

        vm.prank(admin);
        staking.setMinStakingAmount(stakeAmount);

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        _fastforward(uint256(period) * 1 days);

        _addMeasurementsEpochInterval(1, 1, NODE_1_ID, 25, 0, Staking.NodeSlaLevel.Diamond);

        uint256 claimAmount = 0;
        _expectClaimEvents(alice, stakeId, true, claimAmount, 1, 1);

        vm.prank(alice);
        staking.claim(stakeId);

        _expectBalances(alice, stakeId, CONTRACT_INITIAL_BALANCE, stakerBalanceBefore, stakeAmount, true, claimAmount);
    }
}
