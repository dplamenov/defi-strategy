// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Strategy {
    address UniswapV2Router02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    mapping(address => uint256) public userPositions;

    event Deposit(uint256 amount);

    function deposit() public payable {
        address[] memory path = new address[](2);
        path[0] = IUniswapV2Router02(UniswapV2Router02).WETH();
        path[1] = 0xD87Ba7A50B2E7E660f678A895E4B72E7CB4CCd9C;

        uint256[] memory amounts = IUniswapV2Router02(UniswapV2Router02)
            .swapExactETHForTokens{value: msg.value}(
            1 wei,
            path,
            address(this),
            block.timestamp + 1 hours
        );

        userPositions[msg.sender] = amounts[1];
        emit Deposit(amounts[1]);
    }

    fallback() external payable {}
}
