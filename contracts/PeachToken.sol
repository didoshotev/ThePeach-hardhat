// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract PeachNode is ERC20, Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    uint256 private supply = 2000000;
    uint8 private _decimals = 18;
    uint256 private _totalSupply = supply * (10 ** _decimals);

    // A number that helps distributing fees to all holders respectively.
    uint256 private _Total;
    
    address payable public liquidityPool;
    address payable public rewardsPool;
    address payable public treasuryPool; 
    address payable public teamPool;

    uint8 public liquidityPoolFee = 4;
    uint8 public rewardsFee = 12;
    uint8 public treasuryFee = 30;
    uint8 public teamFee = 4;

    // Keeps track of balances 
    mapping (address => uint256) private _balances;

    // Track Blacklisted Addresses
    mapping(address => bool) public _isBlacklisted;

    // Keeps track of which address are excluded from fee.
    mapping (address => bool) private _isExcludedFromFee;

    // ERC20 Token Standard
    mapping (address => mapping (address => uint256)) private _allowances;

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

        _Total =  _totalSupply ;


        //Mint
        _balances[_msgSender()] = _Total;

        // exclude owner and this contract from fees.
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

        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    // allow the contract to receive AVAX
    receive() external payable {}

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

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal override {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(!_isBlacklisted[sender] && !_isBlacklisted[recipient],"Blacklisted address");
        
        ValuesFromAmount memory values = _getValues(amount, _isExcludedFromFee[sender]);
        
        _transferStandard(sender, recipient, values);
        emit Transfer(sender, recipient, values.tTransferAmount);
        super._transfer(sender, treasuryPool, values.amount - values.tTransferAmount);
        
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        require(_allowances[sender][_msgSender()] >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()] - amount);
        return true;
    }

    function _transferStandard(address sender, address recipient, ValuesFromAmount memory values) private {
        _balances[sender] = _balances[sender] - values.amount;
        _balances[recipient] = _balances[recipient] + values.tTransferAmount;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return (_balances[account]);
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
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
