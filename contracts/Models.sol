// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

error InsufficientMintPrice();

contract Models is Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable {
    uint256 public mintPrice;
    uint256 public evalPrice;
    uint8 protocolFeePercent;
    mapping(uint256 => address) public modelAddr;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(
        uint256 tokenId
    ) internal override(ERC721Upgradeable, ERC721URIStorageUpgradeable) {
        super._burn(tokenId);
    }

    function tokenURI(
        uint256 tokenId
    )
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721URIStorageUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function initialize() public initializer {
        __ERC721_init("Models", "MDL");
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();
        mintPrice = 0 ether;
        evalPrice = 0 ether;
        protocolFeePercent = 50;
        // mintPrice = 0.01 ether;
        // evalPrice = 0.0001 ether;
        // protocolFeePercent = 50;
    }

    function safeMint(
        address to,
        uint256 modelId,
        string memory uri,
        address _modelAddr
    ) external payable {
        if (msg.value < mintPrice) revert InsufficientMintPrice();

        _safeMint(to, modelId);
        _setTokenURI(modelId, uri);
        modelAddr[modelId] = _modelAddr;
    }
}
