// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library TransferHelper {
    bytes4 constant private APPROVE_SELECTOR = bytes4(keccak256(bytes('approve(address,uint256)')));
    bytes4 constant private TRANSFER_SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));
    bytes4 constant private TRANSFER_FROM_SELECTOR = bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));

    error FailedApproval();
    error FailedTransfer();

    function safeApprove(
        address _token,
        address _to,
        uint256 _value
    ) internal {
        (bool success, bytes memory data) = _token.call(
            abi.encodeWithSelector(
                TRANSFER_SELECTOR,
                _to,
                _value
            )
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert FailedApproval();
        }
    }

    function safeTransfer(
        address _token,
        address _to,
        uint256 _value
    ) internal {
        (bool success, bytes memory data) = _token.call(
            abi.encodeWithSelector(
                TRANSFER_SELECTOR,
                _to,
                _value
            )
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert FailedTransfer();
        }
    }

    function safeTransferFrom(
        address _token,
        address _from,
        address _to,
        uint256 _value
    ) internal {
        (bool success, bytes memory data) = _token.call(
            abi.encodeWithSelector(
                TRANSFER_FROM_SELECTOR,
                _from,
                _to,
                _value
            )
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert FailedTransfer();
        }
    }

    function safeTransferNative(address _to, uint256 _value) internal {
        (bool success, ) = _to.call{value: _value}("");
        if (!success) revert FailedTransfer();
    }
}
