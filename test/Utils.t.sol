// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

contract Utils {
    /// @dev using uniquify function multiple times in one test can provide inaccurate results
    mapping(bytes32 => bool) private _isUnique;
    mapping(uint256 => bytes32) private _unique;

    /**
     * @dev Removes all but the first occurrence of each element from a list of
     *      integers, preserving the order of original elements, and returns the list.
     *
     * The input list may be of almost any length.
     *
     * @param input The list of bytes32 to be made unique.
     * @return ret input list, with any duplicate elements removed.
     */

    function uniquify(bytes32[] memory input) public returns (bytes32[] memory) {
        uint256 uniqueCount = 0;

        if (input.length == 0 || input.length == 1) {
            return input;
        }

        for (uint256 i = 0; i < input.length; i++) {
            if (_isUnique[input[i]] == false) {
                _isUnique[input[i]] = true;
                _unique[uniqueCount] = input[i];
                uniqueCount++;
            }
        }

        bytes32[] memory _uniqueInput = new bytes32[](uniqueCount);

        for (uint256 i = 0; i < uniqueCount; i++) {
            _uniqueInput[i] = _unique[i];
        }

        return _uniqueInput;
    }
}
