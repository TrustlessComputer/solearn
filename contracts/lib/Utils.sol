// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";

library Utils {
	function zip(SD59x18[][] memory rows) internal pure returns (SD59x18[][] memory) {
		SD59x18[][] memory result = new SD59x18[][](rows[0].length);
		for (uint i = 0; i < rows[0].length; i++) {
			result[i] = new SD59x18[](rows.length);
			for (uint j = 0; j < rows.length; j++) {
				result[i][j] = rows[j][i];
			}
		}
		return result;
	}

	function clone(SD59x18[] memory items) internal pure returns (SD59x18[] memory) {
		SD59x18[] memory result = new SD59x18[](items.length);
		for (uint i = 0; i < items.length; i++) {
			result[i] = items[i];
		}
		return result;
	}

	function isNullOrEmpty(string memory str) internal pure returns (bool) {
		return bytes(str).length == 0;
	}

	function base64_to_hex(string memory str) internal pure returns (string memory) {
		bytes memory raw = bytes(str);
		bytes memory result = new bytes(raw.length * 2);
		for (uint i = 0; i < raw.length; i++) {
			bytes1 hexCh = bytes1(uint8(raw[i]) + 48);
			result[2 * i] = hexCh;
			result[2 * i + 1] = hexCh;
		}
		return string(result);
	}

	function rand(uint256 seed) internal pure returns (SD59x18) {
		return sd(int(seed % 1e18));
	}

	function getWeightedRandom(SD59x18[] memory probs, uint256 seed) internal pure returns (uint256) {
		SD59x18 x = rand(seed);
		SD59x18 sum = sd(0);
		for (uint256 i = 0; i < probs.length; i++) {
			sum = sum + probs[i];
			if (sum.gt(x)) {
				return i;
			}
		}
		return probs.length - 1;
	}

	function getHash(string memory s) internal pure returns (bytes32) {
		return keccak256(bytes(s));
	}

	function equals(string memory a, string memory b) internal pure returns (bool) {
		return getHash(a) == getHash(b);
	}

	function getBinaryDigits(int256 x) internal pure returns (uint256) {
		uint256 count;
		while (x > 0) {
			++count;
			x >>= 1;
		}
		return count;
	}

	function fixedPointToFloatPoint(SD59x18 fixedPoint) internal pure returns (bytes8) {
		int256 value = fixedPoint.intoInt256();
		unchecked {
			if (value == 0) {
				return 0;
			}

			if (value == type(int256).min) {
				return bytes8(uint64(14978972360634269696));
			}

			uint256 isNegative;
			if (value < 0) {
				isNegative = 1;
				value = -value;
			}

			uint256 exponent = 0;
			uint256 mantissa = 0;
			if (value >= 1e18) {
				exponent = getBinaryDigits(value / 1e18) - 1;
				value >>= exponent;
				exponent += 1023;
			} else {
				exponent = getBinaryDigits(1e18 / value);
				value <<= exponent;
				exponent = exponent ^ 1023;
			}

			value -= 1e18;
			for (uint256 i = 0; i < 52; ++i) {
				value <<= 1;
				mantissa <<= 1;
				if (value >= 1e18) {
					mantissa |= 1;
					value -= 1e18;
				}
			}

			return bytes8(uint64(mantissa | (exponent << 52) | (isNegative << 63)));
		}
	}
}
