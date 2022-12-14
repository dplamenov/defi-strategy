// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";

//custom errors
error DepositIsLessThanMinDeposit();
error InsufficientBalance();
error InEmergency();
error NotAdmin();
error TransferFailed();
error NotProposalAdmin();
error ZeroAddress();

contract Strategy is ReentrancyGuard {
    address public immutable UniswapV2Router02 =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public immutable USDCAddress =
        0xA2025B15a1757311bfD68cb14eaeFCc237AF5b43;
    address public immutable AAVEPool =
        0x368EedF3f56ad10b9bC57eed4Dac65B26Bb667f6;
    address public weth;
    address public admin;
    address public proposalAdminAddress;
    uint256 public totalUSDCTokens;
    uint256 public immutable minDeposit;
    uint256 public immutable feePercentage;

    bool public emergency = false;

    mapping(address => uint256) public userPositions;

    /// @notice emit on deposit
    event Deposit(uint256 amount);

    /// @notice emit on withdraw
    event Withdraw(uint256 amount);

    /// @notice emit when new admin propose new admin
    event NewProposalAdmin(address proposalAdmin);

    /// @notice emit when protocal has new admin
    event NewAdmin(address admin);

    /// @notice emergency must be false to pass check
    modifier notInEmergency() {
        if (emergency == true) revert InEmergency();
        _;
    }

    /// @notice msg.sender must be equal to admin to pass check
    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    /// @notice msg.sender must be equal to proposal admin to pass check
    modifier onlyProposalAdmin() {
        if (msg.sender != proposalAdminAddress) revert NotProposalAdmin();
        _;
    }

    /// @notice construct contract
    /// @param _minDeposit Min value of deposit
    /// @param _feePercentage Fercentage of fee for the current protocol at withdraw
    /// @dev 1. get address of WETH
    /// @dev 2. set address of deployer to owner
    constructor(uint256 _minDeposit, uint256 _feePercentage) {
        //get address of WETH contract using UNISWAP ROUTER
        weth = IUniswapV2Router02(UniswapV2Router02).WETH();
        //init storage variables
        minDeposit = _minDeposit;
        feePercentage = _feePercentage;
        admin = msg.sender;
    }

    /// @notice deposit -> User can deposit ETH; Deposit should be more than minDeposit; Avaible only in normal mode(notInEmergency)
    /// @dev 1. Deposited ETH by user is swapped at UNISWAP for USDC after that we supply AAVE pool with that USDC.
    /// @dev 2. emit Deposit event
    function deposit() public payable notInEmergency {
        if (msg.value < minDeposit) revert DepositIsLessThanMinDeposit();

        //construct path of deposit
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = USDCAddress;

        //swap ETH (deposit by user) to USDC (stable coin) at UNISWAP (DEX)
        uint256[] memory amounts = IUniswapV2Router02(UniswapV2Router02)
            .swapExactETHForTokens{value: msg.value}(
            1 wei,
            path,
            address(this),
            block.timestamp + 1 hours
        );

        // call internal deposit method
        _deposit(amounts[1]);
    }

    /// @notice depositWETH -> User can deposit WETH; Before that must be call approve method.
    /// @param wethTokens amount of tokens
    function depositWETH(uint256 wethTokens) public payable notInEmergency {
        if (wethTokens < minDeposit) revert DepositIsLessThanMinDeposit();

        //transfer WETH (Wrapped ETH) from msg.sender to protocol (current controct)
        bool sent = IERC20(weth).transferFrom(
            msg.sender,
            address(this),
            wethTokens
        );

        //check result of transferFrom method
        if (!sent) revert TransferFailed();

        //construct path of deposit
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = USDCAddress;

        //swap WETH for USDC at UNISWAP (DEX)
        uint256[] memory amounts = IUniswapV2Router02(UniswapV2Router02)
            .swapExactTokensForETH(
                wethTokens,
                1 wei,
                path,
                address(this),
                block.timestamp + 1 hours
            );

        // call internal deposit method
        _deposit(amounts[1]);
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
        // call internal withdraw method
        _withdraw(tokens, minEth, msg.sender);
    }

    // @notice withdrawAndTransfer -> Add option to transfer ETH to another address in same transcation
    function withdrawAndTransfer(
        uint256 tokens,
        uint256 minEth,
        address to
    ) public payable nonReentrant {
        // call internal withdraw method
        _withdraw(tokens, minEth, to);
    }

    function getUDSC() public view returns (uint256) {
        return userPositions[msg.sender];
    }

    /// @notice Owner can set protocol in emergency mode
    function startEmergency() public onlyAdmin {
        emergency = true;
    }

    /// @notice Owner can set protocol in emergency mode
    function endEmergency() public onlyAdmin {
        emergency = false;
    }

    /// @notice Estimate how many ETH user will recieve if withdraw all tokens amount
    function estimateWithdraw() public view returns (uint256) {
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

    /// @notice internal method for deposit
    function _deposit(uint256 amount) internal {
        userPositions[msg.sender] += amount;
        totalUSDCTokens += amount;

        //approve AAVE to spend USDC
        IERC20(USDCAddress).approve(AAVEPool, amount);

        //supply AAVE with USDC
        IPool(AAVEPool).supply(USDCAddress, amount, address(this), 0);

        emit Deposit(amount);
    }

    /// @notice internal method for withdraw
    function _withdraw(
        uint256 tokens,
        uint256 minEth,
        address to
    ) internal {
        if (userPositions[msg.sender] < tokens) revert InsufficientBalance();

        address[] memory path = new address[](2);
        path[0] = USDCAddress;
        path[1] = weth;

        userPositions[msg.sender] -= tokens;
        totalUSDCTokens -= tokens;

        //withdraw tokens from AAVE
        uint256 USDCtokens = IPool(AAVEPool).withdraw(
            USDCAddress,
            tokens,
            address(this)
        );

        IERC20(USDCAddress).approve(UniswapV2Router02, USDCtokens);

        uint256[] memory amounts = IUniswapV2Router02(UniswapV2Router02)
            .swapExactTokensForETH(
                (tokens * feePercentage) / 100,
                minEth,
                path,
                admin,
                block.timestamp + 1 hours
            );

        IUniswapV2Router02(UniswapV2Router02)
            .swapExactTokensForETH(
                tokens - ((tokens * feePercentage) / 100),
                minEth,
                path,
                to,
                block.timestamp + 1 hours
            );

        emit Withdraw(amounts[1]);
    }

    /// @notice current admin can propose new admin
    function proposalAdmin(address _proposalAdminAddress) public onlyAdmin {
        if(_proposalAdminAddress == address(0)) revert ZeroAddress();
        proposalAdminAddress = _proposalAdminAddress;
        emit NewProposalAdmin(_proposalAdminAddress);
    }

    /// @notice proposed admin must claim admin role using this method
    function claimAdmin() public onlyProposalAdmin {
        //set admin to msg.sender (proposal admin)
        admin = msg.sender;
        //clear proposalAdminAddress
        proposalAdminAddress = address(0);
        emit NewAdmin(admin);
    }

    //@notice return all amount deposited in protocol converted to ETH
    function totalDeposit() public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = USDCAddress;
        path[1] = weth;

        uint256[] memory amounts = IUniswapV2Router02(UniswapV2Router02)
            .getAmountsOut(totalUSDCTokens, path);

        return amounts[1];
    }
}
