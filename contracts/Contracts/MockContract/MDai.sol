//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "hardhat/console.sol";

//Sole purpose of testing lp manager
contract MDai is ERC20, Ownable{
    
    uint256  private _totalSupply = 2000000*1e18;
        
    constructor() ERC20("MDai Token","MDAI"){
        _mint(owner(), _totalSupply);
    }
}