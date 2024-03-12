// solhint-disable ordering
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Staking.sol";
import "../src/Token.sol";
import "./Utils.t.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract Base is Test {
    Staking public staking;
    ERC20 public token;
    ERC1967Proxy public proxy;

    Utils public utils;

    address public admin = vm.addr(1);
    address public roleAdmin = vm.addr(2);
    address public supervisor = vm.addr(3);
    address public alice = vm.addr(4);
    address public bob = vm.addr(5);
    address public charlie = vm.addr(6);
    address public mallory = vm.addr(7);

    uint256 public deployTimestamp;

    uint256 public constant ONE_TOKEN = 1e18;
    uint256 public constant CONTRACT_INITIAL_BALANCE = ONE_TOKEN * 1e6 * 30; // 30M
    uint256 public constant MIN_STAKING_AMOUNT = ONE_TOKEN * 1000;
    uint256 public constant MAX_NODE_STAKING_AMOUNT = 1e8 * ONE_TOKEN;
    uint16 public constant EPOCH_PERIOD_DAYS = 28;
    uint256 public constant EPOCH_PERIOD_SECONDS = EPOCH_PERIOD_DAYS * 1 days;
    uint24 public constant MIN_RPS = 25;
    uint24 public constant MAX_RPS = 1000;
    uint16 public constant MAX_APY = 1e4;
    uint16 public constant NODE_REWARD_PERCENT = 30;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x0;
    bytes32 public constant SUPERVISOR_ROLE = keccak256("SUPERVISOR_ROLE");

    bytes32 public constant NODE_1_ID = keccak256("NODE_1");

    event TokensStaked(
        address indexed sender,
        uint256 indexed stakeId,
        bytes32 nodeId,
        uint256 amount,
        uint16 stakingDays
    );
    event TokensClaimed(address indexed sender, uint256 indexed stakeId, uint256 amount, uint256 lastClaimedEpoch);
    event PenaltyApplied(address indexed sender, uint256 stakeId, uint256 penaltyAmount);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event EpochClaimed(address indexed sender, uint256 stakeId, uint256 epoch);
    event NodeTokensClaimed(address indexed sender, bytes32 indexed nodeId, uint256 amount);
    event NodeMeasured(
        bytes32 indexed nodeId,
        uint24 rps,
        uint16 penaltyDays,
        Staking.NodeSlaLevel slaLevel,
        uint256 epoch
    );

    function _deployERC20() internal {
        token = new ERC20();
    }

    function _deployUtils() internal {
        utils = new Utils();
    }

    function _deployProxy(address staking_) internal {
        proxy = new ERC1967Proxy(staking_, "");
    }

    function _labelAddresses() internal {
        vm.label(admin, "Admin");
        vm.label(roleAdmin, "RoleAdmin");
        vm.label(supervisor, "Supervisor");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");
        vm.label(mallory, "Mallory");
    }

    function _deployStaking() internal {
        staking = new Staking();
    }

    function _addSupervisors() internal {
        staking.grantRole(SUPERVISOR_ROLE, supervisor);
    }

    function _setupERC20Balances() internal {
        token.transfer(alice, 1e58);
        token.transfer(bob, ONE_TOKEN * 1e6 * 5); // Bob gets 5M tokens
        token.transfer(address(staking), CONTRACT_INITIAL_BALANCE); // Staking smart contract gets 30M tokens
    }

    function _stakeTokens(
        address staker,
        bytes32 nodeId,
        uint256 amount,
        uint16 stakingDays
    ) internal returns (uint256) {
        vm.startPrank(staker);
        token.approve(address(staking), amount);
        uint256 stakeId = staking.stakeTokens(nodeId, amount, stakingDays);
        vm.stopPrank();

        return stakeId;
    }

    function _addMeasurement(
        uint256 epoch,
        bytes32 node,
        uint24 rps,
        uint16 penaltyDays,
        Staking.NodeSlaLevel sla
    ) internal {
        bytes32[] memory nodesArray = new bytes32[](1);
        uint24[] memory rpsArray = new uint24[](1);
        uint16[] memory penaltyArray = new uint16[](1);
        uint8[] memory slaLevels = new uint8[](1);

        nodesArray[0] = node;
        rpsArray[0] = rps;
        penaltyArray[0] = penaltyDays;
        slaLevels[0] = uint8(sla);

        vm.prank(supervisor);
        staking.addMeasurements(epoch, nodesArray, rpsArray, penaltyArray, slaLevels);
    }

    function _addMeasurementsEpochInterval(
        uint256 startEpoch,
        uint256 endEpoch,
        bytes32 node,
        uint24 rps,
        uint16 penaltyDays,
        Staking.NodeSlaLevel sla
    ) internal {
        uint256 i = startEpoch;
        for (; i <= endEpoch; i += 1) {
            _addMeasurement(i, node, rps, penaltyDays, sla);
        }
    }

    function _fastforward(uint256 period) internal {
        vm.warp(block.timestamp + period);
    }

    function setUp() public virtual {
        vm.warp(1677441388);
        _labelAddresses();

        // Save deploy timestamp
        deployTimestamp = block.timestamp;

        vm.startPrank(admin);

        _deployERC20();
        _deployUtils();
        _deployStaking();
        _deployProxy(address(staking));

        staking = Staking(address(proxy));
        staking.initialize(address(token));

        staking.grantRole(DEFAULT_ADMIN_ROLE, roleAdmin);
        staking.revokeRole(DEFAULT_ADMIN_ROLE, admin);

        _setupERC20Balances();

        vm.stopPrank();

        vm.prank(roleAdmin);
        _addSupervisors();
    }
}
