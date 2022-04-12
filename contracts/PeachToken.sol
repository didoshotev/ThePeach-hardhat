// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract PeachToken is ERC20, Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    uint256 private supply = 2000000;
    uint8 private _decimals = 18;
    uint256 private _totalSupply = supply * (10 ** _decimals);

    uint256 private teamSupply = 100000;
    uint256 private vaultLock = 1000000;
    bool private isTeamLocked = false;
    bool private isVaultLocked = false;

    //DEAD - 0x000000000000000000000000000000000000dEaD
    address payable public treasuryPool;
    address payable public teamPool; 
    address payable public vault; 
    

    //ARRAY THESE VALUES
    // uint8 public liquidityPoolFee = 4;
    // uint8 public rewardsFee = 12;
    uint8 public treasuryFee = 50;
    // uint8 public teamFee = 4;

    // Track Blacklisted Addresses
    mapping(address => bool) public _isBlacklisted;

    // Keeps track of which address are excluded from fee.
    mapping (address => bool) private _isExcludedFromFee; 

    event ExcludeAccountFromFee(address account);
    event IncludeAccountInFee(address account);

    struct ValuesFromAmount {
        // Amount of tokens for to transfer.
        uint256 amount;
        // Amount tokens charged to add to liquidity.
        // uint256 tLiquidityFee;
        //Amount tokens charged to add to rewards.
        // uint256 tRewardsFee;
        // Amount tokens charged to add to treasury.
        uint256 tTreasuryFee;
        //Amount tokens charged to add to team.
        // uint256 tTeamFee;
        // Amount tokens after fees.
        uint256 tTransferAmount;
    }
    
    modifier validAddress(address _one, address _two){
        require(_one != address(0));
        require(_two != address(0));
        _;
    }

    constructor(
        // address payable _liquidityPool,
        // address payable _rewardsPool,
        address payable _treasuryPool,
        address payable _teamPool
    )
        ERC20("PEACH NODE", "PEACH") 
        validAddress(_treasuryPool, _teamPool)
         
    {
        require(
            // _liquidityPool != address(0) && 
            // _rewardsPool != address(0) && 
            _treasuryPool != address(0) && 
            _teamPool != address(0),
            "LIQUIDITY/REWARDS/TREASURY/TEAM POOL ADDRESS CANNOT BE ZERO"
        );

        //Set Pool Addresses
        // liquidityPool = _liquidityPool;
        // rewardsPool = _rewardsPool;
        treasuryPool = _treasuryPool;
        teamPool = _teamPool;
        
        //Mint
        _mint(_msgSender(), _totalSupply);

        // exclude owner and this contract from fees.
        excludeAccountFromFee(msg.sender);
        excludeAccountFromFee(address(this));
        excludeAccountFromFee(treasuryPool);
        // excludeAccountFromFee(rewardsPool);
        // excludeAccountFromFee(liquidityPool);
        // excludeAccountFromFee(treasuryPool);

        emit Transfer(address(0), _msgSender(), _totalSupply);
        emit OwnershipTransferred(address(0), _msgSender());
    }

    // allow the contract to receive AVAX
    //test on testnet
    receive() external payable {}

    // function updateLiquidityPool(address payable pool) external onlyOwner {
    //     liquidityPool = pool;
    // }

    // function updateRewardsPool(address payable pool) external onlyOwner {
    //     rewardsPool = pool;
    // }

    function updateTreasuryPool(address payable pool) external onlyOwner {
        treasuryPool = pool;
    }
    // function updateteamPool(address payable pool) external onlyOwner {
    //     teamPool = pool;
    // }

    // function updateRewardsFee(uint8 value) external onlyOwner {
    //     rewardsFee = value;
    // }

    function updateTreasuryFee(uint8 value) external onlyOwner {
        treasuryFee = value;
    }

    // function updateteamFee(uint8 value) external onlyOwner {
    //     teamFee = value;
    // }

    // function updateLiquidityFee(uint8 value) external onlyOwner {
    //     liquidityPoolFee = value;
    // }

    function blacklistMalicious(address account, bool value)
        external
        onlyOwner
    {
        _isBlacklisted[account] = value;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    //TEST TRANSFER FUNCTION
    function _transfer(address sender, address recipient, uint256 amount) 
    validAddress(sender,recipient) 
    internal 
    override 
    {
        require(!_isBlacklisted[sender] && !_isBlacklisted[recipient],"Blacklisted address");
        
        uint256 amountReceived = amount * (10 ** _decimals);
        
        bool takeFee = true;
        ValuesFromAmount memory values = _getValues(amountReceived, _isExcludedFromFee[sender]);
        
        if(_isExcludedFromFee[sender] || _isExcludedFromFee[recipient]){
            takeFee = false;
        }

        if (takeFee) {
            amountReceived=values.tTransferAmount;

            super._transfer(sender, treasuryPool, values.tTreasuryFee);
            // super._transfer(sender, rewardsPool, values.tRewardsFee);
            // super._transfer(sender, teamPool, values.tTeamFee);
            // super._transfer(sender, liquidityPool, values.tLiquidityFee);
        }

        super._transfer(sender, recipient, amountReceived);
        emit Transfer(sender, recipient, amountReceived);
    }

    // Allocate Team Wallet Tokens
    function lockInTeamWallet() public onlyOwner {
        require(isTeamLocked == false);
        isTeamLocked=true;
        transfer(teamPool, teamSupply);
    }

    function lockInVaultWallet(address payable recipient) public onlyOwner {
        require(isVaultLocked == false);
        vault = recipient;
        isVaultLocked=true;
        transfer(vault, vaultLock);
    }

    function isExcludedFromFee(address account) external view returns (bool) {
        return _isExcludedFromFee[account];
    }
    
    function excludeAccountFromFee(address account) public onlyOwner {
        require(!_isExcludedFromFee[account], "Account is already excluded.");

        _isExcludedFromFee[account] = true;

        emit ExcludeAccountFromFee(account);
    }

    function includeAccountInFee(address account) public onlyOwner {
        require(_isExcludedFromFee[account], "Account is already included.");

        _isExcludedFromFee[account] = false;

        emit IncludeAccountInFee(account);
    }

    function _getValues(uint256 amount, bool deductTransferFee) private view returns (ValuesFromAmount memory) {
        ValuesFromAmount memory values;
        values.amount = amount;
        _getTValues(values, deductTransferFee);
        return values;
    }

    function _getTValues(ValuesFromAmount memory values, bool deductTransferFee) view private {

        if (deductTransferFee) {
            values.tTransferAmount = values.amount;
        } else {
            // calculate fee
            // values.tRewardsFee = _calculateTax(values.amount, rewardsFee, 0);
            // values.tLiquidityFee = _calculateTax(values.amount, liquidityPoolFee, 0);
            values.tTreasuryFee = _calculateTax(values.amount, treasuryFee, 0);
            // values.tTeamFee = _calculateTax(values.amount, teamFee, 0);
            
            // amount after fee
            values.tTransferAmount = 
            values.amount - 
            // values.tRewardsFee - 
            // values.tLiquidityFee - 
            values.tTreasuryFee; 
            // values.tTeamFee;
        }
    }

    function _calculateTax(uint256 amount, uint8 tax, uint8 taxDecimals_) private pure returns (uint256) {
        return amount * tax / (10 ** taxDecimals_) / (10 ** 2);
    }
}
