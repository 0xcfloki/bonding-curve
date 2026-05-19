pragma solidity ^0.8.0;

import {IERC20Metadata, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IERC5267} from "openzeppelin-contracts/contracts/interfaces/IERC5267.sol";

interface IBondingCurve is IERC20Metadata, IERC20Permit, IERC5267 {
    struct ConstructorParams {
        uint256 alpha;
        uint256 beta;
        uint256 feePercentage;
        IERC20 reserveToken;
        string name;
        string symbol;
        address initializerAccount;
        address feeRouterAddress;
        address reserveLoansManagerAddress;
        address bondingCurveTokenSplitterAddress;
    }

    function A() external view returns (uint256);
    function B() external view returns (uint256);

    function FEE_PERCENTAGE() external view returns (uint256);
    function initializerAccount() external view returns (address);
    function feeRouterAddress() external view returns (address);
    function reserveLoansManagerAddress() external view returns (address);
    function bondingCurveTokenSplitterAddress() external view returns (address);

    function reserveToken() external view returns (IERC20);

    function virtualSupply() external view returns (uint256);
    function virtualBalance() external view returns (uint256);
    function floorSupply() external view returns (uint256);
    function floorBalance() external view returns (uint256);
    // totalSupply is given by ERC20
    function totalBalance() external view returns (uint256);
    // Helper function that provides in one call all the information needed
    // from the BC in order to calculate ratios between debt and reserve
    function getBalanceAndSupply() external view returns (uint256, uint256);

    function init(uint256 _virtualSupply, uint256 _floorSupply, uint256 _alpha) external;

    function buy(uint256 _bcTokenAmount, uint256 _maxReserveAmount)
        external
        returns (uint256 reserveAmount, uint256 bcTokenFeeAmount);
    function sell(uint256 _bcTokenAmount, uint256 _minReserveAmount)
        external
        returns (uint256 reserveAmount, uint256 bcTokenFeeAmount);
    function floorSellAndBurn(uint256 _bcTokenAmount) external returns (uint256 reserveAmount);
    function permissionedTransferFrom(address _from, address _to, uint256 _value) external returns (bool);

    function getBuyAmount(uint256 _bcTokenAmount) external view returns (uint256 reserveAmount);
    function getBuyAmount(uint256 _bcTokenAmount, uint256 _supply, uint256 _balance)
        external
        view
        returns (uint256 reserveAmount);
    function getBuyAmountFromNet(uint256 _bcTokenAmount) external view returns (uint256 reserveAmount);
    function getBuyAmountFromNet(uint256 _bcTokenAmount, uint256 _supply, uint256 _balance)
        external
        view
        returns (uint256 reserveAmount);
    function getBuyBcTokenAmountFromReserve(uint256 _reserveAmount)
        external
        view
        returns (uint256 bcTokenAmount, uint256 reserveLeftover);
    function getBuyBcTokenAmountFromReserve(uint256 _reserveAmount, uint256 _supply, uint256 _balance)
        external
        view
        returns (uint256 bcTokenAmount, uint256 reserveLeftover);
    function getBuyBcTokenAmountFromReserve(uint256 _reserveAmount, uint256 _supply, uint256 _balance, uint256 _alpha)
        external
        view
        returns (uint256 bcTokenAmount, uint256 reserveLeftover);
    function getSellAmount(uint256 _bcTokenAmount) external view returns (uint256 reserveAmount);
    function getSellAmount(uint256 _bcTokenAmount, uint256 _supply, uint256 _balance)
        external
        view
        returns (uint256 reserveAmount);
    function getSellAmountFromGross(uint256 _bcTokenAmount) external view returns (uint256);
    function getSellAmountFromGross(uint256 _bcTokenAmount, uint256 _supply, uint256 _balance)
        external
        view
        returns (uint256);
    function getSellAmountFromFloorUpwards(uint256 _bcTokenAmount) external view returns (uint256 reserveAmount);
    function getSellAmountFromFloorUpwards(uint256 _bcTokenAmount, uint256 _supply, uint256 _balance)
        external
        view
        returns (uint256 reserveAmount);

    function redeemFpToken(address _receiver, uint256 _fpTokenAmount) external returns (uint256 reserveAmount);

    function getPrice(uint256 _supply) external view returns (uint256);
    function currentPrice() external view returns (uint256);
    function floorPrice() external view returns (uint256);

    function getBcTokenBuyFee(uint256 _bcTokenAmount) external view returns (uint256 bcTokenFeeAmount);
    function getBcTokenBuyFeeFromNet(uint256 _bcTokenAmount) external view returns (uint256 bcTokenFeeAmount);
    function getBcTokenSellFee(uint256 _bcTokenAmount) external view returns (uint256 bcTokenFeeAmount);
    function getBcTokenAmountMinusFee(uint256 _bcTokenAmount) external view returns (uint256 bcTokenNetAmount);

    function reserveRatioDeviation() external view returns (int256);
    function reserveRatioDeviation(uint256 _supply, uint256 _balance) external view returns (int256);
    function checkCurrentDeviation() external view returns (bool);
    function checkCurrentDeviation(uint256 _errorThreshold) external view returns (bool);

    function pow(uint256 _base, uint256 _exponent) external pure returns (uint256);
}
