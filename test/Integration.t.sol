// solhint-disable ordering
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./Base.t.sol";

contract IntegrationTest is Base {
    // contract already running for 155 days
    // alice - 2 stakes (276 days and 35 days)
    // bob -   1 stake (275 days)

    function testMultipleStakers() public {
        uint16 alicePeriod1 = 276;
        uint256 aliceAmount1 = ONE_TOKEN * 1e5;

        uint16 alicePeriod2 = 35;
        uint256 aliceAmount2 = ONE_TOKEN * 1e7;

        uint16 bobPeriod1 = 275;
        uint256 bobAmount1 = ONE_TOKEN * 1e3;

        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 bobBalanceBefore = token.balanceOf(bob);

        _fastforward(155 days);

        uint256 aliceStake1Id = _stakeTokens(alice, NODE_1_ID, aliceAmount1, alicePeriod1);
        uint256 aliceStake2Id = _stakeTokens(alice, NODE_1_ID, aliceAmount2, alicePeriod2);
        uint256 bobStake1Id = _stakeTokens(bob, NODE_1_ID, bobAmount1, bobPeriod1);

        /// @dev need to wait until full epoch ends (276 days ends in a middle of epoch)
        _fastforward(293 days);

        uint16 toEpoch = (155 + 293) / EPOCH_PERIOD_DAYS;
        uint16 fromEpoch = 155 / EPOCH_PERIOD_DAYS;
        for (uint16 epoch = fromEpoch + 1; epoch <= toEpoch; epoch += 1) {
            _addMeasurement(
                epoch,
                NODE_1_ID,
                ((25 * epoch - 1) % 1000) + 25,
                epoch % 29,
                StakingUtils.NodeSlaLevel.Diamond
            );
        }

        uint256 aliceStake1Rewards = 3470048960287488158967;
        uint256 aliceStake2Rewards = 347004896028748815896773;

        vm.expectEmit(true, true, true, true, address(staking));
        emit TokensClaimed(address(alice), aliceStake1Id, aliceStake1Rewards, toEpoch);
        vm.prank(alice);
        staking.claim(aliceStake1Id);

        vm.expectEmit(true, true, true, true, address(staking));
        emit TokensClaimed(address(alice), aliceStake2Id, aliceStake2Rewards, toEpoch);
        vm.prank(alice);
        staking.claim(aliceStake2Id);

        /// @dev due to unlimited epochs everybody will get the same percentage increase

        vm.prank(alice);
        staking.unstakeTokens(aliceStake1Id);

        vm.prank(alice);
        staking.unstakeTokens(aliceStake2Id);

        vm.prank(bob);
        staking.unstakeTokens(bobStake1Id);

        uint256 bobStake1Rewards = 34700489602874881589;

        uint256 contractFinalBalance = CONTRACT_INITIAL_BALANCE -
            aliceStake2Rewards -
            aliceStake1Rewards -
            bobStake1Rewards;

        assertEq(token.balanceOf(address(staking)), contractFinalBalance, "Contract final balance");
        assertEq(
            token.balanceOf(alice),
            aliceBalanceBefore + aliceStake2Rewards + aliceStake1Rewards,
            "Alice final balance"
        );
        assertEq(token.balanceOf(bob), bobBalanceBefore + bobStake1Rewards, "Bob final balance");
    }
}
