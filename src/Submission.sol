// SPDX-License-Identifier: MIT
// Repository: https://github.com/YOUR_USERNAME/YOUR_REPO_NAME
// Commit: REPLACE_WITH_YOUR_ACTUAL_COMMIT_HASH
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface IUniswapV2Router02 {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
}

library SafeTokenOps {
    function safeApprove(IERC20 token, address spender, uint256 amount) internal {
        uint256 current = token.allowance(address(this), spender);
        if (current != 0) {
            _call(token, abi.encodeWithSelector(token.approve.selector, spender, 0));
        }
        if (amount != 0) {
            _call(token, abi.encodeWithSelector(token.approve.selector, spender, amount));
        }
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        _call(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, amount));
    }

    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        _call(token, abi.encodeWithSelector(token.transfer.selector, to, amount));
    }

    function _call(IERC20 token, bytes memory data) private {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) revert TokenCallFailed();
        if (returndata.length > 0) {
            if (!abi.decode(returndata, (bool))) revert TokenOperationReturnedFalse();
        }
    }
}

error TokenCallFailed();
error TokenOperationReturnedFalse();

contract Submission {
    using SafeTokenOps for IERC20;

    address public constant ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    bool private locked;

    error ReentrantCall();
    error AmountIsZero();
    error RecipientIsZeroAddress();

    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() internal {
        if (locked) revert ReentrantCall();
        locked = true;
    }

    function _nonReentrantAfter() internal {
        locked = false;
    }

    function swapUsdtForWeth(
        uint256 amountIn,
        uint256 amountOutMin,
        address recipient,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountOut) {
        if (amountIn == 0) revert AmountIsZero();
        if (recipient == address(0)) revert RecipientIsZeroAddress();

        IERC20 usdt = IERC20(USDT);

        usdt.safeTransferFrom(msg.sender, address(this), amountIn);
        usdt.safeApprove(ROUTER, amountIn);

        address[] memory path = new address[](2);
        path[0] = USDT;
        path[1] = WETH;

        uint256[] memory amounts = IUniswapV2Router02(ROUTER).swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            recipient,
            deadline
        );

        usdt.safeApprove(ROUTER, 0);

        amountOut = amounts[amounts.length - 1];
    }

    function addUsdtWethLiquidity(
        uint256 usdtDesired,
        uint256 wethDesired,
        uint256 usdtMin,
        uint256 wethMin,
        address recipient,
        uint256 deadline
    ) external nonReentrant returns (uint256 usdtUsed, uint256 wethUsed, uint256 liquidity) {
        if (usdtDesired == 0 || wethDesired == 0) revert AmountIsZero();
        if (recipient == address(0)) revert RecipientIsZeroAddress();

        IERC20 usdt = IERC20(USDT);
        IERC20 weth = IERC20(WETH);

        usdt.safeTransferFrom(msg.sender, address(this), usdtDesired);
        weth.safeTransferFrom(msg.sender, address(this), wethDesired);

        usdt.safeApprove(ROUTER, usdtDesired);
        weth.safeApprove(ROUTER, wethDesired);

        (usdtUsed, wethUsed, liquidity) = IUniswapV2Router02(ROUTER).addLiquidity(
            USDT,
            WETH,
            usdtDesired,
            wethDesired,
            usdtMin,
            wethMin,
            recipient,
            deadline
        );

        usdt.safeApprove(ROUTER, 0);
        weth.safeApprove(ROUTER, 0);

        if (usdtDesired > usdtUsed) {
            usdt.safeTransfer(msg.sender, usdtDesired - usdtUsed);
        }
        if (wethDesired > wethUsed) {
            weth.safeTransfer(msg.sender, wethDesired - wethUsed);
        }
    }
}
