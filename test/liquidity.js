const hre = require("hardhat")
const JOE_ROUTER_ABI = require("../abi/joe_router_abi.json");
const JOE_FACTORY_ABI = require("../abi/joe_factory_abi.json");
const WAVAX_ABI = require("../abi/wavax_abi.json");
const { expect, assert } = require("chai");
const { ethers, waffle } = require("hardhat");
const { BigNumber } = require("ethers");
const { expectRevert } = require('@openzeppelin/test-helpers');


const JOE_ROUTER_ADDRESS = '0x60aE616a2155Ee3d9A68541Ba4544862310933d4';
const WAVAX_ADDRESS = "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7";
const DEPOSIT_NUMBER = "5000000000000000000000"; // 5000
const largeAmount = ethers.utils.parseEther('100');
const amount80 = ethers.utils.parseEther('80');
const amount78 = ethers.utils.parseEther('78');
const amount1 = ethers.utils.parseEther('100');

describe("Deploy contracts", () => {
    let peachPool, peachToken, joeRouterContract, joeFactoryContract, JOE_FACTORY_ADDRESS, wavaxContract;
    let peachOwner;

    beforeEach(async function () {
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

        [peachOwner, peachPoolOwner] = await ethers.getSigners();

        // define Joe Router contract
        joeRouterContract = await ethers.getContractAt(JOE_ROUTER_ABI, JOE_ROUTER_ADDRESS);
        JOE_FACTORY_ADDRESS = await joeRouterContract.factory();

        // define Joe Factory contract
        joeFactoryContract = await ethers.getContractAt(JOE_FACTORY_ABI, JOE_FACTORY_ADDRESS);

        // define wavax contract
        wavaxContract = await ethers.getContractAt(WAVAX_ABI, WAVAX_ADDRESS);

        // send avax to peachOwner
        await wavaxContract.connect(peachOwner).deposit({
            value: largeAmount
        })
        const currBalance = await wavaxContract.balanceOf(peachOwner.address);
        const peachOwnerWavaxBalance = ethers.utils.formatEther(currBalance);

        // expect(+peachOwnerWavaxBalance).equal(5000);
        expect(+peachOwnerWavaxBalance).equal(100);


        // deploy PeachToken
        const PeachToken = await hre.ethers.getContractFactory("PeachToken");
        peachToken = await PeachToken.deploy(peachOwner.address, largeAmount);


        // deploy peachPool
        const PeachPool = await hre.ethers.getContractFactory("PeachPool");
        peachPool = await PeachPool.deploy(
            JOE_FACTORY_ADDRESS,
            JOE_ROUTER_ADDRESS,
            peachToken.address,
            WAVAX_ADDRESS,
            [peachToken.address, WAVAX_ADDRESS]
        );

        await wavaxContract.connect(peachOwner).approve(peachPool.address, ethers.constants.MaxUint256);
        await peachToken.connect(peachOwner).approve(peachPool.address, ethers.constants.MaxUint256)
    });

    it("should add liquidity via PeachPool and complete token swap", async () => {

        const lp = await peachPool.connect(peachOwner).checkLPTokenBalance();
        const lpBalanceBefore = ethers.utils.formatUnits(lp, 18);


        const tx = await peachPool.connect(peachOwner)
            .addLiquidityAvax(peachToken.address, amount80, { value: largeAmount });

        await tx.wait();

        // check peachOwner LP balance
        const lpBalance = await peachPool.connect(peachOwner).checkLPTokenBalance();
        const lpBalanceAfter = ethers.utils.formatUnits(lpBalance, 18);

        console.log('LP balance before: ', lpBalanceBefore);
        console.log('LP Balance after: ', lpBalanceAfter);

        expect(+lpBalanceBefore).lessThan(+lpBalanceAfter);

        const _tokenAmount = ethers.utils.parseEther('20');

        const peachBalance = await peachToken.balanceOf(peachOwner.address);
        const peachFormatted = ethers.utils.formatEther(peachBalance)
        
        const wavaxBalance = await wavaxContract.balanceOf(peachOwner.address);
        const wavaxFormatted = ethers.utils.formatEther(wavaxBalance)

        //SWAP FUNCTION
        //SWAP EXACT TOKEN FOR MAX AVAX
        const swap = await peachPool.connect(peachOwner).swapExactTokensForAVAX( 
            peachToken.address,
            _tokenAmount,
            [peachToken.address,wavaxContract.address],
            WAVAX_ADDRESS, // WAVAX ADDRESS
            amount1 //AVAX VALUE TRANSFERRED AS MUCH AS POSSIBLE FROM TOKEN
        )

        // const swapReceipt = await swap.wait();
        // console.log('swapReceipt: ', swapReceipt);

        const newpeachBalance = await peachToken.balanceOf(peachOwner.address);
        const newpeachFormatted = ethers.utils.formatEther(newpeachBalance)
        const newwavaxBalance = await wavaxContract.balanceOf(peachOwner.address);
        const newwavaxFormatted = ethers.utils.formatEther(newwavaxBalance);

        console.log('peachFormatted: ', peachFormatted);
        console.log('wavaxFormatted: ', wavaxFormatted);
        console.log('peachFormatted after: ', newpeachFormatted);
        console.log('wavaxFormatted after: ', newwavaxFormatted);
    })

    it.skip("should directly call joeRouter", async () => {
        await wavaxContract.connect(peachOwner).approve(joeRouterContract.address, largeAmount);
        await peachToken.connect(peachOwner).approve(joeRouterContract.address, largeAmount)

        // add liquidity
        const tx = await joeRouterContract.connect(peachOwner).addLiquidityAVAX(
            peachToken.address,
            largeAmount,
            0,
            0,
            peachOwner.address,
            ethers.BigNumber.from(minutesFromNow(30)),
            { value: largeAmount } // not taken from the sender
        )
        await tx.wait();
    })
})


function minutesFromNow(minAmount) {
    return Math.floor(Date.now() / 1000) + 60 * minAmount;
};