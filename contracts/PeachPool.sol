// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IJoeRouter02.sol";
import "./interfaces/IJoeFactory.sol";
import "./interfaces/IJoePair.sol";

// add/remove liquidity

contract PeachPool {
    address public immutable WAVAX;
    address PEACH_TOKEN;
    address public wavaxPeachPairAddress;

    address private JOE_FACTORY;
    address private JOE_ROUTER;

    IJoeRouter02 private router; // use this
    IJoeFactory private factory;
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
        router = IJoeRouter02(_router);
        pair = createJoePair(path);
        factory = IJoeFactory(pair.factory());

        PEACH_TOKEN = _peachToken;
        WAVAX = _WAVAX;

        JOE_FACTORY = _factory;
        JOE_ROUTER = _router;
        // wavaxPeachPairAddress = IJoeFactory(JOE_FACTORY).createPair(PEACH_TOKEN, _WAVAX);
    }

    receive() external payable {}

    function addLiquidityAvax(address _tokenAddress, uint _tokenAmount)
        external
        payable
    {
        IERC20(_tokenAddress).transferFrom(
            msg.sender,
            address(this),
            _tokenAmount
        );
        IERC20(_tokenAddress).approve(address(router), _tokenAmount);
        // IERC20(_tokenAddress).approve(router.factory(), _tokenAmount);

        router.addLiquidityAVAX{value: msg.value}(
            _tokenAddress,
            _tokenAmount,
            1,
            1,
            msg.sender,
            block.timestamp
        );
    }

    function swapExactTokensForAVAX(
        address _tokenAddress,
        uint256 _tokenAmount,
        address[] calldata path
    ) external returns (uint[] memory amount) {
        IERC20(_tokenAddress).approve(address(router), _tokenAmount);

        IERC20(_tokenAddress).transferFrom(
            msg.sender,
            address(this),
            _tokenAmount
        );

        uint[] memory amounts = router.swapExactTokensForAVAX(
            _tokenAmount,
            0,
            path,
            msg.sender,
            block.timestamp
        );
        return amounts;
    }

    function swapAVAXForExactTokens(
        address _tokenAddress,
        uint256 _tokenAmount,
        address[] calldata path
    ) external payable returns (uint[] memory amount) {
        IERC20(_tokenAddress).approve(address(router), _tokenAmount);

        return
            router.swapAVAXForExactTokens{value: msg.value}(
                _tokenAmount,
                path,
                msg.sender,
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
