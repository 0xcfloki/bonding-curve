pragma solidity ^0.8.24;

import {ABDKMath64x64} from "abdk-libraries-solidity/ABDKMath64x64.sol";
import {BaseBondingCurve} from "./BaseBondingCurve.sol";
import {ABDKMath} from "src/Utils/Math.sol";

//import "forge-std/console2.sol";

contract ABDKBondingCurve is BaseBondingCurve {
    using ABDKMath64x64 for uint256;
    using ABDKMath64x64 for int128;

    constructor(ConstructorParams memory params) BaseBondingCurve(params) {}

    function pow(uint256 _base, uint256 _exponent) public pure override returns (uint256) {
        // _base ^ _exponent = 2 ^ (_exponent * log_2(_base))
        return ABDKMath.toDecimal(
            ABDKMath64x64.exp_2(ABDKMath.fromDecimal(_exponent).mul(ABDKMath64x64.log_2(ABDKMath.fromDecimal(_base))))
        );
    }
}
