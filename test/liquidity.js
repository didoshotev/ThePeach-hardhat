const { expect } = require("chai");
const JOE_ROUTER_ABI = require("../abi/joe_router_abi.json");
const JOE_FACTORY_ABI = require("../abi/joe_factory_abi.json");
const WAVAX_ABI = require("../abi/wavax_abi.json");
const JOE_PAIR_ABI = require("../abi/joe_pair_abi.json");
const hre = require("hardhat");
const { ethers, network } = require("hardhat");

const amount100 = ethers.utils.parseEther("100");

const WAVAX_ADDRESS = "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7";
const JOE_ROUTER_ADDRESS = '0x60aE616a2155Ee3d9A68541Ba4544862310933d4';
let JOE_FACTORY_ADDRESS;

describe("PeachHelper", function () {
    // accounts
    let peachOwner, walletAccount, treasury;

    // joe contracts
    let joeRouterContract, joeFactoryContract

    //tokens
    let peachToken, wavaxContract, peachWavax

    // peach contracts
    let limiter, peachHelper

    before(async () => {

        //accounts
        const accounts = await ethers.getSigners();
        peachOwner = accounts[0];
        walletAccount = accounts[1];
        treasury = accounts[2];

        // tokens
        wavaxContract = await ethers.getContractAt(WAVAX_ABI, WAVAX_ADDRESS);
        const PeachToken = await ethers.getContractFactory("PeachToken");
        peachToken = await PeachToken.connect(peachOwner).deploy(treasury.address, walletAccount.address);

        // joe contracts
        joeRouterContract = await ethers.getContractAt(JOE_ROUTER_ABI, JOE_ROUTER_ADDRESS);
        JOE_FACTORY_ADDRESS = await joeRouterContract.factory();
        console.log('JOE_FACTORY_ADDRESS: ', JOE_FACTORY_ADDRESS);
        joeFactoryContract = await ethers.getContractAt(JOE_FACTORY_ABI, JOE_FACTORY_ADDRESS);

        // peach contracts
        const LimiterContract = await ethers.getContractFactory("LimiterTax");
        limiter = await LimiterContract.connect(peachOwner).deploy(10, 50, [peachToken.address, WAVAX_ADDRESS], treasury.address);

        const peachWavaxAddress = await joeFactoryContract.getPair(peachToken.address, WAVAX_ADDRESS);
        peachWavax = await ethers.getContractAt(JOE_PAIR_ABI, peachWavaxAddress);

        expect(peachWavax.address).equal(peachWavaxAddress);

        const PeachHelper = await ethers.getContractFactory("PeachHelper");
        peachHelper = await PeachHelper.connect(peachOwner).deploy(peachToken.address, peachWavax.address, JOE_ROUTER_ADDRESS);
    })

    beforeEach(async () => {
        await ethers.provider.send(
            "hardhat_reset",
            [
                {
                    forking: {
                        jsonRpcUrl: "https://api.avax.network/ext/bc/C/rpc",
                        blockNumber: 2975762,
                    }
                }
            ]
        );

        // send avax to peachOwner
        await wavaxContract.connect(peachOwner).deposit({
            value: amount100
        })
        const currBalance = await wavaxContract.balanceOf(peachOwner.address);
        const peachOwnerWavaxBalance = ethers.utils.formatEther(currBalance);
        console.log('peachOwnerWavaxBalance: ', peachOwnerWavaxBalance);
    });

    it("Test 1", async () => {
        expect(1).equal(1);
    })
})

const getPairInfo = async (pair, address) => {
    const reserves = await pair.getReserves()
    let reserve0 = reserves[0]
    let reserve1 = reserves[1]
    const totalSupply = await pair.totalSupply()
    const balanceSupply = await pair.balanceOf(address)
    const amount0 = reserve0.mul(balanceSupply).div(totalSupply)
    const amount1 = reserve1.mul(balanceSupply).div(totalSupply)
    reserve0 = reserve0.sub(amount0)
    reserve1 = reserve1.sub(amount1)
    const token0 = await pair.token0()

    return {
        reserve0: reserve0,
        reserve1: reserve1,
        amount0: amount0,
        amount1: amount1,
        token0: token0,
    }
}