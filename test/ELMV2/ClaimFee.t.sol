// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {Test} from 'forge-std/Test.sol';
import {console} from 'forge-std/console.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {IKSElasticLMV2} from 'contracts/interfaces/IKSElasticLMV2.sol';
import {IKyberSwapFarmingToken} from 'contracts/interfaces/periphery/IKyberSwapFarmingToken.sol';
import {KSElasticLMV2} from 'contracts/KSElasticLMV2.sol';
import {IBasePositionManager} from 'contracts/interfaces/IBasePositionManager.sol';
import {MockNftManagerV4 as MockNftManager} from 'contracts/mock/MockNftManagerV4.sol';
import {MockKPoolV4 as MockPool} from 'contracts/mock/MockKPoolV4.sol';
import {MockToken} from 'contracts/mock/MockToken.sol';
import {KSElasticLMHelper} from 'contracts/KSElasticLMHelper.sol';
import {KyberSwapFarmingToken} from 'contracts/periphery/KyberSwapFarmingToken.sol';
import {Base} from './Base.t.sol';

//using mockNft since syncFeeGrowth are not in deployed posManager yet
contract ClaimFee is Base {
  using SafeERC20 for IERC20;
  MockNftManager mockNft;
  MockPool mockPool;
  MockToken mockUsdc;
  MockToken mockUsdt;

  function setUp() public override {
    mainnetFork = vm.createFork(ETH_NODE_URL);
    vm.selectFork(mainnetFork);
    vm.rollFork(16_146_028);

    deployer = makeAddr('Deployer');
    jensen = makeAddr('Jensen');
    rahoz = makeAddr('Rahoz');

    mockUsdc = new MockToken('USDC', 'USDC', 2000 * 10 ** 6);
    mockUsdt = new MockToken('USDT', 'USDT', 2000 * 10 ** 6);
    mockNft = new MockNftManager(address(this), WETH);
    mockPool = new MockPool(mockUsdc, mockUsdt);
    mockNft.setAddressToPoolId(address(mockPool), 12);

    vm.startPrank(deployer);
    helper = new KSElasticLMHelper();
    lm = new KSElasticLMV2(IERC721(address(mockNft)), helper);

    lm.updateOperator(deployer, true);
    lm.updateTokenCode(type(KyberSwapFarmingToken).creationCode);
    vm.stopPrank();

    vm.deal(deployer, 1000 ether);
    vm.deal(jensen, 1000 ether);

    rewards.push(
      IKSElasticLMV2.RewardInput({rewardToken: address(mockUsdc), rewardAmount: rewardAmount})
    );

    rewards.push(
      IKSElasticLMV2.RewardInput({rewardToken: address(mockUsdt), rewardAmount: rewardAmount})
    );

    phase.startTime = startTime;
    phase.endTime = endTime;
    phase.rewards = rewards;

    ranges.push(IKSElasticLMV2.RangeInput({tickLower: -4, tickUpper: 4, weight: 1}));
    ranges.push(IKSElasticLMV2.RangeInput({tickLower: -5, tickUpper: 5, weight: 2}));
    ranges.push(IKSElasticLMV2.RangeInput({tickLower: -10, tickUpper: 10, weight: 3}));

    vm.startPrank(deployer);
    fId = lm.addFarm(address(mockPool), ranges, phase, true);
    (, , , , address farmingTokenAddr, , ) = lm.getFarm(fId);

    farmingToken = IKyberSwapFarmingToken(farmingTokenAddr);

    mockUsdc.mint(address(lm), rewardAmount);
    mockUsdt.mint(address(lm), rewardAmount);
    vm.stopPrank();

    vm.label(address(usdc), 'USDC');
    vm.label(address(usdt), 'USDT');
    vm.label(address(nft), 'NFT');
  }

  function testSetUp() public override {
    assertEq(address(lm.getNft()), address(mockNft));

    (
      address lmPoolAddress,
      ,
      IKSElasticLMV2.PhaseInfo memory lmPhase,
      uint256 lmLiquidity,
      ,
      ,

    ) = lm.getFarm(fId);

    assertEq(lm.farmCount(), 1);
    assertEq(lmPoolAddress, address(mockPool));
    assertEq(lmPhase.startTime, startTime);
    assertEq(lmPhase.endTime, endTime);
    assertEq(lmLiquidity, 0);
  }

  function testClaimFeeSuccess() public {
    uint256 nftId = mockNft.mint(rahoz, address(mockPool), 10 ether);

    uint256[] memory nftIds = new uint256[](1);
    nftIds[0] = nftId;

    vm.startPrank(rahoz);
    mockNft.approve(address(lm), nftId);
    lm.deposit(fId, 0, nftIds, rahoz);
    vm.stopPrank();

    uint256 balanceUsdcBefore = mockUsdc.balanceOf(rahoz);
    uint256 balanceUsdtBefore = mockUsdt.balanceOf(rahoz);

    vm.startPrank(rahoz);
    lm.claimFee(fId, nftIds, 0, 0, endTime, false);
    vm.stopPrank();

    uint256 balanceUsdcAfter = mockUsdc.balanceOf(rahoz);
    uint256 balanceUsdtAfter = mockUsdt.balanceOf(rahoz);

    assertEq(balanceUsdcAfter - balanceUsdcBefore, 10 ** 3);
    assertEq(balanceUsdtAfter - balanceUsdtBefore, 10 ** 3);
  }

  function testClaimFeeFailStakeNotFound() public {
    uint256 nftId = mockNft.mint(rahoz, address(mockPool), 10 ether);

    uint256[] memory nftIds = new uint256[](1);
    nftIds[0] = nftId;

    vm.startPrank(deployer);
    uint256 fId2 = lm.addFarm(address(mockPool), ranges, phase, true);
    vm.stopPrank();

    vm.startPrank(rahoz);
    mockNft.approve(address(lm), nftId);
    lm.deposit(fId2, 0, nftIds, rahoz);
    vm.stopPrank();

    vm.startPrank(rahoz);
    vm.expectRevert(abi.encodeWithSignature('StakeNotFound()'));
    lm.claimFee(fId, nftIds, 0, 0, endTime, false);
    vm.stopPrank();
  }

  function testClaimFeeFailNotOwner() public {
    uint256 nftId = mockNft.mint(rahoz, address(mockPool), 10 ether);

    uint256[] memory nftIds = new uint256[](1);
    nftIds[0] = nftId;

    vm.startPrank(rahoz);
    mockNft.approve(address(lm), nftId);
    lm.deposit(fId, 0, nftIds, jensen);
    vm.stopPrank();

    vm.startPrank(rahoz);
    vm.expectRevert(abi.encodeWithSignature('NotOwner()'));
    lm.claimFee(fId, nftIds, 0, 0, endTime, false);
    vm.stopPrank();
  }
}
