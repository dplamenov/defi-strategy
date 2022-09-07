// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@aave/core-v3/contracts/protocol/pool/L2Pool.sol";

contract Strategy {
    address UniswapV2Router02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address USDCAddress = 0xA2025B15a1757311bfD68cb14eaeFCc237AF5b43;
    mapping(address => uint256) public userPositions;

    event Deposit(uint256 amount);
    event Log(bool);
    event Log2(uint256);

    function deposit() public payable {
        address[] memory path = new address[](2);
        path[0] = IUniswapV2Router02(UniswapV2Router02).WETH();
        path[1] = USDCAddress;

        uint256[] memory amounts = IUniswapV2Router02(UniswapV2Router02)
            .swapExactETHForTokens{value: (msg.value * 90) / 100}(
            1 wei,
            path,
            address(this),
            block.timestamp + 1 hours
        );

        userPositions[msg.sender] = amounts[1];

        bool result = IERC20(USDCAddress).approve(
            0x368EedF3f56ad10b9bC57eed4Dac65B26Bb667f6,
            amounts[1]
        );

        L2Pool(0x368EedF3f56ad10b9bC57eed4Dac65B26Bb667f6).supply(
            USDCAddress,
            amounts[1],
            address(this),
            0
        );

        emit Deposit(amounts[1]);
    }

    fallback() external payable {}
}
