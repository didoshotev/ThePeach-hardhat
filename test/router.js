const hre = require("hardhat")
const JOE_ROUTER_ABI = require("../abi/joe_router_abi.json");
const JOE_FACTORY_ABI = require("../abi/joe_factory_abi.json");
const WAVAX_ABI = require("../abi/wavax_abi.json");
const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { BigNumber } = require("ethers");

const JOE_ROUTER_ADDRESS = '0x60aE616a2155Ee3d9A68541Ba4544862310933d4';
const WAVAX_ADDRESS = "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7";
const DEPOSIT_NUMBER = "500000000000000000000"; // 500

describe("Deploy contracts", () => {
    let peachPool, peachToken, joeRouterContract, JOE_FACTORY_ADDRESS, wavaxContract;
    let peachOwner;

    beforeEach(async function() {
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


        // define wavax contract
        wavaxContract = await ethers.getContractAt(WAVAX_ABI, WAVAX_ADDRESS);

        // send avax to peachOwner
          await wavaxContract.connect(peachOwner).deposit({
            value: BigNumber.from(DEPOSIT_NUMBER)
        })
        const currBalance = await wavaxContract.balanceOf(peachOwner.address);
        const peachOwnerWavaxBalance = ethers.utils.formatEther(currBalance);

        expect(+peachOwnerWavaxBalance).equal(500);
        
        // deploy PeachToken
        const PeachToken = await hre.ethers.getContractFactory("PeachToken");
        peachToken = await PeachToken.deploy(peachOwner.address);


        // deploy peachPool
        const PeachPool = await hre.ethers.getContractFactory("PeachPool");
        peachPool = await PeachPool.deploy(JOE_FACTORY_ADDRESS, JOE_ROUTER_ADDRESS, peachToken.address, WAVAX_ADDRESS);

        // console.log('peachPool: ', peachPool);

        const approveTx = await wavaxContract.connect(peachOwner).approve(JOE_ROUTER_ADDRESS, ethers.constants.MaxUint256);        
        // console.log(approveTx);

        // let value2 = ethers.utils.formatUnits(500, "wei");
        let value = BigNumber.from("500");
        const eth = ethers.utils.parseEther(value);
        console.log(eth);

        // console.log(wavaxContract.transfer);
        // await wavaxContract.connect(peachOwner).transfer(peachOwner, peachPool.address, )

        // send avax to peachPool
        // await wavaxContract.connect(peachPool.address).deposit({
        //     value: BigNumber.from(DEPOSIT_NUMBER)
        // })


        // const b = await wavaxContract.balanceOf(peachOwner.address);
        // const peachPoolWavaxBalance = ethers.utils.formatEther(b);
        // console.log('peachPoolWavaxBalance: ', peachPoolWavaxBalance);

    });


    it("test", () => { 
        expect(true).equal(true);
    })
})
