// solhint-disable ordering
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/Test.sol";
import "../src/Staking.sol";
import "../src/TimelockAdmin.sol";
import "../src/mocks/Token.sol";
import "../src/mocks/ERC721.sol";
import "../src/mocks/GnosisSafe.sol";
import "./Utils.t.sol";

contract Base is Test, IStakingEvents {
    StakingSettings public settings;
    Staking public staking;
    ERC20Mock public token;
    ERC1967Proxy public proxy;
    NFTCollectionMock public nftCollection;

    Utils public utils;

    address public DEPRECATED_EOA_ADMIN = vm.addr(1);
    address public supervisor = vm.addr(2);
    address public newSupervisor = vm.addr(3);
    address public alice = vm.addr(4);
    address public bob = vm.addr(5);
    address public charlie = vm.addr(6);
    address public mallory = vm.addr(7);

    address[] gnosisAdmins;
    address safeAdmin1of3Address;
    address safeAdmin2of3Address;
    address safeAdmin3of3Address;
    uint256 safeAdmin1of3PrivateKey;
    uint256 safeAdmin2of3PrivateKey;
    uint256 safeAdmin3of3PrivateKey;

    /// @dev [safeAdmin1of3Address,safeAdmin2of3Address,safeAdmin3of3Address] are owners of Gnosi Safe adminMultiSig with 2/3 threshold
    SafeL2 public adminMultiSig;
    /// @dev Address will be set after _deployGnosisSafe()
    address public multisig;

    /// @dev adminMultiSig is proposal/executor/cancelor of timelockAdmin. TimelockAdmin is self administred, has no external admin roles
    TimelockAdmin public timelockAdmin;
    /// @dev admin will hold address of timelockAdmin contract after _deployTimeLockAdmin()
    address public admin;

    uint256 public deployTimestamp;

    /**
     * @dev Copied from TimelockAdmin.sol in OpenZeppelin
     */
    event MinDelayChange(uint256 oldDuration, uint256 newDuration);
    bytes32 public constant TIMELOCK_ADMIN_ROLE = keccak256("TIMELOCK_ADMIN_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");

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

    bytes32 public constant STAKING_SETTINGS_ADMIN_ROLE = keccak256("STAKING_SETTINGS_ADMIN_ROLE");
    bytes32 public constant STAKING_ADMIN_ROLE = keccak256("STAKING_ADMIN_ROLE");
    bytes32 public constant SUPERVISOR_ROLE = keccak256("SUPERVISOR_ROLE");
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x0;

    bytes32 public constant NODE_1_ID = keccak256("NODE_1");

    uint256 public constant TWO_DAYS_IN_SECONDS = 2 days;

    uint256 public constant DEFAULT_GAS_LIMIT = 5 ether;
    uint256 internal _gnosisSafeNonce = 0;

    /**
     * @dev Copied from IAccessControl within OpenZeppelin lib
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /// Standard ERC20 Transfer event
    event Transfer(address indexed from, address indexed to, uint256 value);

    function _getNextGnosisSafeNonce() internal returns (uint256) {
        uint256 currentNonce = _gnosisSafeNonce;
        _gnosisSafeNonce++;
        return currentNonce;
    }

    /// @dev Returns (r, s, v) encoded packed
    function _multisigGetSignature(
        uint256 signingKey,
        address to,
        bytes memory calldata_,
        uint256 gasLimit,
        uint256 nonce
    ) internal view returns (bytes memory) {
        bytes32 hash = adminMultiSig.getTransactionHash(
            to,
            0,
            calldata_,
            Enum.Operation.Call,
            gasLimit,
            1,
            1,
            address(0),
            address(0),
            nonce
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingKey, hash);
        bytes memory sigPacked = abi.encodePacked(r, s, v);
        return sigPacked;
    }

    function _multisigApprove1of3(
        address to,
        bytes memory calldata_,
        uint256 gasLimit
    ) internal returns (bytes memory) {
        uint256 currentNonce = _getNextGnosisSafeNonce();
        return _multisigGetSignature(safeAdmin1of3PrivateKey, to, calldata_, gasLimit, currentNonce);
    }

    function _multisigApprove2of3(
        address to,
        bytes memory calldata_,
        uint256 gasLimit
    ) internal returns (bytes memory) {
        uint256 currentNonce = _getNextGnosisSafeNonce();
        bytes memory sig1 = _multisigGetSignature(safeAdmin1of3PrivateKey, to, calldata_, gasLimit, currentNonce);
        bytes memory sig2 = _multisigGetSignature(safeAdmin2of3PrivateKey, to, calldata_, gasLimit, currentNonce);
        /// @dev Gnosis Safe expects signatures to be ordered by the (ecrecover) address
        return bytes.concat(sig2, sig1);
    }

    function _multisigApprove3of3(
        address to,
        bytes memory calldata_,
        uint256 gasLimit
    ) internal returns (bytes memory) {
        uint256 currentNonce = _getNextGnosisSafeNonce();
        bytes memory sig1 = _multisigGetSignature(safeAdmin1of3PrivateKey, to, calldata_, gasLimit, currentNonce);
        bytes memory sig2 = _multisigGetSignature(safeAdmin2of3PrivateKey, to, calldata_, gasLimit, currentNonce);
        bytes memory sig3 = _multisigGetSignature(safeAdmin3of3PrivateKey, to, calldata_, gasLimit, currentNonce);
        /// @dev Gnosis Safe expects signatures to be ordered by the (ecrecover) address
        return bytes.concat(bytes.concat(sig2, sig1), sig3);
    }

    function _multisigExecute(address to, bytes memory calldata_, uint256 gasLimit, bytes memory signatures) internal {
        adminMultiSig.execTransaction(
            to,
            0,
            calldata_,
            Enum.Operation.Call,
            gasLimit,
            1,
            1,
            address(0),
            payable(0),
            signatures
        );
    }

    function _deployGnosisSafe() internal {
        SafeL2 safeSingleton = new SafeL2();
        SafeProxyFactory safeFactory = new SafeProxyFactory();
        (safeAdmin1of3Address, safeAdmin1of3PrivateKey) = makeAddrAndKey("safeAdmin1of3");
        (safeAdmin2of3Address, safeAdmin2of3PrivateKey) = makeAddrAndKey("safeAdmin2of3");
        (safeAdmin3of3Address, safeAdmin3of3PrivateKey) = makeAddrAndKey("safeAdmin3of3");

        gnosisAdmins.push(safeAdmin1of3Address);
        gnosisAdmins.push(safeAdmin2of3Address);
        gnosisAdmins.push(safeAdmin3of3Address);
        bytes memory emptyPayload;

        bytes memory setupPayload = abi.encodeWithSignature(
            "setup(address[],uint256,address,bytes,address,address,uint256,address)",
            gnosisAdmins,
            2,
            address(0),
            emptyPayload,
            address(0),
            address(0),
            0,
            payable(0)
        );
        SafeProxy safeProxy = safeFactory.createProxyWithNonce(address(safeSingleton), setupPayload, 1);
        adminMultiSig = SafeL2(payable(safeProxy));
        multisig = address(adminMultiSig);
    }

    function _timelockSchedule(address to, bytes memory calldata_, uint256 delay) internal {
        timelockAdmin.schedule(to, 0, calldata_, 0x0, 0x0, delay);
    }

    function _timelockExecute(address to, bytes memory calldata_) internal {
        timelockAdmin.execute(to, 0, calldata_, 0x0, 0x0);
    }

    function _deployTimeLockAdmin() internal {
        address gnosiSafeAdmin = address(adminMultiSig);
        address[] memory proposersExecutorsCancellers = new address[](1);
        proposersExecutorsCancellers[0] = gnosiSafeAdmin;
        timelockAdmin = new TimelockAdmin(proposersExecutorsCancellers);
        admin = address(timelockAdmin);
    }

    function _deployERC20() internal {
        token = new ERC20Mock();
    }

    function _deployUtils() internal {
        utils = new Utils();
    }

    function _deployProxy(address staking_) internal {
        proxy = new ERC1967Proxy(staking_, "");
    }

    function _labelAddresses() internal {
        vm.label(DEPRECATED_EOA_ADMIN, "DEPRECATED_EOA_ADMIN");
        vm.label(admin, "Admin");
        vm.label(supervisor, "Supervisor");
        vm.label(newSupervisor, "NewSupervisor");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");
        vm.label(mallory, "Mallory");
    }

    function _deployStakingSettings() internal {
        /// @dev Could have passed admin but better to be explicit with timelockAdmin
        settings = new StakingSettings(address(timelockAdmin));
    }

    function _deployStaking() internal {
        staking = new Staking();
    }

    function _deployNFTCollection() internal {
        nftCollection = new NFTCollectionMock("OMNIA pfp NFTs", "OMNIANFT");
    }

    function _addSupervisors() internal {
        /// @dev Could have passed admin but better to be explicit with timelockAdmin
        vm.prank(address(timelockAdmin));
        staking.grantRole(SUPERVISOR_ROLE, supervisor);
    }

    function _setupERC20Balances() internal {
        vm.startPrank(admin);
        token.transfer(alice, 1e58);
        token.transfer(bob, ONE_TOKEN * 1e6 * 5); // Bob gets 5M tokens
        token.transfer(address(staking), CONTRACT_INITIAL_BALANCE); // Staking smart contract gets 30M tokens
        vm.stopPrank();
    }

    function _setupNFTCollectionBalances() internal {
        // Alice gets 3 seekers and 1 commander
        nftCollection.safeMint(alice, 0); // seeker nft
        nftCollection.safeMint(alice, 10); // seeker nft
        nftCollection.safeMint(alice, 2665); // seeker nft
        nftCollection.safeMint(alice, 3000); // commander nft

        // Bob gets 1 titans
        nftCollection.safeMint(bob, 4000);

        // Charlie gets 1 seeker, 2 commanders and 3 titans
        nftCollection.safeMint(charlie, 5); // seeker nft
        nftCollection.safeMint(charlie, 2666); // commander nft
        nftCollection.safeMint(charlie, 3999); // commander nft
        nftCollection.safeMint(charlie, 4020); // titan nft
        nftCollection.safeMint(charlie, 4120); // titan nft
        nftCollection.safeMint(charlie, 4443); // titan nft
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
        StakingUtils.NodeSlaLevel sla
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
        StakingUtils.NodeSlaLevel sla
    ) internal {
        uint256 i = startEpoch;
        for (; i <= endEpoch; i += 1) {
            _addMeasurement(i, node, rps, penaltyDays, sla);
        }
    }

    function _fastforward(uint256 period) internal {
        vm.warp(block.timestamp + period);
    }

    function _setup() internal {
        vm.warp(1677441388);
        _labelAddresses();

        // Save deploy timestamp
        deployTimestamp = block.timestamp;

        /// @dev [safeAdmin1of3Address,safeAdmin2of3Address,safeAdmin3of3Address] are owners of Gnosi Safe adminMultiSig with 2/3 threshold
        _deployGnosisSafe();

        /// @dev adminMultiSig is proposal/executor/cancelor of timelockAdmin. TimelockAdmin is self administred, has no external admin roles
        _deployTimeLockAdmin();

        /// @dev override Admin label with new address of timelockAdmin hold in admin variable
        vm.label(admin, "Admin");

        /// @dev admin now holds address of timelockAdmin contract
        vm.startPrank(admin);

        _deployERC20();
        _deployUtils();
        _deployStakingSettings();
        _deployStaking();
        _deployNFTCollection();
        _deployProxy(address(staking));

        staking = Staking(address(proxy));
        staking.initialize(address(token), address(settings), address(timelockAdmin));

        _setupERC20Balances();
        _setupNFTCollectionBalances();

        vm.stopPrank();
        _addSupervisors();
    }

    function setUp() public virtual {
        _setup();
    }

    /// @dev This test will run as part of every future test that inherited base test (this file)
    function testEnsureAdminPermissionsTree() public {
        /// @dev Ensure admin label holds the timelock contract address
        assertEq(admin, address(timelockAdmin));

        /// @dev Ensure Timelock is controlled by Gnosis Safe
        assertEq(multisig, address(adminMultiSig));
        assertTrue(timelockAdmin.hasRole(PROPOSER_ROLE, multisig));
        assertTrue(timelockAdmin.hasRole(EXECUTOR_ROLE, multisig));
        assertTrue(timelockAdmin.hasRole(CANCELLER_ROLE, multisig));

        /// @dev Ensure Staking settings is controlled by timelock contract
        assertTrue(settings.hasRole(STAKING_SETTINGS_ADMIN_ROLE, admin));

        /// @dev Ensure Staking is controller by timelock contract
        assertTrue(staking.hasRole(STAKING_ADMIN_ROLE, admin));
    }
}
