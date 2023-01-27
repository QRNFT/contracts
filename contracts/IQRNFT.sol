/*  ______     _______   _____  ___    _______  ___________  
   /    " \   /"      \ (\"   \|"  \  /"     "|("     _   ") 
  // ____  \ |:        ||.\\   \    |(: ______) )__/  \\__/  
 /  /    )  )|_____/   )|: \.   \\  | \/    |      \\_ /     
(: (____/ //  //      / |.  \    \. | // ___)      |.  |     
 \         \ |:  __   \ |    \    \ |(:  (         \:  |     
  \"____/\__\|__|  \___) \___|\____\) \__/          \__|     


 ██▄▄▄██   █▄▀ █░█ █▀▄▀█ ▄▀█
█   ░   █  █░█ █▄█ █░▀░█ █▀█
█   ░   █
█░█░▀░█░█  ▀█▀ █▀█ █▀█ █▄░█   █▀▀ ▀█▀ █░█
 ▀▀▀▀▀▀▀   ░█░ █▀▄ █▄█ █░▀█ ▄ ██▄ ░█░ █▀█
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IQRNFT {
    struct Drop {
        address tokenAddress;
        uint256 tokenId;
        uint256 amount;
        address owner;
        address operator;
        bool claimed;
        string contractType;
    }

    event ClaimCreated(
        uint256 indexed tokenId,
        address operator,
        address indexed nftContract,
        uint256 amount
    );

    event Claimed(
        uint256 indexed tokenId,
        address indexed owner,
        address indexed nftContract,
        uint256
    );

    event ClaimRefunded(
        uint256 indexed tokenId,
        address indexed owner,
        address indexed nftContract,
        uint256 amount
    );

    function getDrop(uint256 _dropId) external view returns (Drop memory);

    function claim(
        uint256 _dropId,
        bytes32 _hash,
        bytes memory _signature
    ) external;

    function returnMyNfts() external;

    function returnAllNfts() external;

    function pause() external;

    function unpause() external;

    function setAdmin(address[] memory _admin) external;

    function revokeAdmin(address[] memory _admin) external;

    function setPartner(address[] memory _partner) external;

    function revokePartner(address[] memory _partner) external;
}
