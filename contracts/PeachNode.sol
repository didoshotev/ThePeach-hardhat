// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./NodeManager.sol";
import "./IJoeRouter02.sol";
import "./IJoeFactory.sol";

contract PEACH is ERC20, Ownable {
    using SafeMath for uint256;

    //NODE REWARD MANAGER
    NodeManager public nodeRewardManager;

    IJoeRouter02 public dexRouter;
    address public lpPair;

    //Initial Supply
    uint public _totalSupply;
    uint16 private _decimals = 18;

    uint private totalTokens = _totalSupply * (10 ** _decimals);

    // JOE ROUTER
    // TESTNET ROUTER 0x2D99ABD9008Dc933ff5c0CD271B88309593aB921
    // MAINNET ROUTER 0x60aE616a2155Ee3d9A68541Ba4544862310933d4

    address private _routerAddress = 0x60aE616a2155Ee3d9A68541Ba4544862310933d4;
    address public deadWallet = 0x000000000000000000000000000000000000dEaD;
    
    address public liquidityPool;
    address public rewardsPool;
    address public treasuryPool;
    address public marketingPool;

    uint256 public liquidityPoolFee;
    uint256 public rewardsFee;
    uint256 public treasuryFee;
    uint256 public marketingFee;

    uint256 public cashoutFee;
    uint256 public totalFees;
    

    uint256 private rwSwap;
    bool private swapping = false;
    bool private swapLiquifyEnabled = false;
    uint256 public swapTokensAmount;

    // Track Blacklisted Addresses
    mapping(address => bool) public _isBlacklisted;

    // Market Pairs
    mapping(address => bool) public automatedMarketMakerPairs;

    //Trader Joe Router Updated
    event UpdateJoeV2Router(
        address indexed newAddress,
        address indexed oldAddress
    );

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event LiquidityWalletUpdated(
        address indexed newLiquidityWallet,
        address indexed oldLiquidityWallet
    );

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    constructor(
        uint256 swapAmount,
        uint256 claimTime,
        address _dexRouter
    )
        ERC20("PEACH NODES", "PEACH")
    {
        _totalSupply =  2000000;
        require(claimTime > 0, "CONSTR: claimTime incorrect");

        require(
            liquidityPool != address(0) && rewardsPool != address(0),
            "FUTUR & REWARD ADDRESS CANNOT BE ZERO"
        );

        require(swapAmount > 0, "CONSTR: Swap amount incorrect");
        swapTokensAmount = swapAmount * (10**18);

        //SET ROUTER
        dexRouter = IJoeRouter02(_dexRouter);
    }

    // Liquidity functions

    // Create AVAX / PEACH Liquidity Pair
    function setJoeV2RouterAndCreatePair() public onlyOwner {
        IJoeRouter02 _dexRouter = IJoeRouter02(_routerAddress);
        lpPair = IJoeFactory(_dexRouter.factory()).createPair(
            address(this),
            _dexRouter.WAVAX()
        );

        dexRouter = _dexRouter;
        _setAutomatedMarketMakerPair(lpPair, true);
    }

    //SET NODE MANAGER
    function setNodeManagement(address nodeManagement) external onlyOwner {
        nodeRewardManager = NodeManager(nodeManagement);
    }

    function updateJoeV2RouterAddress(address newAddress) public onlyOwner {
        require(
            newAddress != address(dexRouter),
            "This router address is already set"
        );
        emit UpdateJoeV2Router(newAddress, address(dexRouter));
        dexRouter = IJoeRouter02(newAddress);
        address _joeV2Pair = IJoeFactory(dexRouter.factory()).createPair(
            address(this),
            dexRouter.WAVAX()
        );
        lpPair = _joeV2Pair;
    }

    //Update Tokens Swapp
    function updateSwapTokensAmount(uint256 newVal) external onlyOwner {
        swapTokensAmount = newVal;
    }

    //Update Address Of Liquidity Pool
    function updateLiquidityPool(address payable pool) external onlyOwner {
        liquidityPool = pool;
    }

    //Update Address Of Rewards Pooln
    function updateRewardsPool(address payable pool) external onlyOwner {
        rewardsPool = pool;
    }
    function updateTreasuryPool(address payable pool) external onlyOwner {
        treasuryPool = pool;
    }
    function updateMarketingPool(address payable pool) external onlyOwner {
        marketingPool = pool;
    }

    function updateRewardsFee(uint256 value) external onlyOwner {
        rewardsFee = value;
        totalFees = rewardsFee.add(liquidityPoolFee);
    }

    function updateLiquidityFee(uint256 value) external onlyOwner {
        liquidityPoolFee = value;
        totalFees = rewardsFee.add(liquidityPoolFee);
    }

    function updateCashoutFee(uint256 value) external onlyOwner {
        cashoutFee = value;
    }

    function updateRwSwapFee(uint256 value) external onlyOwner {
        rwSwap = value;
    }

    function setAutomatedMarketMakerPair(address pair, bool value)
        public
        onlyOwner
    {
        require(
            pair != lpPair,
            "TKN: The Trader Joe pair cannot be removed from automatedMarketMakerPairs"
        );

        _setAutomatedMarketMakerPair(pair, value);
    }

    function blacklistMalicious(address account, bool value)
        external
        onlyOwner
    {
        _isBlacklisted[account] = value;
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        require(
            automatedMarketMakerPairs[pair] != value,
            "TKN: Automated market maker pair is already set to that value"
        );
        automatedMarketMakerPairs[pair] = value;

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(
            !_isBlacklisted[from] && !_isBlacklisted[to],
            "Blacklisted address"
        );

        super._transfer(from, to, amount);
    }

    //Swap Tokens for AVAX
    function swapAndSendToFee(address destination, uint256 tokens) private {
        uint256 initialAVAXBalance = address(this).balance;

        swapTokensForAVAX(tokens);
        uint256 newBalance = (address(this).balance).sub(initialAVAXBalance);
        payable(destination).transfer(newBalance);
    }

    //Swap Half Tokens Liquify Half Tokens
    function swapAndLiquify(uint256 tokens) private {
        uint256 half = tokens.div(2);
        uint256 otherHalf = tokens.sub(half);
        uint256 initialBalance = address(this).balance;
        swapTokensForAVAX(half);

        uint256 newBalance = address(this).balance.sub(initialBalance);
        addLiquidity(otherHalf, newBalance);
        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    //Token to AVAX Swap
    function swapTokensForAVAX(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = dexRouter.WAVAX();

        _approve(address(this), address(dexRouter), tokenAmount);

        dexRouter.swapExactTokensForAVAXSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of AVAX
            path,
            address(this),
            block.timestamp
        );
    }

    // Add Liquidity
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token
        _approve(address(this), address(dexRouter), tokenAmount);

        dexRouter.addLiquidityAVAX{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            liquidityPool,
            block.timestamp
        );
    }

    // Create Node
    function createNodeWithTokens(string memory name) public {
        address sender = _msgSender();
        uint256 nodePrice = nodeRewardManager.nodePrice();
        require(
            bytes(name).length > 3 && bytes(name).length < 32,
            "NODE CREATION: NAME SIZE INVALID"
        );
        require(
            sender != address(0),
            "NODE CREATION:  creation from the zero address"
        );
        require(!_isBlacklisted[sender], "NODE CREATION: Blacklisted address");
        require(
            sender != liquidityPool && sender != rewardsPool,
            "NODE CREATION: liquidityPool and rewardsPool cannot create node"
        );
        require(
            balanceOf(sender) >= nodeRewardManager._getNodePrice(),
            "NODE CREATION: Balance too low for creation."
        );

        super._transfer(sender, address(this), nodePrice);
        nodeRewardManager.createNode(sender, name);
    }

    // Claim Rewards
    function claimRewards() public {
        address sender = _msgSender();
        require(
            sender != address(0),
            "CASHOUT: zero address cannot cash out rewards"
        );
        require(
            !_isBlacklisted[sender],
            "CASHOUT: Blacklisted address cannot cash out rewards"
        );
        require(
            sender != liquidityPool && sender != rewardsPool,
            "CASHOUT: future and rewardsPool cannot cashout rewards"
        );
        uint256 rewardAmount = nodeRewardManager._getRewardAmountOf(sender);
        require(
            rewardAmount > 0,
            "CASHOUT: You don't have enough reward to cash out"
        );
        if (swapLiquifyEnabled) {
            uint256 feeAmount;
            if (cashoutFee > 0) {
                feeAmount = rewardAmount.mul(cashoutFee).div(100);
                swapAndSendToFee(liquidityPool, feeAmount);
            }
            rewardAmount -= feeAmount;
        }
        super._transfer(rewardsPool, sender, rewardAmount);
        nodeRewardManager._cashoutAllNodesReward(sender);
    }

    //Change Liquidity Swap Amount
    function changeSwapLiquify(bool newVal) public onlyOwner {
        swapLiquifyEnabled = newVal;
    }

    //View Number Of Nodes For Address
    function getNodeNumberOf(address account) public view returns (uint256) {
        return nodeRewardManager._getNodeNumberOf(account);
    }

    //View Total Reward Amount
    function getRewardAmount() public view returns (uint256) {
        require(msg.sender != address(0), "SENDER CAN'T BE ZERO");
        require(nodeRewardManager._isNodeOwner(msg.sender), "NO NODE OWNER");
        return nodeRewardManager._getRewardAmountOf(msg.sender);
    }


    // function changeNodePrice(uint256 newNodePrice) public onlyOwner {
    //     nodeRewardManager._changeNodePrice(newNodePrice);
    // }

    // function getNodePrice() public view returns (uint256) {
    //     return nodeRewardManager._getNodePrice();
    // }

    // function changeRewardPerNode(uint256 newPrice) public onlyOwner {
    //     nodeRewardManager._changeRewardPerNode(newPrice);
    // }

    // function getRewardPerNode() public view returns (uint256) {
    //     return nodeRewardManager._getRewardPerNode();
    // }

    //Set Auto Distribution Of Rewards Bool
    function changeAutoDistri(bool newMode) public onlyOwner {
        nodeRewardManager._changeAutoDistri(newMode);
    }

    //Change Gas For Rewards Distribution
    function changeGasDistri(uint256 newGasDistri) public onlyOwner {
        nodeRewardManager._changeGasDistri(newGasDistri);
    }

    //View Node Names
    function getNodesNames() public view returns (string memory) {
        require(_msgSender() != address(0), "SENDER CAN'T BE ZERO");
        require(nodeRewardManager._isNodeOwner(_msgSender()), "NO NODE OWNER");
        return nodeRewardManager._getNodesNames(_msgSender());
    }

    //View Time Since First Node Created
    function getNodesCreatime() public view returns (string memory) {
        require(_msgSender() != address(0), "SENDER CAN'T BE ZERO");
        require(nodeRewardManager._isNodeOwner(_msgSender()), "NO NODE OWNER");
        return nodeRewardManager._getNodesCreationTime(_msgSender());
    }

    //View Rewards Available
    function getNodesRewards() public view returns (string memory) {
        require(_msgSender() != address(0), "SENDER CAN'T BE ZERO");
        require(nodeRewardManager._isNodeOwner(_msgSender()), "NO NODE OWNER");
        return nodeRewardManager._getNodesRewardAvailable(_msgSender());
    }

    //View Time Since Last Claim
    function getNodesLastClaims() public view returns (string memory) {
        require(_msgSender() != address(0), "SENDER CAN'T BE ZERO");
        require(nodeRewardManager._isNodeOwner(_msgSender()), "NO NODE OWNER");
        return nodeRewardManager._getNodesLastClaimTime(_msgSender());
    }

    //Distribute Rewards To Node Owners
    function distributeRewards()
        public
        onlyOwner
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return nodeRewardManager._distributeRewards();
    }
    
}