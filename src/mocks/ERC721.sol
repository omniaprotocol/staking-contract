// solhint-disable ordering
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

// Only used as mock for staking tests
contract NFTCollectionMock is ERC721Enumerable {
    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {}

    function safeMint(address to, uint256 tokenId) external {
        _safeMint(to, tokenId);
    }
}
