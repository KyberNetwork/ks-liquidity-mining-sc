// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.9;

import {IWETH} from 'contracts/interfaces/IWETH.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {ERC721} from '@openzeppelin/contracts/token/ERC721/ERC721.sol';

import {MockKPoolV2 as MockPool} from 'contracts/mock/MockKPoolV2.sol';
import {MockToken} from 'contracts/mock/MockToken.sol';

contract MockNftManagerV4 is ERC721 {
  address public weth;

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

  uint256 public currentTokenId;
  address public mockFactory;

  mapping(address => PoolInfo) internal _poolInfos;
  mapping(uint256 => Position) internal _positions;

  mapping(address => uint80) internal _addressToPoolId;
  mapping(uint256 => address) public nftInProMMPool;

  constructor(address _factory, address _weth) ERC721('MockNFT', 'MNFT') {
    mockFactory = _factory;
    weth = _weth;
  }

  function mint(address receiver, address toPoolProMM, uint128 liq) external returns (uint256) {
    _mint(receiver, currentTokenId);
    addLiquidity(currentTokenId, liq);
    setMockTick(currentTokenId, MIN_TICK, MAX_TICK);
    nftInProMMPool[currentTokenId] = toPoolProMM;
    _poolInfos[toPoolProMM] = PoolInfo({
      token0: MockPool(toPoolProMM).token0(),
      token1: MockPool(toPoolProMM).token1(),
      fee: 0
    });
    return currentTokenId++;
  }

  function setMockLiquidity(uint256 tokenId, uint128 _mockLiquidity) external {
    _positions[tokenId].liquidity = _mockLiquidity;
  }

  function addLiquidity(uint256 tokenId, uint128 liq) public {
    _positions[tokenId].liquidity += liq;
  }

  function removeLiquidity(
    RemoveLiquidityParams calldata params
  ) external returns (uint256 amount0, uint256 amount1, uint256 additionalRTokenOwed) {
    amount0 = params.liquidity;
    amount0 = amount0 * 10 ** 6;
    amount1 = params.liquidity;
    amount1 = amount1 * 10 ** 6;

    additionalRTokenOwed = params.liquidity;
    additionalRTokenOwed = additionalRTokenOwed * 10 ** 3;

    _positions[params.tokenId].liquidity -= params.liquidity;
    _positions[params.tokenId].rTokenOwed += additionalRTokenOwed;

    address token0 = MockPool(nftInProMMPool[params.tokenId]).token0();
    address token1 = MockPool(nftInProMMPool[params.tokenId]).token1();

    MockToken(token0).mint(address(this), amount0);
    MockToken(token1).mint(address(this), amount1);
  }

  function syncFeeGrowth(uint256 tokenId) external returns (uint256 additionalRTokenOwed) {
    additionalRTokenOwed = 10 ** 3;

    _positions[tokenId].rTokenOwed += additionalRTokenOwed;
  }

  function burnRTokens(
    BurnRTokenParams calldata params
  ) external returns (uint256 rTokenQty, uint256 amount0, uint256 amount1) {
    rTokenQty = _positions[params.tokenId].rTokenOwed;
    amount0 = rTokenQty;
    amount1 = rTokenQty;

    _positions[params.tokenId].rTokenOwed = 0;

    address token0 = MockPool(nftInProMMPool[params.tokenId]).token0();
    address token1 = MockPool(nftInProMMPool[params.tokenId]).token1();

    MockToken(token0).mint(address(this), amount0);
    MockToken(token1).mint(address(this), amount1);
  }

  function transferAllTokens(
    address token,
    uint256,
    /* minAmount */ address recipient
  ) external payable {
    MockToken(token).transfer(recipient, MockToken(token).balanceOf(address(this)));
  }

  function setMockTick(uint256 tokenId, int24 tickLower, int24 tickUpper) public {
    _positions[tokenId].tickLower = tickLower;
    _positions[tokenId].tickUpper = tickUpper;
  }

  function setMockFeeGrowthInsideLast(uint256 tokenId, uint256 _mockFeeGrowthInsideLast) external {
    _positions[tokenId].feeGrowthInsideLast = _mockFeeGrowthInsideLast;
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
    address poolAddress = nftInProMMPool[tokenId];
    pos = _positions[tokenId];
    pos.poolId = _addressToPoolId[poolAddress];
    info = _poolInfos[poolAddress];
  }

  function WETH() external view returns (address) {
    return weth;
  }

  function unwrapWeth(uint256 minAmount, address recipient) external payable {
    uint256 balanceWETH = IWETH(weth).balanceOf(address(this));
    require(balanceWETH >= minAmount, 'Insufficient WETH');

    if (balanceWETH > 0) {
      IWETH(weth).withdraw(balanceWETH);
      payable(recipient).transfer(balanceWETH);
    }
  }

  receive() external payable {}
}
