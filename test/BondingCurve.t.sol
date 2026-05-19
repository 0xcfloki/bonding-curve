// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {DECIMAL_PRECISION} from "src/Constants.sol";

import {BondingCurveBaseTest, IBondingCurve} from "./TestContracts/BondingCurveBaseTest.t.sol";

import {console2} from "forge-std/Test.sol";

contract BondingCurveTest is BondingCurveBaseTest {
    function _testPow(IBondingCurve _bc) internal pure {
        console2.log(" -- pow --");

        // min
        console2.log("");
        console2.log("min");
        /*
         * y log x >= -59.8e18 (from log_2 min uint test), y < 2e18
         * log x >= -29.8
         * x >= 1e18 * 2^2.2 / 2^32
         */
        uint256 minX = 1e18 * 436 / 100 / uint256(1 << 32);
        uint256 minY = 2e18 - 1;
        console2.log(minX, "minX");
        uint256 minP = _bc.pow(minX, minY);
        console2.log(minP, "minP");
        assertGt(minP, 0, "Reached product zero");

        // max
        console2.log("");
        console2.log("max");
        /*
         * y log x <= 63e18 - 1, y < 2e18
         * log x <= (63e18 - 1) / 2e18 ~= 31.5
         * x <= 2^(31.5) = 2^32 / 2^(1/2) <= 2^32 / 1.4143
         */
        uint256 maxX = uint256(1 << 32) * 10000 / 14143 * 1e18;
        uint256 maxY = 2e18 - 1;
        console2.log(maxX, "maxX");
        uint256 maxP = _bc.pow(maxX, maxY);
        console2.log(maxP, "maxP");
    }

    function _testFuzzPow(IBondingCurve _bc, uint256 x, uint256 y) internal pure {
        // (1, 2 ^32)
        x = bound(x, 1e18 * 436 / 100 / uint256(1 << 32), uint256(1 << 32) * 10000 / 14143 * 1e18);
        // (1e18, 2e18)
        y = bound(y, 1e18 + 1, 2e18 - 1);

        console2.log(x, "x");
        console2.log(y, "y");

        uint256 p = _bc.pow(x, y);
        assertGt(p, 0, "Reached product zero");
    }

    /* beta = 0.5 => B_PLUS_1 = 1.5
     * y log x >= -59.8e18 (from log_2 min uint test), y < 1.5e18
     * log x >= -39.89
     * x >= 1e18 / 2^39
     */
    function _getMinSupply(uint256 _beta) internal pure returns (uint256) {
        uint256 y = _beta + DECIMAL_PRECISION;
        uint256 d = 59.8 ether / y;
        return 1e18 / (uint256(1) << d);
    }

    /* beta = 0.5 => B_PLUS_1 = 1.5
     * y log x <= 63e18 - 1, y < 1.5e18
     * log x <= (63e18 - 1) / 1.5e18 = 42
     * x <= 2^42
     */
    function _getMaxSupply(uint256 _beta) internal pure returns (uint256) {
        uint256 y = _beta + DECIMAL_PRECISION;
        uint256 e = (63e18 - 1) / y;
        return (uint256(1) << e) * DECIMAL_PRECISION;
    }

    function _testPowFixedBeta(IBondingCurve _bc) internal view {
        uint256 y = _bc.B() + DECIMAL_PRECISION;
        console2.log(" -- pow, beta: ", _bc.B());

        // min
        console2.log("");
        console2.log("min");
        uint256 minX = _getMinSupply(_bc.B());
        console2.log(minX, "minX");
        uint256 minP = _bc.pow(minX, y);
        console2.log(minP, "minP");
        assertGt(minP, 0, "Reached product zero");

        // max
        console2.log("");
        console2.log("max");
        uint256 maxX = _getMaxSupply(_bc.B());
        console2.log(maxX, "maxX");
        uint256 maxP = _bc.pow(maxX, y);
        console2.log(maxP, "maxP");
    }

    function _testFuzzPowFixedBeta(IBondingCurve _bc, uint256 x) internal view {
        uint256 y = _bc.B() + DECIMAL_PRECISION;

        uint256 d = 59.8 ether / y;
        uint256 e = (63e18 - 1) / y;
        x = bound(x, 1e18 / (uint256(1) << d), (uint256(1) << e) * DECIMAL_PRECISION);

        //console2.log(x, "x");

        uint256 p = _bc.pow(x, y);
        assertGt(p, 0, "Reached product zero");
    }

    struct TestVars {
        uint256 initialSupply;
        uint256 initialFloorSupply;
        uint256 initialBalance;
        uint256 initialFloorBalance;
        uint256 initialBcTokenAmount;
        uint256 initialReserveAmount;
        uint256 initialBurnRecipientReserveBalance;
        uint256 totalBcTokenFeeAmount;
        uint256 totalBcTokenBurnAmount;
        uint256 totalBcTokenLeakAmount;
        uint256 totalReserveFeeAmount;
        uint256 totalReserveBoughtAmount;
        uint256 totalReserveBurnAmount;
        uint256 totalReserveLeakAmount; // includes fee and burn amounts
    }

    function _testSimple(
        IBondingCurve _bc,
        uint256 _runs,
        uint256 _maxTokenDeviation,
        uint256 _maxReserveDeviation,
        uint256 _rrDeviation
    ) internal {
        console2.log("-- before --");
        logState(_bc);
        logDeviation(_bc);

        TestVars memory vars;
        vars.initialBcTokenAmount = 500 ether;
        vars.initialReserveAmount = _bc.getBuyAmountFromNet(vars.initialBcTokenAmount);

        // buy
        (uint256 reserveAmount, uint256 tokenBuyFeeAmount) = _bc.buy(vars.initialBcTokenAmount, type(uint256).max);
        uint256 bcTokenAmount = vars.initialBcTokenAmount;
        vars.totalBcTokenFeeAmount += tokenBuyFeeAmount;
        uint256 tokenSellFeeAmount;
        for (uint256 i = 0; i < _runs; i++) {
            // sell
            (reserveAmount, tokenSellFeeAmount) = _bc.sell(bcTokenAmount, 0);
            vars.totalBcTokenFeeAmount += tokenSellFeeAmount;
            vars.totalBcTokenLeakAmount += tokenSellFeeAmount;
            vars.totalReserveLeakAmount += _bc.getSellAmount(tokenBuyFeeAmount + tokenSellFeeAmount);
            bcTokenAmount -= tokenSellFeeAmount;
            // buy
            (reserveAmount, tokenBuyFeeAmount) = _bc.buy(bcTokenAmount, type(uint256).max);
            vars.totalBcTokenFeeAmount += tokenBuyFeeAmount;
            vars.totalReserveLeakAmount -= _bc.getSellAmount(tokenBuyFeeAmount);
        }
        // sell
        (reserveAmount, tokenSellFeeAmount) = _bc.sell(bcTokenAmount, 0);
        vars.totalReserveLeakAmount += _bc.getSellAmount(tokenBuyFeeAmount + tokenSellFeeAmount);

        console2.log("-- after --");
        logState(_bc);
        logDeviation(_bc);

        assertApproxEqAbs(
            vars.initialBcTokenAmount,
            bcTokenAmount + vars.totalBcTokenLeakAmount,
            _maxTokenDeviation,
            "Too much token deviation"
        );
        assertApproxEqAbs(
            vars.initialReserveAmount,
            reserveAmount + vars.totalReserveLeakAmount,
            _maxReserveDeviation,
            "Too much reserve deviation"
        );
        assertTrue(_bc.checkCurrentDeviation(_rrDeviation), "Too much reserve ratio deviation");
        // Let's add the last sell fee
        vars.totalBcTokenFeeAmount += tokenSellFeeAmount;
        assertEq(vars.totalBcTokenFeeAmount, _bc.balanceOf(feeRouterAddress), "Fee recipient token balance mismatch");
    }

    function _testSlippage(IBondingCurve _bc, uint256 _maxReserveBuyAmount, uint256 _minReserveSellAmount) internal {
        uint256 initialBcTokenAmount = 500 ether;
        // Reverts with a huge min number
        vm.expectRevert("Max amount surpassed");
        _bc.buy(initialBcTokenAmount, 0);

        // Buy reverts with just 1 wei more
        vm.expectRevert("Max amount surpassed");
        _bc.buy(initialBcTokenAmount, _maxReserveBuyAmount - 1);

        // Buy works with the exact amount
        (uint256 reserveBuyAmount,) = _bc.buy(initialBcTokenAmount, _maxReserveBuyAmount);
        assertEq(reserveBuyAmount, _maxReserveBuyAmount);

        // Sell reverts with a huge min number
        vm.expectRevert("Min amount not reached");
        _bc.sell(initialBcTokenAmount, type(uint256).max);

        // Sell reverts with just 1 wei more
        vm.expectRevert("Min amount not reached");
        _bc.sell(initialBcTokenAmount, _minReserveSellAmount + 1);

        // Sell works with the exact amount
        (uint256 reserveSellAmount,) = _bc.sell(initialBcTokenAmount, _minReserveSellAmount);
        assertEq(reserveSellAmount, _minReserveSellAmount);
    }

    function _testBuyEquivalency(IBondingCurve _bc, uint256 _reserveAmount) internal {
        _reserveAmount = bound(_reserveAmount, 0.001 ether, 1e6 ether);

        // inexact buy
        (uint256 bcTokenAmount1, uint256 reserveLeftover) = _bc.getBuyBcTokenAmountFromReserve(_reserveAmount);
        uint256 finalReserveAmount1 = _reserveAmount - reserveLeftover;
        uint256 bcTokenFeeAmount1 = _bc.getBcTokenBuyFee(bcTokenAmount1);

        // exact output buy
        (uint256 reserveAmount2, uint256 bcTokenFeeAmount2) =
            _bc.buy(bcTokenAmount1 - bcTokenFeeAmount1, type(uint256).max);

        // checks (error introduced by fee)
        assertApproxEqAbs(finalReserveAmount1, reserveAmount2, 1e5, "Reserve amount mismatch");
        assertApproxEqAbs(bcTokenFeeAmount1, bcTokenFeeAmount2, 1, "Fee amount mismatch");
    }

    function _testFloorSellAndBurn(
        IBondingCurve _bc,
        uint256 _runs,
        uint256 _maxTokenDeviation,
        uint256 _maxReserveDeviation,
        uint256 _rrDeviation
    ) internal {
        TestVars memory vars;
        vars.initialSupply = _bc.virtualSupply();
        vars.initialFloorSupply = _bc.floorSupply();
        vars.initialFloorBalance = _bc.floorBalance();
        vars.initialBurnRecipientReserveBalance = reserveToken.balanceOf(feeRouterAddress);
        vars.initialBcTokenAmount = 500 ether;
        vars.initialReserveAmount = _bc.getBuyAmountFromNet(vars.initialBcTokenAmount);

        // buy
        (uint256 reserveAmount, uint256 tokenBuyFeeAmount) = _bc.buy(vars.initialBcTokenAmount, type(uint256).max);
        uint256 bcTokenAmount = vars.initialBcTokenAmount;
        vars.totalBcTokenFeeAmount += tokenBuyFeeAmount;
        uint256 tokenSellFeeAmount;
        uint256 floorSellAndBurnAmount;
        for (uint256 i = 0; i < _runs; i++) {
            // sell
            floorSellAndBurnAmount = bcTokenAmount / 10;
            vars.totalBcTokenBurnAmount += floorSellAndBurnAmount;
            bcTokenAmount -= floorSellAndBurnAmount;
            (reserveAmount, tokenSellFeeAmount) = _bc.sell(bcTokenAmount, 0);
            vars.totalBcTokenFeeAmount += tokenSellFeeAmount;
            vars.totalBcTokenLeakAmount += tokenSellFeeAmount;
            bcTokenAmount -= tokenSellFeeAmount;
            vars.totalReserveLeakAmount += _bc.getSellAmount(
                tokenBuyFeeAmount + tokenSellFeeAmount + floorSellAndBurnAmount
            );

            // floor sell and burn
            if (floorSellAndBurnAmount > 0) {
                // Send Reserve tokens to burn recipient if needed
                uint256 feeRouterBalance = _bc.balanceOf(feeRouterAddress);
                if (floorSellAndBurnAmount > feeRouterBalance) {
                    assertTrue(
                        _bc.transfer(feeRouterAddress, floorSellAndBurnAmount - feeRouterBalance), "Transfer failed"
                    );
                }
                vm.prank(feeRouterAddress);
                uint256 reserveBurnAmount = _bc.floorSellAndBurn(floorSellAndBurnAmount);
                vars.totalReserveBurnAmount += reserveBurnAmount;
            }

            // buy
            (reserveAmount, tokenBuyFeeAmount) = _bc.buy(bcTokenAmount, type(uint256).max);
            vars.totalBcTokenFeeAmount += tokenBuyFeeAmount;
            vars.totalReserveLeakAmount -= _bc.getSellAmount(tokenBuyFeeAmount);
        }

        // sell
        (reserveAmount, tokenSellFeeAmount) = _bc.sell(bcTokenAmount, 0);
        vars.totalReserveLeakAmount += _bc.getSellAmount(tokenBuyFeeAmount + tokenSellFeeAmount);
        // Let's add the last sell fee
        vars.totalBcTokenFeeAmount += tokenSellFeeAmount;

        assertEq(
            vars.totalReserveBurnAmount,
            reserveToken.balanceOf(feeRouterAddress) - vars.initialBurnRecipientReserveBalance,
            "Burn recipient reserve balance mismatch"
        );

        //console2.log(reserveToken.balanceOf(feeRouterAddress), "reserveToken.balanceOf(feeRouterAddress)");
        assertApproxEqAbs(
            vars.initialBcTokenAmount,
            bcTokenAmount + vars.totalBcTokenLeakAmount + vars.totalBcTokenBurnAmount,
            _maxTokenDeviation,
            "Too much token deviation"
        );
        assertApproxEqAbs(
            vars.initialReserveAmount,
            reserveAmount + vars.totalReserveLeakAmount,
            _maxReserveDeviation,
            "Too much reserve deviation"
        );

        assertApproxEqAbs(
            _bc.virtualSupply(),
            vars.initialSupply + vars.totalBcTokenBurnAmount + vars.totalBcTokenFeeAmount,
            _maxTokenDeviation,
            "Wrong supply"
        );
        assertEq(_bc.floorSupply(), vars.initialFloorSupply + vars.totalBcTokenBurnAmount, "Wrong floor supply");
        assertEq(_bc.floorBalance(), vars.initialFloorBalance + vars.totalReserveBurnAmount, "Wrong floor balance");

        assertTrue(_bc.checkCurrentDeviation(_rrDeviation), "Too much reserve ratio deviation");

        // TODO
        //assertEq(_bc.balanceOf(feeRouterAddress), TODO, "Fee router token balance mismatch");
        //assertEq(vars.totalReserveBurnAmount, TODO, "Burn recipient reserve balance mismatch");
    }

    function _testFuzzBuy(IBondingCurve _bc, uint256 _x) internal {
        _bc.buy(_x, type(uint256).max);

        assertTrue(_bc.checkCurrentDeviation(), "Too much reserve ratio deviation");
    }

    function _testFuzzSell(IBondingCurve _bc, uint256 _x) internal {
        _bc.sell(_x, 0);

        assertTrue(_bc.checkCurrentDeviation(), "Too much reserve ratio deviation");
    }

    function _boundSupply(uint256 _beta, uint256 _initialVirtualSupply, uint256 _minMultiplier)
        internal
        pure
        returns (uint256)
    {
        return bound(_initialVirtualSupply, _getMinSupply(_beta) * _minMultiplier, _getMaxSupply(_beta));
    }

    // -- ABDK --

    function testABDKThirdPartyCannotCallBondingCurvePermissionedTransferFunction() public {
        address borrower1 = makeAddr("borrower1");
        address borrower2 = makeAddr("borrower2");
        IBondingCurve abdkBondingCurve = _setUpABDK(1000 ether);

        vm.startPrank(borrower1);

        vm.expectRevert("BC: Not allowed");
        abdkBondingCurve.permissionedTransferFrom(borrower2, borrower1, 1);

        vm.stopPrank();
    }

    function testABDKPow() public {
        IBondingCurve abdkBondingCurve = _setUpABDK(1000 ether);

        _testPow(abdkBondingCurve);
    }

    function testABDKFuzzPow(uint256 x, uint256 y) public {
        IBondingCurve abdkBondingCurve = _setUpABDK(1000 ether);

        _testFuzzPow(abdkBondingCurve, x, y);
    }

    function testABDKPowFixedBeta() public {
        IBondingCurve abdkBondingCurve = _setUpABDK(1000 ether);

        _testPowFixedBeta(abdkBondingCurve);
    }

    function testABDKFuzzPowFixedBeta(uint256 x) public {
        IBondingCurve abdkBondingCurve = _setUpABDK(1000 ether);

        _testFuzzPowFixedBeta(abdkBondingCurve, x);
    }

    function testABDKSimple() public {
        IBondingCurve abdkBondingCurve = _setUpABDK(1000 ether);

        _testSimple(abdkBondingCurve, 10000, 2e7, 0, 0);
    }

    function testABDKSlippage() public {
        IBondingCurve abdkBondingCurve = _setUpABDK(1000 ether);

        _testSlippage(abdkBondingCurve, 35315340200259562422341, 35283705559513758316261);
    }

    function testABDKBuyEquivalency(uint256 _reserveAmount) public {
        IBondingCurve abdkBondingCurve = _setUpABDK(1000 ether);

        _testBuyEquivalency(abdkBondingCurve, _reserveAmount);
    }

    function testABDKBuyEquivalencyReplay() public {
        IBondingCurve abdkBondingCurve = _setUpABDK(1000 ether);

        _testBuyEquivalency(abdkBondingCurve, 999999999000419341825099);
    }

    function testABDKFloorSellAndBurn() public {
        IBondingCurve abdkBondingCurve = _setUpABDK(1000 ether);

        _testFloorSellAndBurn(abdkBondingCurve, 100, 2e7, 1e7, 0);
    }

    function testABDKFuzzBuy(uint256 _initialVirtualSupply, uint256 _x) public {
        uint256 alpha = 2 ether;
        uint256 beta = 0.5 ether;
        _initialVirtualSupply = _boundSupply(beta, _initialVirtualSupply, 2); // we double the min to allow for half floor
        uint256 initialFloorSupply = _initialVirtualSupply / 2;

        IBondingCurve abdkBondingCurve = _setUpABDK(alpha, beta, _initialVirtualSupply, initialFloorSupply);

        _x = bound(_x, Math.max(1e6, Math.min(1 ether, abdkBondingCurve.virtualBalance() / 100000)), 1e6 ether);

        _testFuzzBuy(abdkBondingCurve, _x);
    }

    function testABDKFuzzSell(uint256 _initialVirtualSupply, uint256 _x) public {
        uint256 alpha = 2 ether;
        uint256 beta = 0.5 ether;
        _initialVirtualSupply = _boundSupply(beta, _initialVirtualSupply, 2); // we double the min to allow for half floor
        uint256 initialFloorSupply = _initialVirtualSupply / 2;

        IBondingCurve abdkBondingCurve = _setUpABDK(alpha, beta, _initialVirtualSupply, initialFloorSupply);

        _x = bound(_x, 1, (_initialVirtualSupply - initialFloorSupply) * 99999 / 100000);

        _testFuzzSell(abdkBondingCurve, _x);
    }

    function testABDKFuzzDeploy(uint256 _alpha, uint256 _beta, uint256 _initialVirtualSupply) public {
        _alpha = bound(_alpha, 1, 1e6 ether);
        _beta = bound(_beta, 1, 1e18 - 1);
        _initialVirtualSupply = bound(_initialVirtualSupply, 0.0001 ether, 1e6 ether);
        uint256 initialFloorSupply = _initialVirtualSupply / 2;

        _setUpABDK(_alpha, _beta, _initialVirtualSupply, initialFloorSupply);
    }

    // -- PRB --

    function testPRBThirdPartyCannotCallBondingCurvePermissionedTransferFunction() public {
        address borrower1 = makeAddr("borrower1");
        address borrower2 = makeAddr("borrower2");
        IBondingCurve prbBondingCurve = _setUpPRB(1000 ether);

        vm.startPrank(borrower1);

        vm.expectRevert("BC: Not allowed");
        prbBondingCurve.permissionedTransferFrom(borrower2, borrower1, 1);

        vm.stopPrank();
    }

    function testPRBPow() public {
        IBondingCurve prbBondingCurve = _setUpPRB(1000 ether);

        _testPow(prbBondingCurve);
    }

    function testPRBFuzzPow(uint256 x, uint256 y) public {
        IBondingCurve prbBondingCurve = _setUpPRB(1000 ether);

        _testFuzzPow(prbBondingCurve, x, y);
    }

    function testPRBPowFixedBeta() public {
        IBondingCurve prbBondingCurve = _setUpPRB(1000 ether);

        _testPowFixedBeta(prbBondingCurve);
    }

    function testPRBFuzzPowFixedBeta(uint256 x) public {
        IBondingCurve prbBondingCurve = _setUpPRB(1000 ether);

        _testFuzzPowFixedBeta(prbBondingCurve, x);
    }

    function testPRBSimple() public {
        IBondingCurve prbBondingCurve = _setUpPRB(1000 ether);

        _testSimple(prbBondingCurve, 10000, 1e9, 0, 0);
    }

    function testPRBSlippage() public {
        IBondingCurve prbBondingCurve = _setUpPRB(1000 ether);

        _testSlippage(prbBondingCurve, 35315340200259561979842, 35283705559513757805398);
    }

    function testPRBBuyEquivalency(uint256 _reserveAmount) public {
        IBondingCurve prbBondingCurve = _setUpPRB(1000 ether);

        _testBuyEquivalency(prbBondingCurve, _reserveAmount);
    }

    function testPRBFloorSellAndBurn() public {
        IBondingCurve prbBondingCurve = _setUpPRB(1000 ether);

        _testFloorSellAndBurn(prbBondingCurve, 100, 1e9, 1e12, 0);
    }

    function testPRBFuzzBuy(uint256 _initialVirtualSupply, uint256 _x) public {
        uint256 alpha = 2 ether;
        uint256 beta = 0.5 ether;
        _initialVirtualSupply = _boundSupply(beta, _initialVirtualSupply, 2); // we double the min to allow for half floor
        uint256 initialFloorSupply = _initialVirtualSupply / 2;

        IBondingCurve prbBondingCurve = _setUpPRB(alpha, beta, _initialVirtualSupply, initialFloorSupply);

        _x = bound(_x, Math.max(1e6, Math.min(1 ether, prbBondingCurve.virtualBalance() / 100000)), 1e6 ether);

        _testFuzzBuy(prbBondingCurve, _x);
    }

    function testPRBFuzzSell(uint256 _initialVirtualSupply, uint256 _x) public {
        uint256 alpha = 2 ether;
        uint256 beta = 0.5 ether;
        _initialVirtualSupply = _boundSupply(beta, _initialVirtualSupply, 2); // we double the min to allow for half floor
        uint256 initialFloorSupply = _initialVirtualSupply / 2;
        //_x = bound(_x, 1, (_initialVirtualSupply - initialFloorSupply));
        _x = bound(_x, 1, (_initialVirtualSupply - initialFloorSupply) * 99999 / 100000);

        IBondingCurve prbBondingCurve = _setUpPRB(alpha, beta, _initialVirtualSupply, initialFloorSupply);

        _testFuzzSell(prbBondingCurve, _x);
    }

    function testPRBFuzzDeploy(uint256 _alpha, uint256 _beta, uint256 _initialVirtualSupply) public {
        _alpha = bound(_alpha, 1, 1e6 ether);
        _beta = bound(_beta, 1, 1e18 - 1);
        _initialVirtualSupply = bound(_initialVirtualSupply, 0.0001 ether, 1e6 ether);
        uint256 initialFloorSupply = _initialVirtualSupply / 2;

        _setUpPRB(_alpha, _beta, _initialVirtualSupply, initialFloorSupply);
    }

    // forge-lint: disable-end(mixed-case-function)
}
