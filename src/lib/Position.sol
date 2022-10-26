// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

library Position {
    struct Info {
        uint128 liquidity;
    }

    function update(Info storage _self, uint128 _liquidityDelta) internal {
        uint128 liquidityBefore = _self.liquidity;
        uint128 liquidityAfter = liquidityBefore + _liquidityDelta;

        _self.liquidity = liquidityAfter;
    }

    function get(
        mapping(bytes32 => Info) storage _self,
        address _owner,
        int24 _lowerTick,
        int24 _upperTick
    ) internal view returns (Position.Info storage position) {
        position = _self[
            // Hash owner, lower and uper ticks into a single key. (32 bytes instead of 96 if they were separate keys).
            keccak256(abi.encodePacked(_owner, _lowerTick, _upperTick))
        ];
    }
}
