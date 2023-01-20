//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

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

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "hardhat/console.sol";

contract QRNFT is
    IERC721Receiver,
    IERC1155Receiver,
    Pausable,
    ERC165,
    AccessControl
{
    using Strings for uint256;
    using SignatureChecker for address;

    uint256 public count;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PARTNER_ROLE = keccak256("PARTNER_ROLE");
    address public signer;

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
        uint256 amount
    );

    event ClaimRefunded(
        uint256 indexed tokenId,
        address indexed owner,
        address indexed nftContract,
        uint256 amount
    );

    mapping(uint256 => Drop) public drops;

    constructor(address _signer) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PARTNER_ROLE, msg.sender);
        signer = _signer;
    }

    function onERC721Received(
        address,
        address _from,
        uint256 _tokenId,
        bytes calldata
    ) external returns (bytes4) {
        require(hasRole(PARTNER_ROLE, _from), "QRNFT: Not a partner.");
        drops[count] = Drop(
            msg.sender,
            _tokenId,
            1,
            address(0),
            _from,
            false,
            "ERC721"
        );
        emit ClaimCreated(_tokenId, _from, msg.sender, 1);
        count++;
        return this.onERC721Received.selector;
    }

    function onERC1155Received(
        address,
        address _from,
        uint256 _tokenId,
        uint256 _amount,
        bytes calldata
    ) external returns (bytes4) {
        require(hasRole(PARTNER_ROLE, _from), "QRNFT: Not a partner.");
        drops[count] = Drop(
            msg.sender,
            _tokenId,
            _amount,
            address(0),
            _from,
            false,
            "ERC1155"
        );
        emit ClaimCreated(_tokenId, _from, msg.sender, _amount);
        count++;
        return this.onERC1155Received.selector;
    }

    function onERC721BatchReceived(
        address,
        address _from,
        uint256[] calldata _tokenIds,
        bytes calldata
    ) external returns (bytes4) {
        require(hasRole(PARTNER_ROLE, _from), "QRNFT: Not a partner.");
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            drops[count] = Drop(
                msg.sender,
                _tokenIds[i],
                1,
                address(0),
                _from,
                false,
                "ERC721"
            );
            count++;
        }
        emit ClaimCreated(_tokenIds[0], _from, msg.sender, 1);
        return this.onERC721BatchReceived.selector;
    }

    function onERC1155BatchReceived(
        address,
        address _from,
        uint256[] calldata _tokenIds,
        uint256[] calldata _amounts,
        bytes calldata
    ) external returns (bytes4) {
        require(hasRole(PARTNER_ROLE, _from), "QRNFT: Not a partner.");
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            drops[count] = Drop(
                msg.sender,
                _tokenIds[i],
                _amounts[i],
                address(0),
                _from,
                false,
                "ERC1155"
            );
            count++;
        }
        emit ClaimCreated(_tokenIds[0], _from, msg.sender, _amounts[0]);
        return this.onERC1155BatchReceived.selector;
    }

    /**
     *@dev Get information about a specific drop.
     *@param _dropId The token id of the drop
     *@return Drop information
     */
    function getDrop(uint256 _dropId) external view returns (Drop memory) {
        return drops[_dropId];
    }

    /**
     * @dev Claim a drop
     * @param _dropId The token id of the drop
     */
    function claim(
        uint256 _dropId,
        bytes32 _hash,
        bytes memory _signature
    ) external whenNotPaused {
        require(
            drops[_dropId].operator != address(0),
            "QRNFT: Drop does not exist"
        );
        require(drops[_dropId].owner == address(0), "QRNFT: Already claimed");
        require(drops[_dropId].claimed == false, "QRNFT: Already claimed");

        bytes32 messageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", _hash)
        );

        require(
            signer.isValidSignatureNow(messageHash, _signature),
            "Invalid signature"
        );

        drops[_dropId].owner = msg.sender;
        drops[_dropId].claimed = true;

        if (
            keccak256(abi.encodePacked(drops[_dropId].contractType)) ==
            keccak256("ERC721")
        ) {
            IERC721(drops[_dropId].tokenAddress).safeTransferFrom(
                address(this),
                msg.sender,
                drops[_dropId].tokenId
            );
        } else {
            IERC1155(drops[_dropId].tokenAddress).safeTransferFrom(
                address(this),
                msg.sender,
                drops[_dropId].tokenId,
                drops[_dropId].amount,
                ""
            );
        }

        emit Claimed(
            drops[_dropId].tokenId,
            msg.sender,
            drops[_dropId].tokenAddress,
            drops[_dropId].amount
        );
    }

    /**
     * @dev Refund a drop
     */
    function returnMyNfts() external {
        for (uint256 i = 0; i < count; i++) {
            if (drops[i].operator == msg.sender && drops[i].claimed == false) {
                if (
                    keccak256(abi.encodePacked(drops[i].contractType)) ==
                    keccak256("ERC721")
                ) {
                    IERC721(drops[i].tokenAddress).safeTransferFrom(
                        address(this),
                        msg.sender,
                        drops[i].tokenId
                    );
                } else {
                    IERC1155(drops[i].tokenAddress).safeTransferFrom(
                        address(this),
                        msg.sender,
                        drops[i].tokenId,
                        drops[i].amount,
                        ""
                    );
                }
                emit ClaimRefunded(
                    drops[i].tokenId,
                    msg.sender,
                    drops[i].tokenAddress,
                    drops[i].amount
                );
            }
        }
    }

    /**
     * @dev Return all of the drops for a given owner
     */
    function returnAllNfts() external onlyRole(PARTNER_ROLE) {
        for (uint256 i = 0; i < count; i++) {
            if (drops[i].claimed == false) {
                if (
                    keccak256(abi.encodePacked(drops[i].contractType)) ==
                    keccak256("ERC721")
                ) {
                    IERC721(drops[i].tokenAddress).safeTransferFrom(
                        address(this),
                        drops[i].operator,
                        drops[i].tokenId
                    );
                } else {
                    IERC1155(drops[i].tokenAddress).safeTransferFrom(
                        address(this),
                        drops[i].operator,
                        drops[i].tokenId,
                        drops[i].amount,
                        ""
                    );
                }
                emit ClaimRefunded(
                    drops[i].tokenId,
                    drops[1].operator,
                    drops[i].tokenAddress,
                    drops[1].amount
                );
            }
        }
    }

    /**
     * @dev Pause the contract
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev Set the admin role
     */
    function setAdmin(address[] memory _admin)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        for (uint256 i = 0; i < _admin.length; i++) {
            grantRole(ADMIN_ROLE, _admin[i]);
        }
    }

    /**
     * @dev Revoke an admin role
     */
    function revokeAdmin(address[] memory _admin)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        for (uint256 i = 0; i < _admin.length; i++) {
            revokeRole(ADMIN_ROLE, _admin[i]);
        }
    }

    /**
     * @dev Set the partner role
     */
    function setPartner(address[] memory _partner)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        for (uint256 i = 0; i < _partner.length; i++) {
            grantRole(PARTNER_ROLE, _partner[i]);
        }
    }

    /**
     * @dev Revoke a partner role
     */
    function revokePartner(address[] memory _partner)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        for (uint256 i = 0; i < _partner.length; i++) {
            revokeRole(PARTNER_ROLE, _partner[i]);
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165, IERC165, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
