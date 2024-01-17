// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

error InvalidActivationFunction();
error InvalidPaddingType();

library Tensors {
	struct Tensor1D {
		SD59x18[] mat;
		uint n;
	}

	struct Tensor2D {
		SD59x18[][] mat;
		uint n;
		uint m;
	}

	struct Tensor3D {
		SD59x18[][][] mat;
		uint n;
		uint m;
		uint p;
	}

	struct Tensor4D {
		SD59x18[][][][] mat;
		uint n;
		uint m;
		uint p;
		uint q;
	}

	enum ActivationFunc {
		LeakyReLU,
		Linear,
		ReLU,
		Sigmoid,
		Tanh
	}

	enum PaddingType {
		Valid,
		Same
	}

	function __linear(SD59x18 x) internal pure returns (SD59x18) {
		return x;
	}

	function __relu(SD59x18 x) internal pure returns (SD59x18) {
		return x.unwrap() > 0 ? x : sd(0);
	}

	function __leaky_relu(SD59x18 x) internal pure returns (SD59x18) {
		return x.unwrap() > 0 ? x : x.mul(sd(2e18)).div(sd(10e18));
	}

	function __sigmoid(SD59x18 x) internal pure returns (SD59x18) {
		return sd(1e18).div(sd(1e18) + sd(-x.unwrap()).exp());
	}

	function __tanh(SD59x18 x) internal pure returns (SD59x18) {
		SD59x18 t = sd(2e18).mul(x).exp();
		return (t - sd(1e18)).div(t + sd(1e18));
	}

	function __add(SD59x18 a, SD59x18 b) internal pure returns (SD59x18) {
		return a + b;
	}

	function __mul(SD59x18 a, SD59x18 b) internal pure returns (SD59x18) {
		return a.mul(b);
	}

	function __exp(SD59x18 a) internal pure returns (SD59x18) {
		return a.exp();
	}
	
	function __subMax0(uint a, uint b) public pure returns (uint) {
		return a > b ? a - b : 0;
	}

	function max(SD59x18 a, SD59x18 b) internal pure returns (SD59x18) {
		return a.unwrap() > b.unwrap() ? a : b;
	}

	function getConvSize(
		uint[2] memory dim,
		uint[2] memory size,
		uint[2] memory stride,
		PaddingType padding
	) internal pure returns (
		uint[2] memory out,
		uint[2] memory pad
	) {
		for(uint i = 0; i < 2; ++i) {
			if (padding == PaddingType.Same) {
				out[i] = (dim[i] + stride[i] - 1) / stride[i];
				uint total_pad = (dim[i] % stride[i] == 0) ? __subMax0(size[i], stride[i]) : __subMax0(size[i], dim[i] % stride[i]);
				pad[i] = total_pad / 2;
			} else if (padding == PaddingType.Valid) {
				// TODO: What if dim[i] < size[i]
				out[i] = (dim[i] - size[i]) / stride[i] + 1;
			} else {
				revert InvalidPaddingType();
			}
		}
	}
}
