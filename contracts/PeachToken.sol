// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./IJoeRouter02.sol";
import "./IJoeFactory.sol";
import "./NodeManager.sol";

contract PeachNode is ERC20, Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    uint256 private supply = 2000000;
    uint8 private _decimals = 18;
    uint256 private _tTotal = supply * (10 ** _decimals);
    
    address payable public liquidityPool;
    address payable public rewardsPool;
    address payable public treasuryPool; 
    address payable public teamPool;

    uint8 public liquidityPoolFee = 4;
    uint8 public rewardsFee = 12;
    uint8 public treasuryFee = 30;
    uint8 public teamFee = 4;

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
        uint256 tLiquidityFee;
        //Amount tokens charged to add to rewards.
        uint256 tRewardsFee;
        // Amount tokens charged to add to treasury.
        uint256 tTreasuryFee;
        //Amount tokens charged to add to marketing.
        uint256 tTeamFee;
        // Amount tokens after fees.
        uint256 tTransferAmount;

    }

    constructor(
        address payable _liquidityPool,
        address payable _rewardsPool,
        address payable _treasuryPool,
        address payable _marketingPool
    )
        ERC20("PEACH NODE", "PEACH")
    {

        excludeAccountFromFee(msg.sender);
        excludeAccountFromFee(address(this));

        //Set Pool Addresses
        liquidityPool = _liquidityPool;
        rewardsPool = _rewardsPool;
        treasuryPool = _treasuryPool;
        teamPool = _marketingPool;

        require(
            liquidityPool != address(0) && 
            rewardsPool != address(0) && 
            treasuryPool != address(0) && 
            teamPool != address(0),
            "LIQUIDITY/REWARDS/TREASURY/MARKETING POOL ADDRESS CANNOT BE ZERO"
        );
    }

    function updateLiquidityPool(address payable pool) external onlyOwner {
        liquidityPool = pool;
    }

    function updateRewardsPool(address payable pool) external onlyOwner {
        rewardsPool = pool;
    }
    function updateTreasuryPool(address payable pool) external onlyOwner {
        treasuryPool = pool;
    }
    function updateMarketingPool(address payable pool) external onlyOwner {
        teamPool = pool;
    }

    function updateRewardsFee(uint8 value) external onlyOwner {
        rewardsFee = value;
    }

    function updateTreasuryFee(uint8 value) external onlyOwner {
        treasuryFee = value;
    }

    function updateMarketingFee(uint8 value) external onlyOwner {
        teamFee = value;
    }

    function updateLiquidityFee(uint8 value) external onlyOwner {
        liquidityPoolFee = value;
    }

    function blacklistMalicious(address account, bool value)
        external
        onlyOwner
    {
        _isBlacklisted[account] = value;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal override {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(!_isBlacklisted[sender] && !_isBlacklisted[recipient],"Blacklisted address");
        
        ValuesFromAmount memory values = _getValues(amount, _isExcludedFromFee[sender]);
        
        emit Transfer(sender, recipient, values.tTransferAmount);
        super._transfer(sender, treasuryPool, values.amount - values.tTransferAmount);
        

    }

    function isExcludedFromFee(address account) external view returns (bool) {
        return _isExcludedFromFee[account];
    }
    
    function excludeAccountFromFee(address account) internal {
        require(!_isExcludedFromFee[account], "Account is already excluded.");

        _isExcludedFromFee[account] = true;

        emit ExcludeAccountFromFee(account);
    }

    function includeAccountInFee(address account) internal {
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
            values.tRewardsFee = _calculateTax(values.amount, rewardsFee, 0);
            values.tLiquidityFee = _calculateTax(values.amount, liquidityPoolFee, 0);
            values.tTreasuryFee = _calculateTax(values.amount, treasuryFee, 0);
            values.tTeamFee = _calculateTax(values.amount, teamFee, 0);

            // amount after fee
            values.tTransferAmount = values.amount - values.tRewardsFee - values.tLiquidityFee - values.tTreasuryFee - values.tTeamFee;
        }
    }

    function _calculateTax(uint256 amount, uint8 tax, uint8 taxDecimals_) private pure returns (uint256) {
        return amount * tax / (10 ** taxDecimals_) / (10 ** 2);
    }
}
