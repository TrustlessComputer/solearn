// SPDX-License-Identifier: MIT

import {IAI721} from "./IAI721.sol";
import {ERC721URIStorage, ERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {TransferHelper} from "../lib/TransferHelper.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";

pragma solidity ^0.8.20;

interface IWorkerHub {
    function getMinFeeToUse(
        address _modelAddress
    ) external view returns (uint256);
}

interface IInferable {
    function infer(
        uint256 modelId,
        bytes calldata data,
        address creator
    ) external payable returns (uint256 inferenceId);

    function infer(
        uint256 modelId,
        bytes calldata data,
        address creator,
        bool flag
    ) external payable returns (uint256 inferenceId);
}

interface ISquad {
    function moveAgentToSquad(
        address _caller,
        uint256 _agentId,
        uint256 _toSquadId
    ) external;
}

contract AI721 is ERC721Enumerable, ERC721URIStorage, IAI721 {
    uint256 private constant PORTION_DENOMINATOR = 10000;

    mapping(uint256 nftId => TokenMetaData) private _datas;
    uint256 private _nextTokenId;
    uint256 private _mintPrice;
    address private _royaltyReceiver;
    uint16 private _royaltyPortion;

    address public _workerHub;
    address public _hybridModel;

    mapping(uint256 nftId => uint256) public _poolBalance;
    mapping(address nftId => mapping(bytes32 signature => bool))
        public _signaturesUsed;

    mapping(uint256 nftId => bytes[]) private _missionsOf;
    address private _squadManager;

    modifier onlyAgentOwner(uint256 nftId) {
        _checkAgentOwner(msg.sender, nftId);
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 mintPrice_,
        address royaltyReceiver_,
        uint16 royaltyPortion_,
        uint256 nextTokenId_,
        address hybridModel_,
        address workerHub_
    ) ERC721(name_, symbol_) {
        _mintPrice = mintPrice_;
        _royaltyReceiver = royaltyReceiver_;
        _royaltyPortion = royaltyPortion_;
        _nextTokenId = nextTokenId_;
        _hybridModel = hybridModel_;
        _workerHub = workerHub_;
    }

    function _mint(
        address to,
        string calldata uri,
        bytes calldata data,
        uint fee,
        uint256 agentId,
        string calldata promptKey
    ) internal virtual returns (uint256) {
        if (data.length == 0) revert InvalidAgentData();

        _safeMint(to, agentId);
        _setTokenURI(agentId, uri);

        _datas[agentId].fee = uint128(fee);
        _datas[agentId].sysPrompts[promptKey].push(data);
        _datas[agentId].isUsed = true;

        emit NewToken(agentId, uri, data, fee, to);

        return agentId;
    }

    function _wrapMint(
        address to,
        string calldata uri,
        bytes calldata data,
        uint fee,
        uint256 squadId,
        string calldata promptKey
    ) internal virtual returns (uint256) {
        if (msg.value < _mintPrice) revert InvalidMintingFee();

        while (_datas[_nextTokenId].isUsed) {
            _nextTokenId++;
        }
        uint256 agentId = _nextTokenId++;

        _mint(to, uri, data, fee, agentId, promptKey);

        if (squadId != 0) {
            _validateAgentBeforeMoveToSquad(to, agentId);

            ISquad(_squadManager).moveAgentToSquad(
                msg.sender,
                agentId,
                squadId
            );
        }

        return agentId;
    }

    function _validateURI(string calldata uri) internal virtual pure {
        if (bytes(uri).length == 0) revert InvalidAgentData();
    }

    function updateAgentURI(
        uint256 agentId,
        string calldata uri
    ) public virtual override onlyAgentOwner(agentId) {
        _validateURI(uri);

        _setTokenURI(agentId, uri);
        emit AgentURIUpdate(agentId, uri);
    }

    function updateAgentData(
        uint256 agentId,
        bytes calldata sysPrompt,
        string calldata promptKey,
        uint256 promptIdx
    ) public virtual override onlyAgentOwner(agentId) {
        _validateAgentData(agentId, sysPrompt, promptIdx, promptKey);

        emit AgentDataUpdate(
            agentId,
            promptIdx,
            _datas[agentId].sysPrompts[promptKey][promptIdx],
            sysPrompt
        );

        _datas[agentId].sysPrompts[promptKey][promptIdx] = sysPrompt;
    }

    function _checkUpdatePromptPermission(
        uint256 agentId,
        bytes calldata sysPrompt,
        uint256 promptIdx,
        uint256 randomNonce,
        bytes calldata signature
    ) internal virtual {
        address agentOwner = _ownerOf(agentId);
        (address signer, bytes32 signHash) = _recover(
            keccak256(
                abi.encode(
                    sysPrompt,
                    agentId,
                    promptIdx,
                    randomNonce,
                    address(this),
                    block.chainid
                )
            ),
            signature
        );
        if (_signaturesUsed[agentOwner][signHash]) revert SignatureUsed();
        _signaturesUsed[agentOwner][signHash] = true;

        _checkAgentOwner(signer, agentId);
    }

    function _validateAgentData(
        uint256 agentId,
        bytes calldata sysPrompt,
        uint256 promptIdx,
        string calldata promptKey
    ) internal virtual view {
        if (sysPrompt.length == 0) revert InvalidAgentData();
        uint256 len = _datas[agentId].sysPrompts[promptKey].length;
        if (promptIdx >= len) revert InvalidAgentPromptIndex();
    }

    function updateAgentDataWithSignature(
        uint256 agentId,
        bytes calldata sysPrompt,
        uint256 promptIdx,
        string calldata promptKey,
        uint256 randomNonce,
        bytes calldata signature
    ) public virtual override {
        _validateAgentData(agentId, sysPrompt, promptIdx, promptKey);
        _checkUpdatePromptPermission(
            agentId,
            sysPrompt,
            promptIdx,
            randomNonce,
            signature
        );

        emit AgentDataUpdate(
            agentId,
            promptIdx,
            _datas[agentId].sysPrompts[promptKey][promptIdx],
            sysPrompt
        );

        _datas[agentId].sysPrompts[promptKey][promptIdx] = sysPrompt;
    }

    function _checkUpdateUriPermission(
        uint256 agentId,
        string calldata uri,
        uint256 randomNonce,
        bytes calldata signature
    ) internal virtual {
        address agentOwner = _ownerOf(agentId);
        (address signer, bytes32 signHash) = _recover(
            keccak256(
                abi.encode(
                        agentId, 
                        uri, 
                        randomNonce,
                        address(this),
                        block.chainid
                    )
                ), 
            signature);
        if (_signaturesUsed[agentOwner][signHash]) revert SignatureUsed();
        _signaturesUsed[agentOwner][signHash] = true;
        _checkAgentOwner(signer, agentId);
    }

    function updateAgentUriWithSignature(
        uint256 agentId,
        string calldata uri,
        uint256 randomNonce,
        bytes calldata signature
    ) public virtual override {
        _validateURI(uri);

        _checkUpdateUriPermission(agentId, uri, randomNonce, signature);
        _setTokenURI(agentId, uri);
        emit AgentURIUpdate(agentId, uri);
    }

    function addNewAgentData(
        uint256 agentId,
        string calldata promptKey,
        bytes calldata sysPrompt
    ) public virtual override onlyAgentOwner(agentId) {
        if (sysPrompt.length == 0) revert InvalidAgentData();

        _datas[agentId].sysPrompts[promptKey].push(sysPrompt);

        emit AgentDataAddNew(agentId, _datas[agentId].sysPrompts[promptKey]);
    }

    function updateAgentFee(
        uint256 agentId,
        uint fee
    ) public virtual override onlyAgentOwner(agentId) {
        if (_datas[agentId].fee != fee) {
            _datas[agentId].fee = uint128(fee);
        }

        emit AgentFeeUpdate(agentId, fee);
    }

    function _setHybridModel(address hybridModel) internal virtual {
        hybridModel = hybridModel;
    }

    function _setWorkerHub(address workerHub) internal virtual {
        _workerHub = workerHub;
    }

    function topUpPoolBalance(uint256 agentId) public virtual override payable {
        _poolBalance[agentId] += msg.value;

        emit TopUpPoolBalance(agentId, msg.sender, msg.value);
    }

    function getAgentFee(uint256 agentId) public virtual view returns (uint256) {
        return _datas[agentId].fee;
    }

    function getAgentSystemPrompt(
        uint256 agentId,
        string calldata promptKey
    ) public virtual view returns (bytes[] memory) {
        return _datas[agentId].sysPrompts[promptKey];
    }

    function infer(
        uint256 agentId,
        bytes calldata fwdCalldata,
        string calldata externalData,
        string calldata promptKey,
        uint256 modelId,
        bool flag
    ) public virtual override payable {
        (uint256 estFeeWH, bytes memory fwdData) = _infer(agentId, fwdCalldata, promptKey);

        uint256 inferId = IInferable(_hybridModel).infer{value: estFeeWH}(
            modelId,
            fwdData,
            msg.sender,
            flag
        );

        emit InferencePerformed(
            agentId,
            msg.sender,
            fwdData,
            _datas[agentId].fee,
            externalData,
            inferId
        );
    }

    function infer(
        uint256 agentId,
        bytes calldata fwdCalldata,
        string calldata externalData,
        string calldata promptKey,
        uint256 modelId
    ) public virtual override payable {
        (uint256 estFeeWH, bytes memory fwdData) = _infer(agentId, fwdCalldata, promptKey);

        uint256 inferId = IInferable(_hybridModel).infer{value: estFeeWH}(
            modelId,
            fwdData,
            msg.sender
        );

        emit InferencePerformed(
            agentId,
            msg.sender,
            fwdData,
            _datas[agentId].fee,
            externalData,
            inferId
        );
    }

    function _infer(
        uint256 agentId,
        bytes calldata fwdCalldata,
        string calldata promptKey
    ) internal virtual returns (uint256, bytes memory) {
        if (_datas[agentId].sysPrompts[promptKey].length == 0) revert InvalidAgentData();
        if (msg.value < _datas[agentId].fee) revert InvalidAgentFee();

        bytes memory fwdData = abi.encodePacked(
            _concatSystemPrompts(_datas[agentId].sysPrompts[promptKey]),
            fwdCalldata
        );
        uint256 estFeeWH = IWorkerHub(_workerHub).getMinFeeToUse(_hybridModel);

        if (msg.value < estFeeWH && _poolBalance[agentId] >= estFeeWH) {
            unchecked {
                _poolBalance[agentId] -= estFeeWH;
            }

            if (msg.value > 0) {
                TransferHelper.safeTransferNative(
                    _ownerOf(agentId),
                    msg.value
                );
            }
        } else if (msg.value >= estFeeWH) {
            uint256 remain = msg.value - estFeeWH;
            if (remain > 0) {
                TransferHelper.safeTransferNative(_ownerOf(agentId), remain);
            }
        } else {
            revert InsufficientFunds();
        }

        return (estFeeWH, fwdData);
    }

    function dataOf(
        uint256 agentId
    ) public virtual view returns (uint128, bool) {
        return (_datas[agentId].fee, _datas[agentId].isUsed);
    }

    function royaltyInfo(
        uint256 agentId,
        uint256 salePrice
    ) public virtual view returns (address, uint256) {
        agentId;
        return (
            _royaltyReceiver,
            (salePrice * _royaltyPortion) / PORTION_DENOMINATOR
        );
    }

    function tokenURI(
        uint256 agentId
    )
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(agentId);
    }


    function _checkAgentOwner(address user, uint256 agentId) internal virtual view {
        if (user != _ownerOf(agentId)) revert Unauthorized();
    }

    function _validateAgentBeforeMoveToSquad(
        address user,
        uint256 agentId
    ) internal virtual view {
        _checkAgentOwner(user, agentId);
        if (agentId >= _nextTokenId) revert InvalidAgentId();
    }

    function getAgentIdByOwner(
        address owner
    ) external view returns (uint256[] memory) {
        uint256 len = balanceOf(owner);
        uint256[] memory agentIds = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            agentIds[i] = tokenOfOwnerByIndex(owner, i);
        }

        return agentIds;
    }

    function createMission(
        uint256 agentId,
        bytes calldata missionData
    ) public virtual override onlyAgentOwner(agentId) {
        if (missionData.length == 0 || agentId >= _nextTokenId)
            revert InvalidAgentData();
        _missionsOf[agentId].push(missionData);

        emit AgentMissionAddNew(agentId, _missionsOf[agentId]);
    }

    function getMissionIdsByAgentId(
        uint256 agentId
    ) public virtual override view returns (bytes[] memory) {
        return _missionsOf[agentId];
    }

    function nextTokenId() external view returns (uint256) {
        return _nextTokenId;
    }

    function royaltyReceiver() external view returns (address) {
        return _royaltyReceiver;
    }

    function royaltyPortion() external view returns (uint16) {
        return _royaltyPortion;
    }

    function _concatSystemPrompts(
        bytes[] memory sysPrompts
    ) internal virtual pure returns (bytes memory) {
        uint256 len = sysPrompts.length;
        bytes memory concatedPrompt;

        for (uint256 i = 0; i < len; i++) {
            concatedPrompt = abi.encodePacked(
                concatedPrompt,
                sysPrompts[i],
                ";"
            );
        }

        return concatedPrompt;
    }

    function _recover(
        bytes32 structHash,
        bytes calldata signature
    ) internal pure returns (address, bytes32) {
        bytes32 hash = ECDSA.toEthSignedMessageHash(structHash);
        return (ECDSA.recover(hash, signature), hash);
    }

    function _beforeTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize) internal override(ERC721, ERC721Enumerable) virtual {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }

    function _burn(
        uint256 agentId
    ) internal override(ERC721, ERC721URIStorage) {
        super._burn(agentId);
    }

    //todo: add suport interface
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(
            ERC721Enumerable,
            ERC721URIStorage
        )
        returns (bool)
    {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}