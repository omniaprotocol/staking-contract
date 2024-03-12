// solhint-disable ordering
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./ClaimBase.t.sol";
import "prb-math/casting/Uint256.sol";

contract ClaimCacheTest is ClaimBase {
    function testCacheInterestAfterClaim() public {
        uint256 amount = ONE_TOKEN * 1e7;
        uint16 period = 28;
        uint256 epoch = 1;

        uint256 stakeid = _stakeTokens(alice, NODE_1_ID, amount, period);
        _fastforward(30 days);

        _addMeasurement(1, NODE_1_ID, 1000, 0, Staking.NodeSlaLevel.Diamond);
        Staking.Measurement memory mBefore = staking.getNodeMeasurement(NODE_1_ID, epoch);

        vm.prank(alice);
        staking.claim(stakeid);

        Staking.Measurement memory mAfter = staking.getNodeMeasurement(NODE_1_ID, epoch);

        assertTrue(Prb.eq(mBefore.interest, Prb.ZERO));
        assertTrue(Prb.eq(mAfter.interest, PRBMathCastingUint256.intoSD59x18(1011001354566408916)));
    }

    function testCachePenaltyAfterClaim() public {
        uint256 amount = ONE_TOKEN * 1e7;
        uint16 period = 28;
        uint256 epoch = 1;

        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, amount, period);
        _fastforward(30 days);

        _addMeasurement(1, NODE_1_ID, 1000, 28, Staking.NodeSlaLevel.Diamond);
        Staking.Measurement memory mBefore = staking.getNodeMeasurement(NODE_1_ID, epoch);

        vm.prank(alice);
        staking.claim(stakeId);

        Staking.Measurement memory mAfter = staking.getNodeMeasurement(NODE_1_ID, epoch);

        assertTrue(Prb.eq(mBefore.penalty, Prb.ZERO));
        assertTrue(Prb.eq(mAfter.penalty, PRBMathCastingUint256.intoSD59x18(996072903229575431)));
    }
}
