# DeFi Strategy

Network: goerli

1. User deposit ETH or WETH (Wrapped ETH) in protocol
2. Protocol swap deposited ETH or WETH for USDC at UNISWAP (DEX)
3. Then deposit USDC at AAVE
4. User can withdraw

Deploy: `npx hardhat run scripts/deploy.`
Test: `npx hardhat test`

```shell
npx hardhat help
npx hardhat test
GAS_REPORT=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.js
```
