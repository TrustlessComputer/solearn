// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { Float64x64, fromInt, toInt } from "./../Float64x64/Lib.sol";

error InvalidActivationFunction();
error InvalidPaddingType();

library Tensors {
	Float64x64 private constant ONE = Float64x64.wrap(1 << 64);
	Float64x64 private constant TWO = Float64x64.wrap(2 << 64);
	Float64x64 private constant TEN = Float64x64.wrap(10 << 64);

	struct Tensor1D {
		Float64x64[] mat;
		uint n;
	}

	struct Tensor2D {
		Float64x64[][] mat;
		uint n;
		uint m;
	}

	struct Tensor3D {
		Float64x64[][][] mat;
		uint n;
		uint m;
		uint p;
	}

	struct Tensor4D {
		Float64x64[][][][] mat;
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

	function __linear(Float64x64 x) internal pure returns (Float64x64) {
		return x;
	}

	function __relu(Float64x64 x) internal pure returns (Float64x64) {
		return Float64x64.unwrap(x) > 0 ? x : Float64x64.wrap(0);
	}

	function __leaky_relu(Float64x64 x) internal pure returns (Float64x64) {
		return Float64x64.unwrap(x) > 0 ? x : x.mul(TWO).div(TEN);
	}

	function __sigmoid(Float64x64 x) internal pure returns (Float64x64) {
		// Exp will fail if input is greater than 43
		if (Float64x64.unwrap(x) < -43 << 64) {
			x = fromInt(-43);
		}
		return ONE.div(ONE + (-x).exp());
	}

	function __tanh(Float64x64 x) internal pure returns (Float64x64) {
		// Exp will fail if input is greater than 43
		if (Float64x64.unwrap(x) > 21 << 64) {
			x = fromInt(21);
		}
		Float64x64 t = TWO.mul(x).exp();
		return (t - ONE).div(t + ONE);
	}

	function __add(Float64x64 a, Float64x64 b) internal pure returns (Float64x64) {
		return a + b;
	}

	function __mul(Float64x64 a, Float64x64 b) internal pure returns (Float64x64) {
		return a.mul(b);
	}

	function __exp(Float64x64 a) internal pure returns (Float64x64) {
		return a.exp();
	}
	
	function __subMax0(uint a, uint b) public pure returns (uint) {
		return a > b ? a - b : 0;
	}

	function max(Float64x64 a, Float64x64 b) internal pure returns (Float64x64) {
		return Float64x64.unwrap(a) > Float64x64.unwrap(a) ? a : b;
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
