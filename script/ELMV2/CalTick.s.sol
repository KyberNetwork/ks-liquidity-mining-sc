// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

import {TickMath} from 'contracts/libraries/TickMath.sol';
import {FullMath} from 'contracts/libraries/FullMath.sol';

contract CalTick is Script {
  function _sqrt(uint x) internal pure returns (uint y) {
    uint z = (x + 1) / 2;
    y = x;
    while (z < y) {
      y = z;
      z = (x / z + z) / 2;
    }
  }

  function run() external {
    // uint160 priceX96 = 78435880889121694217608510832; // 0.99 * 2^96
    uint160 priceX96 = 2 ** 96; // 1 * 2^96
    uint256 sqrtPX48 = _sqrt(priceX96);
    uint256 sqrtPX96 = FullMath.mulDivFloor(sqrtPX48, 2 ** 96, 2 ** 48);
    int24 result = TickMath.getTickAtSqrtRatio(uint160(sqrtPX96));
    console.logInt(result);
  }
}
