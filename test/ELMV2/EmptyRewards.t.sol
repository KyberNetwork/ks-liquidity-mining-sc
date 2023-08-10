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
import {IBasePositionManager} from 'contracts/interfaces/IBasePositionManagerV2.sol';

import {FoundryHelper} from '../helpers/FoundryHelper.sol';

contract EmptyRewards is FoundryHelper {
  using SafeERC20 for IERC20;

  string POLYGON_NODE_URL = vm.envString('POLYGON_NODE_URL');
  address MATIC_ADDRESS = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
  address WMATIC = address(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);

  uint256 polygonFork;

  KSElasticLMV2 public lm;
  KSElasticLMHelper public helper;

  address wmaticUsdtPool = 0x46d90A00dbAd3961657c0328a9D1A7850523BE7c;
  IERC721 nft = IERC721(0xe222fBE074A436145b255442D919E4E3A6c6a480);
  IERC20 wmatic = IERC20(WMATIC);
  IERC20 usdt = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
  IERC20 knc = IERC20(0x1C954E8fe737F99f68Fa1CCda3e51ebDB291948C);

  address wmaticWhale = 0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97; //34M
  address usdtWhale = 0xF977814e90dA44bFA03b6295A0616a897441aceC; // 150M
  address kncWhale = 0x76C594e7057f9eC2c19452265EB1Dd90ae8274Ba; //500k

  address public jensen;
  address public rahoz;

  uint256 nftId = 1;
  uint256 nftId2 = 2;
  uint256 nftId3 = 5;

  uint256 nftIdLiq = 2771314335164;
  uint256 nftId2Liq = 20014612759279;
  uint256 nftId3Liq = 364529754791;

  uint256[] nftIds;

  IKSElasticLMV2.RewardInput[] public rewards;
  IKSElasticLMV2.PhaseInput public phase;
  IKSElasticLMV2.RangeInput[] public ranges;

  uint32 startTime = 1686639609;
  uint32 endTime = startTime + 30 days;

  uint256 rewardAmount = 10000 * 10 ** 6;

  uint256 fId;

  uint256 snapShotDeposit;

  function setUp() public virtual {
    polygonFork = vm.createFork(POLYGON_NODE_URL);
    vm.selectFork(polygonFork);
    vm.rollFork(43_800_000);

    deployer = makeAddr('Deployer');
    jensen = makeAddr('Jensen');
    rahoz = makeAddr('Rahoz');

    vm.startPrank(deployer);

    helper = new KSElasticLMHelper();
    lm = new KSElasticLMV2(nft, helper);

    lm.updateTokenCode(type(KyberSwapFarmingToken).creationCode);
    lm.updateOperator(deployer, true);

    nft.setApprovalForAll(address(lm), true);

    vm.stopPrank();

    vm.startPrank(kncWhale);
    knc.safeTransfer(address(lm), rewardAmount);
    vm.stopPrank();

    nftIds.push(nftId);
    nftIds.push(nftId2);
    nftIds.push(nftId3);

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

    phase.startTime = startTime;
    phase.endTime = endTime;
    phase.rewards = rewards;

    ranges.push(IKSElasticLMV2.RangeInput({tickLower: -280000, tickUpper: -275000, weight: 1}));
    ranges.push(IKSElasticLMV2.RangeInput({tickLower: -280000, tickUpper: -270000, weight: 2}));

    vm.startPrank(deployer);
    fId = lm.addFarm(wmaticUsdtPool, ranges, phase, false); // set to false to not using farmingToken
    vm.stopPrank();

    vm.label(address(wmatic), 'WMATIC');
    vm.label(address(usdt), 'USDT');
    vm.label(address(nft), 'NFT');
    vm.label(wmaticUsdtPool, 'Pool WMATIC-USDT');
  }

  function _getLiq(uint256 tokenId) internal view returns (uint128) {
    (IBasePositionManager.Position memory pos, ) = IBasePositionManager(address(nft)).positions(
      tokenId
    );

    return pos.liquidity;
  }

  function _addLiquidity(uint256 tokenId, uint256 amount0, uint256 amount1) internal {
    IBasePositionManager.IncreaseLiquidityParams memory params = IBasePositionManager
      .IncreaseLiquidityParams({
        tokenId: tokenId,
        ticksPrevious: [-887272, -887272],
        amount0Desired: amount0,
        amount1Desired: amount1,
        amount0Min: 0,
        amount1Min: 0,
        deadline: endTime + 1 days
      });

    vm.prank(wmaticWhale);
    wmatic.safeTransfer(address(this), amount0);

    vm.prank(usdtWhale);
    usdt.safeTransfer(address(this), amount1);

    wmatic.safeIncreaseAllowance(address(nft), amount0);
    usdt.safeIncreaseAllowance(address(nft), amount1);

    IBasePositionManager(address(nft)).addLiquidity(params);
  }

  function _calcReward(
    uint256 joinedDuration,
    uint256 reward,
    uint256 liq,
    uint256 duration,
    uint256 totalLiq
  ) internal pure returns (uint256 amount) {
    amount = (joinedDuration * reward * liq) / (duration * totalLiq);
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
    assertEq(lmPoolAddress, wmaticUsdtPool);
    assertEq(lmPhase.startTime, startTime);
    assertEq(lmPhase.endTime, endTime);
    assertEq(lmLiquidity, 0);
  }

  function testDeposit() public {
    vm.startPrank(deployer);
    nft.approve(address(lm), nftId);
    lm.deposit(fId, 0, nftIds, jensen);
    vm.stopPrank();

    (
      ,
      uint256 fIdDeposited,
      uint256 rangeIdDeposited,
      uint256 liquidityDeposited,
      uint256[] memory lastSumRewardPerLiquidity,

    ) = lm.getStake(nftId);

    assertEq(fIdDeposited, fId);
    assertEq(rangeIdDeposited, 0);
    assertEq(nft.ownerOf(nftId), address(lm));
    assertEq(liquidityDeposited, nftIdLiq);
    assertEq(lastSumRewardPerLiquidity.length, 0);

    uint256[] memory listNftIds = lm.getDepositedNFTs(jensen);
    assertEq(listNftIds.length, 3);
    assertEq(listNftIds[0], nftId);
    assertEq(listNftIds[1], nftId2);
    assertEq(listNftIds[2], nftId3);
  }

  function testClaimReward() public {
    vm.startPrank(deployer);
    nft.approve(address(lm), nftId);
    lm.deposit(fId, 0, nftIds, jensen);
    vm.stopPrank();

    vm.warp(startTime + 10 days);

    vm.startPrank(jensen);
    lm.claimReward(fId, nftIds);
    vm.stopPrank();

    assertEq(knc.balanceOf(jensen), 0);
  }

  function testWithdraw() public {
    vm.startPrank(deployer);
    nft.approve(address(lm), nftId);
    lm.deposit(fId, 0, nftIds, jensen);
    vm.stopPrank();

    vm.warp(startTime + 10 days);

    vm.startPrank(jensen);
    lm.withdraw(fId, nftIds);
    vm.stopPrank();

    assertEq(knc.balanceOf(jensen), 0);
    assertEq(nft.ownerOf(nftId), jensen);
  }

  function testAddLiquidity() public {
    vm.startPrank(deployer);
    nft.approve(address(lm), nftId);
    lm.deposit(fId, 0, nftIds, jensen);
    vm.stopPrank();

    vm.warp(startTime + 10 days);

    _addLiquidity(nftId, 1 ether, 1 wei);

    vm.startPrank(jensen);
    lm.addLiquidity(fId, 0, nftIds);
    vm.stopPrank();

    (
      ,
      uint256 fIdDeposited,
      uint256 rangeIdDeposited,
      uint256 liquidityDeposited,
      uint256[] memory lastSumRewardPerLiquidity,

    ) = lm.getStake(nftId);

    assertEq(fIdDeposited, fId);
    assertEq(rangeIdDeposited, 0);
    assertEq(nft.ownerOf(nftId), address(lm));
    assertEq(liquidityDeposited, _getLiq(nftId));

    // calculating by formula joinedDuration * rewardAmount * 2^96 / farmLiq * duration
    // ((10 * 86400) * (10000 * 10^6) * 2^96) / (663143281305 * (30 * 86400))
    assertEq(lastSumRewardPerLiquidity.length, 0);
  }

  function testWithdrawEmgergency() public {
    vm.startPrank(deployer);
    lm.deposit(fId, 1, _toArray(nftId), jensen);
    vm.stopPrank();

    vm.warp(startTime + 1 days);

    vm.startPrank(jensen);
    lm.withdrawEmergency(_toArray(nftId));
    vm.stopPrank();

    assertEq(nft.ownerOf(nftId), jensen);
  }

  function testRemoveLiquidity() public {
    vm.startPrank(deployer);
    nft.approve(address(lm), nftId);
    lm.deposit(fId, 0, nftIds, jensen);
    vm.stopPrank();

    vm.warp(startTime + 10 days);

    _addLiquidity(nftId, 1 ether, 1 wei);

    vm.startPrank(jensen);
    lm.removeLiquidity(nftId, _getLiq(nftId), 0, 0, UINT256_MAX, false, false);
    vm.stopPrank();

    (
      ,
      uint256 fIdDeposited,
      uint256 rangeIdDeposited,
      uint256 liquidityDeposited,
      uint256[] memory lastSumRewardPerLiquidity,

    ) = lm.getStake(nftId);

    assertEq(fIdDeposited, fId);
    assertEq(rangeIdDeposited, 0);
    assertEq(nft.ownerOf(nftId), address(lm));
    assertEq(liquidityDeposited, 0);

    assertEq(lastSumRewardPerLiquidity.length, 0);
  }

  function testClaimFee() public {
    vm.startPrank(deployer);
    nft.approve(address(lm), nftId);
    lm.deposit(fId, 0, nftIds, jensen);
    vm.stopPrank();

    uint256 balanceBefore = payable(jensen).balance;

    vm.startPrank(jensen);
    lm.claimFee(fId, nftIds, 0, 0, UINT256_MAX, true);
    vm.stopPrank();

    uint256 balanceAfter = payable(jensen).balance;

    // this number is returned by calling directly to nft
    assertEq(balanceAfter - balanceBefore, 25520262129608130);
  }

  // a few more complex cases
  function testAddPhase() public {
    vm.startPrank(deployer);
    nft.approve(address(lm), nftId);
    lm.deposit(fId, 0, _toArray(nftId), jensen);
    vm.stopPrank();

    vm.warp(startTime + 10 days);

    vm.startPrank(deployer);
    IKSElasticLMV2.PhaseInput memory phaseInput = IKSElasticLMV2.PhaseInput({
      startTime: startTime + 11 days,
      endTime: endTime + 11 days,
      rewards: rewards
    });

    lm.addPhase(fId, phaseInput);
    vm.stopPrank();

    vm.startPrank(deployer);
    nft.approve(address(lm), nftId2);
    lm.deposit(fId, 0, _toArray(nftId2), rahoz);
    vm.stopPrank();

    (
      ,
      uint256 fIdDeposited,
      uint256 rangeIdDeposited,
      uint256 liquidityDeposited,
      uint256[] memory lastSumRewardPerLiquidity,

    ) = lm.getStake(nftId);

    assertEq(fIdDeposited, fId);
    assertEq(rangeIdDeposited, 0);
    assertEq(nft.ownerOf(nftId), address(lm));
    assertEq(liquidityDeposited, nftIdLiq);
    assertEq(lastSumRewardPerLiquidity.length, 0);

    (, fIdDeposited, rangeIdDeposited, liquidityDeposited, lastSumRewardPerLiquidity, ) = lm
      .getStake(nftId2);

    assertEq(fIdDeposited, fId);
    assertEq(rangeIdDeposited, 0);
    assertEq(nft.ownerOf(nftId), address(lm));
    assertEq(liquidityDeposited, nftId2Liq);
    assertEq(lastSumRewardPerLiquidity.length, 0);

    vm.warp(endTime + 11 days);

    vm.startPrank(jensen);
    lm.withdraw(fId, _toArray(nftId));
    vm.stopPrank();

    vm.startPrank(rahoz);
    lm.withdraw(fId, _toArray(nftId2));
    vm.stopPrank();

    assertEq(nft.ownerOf(nftId), jensen);
    assertEq(nft.ownerOf(nftId2), rahoz);

    (, , , uint256 liquidity, , uint256[] memory sumRewardPerLiquidity, ) = lm.getFarm(fId);

    assertEq(liquidity, 0);
    assertEq(sumRewardPerLiquidity.length, 0);
    assertEq(knc.balanceOf(address(lm)), rewardAmount); // do not lose any rewards
  }

  function testForceClosePhase() public {
    vm.startPrank(deployer);
    nft.approve(address(lm), nftId);
    lm.deposit(fId, 0, _toArray(nftId), jensen);
    vm.stopPrank();

    vm.warp(startTime + 10 days);

    vm.startPrank(deployer);
    nft.approve(address(lm), nftId2);
    lm.deposit(fId, 0, _toArray(nftId2), rahoz);
    vm.stopPrank();

    vm.warp(startTime + 20 days);

    vm.startPrank(deployer);
    lm.forceClosePhase(fId);
    vm.stopPrank();

    vm.warp(endTime);

    vm.startPrank(jensen);
    lm.withdraw(fId, _toArray(nftId));
    vm.stopPrank();

    vm.startPrank(rahoz);
    lm.withdraw(fId, _toArray(nftId2));
    vm.stopPrank();

    assertEq(nft.ownerOf(nftId), jensen);
    assertEq(nft.ownerOf(nftId2), rahoz);

    (, , , uint256 liquidity, , uint256[] memory sumRewardPerLiquidity, ) = lm.getFarm(fId);

    assertEq(liquidity, 0);
    assertEq(sumRewardPerLiquidity.length, 0);
    assertEq(knc.balanceOf(address(lm)), rewardAmount); // do not lose any rewards
  }

  function testAddRange() public {
    vm.startPrank(deployer);
    nft.approve(address(lm), nftId);
    lm.deposit(fId, 0, _toArray(nftId), jensen);
    vm.stopPrank();

    vm.warp(startTime + 10 days);

    vm.startPrank(deployer);
    nft.approve(address(lm), nftId2);
    lm.deposit(fId, 0, _toArray(nftId2), rahoz);
    vm.stopPrank();

    vm.warp(startTime + 20 days);

    IKSElasticLMV2.RangeInput memory rangeInput = IKSElasticLMV2.RangeInput({
      tickLower: -280000,
      tickUpper: -275000,
      weight: 5
    });

    vm.startPrank(deployer);
    lm.addRange(fId, rangeInput);
    vm.stopPrank();

    vm.warp(startTime + 21 days);

    vm.startPrank(jensen);
    lm.withdraw(fId, _toArray(nftId));

    nft.approve(address(lm), nftId);
    lm.deposit(fId, 2, _toArray(nftId), jensen);
    vm.stopPrank();

    vm.startPrank(rahoz);
    lm.withdraw(fId, _toArray(nftId2));

    nft.approve(address(lm), nftId2);
    lm.deposit(fId, 2, _toArray(nftId2), rahoz);
    vm.stopPrank();

    vm.warp(endTime);

    vm.startPrank(jensen);
    lm.withdraw(fId, _toArray(nftId));
    vm.stopPrank();

    vm.startPrank(rahoz);
    lm.withdraw(fId, _toArray(nftId2));
    vm.stopPrank();

    assertEq(nft.ownerOf(nftId), jensen);
    assertEq(nft.ownerOf(nftId2), rahoz);

    (, , , uint256 liquidity, , uint256[] memory sumRewardPerLiquidity, ) = lm.getFarm(fId);

    assertEq(liquidity, 0);
    assertEq(sumRewardPerLiquidity.length, 0);
    assertEq(knc.balanceOf(address(lm)), rewardAmount); // do not lose any rewards
  }

  function testRemoveRange() public {
    vm.startPrank(deployer);
    nft.approve(address(lm), nftId);
    lm.deposit(fId, 0, _toArray(nftId), jensen);
    vm.stopPrank();

    vm.warp(startTime + 10 days);

    vm.startPrank(deployer);
    nft.approve(address(lm), nftId2);
    lm.deposit(fId, 0, _toArray(nftId2), rahoz);
    vm.stopPrank();

    vm.warp(startTime + 20 days);

    vm.startPrank(deployer);
    lm.removeRange(fId, 0);
    vm.stopPrank();

    vm.warp(startTime + 21 days);

    vm.startPrank(jensen);
    lm.withdraw(fId, _toArray(nftId));

    nft.approve(address(lm), nftId);
    lm.deposit(fId, 1, _toArray(nftId), jensen);
    vm.stopPrank();

    vm.warp(endTime);

    vm.startPrank(jensen);
    lm.withdraw(fId, _toArray(nftId));
    vm.stopPrank();

    vm.startPrank(rahoz);
    lm.withdraw(fId, _toArray(nftId2));
    vm.stopPrank();

    assertEq(nft.ownerOf(nftId), jensen);
    assertEq(nft.ownerOf(nftId2), rahoz);

    (, , , uint256 liquidity, , uint256[] memory sumRewardPerLiquidity, ) = lm.getFarm(fId);

    assertEq(liquidity, 0);
    assertEq(sumRewardPerLiquidity.length, 0);
    assertEq(knc.balanceOf(address(lm)), rewardAmount); // do not lose any rewards
  }

  function testActivateRange() public {
    vm.startPrank(deployer);
    nft.approve(address(lm), nftId);
    lm.deposit(fId, 0, _toArray(nftId), jensen);
    vm.stopPrank();

    vm.warp(startTime + 10 days);

    vm.startPrank(deployer);
    nft.approve(address(lm), nftId2);
    lm.deposit(fId, 0, _toArray(nftId2), rahoz);
    vm.stopPrank();

    vm.warp(startTime + 20 days);

    vm.startPrank(deployer);
    lm.removeRange(fId, 0);
    vm.stopPrank();

    vm.startPrank(jensen);
    lm.withdraw(fId, _toArray(nftId));
    vm.stopPrank();

    vm.startPrank(rahoz);
    lm.withdraw(fId, _toArray(nftId2));
    vm.stopPrank();

    vm.warp(startTime + 21 days);

    vm.startPrank(deployer);
    lm.activateRange(fId, 0);
    vm.stopPrank();

    vm.startPrank(jensen);
    nft.approve(address(lm), nftId);
    lm.deposit(fId, 0, _toArray(nftId), jensen);
    vm.stopPrank();

    vm.startPrank(rahoz);
    nft.approve(address(lm), nftId2);
    lm.deposit(fId, 0, _toArray(nftId2), rahoz);
    vm.stopPrank();

    vm.warp(endTime);

    vm.startPrank(jensen);
    lm.withdraw(fId, _toArray(nftId));
    vm.stopPrank();

    vm.startPrank(rahoz);
    lm.withdraw(fId, _toArray(nftId2));
    vm.stopPrank();

    assertEq(nft.ownerOf(nftId), jensen);
    assertEq(nft.ownerOf(nftId2), rahoz);

    (, , , uint256 liquidity, , uint256[] memory sumRewardPerLiquidity, ) = lm.getFarm(fId);

    assertEq(liquidity, 0);
    assertEq(sumRewardPerLiquidity.length, 0);
    assertEq(knc.balanceOf(address(lm)), rewardAmount); // do not lose any rewards
  }

  function testDepositSameNftMultipleTimes() public {
    vm.startPrank(deployer);
    nft.approve(address(lm), nftId);
    lm.deposit(fId, 0, _toArray(nftId), jensen);
    vm.stopPrank();

    vm.warp(startTime + 10 days);

    vm.startPrank(deployer);
    nft.approve(address(lm), nftId2);
    lm.deposit(fId, 0, _toArray(nftId2), rahoz);
    vm.stopPrank();

    vm.warp(startTime + 20 days);

    vm.startPrank(jensen);
    lm.withdraw(fId, _toArray(nftId));

    nft.approve(address(lm), nftId);
    lm.deposit(fId, 0, _toArray(nftId), jensen);
    vm.stopPrank();

    vm.startPrank(rahoz);
    lm.withdraw(fId, _toArray(nftId2));
    vm.stopPrank();

    vm.warp(startTime + 21 days);

    vm.startPrank(rahoz);
    nft.approve(address(lm), nftId2);
    lm.deposit(fId, 0, _toArray(nftId2), rahoz);
    vm.stopPrank();

    vm.startPrank(jensen);
    lm.withdraw(fId, _toArray(nftId));
    vm.stopPrank();

    vm.startPrank(rahoz);
    lm.withdraw(fId, _toArray(nftId2));
    vm.stopPrank();

    assertEq(nft.ownerOf(nftId), jensen);
    assertEq(nft.ownerOf(nftId2), rahoz);

    (, , , uint256 liquidity, , uint256[] memory sumRewardPerLiquidity, ) = lm.getFarm(fId);

    assertEq(liquidity, 0);
    assertEq(sumRewardPerLiquidity.length, 0);
    assertEq(knc.balanceOf(address(lm)), rewardAmount);
  }

  function testDepositClaimRewardAddLiquidity() public {
    vm.startPrank(deployer);
    nft.approve(address(lm), nftId);
    lm.deposit(fId, 0, _toArray(nftId), jensen);
    vm.stopPrank();

    vm.warp(startTime + 10 days);

    vm.startPrank(deployer);
    nft.approve(address(lm), nftId2);
    lm.deposit(fId, 0, _toArray(nftId2), rahoz);
    vm.stopPrank();

    vm.warp(startTime + 20 days);

    _addLiquidity(nftId, 1 ether, 1 wei);
    vm.startPrank(jensen);
    lm.addLiquidity(fId, 0, _toArray(nftId));
    vm.stopPrank();

    vm.warp(endTime);

    vm.startPrank(jensen);
    lm.withdraw(fId, _toArray(nftId));
    vm.stopPrank();

    vm.startPrank(rahoz);
    lm.withdraw(fId, _toArray(nftId2));
    vm.stopPrank();

    assertEq(nft.ownerOf(nftId), jensen);
    assertEq(nft.ownerOf(nftId2), rahoz);

    (, , , uint256 liquidity, , uint256[] memory sumRewardPerLiquidity, ) = lm.getFarm(fId);

    assertEq(liquidity, 0);
    assertEq(sumRewardPerLiquidity.length, 0);
    assertEq(knc.balanceOf(address(lm)), rewardAmount); // do not lose any rewards
  }

  function testDepositClaimRewardRemoveLiquidity() public {
    vm.startPrank(deployer);
    nft.approve(address(lm), nftId);
    lm.deposit(fId, 0, _toArray(nftId), jensen);
    vm.stopPrank();

    vm.warp(startTime + 10 days);

    vm.startPrank(deployer);
    nft.approve(address(lm), nftId2);
    lm.deposit(fId, 0, _toArray(nftId2), rahoz);
    vm.stopPrank();

    vm.warp(startTime + 20 days);

    uint256 maticAmount = 1479293259822358137 + 3055000975670181; //amount from remove liq + claim fee
    uint256 usdtAmount = 994742 + 1983;

    vm.startPrank(jensen);
    lm.removeLiquidity(nftId, uint128(nftIdLiq), 0, 0, MAX_UINT256, true, true);
    vm.stopPrank();

    assertEq(payable(jensen).balance, 1000 ether + maticAmount);
    assertEq(usdt.balanceOf(jensen), usdtAmount);
  }

  function testDepositClaimRewardClaimFee() public {
    vm.startPrank(deployer);
    nft.approve(address(lm), nftId);
    lm.deposit(fId, 0, _toArray(nftId), jensen);
    vm.stopPrank();

    vm.warp(startTime + 10 days);

    vm.startPrank(deployer);
    nft.approve(address(lm), nftId2);
    lm.deposit(fId, 0, _toArray(nftId2), rahoz);
    vm.stopPrank();

    vm.warp(startTime + 20 days);

    uint256 maticAmount = 3055000975670181; //amount from remove liq + claim fee
    uint256 usdtAmount = 1983;

    vm.startPrank(jensen);
    lm.claimFee(fId, _toArray(nftId), 0, 0, MAX_UINT256, true);
    vm.stopPrank();

    assertEq(payable(jensen).balance, 1000 ether + maticAmount);
    assertEq(usdt.balanceOf(jensen), usdtAmount);
  }

  function testDepositWithdrawEmergencyDepositAgain() public {
    vm.startPrank(deployer);
    nft.approve(address(lm), nftId);
    lm.deposit(fId, 0, _toArray(nftId), jensen);
    vm.stopPrank();

    vm.warp(startTime + 10 days);

    vm.startPrank(deployer);
    nft.approve(address(lm), nftId2);
    lm.deposit(fId, 0, _toArray(nftId2), rahoz);
    vm.stopPrank();

    vm.warp(startTime + 20 days);

    vm.startPrank(jensen);
    lm.withdrawEmergency(_toArray(nftId));
    vm.stopPrank();

    assertEq(nft.ownerOf(nftId), jensen);

    vm.startPrank(jensen);
    nft.approve(address(lm), nftId);
    lm.deposit(fId, 0, _toArray(nftId), jensen);
    vm.stopPrank();

    vm.warp(endTime);

    vm.startPrank(jensen);
    lm.withdraw(fId, _toArray(nftId));
    vm.stopPrank();

    vm.startPrank(rahoz);
    lm.withdraw(fId, _toArray(nftId2));
    vm.stopPrank();

    assertEq(nft.ownerOf(nftId), jensen);
    assertEq(nft.ownerOf(nftId2), rahoz);

    (, , , uint256 liquidity, , uint256[] memory sumRewardPerLiquidity, ) = lm.getFarm(fId);

    assertEq(liquidity, 0);
    assertEq(sumRewardPerLiquidity.length, 0);
    assertEq(knc.balanceOf(address(lm)), rewardAmount); // do not lose any rewards
  }
}
