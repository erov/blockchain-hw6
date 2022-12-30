// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "hardhat/console.sol";


contract UniswapFlashloan is IUniswapV2Callee {
    address public owner;
    address public startingToken;


    event Swap(
        address from,
        address to,
        uint token0Out,
        uint token1Out
    );

    event FlashloanReturned(uint amount);


    modifier ownerOnly(address sender) {
        require(sender == owner, "UniswapFlashloan: Sender must be owner");
        _;
    }

    modifier callbackFromFirstTokenSwap(uint amount0, uint amount1) {
        require(
            (IUniswapV2Pair(msg.sender).token0() == startingToken && amount0 != 0 && amount1 == 0) !=
            (IUniswapV2Pair(msg.sender).token1() == startingToken && amount1 != 0 && amount0 == 0),
            'UniswapFlashloan: One of UniswapV2Pair tokens must be startingToken, and corresponding token amount must be non-zero'
        );
        _;
    }


    constructor(address token) {
        owner = msg.sender;
        startingToken = token;
    }


    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data)
        external
        ownerOnly(sender)
        callbackFromFirstTokenSwap(amount0, amount1)
    {
        address[] memory swapChain = new address[](4);
        swapChain[0] = /* wETH */ startingToken;
        swapChain[1] = /* LINK */ 0x514910771AF9Ca656af840dff83E8264EcF986CA;
        swapChain[2] = /* DAI */ 0x6B175474E89094C44Da98b954EedeAC495271d0F;
//        swapChain[2] = /* USDT */ 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        swapChain[3] = /* wETH */ startingToken;

        uint inputAmount = amount0 > amount1 ? amount0 : amount1;
        console.log("Flashloan input token amount: %d %s", inputAmount, IERC20Metadata(startingToken).symbol());
        address uniswapFactory = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

        uint amountActive = inputAmount;

        for (uint i = 0; i + 1 != swapChain.length; ++i) {
            console.log("Swap pair #%d", i);

            address tokenFrom = swapChain[i];
            address tokenTo = swapChain[i + 1];

            address pair = IUniswapV2Factory(uniswapFactory).getPair(tokenFrom, tokenTo);
            bool validOrder = (tokenFrom < tokenTo);

            (uint112 token0Reserve, uint112 token1Reserve, uint32 ts) = IUniswapV2Pair(pair).getReserves();
            (uint112 tokenFromReserve, uint112 tokenToReserve) = validOrder ? (token0Reserve, token1Reserve)  : (token1Reserve, token0Reserve);

            uint amountOut = getAmountOut(amountActive, tokenFromReserve, tokenToReserve);
            require(amountOut > 0, 'UniswapFlashloan: Insufficient output amount');

            IERC20(tokenFrom).transfer(pair, amountActive);
            (uint token0Out, uint token1Out) = validOrder ? (uint(0), amountOut) : (amountOut, uint(0));
            IUniswapV2Pair(pair).swap(token0Out, token1Out, address(this), new bytes(0));  // swap w/o callback
            emit Swap(tokenFrom, tokenTo, token0Out, token1Out);

            console.log('Swap #%d successful:', i);
            console.log('    %d %s ->', amountActive, IERC20Metadata(tokenFrom).symbol());
            console.log('    -> %d %s', amountOut, IERC20Metadata(tokenTo).symbol());
            amountActive = amountOut;
        }

        if (amountActive > inputAmount) {
            console.log("Profit of flashloan: %d %s", amountActive - inputAmount, IERC20Metadata(startingToken).symbol());
        } else {
            console.log("Loss of flashloan: %d %s", inputAmount - amountActive, IERC20Metadata(startingToken).symbol());
        }

        // Because of 'Single-Token' topic on https://docs.uniswap.org/contracts/v2/guides/smart-contract-integration/using-flash-swaps
        uint returnAmount = (inputAmount * 1000 + 996) / 997;

        console.log("Try to return flashloan inputAmount with 0.3% fee: %d %s", returnAmount, IERC20Metadata(startingToken).symbol());
        IERC20(swapChain[0]).transfer(msg.sender, returnAmount);

        emit FlashloanReturned(returnAmount);
    }

    // This function was stolen from @v2-periphery/UniswapV2Library
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'UniswapFlashloan: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapFlashloan: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }
}
