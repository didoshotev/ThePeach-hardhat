const { expect } = require("chai");
const { ethers } = require("hardhat");
const { expectRevert, ether } = require('@openzeppelin/test-helpers');
const {router_abi, factory_abi} = require("../abi/router_abi");
const Table = require("cli-table3");
const routerAddress = "0x60aE616a2155Ee3d9A68541Ba4544862310933d4";

describe("Peach Token Tests", function(){

    let table = new Table({
        head:['Contracts', 'contract addresses'],
        colWidths:['auto','auto']
      });

    let peachToken, limiter, acc1, acc2, routerContract, dai;
    beforeEach(async function(){
            await ethers.provider.send("hardhat_reset",[{
                forking: {
                    jsonRpcUrl: "https://api.avax.network/ext/bc/C/rpc",
                    blockNumber: 2975762,
                        },
                    },
                ],
            );


        [peachOwner, treasury, team, acc1, acc2, acc3] = await ethers.getSigners();

         //initating Router contract
        routerContract = await ethers.getContractAt(router_abi, routerAddress )
        
        //deploying peach token
        const PeachContract = await ethers.getContractFactory("PeachToken");
        peachToken = await PeachContract.connect(peachOwner).deploy(treasury.address, team.address);
        const ownerPeach = await peachToken.owner();

        //deploying Mock token
        const MockContract = await ethers.getContractFactory("MDai");
        mDai = await MockContract.connect(peachOwner).deploy();
        
        //deploying limiter contract
        const LimiterContract = await ethers.getContractFactory("LimiterTax");
        limiter = await LimiterContract.connect(peachOwner).deploy("10", "50", [peachToken.address, mDai.address], treasury.address);

        //set implemetation point
        await peachToken.setLiquidityTaxManager(limiter.address);
        const add = await peachToken.getLiquidityTaxManager();

        const pairAddress = await limiter.getPair();
        table.push(
            ["Peach and limiter tax owner: ", ownerPeach],
            ["Peach Token Contract: ", peachToken.address],
            ["Mock Dai Contract: ", mDai.address],
            ["Limiter COntract deployed at: ", limiter.address],
            ["Limiter address via Peach Token: ", add],
            ["Pair address:", pairAddress],
        );
    });

    it("Contracts ", async function(){
        console.log(table.toString());
      })

    it("Transfer Tax", async function(){

        //Transfering from owner. This should not incur any tax
        let amount =ethers.utils.parseEther("10000");
        expect(await peachToken.balanceOf(peachOwner.address)).to.equal(await peachToken.totalSupply());
        await peachToken.connect(peachOwner).transfer(acc1.address, amount );
        expect((await peachToken.balanceOf(acc1.address)).toString()).to.equal(amount.toString());
        expect((await peachToken.balanceOf(treasury.address)).toString()).to.equal("0");

        //transfering from acc1 to acc2. This should incur transfer tax.
        amount = ethers.utils.parseEther("5000");
        await peachToken.connect(acc1).transfer(acc2.address, amount );
        expect((await peachToken.balanceOf(acc1.address)/1e18).toString()).to.equal("5000")
        expect((await peachToken.balanceOf(acc2.address)/1e18).toString()).to.equal("2500");
        expect((await peachToken.balanceOf(treasury.address)/1e18).toString()).to.equal("2500");

        //transfering from acc2 to acc3. This should incur transfer tax.
        amount = ethers.utils.parseEther("2500");
        await peachToken.connect(acc2).transfer(acc3.address, amount );
        expect((await peachToken.balanceOf(acc2.address)/1e18).toString()).to.equal("0")
        expect((await peachToken.balanceOf(acc3.address)/1e18).toString()).to.equal("1250");
        expect((await peachToken.balanceOf(treasury.address)/1e18).toString()).to.equal("3750");
    })

    it("Sell Tax & Buy", async function(){

        //Transfering from owner. This should not incur any tax
        let amountAcc1 =ethers.utils.parseEther("10000");
        await peachToken.connect(peachOwner).transfer(acc1.address, amountAcc1);
        await mDai.connect(peachOwner).transfer(acc1.address, amountAcc1);
        expect((await peachToken.balanceOf(acc1.address)).toString()).to.equal(amountAcc1.toString());
        expect((await mDai.balanceOf(acc1.address)).toString()).to.equal(amountAcc1.toString());
        await peachToken.connect(acc1).approve(routerAddress, amountAcc1);
        await mDai.connect(acc1).approve(routerAddress, amountAcc1);
        console.log("Dai before LP: ", ethers.utils.formatUnits(await mDai.balanceOf(peachOwner.address), 18));
        console.log("PeachToken before LP: ",ethers.utils.formatUnits(await peachToken.balanceOf(peachOwner.address), 18));
        console.log("--------------------------------------------");
        //Adding lp peach and avax lp
        const approveAmount = ethers.utils.parseEther("100000");
        await peachToken.connect(peachOwner).approve(routerAddress, approveAmount);
        await mDai.connect(peachOwner).approve(routerAddress, approveAmount);
        
        const amountLp = ethers.utils.parseEther("50000");
        await routerContract.connect(peachOwner).addLiquidity
        ( peachToken.address, mDai.address,
            amountLp, amountLp,
            "0", "0",
            peachOwner.address, "1649910829447"// update this with current epoch
        )
        let reserve0 =  ethers.utils.formatUnits( await limiter.getReserve0(), 18)
        let reserve1 =  ethers.utils.formatUnits(await limiter.getReserve1(), 18); 
        console.log("price: ", reserve1/reserve0);
        console.log(await peachToken.shouldTakeFee(peachOwner.address))
        console.log("Dai after LP: ", ethers.utils.formatUnits(await mDai.balanceOf(peachOwner.address), 18));
        console.log("PeachToken after LP: ",ethers.utils.formatUnits(await peachToken.balanceOf(peachOwner.address), 18));
        console.log("--------------------------------------------");
        //swapping token - no tax should incur
        let amountTo = ethers.utils.parseEther("5000");
        await routerContract.connect(peachOwner).swapExactTokensForTokens(
            amountTo, "0", [ peachToken.address, mDai.address], 
            peachOwner.address, "1649910829447"
          );
        console.log("mdai after swap: ",  ethers.utils.formatUnits(await mDai.balanceOf(peachOwner.address), 18));
        console.log("PeachToken after swap: ", ethers.utils.formatUnits(await peachToken.balanceOf(peachOwner.address), 18));
        console.log("Treasury peachToken after swap: ", ethers.utils.formatUnits(await peachToken.balanceOf(treasury.address), 18));
        console.log("Treasury mDai after swap: ", ethers.utils.formatUnits(await mDai.balanceOf(treasury.address), 18));
        
        reserve0 =  ethers.utils.formatUnits( await limiter.getReserve0(), 18)
        reserve1 =  ethers.utils.formatUnits(await limiter.getReserve1(), 18); 
        console.log("price: ", reserve1/reserve0);
        // console.log(await peachToken.balanceOf(acc1.address));
        console.log(await mDai.balanceOf(acc1.address));

        console.log("--------------------------------------------");
        //Acc1 selling token. This should incur sell tax
        expect((await peachToken.balanceOf(acc1.address)).toString()).to.equal(amountAcc1.toString());
        expect((await mDai.balanceOf(acc1.address)).toString()).to.equal(amountAcc1.toString());
        let amountTo1 = ethers.utils.parseEther("50");

        await routerContract.connect(acc1).swapExactTokensForTokensSupportingFeeOnTransferTokens(
        amountTo1, "0", [ peachToken.address, mDai.address], 
        acc1.address, "1649910829447"
        );
        console.log("mdai acc1 after: ",  ethers.utils.formatUnits(await mDai.balanceOf(acc1.address), 18));
        console.log("PeachToken acc1 after: ", ethers.utils.formatUnits(await peachToken.balanceOf(acc1.address), 18));
        console.log("Treasury acc1 after: ", ethers.utils.formatUnits(await peachToken.balanceOf(treasury.address), 18));
        
        console.log("--------------------------------------------");
        ////Acc1 buying token. This should incur sell tax
        amountTo1 = ethers.utils.parseEther("500");
        await routerContract.connect(acc1).swapExactTokensForTokens(
            amountTo1, "0", [ mDai.address, peachToken.address], 
            acc1.address, "1649910829447"
        );

        console.log("mdai acc1 after buy: ",  ethers.utils.formatUnits(await mDai.balanceOf(acc1.address), 18));
        console.log("PeachToken acc1 after buy: ", ethers.utils.formatUnits(await peachToken.balanceOf(acc1.address), 18));
        console.log("Treasury acc1 after buy: ", ethers.utils.formatUnits(await peachToken.balanceOf(treasury.address), 18));
        
    })
})
