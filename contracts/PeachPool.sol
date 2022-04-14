// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "./interfaces/IERC20.sol";
import "./interfaces/IJoeRouter01.sol";
import "./interfaces/IJoeFactory.sol";

// add/remove liquidity

contract PeachPool { 
    address public immutable WAVAX;
    address PEACH_TOKEN;
    address public wavaxPeachPairAddress;

    address private JOE_FACTORY;
    address private JOE_ROUTER;

    IJoeRouter01 joeRouter;

    event Log(string message, uint val);
    event Pair(string message, address pairAddress);

    constructor(address _factory, address _router, address _peachToken, address _WAVAX) { 
        PEACH_TOKEN = _peachToken;
        WAVAX = _WAVAX;

        JOE_FACTORY = _factory;
        JOE_ROUTER = _router;
        wavaxPeachPairAddress = IJoeFactory(JOE_FACTORY).createPair(PEACH_TOKEN, _WAVAX);
    }

    receive() external payable { }

    //   @params addLiquidityAVAX
    //     address token,
    //     uint256 amountTokenDesired,
    //     uint256 amountTokenMin,
    //     uint256 amountAVAXMin,
    //     address to,
    //     uint256 deadline
    function addLiquidityAvax(address _tokenAddress, uint _tokenAmount, uint _avaxAmount) external payable { 
        IERC20(_tokenAddress).approve(JOE_ROUTER, _tokenAmount);
        IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _tokenAmount);

        (uint256 amountToken, uint256 amountAVAX, uint256 liquidity) 
            = IJoeRouter01(JOE_ROUTER).addLiquidityAVAX{value: _avaxAmount}(_tokenAddress, _tokenAmount, 1, 1, address(this), block.timestamp);
        
        emit Log("amountA", amountToken);
        emit Log("amountAvax", amountAVAX);
        emit Log("liquidity", liquidity);
    }

    function removeLiquidityAvax(address _tokenAddress) external {
        address pair = IJoeFactory(JOE_FACTORY).getPair(_tokenAddress, WAVAX); 
        emit Pair("Peach/Wavax", pair);
        
        uint liquidity = IERC20(pair).balanceOf(address(this));

        IERC20(pair).approve(JOE_ROUTER, liquidity); 
        
        (uint peachAmount, uint avaxAmount) = IJoeRouter01(JOE_ROUTER).removeLiquidityAVAX(
            _tokenAddress,
            liquidity,
            1,
            1,
            address(this),
            block.timestamp
        );

        emit Log("peachAmount", peachAmount);
        emit Log("avaxAmount", avaxAmount);
    }

    function addLiquidityToken(address token1Address, address token2Address, uint token1Amount, uint token2Amount) external {
        IJoeRouter01(JOE_ROUTER).addLiquidity(
            token1Address,
            token2Address,
            token1Amount,
            token2Amount,
            1,
            1,
            address(this),
            block.timestamp
        );
    }

    // internalTokenAmount - depends on the network (avax/eth)
    function addLiquidityTest(address _tokenAddress, uint _tokenAmount, uint _internalTokenAmount) external payable { 
        IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _tokenAmount);
        
        IERC20(_tokenAddress).approve(JOE_ROUTER, _tokenAmount);

        (uint256 amountToken, uint256 internalTokenAmount, uint256 liquidity) 
            = IJoeRouter01(JOE_ROUTER).addLiquidityAVAX{value: _internalTokenAmount}(_tokenAddress, _tokenAmount, 1, 1, address(this), block.timestamp);
        
        emit Log("amountA", amountToken);
        emit Log("internalTokenAmount", internalTokenAmount);
        emit Log("liquidity", liquidity);
    }

    function getPair() public view returns(address) {
        return wavaxPeachPairAddress;
    }


//  uint256 amountOutMin,
//         address[] calldata path,
//         address to,
//         uint256 deadline

    function customSwapExactAVAXForTokens(uint256 amountOutMin, address[] calldata path, address to) external payable returns(uint[] memory amount) { 
        return IJoeRouter01(JOE_ROUTER).swapExactAVAXForTokens(
            amountOutMin,
            path,
            to,
            block.timestamp
        );       
    }

    function customAddLiquidityAVAX(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountAVAXMin,
        address to
    ) external payable returns(uint256 amountToken, uint256 amountAVAX, uint256 liquidity) {
        return IJoeRouter01(JOE_ROUTER).addLiquidityAVAX(
        token,
        amountTokenDesired,
        amountTokenMin,
        amountAVAXMin,
        to,
        block.timestamp
        );
    }
}