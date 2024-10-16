// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MintingProxy {
    address public owner;

    // sender => handler address
    mapping(address => address) public handlers;
    // handler address => sig => approved sigs
    mapping(address => mapping(bytes4 => bool)) public approvedSigs;

    constructor(address _owner) {
        owner = _owner;   
    }

    function setOwner(address newOwner) public {
        require(msg.sender == owner, "Auth");
        owner = newOwner;
    }

    function setHandler(address workerHub, address handler) public {
        require(msg.sender == owner, "Auth");

        handlers[workerHub] = handler;
    }

    function setApprovedSig(address handler, bytes4 sig, bool approved) public {
        require(msg.sender == owner, "Only the owner can set approved sigs");
        
        approvedSigs[handler][sig] = approved;
    }

    fallback() external payable {
        require(msg.data.length >= 4 || msg.data.length == 0, "Ut");
        // Get facet from function selector
        address facetAddress = handlers[msg.sender];

        require(facetAddress != address(0), "F"); // Proxy has no facet for this selector
        require(approvedSigs[facetAddress][msg.sig], "N"); // Proxy does not allow this function call

        assembly {
            // The pointer to the free memory slot
            let ptr := mload(0x40)
            // Copy function signature and arguments from calldata at zero position into memory at pointer position
            calldatacopy(ptr, 0, calldatasize())
            // Delegatecall method of the implementation contract returns 0 on error
            let result := delegatecall(gas(), facetAddress, ptr, calldatasize(), 0, 0)
            // Get the size of the last return data
            let size := returndatasize()
            // Copy the size length of bytes from return data at zero position to pointer position
            returndatacopy(ptr, 0, size)
            // Depending on the result value
            switch result
            case 0 {
                // End execution and revert state changes
                revert(ptr, size)
            }
            default {
                // Return data with length of size at pointers position
                return(ptr, size)
            }
        }
    }
}
