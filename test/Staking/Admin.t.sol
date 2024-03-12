// solhint-disable ordering
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../Base.t.sol";

contract AdminTest is Base {
    // max apy

    function testRevertIfNotAdminSetMaxApy() public {
        vm.expectRevert("Caller is not an admin");
        staking.setMaxApy(Staking.NodeSlaLevel.Silver, 100);
    }

    function testRevertIfNotAdminSetMaxRps() public {
        vm.expectRevert("Caller is not an admin");
        staking.setMaxRps(MAX_RPS);
    }

    function testRevertIfApyExceedMaxSetMaxApy() public {
        uint256 newApy = MAX_APY + 1;
        Staking.NodeSlaLevel sla = Staking.NodeSlaLevel.Silver;

        vm.prank(admin);
        vm.expectRevert("Invalid APY");
        staking.setMaxApy(sla, newApy);
    }

    function testRevertIfApyBelowMinSetMaxApy() public {
        uint256 newApy = 0;
        Staking.NodeSlaLevel sla = Staking.NodeSlaLevel.Silver;

        vm.prank(admin);
        vm.expectRevert("Invalid APY");
        staking.setMaxApy(sla, newApy);
    }

    function testSetMaxApyToMin() public {
        uint256 newApy = 1;
        Staking.NodeSlaLevel sla = Staking.NodeSlaLevel.Silver;

        vm.prank(admin);
        staking.setMaxApy(sla, newApy);
    }

    function testSetMaxApyToMax() public {
        uint256 newApy = MAX_APY;
        Staking.NodeSlaLevel sla = Staking.NodeSlaLevel.Silver;

        vm.prank(admin);
        staking.setMaxApy(sla, newApy);
    }

    // supervisor management

    function testRevertIfNotRoleAdminAddSupervisor() public {
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(address(0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496)),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(DEFAULT_ADMIN_ROLE), 32)
            )
        );
        staking.grantRole(SUPERVISOR_ROLE, alice);
    }

    function testRevertIfNotRoleAdminRemoveSupervisor() public {
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(address(0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496)),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(DEFAULT_ADMIN_ROLE), 32)
            )
        );
        staking.revokeRole(SUPERVISOR_ROLE, alice);
    }

    function testRevertAdminCantGrantSupervisor() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(admin),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(DEFAULT_ADMIN_ROLE), 32)
            )
        );
        staking.grantRole(SUPERVISOR_ROLE, alice);
    }

    function testRevertAdminCantRevokeSupervisor() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(admin),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(DEFAULT_ADMIN_ROLE), 32)
            )
        );
        staking.revokeRole(SUPERVISOR_ROLE, alice);
    }

    function testGrantSupervisor() public {
        vm.prank(roleAdmin);
        staking.grantRole(SUPERVISOR_ROLE, alice);
        assertEq(staking.hasRole(SUPERVISOR_ROLE, alice), true);
    }

    function testRevokeSupervisor() public {
        vm.prank(roleAdmin);
        staking.revokeRole(SUPERVISOR_ROLE, supervisor);
        assertEq(staking.hasRole(SUPERVISOR_ROLE, supervisor), false);
    }

    // min staking

    function testRevertIfNotAdminSetMinStaking() public {
        vm.expectRevert("Caller is not an admin");
        staking.setMinStakingAmount(100);
    }

    function testRevertIfNotAdminSetMinRps() public {
        vm.expectRevert("Caller is not an admin");
        staking.setMinRps(MIN_RPS);
    }

    function testFuzzSetMinStaking(uint256 amount) public {
        /// @dev max staking per node default
        vm.assume(amount <= 1e8 * 1e18 && amount > 0);

        vm.prank(admin);
        staking.setMinStakingAmount(amount);
        uint16 period = EPOCH_PERIOD_DAYS;

        _stakeTokens(alice, NODE_1_ID, amount, period);
    }

    // max staking per node

    function testFuzzSetMaxStakingAmountPerNode(uint256 amount) public {
        // default min staking and max token
        vm.assume(amount >= 1000 * ONE_TOKEN && amount < 100e6 ether);

        vm.prank(admin);
        staking.setMaxStakingAmountPerNode(amount);
        uint16 period = EPOCH_PERIOD_DAYS;

        _stakeTokens(alice, NODE_1_ID, amount, period);
    }

    // min/max rps

    function testRevertIfMinRpsBelow1() public {
        uint24 minRps = 0;

        vm.prank(admin);
        vm.expectRevert("Exceeds max RPS or below 1");
        staking.setMinRps(minRps);
    }

    function testRevertIfMinRpsAboveMaxSetMinRps() public {
        uint24 minRps = MAX_RPS + 1;

        vm.prank(admin);
        vm.expectRevert("Exceeds max RPS or below 1");
        staking.setMinRps(minRps);
    }

    function testSetMinRps() public {
        uint24 minRps = MIN_RPS - 1;
        uint256 epoch = 1;
        uint16 penaltyDays = 0;
        Staking.NodeSlaLevel sla = Staking.NodeSlaLevel.Diamond;

        vm.prank(admin);
        staking.setMinRps(minRps);

        _stakeTokens(alice, NODE_1_ID, 1e21, 28);

        _fastforward(30 days);
        _addMeasurement(epoch, NODE_1_ID, minRps, penaltyDays, sla);
    }

    function testRevertIfMaxRpsBelowMinSetMaxRps() public {
        uint24 maxRps = MIN_RPS - 1;

        vm.prank(admin);
        vm.expectRevert("Below min RPS");
        staking.setMaxRps(maxRps);
    }

    function testSetMaxRps() public {
        uint24 maxRps = 2 ** 24 - 1;
        uint256 epoch = 1;
        uint16 penaltyDays = 0;
        Staking.NodeSlaLevel sla = Staking.NodeSlaLevel.Diamond;

        vm.prank(admin);
        staking.setMaxRps(maxRps);

        _stakeTokens(alice, NODE_1_ID, 1e21, 28);

        _fastforward(30 days);
        _addMeasurement(epoch, NODE_1_ID, maxRps, penaltyDays, sla);
    }

    // penalty rate

    function testRevertSetPenaltyRateOutOfBounds() public {
        vm.prank(admin);
        vm.expectRevert("Rate exceeds limit");
        staking.setPenaltyRate(1e4);
    }

    function testSetPenaltyRate() public {
        vm.prank(admin);
        staking.setPenaltyRate(1e4 - 1);
    }

    function testSetPenaltyRateToZero() public {
        vm.prank(admin);
        staking.setPenaltyRate(0);
    }

    // node owner reward percent

    function testSetNodeOwnerRewardPercentToZero() public {
        vm.prank(admin);
        staking.setNodeOwnerRewardPercent(0);
    }

    function testSetNodeOwnerRewardPercentToMax() public {
        vm.prank(admin);
        staking.setNodeOwnerRewardPercent(1e2);
    }

    function testRevertSetNodeOwnerRewardPercentIfAboveMax() public {
        vm.prank(admin);
        vm.expectRevert("Exceeds limit");
        staking.setNodeOwnerRewardPercent(1e2 + 1);
    }

    // other

    function testDefaultAdmin() public {
        assertEq(staking.hasRole(ADMIN_ROLE, admin), true);
    }

    function testVerifyStartEpoch() public {
        assertEq(staking.getContractStartTimestamp(), deployTimestamp);
    }
}
