// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {FoundryHelper} from '../helpers/FoundryHelper.sol';
import {KSElasticLMV2} from 'contracts/KSElasticLMV2.sol';
import {KyberSwapFarmingToken} from 'contracts/periphery/KyberSwapFarmingToken.sol';
import {KSElasticLMHelper} from 'contracts/KSElasticLMHelper.sol';
import {MockKPoolV3} from 'contracts/mock/MockKPoolV3.sol';
import {MockToken} from 'contracts/mock/MockToken.sol';
import {MockNftManagerV2} from 'contracts/mock/MockNftManagerV2.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IKSElasticLMV2 as IELM3} from 'contracts/interfaces/IKSElasticLMV2.sol';
import {IKSElasticLMHelper} from 'contracts/interfaces/IKSElasticLMHelper.sol';
import {IKyberSwapFarmingToken} from 'contracts/interfaces/periphery/IKyberSwapFarmingToken.sol';
import {IBasePositionManager} from 'contracts/interfaces/IBasePositionManager.sol';

import {console} from 'forge-std/console.sol';

contract Integration is FoundryHelper {
  KSElasticLMV2 public farm;
  MockNftManagerV2 public nft;
  MockKPoolV3 public elasticPool;
  MockKPoolV3 public elasticPool2;
  MockToken public token;
  MockToken public token2;
  KSElasticLMHelper public helperSC;
  address public ePool;
  address public ePool2;
  address public mockFactory = address(bytes20('factory-Contract'));
  address public mockToken0 = address(bytes20('token0'));
  address public mockToken1 = address(bytes20('token1'));
  int24 internal constant MIN_TICK = -887_272;
  int24 internal constant MAX_TICK = 887_272;
  address WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

  uint32 private st = 1893430800; // Jan 1 2030
  uint32 private et = st + 30 days; // next 30 days

  uint256 public nft0;
  uint256 public nft00;
  uint256 public nft1;
  uint256 public nft11;
  uint256 public nft2;
  uint256 public nft3;
  uint256 public nft4;
  uint256 public nft5;
  uint256 public nft6;
  uint256 public nft7;

  function setUp() public virtual {
    _setupAccount();
    vm.startPrank(deployer);
    token = new MockToken('Reward Token', 'RW', 1000 ether);
    token2 = new MockToken('Reward Token 2', 'RW 2', 1000 ether);
    vm.label(address(token), 'Token 1');
    vm.label(address(token2), 'Token 2');
    elasticPool = new MockKPoolV3(token, token2);
    elasticPool2 = new MockKPoolV3(token, token2);

    ePool = address(elasticPool);
    ePool2 = address(elasticPool2);
    nft = new MockNftManagerV2(mockFactory, mockToken0, mockToken1, WETH);
    helperSC = new KSElasticLMHelper();
    farm = new KSElasticLMV2(nft, helperSC);
    farm.updateOperator(deployer, true);
    farm.updateTokenCode(type(KyberSwapFarmingToken).creationCode);
    // farm.updateHelper(helperSC);

    deal(address(deployer), 21_000 ether);
    deal(address(token), address(deployer), 11_000 ether);
    deal(address(token2), address(deployer), 12_000 ether);

    uint128 LIQ1 = 30 ether;
    uint128 LIQ2 = 40 ether;
    uint80 POOL_ID = 1997;
    uint80 POOL_ID_2 = 1998;
    // setup pool
    nft0 = nft.mint(user1, ePool, LIQ1, MIN_TICK, MAX_TICK);
    nft00 = nft.mint(user1, ePool, LIQ1, -9, -5);
    nft1 = nft.mint(user1, ePool, (LIQ1 * 2) / 3, -9, -1);
    nft11 = nft.mint(user1, ePool, LIQ2, -10, 10);
    nft2 = nft.mint(user2, ePool, LIQ2, MIN_TICK, MAX_TICK);
    nft3 = nft.mint(user2, ePool, LIQ2, MIN_TICK, MAX_TICK);
    nft4 = nft.mint(user1, ePool2, LIQ1, MIN_TICK, MAX_TICK);
    nft5 = nft.mint(user1, ePool2, LIQ1, MIN_TICK, MAX_TICK);
    nft6 = nft.mint(user2, ePool2, LIQ2, MIN_TICK, MAX_TICK);
    nft7 = nft.mint(user2, ePool2, LIQ2, MIN_TICK, MAX_TICK);
    nft.setAddressToPoolId(ePool, POOL_ID);
    nft.setAddressToPoolId(ePool2, POOL_ID_2);
    vm.stopPrank();
  }

  function test_In_01() public {
    vm.startPrank(deployer);

    IELM3.RangeInput[] memory r = new IELM3.RangeInput[](3);
    r[0] = IELM3.RangeInput({tickLower: -5, tickUpper: 5, weight: 1});
    r[1] = IELM3.RangeInput({tickLower: -8, tickUpper: -3, weight: 2});
    r[2] = IELM3.RangeInput({tickLower: 2, tickUpper: 9, weight: 4});

    IELM3.RewardInput[] memory rw = new IELM3.RewardInput[](2);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 140 ether});
    rw[1] = IELM3.RewardInput({rewardToken: ETH_ADDRESS, rewardAmount: 310 ether});

    IELM3.PhaseInput memory p = IELM3.PhaseInput({startTime: st, endTime: et, rewards: rw});
    token.approve(address(farm), MAX_UINT256);

    uint256 fId = farm.addFarm(ePool, r, p, true);
    uint256[] memory rwAmount = new uint256[](2);
    rwAmount[0] = 140 ether;
    rwAmount[1] = 310 ether;
    token.transfer(address(farm), 140 ether);
    payable(address(farm)).transfer(310 ether);
    vm.warp(st + 1 days);

    // deposit then claim
    changePrank(user1);
    nft.setApprovalForAll(address(farm), true);

    uint256[] memory nfts = new uint256[](1);
    nfts[0] = nft0;
    farm.deposit(fId, 0, nfts, user1);
    nfts[0] = nft1;
    farm.deposit(fId, 1, nfts, user1);

    vm.warp(st + 5 days);
    uint256 balanceBefore1 = token.balanceOf(user1);
    uint256 balanceBefore2 = address(user1).balance;
    uint256[] memory listNFT = new uint256[](2);
    listNFT[0] = nft0;
    listNFT[1] = nft1;
    farm.claimReward(fId, listNFT);

    uint256 balanceAfter1 = token.balanceOf(user1);
    uint256 balanceAfter2 = address(user1).balance;
    assertGe(balanceAfter1, balanceBefore1);
    assertGe(balanceAfter2, balanceBefore2);

    vm.warp(st + 7 days);
    farm.withdraw(fId, listNFT);
    nfts[0] = nft0;
    farm.deposit(fId, 0, nfts, user1);

    changePrank(user2);
    nft.setApprovalForAll(address(farm), true);
    nfts[0] = nft2;
    farm.deposit(fId, 0, nfts, user2);

    vm.warp(et);
    listNFT = new uint256[](1);
    listNFT[0] = nft2;
    farm.withdraw(fId, listNFT);
    changePrank(user1);
    listNFT[0] = nft0;
    farm.withdraw(fId, listNFT);
  }

  function test_In_02() public {
    vm.startPrank(deployer);

    IELM3.RangeInput[] memory r = new IELM3.RangeInput[](3);
    r[0] = IELM3.RangeInput({tickLower: -5, tickUpper: 5, weight: 1});
    r[1] = IELM3.RangeInput({tickLower: -8, tickUpper: -3, weight: 2});
    r[2] = IELM3.RangeInput({tickLower: 2, tickUpper: 9, weight: 4});

    IELM3.RewardInput[] memory rw = new IELM3.RewardInput[](2);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 140 ether});
    rw[1] = IELM3.RewardInput({rewardToken: ETH_ADDRESS, rewardAmount: 310 ether});

    IELM3.PhaseInput memory p = IELM3.PhaseInput({startTime: st, endTime: et, rewards: rw});
    token.approve(address(farm), MAX_UINT256);

    vm.warp(st - 10 days);

    uint256 fId = farm.addFarm(ePool, r, p, true);
    token.transfer(address(farm), 140 ether);
    payable(address(farm)).transfer(310 ether);

    vm.warp(st - 1 days);
    changePrank(user1);
    nft.setApprovalForAll(address(farm), true);
    uint256[] memory nfts = new uint256[](1);
    nfts[0] = nft0;
    farm.deposit(fId, 0, nfts, user1);
    vm.warp(st + 10 days);
    uint256[] memory listNFT = new uint256[](1);
    listNFT[0] = nft0;
    farm.claimReward(fId, listNFT);
    vm.warp(st + 15 days);
    farm.withdraw(fId, listNFT);
    farm.deposit(fId, 0, nfts, user1);
    vm.warp(et);
    farm.withdraw(fId, listNFT);
  }

  // add + remove range
  function test_In_03() public {
    vm.startPrank(deployer);

    IELM3.RangeInput[] memory r = new IELM3.RangeInput[](1);
    r[0] = IELM3.RangeInput({tickLower: -5, tickUpper: -3, weight: 1});

    IELM3.RewardInput[] memory rw = new IELM3.RewardInput[](1);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 140 ether});

    IELM3.PhaseInput memory p = IELM3.PhaseInput({startTime: st, endTime: et, rewards: rw});
    token.approve(address(farm), MAX_UINT256);

    uint256 fId = farm.addFarm(ePool, r, p, true);
    uint256[] memory rwAmount = new uint256[](1);
    rwAmount[0] = 140 ether;
    token.transfer(address(farm), 140 ether);
    vm.warp(st);
    changePrank(user1);
    nft.setApprovalForAll(address(farm), true);
    uint256[] memory nfts = new uint256[](1);
    nfts[0] = nft1;
    farm.deposit(fId, 0, nfts, user1);

    // add range
    changePrank(deployer);
    IELM3.RangeInput memory newRange = IELM3.RangeInput({tickLower: -8, tickUpper: -3, weight: 2});
    farm.addRange(fId, newRange);
    farm.removeRange(fId, 0);

    vm.warp(st + 2 days);
    changePrank(user1);
    uint256[] memory listNFT = new uint256[](1);
    listNFT[0] = nft1;
    farm.withdraw(fId, listNFT);
    farm.deposit(fId, 1, nfts, user1);
    vm.warp(st + 3 days);

    farm.claimReward(fId, listNFT);
    vm.warp(et);
    farm.withdraw(fId, listNFT);
  }

  // force close
  function test_In_04() public {
    vm.startPrank(deployer);

    IELM3.RangeInput[] memory r = new IELM3.RangeInput[](1);
    r[0] = IELM3.RangeInput({tickLower: -5, tickUpper: -3, weight: 1});

    IELM3.RewardInput[] memory rw = new IELM3.RewardInput[](1);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 140 ether});

    IELM3.PhaseInput memory p = IELM3.PhaseInput({startTime: st, endTime: et, rewards: rw});
    token.approve(address(farm), MAX_UINT256);

    uint256 fId = farm.addFarm(ePool, r, p, true);
    token.transfer(address(farm), 140 ether);

    vm.warp(st);
    changePrank(user1);
    nft.setApprovalForAll(address(farm), true);
    uint256[] memory nfts = new uint256[](1);
    nfts[0] = nft1;
    farm.deposit(fId, 0, nfts, user1);

    vm.warp(st + 2 days);
    uint256[] memory listNFT = new uint256[](1);
    listNFT[0] = nft1;
    farm.withdraw(fId, listNFT);
    farm.deposit(fId, 0, nfts, user1);

    // force close phase after 3 day
    vm.warp(st + 3 days);

    changePrank(deployer);
    farm.forceClosePhase(fId);

    changePrank(user2);
    nft.setApprovalForAll(address(farm), true);
    vm.expectRevert(abi.encodeWithSignature('PhaseSettled()'));
    nfts[0] = nft2;
    farm.deposit(fId, 0, nfts, user2);

    changePrank(user1);
    farm.withdraw(fId, listNFT);
  }

  // send over reward and claim back
  function test_In_05() public {
    vm.startPrank(deployer);

    IELM3.RangeInput[] memory r = new IELM3.RangeInput[](3);
    r[0] = IELM3.RangeInput({tickLower: -5, tickUpper: 5, weight: 1});
    r[1] = IELM3.RangeInput({tickLower: -8, tickUpper: -3, weight: 2});
    r[2] = IELM3.RangeInput({tickLower: 2, tickUpper: 9, weight: 4});

    IELM3.RewardInput[] memory rw = new IELM3.RewardInput[](2);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 140 ether});
    rw[1] = IELM3.RewardInput({rewardToken: ETH_ADDRESS, rewardAmount: 310 ether});

    IELM3.PhaseInput memory p = IELM3.PhaseInput({startTime: st, endTime: et, rewards: rw});
    token.approve(address(farm), MAX_UINT256);

    uint256 fId = farm.addFarm(ePool, r, p, true);
    token.transfer(address(farm), 200 ether);
    payable(address(farm)).transfer(400 ether);

    vm.warp(st - 1 days);

    // deposit
    changePrank(user1);
    nft.setApprovalForAll(address(farm), true);
    uint256[] memory nfts = new uint256[](1);
    nfts[0] = nft0;
    farm.deposit(fId, 0, nfts, user1);
    nfts[0] = nft1;
    farm.deposit(fId, 1, nfts, user1);
    changePrank(user2);
    nft.setApprovalForAll(address(farm), true);
    nfts[0] = nft2;
    farm.deposit(fId, 0, nfts, user2);

    vm.warp(st + 5 days);

    changePrank(user1);
    uint256[] memory listNFT = new uint256[](1);
    listNFT[0] = nft0;
    farm.claimReward(fId, listNFT);
    listNFT[0] = nft1;
    farm.claimReward(fId, listNFT);
    vm.warp(et + 1 days);

    changePrank(user2);
    listNFT[0] = nft2;
    farm.withdraw(fId, listNFT);
    changePrank(user1);
    listNFT = new uint256[](2);
    listNFT[0] = nft0;
    listNFT[1] = nft1;
    farm.withdraw(fId, listNFT);

    uint256 balance1LastF = token.balanceOf(address(farm));
    uint256 balance2LastF = address(farm).balance;
    assertGe(balance1LastF, 60 ether);
    assertGe(balance2LastF, 90 ether);
    changePrank(deployer);
    address[] memory tkAddress = new address[](2);
    tkAddress[0] = address(token);
    tkAddress[1] = ETH_ADDRESS;
    uint256[] memory amountWithdraw = new uint256[](2);
    amountWithdraw[0] = 60 ether;
    amountWithdraw[1] = 90 ether;
    farm.withdrawUnusedRewards(tkAddress, amountWithdraw);
    assertLe(token.balanceOf(address(farm)), 10 wei);
    assertLe(address(farm).balance, 10 wei);
  }

  // front-run unused reward
  function test_In_06() public {
    vm.startPrank(deployer);

    IELM3.RangeInput[] memory r = new IELM3.RangeInput[](1);
    r[0] = IELM3.RangeInput({tickLower: -5, tickUpper: -3, weight: 1});

    IELM3.RewardInput[] memory rw = new IELM3.RewardInput[](1);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 140 ether});

    IELM3.PhaseInput memory p = IELM3.PhaseInput({startTime: st, endTime: et, rewards: rw});
    token.approve(address(farm), MAX_UINT256);

    uint256 fId = farm.addFarm(ePool, r, p, true);
    token.transfer(address(farm), 300 ether);
    vm.warp(st);
    changePrank(user1);
    nft.setApprovalForAll(address(farm), true);
    uint256[] memory listNFT = new uint256[](1);
    listNFT[0] = nft1;
    farm.deposit(fId, 0, listNFT, user1);
    vm.warp(et);
    farm.withdraw(fId, listNFT);
    uint256 balance1LastF = token.balanceOf(address(farm));
    assertGe(balance1LastF, 160 ether);

    changePrank(deployer);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 100 ether});
    r[0] = IELM3.RangeInput({tickLower: -4, tickUpper: -2, weight: 5});
    uint32 st2 = 2529045460; // Aug 7
    uint32 et2 = st2 + 30 days; // st2 + 30 days
    p = IELM3.PhaseInput({startTime: st2, endTime: et2, rewards: rw});
    uint256 fId2 = farm.addFarm(ePool, r, p, true);

    changePrank(user1);
    farm.deposit(fId2, 0, listNFT, user1);
    vm.warp(et2);

    farm.withdraw(fId2, listNFT);
    uint256 balance2LastF = token.balanceOf(address(farm));
    assertGe(balance2LastF, 60 ether);
    changePrank(deployer);
    address[] memory tkAddress = new address[](1);
    tkAddress[0] = address(token);
    uint256[] memory amountWithdraw = new uint256[](1);
    amountWithdraw[0] = token.balanceOf(address(farm));
    farm.withdrawUnusedRewards(tkAddress, amountWithdraw);
    assertEq(token.balanceOf(address(farm)), 0);
  }

  // increase time of farm
  function test_In_07() public {
    vm.startPrank(deployer);

    IELM3.RangeInput[] memory r = new IELM3.RangeInput[](1);
    r[0] = IELM3.RangeInput({tickLower: -5, tickUpper: -3, weight: 1});

    IELM3.RewardInput[] memory rw = new IELM3.RewardInput[](1);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 300 ether});

    uint256[] memory rwAmt = new uint256[](1);
    rwAmt[0] = 300 ether;

    IELM3.PhaseInput memory p = IELM3.PhaseInput({startTime: st, endTime: et, rewards: rw});
    token.approve(address(farm), MAX_UINT256);

    uint256 fId = farm.addFarm(ePool, r, p, true);
    token.transfer(address(farm), 300 ether);

    vm.warp(st);
    changePrank(user1);
    nft.setApprovalForAll(address(farm), true);
    uint256[] memory nfts = new uint256[](1);
    nfts[0] = nft1;
    farm.deposit(fId, 0, nfts, user1);

    //junmp 10 days
    uint32 curr = st + 10 days;
    vm.warp(curr);

    changePrank(deployer);

    // increase end time + 10 days
    uint32 updateTime = et + 11 days;

    p.startTime = curr + 1 days;
    p.endTime = updateTime;
    farm.addPhase(fId, p);
    token.transfer(address(farm), 100 ether);

    // jump to end time
    vm.warp(updateTime);
    changePrank(user1);
    uint256[] memory listNFT = new uint256[](1);
    listNFT[0] = nft1;
    farm.withdraw(fId, listNFT);
    assertEq(token.balanceOf(address(farm)), 0);
  }

  // increase time of farm,
  // then add new phase
  // other deposit for -> withdraw both
  function test_In_08() public {
    vm.startPrank(deployer);

    IELM3.RangeInput[] memory r = new IELM3.RangeInput[](1);
    r[0] = IELM3.RangeInput({tickLower: -5, tickUpper: -3, weight: 1});

    IELM3.RewardInput[] memory rw = new IELM3.RewardInput[](1);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 100 ether});

    uint256[] memory rwAmt = new uint256[](1);
    rwAmt[0] = 300 ether;

    IELM3.PhaseInput memory p = IELM3.PhaseInput({startTime: st, endTime: et, rewards: rw});
    token.approve(address(farm), MAX_UINT256);

    uint256 fId = farm.addFarm(ePool, r, p, true);
    token.transfer(address(farm), 100 ether);

    vm.warp(st);
    changePrank(user1);
    nft.setApprovalForAll(address(farm), true);
    uint256[] memory nfts = new uint256[](1);
    nfts[0] = nft1;
    farm.deposit(fId, 0, nfts, user1);

    //junmp 10 days
    uint32 curr = st + 10 days;
    vm.warp(curr);

    // next phase data
    changePrank(deployer);
    p = IELM3.PhaseInput({startTime: curr + 1 days, endTime: curr + 31 days, rewards: rw});
    farm.addPhase(fId, p);
    token.transfer(address(farm), 100 ether);

    changePrank(user2);
    nft.setApprovalForAll(address(farm), true);

    // user 2 deposit for user 1
    vm.warp(curr + 2 days);

    nfts[0] = nft2;
    farm.deposit(fId, 0, nfts, user1);

    vm.warp(curr + 32 days);

    changePrank(user1);
    uint256[] memory listNFT = new uint256[](2);
    listNFT[0] = nft1;
    listNFT[1] = nft2;
    farm.withdraw(fId, listNFT);
  }

  // update liquidity while removed range
  function test_In_09() public {
    vm.startPrank(deployer);

    IELM3.RangeInput[] memory r = new IELM3.RangeInput[](3);
    r[0] = IELM3.RangeInput({tickLower: -5, tickUpper: 5, weight: 1});
    r[1] = IELM3.RangeInput({tickLower: -8, tickUpper: -3, weight: 2});
    r[2] = IELM3.RangeInput({tickLower: 2, tickUpper: 9, weight: 4});

    IELM3.RewardInput[] memory rw = new IELM3.RewardInput[](1);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 140 ether});

    IELM3.PhaseInput memory p = IELM3.PhaseInput({startTime: st, endTime: et, rewards: rw});
    token.approve(address(farm), MAX_UINT256);

    uint256 fId = farm.addFarm(ePool, r, p, true);
    token.transfer(address(farm), 140 ether);
    vm.warp(st);
    changePrank(user1);
    nft.setApprovalForAll(address(farm), true);
    uint256[] memory nfts = new uint256[](1);
    nfts[0] = nft1;
    farm.deposit(fId, 1, nfts, user1);

    changePrank(deployer);
    farm.removeRange(fId, 1);

    //junmp 10 days
    uint32 curr = st + 10 days;
    vm.warp(curr);
    // add liquidity from NFT Manager
    nft.addLiquidity(nft1, 19 ether);
    // call to farm to update liquidity
    vm.expectRevert(abi.encodeWithSignature('RangeNotFound()'));
    farm.addLiquidity(fId, 1, nfts);
  }

  // update liquidity as usually
  function test_In_10() public {
    vm.startPrank(deployer);

    IELM3.RangeInput[] memory r = new IELM3.RangeInput[](3);
    r[0] = IELM3.RangeInput({tickLower: -5, tickUpper: 5, weight: 1});
    r[1] = IELM3.RangeInput({tickLower: -8, tickUpper: -3, weight: 2});
    r[2] = IELM3.RangeInput({tickLower: 2, tickUpper: 9, weight: 4});

    IELM3.RewardInput[] memory rw = new IELM3.RewardInput[](1);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 140 ether});

    IELM3.PhaseInput memory p = IELM3.PhaseInput({startTime: st, endTime: et, rewards: rw});
    token.approve(address(farm), MAX_UINT256);

    uint256 fId = farm.addFarm(ePool, r, p, true);
    token.transfer(address(farm), 140 ether);

    vm.warp(st - 1 days);
    changePrank(user1);
    nft.setApprovalForAll(address(farm), true);
    uint256[] memory nfts = new uint256[](1);
    nfts[0] = nft1;
    farm.deposit(fId, 1, nfts, user1);

    //junmp 10 days
    uint32 curr = st + 10 days;
    vm.warp(curr);
    // add liquidity from NFT Manager
    nft.addLiquidity(nft1, 19 ether);
    // call to farm to update liquidity
    farm.addLiquidity(fId, 1, nfts);
    vm.warp(et);
    uint256[] memory listNFT = new uint256[](1);
    listNFT[0] = nft1;
    farm.withdraw(fId, listNFT);
    assertLe(token.balanceOf(address(farm)), 1 gwei);
  }

  // check reward unclaim after end phase
  function test_In_11() public {
    vm.startPrank(deployer);

    IELM3.RangeInput[] memory r = new IELM3.RangeInput[](1);
    r[0] = IELM3.RangeInput({tickLower: -5, tickUpper: 5, weight: 1});

    IELM3.RewardInput[] memory rw = new IELM3.RewardInput[](1);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 140 ether});

    IELM3.PhaseInput memory p = IELM3.PhaseInput({startTime: st, endTime: et, rewards: rw});
    token.approve(address(farm), MAX_UINT256);

    uint256 fId = farm.addFarm(ePool, r, p, true);
    token.transfer(address(farm), 140 ether);

    vm.warp(st - 1 days);

    // deposit
    changePrank(user1);
    nft.setApprovalForAll(address(farm), true);
    uint256[] memory nfts = new uint256[](1);
    nfts[0] = nft0;
    farm.deposit(fId, 0, nfts, user1);

    vm.warp(et + 1 days);
    changePrank(deployer);
    // farm.forceClosePhase(fId);

    uint256 balanceF = token.balanceOf(address(farm));
    assertEq(balanceF, 140 ether);

    changePrank(user1);
    uint256[] memory listNFT = new uint256[](1);
    listNFT[0] = nft0;
    farm.withdraw(fId, listNFT);
    balanceF = token.balanceOf(address(farm));
    assertLe(balanceF, 10 wei);
  }

  // send reward for settle phase
  function test_In_12() public {
    vm.startPrank(deployer);

    IELM3.RangeInput[] memory r = new IELM3.RangeInput[](1);
    r[0] = IELM3.RangeInput({tickLower: -5, tickUpper: 5, weight: 1});

    IELM3.RewardInput[] memory rw = new IELM3.RewardInput[](1);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 140 ether});

    IELM3.PhaseInput memory p = IELM3.PhaseInput({startTime: st, endTime: et, rewards: rw});
    token.approve(address(farm), MAX_UINT256);

    uint256 fId = farm.addFarm(ePool, r, p, true);
    token.transfer(address(farm), 140 ether);

    vm.warp(st - 1 days);

    // deposit
    changePrank(user1);
    nft.setApprovalForAll(address(farm), true);
    uint256[] memory nfts = new uint256[](1);
    nfts[0] = nft0;
    farm.deposit(fId, 0, nfts, user1);

    vm.warp(et + 1);
    changePrank(deployer);
    // farm.forceClosePhase(fId);
    token.transfer(address(farm), 140 ether);

    assertEq(token.balanceOf(address(farm)), 280 ether);

    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 80 ether});
    p = IELM3.PhaseInput({startTime: et + 2 days, endTime: et + 30 days, rewards: rw});
    farm.addPhase(fId, p);

    changePrank(user1);
    uint256[] memory listNFT = new uint256[](1);
    listNFT[0] = nft0;
    farm.claimReward(fId, listNFT);

    assertGe(token.balanceOf(address(farm)), 140 ether - 10 wei);

    vm.warp(et + 30 days);
    farm.withdraw(fId, listNFT);
    assertGe(token.balanceOf(address(farm)), 60 ether); // 140 - 80
  }

  // reduce reward for farm
  function test_In_13() public {
    vm.startPrank(deployer);

    IELM3.RangeInput[] memory r = new IELM3.RangeInput[](1);
    r[0] = IELM3.RangeInput({tickLower: -5, tickUpper: 5, weight: 1});

    IELM3.RewardInput[] memory rw = new IELM3.RewardInput[](1);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 300 ether});

    IELM3.PhaseInput memory p = IELM3.PhaseInput({startTime: st, endTime: et, rewards: rw});
    token.approve(address(farm), MAX_UINT256);

    uint256 fId = farm.addFarm(ePool, r, p, true);
    token.transfer(address(farm), 300 ether);

    vm.warp(st - 1 days);

    // deposit
    changePrank(user1);
    nft.setApprovalForAll(address(farm), true);

    uint256 balanceUserBefore = token.balanceOf(address(user1));
    uint256[] memory nfts = new uint256[](1);
    nfts[0] = nft0;
    farm.deposit(fId, 0, nfts, user1);
    vm.warp(st + 10 days);
    changePrank(deployer);
    uint256[] memory rwAmt = new uint256[](1);
    rwAmt[0] = 140 ether;

    p.startTime = st + 11 days;
    p.rewards[0].rewardAmount = 140 ether;
    farm.addPhase(fId, p);

    vm.warp(st + 20 days);
    changePrank(user1);
    uint256[] memory listNFT = new uint256[](1);
    listNFT[0] = nft0;
    farm.withdraw(fId, listNFT);
    uint256 balanceUserAfter = token.balanceOf(address(user1));
    assertGe(balanceUserAfter - balanceUserBefore, 166315789473684210520); // 99999999999999999996 of first 10 days + 66315789473684210524 for next 9 days

    assertGe(token.balanceOf(address(farm)), 133684210526315789474); // 300E - 166315789473684210520
  }

  // increase reward
  function test_In_14() public {
    vm.startPrank(deployer);

    IELM3.RangeInput[] memory r = new IELM3.RangeInput[](1);
    r[0] = IELM3.RangeInput({tickLower: -5, tickUpper: 5, weight: 1});

    IELM3.RewardInput[] memory rw = new IELM3.RewardInput[](1);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 300 ether});

    IELM3.PhaseInput memory p = IELM3.PhaseInput({startTime: st, endTime: et, rewards: rw});
    token.approve(address(farm), MAX_UINT256);

    uint256 fId = farm.addFarm(ePool, r, p, true);
    token.transfer(address(farm), 300 ether);

    vm.warp(st - 1 days);

    // deposit
    changePrank(user1);
    nft.setApprovalForAll(address(farm), true);

    uint256 balanceUserBefore = token.balanceOf(address(user1));
    uint256[] memory nfts = new uint256[](1);
    nfts[0] = nft0;
    farm.deposit(fId, 0, nfts, user1);
    vm.warp(st + 10 days);
    changePrank(deployer);
    uint256[] memory rwAmt = new uint256[](1);
    rwAmt[0] = 600 ether;

    p.startTime = st + 10 days + 3600;
    p.rewards[0].rewardAmount = 600 ether;
    farm.addPhase(fId, p);

    vm.warp(st + 20 days);
    changePrank(user1);
    // not send reward more, will be reverted
    vm.expectRevert();
    uint256[] memory listNFT = new uint256[](1);
    listNFT[0] = nft0;
    farm.withdraw(fId, listNFT);
    changePrank(deployer);
    token.transfer(address(farm), 600 ether);
    changePrank(user1);
    farm.withdraw(fId, listNFT);
    uint256 balanceUserAfter = token.balanceOf(address(user1));
    assertGe(balanceUserAfter - balanceUserBefore, 350 ether - 10 wei); // 100E of first 10 days + 250E for next 10 days
    assertGe(token.balanceOf(address(farm)), 500 ether); // 500E
  }

  //deposit then withdraw before start
  function test_In_15() public {
    vm.startPrank(deployer);

    IELM3.RangeInput[] memory r = new IELM3.RangeInput[](1);
    r[0] = IELM3.RangeInput({tickLower: -5, tickUpper: 5, weight: 1});

    IELM3.RewardInput[] memory rw = new IELM3.RewardInput[](1);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 140 ether});

    IELM3.PhaseInput memory p = IELM3.PhaseInput({startTime: st, endTime: et, rewards: rw});
    token.approve(address(farm), MAX_UINT256);

    uint256 fId = farm.addFarm(ePool, r, p, true);
    token.transfer(address(farm), 140 ether);

    vm.warp(st - 1 days);

    // deposit
    changePrank(user1);
    nft.setApprovalForAll(address(farm), true);
    uint256[] memory nfts = new uint256[](1);
    nfts[0] = nft0;
    farm.deposit(fId, 0, nfts, user1);
    uint256[] memory listNFT = new uint256[](1);
    listNFT[0] = nft0;
    farm.withdraw(fId, listNFT);
  }

  // claim, withdraw, deposit, claim, withdraw
  function test_In_16() public {
    vm.startPrank(deployer);

    IELM3.RangeInput[] memory r = new IELM3.RangeInput[](3);
    r[0] = IELM3.RangeInput({tickLower: -5, tickUpper: 5, weight: 1});
    r[1] = IELM3.RangeInput({tickLower: -8, tickUpper: -5, weight: 2});
    r[2] = IELM3.RangeInput({tickLower: 2, tickUpper: 9, weight: 4});

    IELM3.RewardInput[] memory rw = new IELM3.RewardInput[](2);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 140 ether});
    rw[1] = IELM3.RewardInput({rewardToken: ETH_ADDRESS, rewardAmount: 310 ether});

    IELM3.PhaseInput memory p = IELM3.PhaseInput({startTime: st, endTime: et, rewards: rw});
    token.approve(address(farm), MAX_UINT256);

    uint256 fId = farm.addFarm(ePool, r, p, true);
    token.transfer(address(farm), 140 ether);
    payable(address(farm)).transfer(310 ether);

    vm.warp(st - 1 days);

    // deposit
    changePrank(user1);
    nft.setApprovalForAll(address(farm), true);
    uint256[] memory nfts = new uint256[](1);
    nfts[0] = nft0;
    farm.deposit(fId, 0, nfts, user1);
    nfts[0] = nft1;
    farm.deposit(fId, 1, nfts, user1);
    changePrank(user2);
    nft.setApprovalForAll(address(farm), true);
    nfts[0] = nft2;
    farm.deposit(fId, 0, nfts, user2);

    // start to claim + withdraw
    vm.warp(st + 10 days);
    uint256[] memory listNFT = new uint256[](1);
    listNFT[0] = nft2;
    farm.claimReward(fId, listNFT);
    farm.withdraw(fId, listNFT);
    farm.deposit(fId, 0, nfts, user2);
    changePrank(user1);
    listNFT = new uint256[](2);
    listNFT[0] = nft0;
    listNFT[1] = nft1;

    farm.claimReward(fId, listNFT);
    farm.withdraw(fId, listNFT);

    nfts[0] = nft0;
    farm.deposit(fId, 0, nfts, user1);
    nfts[0] = nft1;
    farm.deposit(fId, 1, nfts, user1);
    vm.warp(et);
    farm.withdraw(fId, listNFT);
    changePrank(user2);
    listNFT = new uint256[](1);
    listNFT[0] = nft2;
    farm.withdraw(fId, listNFT);
  }

  // using new farming token
  function test_In_17() public {
    vm.startPrank(deployer);

    IELM3.RangeInput[] memory r = new IELM3.RangeInput[](3);
    r[0] = IELM3.RangeInput({tickLower: -5, tickUpper: 5, weight: 1});
    r[1] = IELM3.RangeInput({tickLower: -8, tickUpper: -5, weight: 2});
    r[2] = IELM3.RangeInput({tickLower: 2, tickUpper: 9, weight: 4});

    IELM3.RewardInput[] memory rw = new IELM3.RewardInput[](2);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 140 ether});
    rw[1] = IELM3.RewardInput({rewardToken: ETH_ADDRESS, rewardAmount: 310 ether});

    IELM3.PhaseInput memory p = IELM3.PhaseInput({startTime: st, endTime: et, rewards: rw});
    token.approve(address(farm), MAX_UINT256);

    uint256 fId = farm.addFarm(ePool, r, p, true);
    token.transfer(address(farm), 140 ether);
    payable(address(farm)).transfer(310 ether);

    vm.warp(st - 1 days);

    // deposit
    changePrank(user1);
    nft.setApprovalForAll(address(farm), true);
    uint256[] memory listNFT = new uint256[](1);
    listNFT[0] = nft0;
    farm.deposit(fId, 0, listNFT, user1);
    listNFT[0] = nft1;
    farm.deposit(fId, 1, listNFT, user1);

    (, , , , address fToken, , ) = farm.getFarm(fId);
    assertEq(IKyberSwapFarmingToken(fToken).balanceOf(address(user1)), 70 ether); // 30 index 0 + 20*2 index 1
    vm.expectRevert(abi.encodeWithSignature('InvalidOperation()'));
    IKyberSwapFarmingToken(fToken).transfer(address(user2), 10 ether);

    assertEq(
      IKyberSwapFarmingToken(fToken).hasRole(
        0x523a704056dcd17bcf83bed8b68c59416dac1119be77755efe3bde0a64e46e0c,
        address(farm)
      ),
      true
    ); // operator to farm contract
    assertEq(
      IKyberSwapFarmingToken(fToken).hasRole(
        0x0000000000000000000000000000000000000000000000000000000000000000,
        address(deployer)
      ),
      true
    ); // admin to deployer

    // whitelist to receiver, then user can transfer their token to , i,e receiver will be user 2
    changePrank(deployer);
    IKyberSwapFarmingToken(fToken).addWhitelist(address(user2));
    changePrank(user1);
    IKyberSwapFarmingToken(fToken).transfer(address(user2), 10 ether);
    IKyberSwapFarmingToken(fToken).approve(address(deployer), MAX_UINT256);
    changePrank(deployer);
    IKyberSwapFarmingToken(fToken).transferFrom(address(user1), address(user2), 20 ether);

    assertEq(IKyberSwapFarmingToken(fToken).balanceOf(address(user2)), 30 ether);
  }

  //quoter check
  function test_In_18() public {
    vm.startPrank(deployer);

    IELM3.RangeInput[] memory r = new IELM3.RangeInput[](4);
    r[0] = IELM3.RangeInput({tickLower: -5, tickUpper: 5, weight: 1});
    r[1] = IELM3.RangeInput({tickLower: -8, tickUpper: -5, weight: 2});
    r[2] = IELM3.RangeInput({tickLower: 2, tickUpper: 9, weight: 4});
    r[3] = IELM3.RangeInput({tickLower: -4, tickUpper: -2, weight: 5});

    IELM3.RewardInput[] memory rw = new IELM3.RewardInput[](1);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 140 ether});

    IELM3.PhaseInput memory p = IELM3.PhaseInput({startTime: st, endTime: et, rewards: rw});
    token.approve(address(farm), MAX_UINT256);

    uint256 fId = farm.addFarm(ePool, r, p, true);
    token.transfer(address(farm), 140 ether);

    vm.warp(st - 1 days);

    nft.setMockFeeGrowthInsideLast(MAX_UINT256);
    uint256[] memory indexesValid = helperSC.getEligibleRanges(farm, fId, nft0);
    assertEq(indexesValid.length, 4);
    assertEq(indexesValid[0], 0);
    assertEq(indexesValid[1], 1);
    assertEq(indexesValid[2], 2);
    assertEq(indexesValid[3], 3);

    uint256[] memory indexesValid2 = helperSC.getEligibleRanges(farm, fId, nft1);
    assertEq(indexesValid2.length, 2);
    assertEq(indexesValid2[0], 1);
    assertEq(indexesValid2[1], 3);
  }

  // reward unclaim
  function test_In_19() public {
    vm.startPrank(deployer);

    IELM3.RangeInput[] memory r = new IELM3.RangeInput[](1);
    r[0] = IELM3.RangeInput({tickLower: -5, tickUpper: -2, weight: 1});

    IELM3.RewardInput[] memory rw = new IELM3.RewardInput[](1);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 300 ether});

    IELM3.PhaseInput memory p = IELM3.PhaseInput({startTime: st, endTime: et, rewards: rw});
    token.approve(address(farm), MAX_UINT256);

    uint256 fId = farm.addFarm(ePool, r, p, true);
    token.transfer(address(farm), 140 ether);

    vm.warp(st - 1 days);

    changePrank(user1);
    nft.setApprovalForAll(address(farm), true);
    uint256[] memory listNFT = new uint256[](2);
    listNFT[0] = nft0;
    listNFT[1] = nft1;
    farm.deposit(fId, 0, listNFT, user1);
    vm.warp(st + 10 days);
    uint256[] memory currentUnclaimedRewards = helperSC.getCurrentUnclaimedReward(farm, nft0);
    assertEq(currentUnclaimedRewards.length, 1);
    assertEq(currentUnclaimedRewards[0], 60000000000000000000);
    uint256[] memory currentUnclaimedRewards1 = helperSC.getCurrentUnclaimedReward(farm, nft1);
    assertEq(currentUnclaimedRewards1[0], 40000000000000000000);

    changePrank(deployer);
    uint256[] memory rwAmt = new uint256[](1);
    rwAmt[0] = 500 ether;

    p.startTime = st + 11 days;
    p.rewards[0].rewardAmount = 500 ether;
    farm.addPhase(fId, p);

    vm.warp(st + 20 days);
    currentUnclaimedRewards = helperSC.getCurrentUnclaimedReward(farm, nft0);
    assertEq(currentUnclaimedRewards[0], 202105263157894736842);
    currentUnclaimedRewards1 = helperSC.getCurrentUnclaimedReward(farm, nft1);
    assertEq(currentUnclaimedRewards1[0], 134736842105263157894);
    vm.warp(et);
    rw = new IELM3.RewardInput[](1);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 60 ether});
    p = IELM3.PhaseInput({startTime: et + 30 days, endTime: et + 60 days, rewards: rw});
    farm.addPhase(fId, p);
    token.transfer(address(farm), 60 ether);

    vm.warp(et + 40 days); // 10 days after phase 2
    currentUnclaimedRewards = helperSC.getCurrentUnclaimedReward(farm, nft0);
    assertGe(currentUnclaimedRewards[0], 312 ether - 5 wei); // 180 + 120 + 12
    currentUnclaimedRewards1 = helperSC.getCurrentUnclaimedReward(farm, nft1);
    assertGe(currentUnclaimedRewards1[0], 208 ether - 5 wei); // 120 + 80 + 8
  }

  function test_In_20_deposit_list_nfts() public {
    vm.startPrank(deployer);

    IELM3.RangeInput[] memory r = new IELM3.RangeInput[](1);
    r[0] = IELM3.RangeInput({tickLower: -5, tickUpper: -2, weight: 2});

    IELM3.RewardInput[] memory rw = new IELM3.RewardInput[](2);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 300 ether});
    rw[1] = IELM3.RewardInput({
      rewardToken: address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
      rewardAmount: 300 ether
    });

    IELM3.PhaseInput memory p = IELM3.PhaseInput({startTime: st, endTime: et, rewards: rw});
    token.approve(address(farm), MAX_UINT256);

    uint256 fId = farm.addFarm(ePool, r, p, true);
    token.transfer(address(farm), 300 ether);
    vm.deal(address(farm), 300 ether);

    changePrank(user1);
    nft.setApprovalForAll(address(farm), true);
    uint256[] memory listNFT = new uint256[](3);
    listNFT[0] = nft0;
    listNFT[1] = nft1;
    listNFT[2] = nft11;

    farm.deposit(fId, 0, listNFT, user1);

    (
      ,
      ,
      ,
      uint256 liquidity,
      address farmingToken,
      uint256[] memory sumRewardPerLiquidity,

    ) = farm.getFarm(fId);

    assertEq(liquidity, 180 ether);
    assertEq(sumRewardPerLiquidity[0], 0);

    uint256 stakedLiq;
    uint256[] memory lastSumRewardPerLiquidity;
    uint256[] memory rewardUnclaimed;

    (, , , stakedLiq, lastSumRewardPerLiquidity, rewardUnclaimed) = farm.getStake(nft0);

    assertEq(stakedLiq, 60 ether);
    assertEq(lastSumRewardPerLiquidity[0], 0);
    assertEq(rewardUnclaimed[0], 0);

    (, , , stakedLiq, lastSumRewardPerLiquidity, rewardUnclaimed) = farm.getStake(nft1);

    assertEq(stakedLiq, 40 ether);
    assertEq(lastSumRewardPerLiquidity[0], 0);
    assertEq(rewardUnclaimed[0], 0);

    (, , , stakedLiq, lastSumRewardPerLiquidity, rewardUnclaimed) = farm.getStake(nft11);

    assertEq(stakedLiq, 80 ether);
    assertEq(lastSumRewardPerLiquidity[0], 0);
    assertEq(rewardUnclaimed[0], 0);

    uint256 farmingTokenBalance = IERC20(farmingToken).balanceOf(user1);

    assertEq(farmingTokenBalance, 180 ether);
  }

  function test_In_21_deposit_list_nfts_with_sameId() public {
    vm.startPrank(deployer);

    IELM3.RangeInput[] memory r = new IELM3.RangeInput[](1);
    r[0] = IELM3.RangeInput({tickLower: -5, tickUpper: -2, weight: 2});

    IELM3.RewardInput[] memory rw = new IELM3.RewardInput[](2);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 300 ether});
    rw[1] = IELM3.RewardInput({
      rewardToken: address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
      rewardAmount: 300 ether
    });

    IELM3.PhaseInput memory p = IELM3.PhaseInput({startTime: st, endTime: et, rewards: rw});
    token.approve(address(farm), MAX_UINT256);

    uint256 fId = farm.addFarm(ePool, r, p, true);
    token.transfer(address(farm), 300 ether);
    vm.deal(address(farm), 300 ether);

    changePrank(user1);
    nft.setApprovalForAll(address(farm), true);
    uint256[] memory listNFT = new uint256[](3);
    listNFT[0] = nft0;
    listNFT[1] = nft0;
    listNFT[2] = nft1;

    vm.expectRevert('ERC721: transfer of token that is not own');
    farm.deposit(fId, 0, listNFT, user1);
  }

  function test_In_22_claimReward_list_nfts() public {
    vm.startPrank(deployer);

    IELM3.RangeInput[] memory r = new IELM3.RangeInput[](1);
    r[0] = IELM3.RangeInput({tickLower: -5, tickUpper: -2, weight: 2});

    IELM3.RewardInput[] memory rw = new IELM3.RewardInput[](2);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 300 ether});
    rw[1] = IELM3.RewardInput({
      rewardToken: address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
      rewardAmount: 300 ether
    });

    IELM3.PhaseInput memory p = IELM3.PhaseInput({startTime: st, endTime: et, rewards: rw});
    token.approve(address(farm), MAX_UINT256);

    uint256 fId = farm.addFarm(ePool, r, p, true);
    token.transfer(address(farm), 300 ether);
    vm.deal(address(farm), 300 ether);

    changePrank(user1);
    nft.setApprovalForAll(address(farm), true);

    uint256[] memory listNFT = new uint256[](3);
    listNFT[0] = nft0;
    listNFT[1] = nft1;
    listNFT[2] = nft11;

    farm.deposit(fId, 0, listNFT, user1);

    vm.warp(st + 1 days);

    uint256 balanceTokenBefore = token.balanceOf(user1);
    uint256 balanceETHBefore = payable(user1).balance;

    farm.claimReward(fId, listNFT);

    (, , , uint256 liquidity, , uint256[] memory sumRewardPerLiquidity, ) = farm.getFarm(fId);

    assertEq(liquidity, 180 ether);
    assertEq(sumRewardPerLiquidity[0], 4401564584125796532974663907);
    assertApproxEqAbs(token.balanceOf(address(farm)), 290 ether, 10);
    assertApproxEqAbs(payable(address(farm)).balance, 290 ether, 10);

    uint256 stakedLiq;
    uint256[] memory lastSumRewardPerLiquidity;
    uint256[] memory rewardUnclaimed;

    (, , , stakedLiq, lastSumRewardPerLiquidity, rewardUnclaimed) = farm.getStake(nft0);

    assertEq(stakedLiq, 60 ether);
    assertEq(lastSumRewardPerLiquidity[0], 4401564584125796532974663907);
    assertEq(rewardUnclaimed[0], 0);

    (, , , stakedLiq, lastSumRewardPerLiquidity, rewardUnclaimed) = farm.getStake(nft1);

    assertEq(stakedLiq, 40 ether);
    assertEq(lastSumRewardPerLiquidity[0], 4401564584125796532974663907);
    assertEq(rewardUnclaimed[0], 0);

    (, , , stakedLiq, lastSumRewardPerLiquidity, rewardUnclaimed) = farm.getStake(nft11);

    assertEq(stakedLiq, 80 ether);
    assertEq(lastSumRewardPerLiquidity[0], 4401564584125796532974663907);
    assertEq(rewardUnclaimed[0], 0);

    uint256 balanceTokenAfter = token.balanceOf(user1);
    uint256 balanceETHAfter = payable(user1).balance;

    assertApproxEqAbs(balanceTokenAfter - balanceTokenBefore, 10 ether, 10);
    assertApproxEqAbs(balanceETHAfter - balanceETHBefore, 10 ether, 10);
  }

  function test_In_23_claimReward_list_nfts_with_sameId() public {
    vm.startPrank(deployer);

    IELM3.RangeInput[] memory r = new IELM3.RangeInput[](1);
    r[0] = IELM3.RangeInput({tickLower: -5, tickUpper: -2, weight: 2});

    IELM3.RewardInput[] memory rw = new IELM3.RewardInput[](2);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 300 ether});
    rw[1] = IELM3.RewardInput({
      rewardToken: address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
      rewardAmount: 300 ether
    });

    IELM3.PhaseInput memory p = IELM3.PhaseInput({startTime: st, endTime: et, rewards: rw});
    token.approve(address(farm), MAX_UINT256);

    uint256 fId = farm.addFarm(ePool, r, p, true);
    token.transfer(address(farm), 300 ether);
    vm.deal(address(farm), 300 ether);

    changePrank(user1);
    nft.setApprovalForAll(address(farm), true);
    uint256[] memory listNFT = new uint256[](3);
    listNFT[0] = nft0;
    listNFT[1] = nft1;
    listNFT[2] = nft11;

    farm.deposit(fId, 0, listNFT, user1);

    vm.warp(st + 1 days);

    listNFT = new uint256[](3);
    listNFT[0] = nft0;
    listNFT[1] = nft1;
    listNFT[2] = nft1;

    uint256 balanceTokenBefore = token.balanceOf(user1);
    uint256 balanceETHBefore = payable(user1).balance;

    farm.claimReward(fId, listNFT);

    (, , , uint256 liquidity, , uint256[] memory sumRewardPerLiquidity, ) = farm.getFarm(fId);

    assertEq(liquidity, 180 ether);
    assertEq(sumRewardPerLiquidity[0], 4401564584125796532974663907);

    uint256 stakedLiq;
    uint256[] memory lastSumRewardPerLiquidity;
    uint256[] memory rewardUnclaimed;

    (, , , stakedLiq, lastSumRewardPerLiquidity, rewardUnclaimed) = farm.getStake(nft0);

    assertEq(stakedLiq, 60 ether);
    assertEq(lastSumRewardPerLiquidity[0], 4401564584125796532974663907);
    assertEq(rewardUnclaimed[0], 0);

    (, , , stakedLiq, lastSumRewardPerLiquidity, rewardUnclaimed) = farm.getStake(nft1);

    assertEq(stakedLiq, 40 ether);
    assertEq(lastSumRewardPerLiquidity[0], 4401564584125796532974663907);
    assertEq(rewardUnclaimed[0], 0);

    (, , , stakedLiq, lastSumRewardPerLiquidity, rewardUnclaimed) = farm.getStake(nft11);

    assertEq(stakedLiq, 80 ether);
    assertEq(lastSumRewardPerLiquidity[0], 0);
    assertEq(rewardUnclaimed[0], 0);

    uint256 balanceTokenAfter = token.balanceOf(user1);
    uint256 balanceETHAfter = payable(user1).balance;

    assertApproxEqAbs(balanceTokenAfter - balanceTokenBefore, 5555555555555555555, 10);
    assertApproxEqAbs(balanceETHAfter - balanceETHBefore, 5555555555555555555, 10);
  }

  function test_In_24_withdraw_list_nfts() public {
    vm.startPrank(deployer);

    IELM3.RangeInput[] memory r = new IELM3.RangeInput[](1);
    r[0] = IELM3.RangeInput({tickLower: -5, tickUpper: -2, weight: 2});

    IELM3.RewardInput[] memory rw = new IELM3.RewardInput[](2);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 300 ether});
    rw[1] = IELM3.RewardInput({
      rewardToken: address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
      rewardAmount: 300 ether
    });

    IELM3.PhaseInput memory p = IELM3.PhaseInput({startTime: st, endTime: et, rewards: rw});
    token.approve(address(farm), MAX_UINT256);

    uint256 fId = farm.addFarm(ePool, r, p, true);
    token.transfer(address(farm), 300 ether);
    vm.deal(address(farm), 300 ether);

    changePrank(user1);
    nft.setApprovalForAll(address(farm), true);
    uint256[] memory listNFT = new uint256[](3);
    listNFT[0] = nft0;
    listNFT[1] = nft1;
    listNFT[2] = nft11;

    farm.deposit(fId, 0, listNFT, user1);

    vm.warp(st + 1 days);

    uint256 balanceTokenBefore = token.balanceOf(user1);
    uint256 balanceETHBefore = payable(user1).balance;

    farm.withdraw(fId, listNFT);

    (, , , uint256 liquidity, , uint256[] memory sumRewardPerLiquidity, ) = farm.getFarm(fId);

    assertEq(liquidity, 0);
    assertEq(sumRewardPerLiquidity[0], 4401564584125796532974663907);
    assertApproxEqAbs(token.balanceOf(address(farm)), 290 ether, 10);
    assertApproxEqAbs(payable(address(farm)).balance, 290 ether, 10);

    uint256 stakedLiq;
    uint256[] memory lastSumRewardPerLiquidity;
    uint256[] memory rewardUnclaimed;

    (, , , stakedLiq, lastSumRewardPerLiquidity, rewardUnclaimed) = farm.getStake(nft0);

    assertEq(stakedLiq, 0);
    assertEq(lastSumRewardPerLiquidity.length, 0);
    assertEq(rewardUnclaimed.length, 0);
    assertEq(nft.ownerOf(nft0), user1);

    (, , , stakedLiq, lastSumRewardPerLiquidity, rewardUnclaimed) = farm.getStake(nft1);

    assertEq(stakedLiq, 0);
    assertEq(lastSumRewardPerLiquidity.length, 0);
    assertEq(rewardUnclaimed.length, 0);
    assertEq(nft.ownerOf(nft1), user1);

    (, , , stakedLiq, lastSumRewardPerLiquidity, rewardUnclaimed) = farm.getStake(nft11);

    assertEq(stakedLiq, 0);
    assertEq(lastSumRewardPerLiquidity.length, 0);
    assertEq(rewardUnclaimed.length, 0);
    assertEq(nft.ownerOf(nft11), user1);

    uint256 balanceTokenAfter = token.balanceOf(user1);
    uint256 balanceETHAfter = payable(user1).balance;

    assertApproxEqAbs(balanceTokenAfter - balanceTokenBefore, 10 ether, 10);
    assertApproxEqAbs(balanceETHAfter - balanceETHBefore, 10 ether, 10);
  }

  function test_In_25_withdraw_list_nfts_with_sameId() public {
    vm.startPrank(deployer);

    IELM3.RangeInput[] memory r = new IELM3.RangeInput[](1);
    r[0] = IELM3.RangeInput({tickLower: -5, tickUpper: -2, weight: 2});

    IELM3.RewardInput[] memory rw = new IELM3.RewardInput[](2);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 300 ether});
    rw[1] = IELM3.RewardInput({
      rewardToken: address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
      rewardAmount: 300 ether
    });

    IELM3.PhaseInput memory p = IELM3.PhaseInput({startTime: st, endTime: et, rewards: rw});
    token.approve(address(farm), MAX_UINT256);

    uint256 fId = farm.addFarm(ePool, r, p, true);
    token.transfer(address(farm), 300 ether);
    vm.deal(address(farm), 300 ether);

    changePrank(user1);
    nft.setApprovalForAll(address(farm), true);
    uint256[] memory listNFT = new uint256[](3);
    listNFT[0] = nft0;
    listNFT[1] = nft1;
    listNFT[2] = nft11;

    farm.deposit(fId, 0, listNFT, user1);

    vm.warp(st + 1 days);

    listNFT = new uint256[](3);
    listNFT[0] = nft0;
    listNFT[1] = nft1;
    listNFT[2] = nft1;

    vm.expectRevert(abi.encodeWithSignature('FailToRemove()'));
    farm.withdraw(fId, listNFT);
  }

  function test_In_26_addLiquidity_list_nfts() public {
    vm.startPrank(deployer);

    IELM3.RangeInput[] memory r = new IELM3.RangeInput[](1);
    r[0] = IELM3.RangeInput({tickLower: -5, tickUpper: -2, weight: 2});

    IELM3.RewardInput[] memory rw = new IELM3.RewardInput[](2);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 300 ether});
    rw[1] = IELM3.RewardInput({
      rewardToken: address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
      rewardAmount: 300 ether
    });

    IELM3.PhaseInput memory p = IELM3.PhaseInput({startTime: st, endTime: et, rewards: rw});
    token.approve(address(farm), MAX_UINT256);

    uint256 fId = farm.addFarm(ePool, r, p, true);
    token.transfer(address(farm), 300 ether);
    vm.deal(address(farm), 300 ether);

    changePrank(user1);
    nft.setApprovalForAll(address(farm), true);
    uint256[] memory listNFT = new uint256[](3);
    listNFT[0] = nft0;
    listNFT[1] = nft1;
    listNFT[2] = nft11;

    farm.deposit(fId, 0, listNFT, user1);

    vm.warp(st + 1 days);

    nft.addLiquidity(nft0, 10 ether);
    nft.addLiquidity(nft1, 10 ether);
    nft.addLiquidity(nft11, 10 ether);

    farm.addLiquidity(fId, 0, listNFT);

    (
      ,
      ,
      ,
      uint256 liquidity,
      address farmingToken,
      uint256[] memory sumRewardPerLiquidity,

    ) = farm.getFarm(fId);

    assertEq(liquidity, 240 ether);
    assertEq(sumRewardPerLiquidity[0], 4401564584125796532974663907);

    uint256 stakedLiq;
    uint256[] memory lastSumRewardPerLiquidity;
    uint256[] memory rewardUnclaimed;

    (, , , stakedLiq, lastSumRewardPerLiquidity, rewardUnclaimed) = farm.getStake(nft0);

    assertEq(stakedLiq, 80 ether);
    assertEq(lastSumRewardPerLiquidity[0], 4401564584125796532974663907);
    assertApproxEqAbs(rewardUnclaimed[0], 3333333333333333333, 10);

    (, , , stakedLiq, lastSumRewardPerLiquidity, rewardUnclaimed) = farm.getStake(nft1);

    assertEq(stakedLiq, 60 ether);
    assertEq(lastSumRewardPerLiquidity[0], 4401564584125796532974663907);
    assertApproxEqAbs(rewardUnclaimed[0], 2222222222222222222, 10);

    (, , , stakedLiq, lastSumRewardPerLiquidity, rewardUnclaimed) = farm.getStake(nft11);

    assertEq(stakedLiq, 100 ether);
    assertEq(lastSumRewardPerLiquidity[0], 4401564584125796532974663907);
    assertApproxEqAbs(rewardUnclaimed[0], 4444444444444444444, 10);

    assertEq(IERC20(farmingToken).balanceOf(user1), 240 ether);
  }

  function test_In_27_addLiquidity_list_nfts_with_sameId() public {
    vm.startPrank(deployer);

    IELM3.RangeInput[] memory r = new IELM3.RangeInput[](1);
    r[0] = IELM3.RangeInput({tickLower: -5, tickUpper: -2, weight: 2});

    IELM3.RewardInput[] memory rw = new IELM3.RewardInput[](2);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 300 ether});
    rw[1] = IELM3.RewardInput({
      rewardToken: address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
      rewardAmount: 300 ether
    });

    IELM3.PhaseInput memory p = IELM3.PhaseInput({startTime: st, endTime: et, rewards: rw});
    token.approve(address(farm), MAX_UINT256);

    uint256 fId = farm.addFarm(ePool, r, p, true);
    token.transfer(address(farm), 300 ether);
    vm.deal(address(farm), 300 ether);

    changePrank(user1);
    nft.setApprovalForAll(address(farm), true);
    uint256[] memory listNFT = new uint256[](3);
    listNFT[0] = nft0;
    listNFT[1] = nft1;
    listNFT[2] = nft11;

    farm.deposit(fId, 0, listNFT, user1);

    vm.warp(st + 1 days);

    nft.addLiquidity(nft0, 10 ether);
    nft.addLiquidity(nft1, 10 ether);
    nft.addLiquidity(nft11, 10 ether);

    listNFT[0] = nft0;
    listNFT[1] = nft0;
    listNFT[2] = nft11;

    farm.addLiquidity(fId, 0, listNFT);

    (
      ,
      ,
      ,
      uint256 liquidity,
      address farmingToken,
      uint256[] memory sumRewardPerLiquidity,

    ) = farm.getFarm(fId);

    assertEq(liquidity, 220 ether);
    assertEq(sumRewardPerLiquidity[0], 4401564584125796532974663907);

    uint256 stakedLiq;
    uint256[] memory lastSumRewardPerLiquidity;
    uint256[] memory rewardUnclaimed;

    (, , , stakedLiq, lastSumRewardPerLiquidity, rewardUnclaimed) = farm.getStake(nft0);

    assertEq(stakedLiq, 80 ether);
    assertEq(lastSumRewardPerLiquidity[0], 4401564584125796532974663907);
    assertApproxEqAbs(rewardUnclaimed[0], 3333333333333333333, 10);

    (, , , stakedLiq, lastSumRewardPerLiquidity, rewardUnclaimed) = farm.getStake(nft1);

    assertEq(stakedLiq, 40 ether);
    assertEq(lastSumRewardPerLiquidity[0], 0);
    assertApproxEqAbs(rewardUnclaimed[0], 0, 10);

    (, , , stakedLiq, lastSumRewardPerLiquidity, rewardUnclaimed) = farm.getStake(nft11);

    assertEq(stakedLiq, 100 ether);
    assertEq(lastSumRewardPerLiquidity[0], 4401564584125796532974663907);
    assertApproxEqAbs(rewardUnclaimed[0], 4444444444444444444, 10);

    assertEq(IERC20(farmingToken).balanceOf(user1), 220 ether);
  }

  function test_In_28_removeLiquidity_list_nfts() public {
    vm.startPrank(deployer);

    IELM3.RangeInput[] memory r = new IELM3.RangeInput[](1);
    r[0] = IELM3.RangeInput({tickLower: -5, tickUpper: -2, weight: 2});

    IELM3.RewardInput[] memory rw = new IELM3.RewardInput[](2);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 300 ether});
    rw[1] = IELM3.RewardInput({
      rewardToken: address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
      rewardAmount: 300 ether
    });

    IELM3.PhaseInput memory p = IELM3.PhaseInput({startTime: st, endTime: et, rewards: rw});
    token.approve(address(farm), MAX_UINT256);

    uint256 fId = farm.addFarm(ePool, r, p, true);
    token.transfer(address(farm), 300 ether);
    vm.deal(address(farm), 300 ether);

    changePrank(user1);
    nft.setApprovalForAll(address(farm), true);
    uint256[] memory listNFT = new uint256[](3);
    listNFT[0] = nft0;
    listNFT[1] = nft1;
    listNFT[2] = nft11;

    farm.deposit(fId, 0, listNFT, user1);

    vm.warp(st + 1 days);

    uint128[] memory removeLiqs = new uint128[](3);
    removeLiqs[0] = 10 ether;
    removeLiqs[1] = 10 ether;
    removeLiqs[2] = 10 ether;

    farm.removeLiquidity(listNFT[0], removeLiqs[0], 0, 0, 2 ** 255, true, false);
    farm.removeLiquidity(listNFT[1], removeLiqs[1], 0, 0, 2 ** 255, true, false);
    farm.removeLiquidity(listNFT[2], removeLiqs[2], 0, 0, 2 ** 255, true, false);

    (
      ,
      ,
      ,
      uint256 liquidity,
      address farmingToken,
      uint256[] memory sumRewardPerLiquidity,

    ) = farm.getFarm(fId);

    assertEq(liquidity, 120 ether);
    assertEq(sumRewardPerLiquidity[0], 4401564584125796532974663907);

    uint256 stakedLiq;
    uint256[] memory lastSumRewardPerLiquidity;
    uint256[] memory rewardUnclaimed;

    (, , , stakedLiq, lastSumRewardPerLiquidity, rewardUnclaimed) = farm.getStake(nft0);

    assertEq(stakedLiq, 40 ether);
    assertEq(lastSumRewardPerLiquidity[0], 4401564584125796532974663907);
    assertApproxEqAbs(rewardUnclaimed[0], 3333333333333333333, 10);

    (, , , stakedLiq, lastSumRewardPerLiquidity, rewardUnclaimed) = farm.getStake(nft1);

    assertEq(stakedLiq, 20 ether);
    assertEq(lastSumRewardPerLiquidity[0], 4401564584125796532974663907);
    assertApproxEqAbs(rewardUnclaimed[0], 2222222222222222222, 10);

    (, , , stakedLiq, lastSumRewardPerLiquidity, rewardUnclaimed) = farm.getStake(nft11);

    assertEq(stakedLiq, 60 ether);
    assertEq(lastSumRewardPerLiquidity[0], 4401564584125796532974663907);
    assertApproxEqAbs(rewardUnclaimed[0], 4444444444444444444, 10);

    assertEq(IERC20(farmingToken).balanceOf(user1), 120 ether);
  }

  function test_In_29_removeLiquidity_list_nfts_with_sameId() public {
    vm.startPrank(deployer);

    IELM3.RangeInput[] memory r = new IELM3.RangeInput[](1);
    r[0] = IELM3.RangeInput({tickLower: -5, tickUpper: -2, weight: 2});

    IELM3.RewardInput[] memory rw = new IELM3.RewardInput[](2);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 300 ether});
    rw[1] = IELM3.RewardInput({
      rewardToken: address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
      rewardAmount: 300 ether
    });

    IELM3.PhaseInput memory p = IELM3.PhaseInput({startTime: st, endTime: et, rewards: rw});
    token.approve(address(farm), MAX_UINT256);

    uint256 fId = farm.addFarm(ePool, r, p, true);
    token.transfer(address(farm), 300 ether);
    vm.deal(address(farm), 300 ether);

    changePrank(user1);
    nft.setApprovalForAll(address(farm), true);
    uint256[] memory listNFT = new uint256[](3);
    listNFT[0] = nft0;
    listNFT[1] = nft1;
    listNFT[2] = nft11;

    farm.deposit(fId, 0, listNFT, user1);

    vm.warp(st + 1 days);

    listNFT[0] = nft0;
    listNFT[1] = nft0;
    listNFT[2] = nft11;

    uint128[] memory removeLiqs = new uint128[](3);
    removeLiqs[0] = 10 ether;
    removeLiqs[1] = 10 ether;
    removeLiqs[2] = 10 ether;

    farm.removeLiquidity(listNFT[0], removeLiqs[0], 0, 0, 2 ** 255, true, false);
  }

  function test_In_30_withdrawEmergency_list_nfts() public {
    vm.startPrank(deployer);

    IELM3.RangeInput[] memory r = new IELM3.RangeInput[](1);
    r[0] = IELM3.RangeInput({tickLower: -5, tickUpper: -2, weight: 2});

    IELM3.RewardInput[] memory rw = new IELM3.RewardInput[](2);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 300 ether});
    rw[1] = IELM3.RewardInput({
      rewardToken: address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
      rewardAmount: 300 ether
    });

    IELM3.PhaseInput memory p = IELM3.PhaseInput({startTime: st, endTime: et, rewards: rw});
    token.approve(address(farm), MAX_UINT256);

    uint256 fId = farm.addFarm(ePool, r, p, true);
    token.transfer(address(farm), 300 ether);
    vm.deal(address(farm), 300 ether);

    changePrank(user1);
    nft.setApprovalForAll(address(farm), true);
    uint256[] memory listNFT = new uint256[](3);
    listNFT[0] = nft0;
    listNFT[1] = nft1;
    listNFT[2] = nft11;

    farm.deposit(fId, 0, listNFT, user1);

    vm.warp(st + 1 days);

    farm.withdrawEmergency(listNFT);

    (, , , uint256 liquidity, address farmingToken, , ) = farm.getFarm(fId);

    assertEq(liquidity, 0);

    assertEq(nft.ownerOf(nft0), user1);
    assertEq(nft.ownerOf(nft1), user1);
    assertEq(nft.ownerOf(nft11), user1);

    uint256 stakedLiq;
    uint256[] memory lastSumRewardPerLiquidity;
    uint256[] memory rewardUnclaimed;

    (, , , stakedLiq, lastSumRewardPerLiquidity, rewardUnclaimed) = farm.getStake(nft0);

    assertEq(stakedLiq, 0);
    assertEq(lastSumRewardPerLiquidity.length, 0);
    assertEq(rewardUnclaimed.length, 0);

    (, , , stakedLiq, lastSumRewardPerLiquidity, rewardUnclaimed) = farm.getStake(nft1);

    assertEq(stakedLiq, 0);
    assertEq(lastSumRewardPerLiquidity.length, 0);
    assertEq(rewardUnclaimed.length, 0);

    (, , , stakedLiq, lastSumRewardPerLiquidity, rewardUnclaimed) = farm.getStake(nft11);

    assertEq(stakedLiq, 0);
    assertEq(lastSumRewardPerLiquidity.length, 0);
    assertEq(rewardUnclaimed.length, 0);

    assertEq(IERC20(farmingToken).balanceOf(user1), 0);
  }

  function test_In_31_withdrawEmergency_list_nfts_with_same_Id() public {
    vm.startPrank(deployer);

    IELM3.RangeInput[] memory r = new IELM3.RangeInput[](1);
    r[0] = IELM3.RangeInput({tickLower: -5, tickUpper: -2, weight: 2});

    IELM3.RewardInput[] memory rw = new IELM3.RewardInput[](2);
    rw[0] = IELM3.RewardInput({rewardToken: address(token), rewardAmount: 300 ether});
    rw[1] = IELM3.RewardInput({
      rewardToken: address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
      rewardAmount: 300 ether
    });

    IELM3.PhaseInput memory p = IELM3.PhaseInput({startTime: st, endTime: et, rewards: rw});
    token.approve(address(farm), MAX_UINT256);

    uint256 fId = farm.addFarm(ePool, r, p, true);
    token.transfer(address(farm), 300 ether);
    vm.deal(address(farm), 300 ether);

    changePrank(user1);
    nft.setApprovalForAll(address(farm), true);
    uint256[] memory listNFT = new uint256[](3);
    listNFT[0] = nft0;
    listNFT[1] = nft1;
    listNFT[2] = nft11;

    farm.deposit(fId, 0, listNFT, user1);

    vm.warp(st + 1 days);

    listNFT[0] = nft0;
    listNFT[1] = nft0;
    listNFT[2] = nft11;

    vm.expectRevert(abi.encodeWithSignature('NotOwner()'));
    farm.withdrawEmergency(listNFT);
  }
}
