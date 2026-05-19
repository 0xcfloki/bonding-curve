pragma solidity ^0.8.0;

import {ERC20Permit, ERC20} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract ERC20Mock is ERC20Permit {
    mapping(address => bool) public isAdmin; // can also mint
    mapping(address => bool) public canMint;

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) ERC20Permit(_name) {
        isAdmin[msg.sender] = true;
    }

    function mint(address _account, uint256 _amount) external {
        require(canMint[msg.sender] || isAdmin[msg.sender], "ERC20Mock: Not allowed");

        _mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount) external {
        require(isAdmin[msg.sender], "ERC20Mock: Not allowed");
        _burn(_account, _amount);
    }

    function addAdmin(address _account) external {
        require(isAdmin[msg.sender], "ERC20Mock: Not allowed");
        isAdmin[_account] = true;
    }

    function addMinter(address _account) external {
        require(isAdmin[msg.sender], "ERC20Mock: Not allowed");
        canMint[_account] = true;
    }

    function removeMinter(address _account) external {
        require(isAdmin[msg.sender], "ERC20Mock: Not allowed");
        canMint[_account] = false;
    }
}
