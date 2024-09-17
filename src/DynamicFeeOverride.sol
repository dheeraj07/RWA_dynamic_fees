// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";

import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {LPFeeLibrary} from "v4-core/src/libraries/LPFeeLibrary.sol";
import {FunctionsConsumer} from "./FunctionsConsumer.sol";

/// @notice A dynamic fee, updated automatically with beforeSwap() using Chainlink FunctionsConsumer
contract DynamicFeeOverride is BaseHook {
    uint256 public immutable startTimestamp;

    uint256 public constant BASE_FEE = 1000; // 0.10% (in basis points)
    uint256 public constant VOLATILITY_FACTOR = 5; // 0.05% per 0.01 volatility increase
    uint256 public constant VOLATILITY_THRESHOLD = 20000; // 20% (scaled by 1000)
    uint256 public constant MIN_FEE = 500; // 0.05%
    uint256 public constant MAX_FEE = 10000; // 1%

    FunctionsConsumer functionsConsumer;

    constructor(IPoolManager _poolManager, address _consumerAddress) BaseHook(_poolManager) {
        startTimestamp = block.timestamp;
        functionsConsumer = FunctionsConsumer(_consumerAddress);
    }

    function beforeSwap(address, PoolKey calldata, IPoolManager.SwapParams calldata, bytes calldata)
    external
    override
    returns (bytes4, BeforeSwapDelta, uint24)
    {
        uint256 currentFee = calculateDynamicFee();

        uint256 overrideFee = currentFee | uint256(LPFeeLibrary.OVERRIDE_FEE_FLAG);
        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, uint24(overrideFee));
    }

    function calculateDynamicFee() internal view returns (uint256) {
        uint256 currentVolatility = functionsConsumer.volatility();
        
        if (currentVolatility <= VOLATILITY_THRESHOLD) {
            return BASE_FEE;
        }

        uint256 excessVolatility = currentVolatility - VOLATILITY_THRESHOLD;
        uint256 additionalFee = (excessVolatility * VOLATILITY_FACTOR) / 1000;
        uint256 totalFee = BASE_FEE + additionalFee;

        if (totalFee < MIN_FEE) {
            return MIN_FEE;
        } else if (totalFee > MAX_FEE) {
            return MAX_FEE;
        }
        return totalFee;
    }

    function afterInitialize(address, PoolKey calldata key, uint160, int24, bytes calldata)
        external
        override
        returns (bytes4)
    {
        uint256 initialFee = calculateDynamicFee();
        poolManager.updateDynamicLPFee(key, uint24(initialFee));
        return BaseHook.afterInitialize.selector;
    }

    /// @dev this example hook contract does not implement any hooks
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: true,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function stringToUint(string memory s) public pure returns (uint) {
        bytes memory b = bytes(s);
        uint result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            uint256 c = uint256(uint8(b[i]));
            if (c >= 48 && c <= 57) {
                result = result * 10 + (c - 48);
            }
        }
        return result;
    }
}