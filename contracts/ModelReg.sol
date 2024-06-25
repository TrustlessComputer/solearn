// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { IModelReg } from "./interfaces/IModelReg.sol";
import { IModel } from "./interfaces/IModel.sol";

error InsufficientMintPrice();

contract ModelRegStorage is IModelReg {
    uint256 public mintPrice;
    uint256 public evalPrice;
    uint8 protocolFeePercent; // deprecated
    mapping(uint256 => address) public modelAddr;
    address public royaltyReceiver;
    uint256 public nextModelId;

    uint256[50] private __gap;
}

contract ModelReg is
ModelRegStorage,
Initializable,
ERC721Upgradeable,
ERC721EnumerableUpgradeable,
ERC721URIStorageUpgradeable,
IERC2981Upgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    receive() external payable {}

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

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Upgradeable, ERC721EnumerableUpgradeable, IERC165Upgradeable, ERC721URIStorageUpgradeable) returns (bool) {
        return
        interfaceId == type(IERC2981Upgradeable).interfaceId ||
        super.supportsInterface(interfaceId);
    }

    function initialize(uint256 _mintPrice, uint256 _evalPrice, address _royaltyReceiver) public initializer {
        __ERC721_init("Models", "MDL");
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();

        mintPrice = _mintPrice;
        evalPrice = _evalPrice;
        royaltyReceiver = _royaltyReceiver;
        nextModelId = 1;
    }

    function afterUpgrade(uint256 _mintPrice, uint256 _evalPrice, address _royaltyReceiver, uint256 _nextModelId) public {
        mintPrice = _mintPrice;
        evalPrice = _evalPrice;
        royaltyReceiver = _royaltyReceiver;
        nextModelId = _nextModelId;
    }


    function safeMint(
        address to,
        string memory uri,
        address _modelAddr
    ) external payable {
        if (msg.value < mintPrice) revert InsufficientMintPrice();
        while (modelAddr[nextModelId] != address(0)) {
            nextModelId++;
        }
        uint256 modelId = nextModelId;
        _safeMint(to, modelId);
        _setTokenURI(modelId, uri);
        modelAddr[modelId] = _modelAddr;
        nextModelId++;
        IModel(_modelAddr).setModelId(modelId);
    }

    /* @dev EIP2981 royalties implementation.
    // EIP2981 standard royalties return.
    */
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view virtual override
    returns (address receiver, uint256 royaltyAmount) {
        receiver = royaltyReceiver;
        royaltyAmount = mintPrice * 200 / 10000; // 2% of the mint price
    }
}
