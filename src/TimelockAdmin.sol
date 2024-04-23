// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "openzeppelin-contracts/contracts/governance/TimelockController.sol";
import "openzeppelin-contracts/contracts/utils/Address.sol";

contract TimelockAdmin is TimelockController {
    using Address for address;

    uint256 public constant TWO_DAYS_IN_SECONDS = 2 days;

    /// @dev Enforce min 48 hours delays of proposals. Pass zero address as admin to keep default self administration.
    constructor(
        address[] memory gnosisSafe
    ) TimelockController(TWO_DAYS_IN_SECONDS, gnosisSafe, gnosisSafe, address(0)) {
        /// @dev Ensure there was exactly 1 address in array
        require(gnosisSafe.length == 1, "Invalid array length");

        /// @dev Ensure the proposer/executor/canceller is a contract
        require(gnosisSafe[0].isContract(), "Proposer/Executor/Canceller must be a live contract");
    }
}
