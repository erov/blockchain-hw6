# UniswapV2 flashloan 

A simple implementation of `IUniswapV2Callee` that supports cycle swapping of tokens. In this contract and test code the following swap-cycle as hardcoded: 
`wETH -> LINK -> DAI -> wETH`, however first token (and last one too, correspondingly) can be different-way specified in test file.

This hw done in hardhat mainnet fork at block `16293919`. These, it was failed to complete a flashloan tokens returning (See 'Sample of Usage' output) due to a large loss occurring while flashloan was being done. But, I guess, there is a block which allows us to complete a flashloan (but how should we find it? :hmm:)

This way, there is a successful test with revert expecting down below.

## Preparing
Node.js must be installed before work starting. Moreover, there is some modules that we need in:
```
npm install --save-dev hardhat
npm install module '@openzeppelin/contracts'
npm install module '@uniswap/v2-core'
```

## Usage
```
$ export ALCHEMY_TOKEN=<YOUR ALCHEMY TOKEN>
$ npx hardhat test
```

## Sample of usage
```
$ npx hardhat test

  Contract deployment test
    ✔ Deployment

  UniswapFlashloan test
Flashloan input token amount: 10000000000000000000 WETH
Swap pair #0
Swap #0 successful:
    10000000000000000000 WETH ->
    -> 2.110855490272383e+21 LINK
Swap pair #1
Swap #1 successful:
    2.110855490272383e+21 LINK ->
    -> 1.0901381661454801e+21 DAI
Swap pair #2
Swap #2 successful:
    1.0901381661454801e+21 DAI ->
    -> 905859138347179400 WETH
Loss of flashloan: 9094140861652821000 WETH
Try to return flashloan inputAmount with 0.3% fee: 10030090270812436000 WETH
    ✔ Cycle swapping test -- revert (193ms)


  2 passing (4s)

```
