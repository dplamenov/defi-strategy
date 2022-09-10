# DeFi Strategy

Network: goerli

1. User deposit ETH or WETH (Wrapped ETH) in protocol
2. Protocol swap deposited ETH or WETH for USDC at UNISWAP (DEX)
3. Then deposit USDC at AAVE
4. User can withdraw

Things to improve: 
1. Possible usage of ERC20 to represent users deposits.

Deploy: `npx hardhat run scripts/deploy`

Test: `npx hardhat test`
