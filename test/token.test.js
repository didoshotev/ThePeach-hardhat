const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { BN, constants, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const { ZERO_ADDRESS, MAX_UINT256 } = constants;

let Token;
let Peach;
let owner;
let addr1;
let addr2;
let addrs;


beforeEach(async function () {
    Token = await ethers.getContractFactory("PeachNode");
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
    Peach = await Token.deploy(
        "0x000000000000000000000000000000000000dEaD",
        "0x000000000000000000000000000000000000dEaD",
        "0x000000000000000000000000000000000000dEaD",
        "0x000000000000000000000000000000000000dEaD"
    );
    await Peach.deployed();
})

describe("PEACH Token Deployment", function () {
    it("Should be deployed", async function () {
        expect(await Peach.symbol()).to.equal("PEACH");
    });

    it("Should set the right owner", async function () {
      expect(await Peach.owner()).to.equal(owner.address);
    });
});


describe("Transactions", function () {
    it("Owner Should Have 2 Million Tokens", async function () {
        let  supply = 2000000;
        let  _decimals = 18;
        let  _totalSupply = supply * (10 ** _decimals);
        
        // Get Balance Of Owner
        const ownerBalance = await Peach.balanceOf(
            owner.address
        );
        assert.equal(ownerBalance,_totalSupply, 'Tokens Minted To Owner')
    });

    it("Owner Should Transfer 50 Tokens to Address 1 using Transfer", async function () {
        // Transfer 50 tokens from addr1 to addr2
        // We use .connect(signer) to send a transaction from another account
        await Peach.connect(owner).transfer(addr1.address, 50);
        const addr1Balance = await Peach.balanceOf(
            addr1.address
        );

        expect(addr1Balance).to.equal(50);
    });

    it("Owner Should Transfer 50 Tokens to Address 1 using transferFrom", async function () {
        // Transfer 50 tokens from addr1 to addr2
        // We use .connect(signer) to send a transaction from another account
        await Peach.connect(owner).transferFrom(owner.address, addr1.address, 50);
        const addr1Balance = await Peach.balanceOf(
            addr1.address
        );

        expect(addr1Balance).to.equal(50);
    });
    it("Transfer Tax Between Address 1 and 2", async function () {
        // Transfer 50 tokens from addr1 to addr2
        // We use .connect(signer) to send a transaction from another account
        await Peach.connect(owner).transferFrom(owner.address, addr1.address, 50);
        const addr1Balance = await Peach.balanceOf(
            addr1.address
        );

        expect(addr1Balance).to.equal(50);
        // Transfer 50 tokens from addr1 to addr2
        // We use .connect(signer) to send a transaction from another account
        await Peach.connect(addr1).transfer(addr2.address, 50);
        const addr2Balance = await Peach.balanceOf(
            addr2.address
        );
        expect(addr2Balance).to.equal(25);
    });

    it("Should fail if sender doesn’t have enough tokens", async function () {
        const initialOwnerBalance = await Peach.balanceOf(
          owner.address
        );
  
        // Try to send 1 token from addr1 (0 tokens) to owner (1000 tokens).
  
        // Owner balance shouldn't have changed.
        expect(await Peach.balanceOf(owner.address)).to.equal(
          initialOwnerBalance
        );
      });

      it("Should update balances after transfers", async function () {
        const initialOwnerBalance = await Peach.balanceOf(
          owner.address
        );
  
        // Transfer 100 tokens from owner to addr1.
        await Peach.transfer(addr1.address, 100);
  
        // Transfer another 50 tokens from owner to addr2.
        await Peach.transfer(addr2.address, 50);
  
        // Check balances.
        const finalOwnerBalance = await Peach.balanceOf(
          owner.address
        );
        expect(finalOwnerBalance < initialOwnerBalance);
  
        const addr1Balance = await Peach.balanceOf(
          addr1.address
        );
        expect(addr1Balance).to.equal(100);
  
        const addr2Balance = await Peach.balanceOf(
          addr2.address
        );
        expect(addr2Balance).to.equal(50);
      });

      it("Team Wallet Tokens Should Be Allocated", async function (){
        let  supply = 2000000;
        let  _decimals = 18;
        let  _totalSupply = supply * (10 ** _decimals);
        let lock = 100000;
        let lockedSupply = lock * (10 ** _decimals);
        // Get Balance Of Owner
        const ownerBalance = await Peach.balanceOf(
            owner.address
        );
        assert.equal(ownerBalance,_totalSupply, 'Tokens Minted To Owner')

        await Peach.lockInTeamWallet(addr1.address);
        
        const addr1Balance = await Peach.balanceOf(addr1.address);
        
        assert.equal(addr1Balance,lockedSupply, 'Team Wallet Tokens Sent')
      })
      
});