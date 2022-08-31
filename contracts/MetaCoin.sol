//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract MetaCoin {
    event Transfer(address sender, address recipient, uint256 amount);

    address public owner;
    mapping(address => uint256) public balances;

    constructor() {
        owner = msg.sender;
        console.log("Deploying a MetaCoin");
    }

    function mint(address target, uint256 amount) public onlyOwner {
        balances[target] += amount;
    }

    function burn(address target, uint256 amount) public onlyOwner {
        require(amount > balances[target], "insufficient balance");
        balances[target] -= amount;
    }

    function transfer(address target, uint256 amount) public {
        require(amount > balances[msg.sender], "insufficient balance");
        balances[msg.sender] -= amount;
        balances[target] += amount;
        emit Transfer(msg.sender, target, amount);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "NO");
        _;
    }
}
