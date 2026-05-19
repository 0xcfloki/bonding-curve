pragma solidity ^0.8.24;

import {BondingCurveInvariantsBaseTest} from "./TestContracts/BondingCurveInvariantsBaseTest.t.sol";
// import {console2} from "forge-std/Test.sol";

contract BondingCurveInvariants is BondingCurveInvariantsBaseTest {
    function invariant_ReserveRatio() external view {
        //assertTrue(bondingCurve.checkCurrentDeviation(0), "Too much reserve ratio deviation");
        assertEq(bondingCurve.reserveRatioDeviation(), 0, "Too much reserve ratio deviation");
    }

    function invariant_FloorReserveRatio() external view {
        assertEq(
            bondingCurve.reserveRatioDeviation(bondingCurve.floorSupply(), bondingCurve.floorBalance()),
            0,
            "Too much reserve ratio deviation"
        );
    }

    function invariant_NonZeroBalances() external view {
        assertGt(bondingCurve.virtualSupply(), 0, "Zero virtual supply");
        assertGt(bondingCurve.virtualBalance(), 0, "Zero virtual balance");
        assertGt(bondingCurve.floorSupply(), 0, "Zero floor supply");
        assertGt(bondingCurve.floorBalance(), 0, "Zero floor balance");

        (uint256 totalBalance, uint256 totalSupply) = bondingCurve.getBalanceAndSupply();
        //console2.log(totalBalance, "totalBalance");
        //console2.log(totalSupply, "totalSupply");
        if (totalBalance == 0) {
            // TODO: Can we make this abs zero?
            assertLt(totalSupply, 1000, "Zero total bal should mean (almost) zero total supply");
        }
        if (totalSupply == 0) {
            assertEq(totalBalance, 0, "Zero total supply should mean zero total bal");
        }

        // TODO: Should we enforce a minimum, as a defensive measure, like in the SP?
        // Or is it fine if floor and virtual supply are exactly the same?
        //assertGt(bondingCurve.totalSupply(), 0, "Zero total supply");
    }

    function invariant_TokenBalances() external view {
        assertEq(
            bondingCurve.totalSupply(), bondingCurve.virtualSupply() - bondingCurve.floorSupply(), "Wrong token supply"
        );
        assertEq(bondingCurve.virtualSupply(), handler.virtualSupply(), "Wrong virtual supply");
        assertEq(
            bondingCurve.totalSupply(),
            bondingCurve.balanceOf(address(handler)) + bondingCurve.balanceOf(feeRouterAddress),
            "Wrong total balances"
        );
        assertEq(
            reserveToken.balanceOf(address(bondingCurve)),
            bondingCurve.totalBalance(), // equals to: bondingCurve.virtualBalance() - bondingCurve.floorBalance(),
            "Wrong reserve balance"
        );
        assertEq(reserveToken.balanceOf(feeRouterAddress), bondingCurve.floorBalance(), "Wrong reserve floor balance");
    }
}
