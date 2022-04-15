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
        peachPool = await PeachPool.deploy(JOE_FACTORY_ADDRESS, JOE_ROUTER_ADDRESS, peachToken.address, WAVAX_ADDRESS);

        await wavaxContract.connect(peachOwner).approve(peachPool.address, ethers.constants.MaxUint256);
        await peachToken.connect(peachOwner).approve(peachPool.address, ethers.constants.MaxUint256)
    });

    it("should add liquidity", async () => {

        await wavaxContract.connect(peachOwner).approve(joeRouterContract.address, largeAmount);
        await peachToken.connect(peachOwner).approve(joeRouterContract.address, largeAmount)

        console.log('peach address: ', peachToken.address);
        // const options = { value: ethers.utils.parseEther("1.0") }
        // const reciept = await contract.buyPunk(1001, options);

        const tx = await joeRouterContract.connect(peachOwner).addLiquidityAVAX(
            peachToken.address,
            amount80,
            0,
            0,
            peachOwner.address,
            ethers.BigNumber.from(minutesFromNow(30)),
            { value: amount80 }
        )
        const receipt = await tx.wait();

        const wavaxPeachPairAddress = await peachPool.getPair();
        console.log('wavaxPeachPairAddress: ', wavaxPeachPairAddress);
        
        const wavaxPeachPairAddress2 = await joeFactoryContract.getPair(peachToken.address, WAVAX_ADDRESS);
        console.log('wavaxPeachPairAddress2: ', wavaxPeachPairAddress2);
        
        expect(wavaxPeachPairAddress).equal(wavaxPeachPairAddress2);

        const peachBalance = await peachToken.balanceOf(peachOwner.address);
        const peachFormatted = ethers.utils.formatEther(peachBalance)
        
        const wavaxBalance = await wavaxContract.balanceOf(peachOwner.address);
        const wavaxFormatted = ethers.utils.formatEther(wavaxBalance);


        console.log('peachFormatted: ', peachFormatted);
        console.log('wavaxFormatted: ', wavaxFormatted);

        // const lpBalance = await wavaxPeachPairAddress.balanceOf(peachOwner.address);
        // console.log('lpBalance: ', lpBalance);
        
        // const tx2 = await peachPool.connect(peachOwner).customAddLiquidityAVAX(
        //     peachToken.address,
        //     amount80,
        //     1,
        //     1,
        //     peachOwner.address
        // )
        // const receipt2 = tx2.wait();
        // console.log('receipt2: ', receipt2);
    })
})


function minutesFromNow(minAmount) {
    return Math.floor(Date.now() / 1000) + 60 * minAmount;
};