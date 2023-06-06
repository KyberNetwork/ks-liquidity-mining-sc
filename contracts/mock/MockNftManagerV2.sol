// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.9;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {ERC721} from '@openzeppelin/contracts/token/ERC721/ERC721.sol';

contract MockNftManagerV2 is ERC721 {
  struct Position {
    // the nonce for permits
    uint96 nonce;
    // the address that is approved for spending this token
    address operator;
    // the ID of the pool with which this token is connected
    uint80 poolId;
    // the tick range of the position
    int24 tickLower;
    int24 tickUpper;
    // the liquidity of the position
    uint128 liquidity;
    // the current rToken that the position owed
    uint256 rTokenOwed;
    // fee growth per unit of liquidity as of the last update to liquidity
    uint256 feeGrowthInsideLast;
  }

  struct PoolInfo {
    address token0;
    uint16 fee;
    address token1;
  }

  struct RemoveLiquidityParams {
    uint256 tokenId;
    uint128 liquidity;
    uint256 amount0Min;
    uint256 amount1Min;
    uint256 deadline;
  }

  struct BurnRTokenParams {
    uint256 tokenId;
    uint256 amount0Min;
    uint256 amount1Min;
    uint256 deadline;
  }

  int24 internal constant MIN_TICK = -887_272;
  int24 internal constant MAX_TICK = 887_272;

  address public mockFactory;
  address public mockToken0;
  address public mockToken1;
  address public weth;

  // uint256 public mockLiquidity;
  mapping(uint256 => uint128) public mockLiquidity;
  mapping(uint256 => int24) public mockMinTick;
  mapping(uint256 => int24) public mockMaxTick;

  uint256 public mockFeeGrowthInsideLast;
  uint256 public currentTokenId;

  mapping(address => uint80) internal _addressToPoolId;
  mapping(uint256 => Position) internal _positions;

  mapping(uint256 => address) public nftInProMMPool;

  constructor(
    address _factory,
    address _token0,
    address _token1,
    address _weth
  ) ERC721('MockNFT', 'MNFT') {
    mockFactory = _factory;
    mockToken0 = _token0;
    mockToken1 = _token1;
    weth = _weth;
  }

  function mint(
    address receiver,
    address toPoolProMM,
    uint128 liquidity,
    int24 minTick,
    int24 maxTick
  ) external returns (uint256) {
    _mint(receiver, currentTokenId);
    addLiquidity(currentTokenId, liquidity);
    addMinTick(currentTokenId, minTick);
    addMaxTick(currentTokenId, maxTick);

    nftInProMMPool[currentTokenId] = toPoolProMM;
    return currentTokenId++;
  }

  function setMockLiquidity(uint256 tokenId, uint128 _mockLiquidity) external {
    mockLiquidity[tokenId] = _mockLiquidity;
  }

  function addLiquidity(uint256 tokenId, uint128 liq) public {
    mockLiquidity[tokenId] += liq;
  }

  function addMinTick(uint256 tokenId, int24 tick) public {
    mockMinTick[tokenId] = tick;
  }

  function addMaxTick(uint256 tokenId, int24 tick) public {
    mockMaxTick[tokenId] = tick;
  }

  function removeLiquidity(
    RemoveLiquidityParams memory params
  ) external returns (uint256 amount0, uint256 amount1, uint256 additionalRTokenOwed) {
    //to disable warnings
    amount0 = 0;
    amount1 = 0;
    additionalRTokenOwed = 0;

    mockLiquidity[params.tokenId] -= params.liquidity;
  }

  function burnRTokens(
    BurnRTokenParams memory /* params */
  ) external returns (uint256 rTokenQty, uint256 amount0, uint256 amount1) {}

  function transferAllTokens(
    address token,
    uint256 /* minAmount */,
    address recipient
  ) external payable {
    IERC20(token).transfer(recipient, IERC20(token).balanceOf(address(this)));
  }

  function setMockFeeGrowthInsideLast(uint256 _mockFeeGrowthInsideLast) external {
    mockFeeGrowthInsideLast = _mockFeeGrowthInsideLast;
  }

  function setAddressToPoolId(address pool, uint80 id) external {
    _addressToPoolId[pool] = id;
  }

  // address of promm pool will belong to pool promm id
  function addressToPoolId(address pool) external view returns (uint80) {
    return _addressToPoolId[pool];
  }

  function positions(
    uint256 tokenId
  ) external view returns (Position memory pos, PoolInfo memory info) {
    pos = Position(
      /* nonce */
      0,
      /* operator */
      address(0),
      /* poolId */
      _addressToPoolId[nftInProMMPool[tokenId]],
      /* tickLower */
      mockMinTick[tokenId],
      /* tickUpper */
      mockMaxTick[tokenId],
      /* liquidity */
      mockLiquidity[tokenId],
      /* rTokenOwed */
      0,
      /* feeGrowthInsideLast */
      mockFeeGrowthInsideLast
    );
    info = PoolInfo(
      /* token0 */
      mockToken0,
      /* fee */
      0,
      /* token1 */
      mockToken1
    );
  }

  function WETH() external view returns (address) {
    return weth;
  }
}
