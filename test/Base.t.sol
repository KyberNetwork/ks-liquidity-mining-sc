// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {Test} from 'forge-std/Test.sol';
import {console} from 'forge-std/console.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {IKSElasticLMV2} from 'contracts/interfaces/IKSElasticLMV2.sol';
import {IKSElasticLMHelper} from 'contracts/interfaces/IKSElasticLMHelper.sol';
import {IKyberSwapFarmingToken} from 'contracts/interfaces/periphery/IKyberSwapFarmingToken.sol';
import {KyberSwapFarmingToken} from 'contracts/periphery/KyberSwapFarmingToken.sol';
import {KSElasticLMV2} from 'contracts/KSElasticLMV2.sol';
import {KSElasticLMHelper} from 'contracts/KSElasticLMHelper.sol';
import {IBasePositionManager} from 'contracts/interfaces/IBasePositionManager.sol';

contract Base is Test {
  using SafeERC20 for IERC20;

  string ETH_NODE_URL = vm.envString('ETH_NODE_URL');
  address ETH_ADDRESS = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
  address WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

  uint256 mainnetFork;

  KSElasticLMV2 public lm;
  KSElasticLMHelper public helper;

  address pool = 0x952FfC4c47D66b454a8181F5C68b6248E18b66Ec;
  IERC721 nft = IERC721(0x2B1c7b41f6A8F2b2bc45C3233a5d5FB3cD6dC9A8);
  IERC20 usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
  IERC20 usdt = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);

  address usdcWhale = 0x0A59649758aa4d66E25f08Dd01271e891fe52199;
  address usdtWhale = 0x5754284f345afc66a98fbB0a0Afe71e0F007B949;

  address public deployer;
  address public jensen;
  address public rahoz;

  uint256[] nftIds; // from pool usdc-usdt

  IKSElasticLMV2.RewardInput[] public rewards;
  IKSElasticLMV2.PhaseInput public phase;
  IKSElasticLMV2.RangeInput[] public ranges;

  uint32 startTime = 1670578490;
  uint32 endTime = 1673208490;

  uint256 rewardAmount = 1000 * 10 ** 6;

  uint256 fId;
  uint256 fETHId;

  IKyberSwapFarmingToken farmingToken;
  IKyberSwapFarmingToken ETHfarmingToken;

  uint256 snapShotDeposit;

  function setUp() public virtual {
    mainnetFork = vm.createFork(ETH_NODE_URL);
    vm.selectFork(mainnetFork);
    vm.rollFork(16_146_028);

    deployer = makeAddr('Deployer');
    jensen = makeAddr('Jensen');
    rahoz = makeAddr('Rahoz');

    vm.startPrank(deployer);

    helper = new KSElasticLMHelper();
    lm = new KSElasticLMV2(nft, helper);

    lm.updateTokenCode(type(KyberSwapFarmingToken).creationCode);
    lm.updateOperator(deployer, true);
    vm.stopPrank();

    vm.startPrank(usdcWhale);
    usdc.safeTransfer(deployer, 2000 * 10 ** 6);
    vm.stopPrank();

    vm.startPrank(usdtWhale);
    usdt.safeTransfer(deployer, 2000 * 10 ** 6);
    vm.stopPrank();

    vm.startPrank(deployer);
    usdc.safeIncreaseAllowance(address(lm), 2 ** 256 - 1);
    usdt.safeIncreaseAllowance(address(lm), 2 ** 256 - 1);
    vm.stopPrank();

    vm.startPrank(jensen);
    usdc.safeIncreaseAllowance(address(lm), 2 ** 256 - 1);
    usdt.safeIncreaseAllowance(address(lm), 2 ** 256 - 1);
    vm.stopPrank();

    nftIds.push(18);
    nftIds.push(22);
    nftIds.push(99);

    for (uint256 i; i < nftIds.length; ) {
      address owner = nft.ownerOf(nftIds[i]);

      vm.prank(owner);
      nft.transferFrom(owner, deployer, nftIds[i]);

      unchecked {
        ++i;
      }
    }

    vm.deal(deployer, 1000 ether);
    vm.deal(jensen, 1000 ether);

    rewards.push(
      IKSElasticLMV2.RewardInput({rewardToken: address(usdc), rewardAmount: rewardAmount})
    );

    rewards.push(
      IKSElasticLMV2.RewardInput({rewardToken: address(usdt), rewardAmount: rewardAmount})
    );

    phase.startTime = startTime;
    phase.endTime = endTime;
    phase.rewards = rewards;

    ranges.push(IKSElasticLMV2.RangeInput({tickLower: -4, tickUpper: 4, weight: 1}));
    ranges.push(IKSElasticLMV2.RangeInput({tickLower: -5, tickUpper: 5, weight: 2}));
    ranges.push(IKSElasticLMV2.RangeInput({tickLower: -10, tickUpper: 10, weight: 3}));

    vm.startPrank(deployer);
    fId = lm.addFarm(pool, ranges, phase, true);
    (, , , , address farmingTokenAddr, , ) = lm.getFarm(fId);

    farmingToken = IKyberSwapFarmingToken(farmingTokenAddr);

    usdc.safeTransfer(address(lm), rewardAmount);
    usdt.safeTransfer(address(lm), rewardAmount);
    vm.stopPrank();

    vm.label(address(usdc), 'USDC');
    vm.label(address(usdt), 'USDT');
    vm.label(address(nft), 'NFT');
    vm.label(pool, 'Pool ID 12');
  }

  function _getLiq(uint256 nftId) internal view returns (uint128) {
    (IBasePositionManager.Position memory pos, ) = IBasePositionManager(address(nft)).positions(
      nftId
    );

    return pos.liquidity;
  }

  function _addLiquidity(uint256 nftId) internal {
    IBasePositionManager.IncreaseLiquidityParams memory params = IBasePositionManager
      .IncreaseLiquidityParams({
        tokenId: nftId,
        amount0Desired: 1000 * 10 ** 6,
        amount1Desired: 1000 * 10 ** 6,
        amount0Min: 0,
        amount1Min: 0,
        deadline: endTime + 1 days
      });

    vm.startPrank(deployer);
    usdc.safeIncreaseAllowance(address(nft), 2 ** 256 - 1);
    usdt.safeIncreaseAllowance(address(nft), 2 ** 256 - 1);
    IBasePositionManager(address(nft)).addLiquidity(params);
    vm.stopPrank();
  }

  function testSetUp() public virtual {
    assertEq(address(lm.getNft()), address(nft));

    (
      address lmPoolAddress,
      ,
      IKSElasticLMV2.PhaseInfo memory lmPhase,
      uint256 lmLiquidity,
      ,
      ,

    ) = lm.getFarm(fId);

    assertEq(lm.farmCount(), 1);
    assertEq(lmPoolAddress, pool);
    assertEq(lmPhase.startTime, startTime);
    assertEq(lmPhase.endTime, endTime);
    assertEq(lmLiquidity, 0);
  }

  function _verifyUintArray(uint256[] memory A, uint256[] memory B) internal {
    assertTrue(A.length == B.length, 'array length not eq');
    for (uint256 i; i < A.length; ++i) {
      assertTrue(A[i] == B[i], 'array element not eq');
    }
  }

  function _getRewardBalances(address owner) internal view returns (uint256[] memory array) {
    array = new uint256[](rewards.length);
    for (uint256 i; i < rewards.length; ++i) {
      array[i] = IERC20(rewards[i].rewardToken).balanceOf(owner);
    }
  }

  function _inUintArray(
    uint256 element,
    uint256[] memory array
  ) internal pure returns (bool result) {
    result = false;
    for (uint256 i; i < array.length; ++i) {
      if (array[i] == element) {
        result = true;
        break;
      }
    }
  }
}
