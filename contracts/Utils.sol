// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract Utils {
	function zip(uint[][] memory rows) public pure returns (uint[][] memory) {
		uint[][] memory result = new uint[][](rows[0].length);
		for (uint i = 0; i < rows[0].length; i++) {
			result[i] = new uint[](rows.length);
			for (uint j = 0; j < rows.length; j++) {
				result[i][j] = rows[j][i];
			}
		}
		return result;
	}

	function clone(uint[] memory items) public pure returns (uint[] memory) {
		uint[] memory result = new uint[](items.length);
		for (uint i = 0; i < items.length; i++) {
			result[i] = items[i];
		}
		return result;
	}

	function isNullOrEmpty(string memory str) public pure returns (bool) {
		return bytes(str).length == 0;
	}

	function base64_to_hex(string memory str) public pure returns (string memory) {
		bytes memory raw = bytes(str);
		bytes memory result = new bytes(raw.length * 2);
		for (uint i = 0; i < raw.length; i++) {
			bytes1 hexCh = bytes1(uint8(raw[i]) + 48);
			result[2 * i] = hexCh;
			result[2 * i + 1] = hexCh;
		}
		return string(result);
	}

}
