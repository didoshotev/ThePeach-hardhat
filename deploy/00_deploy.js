const { ethers } = require("hardhat");
const hre = require("hardhat");

module.exports = async (hre) => {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer, walletAccount: teamWallet, treasury } = await getNamedAccounts();
    const namedAccounts = await getNamedAccounts();
    console.log('namedAccounts: ', namedAccounts);

    await deploy("PeachToken", { 
        from: deployer,
        args: [treasury, teamWallet],
        log: true,
        autoMine: true
    })
}