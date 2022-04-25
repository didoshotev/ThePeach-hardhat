// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILimiterTax{

    function takeFee (address from, address to, uint256 amount) external view returns(uint256);

    function getSellTax() external view returns(uint256);

    function getTransferTax() external view returns(uint256);

}