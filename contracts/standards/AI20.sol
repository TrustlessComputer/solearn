// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IAI20} from "./IAI20.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

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

contract AI20 is ERC20, IAI20 {
    uint256 private constant PORTION_DENOMINATOR = 10000;

    TokenMetaData private _data;
    address public _workerHub;
    address public _hybridModel;
    IERC20 private immutable _tokenFee;
    uint256 public _poolBalance;
    mapping(bytes32 signature => bool) public _signaturesUsed;
    bytes[] private _mission;

    constructor(
        string memory name_,
        string memory symbol_,
        address hybridModel_,
        address workerHub_,
        IERC20 tokenFee_
    ) ERC20(name_, symbol_) {
        _hybridModel = hybridModel_;
        _workerHub = workerHub_;
        _tokenFee = tokenFee_;
    }

    function _setHybridModel(address hybridModel) internal virtual {
        hybridModel = hybridModel;
    }

    function _setWorkerHub(address workerHub) internal virtual {
        _workerHub = workerHub;
    }

    function _mint(
        address to,
        string calldata uri,
        bytes calldata data,
        uint fee,
        uint256 agentId,
        string calldata promptKey
    ) internal virtual returns (uint256) {

        return agentId;
    }

    function _validateURI(string calldata uri) internal virtual pure {
        if (bytes(uri).length == 0) revert InvalidAgentData();
    }

    function _updateAgentData(
        bytes calldata sysPrompt,
        string calldata promptKey,
        uint256 promptIdx
    ) internal virtual {
        _validateAgentData(sysPrompt, promptIdx, promptKey);
        _data.sysPrompts[promptKey][promptIdx] = sysPrompt;
    }

    function _validateAgentData(
        bytes calldata sysPrompt,
        uint256 promptIdx,
        string calldata promptKey
    ) internal virtual view {
        if (sysPrompt.length == 0) revert InvalidAgentData();
        uint256 len = _data.sysPrompts[promptKey].length;
        if (promptIdx >= len) revert InvalidAgentPromptIndex();
    }

    function _addNewAgentData(
        string calldata promptKey,
        bytes calldata sysPrompt
    ) internal virtual {
        if (sysPrompt.length == 0) revert InvalidAgentData();
        _data.sysPrompts[promptKey].push(sysPrompt);

        emit AgentDataAddNew(_data.sysPrompts[promptKey]);
    }

    function _updateAgentFee(
        uint fee
    ) internal virtual {
        if (_data.fee != fee) {
            _data.fee = uint128(fee);
        }

        emit AgentFeeUpdate(fee);
    }

    function topUpPoolBalance(uint256 amount) public virtual override {
        SafeERC20.safeTransferFrom(_tokenFee, msg.sender, address(this), amount);
        _poolBalance += amount;

        emit TopUpPoolBalance(msg.sender, amount);
    }

    function getAgentSystemPrompt(
        string calldata promptKey
    ) public virtual view returns (bytes[] memory) {
        return _data.sysPrompts[promptKey];
    }

    function infer(
        bytes calldata fwdCalldata,
        string calldata externalData,
        string calldata promptKey,
        uint256 modelId,
        bool flag,
        uint feeAmount
    ) public virtual override payable {
        (uint256 estFeeWH, bytes memory fwdData) = _infer(fwdCalldata, promptKey, feeAmount);

        uint256 inferId = IInferable(_hybridModel).infer{value: estFeeWH}(
            modelId,
            fwdData,
            msg.sender,
            flag
        );

        emit InferencePerformed(
            msg.sender,
            fwdData,
            _data.fee,
            externalData,
            inferId
        );
    }

    function infer(
        bytes calldata fwdCalldata,
        string calldata externalData,
        string calldata promptKey,
        uint256 modelId,
        uint256 feeAmount
    ) public virtual override payable {
        (uint256 estFeeWH, bytes memory fwdData) = _infer(fwdCalldata, promptKey, feeAmount);

        uint256 inferId = IInferable(_hybridModel).infer{value: estFeeWH}(
            modelId,
            fwdData,
            msg.sender
        );

        emit InferencePerformed(
            msg.sender,
            fwdData,
            _data.fee,
            externalData,
            inferId
        );
    }

    function _infer(
        bytes calldata fwdCalldata,
        string calldata promptKey,
        uint256 feeAmount
    ) internal virtual returns (uint256, bytes memory) {
        if (_data.sysPrompts[promptKey].length == 0) revert InvalidAgentData();
        if (feeAmount < _data.fee) revert InvalidAgentFee();
        SafeERC20.safeTransferFrom(_tokenFee, msg.sender, address(this), feeAmount);

        bytes memory fwdData = abi.encodePacked(
            _concatSystemPrompts(_data.sysPrompts[promptKey]),
            fwdCalldata
        );
        uint256 estFeeWH = IWorkerHub(_workerHub).getMinFeeToUse(_hybridModel);

        if (feeAmount < estFeeWH && _poolBalance >= estFeeWH) {
            unchecked {
                _poolBalance -= estFeeWH;
            }

            // todo:
            // if (feeAmount > 0) {
            //     SafeERC20.safeTransfer(_tokenFee, _ownerOf(agentId), _datas.fee);
            // }
        } else if (feeAmount >= estFeeWH) {
            uint256 remain = feeAmount - estFeeWH;
            // if (remain > 0) {
            //     SafeERC20.safeTransfer(_tokenFee, _ownerOf(agentId), remain);
            // }
        } else {
            revert InsufficientFunds();
        }

        return (estFeeWH, fwdData);
    }

    function inferData() public virtual view returns(uint256) {
        return _data.fee;
    }

    function _createMission(
        bytes memory missionData
    ) internal virtual {
        // _mission = missionData;

        emit AgentMissionAddNew(_mission);
    }

    function getMission() public virtual override view returns (bytes[] memory) {
        return _mission;
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

}