import { expect } from "chai";
import { ethers } from "hardhat";
import {BigNumber} from "ethers";

import { abi as UniswapV2FactoryABI } from "@uniswap/v2-core/build/UniswapV2Factory.json";
import { abi as UniswapV2PairABI } from "@uniswap/v2-core/build/UniswapV2Pair.json";

let owner;
let contract;

beforeEach(async function () {
    [owner] = await ethers.getSigners();

    const factory = await ethers.getContractFactory("UniswapFlashloan");

    contract = await factory.connect(owner).deploy("0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2");
    await contract.deployed();
});

describe("Contract deployment test", function () {
    it ("Deployment", async function() {
        expect(await contract.owner()).to.equal(
            owner.address,
            "Deployed contract owner must be 'owner'"
        );
    });
});

describe("UniswapFlashloan test", function () {
   it ("Cycle swapping test -- revert", async function() {
       const uniswapFactory = await ethers.getContractAt(
           UniswapV2FactoryABI,
           "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f"
       );
       const wETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
       const SUSHI = "0x6B3595068778DD592e39A122f4f5a5cF09C90fE2";

       const token0 = (wETH < SUSHI) ? wETH : SUSHI;
       const token1 = (wETH < SUSHI) ? SUSHI : wETH;

       const wETHtoLINKpair = await ethers.getContractAt(
           UniswapV2PairABI,
           await uniswapFactory.getPair(token0, token1)
       );

       const wETHamount = BigNumber.from(10).pow(18).mul(10);
       const token0amount = (wETH < SUSHI) ? wETHamount : 0;
       const token1amount = (wETH < SUSHI) ? 0 : wETHamount;

       await expect(wETHtoLINKpair.connect(owner).swap(token0amount, token1amount, contract.address, 1))
           .to.be.reverted;
   });
});



