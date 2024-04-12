
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract Test {
  uint64[] public a;
  
  function testSaveStorage(uint n) public {
    unchecked {
      for(uint i = 0; i < n; ++i) {
        a.push(123);
      }
    }
  }

  function testLoadStorage(uint n) public {
    uint64 res = 0;
    uint len = a.length;
    unchecked {
      for(uint i = len-n; i < len; ++i) {
        res = a[i];
      }
    }
  }
  
  function clearStorage() public {
    delete a;
  }
}
