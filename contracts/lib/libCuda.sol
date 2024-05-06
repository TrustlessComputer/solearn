// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SD59x18, sd} from "@prb/math/src/SD59x18.sol";
import {Float32x32} from "./Float32x32/Lib32x32.sol";

library CUDA {
    address constant CUDA_ADD = 0x0000000000000000000000000000000000000021;
    address constant CUDA_SUB = 0x0000000000000000000000000000000000000022;
    address constant CUDA_MUL = 0x0000000000000000000000000000000000000023;
    address constant CUDA_DIV = 0x0000000000000000000000000000000000000024;
    address constant CUDA_GEMM = 0x0000000000000000000000000000000000000025;
    address constant CUDA_ABS = 0x0000000000000000000000000000000000000026;
    address constant CUDA_BITWISE_AND = 0x0000000000000000000000000000000000000027;
    address constant CUDA_BITWISE_NOT = 0x0000000000000000000000000000000000000028;
    address constant CUDA_BITWISE_OR = 0x0000000000000000000000000000000000000029;
    address constant CUDA_BITWISE_XOR = 0x000000000000000000000000000000000000002A;
    address constant CUDA_EXP = 0x000000000000000000000000000000000000002b;
    address constant CUDA_LOG = 0x000000000000000000000000000000000000002c;
    address constant CUDA_MAX = 0x000000000000000000000000000000000000002D;
    address constant CUDA_MIN = 0x000000000000000000000000000000000000002E;
    address constant CUDA_SQRT = 0x000000000000000000000000000000000000002F;

    uint8 constant _32BIT_SIGN_INT_MAT_TYPE = 4;
    uint8  constant _64BIT_SIGN_INT_MAT_TYPE_FIXED = 7;
    uint8 constant _32BIT_FLOAT_MAT_TYPE = 5;
    uint8  constant _64BIT_FLOAT_MAT_TYPE = 6;

    /*uint8 matTypeInBit = 4;
        uint8 matInputTypeSize = 32;
        uint8 matOutputTypeSize = 32;*/

    function add(int[][] memory mat1, int[][] memory mat2, uint8 matTypeInBit, uint8 matInputTypeSize, uint8 matOutputTypeSize)
    internal
    returns (int[][] memory result) {
        (, bytes memory matData) = CUDA_ADD.call(abi.encode(matTypeInBit, matInputTypeSize, matOutputTypeSize, mat1, mat2));
        (result) = abi.decode(matData, (int[][]));
    }

    function addFloat32x32(Float32x32[][] memory mat1, Float32x32[][] memory mat2, uint8 matTypeInBit, uint8 matInputTypeSize, uint8 matOutputTypeSize)
    internal
    returns (Float32x32[][] memory result) {
        (, bytes memory matData) = CUDA_ADD.call(abi.encode(matTypeInBit, matInputTypeSize, matOutputTypeSize, mat1, mat2));
        (result) = abi.decode(matData, (Float32x32[][]));
    }

    function sub(int[][] memory mat1, int[][] memory mat2, uint8 matTypeInBit, uint8 matInputTypeSize, uint8 matOutputTypeSize)
    internal
    returns (int[][] memory result) {
        (, bytes memory matData) = CUDA_SUB.call(abi.encode(matTypeInBit, matInputTypeSize, matOutputTypeSize, mat1, mat2));
        (result) = abi.decode(matData, (int[][]));
    }

    /*function subFloat32x32(Float32x32[][] memory mat1, Float32x32[][] memory mat2, uint8 matTypeInBit, uint8 matInputTypeSize, uint8 matOutputTypeSize)
    internal
    returns (Float32x32[][] memory result) {
        (, bytes memory matData) = CUDA_SUB.call(abi.encode(matTypeInBit, matInputTypeSize, matOutputTypeSize, mat1, mat2));
        (result) = abi.decode(matData, (Float32x32[][]));
    }*/

    function mul(int[][] memory mat1, int[][] memory mat2, uint8 matTypeInBit, uint8 matInputTypeSize, uint8 matOutputTypeSize)
    internal
    returns (int[][] memory result) {
        (, bytes memory matData) = CUDA_MUL.call(abi.encode(matTypeInBit, matInputTypeSize, matOutputTypeSize, mat1, mat2));
        (result) = abi.decode(matData, (int[][]));
    }

    /*function mulFloat32x32(Float32x32[][] memory mat1, Float32x32[][] memory mat2, uint8 matTypeInBit, uint8 matInputTypeSize, uint8 matOutputTypeSize)
    internal
    returns (Float32x32[][] memory result) {
        (, bytes memory matData) = CUDA_MUL.call(abi.encode(matTypeInBit, matInputTypeSize, matOutputTypeSize, mat1, mat2));
        (result) = abi.decode(matData, (Float32x32[][]));
    }*/

    function div(int[][] memory mat1, int[][] memory mat2, uint8 matTypeInBit, uint8 matInputTypeSize, uint8 matOutputTypeSize)
    internal
    returns (int[][] memory result) {
        (, bytes memory matData) = CUDA_DIV.call(abi.encode(matTypeInBit, matInputTypeSize, matOutputTypeSize, mat1, mat2));
        (result) = abi.decode(matData, (int[][]));
    }

    /*function divFloat32x32(Float32x32[][] memory mat1, Float32x32[][] memory mat2, uint8 matTypeInBit, uint8 matInputTypeSize, uint8 matOutputTypeSize)
    internal
    returns (Float32x32[][] memory result) {
        (, bytes memory matData) = CUDA_DIV.call(abi.encode(matTypeInBit, matInputTypeSize, matOutputTypeSize, mat1, mat2));
        (result) = abi.decode(matData, (Float32x32[][]));
    }*/

    function gemm(int[][] memory mat1, int[][] memory mat2, uint8 matTypeInBit, uint8 matInputTypeSize, uint8 matOutputTypeSize)
    internal
    returns (int[][] memory result) {
        (, bytes memory matData) = CUDA_GEMM.call(abi.encode(matTypeInBit, matInputTypeSize, matOutputTypeSize, mat1, mat2));
        (result) = abi.decode(matData, (int[][]));
    }

    function gemmFloat32x32(Float32x32[][] memory mat1, Float32x32[][] memory mat2, uint8 matTypeInBit, uint8 matInputTypeSize, uint8 matOutputTypeSize)
    internal
    returns (Float32x32[][] memory result) {
        (, bytes memory matData) = CUDA_GEMM.call(abi.encode(matTypeInBit, matInputTypeSize, matOutputTypeSize, mat1, mat2));
        (result) = abi.decode(matData, (Float32x32[][]));
    }

    function abs(int[][] memory mat, uint8 matTypeInBit, uint8 matInputTypeSize, uint8 matOutputTypeSize) internal
    returns (int[][] memory result) {
        (, bytes memory matData) = CUDA_ABS.call(abi.encode(matTypeInBit, matInputTypeSize, matOutputTypeSize, mat));
        (result) = abi.decode(matData, (int[][]));
    }

    /*function absFloat32x32(Float32x32[][] memory mat, uint8 matTypeInBit, uint8 matInputTypeSize, uint8 matOutputTypeSize) internal
    returns (Float32x32[][] memory result) {
        (, bytes memory matData) = CUDA_ABS.call(abi.encode(matTypeInBit, matInputTypeSize, matOutputTypeSize, mat));
        (result) = abi.decode(matData, (Float32x32[][]));
    }*/

    function bitwiseAnd(int[][] memory mat1, int[][] memory mat2, uint8 matTypeInBit, uint8 matInputTypeSize, uint8 matOutputTypeSize)
    internal
    returns (int[][] memory result) {
        (, bytes memory matData) = CUDA_BITWISE_AND.call(abi.encode(matTypeInBit, matInputTypeSize, matOutputTypeSize, mat1, mat2));
        (result) = abi.decode(matData, (int[][]));
    }

    /*function bitwiseAndFloat32x32(Float32x32[][] memory mat1, Float32x32[][] memory mat2, uint8 matTypeInBit, uint8 matInputTypeSize, uint8 matOutputTypeSize)
    internal
    returns (Float32x32[][] memory result) {
        (, bytes memory matData) = CUDA_BITWISE_AND.call(abi.encode(matTypeInBit, matInputTypeSize, matOutputTypeSize, mat1, mat2));
        (result) = abi.decode(matData, (Float32x32[][]));
    }*/

    function bitwiseNot(int[][] memory mat1, int[][] memory mat2, uint8 matTypeInBit, uint8 matInputTypeSize, uint8 matOutputTypeSize)
    internal
    returns (int[][] memory result) {
        (, bytes memory matData) = CUDA_BITWISE_NOT.call(abi.encode(matTypeInBit, matInputTypeSize, matOutputTypeSize, mat1, mat2));
        (result) = abi.decode(matData, (int[][]));
    }

    /*function bitwiseNotFloat32x32(Float32x32[][] memory mat1, Float32x32[][] memory mat2, uint8 matTypeInBit, uint8 matInputTypeSize, uint8 matOutputTypeSize)
    internal
    returns (Float32x32[][] memory result) {
        (, bytes memory matData) = CUDA_BITWISE_NOT.call(abi.encode(matTypeInBit, matInputTypeSize, matOutputTypeSize, mat1, mat2));
        (result) = abi.decode(matData, (Float32x32[][]));
    }*/

    function bitwiseOr(int[][] memory mat1, int[][] memory mat2, uint8 matTypeInBit, uint8 matInputTypeSize, uint8 matOutputTypeSize)
    internal
    returns (int[][] memory result) {
        (, bytes memory matData) = CUDA_BITWISE_OR.call(abi.encode(matTypeInBit, matInputTypeSize, matOutputTypeSize, mat1, mat2));
        (result) = abi.decode(matData, (int[][]));
    }

    function bitwiseXor(int[][] memory mat1, int[][] memory mat2, uint8 matTypeInBit, uint8 matInputTypeSize, uint8 matOutputTypeSize)
    internal
    returns (int[][] memory result) {
        (, bytes memory matData) = CUDA_BITWISE_XOR.call(abi.encode(matTypeInBit, matInputTypeSize, matOutputTypeSize, mat1, mat2));
        (result) = abi.decode(matData, (int[][]));
    }

    function exp(int[][] memory mat, uint8 matTypeInBit, uint8 matInputTypeSize, uint8 matOutputTypeSize) internal
    returns (int[][] memory result) {
        (, bytes memory matData) = CUDA_EXP.call(abi.encode(matTypeInBit, matInputTypeSize, matOutputTypeSize, mat));
        (result) = abi.decode(matData, (int[][]));
    }

    function log(int[][] memory mat, uint8 matTypeInBit, uint8 matInputTypeSize, uint8 matOutputTypeSize) internal
    returns (int[][] memory result) {
        (, bytes memory matData) = CUDA_LOG.call(abi.encode(matTypeInBit, matInputTypeSize, matOutputTypeSize, mat));
        (result) = abi.decode(matData, (int[][]));
    }

    function max(int[][] memory mat1, int[][] memory mat2, uint8 matTypeInBit, uint8 matInputTypeSize, uint8 matOutputTypeSize)
    internal
    returns (int[][] memory result) {
        (, bytes memory matData) = CUDA_MAX.call(abi.encode(matTypeInBit, matInputTypeSize, matOutputTypeSize, mat1, mat2));
        (result) = abi.decode(matData, (int[][]));
    }

    function min(int[][] memory mat1, int[][] memory mat2, uint8 matTypeInBit, uint8 matInputTypeSize, uint8 matOutputTypeSize)
    internal
    returns (int[][] memory result) {
        (, bytes memory matData) = CUDA_MIN.call(abi.encode(matTypeInBit, matInputTypeSize, matOutputTypeSize, mat1, mat2));
        (result) = abi.decode(matData, (int[][]));
    }

    function sqrt(int[][] memory mat, uint8 matTypeInBit, uint8 matInputTypeSize, uint8 matOutputTypeSize) internal
    returns (int[][] memory result) {
        (, bytes memory matData) = CUDA_SQRT.call(abi.encode(matTypeInBit, matInputTypeSize, matOutputTypeSize, mat));
        (result) = abi.decode(matData, (int[][]));
    }

    /*function bitwiseOrFloat32x32(Float32x32[][] memory mat1, Float32x32[][] memory mat2, uint8 matTypeInBit, uint8 matInputTypeSize, uint8 matOutputTypeSize)
    internal
    returns (Float32x32[][] memory result) {
        (, bytes memory matData) = CUDA_BITWISE_OR.call(abi.encode(matTypeInBit, matInputTypeSize, matOutputTypeSize, mat1, mat2));
        (result) = abi.decode(matData, (Float32x32[][]));
    }*/

    /*function bitwiseXorFloat32x32(Float32x32[][] memory mat1, Float32x32[][] memory mat2, uint8 matTypeInBit, uint8 matInputTypeSize, uint8 matOutputTypeSize)
    internal
    returns (Float32x32[][] memory result) {
        (, bytes memory matData) = CUDA_BITWISE_XOR.call(abi.encode(matTypeInBit, matInputTypeSize, matOutputTypeSize, mat1, mat2));
        (result) = abi.decode(matData, (Float32x32[][]));
    }*/

    /*function expFloat32x32(Float32x32[][] memory mat, uint8 matTypeInBit, uint8 matInputTypeSize, uint8 matOutputTypeSize) internal
    returns (Float32x32[][] memory result) {
        (, bytes memory matData) = CUDA_EXP.call(abi.encode(matTypeInBit, matInputTypeSize, matOutputTypeSize, mat));
        (result) = abi.decode(matData, (Float32x32[][]));
    }*/

    /*function logFloat32x32(Float32x32[][] memory mat, uint8 matTypeInBit, uint8 matInputTypeSize, uint8 matOutputTypeSize) internal
    returns (Float32x32[][] memory result) {
        (, bytes memory matData) = CUDA_LOG.call(abi.encode(matTypeInBit, matInputTypeSize, matOutputTypeSize, mat));
        (result) = abi.decode(matData, (Float32x32[][]));
    }*/

    /*function maxFloat32x32(Float32x32[][] memory mat1, Float32x32[][] memory mat2, uint8 matTypeInBit, uint8 matInputTypeSize, uint8 matOutputTypeSize)
    internal
    returns (Float32x32[][] memory result) {
        (, bytes memory matData) = CUDA_MAX.call(abi.encode(matTypeInBit, matInputTypeSize, matOutputTypeSize, mat1, mat2));
        (result) = abi.decode(matData, (Float32x32[][]));
    }*/

    /*function minFloat32x32(Float32x32[][] memory mat1, Float32x32[][] memory mat2, uint8 matTypeInBit, uint8 matInputTypeSize, uint8 matOutputTypeSize)
    internal
    returns (Float32x32[][] memory result) {
        (, bytes memory matData) = CUDA_MIN.call(abi.encode(matTypeInBit, matInputTypeSize, matOutputTypeSize, mat1, mat2));
        (result) = abi.decode(matData, (Float32x32[][]));
    }*/

    /*function sqrtFloat32x32(Float32x32[][] memory mat, uint8 matTypeInBit, uint8 matInputTypeSize, uint8 matOutputTypeSize) internal
    returns (Float32x32[][] memory result) {
        (, bytes memory matData) = CUDA_SQRT.call(abi.encode(matTypeInBit, matInputTypeSize, matOutputTypeSize, mat));
        (result) = abi.decode(matData, (Float32x32[][]));
    }*/
}
