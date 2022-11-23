//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ERC721MOCK is ERC721 {
    constructor() ERC721("ERC721MOCK", "ERC721MOCK") {}

    function mint(address to, uint256 tokenId) public {
        _safeMint(to, tokenId);
    }
}
