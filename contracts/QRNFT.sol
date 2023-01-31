//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/*  ______     _______   _____  ___    _______  ___________  
   /    " \   /"      \ (\"   \|"  \  /"     "|("     _   ") 
  // ____  \ |:        ||.\\   \    |(: ______) )__/  \\__/  
 /  /    )  )|_____/   )|: \.   \\  | \/    |      \\_ /     
(: (____/ //  //      / |.  \    \. | // ___)      |.  |     
 \         \ |:  __   \ |    \    \ |(:  (         \:  |     
  \"____/\__\|__|  \___) \___|\____\) \__/          \__|     

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
import "@opengsn/contracts/src/ERC2771Recipient.sol";

import "hardhat/console.sol";

contract QRNFT is
    IERC721Receiver,
    IERC1155Receiver,
    Pausable,
    ERC165,
    AccessControl,
    ERC2771Recipient
{
    using Strings for uint256;
    using SignatureChecker for address;

    uint256 public count;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PARTNER_ROLE = keccak256("PARTNER_ROLE");
    address public signer;
    string public name = "QRNFT";
    string public symbol = "QRNFT";

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
        uint256 indexed claimId,
        uint256 indexed tokenId,
        address operator,
        address indexed nftContract,
        uint256 amount
    );

    event Claimed(
        uint256 indexed claimId,
        uint256 indexed tokenId,
        address indexed owner,
        address nftContract,
        uint256
    );

    event ClaimRefunded(
        uint256 indexed claimId,
        uint256 indexed tokenId,
        address indexed owner,
        address nftContract,
        uint256 amount
    );

    mapping(uint256 => Drop) public drops;

    constructor(
        address _owner,
        address _signer,
        address _trustedForwarder
    ) {
        _setTrustedForwarder(_trustedForwarder);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PARTNER_ROLE, msg.sender);
        signer = _signer;
    }

    /**
     * @dev Set the trusted forwarder for a contract.
     * @param forwarder The address of the TrustedForwarder contract.
     */
    function setTrustedForwarder(address forwarder)
        public
        onlyRole(ADMIN_ROLE)
    {
        _setTrustedForwarder(forwarder);
    }

    /**
     * @dev Set the signer for a contract.
     * @param _signer The address of the signer.
     */
    function setSigner(address _signer) public onlyRole(DEFAULT_ADMIN_ROLE) {
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
        emit ClaimCreated(count++, _tokenId, _from, msg.sender, 1);

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

        for (uint256 i = 0; i < _amount; i++) {
            drops[count] = Drop(
                msg.sender,
                _tokenId,
                1,
                address(0),
                _from,
                false,
                "ERC1155"
            );
            emit ClaimCreated(count++, _tokenId, _from, msg.sender, 1);
        }

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

            emit ClaimCreated(count++, _tokenIds[i], _from, msg.sender, 1);
        }
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
            for (uint256 j = 0; j < _amounts[i]; j++) {
                drops[count] = Drop(
                    msg.sender,
                    _tokenIds[i],
                    _amounts[i],
                    address(0),
                    _from,
                    false,
                    "ERC1155"
                );

                emit ClaimCreated(count++, _tokenIds[i], _from, msg.sender, 1);
            }
        }
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

        drops[_dropId].owner = _msgSender();
        drops[_dropId].claimed = true;

        if (
            keccak256(abi.encodePacked(drops[_dropId].contractType)) ==
            keccak256("ERC721")
        ) {
            IERC721(drops[_dropId].tokenAddress).safeTransferFrom(
                address(this),
                _msgSender(),
                drops[_dropId].tokenId
            );
        } else {
            IERC1155(drops[_dropId].tokenAddress).safeTransferFrom(
                address(this),
                _msgSender(),
                drops[_dropId].tokenId,
                drops[_dropId].amount,
                _msgData()
            );
        }

        emit Claimed(
            _dropId,
            drops[_dropId].tokenId,
            _msgSender(),
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
                    i,
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
                    i,
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

    // override _msgsende()
    function _msgSender()
        internal
        view
        virtual
        override(Context, ERC2771Recipient)
        returns (address)
    {
        return ERC2771Recipient._msgSender();
    }

    // override _msgdata()
    function _msgData()
        internal
        view
        virtual
        override(Context, ERC2771Recipient)
        returns (bytes calldata)
    {
        return ERC2771Recipient._msgData();
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

    function versionRecipient() external pure returns (string memory) {
        return "1";
    }
}

/**
 ██▄▄▄██   █▄▀ █░█ █▀▄▀█ ▄▀█
█   ░   █  █░█ █▄█ █░▀░█ █▀█
█   ░   █
█░█░▀░█░█  ▀█▀ █▀█ █▀█ █▄░█   █▀▀ ▀█▀ █░█
 ▀▀▀▀▀▀▀   ░█░ █▀▄ █▄█ █░▀█ ▄ ██▄ ░█░ █▀█
 */
