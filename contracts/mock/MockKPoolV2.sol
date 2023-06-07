// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.9;

contract MockKPoolV2 {
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

  struct PoolData {
    uint160 sqrtP;
    int24 nearestCurrentTick;
    int24 currentTick;
    bool locked;
    uint128 baseL;
    uint128 reinvestL;
    uint128 reinvestLLast;
    uint256 feeGrowthGlobal;
    uint128 secondsPerLiquidityGlobal;
    uint32 secondsPerLiquidityUpdateTime;
  }

  int24 public constant MIN_TICK = -887_272;
  int24 public constant MAX_TICK = 887_272;

  mapping(int24 => TickData) public ticks;

  uint256 public mockFeeGrowthGlobal;
  uint128 public mockSecondsPerLiquidityGlobal;

  int24 public mockCurrentTick;

  address public token0;
  address public token1;

  constructor(address _token0, address _token1) {
    token0 = _token0;
    token1 = _token1;
  }

  function totalSupply() external pure returns (uint256) {
    return 0;
  }

  function setMockFeeGrowthGlobal(uint256 _feeGrowthGlobal) external {
    mockFeeGrowthGlobal = _feeGrowthGlobal;
  }

  function setMockSecondsPerLiquidityGlobal(uint128 _secondsPerLiquidityGlobal) external {
    mockSecondsPerLiquidityGlobal = _secondsPerLiquidityGlobal;
  }

  function setMockCurrentTick(int24 _currentTick) external {
    mockCurrentTick = _currentTick;
  }

  function setMockInitTick(
    int24 tick,
    uint256 _feeGrowthOutside,
    uint128 _secondsPerLiquidityOutside
  ) external {
    ticks[tick].feeGrowthOutside = _feeGrowthOutside;
    ticks[tick].secondsPerLiquidityOutside = _secondsPerLiquidityOutside;
  }

  function getFeeGrowthGlobal() external view returns (uint256) {
    return mockFeeGrowthGlobal;
  }

  function getSecondsPerLiquidityInside(
    int24 tickLower,
    int24 tickUpper
  ) external view returns (uint128 secondsPerLiquidityInside) {
    require(tickLower <= tickUpper, 'bad tick range');
    int24 currentTick = mockCurrentTick;
    uint128 lowerValue = ticks[tickLower].secondsPerLiquidityOutside;
    uint128 upperValue = ticks[tickUpper].secondsPerLiquidityOutside;

    unchecked {
      if (currentTick < tickLower) {
        secondsPerLiquidityInside = lowerValue - upperValue;
      } else if (currentTick >= tickUpper) {
        secondsPerLiquidityInside = upperValue - lowerValue;
      } else {
        secondsPerLiquidityInside = mockSecondsPerLiquidityGlobal - (lowerValue + upperValue);
      }
    }
  }

  function getPoolState()
    external
    view
    returns (uint160 sqrtP, int24 currentTick, int24 nearestCurrentTick, bool locked)
  {
    sqrtP = 0;
    currentTick = mockCurrentTick;
    nearestCurrentTick = 1;
    locked = false;
  }

  function getLiquidityState()
    external
    pure
    returns (uint128 baseL, uint128 reinvestL, uint128 reinvestLLast)
  {
    baseL = 1;
    reinvestL = 1;
    reinvestLLast = 1;
  }
}
