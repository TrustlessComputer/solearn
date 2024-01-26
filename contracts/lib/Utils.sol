// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";

contract Utils {
	function zip(SD59x18[][] memory rows) public pure returns (SD59x18[][] memory) {
		SD59x18[][] memory result = new SD59x18[][](rows[0].length);
		for (uint i = 0; i < rows[0].length; i++) {
			result[i] = new SD59x18[](rows.length);
			for (uint j = 0; j < rows.length; j++) {
				result[i][j] = rows[j][i];
			}
		}
		return result;
	}

	function clone(SD59x18[] memory items) public pure returns (SD59x18[] memory) {
		SD59x18[] memory result = new SD59x18[](items.length);
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
