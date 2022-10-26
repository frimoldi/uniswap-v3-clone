// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

library Tick {
    struct Info {
        bool initialized;
        uint128 liquidity;
    }

    function update(
        mapping(int24 => Tick.Info) storage _self,
        int24 _tick,
        uint128 _liquidityDelta
    ) internal {
        Tick.Info storage tickInfo = _self[_tick];
        uint128 liquidityBefore = tickInfo.liquidity;
        uint128 liquidityAfter = tickInfo.liquidity + _liquidityDelta;

        if (liquidityBefore == 0) {
            tickInfo.initialized = true;
        }

        tickInfo.liquidity = liquidityAfter;
    }
}
