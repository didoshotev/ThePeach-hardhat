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
    
    uint8 public treasuryFee = 50;

    // Track Blacklisted Addresses
    mapping(address => bool) public _isBlacklisted;

    // Keeps track of which address are excluded from fee.
    mapping (address => bool) private _isExcludedFromFee; 

    event ExcludeAccountFromFee(address account);
    event IncludeAccountInFee(address account);

    struct ValuesFromAmount {
        // Amount of tokens for to transfer.
        uint256 amount;
        // Amount tokens charged to add to treasury.
        uint256 tTreasuryFee;
        // Amount tokens after fees.
        uint256 tTransferAmount;
    }
    
    modifier validAddress(address _one, address _two){
        require(_one != address(0));
        require(_two != address(0));
        _;
    }

    constructor(
        address payable _treasuryPool,
        address payable _teamPool
    )
        ERC20("PEACH NODE", "PEACH") 
        validAddress(_treasuryPool, _teamPool)
         
    {

        //Set Pool Addresses
        treasuryPool = _treasuryPool;
        teamPool = _teamPool;
        
        //Mint
        _mint(_msgSender(), _totalSupply);

        // exclude owner and this contract from fees.
        excludeAccountFromFee(msg.sender);
        excludeAccountFromFee(address(this));
        excludeAccountFromFee(treasuryPool);
        excludeAccountFromFee(teamPool);

        emit Transfer(address(0), _msgSender(), _totalSupply);
        emit OwnershipTransferred(address(0), _msgSender());
    }

    // allow the contract to receive AVAX
    //test on testnet
    receive() external payable {}

    function updateTreasuryPool(address payable pool) external onlyOwner {
        treasuryPool = pool;
    }

    function updateTreasuryFee(uint8 value) external onlyOwner {
        treasuryFee = value;
    }

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

    // Set Vault Wallet and Allocate Funds
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
            values.tTreasuryFee = _calculateTax(values.amount, treasuryFee, 0);
            
            // amount after fee
            values.tTransferAmount = 
            values.amount - 
            values.tTreasuryFee; 
        }
    }

    function _calculateTax(uint256 amount, uint8 tax, uint8 taxDecimals_) private pure returns (uint256) {
        return amount * tax / (10 ** taxDecimals_) / (10 ** 2);
    }
}
