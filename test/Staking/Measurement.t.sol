// solhint-disable ordering
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../Base.t.sol";

contract MeasurementTest is Base {
    function testRevertIfNonSupervisor() public {
        uint256 epoch = 1;

        uint24[] memory rps = new uint24[](1);
        rps[0] = 1000;

        uint16[] memory penaltyDays = new uint16[](1);
        penaltyDays[0] = 0;

        uint8[] memory sla = new uint8[](1);
        sla[0] = uint8(StakingUtils.NodeSlaLevel.Diamond);

        bytes32[] memory nodeIds = new bytes32[](1);
        nodeIds[0] = NODE_1_ID;

        _fastforward(30 days);

        vm.expectRevert("Caller is not a supervisor");
        staking.addMeasurements(epoch, nodeIds, rps, penaltyDays, sla);
    }

    function testRevertIfEmptyDataIn() public {
        uint256 epoch = 1;

        uint24[] memory rps = new uint24[](0);
        uint16[] memory penaltyDays = new uint16[](0);
        uint8[] memory sla = new uint8[](0);
        bytes32[] memory nodeIds = new bytes32[](0);

        _fastforward(30 days);

        vm.prank(supervisor);
        vm.expectRevert("No data received");
        staking.addMeasurements(epoch, nodeIds, rps, penaltyDays, sla);
    }

    function testRevertIfUnequalRpsEntries() public {
        uint256 epoch = 1;

        uint24[] memory rps = new uint24[](2);
        rps[0] = 1000;
        rps[1] = 1000;

        uint16[] memory penaltyDays = new uint16[](1);
        penaltyDays[0] = 0;

        uint8[] memory sla = new uint8[](1);
        sla[0] = uint8(StakingUtils.NodeSlaLevel.Diamond);

        bytes32[] memory nodeIds = new bytes32[](1);
        nodeIds[0] = NODE_1_ID;

        _fastforward(30 days);

        vm.prank(supervisor);
        vm.expectRevert("Unequal lengths");
        staking.addMeasurements(epoch, nodeIds, rps, penaltyDays, sla);
    }

    function testRevertIfUnequalPenaltyDaysEntries() public {
        uint256 epoch = 1;

        uint24[] memory rps = new uint24[](1);
        rps[0] = 1000;

        uint16[] memory penaltyDays = new uint16[](2);
        penaltyDays[0] = 0;
        penaltyDays[1] = 0;

        uint8[] memory sla = new uint8[](1);
        sla[0] = uint8(StakingUtils.NodeSlaLevel.Diamond);

        bytes32[] memory nodeIds = new bytes32[](1);
        nodeIds[0] = NODE_1_ID;

        _fastforward(30 days);

        vm.prank(supervisor);
        vm.expectRevert("Unequal lengths");
        staking.addMeasurements(epoch, nodeIds, rps, penaltyDays, sla);
    }

    function testRevertIfUnequalSlaEntries() public {
        uint256 epoch = 1;

        uint24[] memory rps = new uint24[](1);
        rps[0] = 1000;

        uint16[] memory penaltyDays = new uint16[](1);
        penaltyDays[0] = 0;

        uint8[] memory sla = new uint8[](2);
        sla[0] = uint8(StakingUtils.NodeSlaLevel.Diamond);
        sla[1] = uint8(StakingUtils.NodeSlaLevel.Diamond);

        bytes32[] memory nodeIds = new bytes32[](1);
        nodeIds[0] = NODE_1_ID;

        _fastforward(30 days);

        vm.prank(supervisor);
        vm.expectRevert("Unequal lengths");
        staking.addMeasurements(epoch, nodeIds, rps, penaltyDays, sla);
    }

    function testRevertIfUnequalNodeIdEntries() public {
        uint256 epoch = 1;

        uint24[] memory rps = new uint24[](1);
        rps[0] = 1000;

        uint16[] memory penaltyDays = new uint16[](1);
        penaltyDays[0] = 0;

        uint8[] memory sla = new uint8[](1);
        sla[0] = uint8(StakingUtils.NodeSlaLevel.Diamond);

        bytes32[] memory nodeIds = new bytes32[](2);
        nodeIds[0] = NODE_1_ID;
        nodeIds[1] = NODE_1_ID;

        _fastforward(30 days);

        vm.prank(supervisor);
        vm.expectRevert("Unequal lengths");
        staking.addMeasurements(epoch, nodeIds, rps, penaltyDays, sla);
    }

    function testRevertIfRpsBelowMin() public {
        uint256 epoch = 1;

        uint24[] memory rps = new uint24[](1);
        rps[0] = MIN_RPS - 1;

        uint16[] memory penaltyDays = new uint16[](1);
        penaltyDays[0] = 0;

        uint8[] memory sla = new uint8[](1);
        sla[0] = uint8(StakingUtils.NodeSlaLevel.Diamond);

        bytes32[] memory nodeIds = new bytes32[](1);
        nodeIds[0] = NODE_1_ID;

        _fastforward(30 days);

        vm.prank(supervisor);
        vm.expectRevert("Invalid RPS");
        staking.addMeasurements(epoch, nodeIds, rps, penaltyDays, sla);
    }

    function testRevertIfRpsAboveMax() public {
        uint256 epoch = 1;

        uint24[] memory rps = new uint24[](1);
        rps[0] = MAX_RPS + 1;

        uint16[] memory penaltyDays = new uint16[](1);
        penaltyDays[0] = 0;

        uint8[] memory sla = new uint8[](1);
        sla[0] = uint8(StakingUtils.NodeSlaLevel.Diamond);

        bytes32[] memory nodeIds = new bytes32[](1);
        nodeIds[0] = NODE_1_ID;

        _fastforward(30 days);

        vm.prank(supervisor);
        vm.expectRevert("Invalid RPS");
        staking.addMeasurements(epoch, nodeIds, rps, penaltyDays, sla);
    }

    /// todo: fail reason not checked.
    function testFailIfSlaAboveMax() public {
        uint256 epoch = 1;

        uint24[] memory rps = new uint24[](1);
        rps[0] = MAX_RPS;

        uint16[] memory penaltyDays = new uint16[](1);
        penaltyDays[0] = 0;

        uint8[] memory sla = new uint8[](1);
        sla[0] = 4;

        bytes32[] memory nodeIds = new bytes32[](1);
        nodeIds[0] = NODE_1_ID;

        _fastforward(30 days);

        vm.prank(supervisor);
        staking.addMeasurements(epoch, nodeIds, rps, penaltyDays, sla);
    }

    function testRevertIfFutureEpoch() public {
        uint256 epoch = 1;

        uint24[] memory rps = new uint24[](1);
        rps[0] = MAX_RPS;

        uint16[] memory penaltyDays = new uint16[](1);
        penaltyDays[0] = 0;

        uint8[] memory sla = new uint8[](1);
        sla[0] = uint8(StakingUtils.NodeSlaLevel.Diamond);

        bytes32[] memory nodeIds = new bytes32[](1);
        nodeIds[0] = NODE_1_ID;

        _fastforward(28 days - 1);

        vm.prank(supervisor);
        vm.expectRevert("Invalid epoch");
        staking.addMeasurements(epoch, nodeIds, rps, penaltyDays, sla);
    }

    function testRevertIfNothingStaked() public {
        uint256 epoch = 1;

        uint24[] memory rps = new uint24[](1);
        rps[0] = MAX_RPS;

        uint16[] memory penaltyDays = new uint16[](1);
        penaltyDays[0] = 0;

        uint8[] memory sla = new uint8[](1);
        sla[0] = uint8(StakingUtils.NodeSlaLevel.Diamond);

        bytes32[] memory nodeIds = new bytes32[](1);
        nodeIds[0] = NODE_1_ID;

        _fastforward(28 days);

        vm.prank(supervisor);
        vm.expectRevert(abi.encodeWithSelector(Staking.NothingStaked.selector, NODE_1_ID));
        staking.addMeasurements(epoch, nodeIds, rps, penaltyDays, sla);
    }

    function testRevertIfDuplicateNodeId() public {
        uint256 epoch = 1;

        uint24[] memory rps = new uint24[](2);
        rps[0] = MAX_RPS;
        rps[1] = MAX_RPS;

        uint16[] memory penaltyDays = new uint16[](2);
        penaltyDays[0] = 0;
        penaltyDays[1] = 0;

        uint8[] memory sla = new uint8[](2);
        sla[0] = uint8(StakingUtils.NodeSlaLevel.Diamond);
        sla[1] = uint8(StakingUtils.NodeSlaLevel.Diamond);

        bytes32[] memory nodeIds = new bytes32[](2);
        nodeIds[0] = NODE_1_ID;
        nodeIds[1] = NODE_1_ID;

        _stakeTokens(alice, NODE_1_ID, 1e21, 28);

        _fastforward(28 days);

        vm.prank(supervisor);
        vm.expectRevert(abi.encodeWithSelector(Staking.ExistingMeasurement.selector, NODE_1_ID));
        staking.addMeasurements(epoch, nodeIds, rps, penaltyDays, sla);
    }

    function testRevertIfDuplicateNodeIdAfterSubmission() public {
        uint256 epoch = 1;

        uint24[] memory rps = new uint24[](1);
        rps[0] = MAX_RPS;

        uint16[] memory penaltyDays = new uint16[](1);
        penaltyDays[0] = 0;

        uint8[] memory sla = new uint8[](1);
        sla[0] = uint8(StakingUtils.NodeSlaLevel.Diamond);

        bytes32[] memory nodeIds = new bytes32[](1);
        nodeIds[0] = NODE_1_ID;

        _stakeTokens(alice, NODE_1_ID, 1e21, 28);

        _fastforward(28 days);

        vm.startPrank(supervisor);
        staking.addMeasurements(epoch, nodeIds, rps, penaltyDays, sla);
        vm.expectRevert(abi.encodeWithSelector(Staking.ExistingMeasurement.selector, NODE_1_ID));
        staking.addMeasurements(epoch, nodeIds, rps, penaltyDays, sla);
    }

    function testAddMeasurement() public {
        uint256 epoch = 1;
        uint16 rps = 1000;
        uint16 penaltyDays = 0;
        StakingUtils.NodeSlaLevel sla = StakingUtils.NodeSlaLevel.Diamond;

        _stakeTokens(alice, NODE_1_ID, 1e21, 28);

        _fastforward(30 days);

        vm.expectEmit(true, true, true, true, address(staking));
        emit NodeMeasured(NODE_1_ID, rps, penaltyDays, sla, epoch);

        _addMeasurement(epoch, NODE_1_ID, rps, penaltyDays, sla);

        StakingUtils.Measurement memory m = staking.getNodeMeasurement(NODE_1_ID, epoch);

        assertEq(m.rps, rps);
        assertEq(m.penaltyDays, penaltyDays);
        assertEq(uint8(m.slaLevel), uint8(sla));
    }

    function testFuzzAddMeasurement(uint24 rps, uint16 penaltyDays, uint8 sla, uint32 fastForwardSeconds) public {
        vm.assume(MIN_RPS <= rps && rps <= MAX_RPS);
        vm.assume(penaltyDays <= EPOCH_PERIOD_DAYS);
        vm.assume(sla <= uint8(StakingUtils.NodeSlaLevel.Diamond));
        vm.assume(fastForwardSeconds < (300 * 1 days));

        /// @dev make sure that fastForwards at least one epoch
        fastForwardSeconds += uint32(EPOCH_PERIOD_DAYS) * 1 days;

        uint256 epochSeconds = (uint256(EPOCH_PERIOD_DAYS) * 1 days);
        uint256 epoch = fastForwardSeconds / epochSeconds;

        _stakeTokens(alice, NODE_1_ID, 1e21, 328);
        _fastforward(fastForwardSeconds);

        vm.expectEmit(true, true, true, true, address(staking));
        emit NodeMeasured(NODE_1_ID, rps, penaltyDays, StakingUtils.NodeSlaLevel(sla), epoch);
        _addMeasurement(epoch, NODE_1_ID, rps, penaltyDays, StakingUtils.NodeSlaLevel(sla));

        StakingUtils.Measurement memory m = staking.getNodeMeasurement(NODE_1_ID, epoch);

        assertEq(m.rps, rps);
        assertEq(m.penaltyDays, penaltyDays);
        assertEq(uint8(m.slaLevel), sla);
    }

    /// @dev does not allow overwriting, but relatively slow due to array unique validation.
    function testFuzzNodeIdAddMeasurements(bytes32[] calldata randomNodeIds, uint32 fastForwardSeconds) public {
        vm.assume(randomNodeIds.length > 0);

        /// @dev hackish way to ensure that test parameters are within range
        fastForwardSeconds = fastForwardSeconds % (300 * 1 days);
        fastForwardSeconds += uint32(EPOCH_PERIOD_DAYS) * 1 days;

        bytes32[] memory uniqueNodeIds = utils.uniquify(randomNodeIds);

        uint24[] memory rps = new uint24[](uniqueNodeIds.length);
        uint16[] memory penaltyDays = new uint16[](uniqueNodeIds.length);
        uint8[] memory sla = new uint8[](uniqueNodeIds.length);

        uint128 i = 0;
        for (; i < uniqueNodeIds.length; i = i + 1) {
            // for tracking if rps persists correctly per nodeId
            rps[i] = uint16((i + 25) % 1001);
            penaltyDays[i] = uint16(i % (EPOCH_PERIOD_DAYS + 1));
            sla[i] = uint8(i % 4);
            _stakeTokens(alice, uniqueNodeIds[i], 1e21, 328);
        }

        _fastforward(fastForwardSeconds);

        uint256 contractStartTimestamp = staking.getContractStartTimestamp();
        uint256 contractTime = block.timestamp - contractStartTimestamp;

        uint256 previousEpoch = (contractTime / EPOCH_PERIOD_SECONDS);

        vm.prank(supervisor);
        staking.addMeasurements(previousEpoch, uniqueNodeIds, rps, penaltyDays, sla);

        i = 0;
        for (; i < uniqueNodeIds.length; i = i + 1) {
            StakingUtils.Measurement memory m = staking.getNodeMeasurement(uniqueNodeIds[i], previousEpoch);

            assertEq(m.rps, rps[i], "Unexpected rps");
            assertEq(m.penaltyDays, penaltyDays[i], "Unexpected penaltyDays");
            assertEq(uint8(m.slaLevel), sla[i], "Unexpected sla");
        }
    }
}
