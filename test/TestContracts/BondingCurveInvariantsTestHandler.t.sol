pragma solidity 0.8.24;

import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";

import {IBondingCurve} from "src/Interfaces/IBondingCurve.sol";
import {ERC20Mock} from "./ERC20Mock.sol";
import {StringFormatting} from "../Utils/StringFormatting.sol";
import {BaseHandler} from "./BaseHandler.sol";

import {console2} from "forge-std/Test.sol";

contract BondingCurveInvariantsTestHandler is BaseHandler {
    using StringFormatting for uint256;
    using StringFormatting for int256;
    uint256 constant DECIMAL_PRECISION = 1e18;

    IBondingCurve bondingCurve;
    ERC20Mock reserveToken;
    address feeRouterAddress;

    uint256 public virtualSupply;

    constructor(IBondingCurve _bc) {
        bondingCurve = _bc;
        reserveToken = ERC20Mock(address(_bc.reserveToken()));
        feeRouterAddress = address(_bc.feeRouterAddress());
        reserveToken.approve(address(_bc), type(uint256).max);
        virtualSupply = _bc.virtualSupply();
    }

    function _logState() internal view {
        info("Bonding curve balances");
        info(
            "reserve = ",
            (bondingCurve.virtualBalance()).decimal(),
            ", token = ",
            (bondingCurve.virtualSupply()).decimal()
        );
        info("Current price = ", (bondingCurve.currentPrice()).decimal());
        info(
            "Floor: reserve = ",
            (bondingCurve.floorBalance()).decimal(),
            ", token = ",
            (bondingCurve.floorSupply()).decimal()
        );
        info("Floor price = ", (bondingCurve.floorPrice()).decimal());
        info("Handler balances");
        info(
            "reserve = ",
            (reserveToken.balanceOf(address(this))).decimal(),
            ", token = ",
            (bondingCurve.balanceOf(address(this))).decimal()
        );
    }

    function buy(uint256 _bcTokenAmount) external {
        // To avoid buys that return zero reserve tokens
        _bcTokenAmount = _bound(
            _bcTokenAmount,
            bondingCurve.virtualSupply() * 10 / DECIMAL_PRECISION,
            bondingCurve.virtualSupply() * 99999 / 100000
        );
        uint256 expectedBcTokenFeeAmount = bondingCurve.getBcTokenBuyFeeFromNet(_bcTokenAmount);
        uint256 expectedReserveAmount = bondingCurve.getBuyAmount(_bcTokenAmount + expectedBcTokenFeeAmount);
        vm.assume(expectedReserveAmount <= reserveToken.balanceOf(address(this)));

        _logState();

        //uint256 tokenAmount = bondingCurve.buy(_reserveAmount, 0);
        try bondingCurve.buy(_bcTokenAmount, type(uint256).max) returns (
            uint256 reserveAmount, uint256 bcTokenFeeAmount
        ) {
            virtualSupply += _bcTokenAmount + bcTokenFeeAmount;
            logCallWithTwoReturns("buy", _bcTokenAmount.decimal(), reserveAmount.decimal(), bcTokenFeeAmount.decimal());
            assertEq(reserveAmount, expectedReserveAmount, "Reserve amount mismatch");
            assertEq(bcTokenFeeAmount, expectedBcTokenFeeAmount, "BC token fee amount mismatch");
            //assertGt(tokenAmount, 0, "Should get tokens on buy");
        } catch Error(string memory reason) {
            // catch failing revert() and require()
            logCall("buy", _bcTokenAmount.decimal());
            info(reason);
            revert();
        } catch (bytes memory reason) {
            // catch failing assert()
            logCall("buy", _bcTokenAmount.decimal());
            console2.logBytes(reason);
            revert();
        }
    }

    function sell(uint256 _tokenAmount) external {
        // To avoid sales that return zero reserve tokens
        uint256 maxBound =
            Math.min(bondingCurve.virtualSupply() * 99999 / 100000, bondingCurve.balanceOf(address(this)));
        uint256 minBound = Math.min(bondingCurve.virtualSupply() * 10 / DECIMAL_PRECISION, maxBound);
        _tokenAmount = _bound(_tokenAmount, minBound, maxBound);
        vm.assume(_tokenAmount > 0);

        _logState();

        //uint256 reserveAmount = bondingCurve.sell(_tokenAmount, 0);
        try bondingCurve.sell(_tokenAmount, 0) returns (uint256 reserveAmount, uint256 tokenFeeAmount) {
            virtualSupply -= (_tokenAmount - tokenFeeAmount);
            logCallWithTwoReturns("sell", _tokenAmount.decimal(), reserveAmount.decimal(), tokenFeeAmount.decimal());
            //assertGt(reserveAmount, 0, "Should get reserve tokens on sell");
        } catch Error(string memory reason) {
            // catch failing revert() and require()
            logCall("sell", _tokenAmount.decimal());
            info(reason);
            revert();
        } catch (bytes memory reason) {
            // catch failing assert()
            logCall("sell", _tokenAmount.decimal());
            console2.logBytes(reason);
            revert();
        }
    }

    function floorSellAndBurn(uint256 _tokenAmount) external {
        // To avoid sales that return zero reserve tokens
        uint256 maxBound =
            Math.min(bondingCurve.virtualSupply() - bondingCurve.floorSupply(), bondingCurve.balanceOf(address(this)));
        uint256 minBound = Math.min(bondingCurve.virtualSupply() * 10 / DECIMAL_PRECISION, maxBound);
        _tokenAmount = _bound(_tokenAmount, minBound, maxBound);
        vm.assume(_tokenAmount > 0);

        _logState();

        assertTrue(bondingCurve.transfer(feeRouterAddress, _tokenAmount), "Transfer failed");
        vm.prank(feeRouterAddress);
        try bondingCurve.floorSellAndBurn(_tokenAmount) returns (uint256 reserveAmount) {
            logCallWithReturn("floorSellAndBurn", _tokenAmount.decimal(), reserveAmount.decimal());
            //assertGt(tokenAmount, 0, "Should get tokens on buy");
        } catch Error(string memory reason) {
            // catch failing revert() and require()
            logCall("floorSellAndBurn", _tokenAmount.decimal());
            info(reason);
            revert();
        } catch (bytes memory reason) {
            // catch failing assert()
            logCall("floorSellAndBurn", _tokenAmount.decimal());
            console2.logBytes(reason);
            revert();
        }
    }
}
