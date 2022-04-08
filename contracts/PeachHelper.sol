// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./NodeManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IJoeRouter02.sol";
import "./Pool.sol";

contract PeachHelper is Ownable {
    NodeManager public manager;
    IERC20 public PeachToken;
    IJoeRouter02 public dexRouter;
    address public lpPair;
    Pool public pool;

    using SafeMath for uint;
    using SafeMath for uint256;

    address private WAVAX;

    event Received(address, uint);

    constructor(address _manager, address _PeachToken, address _dexRouter){
        manager = NodeManager(_manager);
        PeachToken = IERC20(_PeachToken);
        pool = new Pool(_PeachToken);

        dexRouter = IJoeRouter02(_dexRouter);
        WAVAX = dexRouter.WAVAX();

        PeachToken.approve(_dexRouter, type(uint256).max);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}