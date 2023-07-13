// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.9;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract MockKPoolV3 {
  struct TickData {
    // gross liquidity of all positions in tick
    uint128 liquidityGross;
    // liquidity quantity to be added | removed when tick is crossed up | down
    int128 liquidityNet;
    // fee growth per unit of liquidity on the other side of this tick (relative to current tick)
    // only has relative meaning, not absolute — the value depends on when the tick is initialized
    uint256 feeGrowthOutside;
    // seconds spent on the other side of this tick (relative to current tick)
    // only has relative meaning, not absolute — the value depends on when the tick is initialized
    uint128 secondsPerLiquidityOutside;
  }

  int24 public constant MIN_TICK = -887_272;
  int24 public constant MAX_TICK = 887_272;

  IERC20 public token0;
  IERC20 public token1;

  uint160 internal sqrtP;
  int24 internal currentTick;
  int24 internal nearestCurrentTick;
  bool internal locked;

  uint128 internal baseL;
  uint128 internal reinvestL;
  uint128 internal reinvestLLast;

  uint256 public mockFeeGrowthGlobal;
  uint256 public mockSecondsPerLiquidityGlobal;

  constructor(IERC20 _token0, IERC20 _token1) {
    token0 = _token0;
    token1 = _token1;
  }

  function totalSupply() external pure returns (uint256) {
    return 0;
  }

  function setMockFeeGrowthGlobal(uint256 _mockFeeGrowthGlobal) external {
    mockFeeGrowthGlobal = _mockFeeGrowthGlobal;
  }

  function setMockSecondsPerLiquidityGlobal(uint256 _mockSecondsPerLiquidityGlobal) external {
    mockSecondsPerLiquidityGlobal = _mockSecondsPerLiquidityGlobal;
  }

  function setMockPoolState(
    uint160 _sqrtP,
    int24 _currentTick,
    int24 _nearestCurrentTick,
    bool _locked
  ) external {
    sqrtP = _sqrtP;
    currentTick = _currentTick;
    nearestCurrentTick = _nearestCurrentTick;
    locked = _locked;
  }

  function setMockLiquidityState(
    uint128 _baseL,
    uint128 _reinvestL,
    uint128 _reinvestLLast
  ) external {
    baseL = _baseL;
    reinvestL = _reinvestL;
    reinvestLLast = _reinvestLLast;
  }

  function ticks(int24 tick) external pure returns (TickData memory) {
    require(MIN_TICK <= tick && tick <= MAX_TICK, 'tick out of range');
    return
      TickData(
        /* liquidityGross */
        0,
        /* liquidityNet */
        0,
        /* feeGrowthOutside */
        0,
        /* secondsPerLiquidityOutside */
        0
      );
  }

  function getFeeGrowthGlobal() external view returns (uint256) {
    return mockFeeGrowthGlobal;
  }

  function getSecondsPerLiquidityInside(
    int24 tickLower,
    int24 tickUpper
  ) external view returns (uint256) {
    require(tickLower <= tickUpper, 'bad tick range');
    return mockSecondsPerLiquidityGlobal;
  }

  function getPoolState()
    external
    view
    returns (uint160 _sqrtP, int24 _currentTick, int24 _nearestCurrentTick, bool _locked)
  {
    _sqrtP = sqrtP;
    _currentTick = currentTick;
    _nearestCurrentTick = nearestCurrentTick;
    _locked = locked;
  }

  function getLiquidityState()
    external
    view
    returns (uint128 _baseL, uint128 _reinvestL, uint128 _reinvestLLast)
  {
    _baseL = baseL;
    _reinvestL = reinvestL;
    _reinvestLLast = reinvestLLast;
  }
}
