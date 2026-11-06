// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {DECIMAL_PRECISION} from "src/Constants.sol";

import {BondingCurveBaseTest, IBondingCurve} from "./TestContracts/BondingCurveBaseTest.t.sol";

contract FromDecimalOverflowTest is BondingCurveBaseTest {
    uint256 constant FEE = 5e14; // same fee as the test setup

    // Amount whose gross (amount + getBcTokenBuyFeeFromNet(amount)) is `_target`
    function _netFor(uint256 _target) internal pure returns (uint256) {
        return _target * (DECIMAL_PRECISION - FEE) / DECIMAL_PRECISION;
    }

    // Before the argument check, `x << 64` silently dropped the bits above 2^192, so a buy of
    // 2^192 + k tokens was priced like a buy of k tokens while minting all 2^192 + k of them.
    function testABDKBuyAboveTwoPow192Reverts() public {
        IBondingCurve bc = _setUpABDK(1000 ether);

        uint256 hugeNet = _netFor((1 << 192) + 1 ether);
        vm.expectRevert("ABDKMath: argument too large");
        bc.buy(hugeNet, type(uint256).max);
    }

    function testABDKPowRevertsForBaseAboveMaxArgument() public {
        IBondingCurve bc = _setUpABDK(1000 ether);

        vm.expectRevert("ABDKMath: argument too large");
        bc.pow((1 << 192) + 1 ether, 1.5 ether);
    }

    function testABDKPowRevertsForExponentAboveMaxArgument() public {
        IBondingCurve bc = _setUpABDK(1000 ether);

        vm.expectRevert("ABDKMath: argument too large");
        bc.pow(1 ether, (1 << 192) + 1 ether);
    }

    function testPRBBuyAboveTwoPow192Reverts() public {
        IBondingCurve bc = _setUpPRB(1000 ether);

        uint256 hugeNet = _netFor((1 << 192) + 1 ether);
        vm.expectRevert();
        bc.buy(hugeNet, type(uint256).max);
    }
}
