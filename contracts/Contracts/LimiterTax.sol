// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../Interfaces/IJoeRouter02.sol";
import "../Interfaces/IJoeFactory.sol";
import "../Interfaces/IJoePair.sol";

contract LimiterTax is Ownable{
    using SafeERC20 for IERC20;
    uint256 private sellTax;//= 1000 //10%
    uint256 private transferTax; //50%
    uint256  feeDenominator = 100;
    address public WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    address routerAddress = 0x60aE616a2155Ee3d9A68541Ba4544862310933d4;
    address DeadAddress = 0x0000000000000000000000000000000000000000;
    IJoeRouter02 private router;
    IJoePair private pair;
    IERC20 private token0;
    IERC20 private token1;
    address public treasury;
    uint256 MAX_UINT256 = type(uint).max;

    constructor(uint256 _sellTax, uint256 _transferTax, address[2] memory path, address _treasury ){
        router = IJoeRouter02(routerAddress);
        pair = createPairWith(path);
        treasury = _treasury;
        token0 = IERC20(path[0]);
        token1 = IERC20(path[1]);
        setSellTax(_sellTax);
        setTransferTax(_transferTax);
    }

    function takeFee( address from, address to, uint256 amount) external view returns(uint256) {
        uint256 feeAmount;
        uint256 netAmount;
        address pairAddress = address(pair);
        bool isSelling = to == DeadAddress || to == pairAddress || to == routerAddress ;
        bool isBuy = from == DeadAddress || from == pairAddress || from == routerAddress ;

         if (isBuy){  //BUY TAX
           return amount;
        } 
        else if (isSelling){  //SELL TAX
           unchecked {
                feeAmount = (amount*sellTax)/feeDenominator;
                netAmount = amount - feeAmount;
                return netAmount; 
           }
           //sellfee(feeAmount);
             
        }
        else {  //Transfer TAX
            unchecked {
                feeAmount = (amount*transferTax)/(feeDenominator);
                netAmount = amount - feeAmount;
                return netAmount;   
            }
        }
    }

    // function sellfee(uint256 _feeAmount) internal {
    //     address[] memory path = new address[](2);
    //     path[0] = address(token0);
    //     path[1] = address(token1);
    //     router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
    //         _feeAmount, 
    //         0,
    //         path,
    //         treasury,
    //         block.timestamp
    //     );
    // }

    function isSell(address to) external view returns(bool){
        address pairAddress = address(pair);
        bool selling = to == DeadAddress || to == pairAddress || to == routerAddress;

        return selling;
    }

    function createPairWith(address[2] memory path) private returns (IJoePair) {
        IJoeFactory factory = IJoeFactory(router.factory());
        address _pair;
        address _currentPair = factory.createPair(path[0], path[1]);
        if (_currentPair != address(0)) {
            _pair = _currentPair;
        } else {
            _pair = factory.createPair(path[0], path[1]);
        }
        return IJoePair(_pair);
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

    function getPair() external view returns(address){
        return address(pair);
    }

    //for testing only

    function getReserve0() external view returns(uint256){
        uint256 reserve0;
        uint256 reserve1;
        uint256 time;
        (reserve0, reserve1, time ) = pair.getReserves();
        return reserve0;
    }

    function getReserve1() external view returns(uint256){
        uint256 reserve0;
        uint256 reserve1;
        uint256 time;
        (reserve0, reserve1, time ) = pair.getReserves();
        return reserve1;
    }
 }