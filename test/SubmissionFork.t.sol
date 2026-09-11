// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Submission, IERC20} from "../src/Submission.sol";

interface INoReturnERC20 {
    function transfer(address to, uint256 amount) external;
    function approve(address spender, uint256 amount) external;
}

contract SubmissionForkTest is Test {
    Submission internal submission;

    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant PAIR = 0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852;

    // Binance 14 hot wallet - a funded mainnet holder, NOT the pair itself.
    address internal constant FUNDED_HOLDER = 0x28C6c06298d514Db089934071355E5743bf21d60;

    address internal testUser = makeAddr("testUser");

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 25_949_200);

        submission = new Submission();

        uint256 usdtAmount = 5_000 * 1e6;
        uint256 wethAmount = 2 ether;

        vm.startPrank(FUNDED_HOLDER);
        INoReturnERC20(USDT).transfer(testUser, usdtAmount);
        INoReturnERC20(WETH).transfer(testUser, wethAmount);
        vm.stopPrank();

        vm.startPrank(testUser);
        INoReturnERC20(USDT).approve(address(submission), type(uint256).max);
        INoReturnERC20(WETH).approve(address(submission), type(uint256).max);
        vm.stopPrank();
    }

    function test_SwapUsdtForWethIncreasesRecipientBalance() public {
        uint256 amountIn = 1_000 * 1e6;
        uint256 wethBalanceBefore = IERC20(WETH).balanceOf(testUser);

        vm.prank(testUser);
        uint256 amountOut = submission.swapUsdtForWeth(
            amountIn,
            1,
            testUser,
            block.timestamp + 300
        );

        uint256 wethBalanceAfter = IERC20(WETH).balanceOf(testUser);

        assertGt(amountOut, 0, "amountOut should be nonzero");
        assertEq(
            wethBalanceAfter,
            wethBalanceBefore + amountOut,
            "recipient WETH balance should increase by amountOut"
        );
    }

    function test_AddLiquidityIncreasesRecipientLpBalance() public {
        uint256 usdtDesired = 1_000 * 1e6;
        uint256 wethDesired = 0.5 ether;

        uint256 lpBalanceBefore = IERC20(PAIR).balanceOf(testUser);

        vm.prank(testUser);
        (uint256 usdtUsed, uint256 wethUsed, uint256 liquidity) = submission.addUsdtWethLiquidity(
            usdtDesired,
            wethDesired,
            1,
            1,
            testUser,
            block.timestamp + 300
        );

        uint256 lpBalanceAfter = IERC20(PAIR).balanceOf(testUser);

        assertGt(liquidity, 0, "liquidity should be nonzero");
        assertGt(usdtUsed, 0, "usdtUsed should be nonzero");
        assertGt(wethUsed, 0, "wethUsed should be nonzero");
        assertEq(
            lpBalanceAfter,
            lpBalanceBefore + liquidity,
            "recipient LP balance should increase by liquidity"
        );
    }
}
