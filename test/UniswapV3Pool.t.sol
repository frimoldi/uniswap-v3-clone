// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import {Test, stdError} from "forge-std/Test.sol";
import "./ERC20Mintable.sol";
import "../src/UniswapV3Pool.sol";

struct TestCaseParams {
    uint256 wethBalance;
    uint256 usdcBalance;
    int24 currentTick;
    int24 lowerTick;
    int24 upperTick;
    uint128 liquidity;
    uint160 currentSqrtP;
    bool shouldTransfer0InCallback;
    bool shouldTransfer1InCallback;
    bool mintLiqudity;
}

contract UniswapV3PoolTest is Test {
    ERC20Mintable token0;
    ERC20Mintable token1;
    UniswapV3Pool pool;

    bool shouldTransfer0InCallback;
    bool shouldTransfer1InCallback;

    function setUp() public {
        token0 = new ERC20Mintable("Ether", "ETH", 18);
        token1 = new ERC20Mintable("USDC", "USDC", 18);
    }

    function setupTestCase(TestCaseParams memory params)
        internal
        returns (uint256 poolBalance0, uint256 poolBalance1)
    {
        console.log("HERE");

        token0.mint(address(this), params.wethBalance);
        token1.mint(address(this), params.usdcBalance);

        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            params.currentSqrtP,
            params.currentTick
        );

        shouldTransfer0InCallback = params.shouldTransfer0InCallback;
        shouldTransfer1InCallback = params.shouldTransfer1InCallback;

        if (params.mintLiqudity) {
            (poolBalance0, poolBalance1) = pool.mint(
                address(this),
                params.lowerTick,
                params.upperTick,
                params.liquidity
            );
        }
    }

    function uniswapV3MintCallback(uint256 _amount0, uint256 _amount1) public {
        if (shouldTransfer0InCallback) token0.transfer(msg.sender, _amount0);
        if (shouldTransfer1InCallback) token1.transfer(msg.sender, _amount1);
    }

    function testMintSuccess() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            shouldTransfer0InCallback: true,
            shouldTransfer1InCallback: true,
            mintLiqudity: true
        });

        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

        uint256 expectedAmount0 = 0.998976618347425280 ether;
        uint256 expectedAmount1 = 5000 ether;

        assertEq(
            poolBalance0,
            expectedAmount0,
            "incorrect token0 deposited amount"
        );
        assertEq(
            poolBalance1,
            expectedAmount1,
            "incorrect token1 deposited amount"
        );

        // Tokens balance
        assertEq(token0.balanceOf(address(pool)), expectedAmount0);
        assertEq(token1.balanceOf(address(pool)), expectedAmount1);

        // Position
        bytes32 positionKey = keccak256(
            abi.encodePacked(address(this), params.lowerTick, params.upperTick)
        );
        uint128 positionLiquidity = pool.positions(positionKey);
        assertEq(positionLiquidity, params.liquidity);

        // Lower tick liquidity
        (bool tickInitialized, uint128 tickLiquidity) = pool.ticks(
            params.lowerTick
        );
        assertTrue(tickInitialized);
        assertEq(tickLiquidity, params.liquidity);

        // Upper tick liquidity
        (tickInitialized, tickLiquidity) = pool.ticks(params.upperTick);
        assertTrue(tickInitialized);
        assertEq(tickLiquidity, params.liquidity);

        // sqrt(P) and L
        (uint160 sqrtPriceX96, int24 tick) = pool.slot0();
        assertEq(
            sqrtPriceX96,
            5602277097478614198912276234240,
            "invalid current sqrtP"
        );
        assertEq(tick, 85176, "invalid current tick");
        assertEq(
            pool.liquidity(),
            1517882343751509868544,
            "invalid current liquidity"
        );
    }

    function testInvalidLowerTick() public {
        pool = new UniswapV3Pool(address(token0), address(token1), 1, 0);

        vm.expectRevert(UniswapV3Pool.InvalidTickRange.selector);

        pool.mint(address(this), -887273, 1, 1 ether);
    }

    function testInvalidUpperTick() public {
        pool = new UniswapV3Pool(address(token0), address(token1), 1, 0);

        vm.expectRevert(UniswapV3Pool.InvalidTickRange.selector);

        pool.mint(address(this), -1, 887273, 1 ether);
    }

    function testInvalidTickRange() public {
        pool = new UniswapV3Pool(address(token0), address(token1), 1, 0);

        vm.expectRevert(UniswapV3Pool.InvalidTickRange.selector);

        pool.mint(address(this), 5, 0, 1 ether);
    }

    function testZeroLiquidity() public {
        pool = new UniswapV3Pool(address(token0), address(token1), 1, 0);

        vm.expectRevert(UniswapV3Pool.ZeroLiquidity.selector);
        pool.mint(address(this), -5, 5, 0);
    }

    function testInsufficientInputAmount0() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            shouldTransfer0InCallback: false,
            shouldTransfer1InCallback: true,
            mintLiqudity: false
        });
        setupTestCase(params);

        vm.expectRevert(UniswapV3Pool.InsufficientInputAmount.selector);
        pool.mint(address(this), -5, 5, 1 ether);
    }

    function testInsufficientInputAmount1() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            shouldTransfer0InCallback: true,
            shouldTransfer1InCallback: false,
            mintLiqudity: false
        });
        setupTestCase(params);

        vm.expectRevert(UniswapV3Pool.InsufficientInputAmount.selector);
        pool.mint(address(this), -5, 5, 1 ether);
    }

    function testInsufficientTokens() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 0,
            usdcBalance: 0,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            shouldTransfer0InCallback: true,
            shouldTransfer1InCallback: true,
            mintLiqudity: false
        });
        setupTestCase(params);

        vm.expectRevert(stdError.arithmeticError);
        pool.mint(
            address(this),
            params.lowerTick,
            params.upperTick,
            params.liquidity
        );
    }
}
