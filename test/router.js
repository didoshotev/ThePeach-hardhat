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
            value: BigNumber.from(DEPOSIT_NUMBER)
        })
        const currBalance = await wavaxContract.balanceOf(peachOwner.address);
        const peachOwnerWavaxBalance = ethers.utils.formatEther(currBalance);

        expect(+peachOwnerWavaxBalance).equal(5000);

        // deploy PeachToken
        const PeachToken = await hre.ethers.getContractFactory("PeachToken");
        peachToken = await PeachToken.deploy(peachOwner.address);


        // deploy peachPool
        const PeachPool = await hre.ethers.getContractFactory("PeachPool");
        peachPool = await PeachPool.deploy(JOE_FACTORY_ADDRESS, JOE_ROUTER_ADDRESS, peachToken.address, WAVAX_ADDRESS);

        // console.log('peachPool: ', peachPool);
        await wavaxContract.connect(peachOwner).approve(peachPool.address, ethers.constants.MaxUint256);
        await peachToken.connect(peachOwner).approve(peachPool.address, ethers.constants.MaxUint256)

        // const addLpResult = await peachPool.connect(peachOwner).addLiquidityAvax(peachToken.address, 500, 50);
        // console.log('addLpResult: ', addLpResult);
        // console.log(joeFactoryContract);
        // const lpAddress = await joeFactoryContract.getPair(peachToken.address, wavaxContract.address);
        // console.log('lpAddress: ', lpAddress);

        // //adding liquidity
        // const liquidtyToken = "900000000000000000000" //1000 tokens
        // const minimumToken = "890000000000000000000"; //990 tokens
        // const addLpResult = await joeRouterContract.connect(peachOwner).addLiquidity
        //     (peachToken.address, wavaxContract.address,
        //         liquidtyToken, liquidtyToken,
        //         minimumToken, minimumToken,
        //         peachOwner.address, "1649646004"// update this with current epoch
        //     )
        // // console.log(addLpResult);
        
        // const pair = await joeFactoryContract.createPair(peachToken.address, wavaxContract.address);
        // const pairTx = await pair.wait();

        // console.log('pair args: ', pairTx.events[0].args);
        // // const lpAddress = await joeFactoryContract.getPair(peachToken.address, wavaxContract.address);
        // console.log('lpAddress: ', lpAddress);

        // const lpValue = ethers.utils.formatEther(pairTx.events[0].args[3]);
        // console.log('lp value: ', lpValue);

        // console.log('peachOwner: ', peachOwner.address);
        // let value2 = ethers.utils.formatUnits(500, "wei");
        // let value = BigNumber.from("500");
    });

    // it("should create pair", async () => { 
    //     const wavaxPeachPairAddress = await peachPool.getPair();
    //     console.log('wavaxPeachPairAddress: ', wavaxPeachPairAddress);

    //     // await expectRevert(joeFactoryContract.createPair(peachToken.address, wavaxContract.address),"Joe: PAIR_EXISTS");
    //     // console.log();

    //     // const pair = await joeFactoryContract.createPair(peachToken.address, wavaxContract.address);
    //     // const pair3 = await joeFactoryContract.createPair(peachToken.address, wavaxContract.address);

    //     // const pairTx = await pair.wait();

    //     // const pairAddress = await joeFactoryContract.getPair(peachToken.address, wavaxContract.address);


    //     // expect(pairAddress).equal(pairTx.events[0].args[2]);
    //     // const pair2 = await joeFactoryContract.createPair(peachToken.address, wavaxContract.address);
    //     // const pair2Tx = await pair2.wait();
    //     // console.log(pair2Tx);
    //     // console.log('----------------');
    //     // console.log(pair2Tx);
    //     // const shouldRevertTx = await expectRevert(joeFactoryContract.createPair(peachToken.address, wavaxContract.address),"Joe: PAIR_EXISTS");
    //     // console.log('shouldRevertTx: ', shouldRevertTx);
    // })

    it.only("Swap", async function () { 
        const MIN_NUMBER = "4800000000000000000000"; // 5000

        const wavaxPeachPairAddress = await peachPool.getPair();
        
        // add via avax
        const addLiquidity = await peachPool.connect(peachOwner).customAddLiquidityAVAX(
            peachToken.address,
            DEPOSIT_NUMBER,
            MIN_NUMBER,
            MIN_NUMBER,
            peachOwner.address
        )
        const addLiquidityReceipt = await addLiquidity.wait();
        console.log('addLiquidityReceipt: ', addLiquidityReceipt);
        
        // const currBalance = await wavaxContract.balanceOf(peachOwner.address);
        
        // const big_number = "50000000000000000000000"; // 5000

        // const swap = await peachPool.connect(peachOwner).customSwapExactAVAXForTokens( 
        //     big_number, 
        //     [wavaxContract.address, peachToken.address],
        //     peachOwner.address
        // )
        // const swapReceipt = await swap.wait();
        // console.log('swapReceipt: ', swapReceipt);
    })
})
