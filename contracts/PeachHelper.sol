// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./NodeManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IJoeRouter02.sol";
import "./IJoeFactory.sol";
import "./Pool.sol";

contract PeachHelper is Ownable {
    using SafeMath for uint;
    using SafeMath for uint256;

    NodeManager public manager;
    IERC20 public PeachToken;
    
    address public router;
    IJoeRouter02 public dexRouter;
    address public lpPair;

    Pool public pool;

    mapping (address => bool) lpPairs;
    uint256 private timeSinceLastPair = 0;

    address private WAVAX;
    address private Peach;

    event Received(address, uint);
    
    constructor(address _manager, address _PeachToken){
        manager = NodeManager(_manager);
        PeachToken = IERC20(_PeachToken);
        pool = new Pool(_PeachToken);
        Peach = _PeachToken;

        //Testnet Router 
        //Mainnet Router 0x60aE616a2155Ee3d9A68541Ba4544862310933d4
        router = 0x60aE616a2155Ee3d9A68541Ba4544862310933d4;

        dexRouter = IJoeRouter02(router);
        WAVAX = dexRouter.WAVAX();
        
        //SET LP PAIR PEACH/AVAX
        lpPair = IJoeFactory(dexRouter.factory()).createPair(
            _PeachToken,
            WAVAX
        );

        lpPairs[lpPair] = true;

        PeachToken.approve(router, type(uint256).max);
        
    }

    //Transfer Function Discord

    //Receive AVAX
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    //Swap Exact Tokens for Max AVAX PEACH/AVAX
    function swapTokensForAvax(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = Peach;
        path[1] = dexRouter.WAVAX();

        dexRouter.swapExactTokensForAVAXSupportingFeeOnTransferTokens(
            tokenAmount, //Amount In
            0, // Accept Any Amount Of AVAX
            path, 
            Peach, // Recipient Of AVAX - Clarify Potentialy LPool
            block.timestamp /// Transaction Complete in Block
        );
    }

    function addLiquidityAVAX(uint256 tokenAmount, uint256 avaxAmount) private {

        // add the liquidity
        dexRouter.addLiquidityAVAX{value: avaxAmount}(
            Peach,
            tokenAmount,
            0, 
            0, 
            address(0), // Clarify - Tokens sent potentiall LPool
            block.timestamp
        );
    }
}