// solhint-disable ordering
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./ClaimBase.t.sol";
import "prb-math/casting/Uint256.sol";

contract ClaimCacheTest is ClaimBase, IStakingSettingsEvents {
    function testClaimWithoutBoost() public {
        uint256 stakeAmount = ONE_TOKEN * 1e6; // 1M tokens
        uint16 stakingDays = 364; // almost one full year to avoid boost
        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, stakingDays);
        _fastforward(364 days);
        _addMeasurementsEpochInterval(1, 13, NODE_1_ID, 1000, 0, StakingUtils.NodeSlaLevel.Diamond);

        uint256 claimAmount = 152849424536692522003734; // MAX APY , no boost
        uint256 stakerBalanceBefore = token.balanceOf(alice);
        vm.prank(alice);
        staking.claim(stakeId);
        uint256 stakerBalanceAfter = token.balanceOf(alice);
        assertEq(stakerBalanceBefore + claimAmount, stakerBalanceAfter);
    }

    function testClaimWithMinBoost() public {
        uint256 stakeAmount = ONE_TOKEN * 1e6; // 1M tokens
        uint16 stakingDays = 365; // one full year
        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, stakingDays);
        _fastforward(365 days);
        _addMeasurementsEpochInterval(1, 13, NODE_1_ID, 1000, 0, StakingUtils.NodeSlaLevel.Diamond);

        uint256 claimAmount = 198704251897700278604854; // MAX APY + 30%
        uint256 stakerBalanceBefore = token.balanceOf(alice);
        vm.prank(alice);
        staking.claim(stakeId);
        uint256 stakerBalanceAfter = token.balanceOf(alice);
        assertEq(stakerBalanceBefore + claimAmount, stakerBalanceAfter);
    }

    function testClaimWithMaxBoost() public {
        uint256 stakeAmount = ONE_TOKEN * 1e6; // 1M tokens
        uint16 stakingDays = 730; //2 years
        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, stakingDays);
        _fastforward(365 days);
        _addMeasurementsEpochInterval(1, 13, NODE_1_ID, 1000, 0, StakingUtils.NodeSlaLevel.Diamond);

        uint256 claimAmount = 229274136805038783005601; // MAX APY + 50%
        uint256 stakerBalanceBefore = token.balanceOf(alice);
        vm.prank(alice);
        staking.claim(stakeId);
        uint256 stakerBalanceAfter = token.balanceOf(alice);
        assertEq(stakerBalanceBefore + claimAmount, stakerBalanceAfter);
    }

    function testClaimWithMaxBoostMax3Years() public {
        uint256 stakeAmount = ONE_TOKEN * 1e6; // 1M tokens
        uint16 stakingDays = 1095; //3 years
        // Set boost setings to 30-100% for 3 years
        vm.prank(admin);
        settings.setApyBoostDeltaPercent(70); // delta 70% => max boost 30+70=100%
        vm.prank(admin);
        settings.setApyBoostMaxDays(1095); // max boost will be reached at 3 years mark
        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, stakingDays);
        _fastforward(730 days);
        _addMeasurementsEpochInterval(1, 13, NODE_1_ID, 1000, 0, StakingUtils.NodeSlaLevel.Diamond);

        uint256 claimAmount = 305698849073385044007468; // MAX APY + 100%
        uint256 stakerBalanceBefore = token.balanceOf(alice);
        vm.prank(alice);
        staking.claim(stakeId);
        uint256 stakerBalanceAfter = token.balanceOf(alice);
        assertEq(stakerBalanceBefore + claimAmount, stakerBalanceAfter);
    }

    function testClaimWithMaxBoostBoostChanges() public {
        uint256 stakeAmount = ONE_TOKEN * 1e6; // 1M tokens
        uint16 stakingDays = 1095; //3 years
        // Set boost setings to 30-40% for 3 years
        vm.prank(admin);
        settings.setApyBoostDeltaPercent(10);
        vm.prank(admin);
        settings.setApyBoostMaxDays(1095); // max boost will be reached at 3 years mark
        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, stakingDays);
        _fastforward(730 days);
        _addMeasurementsEpochInterval(1, 13, NODE_1_ID, 1000, 0, StakingUtils.NodeSlaLevel.Diamond);

        uint256 claimAmount = 213989194351369530805227; // MAX APY + 40%
        uint256 stakerBalanceBefore = token.balanceOf(alice);
        // APY Boost changes before claim
        vm.prank(admin);
        settings.setApyBoostMaxDays(1460); // max boost will be reached at 4 years instead of 3
        vm.prank(admin);
        settings.setApyBoostDeltaPercent(2); // max apy now is 30+2=32%
        vm.prank(alice);
        staking.claim(stakeId); // claim happens at stake moment settings
        uint256 stakerBalanceAfter = token.balanceOf(alice);
        assertEq(stakerBalanceBefore + claimAmount, stakerBalanceAfter);
    }

    function testRevertBoostMaxDaysTooLow() public {
        vm.prank(admin);
        vm.expectRevert("Min 366 days");
        settings.setApyBoostMaxDays(100);
        vm.prank(admin);
        vm.expectRevert("Min 366 days");
        settings.setApyBoostMaxDays(365);
    }

    function testClaimWithNoBoostMaxYears() public {
        uint256 stakeAmount = ONE_TOKEN * 1e6; // 1M tokens
        uint16 stakingDays = 730; //2 years
        // Set boost setings to 0-0% for 1 years
        vm.prank(admin);
        settings.setApyBoostMinPercent(0);
        vm.prank(admin);
        settings.setApyBoostDeltaPercent(0);
        vm.prank(admin);
        settings.setApyBoostMaxDays(366);
        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, stakingDays);
        _fastforward(730 days);
        _addMeasurementsEpochInterval(1, 13, NODE_1_ID, 1000, 0, StakingUtils.NodeSlaLevel.Diamond);

        uint256 claimAmount = 152849424536692522003734; // MAX APY, no boost
        uint256 stakerBalanceBefore = token.balanceOf(alice);
        vm.prank(alice);
        staking.claim(stakeId);
        uint256 stakerBalanceAfter = token.balanceOf(alice);
        assertEq(stakerBalanceBefore + claimAmount, stakerBalanceAfter);
    }

    function testClaimNFTBoost3Seekers1Commander() public {
        _enableNFTBoost();
        uint256 stakeAmount = ONE_TOKEN * 1e6; // 1M tokens
        uint16 stakingDays = 364;
        uint256 stakeId = _stakeTokens(alice, NODE_1_ID, stakeAmount, stakingDays);
        _fastforward(364 days);
        _addMeasurementsEpochInterval(1, 13, NODE_1_ID, 1000, 0, StakingUtils.NodeSlaLevel.Diamond);

        uint256 claimAmount = 171955602603779087254200; // MAX APY + 12,5% * MAX APY, where 12,5% = 3 * 2.5% = 5%
        uint256 stakerBalanceBefore = token.balanceOf(alice);
        vm.prank(alice);
        staking.claim(stakeId);
        uint256 stakerBalanceAfter = token.balanceOf(alice);
        assertEq(stakerBalanceBefore + claimAmount, stakerBalanceAfter);
    }

    function testClaimNFTBoost1Titan() public {
        _enableNFTBoost();
        uint256 stakeAmount = ONE_TOKEN * 1e6; // 1M tokens
        uint16 stakingDays = 364;
        uint256 stakeId = _stakeTokens(bob, NODE_1_ID, stakeAmount, stakingDays);
        _fastforward(364 days);
        _addMeasurementsEpochInterval(1, 13, NODE_1_ID, 1000, 0, StakingUtils.NodeSlaLevel.Diamond);

        uint256 claimAmount = 175776838217196400304294; // MAX APY + 15% * MAX APY, where 15% is from 1 Titan NFT
        uint256 stakerBalanceBefore = token.balanceOf(bob);
        vm.prank(bob);
        staking.claim(stakeId);
        uint256 stakerBalanceAfter = token.balanceOf(bob);
        assertEq(stakerBalanceBefore + claimAmount, stakerBalanceAfter);
    }

    function testClaimNFTBoost1Seeker2Commanders3Titans() public {
        _enableNFTBoost();
        uint256 stakeAmount = ONE_TOKEN * 1e6; // 1M tokens

        // First give charlie some tokens from alice
        vm.prank(alice);
        token.transfer(charlie, stakeAmount);

        uint16 stakingDays = 364;
        uint256 stakeId = _stakeTokens(charlie, NODE_1_ID, stakeAmount, stakingDays);
        _fastforward(364 days);
        _addMeasurementsEpochInterval(1, 13, NODE_1_ID, 1000, 0, StakingUtils.NodeSlaLevel.Diamond);

        uint256 claimAmount = 240737843645290722155881; // MAX APY + 57,5% * MAX APY, where 57% = 2.5% + 2 * 5% + 3 * 15%
        uint256 stakerBalanceBefore = token.balanceOf(charlie);
        vm.prank(charlie);
        staking.claim(stakeId);
        uint256 stakerBalanceAfter = token.balanceOf(charlie);
        assertEq(stakerBalanceBefore + claimAmount, stakerBalanceAfter);
    }

    function testClaimNFTBoostDisabledExplicit() public {
        _enableNFTBoost();
        _disableNFTBoost();
        testClaimWithoutBoost();
    }

    function testRevertInvalidNFTApyBoost() public {
        _enableNFTBoost();
        vm.expectRevert("Invalid APY boost");
        vm.prank(admin);
        settings.changeNFTApyBoost(1, 1, 1);
    }

    function testRevertChangeNFTApyBoostButDisabled() public {
        vm.expectRevert("NFT APY boost disabled");
        vm.prank(admin);
        settings.changeNFTApyBoost(100, 100, 100);
    }

    function testChangeNFTApyBoostSeekersCommandersTitans() public {
        _enableNFTBoost();
        // Set 5% Seekers, 12% Commanders and 20% Titans
        _changeNFTApyBoost(50, 120, 200);

        uint256 stakeAmount = ONE_TOKEN * 1e6; // 1M tokens

        // First give charlie some tokens from alice
        vm.prank(alice);
        token.transfer(charlie, stakeAmount);

        uint16 stakingDays = 364;
        uint256 stakeId = _stakeTokens(charlie, NODE_1_ID, stakeAmount, stakingDays);
        _fastforward(364 days);
        _addMeasurementsEpochInterval(1, 13, NODE_1_ID, 1000, 0, StakingUtils.NodeSlaLevel.Diamond);

        uint256 claimAmount = 288885412374348866587057; // MAX APY + 89% * MAX APY, where 89% = 5% + 2 * 12% + 3 * 20%
        uint256 stakerBalanceBefore = token.balanceOf(charlie);
        vm.prank(charlie);
        staking.claim(stakeId);
        uint256 stakerBalanceAfter = token.balanceOf(charlie);
        assertEq(stakerBalanceBefore + claimAmount, stakerBalanceAfter);
    }

    function testHugeNFTApyBoostAllTypes() public {
        _enableNFTBoost();
        // Set 20% Seekers, 40% Commanders and 55% Titans
        _changeNFTApyBoost(200, 400, 550);

        uint256 stakeAmount = ONE_TOKEN * 1e6; // 1M tokens

        // First give charlie some tokens from alice
        vm.prank(alice);
        token.transfer(charlie, stakeAmount);

        uint16 stakingDays = 364;
        uint256 stakeId = _stakeTokens(charlie, NODE_1_ID, stakeAmount, stakingDays);
        _fastforward(364 days);
        _addMeasurementsEpochInterval(1, 13, NODE_1_ID, 1000, 0, StakingUtils.NodeSlaLevel.Diamond);

        uint256 claimAmount = 557900399558927705313629; // MAX APY + 265% * MAX APY, where 265% = 20% + 2 * 40% + 3 * 55%
        uint256 stakerBalanceBefore = token.balanceOf(charlie);
        vm.prank(charlie);
        staking.claim(stakeId);
        uint256 stakerBalanceAfter = token.balanceOf(charlie);
        assertEq(stakerBalanceBefore + claimAmount, stakerBalanceAfter);
    }

    function _changeNFTApyBoost(uint16 seekersBoost, uint16 commandersBoost, uint16 titansBoost) internal {
        vm.expectEmit(true, true, true, true, address(settings));
        emit NFTApyBoostChanged(address(nftCollection), seekersBoost, commandersBoost, titansBoost);
        vm.prank(admin);
        settings.changeNFTApyBoost(seekersBoost, commandersBoost, titansBoost);
    }

    function _disableNFTBoost() internal {
        vm.expectEmit(true, false, false, true, address(settings));
        emit NFTApyBoostDisabled(address(nftCollection));
        vm.prank(admin);
        settings.disableNFTApyBoost();
    }

    function _enableNFTBoost() internal {
        vm.expectEmit(true, false, false, true, address(settings));
        emit NFTApyBoostEnabled(address(nftCollection));
        vm.prank(admin);
        settings.enableNFTApyBoost(address(nftCollection));
    }
}
