//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../../Interfaces/ILimiterTax.sol";


abstract contract LimiterTaxImplementationPoint is Ownable{
    ILimiterTax public limiterTax;

    event UpdateLimiterTax(
        address indexed oldImplementation,
        address indexed newImplementation
    );

    modifier onlyLiquidityTaxManager() {
        require(
            address(limiterTax) != address(0),
            "Implementations: LimiterManager is not set"
        );
        address sender = _msgSender();
        require(
            sender == address(limiterTax),
            "Implementations: Not LimiterManager"
        );
        _;
    }

    function getLiquidityTaxManager() public view returns (address) {
        return address(limiterTax);
    }

    function setLiquidityTaxManager(address newImplementation) public virtual onlyOwner{
        address oldImplementation = address(limiterTax);
        require(Address.isContract(newImplementation) || newImplementation == address(0),
        "LimiterManager: either 0x0 or a contract address");
        limiterTax = ILimiterTax(newImplementation);

        emit UpdateLimiterTax(oldImplementation, newImplementation);
    } 

    uint256[49] private __gap;
}