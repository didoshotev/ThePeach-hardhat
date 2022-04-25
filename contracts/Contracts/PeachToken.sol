//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./helpers/LimiterTaxImplementationPoint.sol";

contract PeachToken is ERC20, Ownable, ReentrancyGuard, LimiterTaxImplementationPoint {
    using SafeMath for uint256;
     mapping (address => uint256) private _balances;
    uint256 private supply = 2000000;
    uint8 private _decimals = 18;
    uint256 private _totalSupply = supply * (10 ** _decimals);

    uint256 private teamSupply = 100000 * (10 ** _decimals);
    uint256 private vaultLock = 1000000 * (10 ** _decimals);
    bool private isTeamLocked = false;
    bool private isVaultLocked = false;

    address payable public treasuryPool;
    address payable public teamPool; 
    address payable public vault; 
    
    // Track Blacklisted Addresses
    mapping(address => bool) public _isBlacklisted;

    // Keeps track of which address are excluded from fee.
    mapping (address => bool) private _isExcludedFromFee; 

    event ExcludeAccountFromFee(address account);
    event IncludeAccountInFee(address account);
    
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
        setFeeExempt(owner(), true );
        setFeeExempt(address(this), true );
        setFeeExempt(treasuryPool, true );
        setFeeExempt(teamPool, true );
        emit Transfer(address(0), _msgSender(), _totalSupply);
        emit OwnershipTransferred(address(0), _msgSender());
    }

    // allow the contract to receive AVAX
    //test on testnet
    receive() external payable {}

    function updateTreasuryPool(address payable pool) external onlyOwner {
        treasuryPool = pool;
    }

    function blacklistMalicious(address account, bool value)
        external
        onlyOwner
    {
        _isBlacklisted[account] = value;
    }

    function _transfer(address sender, address recipient, uint256 amount) 
    validAddress(sender,recipient) 
    internal 
    override 
    {
        require(!_isBlacklisted[sender] && !_isBlacklisted[recipient],"Blacklisted address");

        uint currentFeeAmount;
        uint256 amountReceived = shouldTakeFee(sender) ? limiterTax.takeFee(sender, recipient, amount) : amount;
        unchecked {
          currentFeeAmount = amount - amountReceived;  
        } 
        
        if (currentFeeAmount > 0){
            unchecked {
                _balances[sender] -= amount;
                _balances[treasuryPool] += currentFeeAmount;
                _balances[recipient] += amountReceived;    
            }
        }
        else {
            unchecked {
                _balances[sender] -= amount;
                _balances[recipient] += amount;
            }
        }
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
    
    function setFeeExempt(address account, bool exempt) public onlyOwner {
        _isExcludedFromFee[account] = exempt;
    }

    //view funtcion
    function shouldTakeFee(address sender) internal view returns(bool){
        return !_isExcludedFromFee[sender];
    }

}
