pragma solidity ^0.8.0;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IBondingCurve} from "./IBondingCurve.sol";

interface IBondingCurveBootstrap {
    struct ConstructorParams {
        uint256 minReserveAmountRaised;
        uint256 maxReserveAmountRaised;
        uint256 startTime;
        uint256 fundraisingPeriod;
        uint256 deadlinePeriod;
        uint256 antiCliffPercentage;
        uint256 vestingPeriod;
        uint256 rageQuitPenalty;
        uint256 floorSupplyPercentage;
        bytes32 merkleRoot;
    }

    function MIN_RESERVE_AMOUNT_RAISED() external view returns (uint256);
    function START_TIME() external view returns (uint256);
    function END_TIME() external view returns (uint256);
    function DEPLOYMENT_DEADLINE() external view returns (uint256);
    function ANTI_CLIFF_PERCENTAGE() external view returns (uint256);
    function VESTING_PERIOD() external view returns (uint256);
    function FLOOR_SUPPLY_PERCENTAGE() external view returns (uint256);
    function merkleRoot() external view returns (bytes32);
    function reserveToken() external view returns (IERC20);
    //function bcParams() external view returns (IBondingCurve.ConstructorParams memory);

    function bondingCurve() external view returns (IBondingCurve);
    function reserveTokenBalance(address) external view returns (uint256);
    function claimedBcTokenAmount(address) external view returns (uint256);
    function totalReserveAmount() external view returns (uint256);
    function totalBcTokenAmount() external view returns (uint256);
    function totalBcTokenClaimed() external view returns (uint256);

    function depositReserveToken(uint256 _depositAmount, uint256 _allowanceAmount, bytes32[] memory _proof) external;
    function finishAndDeployBondingCurve(uint256 _additionalFloorSupply) external returns (IBondingCurve);
    function claimReserveToken() external returns (uint256);
    function claimBcToken() external returns (uint256);
    function rageQuit() external returns (uint256 totalGrossAmount, uint256 totalFinalAmount);

    function getUserTotalClaimableBcTokenAmount(address _account) external view returns (uint256);
    function getUserVestingBcTokenAmounts(address _account)
        external
        view
        returns (
            uint256 totalClaimableBcTokenAmount,
            uint256 vestedBcTokenAmount,
            uint256 claimableBcTokenAmount,
            uint256 claimedBcTokenAmount
        );
}
