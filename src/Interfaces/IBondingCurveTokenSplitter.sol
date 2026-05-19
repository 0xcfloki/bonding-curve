pragma solidity ^0.8.0;

import {IERC20Metadata, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";

interface IBondingCurveTokenSplitter is IERC20Metadata, IERC20Permit {
    function reserveToken() external view returns (IERC20);
    function redeemedFpTokenBalance() external view returns (uint256);
    function redeemedReserveBalance() external view returns (uint256);

    function split(uint256 _amount) external;
    function merge(uint256 _amount) external;
    function redeem(uint256 _fpTokenAmount) external;
    function buyFpToken(uint256 _reserveAmount) external;
    function rescueFpTokenProfits(uint256 _amount) external;
    function permissionedTransferFrom(address _from, address _to, uint256 _value) external returns (bool);
}
