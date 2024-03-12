// solhint-disable ordering
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../Base.t.sol";

contract ApyParamCalculation is Base {
    function testSetMinAndMaxToIntBoundaries() public {
        uint24 minRps = 1;
        uint24 maxRps = type(uint24).max;

        vm.prank(admin);
        staking.setMinRps(minRps);

        vm.prank(admin);
        staking.setMaxRps(maxRps);

        uint256 stakeAmount = ONE_TOKEN * 1e3;
        uint16 period = 28;

        uint256 stakeIdMax = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        uint256 stakeIdMin = _stakeTokens(alice, keccak256("NODE_2"), stakeAmount, period);

        _fastforward(period * 1 days);

        _addMeasurement(1, NODE_1_ID, maxRps, 0, Staking.NodeSlaLevel.Diamond);
        _addMeasurement(1, keccak256("NODE_2"), minRps, 0, Staking.NodeSlaLevel.Diamond);

        /// @notice claim from node with max RPS

        uint256 claimAmountMax = 11001354566408916000;

        vm.expectEmit(true, true, true, true, address(staking));
        emit TokensClaimed(alice, stakeIdMax, claimAmountMax, 1);

        vm.prank(alice);
        staking.claim(stakeIdMax);

        /// @notice claim from node with min RPS

        uint256 claimAmountMin = 2307569250907432000;

        vm.expectEmit(true, true, true, true, address(staking));
        emit TokensClaimed(alice, stakeIdMin, claimAmountMin, 1);

        vm.prank(alice);
        staking.claim(stakeIdMin);
    }

    function testSetMinAndMaxCloseToIntMax() public {
        uint24 minRps = type(uint24).max - 1;
        uint24 maxRps = type(uint24).max;

        vm.prank(admin);
        staking.setMaxRps(maxRps);

        vm.prank(admin);
        staking.setMinRps(minRps);

        uint256 stakeAmount = ONE_TOKEN * 1e3;
        uint16 period = 28;

        uint256 stakeIdMax = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        uint256 stakeIdMin = _stakeTokens(alice, keccak256("NODE_2"), stakeAmount, period);

        _fastforward(period * 1 days);

        _addMeasurement(1, NODE_1_ID, maxRps, 0, Staking.NodeSlaLevel.Diamond);
        _addMeasurement(1, keccak256("NODE_2"), minRps, 0, Staking.NodeSlaLevel.Diamond);

        /// @notice claim from node with max RPS

        uint256 claimAmountMax = 11000687080924046000;

        vm.expectEmit(true, true, true, true, address(staking));
        emit TokensClaimed(alice, stakeIdMax, claimAmountMax, 1);

        vm.prank(alice);
        staking.claim(stakeIdMax);

        /// @notice claim from node with min RPS

        uint256 claimAmountMin = 2306828712225397000;

        vm.expectEmit(true, true, true, true, address(staking));
        emit TokensClaimed(alice, stakeIdMin, claimAmountMin, 1);

        vm.prank(alice);
        staking.claim(stakeIdMin);
    }

    function testSetMinAndMaxCloseToIntMin() public {
        uint24 minRps = 1;
        uint24 maxRps = 2;

        vm.prank(admin);
        staking.setMinRps(minRps);

        vm.prank(admin);
        staking.setMaxRps(maxRps);

        uint256 stakeAmount = ONE_TOKEN * 1e3;
        uint16 period = 28;

        uint256 stakeIdMax = _stakeTokens(alice, NODE_1_ID, stakeAmount, period);
        uint256 stakeIdMin = _stakeTokens(alice, keccak256("NODE_2"), stakeAmount, period);

        _fastforward(period * 1 days);

        _addMeasurement(1, NODE_1_ID, maxRps, 0, Staking.NodeSlaLevel.Diamond);
        _addMeasurement(1, keccak256("NODE_2"), minRps, 0, Staking.NodeSlaLevel.Diamond);

        /// @notice claim from node with max RPS

        uint256 claimAmountMax = 11001354566288773000;

        vm.expectEmit(true, true, true, true, address(staking));
        emit TokensClaimed(alice, stakeIdMax, claimAmountMax, 1);

        vm.prank(alice);
        staking.claim(stakeIdMax);

        /// @notice claim from node with min RPS

        uint256 claimAmountMin = 2307569250774122000;

        vm.expectEmit(true, true, true, true, address(staking));
        emit TokensClaimed(alice, stakeIdMin, claimAmountMin, 1);

        vm.prank(alice);
        staking.claim(stakeIdMin);
    }
}
