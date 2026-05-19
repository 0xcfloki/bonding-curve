pragma solidity ^0.8.0;

import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import {IBondingCurve} from "src/Interfaces/IBondingCurve.sol";
import {ABDKBondingCurve} from "src/ABDKBondingCurve.sol";
import {PRBBondingCurve} from "src/PRBBondingCurve.sol";
import {DECIMAL_PRECISION, ONE_YEAR} from "src/Constants.sol";

import {ERC20Mock} from "./ERC20Mock.sol";

import {Test, console2} from "forge-std/Test.sol";

contract BondingCurveBaseTest is Test {
    using SafeERC20 for ERC20Mock;

    uint256 constant MIN_REWARD_RATE_PERCENTAGE = DECIMAL_PRECISION / 100 / ONE_YEAR; // 1% year
    uint256 constant MAX_REWARD_PERIOD = 4 weeks;

    ERC20Mock reserveToken;
    address feeRouterAddress;

    function setUp() public virtual {
        reserveToken = new ERC20Mock("WETH", "WETH");
        reserveToken.mint(address(this), 1e24 ether);
    }

    function _setUpABDK(uint256 _initialVirtualSupply) internal returns (IBondingCurve) {
        return _setUpABDK(2 ether, 0.5 ether, _initialVirtualSupply, _initialVirtualSupply / 2);
    }

    function _setUpABDK(uint256 _initialVirtualSupply, uint256 _initialFloorSupply) internal returns (IBondingCurve) {
        return _setUpABDK(2 ether, 0.5 ether, _initialVirtualSupply, _initialFloorSupply);
    }

    function _setUpABDK(uint256 _alpha, uint256 _beta, uint256 _initialVirtualSupply, uint256 _initialFloorSupply)
        internal
        returns (IBondingCurve)
    {
        feeRouterAddress = makeAddr("FeeRouter");

        // Compute address to be able to approve
        IBondingCurve.ConstructorParams memory params = IBondingCurve.ConstructorParams({
            alpha: _alpha,
            beta: _beta,
            feePercentage: 5e14, // 0.05%
            reserveToken: reserveToken,
            name: "ADBK token",
            symbol: "TKN",
            initializerAccount: address(this),
            feeRouterAddress: feeRouterAddress,
            reserveLoansManagerAddress: address(1),
            bondingCurveTokenSplitterAddress: address(1)
        });

        IBondingCurve abdkBondingCurve = new ABDKBondingCurve(params);
        reserveToken.approve(address(abdkBondingCurve), type(uint256).max);
        abdkBondingCurve.init(_initialVirtualSupply, _initialFloorSupply, 0);

        return abdkBondingCurve;
    }

    function _setUpPRB(uint256 _initialVirtualSupply) internal returns (IBondingCurve) {
        return _setUpPRB(2 ether, 0.5 ether, _initialVirtualSupply, _initialVirtualSupply / 2);
    }

    function _setUpPRB(uint256 _initialVirtualSupply, uint256 _initialFloorSupply) internal returns (IBondingCurve) {
        return _setUpPRB(2 ether, 0.5 ether, _initialVirtualSupply, _initialFloorSupply);
    }

    function _setUpPRB(uint256 _alpha, uint256 _beta, uint256 _initialVirtualSupply, uint256 _initialFloorSupply)
        internal
        returns (IBondingCurve)
    {
        feeRouterAddress = makeAddr("FeeRouter");

        IBondingCurve.ConstructorParams memory params = IBondingCurve.ConstructorParams({
            alpha: _alpha,
            beta: _beta,
            feePercentage: 5e14, // 0.05%
            reserveToken: reserveToken,
            name: "PRB token",
            symbol: "TKN",
            initializerAccount: address(this),
            feeRouterAddress: feeRouterAddress,
            reserveLoansManagerAddress: address(1),
            bondingCurveTokenSplitterAddress: address(1)
        });

        IBondingCurve prbBondingCurve = new PRBBondingCurve(params);
        reserveToken.approve(address(prbBondingCurve), type(uint256).max);
        prbBondingCurve.init(_initialVirtualSupply, _initialFloorSupply, 0);

        return prbBondingCurve;
    }

    function logState(IBondingCurve _bc) internal view {
        console2.log(_bc.virtualSupply(), "Current supply");
        console2.log(_bc.virtualBalance(), "Current balance");
        console2.log(_bc.currentPrice(), "Current price");
        console2.log(_bc.floorSupply(), "Current floor supply");
        console2.log(_bc.floorBalance(), "Current floor balance");
        console2.log(_bc.floorPrice(), "Floor price");
    }

    function logDeviation(IBondingCurve _bc) internal view {
        int256 d = _bc.reserveRatioDeviation();
        if (d >= 0) {
            // forge-lint: disable-next-line(unsafe-typecast)
            console2.log(uint256(d), "reserveRatioDeviation");
        } else {
            // forge-lint: disable-next-line(unsafe-typecast)
            console2.log(uint256(-d), "-reserveRatioDeviation");
        }
    }
}
