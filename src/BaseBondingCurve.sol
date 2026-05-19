pragma solidity ^0.8.24;

import {
    ERC20Permit,
    IERC20Permit,
    ERC20
} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";

import {DECIMAL_PRECISION} from "./Constants.sol";

import {IBondingCurve} from "./Interfaces/IBondingCurve.sol";

// import "forge-std/console2.sol";

// TODO: events

abstract contract BaseBondingCurve is ERC20Permit, IBondingCurve {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    uint256 public constant RESERVE_RATIO_MAX_DEVIATION = 0;
    // TODO: Choose safety values
    uint256 constant MIN_ALPHA = 0;
    uint256 constant MAX_ALPHA = 1e24;

    // The bonding curve is defined as: p = A * s^B
    uint256 public A; // alpha (coefficient) in the bonding curve
    uint256 public immutable B; // beta (exponent) in the bonding curve
    uint256 public immutable B_PLUS_1; // beta + 1
    uint256 public immutable FEE_PERCENTAGE;

    IERC20 public immutable reserveToken;
    address public immutable feeRouterAddress;
    address public immutable reserveLoansManagerAddress;
    address public immutable bondingCurveTokenSplitterAddress;

    // The reserve balance corresponding to the current state of the curve, i.e., the y axis of the current point
    // It's equal to the real balance of this contract minus the floor balance
    uint256 public virtualBalance;
    // The supply corresponding to the current floor price point of the curve
    // It's equal to the total supply burnt through `buyFloorSellAndBurn` and `floorSellAndBurn`
    uint256 public floorSupply;
    // The reserve balance corresponding to the current floor price point of the curve
    // It's equal to the total reserve sent to `feeRouter`
    uint256 public floorBalance;

    // Address authorized to call init()
    // Zero means init() has been called, and no one is authorized to call it any more
    address public initializerAccount;

    constructor(ConstructorParams memory params) ERC20(params.name, params.symbol) ERC20Permit(params.name) {
        require(params.alpha <= MAX_ALPHA, "Alpha too big");
        require(params.beta > 0, "Beta must be greater than 0");
        require(params.beta < DECIMAL_PRECISION, "Beta must be less than 1");
        require(params.feePercentage <= DECIMAL_PRECISION, "Fee percentage too big");
        require(params.initializerAccount != address(0), "BC: Initializer required");
        require(address(params.reserveToken) != address(0), "BC: Reserve token required");
        require(params.feeRouterAddress != address(0), "BC: Fee router required");
        require(params.reserveLoansManagerAddress != address(0), "BC: Reserve loans manager required");
        require(params.bondingCurveTokenSplitterAddress != address(0), "BC: Splitter required");

        A = params.alpha;
        B = params.beta;
        B_PLUS_1 = B + DECIMAL_PRECISION;
        FEE_PERCENTAGE = params.feePercentage;
        reserveToken = params.reserveToken;
        feeRouterAddress = params.feeRouterAddress;
        reserveLoansManagerAddress = params.reserveLoansManagerAddress;
        reserveToken.approve(params.reserveLoansManagerAddress, type(uint256).max);
        bondingCurveTokenSplitterAddress = params.bondingCurveTokenSplitterAddress;

        initializerAccount = params.initializerAccount;
    }

    // init pool
    function init(uint256 _virtualSupply, uint256 _floorSupply, uint256 _alpha) external {
        require(msg.sender == initializerAccount, "Unauthorized");
        delete initializerAccount;
        if (_alpha > 0) {
            require(A == 0, "Alpha was already set");
            A = _alpha;
        }
        require(A > MIN_ALPHA, "Alpha too low");

        // To avoid `pow` reverting below we enforce the floor to be non zero since the very beginning.
        // We don't want to add code that will only be executed once
        // and for a scenario that will only last for very short period of time (until the first time the floor is increased)
        // It also prevents the edge case of the bonding curve being fully emptied again.
        require(_floorSupply > 0, "Floor cannot be zero");
        // It implies virtualSupply > 0 too
        require(_floorSupply <= _virtualSupply, "Floor cannot be above current state");

        floorSupply = _floorSupply;
        uint256 initialVirtualBalance = _getBalanceFromReserveRatio(_virtualSupply);
        assert(reserveRatioDeviation(_virtualSupply, initialVirtualBalance) == 0);
        uint256 initialFloorBalance = _getBalanceFromReserveRatio(_floorSupply);
        assert(reserveRatioDeviation(_floorSupply, initialFloorBalance) == 0);
        assert(initialFloorBalance <= initialVirtualBalance);

        virtualBalance = initialVirtualBalance;
        floorBalance = initialFloorBalance;

        // token operations
        _mint(msg.sender, _virtualSupply - _floorSupply); // equals initial total supply
        reserveToken.safeTransferFrom(msg.sender, address(this), initialVirtualBalance - initialFloorBalance);
        reserveToken.safeTransferFrom(msg.sender, feeRouterAddress, initialFloorBalance);
    }

    // These functions move virtual supply upwards (right)
    function buy(uint256 _bcTokenAmount, uint256 _maxReserveAmount) external returns (uint256, uint256) {
        require(initializerAccount == address(0), "BC not initialized yet");

        uint256 bcTokenFeeAmount;
        uint256 bcTokenTotalAmount = _bcTokenAmount;
        if (msg.sender != feeRouterAddress) {
            bcTokenFeeAmount = getBcTokenBuyFeeFromNet(_bcTokenAmount);
            bcTokenTotalAmount += bcTokenFeeAmount;
        }

        uint256 initialVirtualSupply = virtualSupply();
        uint256 initialVirtualBalance = virtualBalance;
        uint256 reserveAmount = getBuyAmount(bcTokenTotalAmount, initialVirtualSupply, initialVirtualBalance);
        require(reserveAmount <= _maxReserveAmount, "Max amount surpassed");

        virtualBalance = initialVirtualBalance + reserveAmount;

        _mint(msg.sender, _bcTokenAmount);
        if (bcTokenFeeAmount > 0) {
            _mint(feeRouterAddress, bcTokenFeeAmount);
        }
        reserveToken.safeTransferFrom(msg.sender, address(this), reserveAmount);

        return (reserveAmount, bcTokenFeeAmount);
    }

    function getBuyAmount(uint256 _bcTokenAmount) external view returns (uint256) {
        return getBuyAmount(_bcTokenAmount, virtualSupply(), virtualBalance);
    }

    function getBuyAmount(uint256 _bcTokenAmount, uint256 _supply, uint256 _balance) public view returns (uint256) {
        _requireNonZeroAmount(_bcTokenAmount);

        //uint256 gasLeft = gasleft();
        uint256 newVirtualSupply = _supply + _bcTokenAmount;
        uint256 newVirtualBalance = _getBalanceFromReserveRatio(newVirtualSupply);
        uint256 reserveAmount = newVirtualBalance - _balance;
        //console2.log(gasLeft - gasleft(), "gas used by math");

        return reserveAmount;
    }

    function getBuyAmountFromNet(uint256 _bcTokenAmount) external view returns (uint256) {
        return getBuyAmountFromNet(_bcTokenAmount, virtualSupply(), virtualBalance);
    }

    function getBuyAmountFromNet(uint256 _bcTokenAmount, uint256 _supply, uint256 _balance)
        public
        view
        returns (uint256)
    {
        uint256 bcTokenTotalAmount = _bcTokenAmount + getBcTokenBuyFeeFromNet(_bcTokenAmount);
        return getBuyAmount(bcTokenTotalAmount, _supply, _balance);
    }

    function getBuyBcTokenAmountFromReserve(uint256 _reserveAmount) external view returns (uint256, uint256) {
        return getBuyBcTokenAmountFromReserve(_reserveAmount, virtualSupply(), virtualBalance, A);
    }

    function getBuyBcTokenAmountFromReserve(uint256 _reserveAmount, uint256 _supply, uint256 _balance)
        external
        view
        returns (uint256, uint256)
    {
        return getBuyBcTokenAmountFromReserve(_reserveAmount, _supply, _balance, A);
    }

    function getBuyBcTokenAmountFromReserve(uint256 _reserveAmount, uint256 _supply, uint256 _balance, uint256 _alpha)
        public
        view
        returns (uint256, uint256)
    {
        _requireNonZeroAmount(_reserveAmount);

        //uint256 gasLeft = gasleft();
        uint256 newVirtualBalance = _balance + _reserveAmount;
        uint256 newVirtualSupply =
            pow(newVirtualBalance * B_PLUS_1 / _alpha, DECIMAL_PRECISION * DECIMAL_PRECISION / B_PLUS_1);
        require(newVirtualSupply > _supply, "Reserve amount too low");
        uint256 bcTokenAmount = newVirtualSupply - _supply;
        // After the initial approximation by the regular buy formula, we now get the final amounts from the RR formula
        uint256 resultingVirtualBalance = _getBalanceFromReserveRatio(newVirtualSupply);
        // TODO: prove that this always holds true
        require(newVirtualBalance >= resultingVirtualBalance, "reserve leftovers negative!");
        uint256 reserveLeftover = newVirtualBalance - resultingVirtualBalance;
        //console2.log(gasLeft - gasleft(), "gas used by math");

        return (bcTokenAmount, reserveLeftover);
    }

    // These functions move virtual supply downwards (left)
    function sell(uint256 _bcTokenAmount, uint256 _minReserveAmount) external returns (uint256, uint256) {
        // We don't need to check initialization, because buy is locked, so there are no BC tokens to sell before it

        uint256 bcTokenFeeAmount = getBcTokenSellFee(_bcTokenAmount);
        uint256 bcTokenNetAmount = _bcTokenAmount - bcTokenFeeAmount;

        uint256 initialVirtualSupply = virtualSupply();
        uint256 initialVirtualBalance = virtualBalance;
        uint256 reserveAmount = getSellAmount(bcTokenNetAmount, initialVirtualSupply, initialVirtualBalance);
        require(reserveAmount >= _minReserveAmount, "Min amount not reached");

        virtualBalance = initialVirtualBalance - reserveAmount;

        _burn(msg.sender, bcTokenNetAmount);
        _transfer(msg.sender, feeRouterAddress, bcTokenFeeAmount);
        reserveToken.safeTransfer(msg.sender, reserveAmount);

        return (reserveAmount, bcTokenFeeAmount);
    }

    function getSellAmount(uint256 _bcTokenAmount) external view returns (uint256) {
        return getSellAmount(_bcTokenAmount, virtualSupply(), virtualBalance);
    }

    function getSellAmount(uint256 _bcTokenAmount, uint256 _supply, uint256 _balance) public view returns (uint256) {
        _requireNonZeroAmount(_bcTokenAmount);
        require(_bcTokenAmount <= _supply, "BC: Amount greater than supply");

        //uint256 gasLeft = gasleft();
        uint256 newVirtualSupply = _supply - _bcTokenAmount;
        uint256 newVirtualBalance = _getBalanceFromReserveRatio(newVirtualSupply);
        uint256 reserveAmount = _balance - newVirtualBalance;
        //console2.log(gasLeft - gasleft(), "gas used by math");

        return reserveAmount;
    }

    function getSellAmountFromGross(uint256 _bcTokenAmount) external view returns (uint256) {
        return getSellAmountFromGross(_bcTokenAmount, virtualSupply(), virtualBalance);
    }

    function getSellAmountFromGross(uint256 _bcTokenAmount, uint256 _supply, uint256 _balance)
        public
        view
        returns (uint256)
    {
        uint256 bcTokenNetAmount = _bcTokenAmount - getBcTokenSellFee(_bcTokenAmount);
        return getSellAmount(bcTokenNetAmount, _supply, _balance);
    }

    // These functions move floor supply upwards (right)
    function floorSellAndBurn(uint256 _bcTokenAmount) external returns (uint256) {
        // We don't need to check initialization, because buy is locked, so there are no BC tokens to burn before it
        // Besides, this is a permissioned function
        // TODO: add emergency mode or other use cases
        _requireOnlyFeeRouter();

        uint256 initialFloorSupply = floorSupply;
        uint256 initialFloorBalance = floorBalance;
        uint256 reserveAmount = getSellAmountFromFloorUpwards(_bcTokenAmount, initialFloorSupply, initialFloorBalance);

        uint256 newFloorSupply = initialFloorSupply + _bcTokenAmount;
        require(newFloorSupply <= virtualSupply(), "Floor cannot surpass virtual state");
        uint256 newFloorBalance = initialFloorBalance + reserveAmount;
        assert(newFloorBalance <= virtualBalance);

        // BC token operations
        floorSupply = newFloorSupply;
        _burn(msg.sender, _bcTokenAmount);

        // Reserve token operations
        floorBalance = newFloorBalance;
        reserveToken.safeTransfer(msg.sender, reserveAmount);

        return reserveAmount;
    }

    function getSellAmountFromFloorUpwards(uint256 _bcTokenAmount) external view returns (uint256) {
        return getSellAmountFromFloorUpwards(_bcTokenAmount, floorSupply, floorBalance);
    }

    function getSellAmountFromFloorUpwards(uint256 _bcTokenAmount, uint256 _supply, uint256 _balance)
        public
        view
        returns (uint256)
    {
        _requireNonZeroAmount(_bcTokenAmount);

        //uint256 gasLeft = gasleft();
        uint256 newFloorSupply = _supply + _bcTokenAmount;
        uint256 newFloorBalance = _getBalanceFromReserveRatio(newFloorSupply);
        uint256 reserveAmount = newFloorBalance - _balance;
        //console2.log(gasLeft - gasleft(), "gas used by math");

        return reserveAmount;
    }

    function redeemFpToken(address _receiver, uint256 _fpTokenAmount) external returns (uint256) {
        _requireOnlySplitter();

        uint256 reserveAmount = _fpTokenAmount * floorPrice() / DECIMAL_PRECISION;
        reserveToken.safeTransfer(_receiver, reserveAmount);

        return reserveAmount;
    }

    // to avoid the need for approvals
    function permissionedTransferFrom(address _from, address _to, uint256 _value) external returns (bool) {
        _requireOnlyFeeRouterOrReserveLoansManagerOrSplitter();
        _transfer(_from, _to, _value);
        return true;
    }

    // View functions

    // The supply corresponding to the current state of the curve, i.e., the x axis of the current point
    // It's equal to the real total supply plus the floor supply
    function virtualSupply() public view returns (uint256) {
        return floorSupply + totalSupply();
    }

    // Analogous to total supply but for reserve. It's the amount of reserve hold by the BC.
    // It's equal to the virtual balance minus the floor balance
    function totalBalance() public view returns (uint256) {
        return virtualBalance - floorBalance;
    }

    function getBalanceAndSupply() external view returns (uint256 balance, uint256 supply) {
        balance = totalBalance();
        supply = totalSupply();
    }

    function getPrice(uint256 _supply) public view returns (uint256) {
        return A * pow(_supply, B) / DECIMAL_PRECISION;
    }

    function currentPrice() external view returns (uint256) {
        return getPrice(virtualSupply());
    }

    function floorPrice() public view returns (uint256) {
        return getPrice(floorSupply);
    }

    function getBcTokenBuyFee(uint256 _bcTokenAmount) public view returns (uint256) {
        return _bcTokenAmount * FEE_PERCENTAGE / DECIMAL_PRECISION;
    }

    function getBcTokenBuyFeeFromNet(uint256 _bcTokenAmount) public view returns (uint256) {
        return _bcTokenAmount * FEE_PERCENTAGE / (DECIMAL_PRECISION - FEE_PERCENTAGE);
    }

    function getBcTokenSellFee(uint256 _bcTokenAmount) public view returns (uint256) {
        return _bcTokenAmount * FEE_PERCENTAGE / DECIMAL_PRECISION;
    }

    function getBcTokenAmountMinusFee(uint256 _bcTokenAmount) external view returns (uint256) {
        return _bcTokenAmount - getBcTokenBuyFee(_bcTokenAmount);
    }

    function checkCurrentDeviation() external view returns (bool) {
        return checkCurrentDeviation(RESERVE_RATIO_MAX_DEVIATION);
    }

    function checkCurrentDeviation(uint256 _errorThreshold) public view returns (bool) {
        return _validatePosition(virtualSupply(), virtualBalance, _errorThreshold);
    }

    function reserveRatioDeviation() external view returns (int256) {
        return reserveRatioDeviation(virtualSupply(), virtualBalance);
    }

    function reserveRatioDeviation(uint256 _supply, uint256 _balance) public view returns (int256) {
        // casting to 'int256' is safe:
        // B_PLUS_1 * _balance: _balance should be > 2.89e58, i.e., more than 2.89e40 reserve tokens
        // _getReserveRatioLeftFormula: it is essentially market cap of the bonding curve * 1e18. Market cap should be > 5.78e40 reserve tokens
        // DECIMAL_PRECISION: it's a constant
        // But, this is not used in any state writing, so gas is not important, and if called directly it wouldn't revert anywhere else,
        // so we use SafeCast except for the constant.
        return ((B_PLUS_1 * _balance).toInt256() - _getReserveRatioLeftFormula(_supply).toInt256())
            // forge-lint: disable-next-line(unsafe-typecast)
            / int256(DECIMAL_PRECISION);
    }

    function _getBalanceFromReserveRatio(uint256 _supply) internal view returns (uint256) {
        uint256 left = _getReserveRatioLeftFormula(_supply);
        uint256 bal = (left + DECIMAL_PRECISION - 1) / B_PLUS_1;
        return bal;
    }

    function _getReserveRatioLeftFormula(uint256 _supply) internal view returns (uint256) {
        // This is equivalent to: _supply * getPrice(_supply);
        return A * pow(_supply, B_PLUS_1);
    }

    function _validatePosition(uint256 _supply, uint256 _balance, uint256 _errorThreshold)
        internal
        view
        returns (bool)
    {
        int256 deviation = reserveRatioDeviation(_supply, _balance);
        // casting to 'uint256' is safe because we are checking sign
        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 absoluteDiff = deviation >= 0 ? uint256(deviation) : uint256(-deviation);
        // console2.log(absoluteDiff, "absoluteDiff");
        // console2.log(_supply, "_supply");
        // console2.log(_balance, "_balance");

        if (absoluteDiff * DECIMAL_PRECISION / _balance <= _errorThreshold) return true;
        return false;
    }

    function _requireOnlyFeeRouter() internal view {
        require(msg.sender == feeRouterAddress, "BC: Not allowed");
    }

    function _requireOnlyFeeRouterOrReserveLoansManagerOrSplitter() internal view {
        require(
            msg.sender == feeRouterAddress || msg.sender == reserveLoansManagerAddress
                || msg.sender == bondingCurveTokenSplitterAddress,
            "BC: Not allowed"
        );
    }

    function _requireOnlySplitter() internal view {
        require(msg.sender == bondingCurveTokenSplitterAddress, "BC: Not allowed");
    }

    function _requireNonZeroAmount(uint256 _amount) internal pure {
        require(_amount > 0, "BC: Amount cannot be zero");
    }

    // Unimplemented functions
    function pow(uint256 _base, uint256 _exponent) public pure virtual returns (uint256);

    // ERC20 functions

    function transfer(address recipient, uint256 amount) public override(ERC20, IERC20) returns (bool) {
        _requireValidRecipient(recipient);
        return super.transfer(recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount)
        public
        override(ERC20, IERC20)
        returns (bool)
    {
        _requireValidRecipient(recipient);
        return super.transferFrom(sender, recipient, amount);
    }

    function _requireValidRecipient(address _recipient) internal view {
        require(
            _recipient != address(0) && _recipient != address(this),
            "BC: Cannot transfer tokens directly to the BC token contract or the zero address"
        );
    }

    function nonces(address owner) public view virtual override(IERC20Permit, ERC20Permit) returns (uint256) {
        return super.nonces(owner);
    }
}
