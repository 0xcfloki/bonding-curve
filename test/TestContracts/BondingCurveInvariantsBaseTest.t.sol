pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
// import {console2} from "forge-std/Test.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {IBondingCurve} from "src/Interfaces/IBondingCurve.sol";
import {ABDKBondingCurve} from "src/ABDKBondingCurve.sol";
import {DECIMAL_PRECISION, ONE_YEAR} from "src/Constants.sol";

import {ERC20Mock} from "./ERC20Mock.sol";
import {BondingCurveInvariantsTestHandler} from "./BondingCurveInvariantsTestHandler.t.sol";

contract BondingCurveInvariantsBaseTest is Test {
    uint256 constant ALPHA = 0.01632993162 ether;
    uint256 constant BETA = 0.5 ether;
    uint256 constant INITIAL_SUPPLY = 3750 ether;
    uint256 constant INITIAL_FLOOR_SUPPLY = INITIAL_SUPPLY / 2;
    uint256 constant MIN_REWARD_RATE_PERCENTAGE = DECIMAL_PRECISION / 100 / ONE_YEAR; // 1% year
    uint256 constant MAX_REWARD_PERIOD = 4 weeks;

    ERC20Mock reserveToken;
    address feeRouterAddress;
    IBondingCurve bondingCurve;
    BondingCurveInvariantsTestHandler handler;

    function _setUp(uint256 _alpha, uint256 _beta, uint256 _initialSupply, uint256 _initialFloorSupply) internal {
        reserveToken = new ERC20Mock("WETH", "WETH");

        // Mint some reserve tokens to initialize bonding curve and to allow for selling
        reserveToken.mint(address(this), 1e6 ether);

        feeRouterAddress = makeAddr("FeeRouter");

        // Compute address to be able to approve
        IBondingCurve.ConstructorParams memory params = IBondingCurve.ConstructorParams({
            alpha: _alpha,
            beta: _beta,
            feePercentage: 5e14, // 0.05%
            reserveToken: IERC20(reserveToken),
            name: "ADBK token",
            symbol: "TKN",
            initializerAccount: address(this),
            feeRouterAddress: feeRouterAddress,
            reserveLoansManagerAddress: address(1),
            bondingCurveTokenSplitterAddress: address(1)
        });

        bondingCurve = new ABDKBondingCurve(params);
        reserveToken.approve(address(bondingCurve), type(uint256).max);
        bondingCurve.init(_initialSupply, _initialFloorSupply, 0);

        handler = new BondingCurveInvariantsTestHandler(bondingCurve);
        vm.label(address(handler), "handler");
        targetContract(address(handler));

        // Mint some reserve tokens so that handler can buy
        reserveToken.mint(address(handler), 1e12 ether);
        // Make the initial supply available to the handler contract, so it can be sold too
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        bondingCurve.transfer(address(handler), bondingCurve.balanceOf(address(this)));
    }

    function setUp() public virtual {
        _setUp(ALPHA, BETA, INITIAL_SUPPLY, INITIAL_FLOOR_SUPPLY);
    }
}
