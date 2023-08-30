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
import {MockToken} from 'contracts/mock/MockToken.sol';

import {FoundryHelper} from '../helpers/FoundryHelper.sol';

contract ElasticV2 is FoundryHelper {
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

  IKyberSwapFarmingToken farmingToken;

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

    rewards.push(
      IKSElasticLMV2.RewardInput({rewardToken: address(knc), rewardAmount: rewardAmount})
    );

    phase.startTime = startTime;
    phase.endTime = endTime;
    phase.rewards = rewards;

    ranges.push(IKSElasticLMV2.RangeInput({tickLower: -280000, tickUpper: -275000, weight: 1}));
    ranges.push(IKSElasticLMV2.RangeInput({tickLower: -280000, tickUpper: -270000, weight: 2}));

    vm.startPrank(deployer);
    fId = lm.addFarm(wmaticUsdtPool, ranges, phase, true);
    (, , , , address farmingTokenAddr, , ) = lm.getFarm(fId);

    farmingToken = IKyberSwapFarmingToken(farmingTokenAddr);
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

  function _buildFlags(
    bool isClaimFee,
    bool isSyncFee,
    bool isClaimReward,
    bool isReceiveNative
  ) internal pure returns (uint8 flags) {
    if (isReceiveNative) flags = 1;

    if (isClaimFee) flags = flags | (1 << 3);
    if (isSyncFee) flags = flags | (1 << 2);
    if (isClaimReward) flags = flags | (1 << 1);
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
    uint256 farmingTokenBalance = farmingToken.balanceOf(jensen);

    assertEq(fIdDeposited, fId);
    assertEq(rangeIdDeposited, 0);
    assertEq(nft.ownerOf(nftId), address(lm));
    assertEq(liquidityDeposited, nftIdLiq);
    assertEq(farmingTokenBalance, nftIdLiq + nftId2Liq + nftId3Liq);
    assertEq(lastSumRewardPerLiquidity[0], 0);

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

    assertApproxEqAbs(knc.balanceOf(jensen), rewardAmount / 3, 10);
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

    assertApproxEqAbs(knc.balanceOf(jensen), rewardAmount / 3, 10);
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
    uint256 farmingTokenBalance = farmingToken.balanceOf(jensen);

    assertEq(fIdDeposited, fId);
    assertEq(rangeIdDeposited, 0);
    assertEq(nft.ownerOf(nftId), address(lm));
    assertEq(liquidityDeposited, _getLiq(nftId));
    assertEq(farmingTokenBalance, _getLiq(nftId) + nftId2Liq + nftId3Liq);

    // calculating by formula joinedDuration * rewardAmount * 2^96 / farmLiq * duration
    // ((10 * 86400) * (10000 * 10^6) * 2^96) / (663143281305 * (30 * 86400))
    assertEq(lastSumRewardPerLiquidity[0], 11407717643217313169056717);
  }

  function testWithdrawEmgergency() public {
    vm.startPrank(deployer);
    lm.deposit(fId, 1, _toArray(nftId), jensen);
    vm.stopPrank();

    vm.warp(startTime + 1 days);

    vm.startPrank(jensen);
    uint256 farmingTokenBalance = farmingToken.balanceOf(jensen);
    farmingToken.approve(address(lm), farmingTokenBalance);
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
    lm.removeLiquidity(
      nftId,
      _getLiq(nftId),
      0,
      0,
      UINT256_MAX,
      _buildFlags(false, true, false, false)
    );
    vm.stopPrank();

    (
      ,
      uint256 fIdDeposited,
      uint256 rangeIdDeposited,
      uint256 liquidityDeposited,
      uint256[] memory lastSumRewardPerLiquidity,

    ) = lm.getStake(nftId);
    uint256 farmingTokenBalance = farmingToken.balanceOf(jensen);

    assertEq(fIdDeposited, fId);
    assertEq(rangeIdDeposited, 0);
    assertEq(nft.ownerOf(nftId), address(lm));
    assertEq(liquidityDeposited, 0);
    assertEq(farmingTokenBalance, nftId2Liq + nftId3Liq); // nftId2Liq + nftId3Liq

    // calculating by formula joinedDuration * rewardAmount * 2^96 / farmLiq * duration
    // ((10 * 86400) * (10000 * 10^6) * 2^96) / ((nftIdLiq + nftId2Liq + nftId3Liq) * (30 * 86400))
    assertEq(lastSumRewardPerLiquidity[0], 11407717643217313169056717); //
  }

  function testClaimFee() public {
    vm.startPrank(deployer);
    nft.approve(address(lm), nftId);
    lm.deposit(fId, 0, nftIds, jensen);
    vm.stopPrank();

    uint256 balanceBefore = payable(jensen).balance;

    vm.startPrank(jensen);
    lm.claimFee(fId, nftIds, 0, 0, UINT256_MAX, _buildFlags(false, true, false, true));
    vm.stopPrank();

    uint256 balanceAfter = payable(jensen).balance;

    // this number is returned by calling directly to nft
    assertEq(balanceAfter - balanceBefore, 25520262129608130);
  }

  function test_DepositClaimWithdrawMultiplePositions() public {
    uint256[] memory listNFT = new uint256[](2);
    listNFT[0] = nftId;
    listNFT[1] = nftId2;

    // deposit then claim
    vm.warp(startTime + 1 days);

    vm.startPrank(deployer);
    nft.setApprovalForAll(address(lm), true);
    lm.deposit(fId, 0, listNFT, jensen);
    vm.stopPrank();

    vm.warp(startTime + 5 days);

    uint256 balanceBefore = knc.balanceOf(jensen);

    vm.startPrank(jensen);
    lm.claimReward(fId, listNFT);
    vm.stopPrank();

    uint256 balanceAfter = knc.balanceOf(jensen);

    assertApproxEqAbs(balanceAfter - balanceBefore, (rewardAmount / 30) * 4, 10);

    vm.warp(startTime + 7 days);

    vm.startPrank(jensen);
    lm.withdraw(fId, listNFT);
    vm.stopPrank();

    listNFT = new uint256[](1);
    listNFT[0] = nftId;

    vm.startPrank(jensen);
    nft.setApprovalForAll(address(lm), true);
    lm.deposit(fId, 0, listNFT, rahoz);
    vm.stopPrank();

    listNFT = new uint256[](1);
    listNFT[0] = nftId3;

    vm.startPrank(deployer);
    lm.deposit(fId, 0, listNFT, rahoz);
    vm.stopPrank();

    vm.warp(endTime);

    listNFT = new uint256[](2);
    listNFT[0] = nftId;
    listNFT[1] = nftId3;

    balanceBefore = knc.balanceOf(rahoz);

    vm.startPrank(rahoz);
    lm.withdraw(fId, listNFT);
    vm.stopPrank();

    balanceAfter = knc.balanceOf(rahoz);

    assertApproxEqAbs(balanceAfter - balanceBefore, (rewardAmount / 30) * 23, 10);
  }

  function test_DepositClaimWithdrawThenDepositForOtherUser() public {
    uint256[] memory listNFT = new uint256[](1);
    listNFT[0] = nftId;

    vm.startPrank(deployer);
    lm.deposit(fId, 0, listNFT, jensen);
    vm.stopPrank();

    uint256 balanceBefore = knc.balanceOf(jensen);

    vm.warp(startTime + 10 days);

    vm.startPrank(jensen);
    lm.claimReward(fId, listNFT);
    vm.stopPrank();

    vm.warp(startTime + 15 days);

    vm.startPrank(jensen);
    lm.withdraw(fId, listNFT);
    vm.stopPrank();

    uint256 balanceAfter = knc.balanceOf(jensen);

    assertApproxEqAbs(balanceAfter - balanceBefore, (rewardAmount / 30) * 15, 10);

    vm.startPrank(jensen);
    nft.setApprovalForAll(address(lm), true);
    lm.deposit(fId, 0, listNFT, rahoz);
    vm.stopPrank();

    vm.warp(endTime);

    vm.startPrank(rahoz);
    lm.withdraw(fId, listNFT);
    vm.stopPrank();
  }

  function test_DepositThenAddRangeAndDepositAgain() public {
    uint256[] memory listNFT = new uint256[](1);
    listNFT[0] = nftId;

    uint256[] memory listNFT2 = new uint256[](1);
    listNFT2[0] = nftId2;

    vm.startPrank(deployer);
    lm.deposit(fId, 0, listNFT, jensen);
    vm.stopPrank();

    vm.startPrank(deployer);
    lm.deposit(fId, 0, listNFT2, rahoz);
    vm.stopPrank();

    uint256 balanceBefore = knc.balanceOf(jensen);

    // add range
    vm.startPrank(deployer);
    IKSElasticLMV2.RangeInput memory newRange = IKSElasticLMV2.RangeInput({
      tickLower: -280001,
      tickUpper: -275001,
      weight: 2
    });

    lm.addRange(fId, newRange);
    lm.removeRange(fId, 0);
    vm.stopPrank();

    vm.warp(startTime + 2 days);

    vm.startPrank(jensen);
    nft.setApprovalForAll(address(lm), true);
    lm.withdraw(fId, listNFT);
    lm.deposit(fId, 1, listNFT, jensen);
    vm.stopPrank();

    vm.warp(startTime + 3 days);

    vm.startPrank(jensen);
    lm.claimReward(fId, listNFT);
    vm.stopPrank();

    vm.warp(endTime);

    vm.startPrank(jensen);
    lm.withdraw(fId, listNFT);
    vm.stopPrank();

    uint256 balanceAfter = knc.balanceOf(jensen);

    uint256 rewardPeriod1 = _calcReward(
      2 days,
      rewardAmount,
      nftIdLiq,
      30 days,
      nftIdLiq + nftId2Liq
    );

    uint256 rewardPeriod2 = _calcReward(
      28 days,
      rewardAmount,
      nftIdLiq * 2,
      30 days,
      nftIdLiq * 2 + nftId2Liq
    );

    assertApproxEqAbs(balanceAfter - balanceBefore, rewardPeriod1 + rewardPeriod2, 10);
  }

  function test_DepositThenClosePhase() public {
    uint256[] memory listNFT = new uint256[](1);
    listNFT[0] = nftId;

    vm.startPrank(deployer);
    lm.deposit(fId, 0, listNFT, jensen);
    vm.stopPrank();

    vm.warp(startTime + 2 days);

    uint256 balanceBefore = knc.balanceOf(jensen);

    vm.startPrank(jensen);
    nft.setApprovalForAll(address(lm), true);

    lm.withdraw(fId, listNFT);
    lm.deposit(fId, 0, listNFT, jensen);

    vm.stopPrank();

    // force close phase after 3 day
    vm.warp(startTime + 3 days);

    vm.startPrank(deployer);
    lm.forceClosePhase(fId);
    vm.stopPrank();

    listNFT[0] = nftId2;

    vm.startPrank(deployer);
    vm.expectRevert(abi.encodeWithSignature('PhaseSettled()'));
    lm.deposit(fId, 0, listNFT, rahoz);
    vm.stopPrank();

    listNFT[0] = nftId;
    vm.startPrank(jensen);
    lm.withdraw(fId, listNFT);
    vm.stopPrank();

    uint256 balanceAfter = knc.balanceOf(jensen);

    assertApproxEqAbs(balanceAfter - balanceBefore, (rewardAmount / 30) * 3, 10);
  }

  function test_DepositThenWithdrawUnusedRewards() public {
    vm.startPrank(kncWhale);
    knc.transfer(address(lm), 1000 ether);
    vm.stopPrank();

    vm.startPrank(deployer);
    lm.deposit(fId, 1, _toArray(nftId), jensen);
    lm.deposit(fId, 0, _toArray(nftId2), jensen);
    lm.deposit(fId, 0, _toArray(nftId3), rahoz);
    vm.stopPrank();

    vm.warp(startTime + 5 days);

    vm.startPrank(jensen);
    lm.claimReward(fId, _toArray(nftId, nftId2));
    vm.stopPrank();

    vm.warp(endTime + 1 days);

    vm.startPrank(rahoz);
    lm.withdraw(fId, _toArray(nftId3));
    vm.stopPrank();

    vm.startPrank(jensen);
    lm.withdraw(fId, _toArray(nftId, nftId2));
    vm.stopPrank();

    uint256 farmBalance = knc.balanceOf(address(lm));
    assertApproxEqAbs(farmBalance, 1000 ether, 10);

    vm.startPrank(deployer);
    lm.withdrawUnusedRewards(_toArray(address(knc)), _toArray(farmBalance));
    vm.stopPrank();

    assertEq(knc.balanceOf(address(lm)), 0);
  }

  function test_DepositThenAddFarmAndWithdrawUnusedRewards() public {
    vm.startPrank(kncWhale);
    knc.transfer(address(lm), 1000 ether); // unused rewards
    vm.stopPrank();

    vm.startPrank(deployer);
    lm.deposit(fId, 0, _toArray(nftId), jensen);
    vm.stopPrank();

    vm.warp(endTime);

    vm.startPrank(jensen);
    lm.withdraw(fId, _toArray(nftId));
    vm.stopPrank();

    uint256 balanceFarm = knc.balanceOf(address(lm));
    assertApproxEqAbs(balanceFarm, 1000 ether, 10);

    uint32 startTime2 = uint32(block.timestamp) + 3600;
    uint32 endTime2 = startTime2 + 30 days;
    IKSElasticLMV2.PhaseInput memory phaseInput = IKSElasticLMV2.PhaseInput({
      startTime: startTime2,
      endTime: endTime2,
      rewards: rewards
    });

    vm.startPrank(deployer);
    uint256 fId2 = lm.addFarm(wmaticUsdtPool, ranges, phaseInput, true);
    vm.stopPrank();

    vm.startPrank(jensen);
    nft.setApprovalForAll(address(lm), true);
    lm.deposit(fId2, 0, _toArray(nftId), jensen);
    vm.stopPrank();

    vm.warp(endTime2);

    vm.startPrank(jensen);
    lm.withdraw(fId2, _toArray(nftId));
    vm.stopPrank();

    balanceFarm = knc.balanceOf(address(lm));
    assertApproxEqAbs(balanceFarm, 1000 ether - rewardAmount, 10);

    vm.startPrank(deployer);
    lm.withdrawUnusedRewards(_toArray(address(knc)), _toArray(balanceFarm));
    vm.stopPrank();

    assertEq(knc.balanceOf(address(lm)), 0);
  }

  function test_DepositThenAddPhase() public {
    vm.startPrank(kncWhale);
    knc.transfer(address(lm), 1000 ether); // reward for phase 2
    vm.stopPrank();

    vm.startPrank(deployer);
    lm.deposit(fId, 0, _toArray(nftId), jensen);
    vm.stopPrank();

    vm.warp(endTime);

    uint32 startTime2 = uint32(block.timestamp) + 3600;
    uint32 endTime2 = startTime2 + 30 days;
    IKSElasticLMV2.PhaseInput memory phaseInput = IKSElasticLMV2.PhaseInput({
      startTime: startTime2,
      endTime: endTime2,
      rewards: rewards
    });

    vm.startPrank(deployer);
    lm.addPhase(fId, phaseInput);
    vm.stopPrank();

    vm.warp(endTime2);

    vm.startPrank(jensen);
    lm.withdraw(fId, _toArray(nftId));
    vm.stopPrank();

    assertApproxEqAbs(knc.balanceOf(jensen), rewardAmount * 2, 10);
  }

  function test_DepositThenAddPhaseWith2PositionInFarm() public {
    vm.startPrank(deployer);
    lm.deposit(fId, 0, _toArray(nftId), jensen);
    vm.stopPrank();

    //junmp 10 days
    uint32 curTime = startTime + 10 days;
    vm.warp(curTime);

    // next phase data
    vm.startPrank(deployer);
    IKSElasticLMV2.PhaseInput memory phaseInput = IKSElasticLMV2.PhaseInput({
      startTime: curTime + 1 days,
      endTime: curTime + 31 days,
      rewards: rewards
    });
    lm.addPhase(fId, phaseInput);
    vm.stopPrank();

    vm.startPrank(kncWhale);
    knc.transfer(address(lm), rewardAmount);
    vm.stopPrank();

    vm.warp(curTime + 2 days);

    vm.startPrank(deployer);
    lm.deposit(fId, 0, _toArray(nftId2), rahoz);
    vm.stopPrank();

    vm.warp(curTime + 32 days);

    vm.startPrank(jensen);
    lm.withdraw(fId, _toArray(nftId));
    vm.stopPrank();

    uint256 rewardPhase1 = _calcReward(11 days, rewardAmount, nftIdLiq, 30 days, nftIdLiq);
    uint256 rewardPhase2 = _calcReward(
      29 days,
      rewardAmount,
      nftIdLiq,
      30 days,
      nftIdLiq + nftId2Liq
    );

    assertApproxEqAbs(knc.balanceOf(jensen), rewardPhase1 + rewardPhase2, 10);
  }

  function test_DepositAndAddLiquiditytoRemovedRange() public {
    vm.startPrank(deployer);
    lm.deposit(fId, 0, _toArray(nftId), jensen);
    vm.stopPrank();

    vm.startPrank(deployer);
    lm.removeRange(fId, 0);
    vm.stopPrank();

    //junmp 10 days
    uint32 curTime = startTime + 10 days;
    vm.warp(curTime);

    // add liquidity from NFT Manager
    _addLiquidity(nftId, 10 ether, 10 wei);

    vm.startPrank(jensen);
    // call to farm to update liquidity
    vm.expectRevert(abi.encodeWithSignature('RangeNotFound()'));
    lm.addLiquidity(fId, 0, _toArray(nftId));
    vm.stopPrank();
  }

  function test_DepositThenAddLiquidity() public {
    vm.startPrank(deployer);
    lm.deposit(fId, 0, _toArray(nftId), jensen);
    lm.deposit(fId, 0, _toArray(nftId2), rahoz);
    vm.stopPrank();

    //junmp 10 days
    uint32 curTime = startTime + 10 days;

    vm.warp(curTime);

    // add liquidity from NFT Manager
    _addLiquidity(nftId, 10 ether, 10 wei);

    // call to farm to update liquidity
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

    uint256 rewardPhase1 = _calcReward(
      10 days,
      rewardAmount,
      nftIdLiq,
      30 days,
      nftIdLiq + nftId2Liq
    );

    uint256 rewardPhase2 = _calcReward(
      20 days,
      rewardAmount,
      _getLiq(nftId),
      30 days,
      _getLiq(nftId) + nftId2Liq
    );

    assertApproxEqAbs(knc.balanceOf(jensen), rewardPhase1 + rewardPhase2, 10);
    assertApproxEqAbs(knc.balanceOf(rahoz), rewardAmount - rewardPhase1 - rewardPhase2, 10);
    assertApproxEqAbs(knc.balanceOf(address(lm)), 0, 10);
  }

  function test_AddRangeButTemporaryDisabledItAndActiveLater() public {
    uint256 range1Id = 0;
    uint256 range2Id = 2;
    uint256 range3Id = 3;

    IKSElasticLMV2.RangeInput memory newRange1 = IKSElasticLMV2.RangeInput({
      tickLower: -280001,
      tickUpper: -275001,
      weight: 2
    });

    IKSElasticLMV2.RangeInput memory newRange2 = IKSElasticLMV2.RangeInput({
      tickLower: -280001,
      tickUpper: -275001,
      weight: 3
    });

    vm.startPrank(deployer);
    lm.addRange(fId, newRange1);
    lm.addRange(fId, newRange2);
    lm.removeRange(fId, range2Id);
    lm.removeRange(fId, range3Id);
    vm.stopPrank();

    vm.startPrank(deployer);
    lm.deposit(fId, range1Id, _toArray(nftId), jensen); // active range
    vm.stopPrank();

    vm.startPrank(deployer);
    vm.expectRevert(abi.encodeWithSignature('RangeNotFound()')); // disabled range
    lm.deposit(fId, range2Id, _toArray(nftId2), jensen);

    vm.expectRevert(abi.encodeWithSignature('RangeNotFound()')); // disabled range
    lm.deposit(fId, range2Id, _toArray(nftId2), jensen);
    vm.stopPrank();

    vm.warp(startTime + 7 days);

    //some time later, operator will active those ranges so user can deposit to it
    vm.startPrank(deployer);
    lm.activateRange(fId, range2Id);
    lm.activateRange(fId, range3Id);
    vm.stopPrank();

    //user start deposit to new ranges
    vm.startPrank(jensen);
    lm.withdraw(fId, _toArray(nftId));

    nft.setApprovalForAll(address(lm), true);
    lm.deposit(fId, range2Id, _toArray(nftId), jensen); // new ranges
    vm.stopPrank();

    vm.startPrank(deployer);
    lm.deposit(fId, range3Id, _toArray(nftId2), rahoz); // active range
    vm.stopPrank();

    vm.warp(endTime);

    vm.startPrank(jensen);
    lm.withdraw(fId, _toArray(nftId));
    vm.stopPrank();

    vm.startPrank(rahoz);
    lm.withdraw(fId, _toArray(nftId2));
    vm.stopPrank();

    uint256 rewardJensenPeriod1 = _calcReward(7 days, rewardAmount, nftIdLiq, 30 days, nftIdLiq);
    uint256 rewardJensenPeriod2 = _calcReward(
      23 days,
      rewardAmount - rewardJensenPeriod1,
      nftIdLiq * 2,
      23 days,
      nftIdLiq * 2 + nftId2Liq * 3
    );
    uint256 rewardRahozPeriod2 = _calcReward(
      23 days,
      rewardAmount - rewardJensenPeriod1,
      nftId2Liq * 3,
      23 days,
      nftIdLiq * 2 + nftId2Liq * 3
    );

    assertApproxEqAbs(knc.balanceOf(jensen), rewardJensenPeriod1 + rewardJensenPeriod2, 10);
    assertApproxEqAbs(knc.balanceOf(rahoz), rewardRahozPeriod2, 10);
  }

  function test_RemoveRangeAndActiveAgain() public {
    uint256 rangeId = 0;

    vm.startPrank(deployer);
    lm.deposit(fId, rangeId, _toArray(nftId), jensen);
    vm.stopPrank();

    vm.startPrank(deployer);
    lm.deposit(fId, rangeId, _toArray(nftId2), rahoz);
    vm.stopPrank();

    vm.warp(startTime + 2 days);

    // remove range
    vm.startPrank(deployer);
    lm.removeRange(fId, rangeId);
    vm.stopPrank();

    vm.startPrank(jensen);
    lm.withdraw(fId, _toArray(nftId));
    vm.stopPrank();

    vm.warp(startTime + 4 days);

    vm.startPrank(deployer);
    lm.activateRange(fId, rangeId);
    vm.stopPrank();

    vm.startPrank(jensen);
    nft.setApprovalForAll(address(lm), true);
    lm.deposit(fId, rangeId, _toArray(nftId), jensen);
    vm.stopPrank();

    vm.warp(endTime);

    vm.startPrank(jensen);
    lm.withdraw(fId, _toArray(nftId));
    vm.stopPrank();

    vm.startPrank(rahoz);
    lm.withdraw(fId, _toArray(nftId2));
    vm.stopPrank();

    uint256 rewardJensenPeriod1 = _calcReward(
      2 days,
      rewardAmount,
      nftIdLiq,
      30 days,
      nftIdLiq + nftId2Liq
    );

    uint256 rewardRahozPeriod1 = _calcReward(
      2 days,
      rewardAmount,
      nftId2Liq,
      30 days,
      nftIdLiq + nftId2Liq
    );

    uint256 rewardRahozPeriod2 = _calcReward(
      2 days,
      rewardAmount - rewardJensenPeriod1 - rewardRahozPeriod1,
      nftId2Liq,
      28 days,
      nftId2Liq
    );

    uint256 rewardJensenPeriod3 = _calcReward(
      26 days,
      rewardAmount - rewardJensenPeriod1 - rewardRahozPeriod1 - rewardRahozPeriod2,
      nftIdLiq,
      26 days,
      nftIdLiq + nftId2Liq
    );

    uint256 rewardRahozPeriod3 = _calcReward(
      26 days,
      rewardAmount - rewardJensenPeriod1 - rewardRahozPeriod1 - rewardRahozPeriod2,
      nftId2Liq,
      26 days,
      nftIdLiq + nftId2Liq
    );

    assertApproxEqAbs(knc.balanceOf(jensen), rewardJensenPeriod1 + rewardJensenPeriod3, 10);
    assertApproxEqAbs(
      knc.balanceOf(rahoz),
      rewardRahozPeriod1 + rewardRahozPeriod2 + rewardRahozPeriod3,
      10
    );
  }
}
