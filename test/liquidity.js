const { expect } = require("chai");
const hre = require("hardhat");
const { ethers } = require("hardhat");


describe("PeachHelper", () => { 
    let deployer, walletAccount, treasury;

    before(async () => { 
        const provider = ethers.getDefaultProvider();
        const peachToken = await ethers.getContractAt("PeachToken", "0xf29276E84E241a1EB217a1e52e43426ec62097fa");
        const signers = await ethers.getSigners();
        // console.log('signers: ', signers);
        const accounts = await ethers.getSigners();
        deployer = accounts[0];
        walletAccount = accounts[1];
        treasury = accounts[2];

        console.log('deployer: ',  deployer.address);
        console.log('walletAcc: ', walletAccount.address);
        console.log('treasury: ', treasury.address);

        const balanceAvaxDeployer = await provider.getBalance(deployer.address);
        console.log('balanceAvaxDeployer: ', balanceAvaxDeployer);
    })

    it("Test 1", () => { 
        expect(1).equal(1);
    })
})