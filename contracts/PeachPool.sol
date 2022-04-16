// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "./interfaces/IERC20.sol";
import "./interfaces/IJoeRouter01.sol";
// import "./interfaces/IJoeRouter02.sol";
import "./interfaces/IJoeFactory.sol";
import "./interfaces/IJoePair.sol";

// add/remove liquidity

contract PeachPool {
    address public immutable WAVAX;
    address PEACH_TOKEN;
    address public wavaxPeachPairAddress;

    address private JOE_FACTORY;
    address private JOE_ROUTER;

    IJoeRouter01 private router;
    IJoePair private pair;

    event Log(string message, uint val);
    event Pair(string message, address pairAddress);

    constructor(
        address _factory,
        address _router,
        address _peachToken,
        address _WAVAX,
        address[2] memory path
    ) {
        router = IJoeRouter01(_router);
        pair = createJoePair(path);

        PEACH_TOKEN = _peachToken;
        WAVAX = _WAVAX;

        JOE_FACTORY = _factory;
        JOE_ROUTER = _router;

        // wavaxPeachPairAddress = IJoeFactory(JOE_FACTORY).createPair(PEACH_TOKEN, _WAVAX);
    }

    receive() external payable {}

    //   @params addLiquidityAVAX
    //     address token,
    //     uint256 amountTokenDesired,
    //     uint256 amountTokenMin,
    //     uint256 amountAVAXMin,
    //     address to,
    //     uint256 deadline
    function addLiquidityAvax(
        address _tokenAddress,
        uint _tokenAmount,
        uint _avaxAmount
    ) external payable {
        IERC20(_tokenAddress).approve(JOE_ROUTER, _tokenAmount);
        IERC20(_tokenAddress).transferFrom(
            msg.sender,
            address(this),
            _tokenAmount
        );

        (
            uint256 amountToken,
            uint256 amountAVAX,
            uint256 liquidity
        ) = IJoeRouter01(JOE_ROUTER).addLiquidityAVAX{value: _avaxAmount}(
                _tokenAddress,
                _tokenAmount,
                1,
                1,
                address(this),
                block.timestamp
            );

        emit Log("amountA", amountToken);
        emit Log("amountAvax", amountAVAX);
        emit Log("liquidity", liquidity);
    }

    function removeLiquidityAvax(address _tokenAddress) external {
        address currPair = IJoeFactory(JOE_FACTORY).getPair(
            _tokenAddress,
            WAVAX
        );
        emit Pair("Peach/Wavax", currPair);

        uint liquidity = IERC20(currPair).balanceOf(address(this));

        IERC20(currPair).approve(JOE_ROUTER, liquidity);

        (uint peachAmount, uint avaxAmount) = IJoeRouter01(JOE_ROUTER)
            .removeLiquidityAVAX(
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

    function addLiquidityToken(
        address token1Address,
        address token2Address,
        uint token1Amount,
        uint token2Amount
    ) external {
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

    function customAddLiquidityAVAX(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountAVAXMin,
        address to
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountAVAX,
            uint256 liquidity
        )
    {
        console.log("MSG VALUE: ", msg.value);
        console.log("amountTokenDesired: ", amountTokenDesired);
        // pass msg.value
        return
            router.addLiquidityAVAX{value: msg.value}(
                token,
                amountTokenDesired,
                amountTokenMin,
                amountAVAXMin,
                to,
                block.timestamp
            );
    }

    function createJoePair(address[2] memory path) private returns (IJoePair) {
        IJoeFactory factory = IJoeFactory(router.factory());
        address newPair;
        address currPair = factory.createPair(path[0], path[1]);
        if (currPair != address(0)) {
            newPair = currPair;
        } else {
            newPair = factory.createPair(path[0], path[1]);
        }
        return IJoePair(newPair);
    }

    function getPair() public view returns (address) {
        return wavaxPeachPairAddress;
    }

    function getPair2() external view returns (address) {
        return address(pair);
    }

    function getRouter() external view returns (address) {
        return address(router);
    }

    function isAddressPair(address _pair) external view returns (bool) {
        return _pair == address(pair);
    }

    function isAddressRouter(address _router) external view returns (bool) {
        return _router == address(router);
    }

    function getPairTotalSupply() external view returns (uint) {
        return pair.totalSupply();
    }

    function checkLPTokenBalance() external view returns (uint) {
        return pair.balanceOf(msg.sender);
    }
}
