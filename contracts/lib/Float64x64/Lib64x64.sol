// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import './ABDKMath64x64.sol';

/// @notice The signed 64.64-binary fixed-point number representation, which can have up to 64 binary digits and up to 64
/// binary decimals. The values of this are bound by the minimum and the maximum values permitted by the underlying Solidity
/// type int128.

type Float64x64 is int128;

function fromInt(int256 x) pure returns (Float64x64) {
  unchecked {
    require (x >= -0x8000000000000000 && x <= 0x7FFFFFFFFFFFFFFF);
    return Float64x64.wrap(int128 (x << 64));
  }
}

function toInt(Float64x64 x) pure returns (int64) {
  unchecked {
    return int64(Float64x64.unwrap(x) >> 64);
  }
}

function add(Float64x64 x, Float64x64 y) pure returns (Float64x64) {
  unchecked {
    return Float64x64.wrap(ABDKMath64x64.add(Float64x64.unwrap(x), Float64x64.unwrap(y)));
  }
}

function sub(Float64x64 x, Float64x64 y) pure returns (Float64x64) {
  unchecked {
    return Float64x64.wrap(ABDKMath64x64.sub(Float64x64.unwrap(x), Float64x64.unwrap(y)));
  }
}

function mul(Float64x64 x, Float64x64 y) pure returns (Float64x64) {
  unchecked {
    return Float64x64.wrap(ABDKMath64x64.mul(Float64x64.unwrap(x), Float64x64.unwrap(y)));
  }
}

function div(Float64x64 x, Float64x64 y) pure returns (Float64x64) {
  unchecked {
    return Float64x64.wrap(ABDKMath64x64.div(Float64x64.unwrap(x), Float64x64.unwrap(y)));
  }
}

function neg(Float64x64 x) pure returns (Float64x64) {
  unchecked {
    return Float64x64.wrap(ABDKMath64x64.neg(Float64x64.unwrap(x)));
  }
}

function abs(Float64x64 x) pure returns (Float64x64) {
  unchecked {
    return Float64x64.wrap(ABDKMath64x64.abs(Float64x64.unwrap(x)));
  }
}

function exp(Float64x64 x) pure returns (Float64x64) {
  unchecked {
    return Float64x64.wrap(ABDKMath64x64.exp(Float64x64.unwrap(x)));
  }
}  

function eq(Float64x64 x, Float64x64 y) pure returns (bool) {
  unchecked {
    return Float64x64.unwrap(x) == Float64x64.unwrap(y);
  }
}

function gt(Float64x64 x, Float64x64 y) pure returns (bool) {
  unchecked {
    return Float64x64.unwrap(x) > Float64x64.unwrap(y);
  }
}

function gte(Float64x64 x, Float64x64 y) pure returns (bool) {
  unchecked {
    return Float64x64.unwrap(x) >= Float64x64.unwrap(y);
  }
}

function lt(Float64x64 x, Float64x64 y) pure returns (bool) {
  unchecked {
    return Float64x64.unwrap(x) < Float64x64.unwrap(y);
  }
}

function lte(Float64x64 x, Float64x64 y) pure returns (bool) {
  unchecked {
    return Float64x64.unwrap(x) <= Float64x64.unwrap(y);
  }
}

function neq(Float64x64 x, Float64x64 y) pure returns (bool) {
  unchecked {
    return Float64x64.unwrap(x) != Float64x64.unwrap(y);
  }
}

using {
  add,
  div,
  mul,
  sub,
  neg,
  // mod,
  eq,
  gt,
  gte,
  lt,
  lte,
  neq,
  // and2,
  // or,
  // xor^
  // not,
  exp
} for Float64x64 global;

using {
  add as +,
  div as /,
  mul as *,
  sub as -,
  neg as -,
  // mod as %,
  eq as ==,
  gt as >,
  gte as >=,
  lt as <,
  lte as <=,
  neq as !=
  // and2 as &,
  // or as |,
  // xor as ^
  // not as ~,
} for Float64x64 global;
