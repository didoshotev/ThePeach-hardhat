// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "../Interfaces/IJoeRouter02.sol";
import "../Interfaces/IJoeFactory.sol";

contract LimiterTax is Ownable{
    uint256 private sellTax;//= 1000 //10%
    uint256 private transferTax; //50%
    uint256  feeDenominator = 100;
    address public WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    address routerAddress = 0x60aE616a2155Ee3d9A68541Ba4544862310933d4;
    address DeadAddress = 0x0000000000000000000000000000000000000000;
    address public pair;
    IJoeRouter02 public router;

    constructor(uint256 _sellTax, uint256 _transferTax, address _token ){
        router = IJoeRouter02(routerAddress);
        pair = IJoeFactory(router.factory()).createPair(_token, WAVAX);
        setSellTax(_sellTax);
        setTransferTax(_transferTax);
        
    }

    function takeFee( address from, address to, uint256 amount) external view returns(uint256) {
        uint256 feeAmount;
        uint256 netAmount;
        bool isSell = to == DeadAddress || to == pair || to == routerAddress ;
        bool isBuy = from == DeadAddress || from == pair || from == routerAddress ;

         if (isBuy){  //BUY TAX
           return amount;
        } 
        else if (isSell){  //SELL TAX
           unchecked {
                feeAmount = (amount*sellTax)/feeDenominator;
                netAmount = amount - feeAmount; 
                return netAmount;   
           } 
        }
        else {  //Transfer TAX
            unchecked {
                feeAmount = (amount*transferTax)/(feeDenominator);
                netAmount = amount - feeAmount;
                return netAmount;   
            }
        }
    }


    //@notice Only Owner
    function setSellTax(uint256 _newTax) public onlyOwner{
        sellTax = _newTax;
    }

    function setTransferTax(uint256 _newTax) public onlyOwner{
        transferTax = _newTax;
    }

    // @notice view functions
    function getSellTax() external view returns(uint256){
        return sellTax;
    }

    function getTransferTax() external view returns(uint256){
        return transferTax;
    }
 }