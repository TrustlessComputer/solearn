// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// Base: 0x4cCb0BB02FCABA27e82a56646E81d8c5bC4119a5
/// @notice The details of a registration request.
struct RegisterRequest {
    /// @dev The name being registered.
    string name;
    /// @dev The address of the owner for the name.
    address owner;
    /// @dev The duration of the registration in seconds.
    uint256 duration;
    /// @dev The address of the resolver to set for this name.
    address resolver;
    /// @dev Multicallable data bytes for setting records in the associated resolver upon reigstration.
    bytes[] data;
    /// @dev Bool to decide whether to set this name as the "primary" name for the `owner`.
    bool reverseRecord;
}

interface IBASERegistrarController {
    function registerPrice(string memory name, uint256 duration) external view returns (uint256);

    function register(RegisterRequest calldata request) external payable;

    function renew(string calldata name, uint256 duration) external payable;

    function rootNode() external view returns (bytes32);
}
