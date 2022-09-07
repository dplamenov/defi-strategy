// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";

error DepositIsLessThanMinDeposit();

contract Strategy {
    address UniswapV2Router02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address USDCAddress = 0xA2025B15a1757311bfD68cb14eaeFCc237AF5b43;
    address AAVEPool = 0x368EedF3f56ad10b9bC57eed4Dac65B26Bb667f6;
    address weth;
    address public owner;
    uint256 public minDeposit;
    uint256 public feePercentage;

    mapping(address => uint256) public userPositions;

    event Deposit(uint256 amount);
    event Withdraw(uint256 amount);

    constructor(uint256 _minDeposit, uint256 _feePercentage) {
        weth = IUniswapV2Router02(UniswapV2Router02).WETH();
        minDeposit = _minDeposit;
        feePercentage = _feePercentage;
        owner = msg.sender;
    }

    function deposit() public payable {
        if (msg.value < minDeposit) revert DepositIsLessThanMinDeposit();

        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = USDCAddress;

        uint256[] memory amounts = IUniswapV2Router02(UniswapV2Router02)
            .swapExactETHForTokens{value: msg.value}(
            1 wei,
            path,
            address(this),
            block.timestamp + 1 hours
        );

        userPositions[msg.sender] = amounts[1];

        IERC20(USDCAddress).approve(AAVEPool, amounts[1]);

        IPool(AAVEPool).supply(USDCAddress, amounts[1], address(this), 0);

        emit Deposit(amounts[1]);
    }

    function withdraw() public payable {
        address[] memory path = new address[](2);
        path[0] = USDCAddress;
        path[1] = weth;

        uint256 tokens = IPool(AAVEPool).withdraw(
            USDCAddress,
            type(uint256).max,
            address(this)
        );

        IERC20(USDCAddress).approve(UniswapV2Router02, tokens);

        IUniswapV2Router02(UniswapV2Router02).swapExactTokensForETH(
            (tokens * feePercentage) / 100,
            1 wei,
            path,
            owner,
            block.timestamp + 1 hours
        );

        uint256[] memory amounts = IUniswapV2Router02(UniswapV2Router02)
            .swapExactTokensForETH(
                (tokens * (100 - feePercentage)) / 100,
                1 wei,
                path,
                msg.sender,
                block.timestamp + 1 hours
            );

        emit Withdraw(amounts[1]);
    }

    fallback() external payable {}
}
