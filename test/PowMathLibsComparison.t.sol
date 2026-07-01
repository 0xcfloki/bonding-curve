pragma solidity ^0.8.0;

import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

import {IBondingCurve} from "src/Interfaces/IBondingCurve.sol";
import {ABDKBondingCurve} from "src/ABDKBondingCurve.sol";
import {PRBBondingCurve} from "src/PRBBondingCurve.sol";

import {BondingCurveBaseTest} from "./TestContracts/BondingCurveBaseTest.t.sol";

import {StringFormatting} from "./Utils/StringFormatting.sol";

import {console2} from "forge-std/Test.sol";
import {Test} from "forge-std/Test.sol";

contract PowMathLibs is BondingCurveBaseTest {
    using Strings for uint256;
    using StringFormatting for uint256;
    using StringFormatting for string;

    uint256 public constant DECIMAL_PRECISION = 1e18;
    uint256 public constant B = DECIMAL_PRECISION * 15 / 100;
    uint256 public constant B_PLUS_1 = B + 1 ether;
    uint256 public constant A = 0.19321899697342265 ether;

    uint256 public constant ABDK_VIRTUAL_BALANCE_MAX = 1549678864064168721285149826242827130;
    uint256 public constant ABDK_SUPPLY_PRICE_MAX = 9223372036854775807999999999999999999;
    uint256 public constant ABDK_SUPPLY_RR_MAX = 30989063942584025131852373177124152;

    uint256 public constant PRB_VIRTUAL_BALANCE_MAX =
        9727491886909253638568256650104378053485477408485367443158460542460905514151;
    uint256 public constant PRB_SUPPLY_PRICE_MAX =
        57896044618658097711785492504343953926634992332820282019728792003956564819967;
    uint256 public constant PRB_SUPPLY_RR_MAX = 181518550638961357240962399967812992070853126495805907086670726955007;

    IBondingCurve abdkBondingCurve;
    IBondingCurve prbBondingCurve;

    function setUp() public virtual override {
        super.setUp();

        abdkBondingCurve = _setUpABDK(A, B, 1, 1);
        prbBondingCurve = _setUpPRB(A, B, 1, 1);
    }

    // Base functions

    function _testPowForGetBuyBcTokenAmount(IBondingCurve _bc, uint256 _base) internal pure {
        _bc.pow(_base, DECIMAL_PRECISION * DECIMAL_PRECISION / B_PLUS_1);
    }

    function _testPowForGetBuyBcTokenAmountRevertsBeyondMax(IBondingCurve _bc, uint256 _base) internal {
        vm.expectRevert();
        _bc.pow(_base, DECIMAL_PRECISION * DECIMAL_PRECISION / B_PLUS_1);
    }

    function _testPowForGetPrice(IBondingCurve _bc, uint256 _supply) internal pure {
        _bc.pow(_supply, B);
    }

    function _testPowForGetPriceRevertsBeyondMax(IBondingCurve _bc, uint256 _supply) internal {
        vm.expectRevert();
        _bc.pow(_supply, B);
    }

    function _testPowForGetReserveRatio(IBondingCurve _bc, uint256 _supply) internal pure {
        _bc.pow(_supply, B_PLUS_1);
    }

    function _testPowForGetReserveRatioRevertsBeyondMax(IBondingCurve _bc, uint256 _supply) internal {
        vm.expectRevert();
        _bc.pow(_supply, B_PLUS_1);
    }

    // ABDK

    function testAbdkPowForGetBuyBcTokenAmount(uint256 _virtualBalance) public view {
        _testPowForGetBuyBcTokenAmount(abdkBondingCurve, ABDK_VIRTUAL_BALANCE_MAX * B_PLUS_1 / A);
        _virtualBalance = bound(_virtualBalance, 1, ABDK_VIRTUAL_BALANCE_MAX);
        _testPowForGetBuyBcTokenAmount(abdkBondingCurve, _virtualBalance * B_PLUS_1 / A);
    }

    function testAbdkPowForGetBuyBcTokenAmountRevertsBeyondMax() public {
        _testPowForGetBuyBcTokenAmountRevertsBeyondMax(abdkBondingCurve, (ABDK_VIRTUAL_BALANCE_MAX + 1) * B_PLUS_1 / A);
    }

    function testAbdkPowForGetPrice(uint256 _supply) public view {
        _testPowForGetPrice(abdkBondingCurve, ABDK_SUPPLY_PRICE_MAX);
        _supply = bound(_supply, 1, ABDK_SUPPLY_PRICE_MAX);
        _testPowForGetPrice(abdkBondingCurve, _supply);
    }

    function testAbdkPowForGetPriceRevertsBeyondMax() public {
        _testPowForGetPriceRevertsBeyondMax(abdkBondingCurve, ABDK_SUPPLY_PRICE_MAX + 1);
    }

    function testAbdkPowForGetReserveRatio(uint256 _supply) public view {
        _testPowForGetReserveRatio(abdkBondingCurve, ABDK_SUPPLY_RR_MAX);
        _supply = bound(_supply, 1, ABDK_SUPPLY_RR_MAX);
        _testPowForGetReserveRatio(abdkBondingCurve, _supply);
    }

    function testAbdkPowForGetReserveRatioRevertsBeyondMax() public {
        _testPowForGetReserveRatioRevertsBeyondMax(abdkBondingCurve, ABDK_SUPPLY_RR_MAX + 1);
    }

    // PRB

    function testPrbPowForGetBuyBcTokenAmount(uint256 _virtualBalance) public view {
        _testPowForGetBuyBcTokenAmount(prbBondingCurve, PRB_VIRTUAL_BALANCE_MAX / A * B_PLUS_1);
        _virtualBalance = bound(_virtualBalance, 1, PRB_VIRTUAL_BALANCE_MAX);
        _testPowForGetBuyBcTokenAmount(prbBondingCurve, _virtualBalance / A * B_PLUS_1);
    }

    /* TODO: Fix
    function testPrbPowForGetBuyBcTokenAmountRevertsBeyondMax() public {
        _testPowForGetBuyBcTokenAmountRevertsBeyondMax(prbBondingCurve, (PRB_VIRTUAL_BALANCE_MAX + 1) / A * B_PLUS_1);
    }
    */

    function testPrbPowForGetPrice(uint256 _supply) public view {
        _testPowForGetPrice(prbBondingCurve, PRB_SUPPLY_PRICE_MAX);
        _supply = bound(_supply, 1, PRB_SUPPLY_PRICE_MAX);
        _testPowForGetPrice(prbBondingCurve, _supply);
    }

    function testPrbPowForGetPriceRevertsBeyondMax() public {
        _testPowForGetPriceRevertsBeyondMax(prbBondingCurve, PRB_SUPPLY_PRICE_MAX + 1);
    }

    function testPrbPowForGetReserveRatio(uint256 _supply) public view {
        _testPowForGetReserveRatio(prbBondingCurve, PRB_SUPPLY_RR_MAX);
        _supply = bound(_supply, 1, PRB_SUPPLY_RR_MAX);
        _testPowForGetReserveRatio(prbBondingCurve, _supply);
    }

    function testPrbPowForGetReserveRatioRevertsBeyondMax() public {
        _testPowForGetReserveRatioRevertsBeyondMax(prbBondingCurve, PRB_SUPPLY_RR_MAX + 1);
    }

    // Error comparison
    function _testPowIterations(uint256 _max, uint256 _exp, uint256 _iterations, string memory _fileName) public {
        if (vm.exists(_fileName)) vm.removeFile(_fileName);

        // We split it in blocks
        // numbers below 1(e18)
        _testPowIterationsLoop(_exp, 1, 1e18, _iterations, _fileName);
        // numbers from 1 to 1M
        _testPowIterationsLoop(_exp, 1e18, 1e24, _iterations, _fileName);
        // numbers from 1M to 1B
        _testPowIterationsLoop(_exp, 1e24, 1e27, _iterations, _fileName);
        // numbers from 1B to max
        _testPowIterationsLoop(_exp, 1e27, _max, _iterations, _fileName);

        // Do also the max
        _writeToFile(_fileName, _max, abdkBondingCurve.pow(_max, _exp), prbBondingCurve.pow(_max, _exp));
    }

    function _testPowIterationsLoop(
        uint256 _exp,
        uint256 _min,
        uint256 _max,
        uint256 _iterations,
        string memory _fileName
    ) public {
        uint256 ra;
        uint256 rp;

        uint256 step = (_max - _min) / _iterations;
        for (uint256 i = 0; i < _iterations; i++) {
            uint256 x = _min + i * step;
            ra = abdkBondingCurve.pow(x, _exp);
            rp = prbBondingCurve.pow(x, _exp);
            _writeToFile(_fileName, x, ra, rp);
        }
    }

    function testPowForGetBuyBcTokenAmountIterations() public {
        uint256 exp = DECIMAL_PRECISION * DECIMAL_PRECISION / B_PLUS_1;
        uint256 max = ABDK_VIRTUAL_BALANCE_MAX * B_PLUS_1 / A;
        uint256 iterations = 1000;
        string memory fileName = "bc_buy_bc_tokens.csv";

        _testPowIterations(max, exp, iterations, fileName);
    }

    function testPowForGetPriceIterations() public {
        uint256 exp = B;
        uint256 max = ABDK_SUPPLY_PRICE_MAX;
        uint256 iterations = 1000;
        string memory fileName = "bc_price.csv";

        _testPowIterations(max, exp, iterations, fileName);
    }

    function testPowForGetReserveRatioIterations() public {
        uint256 exp = B_PLUS_1;
        uint256 max = ABDK_SUPPLY_RR_MAX;
        uint256 iterations = 1000;
        string memory fileName = "bc_rr.csv";

        _testPowIterations(max, exp, iterations, fileName);
    }

    // Helpers

    function _testGetBoundsBinary(IBondingCurve _bc, uint256 min, uint256 max, uint256 exp) public returns (uint256) {
        console2.log("checking min");
        console2.log(min, "min");
        _bc.pow(min, exp);
        console2.log("checking max");
        console2.log(max, "max");
        vm.expectRevert();
        _bc.pow(max, exp);
        uint256 i;
        while (min < max - 1 && i < 100) {
            //uint256 x = (min + max) / 2;
            // To avoid overflows
            uint256 diff = max - min;
            uint256 x = min + diff / 2;
            //console2.log(x, "x");
            try _bc.pow(x, exp) {
                //console2.log(x, "worked, new min");
                min = x;
            } catch Error(string memory) {
                //console2.log(x, "reverted 1, new max");
                max = x;
            } catch (bytes memory) {
                //console2.log(x, "reverted 2, new max");
                max = x;
            }
            i++;
            //console2.log(i, "i");
        }
        console2.log(min, "min");
        console2.log(max, "max");

        return min;
    }

    function testAbdkGetBoundsBinary1() public {
        uint256 min = 9223372036854775807999999999994800188;
        uint256 max = 9223372036854775808000000000002051700;
        uint256 x = _testGetBoundsBinary(abdkBondingCurve, min, max, DECIMAL_PRECISION * DECIMAL_PRECISION / B_PLUS_1);
        console2.log(x * A / B_PLUS_1, "x ");
    }

    function testAbdkGetBoundsBinary2() public {
        uint256 min = 9223372036854775807999999999987512007;
        uint256 max = 9223372036854775808000000000002051700;
        _testGetBoundsBinary(abdkBondingCurve, min, max, B);
    }

    function testAbdkGetBoundsBinary3() public {
        uint256 min = 30989063942584025131852373177108685;
        uint256 max = 30989063942584025131852373177136801;
        _testGetBoundsBinary(abdkBondingCurve, min, max, B_PLUS_1);
    }

    function testPrbGetBoundsBinary1() public {
        uint256 min = 57896044618658097711785492504343953926634992332820282019728757288841211502032;
        uint256 max = 57896044618658097711785492504343953926634992332820282019728819518993990113449;
        uint256 x = _testGetBoundsBinary(prbBondingCurve, min, max, DECIMAL_PRECISION * DECIMAL_PRECISION / B_PLUS_1);
        console2.log(x / B_PLUS_1 * A, "x ");
    }

    function testPrbGetBoundsBinary2() public {
        uint256 min = 57896044618658097711785492504343953926634992332820282019728757288841208433419;
        uint256 max = 57896044618658097711785492504343953926634992332820282019728819518993987044836;
        _testGetBoundsBinary(prbBondingCurve, min, max, B);
    }

    function testPrbGetBoundsBinary3() public {
        uint256 min = 181518550638961357240962399967812992070853126495805907086667236687499;
        uint256 max = 181518550638961357240962399967812992070853126495805907086673459702777;
        _testGetBoundsBinary(prbBondingCurve, min, max, B_PLUS_1);
    }

    function _decimal(uint256 n) internal pure returns (string memory) {
        if (n == 0) return "0";
        //if (n == type(uint256).max) return "type(uint256).max";

        uint256 one = 10 ** 18;
        uint256 integerPart = n / one;
        uint256 fractionalPart = n % one;

        return string.concat(integerPart.toString(), ".", (one + fractionalPart).toString().slice(1));
    }

    function _writeToFile(string memory fileName, uint256 _x1, uint256 _x2, uint256 _x3) internal {
        /// forge-lint: disable-next-line(unsafe-cheatcode)
        vm.writeLine(fileName, string.concat(_decimal(_x1), ",", _decimal(_x2), ",", _decimal(_x3)));
    }
}
