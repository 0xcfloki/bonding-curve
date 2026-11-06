// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ABDKMath64x64} from "abdk-libraries-solidity/ABDKMath64x64.sol";
import {wrap, pow as SD59x18_pow, exp2 as SD59x18_exp2, log2 as SD59x18_log2} from "prb-math/SD59x18.sol";
import {SafeCast} from "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import {DECIMAL_PRECISION} from "../Constants.sol";

library ABDKMath {
    using ABDKMath64x64 for int128;
    using ABDKMath for int128;
    using SafeCast for *;

    // Largest number that can be converted to ABDK's 64.64 format
    uint256 internal constant MAX_ARGUMENT = uint256(int256(type(int128).max)) * DECIMAL_PRECISION >> 64;

    function fromDecimal(int256 x) internal pure returns (int128) {
        // `x << 64` does not revert on overflow, so reject what would not fit before shifting
        // casting `MAX_ARGUMENT` to `int256` is safe: it is below 2^127
        // forge-lint: disable-next-line(unsafe-typecast)
        require(x <= int256(MAX_ARGUMENT) && x >= -int256(MAX_ARGUMENT), "ABDKMath: argument too large");
        // casting `DECIMAL_PRECISION` to `int256` is safe
        // forge-lint: disable-next-line(unsafe-typecast)
        int256 ret = (x << 64) / int256(DECIMAL_PRECISION);
        return ret.toInt128();
    }

    function fromDecimal(uint256 x) internal pure returns (int128) {
        // `x << 64` does not revert on overflow: above 2^192 the high bits would be dropped silently
        require(x <= MAX_ARGUMENT, "ABDKMath: argument too large");
        uint256 ret = (x << 64) / DECIMAL_PRECISION;
        return ret.toInt256().toInt128();
    }

    function toDecimal(int128 x) internal pure returns (uint256) {
        return (x.toUint256() * DECIMAL_PRECISION) >> 64;
    }

    function toSignedDecimal(int128 x) internal pure returns (int256) {
        // casting `DECIMAL_PRECISION` to `int256` is safe
        // forge-lint: disable-next-line(unsafe-typecast)
        return (x * int256(DECIMAL_PRECISION)) >> 64;
    }

    function log2(uint256 x) internal pure returns (int256) {
        return ABDKMath.fromDecimal(x).log_2().toSignedDecimal();
    }

    function exp2(int256 _exponent) internal pure returns (uint256) {
        return ABDKMath.fromDecimal(_exponent).exp_2().toDecimal();
    }

    function pow(uint256 _base, uint256 _exponent) internal pure returns (uint256) {
        return ABDKMath.fromDecimal(_base).log_2().mul(ABDKMath.fromDecimal(_exponent)).exp_2().toDecimal();
    }
}

library PRBMath {
    using SafeCast for *;

    function log2(uint256 x) internal pure returns (int256) {
        return SD59x18_log2(wrap(x.toInt256())).unwrap();
    }

    function exp2(int256 _exponent) internal pure returns (uint256) {
        return uint256(SD59x18_exp2(wrap(_exponent)).unwrap());
    }

    function pow(uint256 _base, uint256 _exponent) internal pure returns (uint256) {
        return uint256(SD59x18_pow(wrap(_base.toInt256()), wrap(_exponent.toInt256())).unwrap());
    }
}
