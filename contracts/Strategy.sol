// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";

error DepositIsLessThanMinDeposit();
error InsufficientBalance();
error InEmergency();
error NotAdmin();

contract Strategy is ReentrancyGuard {
    address UniswapV2Router02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address USDCAddress = 0xA2025B15a1757311bfD68cb14eaeFCc237AF5b43;
    address AAVEPool = 0x368EedF3f56ad10b9bC57eed4Dac65B26Bb667f6;
    address weth;
    address public owner;
    uint256 public minDeposit;
    uint256 public feePercentage;
    uint256 public totalUSDCTokens;

    bool emergency = false;

    mapping(address => uint256) public userPositions;

    /// @notice emit ot deposit
    event Deposit(uint256 amount);

    /// @notice emit ot withdraw
    event Withdraw(uint256 amount);

    /// @notice emergency must be false to pass check
    modifier notInEmergency() {
        if (emergency == true) revert InEmergency();
        _;
    }

    /// @notice msg.sender must be equal to owner to pass check
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAdmin();
        _;
    }

    /// @notice construct contract
    /// @param _minDeposit Min value of deposit
    /// @param _feePercentage Fercentage of fee for the current protocol at withdraw
    /// @dev 1. get address of WETH
    /// @dev 2. set address of deployer to owner
    constructor(uint256 _minDeposit, uint256 _feePercentage) {
        weth = IUniswapV2Router02(UniswapV2Router02).WETH();
        minDeposit = _minDeposit;
        feePercentage = _feePercentage;
        owner = msg.sender;
    }

    /// @notice deposit -> User can deposit ETH; Deposit should be more than minDeposit; Avaible only in normal mode(notInEmergency)
    /// @dev 1. Deposited ETH by user is swapped at UNISWAP for USDC after that we supply AAVE pool with that USDC.
    /// @dev 2. emit Deposit event
    function deposit() public payable notInEmergency {
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

        userPositions[msg.sender] += amounts[1];
        totalUSDCTokens += amounts[1];

        IERC20(USDCAddress).approve(AAVEPool, amounts[1]);

        IPool(AAVEPool).supply(USDCAddress, amounts[1], address(this), 0);

        emit Deposit(amounts[1]);
    }

    /// @notice withdraw -> User can withdraw ETH; can revert with InsufficientBalance();
    /// @param tokens How many tokens to withdraw;
    /// @param minEth Min value of returned ETH;
    /// @dev 1. First withdraw tokens from AAVE Pool
    /// @dev 2. Then swap tokens for ETH using UNISWAP
    /// @dev 3. Pay fee
    function withdraw(uint256 tokens, uint256 minEth)
        public
        payable
        nonReentrant
    {
        if (userPositions[msg.sender] < tokens) revert InsufficientBalance();

        address[] memory path = new address[](2);
        path[0] = USDCAddress;
        path[1] = weth;

        userPositions[msg.sender] -= tokens;
        totalUSDCTokens -= tokens;

        uint256 tokens = IPool(AAVEPool).withdraw(
            USDCAddress,
            tokens,
            address(this)
        );

        IERC20(USDCAddress).approve(UniswapV2Router02, tokens);

        uint256[] memory amounts = IUniswapV2Router02(UniswapV2Router02)
            .swapExactTokensForETH(
                tokens,
                0,
                path,
                address(this),
                block.timestamp + 1 hours
            );

        payable(owner).transfer((tokens * feePercentage) / 100);
        payable(msg.sender).transfer((tokens * (100 - feePercentage)) / 100);

        emit Withdraw(amounts[1]);
    }

    function getUDSC() public view returns (uint256) {
        return userPositions[msg.sender];
    }

    /// @notice Owner can set protocol in emergency mode
    function startEmergency() public onlyOwner {
        emergency = true;
    }

    /// @notice Owner can set protocol in emergency mode
    function endEmergency() public onlyOwner {
        emergency = false;
    }

    function estimate() public view returns (uint256) {
        uint256 percentage = (userPositions[msg.sender] * 100) /
            totalUSDCTokens;
        (, , uint256 availableBorrowsBase, , , ) = IPool(AAVEPool)
            .getUserAccountData(address(this));

        address[] memory path = new address[](2);
        path[0] = USDCAddress;
        path[1] = weth;

        uint256[] memory amounts = IUniswapV2Router02(UniswapV2Router02)
            .getAmountsOut((availableBorrowsBase * percentage) / 100, path);

        return ((amounts[1] * (100 - feePercentage)) / 100);
    }

    fallback() external payable {}
}
