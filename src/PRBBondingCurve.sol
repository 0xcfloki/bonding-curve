pragma solidity ^0.8.24;

import {SafeCast} from "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import {wrap, pow as SD59x18_pow} from "prb-math/SD59x18.sol";
import {BaseBondingCurve} from "./BaseBondingCurve.sol";

//import "forge-std/console2.sol";

contract PRBBondingCurve is BaseBondingCurve {
    using SafeCast for uint256;

    constructor(ConstructorParams memory params) BaseBondingCurve(params) {}

    function pow(uint256 _base, uint256 _exponent) public pure override returns (uint256) {
        // Internally uses 2 ^ (_exponent * log_2(_base))
        return uint256(SD59x18_pow(wrap(_base.toInt256()), wrap(_exponent.toInt256())).unwrap());
    }
}
