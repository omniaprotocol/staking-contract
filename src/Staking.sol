// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
/// @dev due to PRB math internal limitations if powerBase is less than 1 - SD59x18 instead of UD60x18 has to be used
import "prb-math/SD59x18.sol" as Prb;

contract Staking is Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    enum NodeSlaLevel {
        Silver,
        Gold,
        Platinum,
        Diamond
    }

    // Holds measurement for one epoch per node
    struct Measurement {
        Prb.SD59x18 interest; // Computed interest for this measurement
        Prb.SD59x18 penalty; // Computed penalty for this measurement
        uint24 rps;
        uint16 penaltyDays;
        NodeSlaLevel slaLevel;
    }

    struct Node {
        // Each epoch has a measurement
        mapping(uint256 => Measurement) measurements;
        uint256 stakedAmount;
        uint256 claimableAmount;
    }

    struct Stake {
        bytes32 nodeId;
        uint256 amount; // amount of OMNIA tokens staked
        uint256 lastClaimedEpoch;
        uint32 startTimestamp;
        uint32 withdrawnTimestamp;
        address staker;
        uint16 stakingDays;
    }

    struct Settings {
        uint24 minRps;
        uint24 maxRps;
        uint16 nodeOwnerRewardPercent;
        uint256 maxStakingAmountPerNode;
        uint256 minStakingAmount;
        /// @notice settings set indirectly
        Prb.SD59x18 dailyPenaltyRate; /// @dev stored as a multiplier rate 0.9xxxx
        Prb.SD59x18 epochPenaltyRate; /// @dev stored as a multiplier rate 0.9xxxx
        Prb.SD59x18 apyParameterOne; /// @dev First parameter used in APY formula
        Prb.SD59x18 apyParameterTwo; /// @dev Second parameter used in APY formula
    }

    mapping(NodeSlaLevel => uint256) private _maxApy; // holds values * 10ˆ2 for better decimal precision

    bytes32 private constant _ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 private constant _SUPERVISOR_ROLE = keccak256("SUPERVISOR_ROLE");
    uint256 private constant _DAYS_IN_ONE_YEAR = 365;
    uint256 private constant _EPOCH_PERIOD_SECONDS = 28 days;
    uint256 private constant _EPOCH_PERIOD_DAYS = 28;

    /// @dev used in APY param calculation
    int256 private constant _APY_CURVE_RATIO = 801029995663981195;
    Prb.SD59x18 private constant _ONE = Prb.SD59x18.wrap(1e18);

    address private _token;
    uint256 private _contractStartTimestamp;
    uint256 private _stakeIdCounter;

    Settings private _s;

    mapping(bytes32 => Node) private _nodes;
    mapping(uint256 => Stake) private _stakes;
    mapping(address => uint256[]) private _stakeIds;

    /// @notice staker events
    event TokensStaked(
        address indexed sender,
        uint256 indexed stakeId,
        bytes32 nodeId,
        uint256 amount,
        uint16 stakingDays
    );
    event TokensUnstaked(address indexed sender, uint256 indexed stakeId, bytes32 nodeId, uint256 amount);
    event TokensClaimed(address indexed sender, uint256 indexed stakeId, uint256 amount, uint256 lastClaimedEpoch);
    event EpochClaimed(address indexed sender, uint256 stakeId, uint256 epoch);
    event PenaltyApplied(address indexed sender, uint256 stakeId, uint256 penaltyAmount);

    /// @notice node owner events
    event NodeTokensClaimed(address indexed sender, bytes32 indexed nodeId, uint256 amount);

    /// @notice admin events
    event NodeMeasured(bytes32 indexed nodeId, uint24 rps, uint16 penaltyDays, NodeSlaLevel slaLevel, uint256 epoch);

    error ExistingMeasurement(bytes32 nodeId);
    error NothingStaked(bytes32 nodeId);

    modifier onlyAdmin() {
        require(hasRole(_ADMIN_ROLE, msg.sender), "Caller is not an admin");
        _;
    }

    modifier onlySupervisor() {
        require(hasRole(_SUPERVISOR_ROLE, msg.sender), "Caller is not a supervisor");
        _;
    }

    function setMinStakingAmount(uint256 amount) external onlyAdmin {
        require(amount > 0, "Cant be zero");
        require(_s.maxStakingAmountPerNode >= amount, "Above max stake amount per node");
        _s.minStakingAmount = amount;
    }

    function setMaxStakingAmountPerNode(uint256 amount) external onlyAdmin {
        require(amount <= 100e6 ether, "Exceed token supply");
        require(amount >= _s.minStakingAmount, "Below min stake amount");
        _s.maxStakingAmountPerNode = amount;
    }

    /// @param apy is a % value and must be multiplied by 10ˆ2
    function setMaxApy(NodeSlaLevel slaLevel, uint256 apy) external onlyAdmin {
        require(apy > 0 && apy <= 1e4, "Invalid APY");
        _maxApy[slaLevel] = apy;
    }

    function setMinRps(uint24 rps) external onlyAdmin {
        /// @dev zero is used to detect measurement existance
        require(rps <= _s.maxRps && rps > 0, "Exceeds max RPS or below 1");
        _s.minRps = rps;
        (_s.apyParameterOne, _s.apyParameterTwo) = _calculateApyParameters(_s.minRps, _s.maxRps);
    }

    function setMaxRps(uint24 rps) external onlyAdmin {
        require(rps >= _s.minRps, "Below min RPS");
        _s.maxRps = rps;
        (_s.apyParameterOne, _s.apyParameterTwo) = _calculateApyParameters(_s.minRps, _s.maxRps);
    }

    function setNodeOwnerRewardPercent(uint16 percent) external onlyAdmin {
        require(percent <= 1e2, "Exceeds limit");
        _s.nodeOwnerRewardPercent = percent;
    }

    /// @param penaltyRate is a % value and must be multiplied by 10ˆ2
    /// todo: confirm parameter bounds
    function setPenaltyRate(uint256 penaltyRate) external onlyAdmin {
        require(penaltyRate <= 9999, "Rate exceeds limit");
        _s.dailyPenaltyRate = _getPeriodCompoundInterestRate(Prb.convert(int256(penaltyRate)), _DAYS_IN_ONE_YEAR, true);
        _s.epochPenaltyRate = _compoundInterest(_s.dailyPenaltyRate, _EPOCH_PERIOD_DAYS);
    }

    function addMeasurements(
        uint256 epoch,
        bytes32[] calldata nodeIds,
        uint24[] calldata rps,
        uint16[] calldata penaltyDays,
        uint8[] calldata slaLevels
    ) external onlySupervisor {
        require(nodeIds.length == rps.length, "Unequal lengths");
        require(rps.length == penaltyDays.length, "Unequal lengths");
        require(penaltyDays.length == slaLevels.length, "Unequal lengths");
        require(slaLevels.length >= 1, "No data received");
        require(epoch < _getCurrentEpoch() && epoch > 0, "Invalid epoch");

        uint128 i = 0;
        for (; i < nodeIds.length; i = i + 1) {
            _addMeasurement(nodeIds[i], epoch, rps[i], penaltyDays[i], NodeSlaLevel(slaLevels[i]));
        }
    }

    function stakeTokens(bytes32 nodeId, uint256 amount, uint16 stakingDays) external nonReentrant returns (uint256) {
        require(amount >= _s.minStakingAmount, "Amount too small");
        require(stakingDays >= _EPOCH_PERIOD_DAYS, "Period too short");
        require(IERC20(_token).allowance(msg.sender, address(this)) >= amount, "Not enough allowance");

        require((_nodes[nodeId].stakedAmount + amount) <= _s.maxStakingAmountPerNode, "Node max amount reached");

        _stakeIdCounter += 1;
        uint256 stakeIdCounter = _stakeIdCounter;

        uint32 startTimestamp = _getNextDayStartTimestamp(
            _toUint32(block.timestamp),
            _toUint32(_contractStartTimestamp)
        );

        _stakes[stakeIdCounter] = Stake(nodeId, amount, 0, startTimestamp, 0, msg.sender, stakingDays);
        _stakeIds[msg.sender].push(stakeIdCounter);
        _nodes[nodeId].stakedAmount += amount;

        IERC20(_token).safeTransferFrom(msg.sender, address(this), amount);
        emit TokensStaked(msg.sender, stakeIdCounter, nodeId, amount, stakingDays);

        return stakeIdCounter;
    }

    function unstakeTokens(uint256 stakeId) external nonReentrant {
        Stake storage stake = _stakes[stakeId];

        require(stake.staker == msg.sender, "Not authorized");
        require(stake.withdrawnTimestamp == 0, "Already withdrawn");

        uint256 latestClaimableEpoch = _getLatestClaimableEpoch(stakeId);

        require(_canUnstake(stake.startTimestamp, stake.stakingDays, latestClaimableEpoch), "Too early");

        ///@notice Force claim rewards or apply penalities before unstaking

        int256 claimReward = 0;
        if (_stakes[stakeId].lastClaimedEpoch < latestClaimableEpoch) {
            claimReward = _claim(stakeId, latestClaimableEpoch);
        }

        uint256 stakeAmount = _stakes[stakeId].amount;
        bytes32 stakeNodeId = _stakes[stakeId].nodeId;

        stake.withdrawnTimestamp = _toUint32(block.timestamp);
        _nodes[stakeNodeId].stakedAmount -= stakeAmount;

        IERC20(_token).safeTransfer(msg.sender, claimReward > 0 ? _sumUintInt(stakeAmount, claimReward) : stakeAmount);
        emit TokensUnstaked(msg.sender, stakeId, stakeNodeId, stakeAmount);
    }

    /// @dev safety method in case the user wants to claim limited amount of epochs (can be removed if claim(uint256 stakeId) is sufficient)
    function claim(uint256 stakeId, uint256 epochs) external nonReentrant {
        require(epochs > 0, "Epoch count too low");
        require(_stakes[stakeId].staker == msg.sender, "Not authorized");
        require(_stakes[stakeId].withdrawnTimestamp == 0, "Already withdrawn");

        uint256 lastClaimedEpoch = _stakes[stakeId].lastClaimedEpoch;
        uint256 latestClaimableEpoch = _getLatestClaimableEpoch(stakeId);
        require(latestClaimableEpoch - lastClaimedEpoch >= epochs, "Epoch count too high");

        int256 claimReward = _claim(
            stakeId,
            _stakes[stakeId].lastClaimedEpoch == 0
                ? _getEpoch(_stakes[stakeId].startTimestamp) + (epochs - 1)
                : _stakes[stakeId].lastClaimedEpoch + epochs
        );
        if (claimReward > 0) {
            IERC20(_token).safeTransfer(msg.sender, uint256(claimReward));
        }
    }

    function claim(uint256 stakeId) external nonReentrant {
        require(_stakes[stakeId].staker == msg.sender, "Not authorized");
        require(_stakes[stakeId].withdrawnTimestamp == 0, "Already withdrawn");

        uint256 latestClaimableEpoch = _getLatestClaimableEpoch(stakeId);

        require(_stakes[stakeId].lastClaimedEpoch < latestClaimableEpoch, "Nothing to claim");

        int256 claimReward = _claim(stakeId, latestClaimableEpoch);
        if (claimReward > 0) {
            IERC20(_token).safeTransfer(msg.sender, uint256(claimReward));
        }
    }

    function claim(bytes32 nodeId) external nonReentrant {
        uint256 uNodeId = uint256(nodeId);
        address owner = address(uint160(uNodeId >> 96));
        uint256 claimableAmount = _nodes[nodeId].claimableAmount;

        require(msg.sender == owner, "Not owner");
        require(claimableAmount > 0, "Nothing to claim");

        _nodes[nodeId].claimableAmount = 0;

        IERC20(_token).safeTransfer(msg.sender, claimableAmount);
        emit NodeTokensClaimed(msg.sender, nodeId, claimableAmount);
    }

    function getStake(uint256 id) external view returns (Stake memory stake) {
        stake = _stakes[id];
    }

    function getStakeCount(address staker) external view returns (uint256) {
        return _stakeIds[staker].length;
    }

    function getStakeId(address staker, uint256 index) external view returns (uint256) {
        return _stakeIds[staker][index];
    }

    function getNodeMeasurement(bytes32 nodeId, uint256 epoch) external view returns (Measurement memory m) {
        m = _nodes[nodeId].measurements[epoch];
    }

    function getNode(bytes32 nodeId) external view returns (uint256, uint256) {
        return (_nodes[nodeId].stakedAmount, _nodes[nodeId].claimableAmount);
    }

    function getContractStartTimestamp() external view returns (uint256) {
        return _contractStartTimestamp;
    }

    // UUPS function
    function initialize(address stakingToken) public initializer {
        require(stakingToken != address(0x0), "Token cant be zero");

        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _contractStartTimestamp = block.timestamp;
        _token = stakingToken;

        _s.minStakingAmount = 1000 * 1e18;
        _s.minRps = 25;
        _s.maxRps = 1000;
        _s.maxStakingAmountPerNode = 1e8 * 1e18;
        _s.nodeOwnerRewardPercent = 0;

        int256 penaltyRate = 500; // Daily penalty rate, as percentage, multiplied by 10ˆ2. Example: 5 % = 500
        _s.dailyPenaltyRate = _getPeriodCompoundInterestRate(Prb.convert(penaltyRate), _DAYS_IN_ONE_YEAR, true);
        _s.epochPenaltyRate = _compoundInterest(_s.dailyPenaltyRate, _EPOCH_PERIOD_DAYS);

        (_s.apyParameterOne, _s.apyParameterTwo) = _calculateApyParameters(_s.minRps, _s.maxRps);

        _maxApy[NodeSlaLevel.Silver] = 383; // 3.83 * 10ˆ2
        _maxApy[NodeSlaLevel.Gold] = 767; // 7.67 * 10 ^2
        _maxApy[NodeSlaLevel.Platinum] = 1073; // 10.73 * 10ˆ2
        _maxApy[NodeSlaLevel.Diamond] = 1533; // 15.33 * 10ˆ2

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(_ADMIN_ROLE, msg.sender);
    }

    // UUPS function
    function _authorizeUpgrade(address) internal override onlyAdmin {}

    /// @dev caller function must make that all measurements are present
    function _computeFullEpochReward(
        bytes32 nodeId,
        uint256 stakeAmount,
        uint256 fromEpoch,
        uint256 untilEpoch
    ) private returns (int256) {
        Prb.SD59x18 reward = Prb.ZERO;
        Prb.SD59x18 stakeAmount_ = Prb.convert(int256(stakeAmount));
        Prb.SD59x18 amountCarryingInterest = stakeAmount_;

        Prb.SD59x18 interest = Prb.ZERO;
        Prb.SD59x18 penalty = Prb.ZERO;
        for (uint256 epoch = fromEpoch; epoch <= untilEpoch; epoch = epoch + 1) {
            (interest, penalty) = _getAndCacheMeasurementRates(nodeId, epoch);

            reward = Prb.add(_calculateInterestPenaltyYield(amountCarryingInterest, interest, penalty), reward);

            /// @dev "stakeAmount" and not "amountCarryingInterest" because the "reward" is carrying the full difference
            amountCarryingInterest = Prb.add(stakeAmount_, reward);
        }

        return Prb.convert(reward);
    }

    /// @dev Caller responsibility to validate epoch. slaLevel is validated by default.
    function _addMeasurement(
        bytes32 nodeId,
        uint256 epoch,
        uint24 rps,
        uint16 penaltyDays,
        NodeSlaLevel slaLevel
    ) private onlySupervisor {
        require((_s.minRps <= rps) && (rps <= _s.maxRps), "Invalid RPS");
        require(penaltyDays <= _EPOCH_PERIOD_DAYS, "Invalid penalty days");
        if (_nodes[nodeId].measurements[epoch].rps != 0) revert ExistingMeasurement(nodeId);
        if (_nodes[nodeId].stakedAmount == 0) revert NothingStaked(nodeId);

        emit NodeMeasured(nodeId, rps, penaltyDays, slaLevel, epoch);
        _nodes[nodeId].measurements[epoch] = Measurement(Prb.ZERO, Prb.ZERO, rps, penaltyDays, slaLevel);
    }

    /// @dev WARNING caller responsibility to stake validity (stake existance, is not withdrawn...)
    function _claim(uint256 stakeId, uint256 latestClaimableEpoch) private returns (int256) {
        bytes32 stakeNodeId = _stakes[stakeId].nodeId;
        uint256 stakeAmount = _stakes[stakeId].amount;
        uint32 stakeStartTimestamp = _stakes[stakeId].startTimestamp;
        uint256 stakeLastClaimedEpoch = _stakes[stakeId].lastClaimedEpoch;

        uint256 stakeFirstEpoch = _getEpoch(stakeStartTimestamp);

        uint256 daysUntilEpochEnd = _getDaysUntilEpochEnd(
            stakeStartTimestamp,
            stakeFirstEpoch,
            _contractStartTimestamp
        );
        bool isFirstEpochAndPartial = stakeLastClaimedEpoch == 0 && daysUntilEpochEnd < _EPOCH_PERIOD_DAYS;

        int256 reward = 0;

        /// @dev check and claim FIRST epoch partially
        if (isFirstEpochAndPartial) {
            reward += _computePartialEpochReward(stakeNodeId, stakeAmount, stakeFirstEpoch, daysUntilEpochEnd);
        }

        /// @dev only start from full staking epoch
        uint256 fullEpochFrom = stakeLastClaimedEpoch == 0
            ? stakeFirstEpoch + (isFirstEpochAndPartial ? 1 : 0)
            : stakeLastClaimedEpoch + 1;

        /// @dev check and claim any FULL epochs
        if (fullEpochFrom <= latestClaimableEpoch) {
            reward += _computeFullEpochReward(
                stakeNodeId,
                _sumUintInt(stakeAmount, reward),
                fullEpochFrom,
                latestClaimableEpoch
            );
        }

        _stakes[stakeId].lastClaimedEpoch = latestClaimableEpoch;

        for (uint256 epoch = stakeLastClaimedEpoch + 1; epoch <= latestClaimableEpoch; epoch = epoch + 1) {
            emit EpochClaimed(msg.sender, stakeId, epoch);
        }

        if (reward < 0) {
            _stakes[stakeId].amount = _sumUintInt(stakeAmount, reward);
            _nodes[stakeNodeId].stakedAmount = _sumUintInt(_nodes[stakeNodeId].stakedAmount, reward);

            emit PenaltyApplied(msg.sender, stakeId, uint256(-reward));
        } else {
            _nodes[stakeNodeId].claimableAmount += (uint256(reward) * _s.nodeOwnerRewardPercent) / 100;

            emit TokensClaimed(msg.sender, stakeId, uint256(reward), latestClaimableEpoch);
        }

        return reward;
    }

    function _computePartialEpochReward(
        bytes32 nodeId,
        uint256 amount,
        uint256 epoch,
        uint256 stakedDays
    ) private returns (int256) {
        if (stakedDays == 0) {
            return 0;
        }

        Prb.SD59x18 interest = Prb.ZERO;
        Prb.SD59x18 penalty = Prb.ZERO;
        (interest, penalty) = _getAndCacheMeasurementRates(nodeId, epoch);

        Prb.SD59x18 sumInterest = interest.isZero() || penalty.isZero()
            ? Prb.add(interest, penalty)
            : Prb.sub(Prb.add(interest, penalty), Prb.convert(1));

        Prb.SD59x18 dailyInterest = _reverseCompoundInterest(sumInterest, _EPOCH_PERIOD_DAYS);
        Prb.SD59x18 totalInterest = _compoundInterest(dailyInterest, stakedDays);

        Prb.SD59x18 amount_ = Prb.convert(int256(amount));
        return
            interest.gte(penalty)
                ? Prb.convert(Prb.sub(Prb.mul(amount_, totalInterest), amount_))
                : -Prb.convert(Prb.sub(amount_, Prb.mul(amount_, totalInterest)));
    }

    /// @dev param is storage because it caches the result if it didn't have values
    /// @return interest in multiplier form >1.0
    /// @return penalty in multiplier form <1.0
    function _getAndCacheMeasurementRates(bytes32 nodeId, uint256 epoch) private returns (Prb.SD59x18, Prb.SD59x18) {
        Prb.SD59x18 interest = _nodes[nodeId].measurements[epoch].interest;
        Prb.SD59x18 penalty = _nodes[nodeId].measurements[epoch].penalty;

        if (!interest.isZero() || !penalty.isZero()) {
            return (interest, penalty);
        }

        uint24 rps = _nodes[nodeId].measurements[epoch].rps;
        uint16 penaltyDays = _nodes[nodeId].measurements[epoch].penaltyDays;
        NodeSlaLevel slaLevel = _nodes[nodeId].measurements[epoch].slaLevel;

        /// @dev Interest has not been calculated before for this measurement
        (interest, penalty) = _computeMeasurementInterest(rps, penaltyDays, slaLevel);
        _nodes[nodeId].measurements[epoch].interest = interest;
        _nodes[nodeId].measurements[epoch].penalty = penalty;

        return (interest, penalty);
    }

    function _canUnstake(
        uint32 startTimestamp,
        uint256 stakingDays,
        uint256 latestClaimableEpoch
    ) private view returns (bool) {
        uint256 unstakeEpoch = _getUnstakeEpoch(startTimestamp, stakingDays);

        return latestClaimableEpoch >= unstakeEpoch;
    }

    function _getEpoch(uint256 timestamp, bool isEdgeRoundedDown) private view returns (uint256) {
        uint256 contractStartTimestamp = _contractStartTimestamp;

        if (
            (!isEdgeRoundedDown && timestamp < contractStartTimestamp) ||
            (isEdgeRoundedDown && timestamp <= contractStartTimestamp)
        ) {
            return 0;
        }

        return
            (timestamp - contractStartTimestamp + _EPOCH_PERIOD_SECONDS - (isEdgeRoundedDown ? 1 : 0)) /
            _EPOCH_PERIOD_SECONDS;
    }

    /// @notice by default returns next epoch if edge timestamp provided
    function _getEpoch(uint256 timestamp) private view returns (uint256) {
        return _getEpoch(timestamp, false);
    }

    function _getUnstakeEpoch(uint32 startTimestamp, uint256 stakingDays) private view returns (uint256) {
        uint256 stakeEndTimestamp = startTimestamp + stakingDays * 1 days;
        return _getEpoch(stakeEndTimestamp, true);
    }

    function _getLatestClaimableEpoch(uint256 stakeId) private view returns (uint256) {
        uint256 lastClaimedEpoch = _stakes[stakeId].lastClaimedEpoch;

        /// @dev no unclaimed epochs
        uint256 lastFinishedEpoch = _getCurrentEpoch() - 1;
        if (lastClaimedEpoch >= lastFinishedEpoch) {
            return lastClaimedEpoch;
        }

        uint256 latestClaimableEpoch = lastClaimedEpoch;

        uint256 stakeFirstEpoch = _getEpoch(_stakes[stakeId].startTimestamp);
        uint256 epoch = lastClaimedEpoch + 1 > stakeFirstEpoch ? lastClaimedEpoch + 1 : stakeFirstEpoch;

        bytes32 nodeId = _stakes[stakeId].nodeId;
        /// @dev check if unclaimed epochs have measurements
        /// todo can still be improved for less iterations
        for (; epoch <= lastFinishedEpoch; epoch = epoch + 1) {
            if (_nodes[nodeId].measurements[epoch].rps == 0) {
                break;
            }
            latestClaimableEpoch = epoch;
        }

        return latestClaimableEpoch;
    }

    /// @return interest in multiplier form >1.xxxx
    /// @return penalty in multiplier form <0.9xxxx
    /// @dev caller function responsibility to verify if measurement is valid
    function _computeMeasurementInterest(
        uint24 rps,
        uint16 penaltyDays,
        NodeSlaLevel slaLevel
    ) private view returns (Prb.SD59x18, Prb.SD59x18) {
        if (penaltyDays == _EPOCH_PERIOD_DAYS) {
            //Only penalities for this epoch
            return (Prb.ZERO, _s.epochPenaltyRate);
        }

        uint256 slaMaxApy = _maxApy[slaLevel];
        require(slaMaxApy > 0, "Invalid APY for measurement");

        // APY = SLA_MAX_APY * APY_PARAMETER_ONE * log10( RPS * APY_PARAMETER_TWO )
        Prb.SD59x18 apy = Prb.mul(
            Prb.convert(int256(slaMaxApy)),
            Prb.mul(_s.apyParameterOne, Prb.log10(Prb.mul(Prb.convert(int256(uint256(rps))), _s.apyParameterTwo)))
        );

        Prb.SD59x18 dailyInterestRate = _getPeriodCompoundInterestRate(apy, _DAYS_IN_ONE_YEAR, false);

        if (penaltyDays == 0) {
            return (_compoundInterest(dailyInterestRate, _EPOCH_PERIOD_DAYS), Prb.ZERO);
        }

        // Need to take penalty days into account;
        Prb.SD59x18 gainInterest = _compoundInterest(dailyInterestRate, (_EPOCH_PERIOD_DAYS - uint256(penaltyDays)));
        Prb.SD59x18 lostInterest = _compoundInterest(_s.dailyPenaltyRate, uint256(penaltyDays));

        return (gainInterest, lostInterest);
    }

    function _getCurrentEpoch() private view returns (uint256) {
        return _getEpoch(block.timestamp);
    }

    function _getDaysUntilEpochEnd(
        uint256 timestamp,
        uint256 timestampEpoch,
        uint256 contractStartTimestamp
    ) private pure returns (uint256) {
        /// @dev epochEndTimestamp - timestamp / 1 days ;
        return (timestampEpoch * _EPOCH_PERIOD_SECONDS + contractStartTimestamp - timestamp) / 1 days;
    }

    function _calculateApyParameters(uint24 minRps, uint24 maxRps) private pure returns (Prb.SD59x18, Prb.SD59x18) {
        Prb.SD59x18 maxRps_ = Prb.convert(int256(uint256(maxRps)));

        Prb.SD59x18 paramOne = Prb.div(
            Prb.SD59x18.wrap(_APY_CURVE_RATIO),
            Prb.log10(Prb.div(maxRps_, Prb.convert(int256(uint256(minRps)))))
        );

        Prb.SD59x18 paramTwo = Prb.div(Prb.pow(Prb.convert(10), Prb.inv(paramOne)), maxRps_);

        return (paramOne, paramTwo);
    }

    function _calculateInterestPenaltyYield(
        Prb.SD59x18 amount,
        Prb.SD59x18 interest,
        Prb.SD59x18 penalty
    ) private pure returns (Prb.SD59x18) {
        interest = interest.gt(Prb.ZERO) ? interest : _ONE;
        penalty = penalty.gt(Prb.ZERO) ? penalty : _ONE;

        return Prb.mul(Prb.sub(Prb.add(interest, penalty), Prb.convert(2)), amount);
    }

    /// @notice Compound interest rate for period formula for positive rate ((1 + rate / 100) ^ (1 / periods)) - 1
    ///                                                       negative rate 1 - ((1 - rate / 100) ^ (1 / periods))
    /// @param rate effective rate is multipled by 10ˆ2
    function _getPeriodCompoundInterestRate(
        Prb.SD59x18 rate,
        uint256 periods,
        bool isNegative
    ) private pure returns (Prb.SD59x18) {
        Prb.SD59x18 percent = Prb.div(rate, Prb.convert(10 ** 4));
        Prb.SD59x18 power = Prb.div(_ONE, Prb.convert(int256(periods)));

        return Prb.pow(isNegative ? Prb.sub(_ONE, percent) : Prb.add(_ONE, percent), power);
    }

    function _getNextDayStartTimestamp(uint32 timestamp, uint32 contractStartTimestamp) private pure returns (uint32) {
        /// @dev timestamp + secondsTillNextDayStart
        return timestamp + ((1 days - ((timestamp - contractStartTimestamp) % 1 days)) % 1 days);
    }

    /// @notice Rate compound formula
    function _compoundInterest(Prb.SD59x18 rate, uint256 periods) private pure returns (Prb.SD59x18) {
        return Prb.pow(rate, Prb.convert(int256(periods)));
    }

    function _reverseCompoundInterest(Prb.SD59x18 rate, uint256 periods) private pure returns (Prb.SD59x18) {
        return Prb.pow(rate, Prb.div(_ONE, Prb.convert(int256(periods))));
    }

    function _sumUintInt(uint256 a, int256 b) private pure returns (uint256) {
        return b >= 0 ? a + uint256(b) : a - uint256(-b);
    }

    // Copied from openZeppelin SafeCast
    function _toUint32(uint256 value) private pure returns (uint32) {
        require(value <= type(uint32).max, "SafeCast: value doesn't fit in 32 bits");
        return uint32(value);
    }
}
