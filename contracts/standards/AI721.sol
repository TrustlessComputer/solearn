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

interface IHybridModel {
    function infer(
        bytes calldata _data,
        address creator,
        bool flag
    ) external payable returns (uint256 referenceId);

    function infer(
        bytes calldata _data,
        address creator
    ) external payable returns (uint256 referenceId);
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
    mapping(address nftOwner => mapping(bytes32 signature => bool))
        public _signaturesUsed;

    mapping(uint256 agentId => bytes[]) private _missionsOf;
    address private _squadManager;

    modifier onlyAgentOwner(uint256 _agentId) {
        _checkAgentOwner(msg.sender, _agentId);
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
       // todo: fill here
    }

    function _mint(
        address to,
        string calldata uri,
        bytes calldata data,
        uint fee,
        uint256 agentId
    ) internal virtual returns (uint256) {
        if (data.length == 0) revert InvalidAgentData();

        _safeMint(to, agentId);
        _setTokenURI(agentId, uri);

        _datas[agentId].fee = fee;
        _datas[agentId].sysPrompts.push(data);

        emit NewToken(agentId, uri, data, fee, to);

        return agentId;
    }

    function _wrapMint(
        address to,
        string calldata uri,
        bytes calldata data,
        uint fee,
        uint256 squadId
    ) internal virtual returns (uint256) {
        if (msg.value < _mintPrice) revert InvalidMintingFee();

        while (_datas[_nextTokenId].sysPrompts.length != 0) {
            _nextTokenId++;
        }
        uint256 agentId = _nextTokenId++;

        _mint(to, uri, data, fee, agentId);

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
        uint256 promptIdx
    ) public virtual override onlyAgentOwner(agentId) {
        _validateAgentData(agentId, sysPrompt, promptIdx);

        emit AgentDataUpdate(
            agentId,
            promptIdx,
            _datas[agentId].sysPrompts[promptIdx],
            sysPrompt
        );

        _datas[agentId].sysPrompts[promptIdx] = sysPrompt;
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
        uint256 promptIdx
    ) internal virtual view {
        if (sysPrompt.length == 0) revert InvalidAgentData();
        uint256 len = _datas[agentId].sysPrompts.length;
        if (promptIdx >= len) revert InvalidAgentPromptIndex();
    }

    function updateAgentDataWithSignature(
        uint256 agentId,
        bytes calldata sysPrompt,
        uint256 promptIdx,
        uint256 randomNonce,
        bytes calldata signature
    ) public virtual override {
        _validateAgentData(agentId, sysPrompt, promptIdx);
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
            _datas[agentId].sysPrompts[promptIdx],
            sysPrompt
        );

        _datas[agentId].sysPrompts[promptIdx] = sysPrompt;
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
        bytes calldata sysPrompt
    ) public virtual override onlyAgentOwner(agentId) {
        if (sysPrompt.length == 0) revert InvalidAgentData();

        _datas[agentId].sysPrompts.push(sysPrompt);

        emit AgentDataAddNew(agentId, _datas[agentId].sysPrompts);
    }

    function updateAgentFee(
        uint256 agentId,
        uint fee
    ) public virtual override onlyAgentOwner(agentId) {
        if (_datas[agentId].fee != fee) {
            _datas[agentId].fee = fee;
        }

        emit AgentFeeUpdate(agentId, fee);
    }

    function _setHybridModel(address hybridModel) internal virtual {
        hybridModel = hybridModel;
    }

    function _setWorkerHub(address workerHub) internal virtual {
        _workerHub = workerHub;
    }

    function topUpPoolBalance(uint256 _agentId) public virtual override payable {
        _poolBalance[_agentId] += msg.value;

        emit TopUpPoolBalance(_agentId, msg.sender, msg.value);
    }

    function getAgentFee(uint256 _agentId) public virtual view returns (uint256) {
        return _datas[_agentId].fee;
    }

    function getAgentSystemPrompt(
        uint256 _agentId
    ) public virtual view returns (bytes[] memory) {
        return _datas[_agentId].sysPrompts;
    }

    function infer(
        uint256 _agentId,
        bytes calldata _calldata,
        string calldata _externalData,
        bool _flag
    ) public virtual override payable {
        (uint256 estFeeWH, bytes memory fwdData) = _infer(_agentId, _calldata);

        uint256 inferId = IHybridModel(_hybridModel).infer{value: estFeeWH}(
            fwdData,
            msg.sender,
            _flag
        );

        emit InferencePerformed(
            _agentId,
            msg.sender,
            fwdData,
            _datas[_agentId].fee,
            _externalData,
            inferId
        );
    }

    function infer(
        uint256 _agentId,
        bytes calldata _calldata,
        string calldata _externalData
    ) public virtual override payable {
        (uint256 estFeeWH, bytes memory fwdData) = _infer(_agentId, _calldata);

        uint256 inferId = IHybridModel(_hybridModel).infer{value: estFeeWH}(
            fwdData,
            msg.sender
        );

        emit InferencePerformed(
            _agentId,
            msg.sender,
            fwdData,
            _datas[_agentId].fee,
            _externalData,
            inferId
        );
    }

    function _infer(
        uint256 _agentId,
        bytes calldata _calldata
    ) internal virtual returns (uint256, bytes memory) {
        if (_datas[_agentId].sysPrompts.length == 0) revert InvalidAgentData();
        if (msg.value < _datas[_agentId].fee) revert InvalidAgentFee();

        bytes memory fwdData = abi.encodePacked(
            _concatSystemPrompts(_datas[_agentId]),
            _calldata
        );
        uint256 estFeeWH = IWorkerHub(_workerHub).getMinFeeToUse(_hybridModel);

        if (msg.value < estFeeWH && _poolBalance[_agentId] >= estFeeWH) {
            unchecked {
                _poolBalance[_agentId] -= estFeeWH;
            }

            if (msg.value > 0) {
                TransferHelper.safeTransferNative(
                    _ownerOf(_agentId),
                    msg.value
                );
            }
        } else if (msg.value >= estFeeWH) {
            uint256 remain = msg.value - estFeeWH;
            if (remain > 0) {
                TransferHelper.safeTransferNative(_ownerOf(_agentId), remain);
            }
        } else {
            revert InsufficientFunds();
        }

        return (estFeeWH, fwdData);
    }

    function dataOf(
        uint256 _agentId
    ) public virtual view returns (TokenMetaData memory) {
        return _datas[_agentId];
    }

    function royaltyInfo(
        uint256 _agentId,
        uint256 _salePrice
    ) public virtual view returns (address, uint256) {
        _agentId;
        return (
            _royaltyReceiver,
            (_salePrice * _royaltyPortion) / PORTION_DENOMINATOR
        );
    }

    function tokenURI(
        uint256 _agentId
    )
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(_agentId);
    }


    function _checkAgentOwner(address _user, uint256 _agentId) internal virtual view {
        if (_user != _ownerOf(_agentId)) revert Unauthorized();
    }

    function _validateAgentBeforeMoveToSquad(
        address _user,
        uint256 _agentId
    ) internal virtual view {
        _checkAgentOwner(_user, _agentId);
        if (_agentId >= _nextTokenId) revert InvalidAgentId();
    }

    function getAgentIdByOwner(
        address _owner
    ) external view returns (uint256[] memory) {
        uint256 len = balanceOf(_owner);
        uint256[] memory agentIds = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            agentIds[i] = tokenOfOwnerByIndex(_owner, i);
        }

        return agentIds;
    }

    function createMission(
        uint256 _agentId,
        bytes calldata _missionData
    ) public virtual override onlyAgentOwner(_agentId) {
        if (_missionData.length == 0 || _agentId >= _nextTokenId)
            revert InvalidAgentData();
        _missionsOf[_agentId].push(_missionData);

        emit AgentMissionAddNew(_agentId, _missionsOf[_agentId]);
    }

    function getMissionIdsByAgentId(
        uint256 _agentId
    ) public virtual override view returns (bytes[] memory) {
        return _missionsOf[_agentId];
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
        TokenMetaData memory data
    ) internal virtual pure returns (bytes memory) {
        bytes[] memory sysPrompts = data.sysPrompts;

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
        uint256 _agentId
    ) internal override(ERC721, ERC721URIStorage) {
        super._burn(_agentId);
    }

    //todo: add suport interface
    function supportsInterface(
        bytes4 _interfaceId
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
            _interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(_interfaceId);
    }
}