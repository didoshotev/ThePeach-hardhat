const hre = require("hardhat")
const JOE_ROUTER_ABI = require("../abi/joe_router_abi.json");
const JOE_FACTORY_ABI = require("../abi/joe_factory_abi.json");
const WAVAX_ABI = require("../abi/wavax_abi.json");
const { expect, assert } = require("chai");
const { ethers, waffle } = require("hardhat");
const { BigNumber } = require("ethers");
const { expectRevert } = require('@openzeppelin/test-helpers');
const { PeachHelper } = require("../helpers/liquidity");


const JOE_ROUTER_ADDRESS = '0x60aE616a2155Ee3d9A68541Ba4544862310933d4';
const WAVAX_ADDRESS = "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7";
const DEPOSIT_NUMBER = "50000000000000000000000"; // 50000

const largeAmount = ethers.utils.parseEther('100');
const amount8k = ethers.utils.parseEther('8000');
const amount1200 = ethers.utils.parseEther('1200');
const amount200 = ethers.utils.parseEther('200');
const amount80 = ethers.utils.parseEther('80');
const amount78 = ethers.utils.parseEther('78');
const amount1 = ethers.utils.parseEther('5');

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
        peachToken = await PeachToken.connect(peachOwner).deploy(peachOwner.address, DEPOSIT_NUMBER);

        // deploy peachPool
        const PeachPool = await hre.ethers.getContractFactory("PeachPool");
        peachPool = await PeachPool.deploy(
            JOE_FACTORY_ADDRESS,
            JOE_ROUTER_ADDRESS,
            peachToken.address,
            WAVAX_ADDRESS,
            [peachToken.address, WAVAX_ADDRESS]
        );

        const lpAddress = await joeFactoryContract.getPair(peachToken.address, WAVAX_ADDRESS);
        const lpCreatedByPeachPool = await peachPool.getPair2();

        //@notice check to see if LP created by PeachPool is the same as in JoeFactory;
        expect(lpAddress).equal(lpCreatedByPeachPool);

        // TODO: negative checks
        //await expectRevert(joeFactoryContract.connect(peachOwner).createPair(peachToken.address, WAVAX_ADDRESS),"Joe: PAIR_EXISTS");

        // We might need to move approvement into the contract functions
        await wavaxContract.connect(peachOwner).approve(peachPool.address, ethers.constants.MaxUint256);
        await peachToken.connect(peachOwner).approve(peachPool.address, ethers.constants.MaxUint256)
    });

    it("should add liquidity via PeachPool and test swaps", async () => {

        const lp = await peachPool.connect(peachOwner).checkLPTokenBalance();
        const lpBalanceBefore = ethers.utils.formatUnits(lp, 18);

        PeachHelper.provideLiquidity(peachPool, peachOwner, peachToken.address, amount200, amount200);

        // check peachOwner LP balance
        const lpBalance = await peachPool.connect(peachOwner).checkLPTokenBalance();
        const lpBalanceAfter = ethers.utils.formatUnits(lpBalance, 18);

        expect(+lpBalanceBefore).lessThan(+lpBalanceAfter);

        // SWAP peachTokens for AVAX
        const peachBeforeSwap = ethers.utils.formatEther(await peachToken.balanceOf(peachOwner.address));
        const peachOwnerAvaxBeforeSwap = ethers.utils.formatEther(await ethers.provider.getBalance(peachOwner.address));

        const swap = await peachPool.connect(peachOwner).swapExactTokensForAVAX(
            peachToken.address,
            amount80,
            [peachToken.address, wavaxContract.address]
        );
        await swap.wait();

        const peachAfterSwap = ethers.utils.formatEther(await peachToken.balanceOf(peachOwner.address))
        const peachOwnerAvaxAfterSwap = ethers.utils.formatEther(await ethers.provider.getBalance(peachOwner.address));

        expect(+peachBeforeSwap).greaterThan(+peachAfterSwap);
        expect(+peachOwnerAvaxBeforeSwap).lessThan(+peachOwnerAvaxAfterSwap);


        //SWAP 2
        const peachBeforeSwap2 = ethers.utils.formatEther(await peachToken.balanceOf(peachOwner.address));
        const peachOwnerAvaxBeforeSwap2 = ethers.utils.formatEther(await ethers.provider.getBalance(peachOwner.address));

        const swap2 = await peachPool.connect(peachOwner).swapAVAXForExactTokens(
            peachToken.address,
            amount80, // Must Be Less Than ETH Value Sent
            [wavaxContract.address, peachToken.address],
            { value: amount80 }
        );
        await swap2.wait();

        const peachAfterSwap2 = ethers.utils.formatEther(await peachToken.balanceOf(peachOwner.address))
        const peachOwnerAvaxAfterSwap2 = ethers.utils.formatEther(await ethers.provider.getBalance(peachOwner.address));

        expect(+peachBeforeSwap2).lessThan(+peachAfterSwap2);
        expect(+peachOwnerAvaxBeforeSwap2).greaterThan(+peachOwnerAvaxAfterSwap2);
    })

    it("should swap 200 AVAX for 190 PeachTokens", async () => {
        await PeachHelper.provideLiquidity(peachPool, peachOwner, peachToken.address, amount8k, amount8k);

        const peachBeforeSwap2 = ethers.utils.formatEther(await peachToken.balanceOf(peachOwner.address));
        const peachOwnerAvaxBeforeSwap2 = ethers.utils.formatEther(await ethers.provider.getBalance(peachOwner.address));

        const swap2 = await peachPool.connect(peachOwner).swapAVAXForExactTokens(
            peachToken.address,
            ethers.utils.parseEther("190"),
            [wavaxContract.address, peachToken.address],
            { value: amount200 }
        );
        await swap2.wait();

        const peachAfterSwap2 = ethers.utils.formatEther(await peachToken.balanceOf(peachOwner.address))
        const peachOwnerAvaxAfterSwap2 = ethers.utils.formatEther(await ethers.provider.getBalance(peachOwner.address));

        expect(+peachBeforeSwap2).lessThan(+peachAfterSwap2);
        expect(+peachOwnerAvaxBeforeSwap2).greaterThan(+peachOwnerAvaxAfterSwap2);
    })

    it("should swap 200 PeachTokens for max AVAX", async () => {
        await PeachHelper.provideLiquidity(peachPool, peachOwner, peachToken.address, amount8k, amount8k);

        // SWAP peachTokens for AVAX
        const peachBeforeSwap = ethers.utils.formatEther(await peachToken.balanceOf(peachOwner.address));
        const peachOwnerAvaxBeforeSwap = ethers.utils.formatEther(await ethers.provider.getBalance(peachOwner.address));

        const swap = await peachPool.connect(peachOwner).swapExactTokensForAVAX(
            peachToken.address,
            ethers.utils.parseEther("200"),
            [peachToken.address, wavaxContract.address]
        );
        await swap.wait();

        const peachAfterSwap = ethers.utils.formatEther(await peachToken.balanceOf(peachOwner.address))
        const peachOwnerAvaxAfterSwap = ethers.utils.formatEther(await ethers.provider.getBalance(peachOwner.address));
        
        expect(+peachBeforeSwap).greaterThan(+peachAfterSwap);
        expect(+peachOwnerAvaxBeforeSwap).lessThan(+peachOwnerAvaxAfterSwap);

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