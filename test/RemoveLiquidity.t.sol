// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IKSElasticLMV2} from "contracts/interfaces/IKSElasticLMV2.sol";
import {IKyberSwapFarmingToken} from "contracts/interfaces/periphery/IKyberSwapFarmingToken.sol";
import {KSElasticLMV2} from "contracts/KSElasticLMV2.sol";
import {IBasePositionManager} from "contracts/interfaces/IBasePositionManager.sol";
import {MockToken} from "contracts/mock/MockToken.sol";
import {MockNftManagerV4 as MockNftManager} from "contracts/mock/MockNftManagerV4.sol";
import {MockKPoolV4 as MockPool} from "contracts/mock/MockKPoolV4.sol";
import {KSElasticLMHelper} from "contracts/KSElasticLMHelper.sol";
import {KyberSwapFarmingToken} from "contracts/periphery/KyberSwapFarmingToken.sol";

import {Base} from "./Base.t.sol";

contract RemoveLiquidity is Base {
    using SafeERC20 for IERC20;

    function _verifyStake(
        uint256 nftId,
        address expectedOwner,
        uint256 expectedFId,
        uint256 expectedRangeId,
        uint256 expectedStakeLiq,
        uint256 expectedLastSumRewardPerLiq,
        uint256 expectedRewardUnclaimed
    ) internal {
        (
            address owner,
            uint256 fId,
            uint256 rangeId,
            uint256 stakedLiq,
            uint256[] memory lastSumRewardPerLiquidity,
            uint256[] memory rewardUnclaimed
        ) = lm.getStake(nftId);

        assertEq(owner, expectedOwner);
        assertEq(fId, expectedFId);
        assertEq(rangeId, expectedRangeId);
        assertEq(stakedLiq, expectedStakeLiq);
        if (lastSumRewardPerLiquidity.length != 0)
            assertEq(lastSumRewardPerLiquidity[0], expectedLastSumRewardPerLiq);
        else assertEq(expectedLastSumRewardPerLiq, 0);
        if (rewardUnclaimed.length != 0)
            assertEq(rewardUnclaimed[0], expectedRewardUnclaimed);
        else assertEq(expectedRewardUnclaimed, 0);
    }

    function _calculateRewardAmount(
        uint32 joinedDuration,
        uint32 duration,
        uint256 liquidity,
        uint256 totalLiquidity,
        uint256 farmReward
    ) internal pure returns (uint256 rewardAmount) {
        rewardAmount =
            (joinedDuration * liquidity * farmReward) /
            (duration * totalLiquidity);
    }

    function testRemoveLiquiditySuccess() public {
        uint256 balanceUsdcBefore = usdc.balanceOf(rahoz);
        uint256 balanceUsdtBefore = usdt.balanceOf(rahoz);

        uint256 nftId = nftIds[2];
        uint256[] memory nfts = new uint256[](1);
        nfts[0] = nftId;

        vm.startPrank(deployer);
        nft.approve(address(lm), nftId);
        lm.deposit(fId, 1, nfts, rahoz);
        vm.stopPrank();

        uint128[] memory liquidities = new uint128[](1);
        liquidities[0] = 1;

        vm.startPrank(rahoz);
        lm.removeLiquidity(
            nfts[0],
            liquidities[0],
            0,
            0,
            block.timestamp + 3600,
            true,
            false
        );
        vm.stopPrank();

        uint256 balanceUsdcAfter = usdc.balanceOf(rahoz);
        uint256 balanceUsdtAfter = usdt.balanceOf(rahoz);

        assertEq(balanceUsdcAfter - balanceUsdcBefore, 857);
        assertEq(balanceUsdtAfter - balanceUsdtBefore, 856);
    }

    function testRemoveLiquiditySuccessCaseRemoveAll() public {
        uint256 nftId = nftIds[2];
        uint256 amountUsdcShouldBe = 5124844; //get from calling directly to posManager
        uint256 amountUsdtShouldBe = 4707024; //get from calling directly to posManager

        uint256 balanceUsdcBefore = usdc.balanceOf(rahoz);
        uint256 balanceUsdtBefore = usdt.balanceOf(rahoz);

        uint256[] memory nfts = new uint256[](1);
        nfts[0] = nftId;
        vm.startPrank(deployer);
        nft.approve(address(lm), nftId);
        lm.deposit(fId, 1, nfts, rahoz);
        vm.stopPrank();

        vm.startPrank(rahoz);
        lm.removeLiquidity(
            nftId,
            _getLiq(nftId),
            0,
            0,
            block.timestamp + 3600,
            false,
            false
        );
        vm.stopPrank();

        uint256 balanceUsdcAfter = usdc.balanceOf(rahoz);
        uint256 balanceUsdtAfter = usdt.balanceOf(rahoz);
        assertEq(balanceUsdcAfter - balanceUsdcBefore, amountUsdcShouldBe);
        assertEq(balanceUsdtAfter - balanceUsdtBefore, amountUsdtShouldBe);
    }

    function testRemoveLiquiditySuccessCaseRemoveAllAndClaimFee() public {
        uint256 nftId = nftIds[2];
        uint256 amountUsdcShouldBe = 5125701; //get from calling directly to posManager
        uint256 amountUsdtShouldBe = 4707880; //get from calling directly to posManager

        uint256 balanceUsdcBefore = usdc.balanceOf(rahoz);
        uint256 balanceUsdtBefore = usdt.balanceOf(rahoz);

        uint256[] memory nfts = new uint256[](1);
        nfts[0] = nftId;
        vm.startPrank(deployer);
        nft.approve(address(lm), nftId);
        lm.deposit(fId, 1, nfts, rahoz);
        vm.stopPrank();

        vm.startPrank(rahoz);
        lm.removeLiquidity(
            nftId,
            _getLiq(nftId),
            0,
            0,
            block.timestamp + 3600,
            true,
            false
        );
        vm.stopPrank();

        uint256 balanceUsdcAfter = usdc.balanceOf(rahoz);
        uint256 balanceUsdtAfter = usdt.balanceOf(rahoz);
        assertEq(balanceUsdcAfter - balanceUsdcBefore, amountUsdcShouldBe);
        assertEq(balanceUsdtAfter - balanceUsdtBefore, amountUsdtShouldBe);
    }

    function testRemoveLiquiditySuccessCaseAddMoreThanRemove() public {
        uint256 nftId = nftIds[2];
        uint256 amountUsdcShouldBe = 9999999;
        uint256 amountUsdtShouldBe = 9184715;

        uint256[] memory nfts = new uint256[](1);
        nfts[0] = nftId;

        vm.startPrank(deployer);
        nft.approve(address(lm), nftId);
        lm.deposit(fId, 1, nfts, rahoz);
        vm.stopPrank();

        IBasePositionManager.IncreaseLiquidityParams
            memory params = IBasePositionManager.IncreaseLiquidityParams({
                tokenId: nftId,
                amount0Desired: 10e6,
                amount1Desired: 10e6,
                amount0Min: 0,
                amount1Min: 0,
                deadline: UINT256_MAX
            });

        uint128 liqBefore = _getLiq(nftId);

        vm.startPrank(deployer);
        usdc.safeIncreaseAllowance(address(nft), 10e6);
        usdt.safeIncreaseAllowance(address(nft), 10e6);
        IBasePositionManager(address(nft)).addLiquidity(params);
        vm.stopPrank();

        uint128 liqDelta = _getLiq(nftId) - liqBefore;

        uint256 balanceUsdcBefore = usdc.balanceOf(rahoz);
        uint256 balanceUsdtBefore = usdt.balanceOf(rahoz);

        vm.startPrank(rahoz);
        lm.removeLiquidity(
            nftId,
            liqDelta - 1,
            0,
            0,
            block.timestamp + 3600,
            false,
            false
        );
        vm.stopPrank();

        uint256 balanceUsdcAfter = usdc.balanceOf(rahoz);
        uint256 balanceUsdtAfter = usdt.balanceOf(rahoz);

        assertEq(balanceUsdcAfter - balanceUsdcBefore, amountUsdcShouldBe);
        assertEq(balanceUsdtAfter - balanceUsdtBefore, amountUsdtShouldBe);

        _verifyStake(nftId, rahoz, fId, 1, liqBefore * 2, 0, 0); // everything the same as before because it's not updated
    }

    function testRemoveLiquiditySuccessCaseAddLessThanRemove() public {
        uint256 nftId = nftIds[2];
        uint256 amountUsdcShouldBe = 15124844;
        uint256 amountUsdtShouldBe = 13891739;

        uint256[] memory nfts = new uint256[](1);
        nfts[0] = nftId;

        vm.startPrank(deployer);
        nft.approve(address(lm), nftId);
        lm.deposit(fId, 1, nfts, rahoz);
        vm.stopPrank();

        IBasePositionManager.IncreaseLiquidityParams
            memory params = IBasePositionManager.IncreaseLiquidityParams({
                tokenId: nftId,
                amount0Desired: 10e6,
                amount1Desired: 10e6,
                amount0Min: 0,
                amount1Min: 0,
                deadline: UINT256_MAX
            });

        vm.startPrank(deployer);
        usdc.safeIncreaseAllowance(address(nft), 10e6);
        usdt.safeIncreaseAllowance(address(nft), 10e6);
        IBasePositionManager(address(nft)).addLiquidity(params);
        vm.stopPrank();

        uint256 balanceUsdcBefore = usdc.balanceOf(rahoz);
        uint256 balanceUsdtBefore = usdt.balanceOf(rahoz);

        vm.startPrank(rahoz);
        lm.removeLiquidity(
            nftId,
            _getLiq(nftId),
            0,
            0,
            block.timestamp + 3600,
            false,
            false
        );
        vm.stopPrank();

        uint256 balanceUsdcAfter = usdc.balanceOf(rahoz);
        uint256 balanceUsdtAfter = usdt.balanceOf(rahoz);

        assertEq(balanceUsdcAfter - balanceUsdcBefore, amountUsdcShouldBe);
        assertEq(balanceUsdtAfter - balanceUsdtBefore, amountUsdtShouldBe);

        _verifyStake(nftId, rahoz, fId, 1, 0, 0, 0); // everything the same as before because it's not updated
    }

    function testRemoveLiquidityFailNotOwner() public {
        uint256 nftId = nftIds[2];
        uint256[] memory nfts = new uint256[](1);
        nfts[0] = nftId;

        vm.startPrank(deployer);
        nft.approve(address(lm), nftId);
        lm.deposit(fId, 1, nfts, jensen);
        vm.stopPrank();

        uint128[] memory liquidities = new uint128[](1);
        liquidities[0] = 1;

        vm.startPrank(rahoz); // wrong owner
        vm.expectRevert(abi.encodeWithSignature("NotOwner()"));
        lm.removeLiquidity(
            nfts[0],
            liquidities[0],
            0,
            0,
            block.timestamp + 3600,
            true,
            false
        );
        vm.stopPrank();
    }

    function testRemoveAllLiquidityThenClaimRewards() public {
        uint256 nftId = nftIds[2];

        uint256[] memory nfts = new uint256[](1);
        nfts[0] = nftId;
        vm.startPrank(deployer);
        nft.approve(address(lm), nftId);
        lm.deposit(fId, 1, nfts, deployer);

        lm.removeLiquidity(
            nftId,
            _getLiq(nftId),
            0,
            0,
            block.timestamp + 3600,
            false,
            false
        );

        vm.warp(block.timestamp + 7 days);

        uint256[] memory rewardBalancesBefore = _getRewardBalances(deployer);

        lm.claimReward(fId, nfts);

        uint256[] memory rewardBalancesAfter = _getRewardBalances(deployer);
        // no rewards
        _verifyUintArray(rewardBalancesBefore, rewardBalancesAfter);
    }

    function testRemoveAllLiquidityThenWithdraw() public {
        uint256 nftId = nftIds[2];

        uint256[] memory nfts = new uint256[](1);
        nfts[0] = nftId;
        vm.startPrank(deployer);
        nft.approve(address(lm), nftId);
        lm.deposit(fId, 1, nfts, deployer);

        lm.removeLiquidity(
            nftId,
            _getLiq(nftId),
            0,
            0,
            block.timestamp + 3600,
            false,
            false
        );

        _verifyStake(nftId, deployer, fId, 1, 0, 0, 0);

        lm.withdraw(fId, nfts);

        // remove stake info
        _verifyStake(nftId, address(0), 0, 0, 0, 0, 0);

        assertTrue(nft.ownerOf(nftId) == deployer);
    }

    function testRemoveAllLiquidityThenWithdrawEmergencyWhenNotEmergencyEnabled()
        public
    {
        uint256 nftId = nftIds[2];

        uint256[] memory nfts = new uint256[](1);
        nfts[0] = nftId;
        vm.startPrank(deployer);
        nft.approve(address(lm), nftId);
        lm.deposit(fId, 1, nfts, deployer);

        lm.removeLiquidity(
            nftId,
            _getLiq(nftId),
            0,
            0,
            block.timestamp + 3600,
            false,
            false
        );

        _verifyStake(nftId, deployer, fId, 1, 0, 0, 0);

        lm.withdrawEmergency(nfts);
        // remove stake info
        _verifyStake(nftId, address(0), 0, 0, 0, 0, 0);

        uint256[] memory deposited = lm.getDepositedNFTs(deployer);

        assertFalse(_inUintArray(nftId, deposited));

        assertTrue(nft.ownerOf(nftId) == deployer);
    }

    function testRemoveAllLiquidityThenWithdrawEmergencyWhenEmergencyEnabled()
        public
    {
        uint256 nftId = nftIds[2];

        uint256[] memory nfts = new uint256[](1);
        nfts[0] = nftId;
        vm.startPrank(deployer);
        nft.approve(address(lm), nftId);
        lm.deposit(fId, 1, nfts, deployer);

        lm.removeLiquidity(
            nftId,
            _getLiq(nftId),
            0,
            0,
            block.timestamp + 3600,
            false,
            false
        );

        _verifyStake(nftId, deployer, fId, 1, 0, 0, 0);

        // enable emergency
        lm.updateEmergency(true);

        lm.withdrawEmergency(nfts);
        // remove stake info
        _verifyStake(nftId, address(0), 0, 0, 0, 0, 0);

        uint256[] memory deposited = lm.getDepositedNFTs(deployer);

        assertTrue(_inUintArray(nftId, deposited));

        assertTrue(nft.ownerOf(nftId) == deployer);
    }

    function testRemoveAllLiquidityThenAddLiquidityWithLegacyElastic() public {
        uint256 nftId = nftIds[2];

        uint256[] memory nfts = new uint256[](1);
        nfts[0] = nftId;
        vm.startPrank(deployer);
        nft.approve(address(lm), nftId);
        lm.deposit(fId, 1, nfts, deployer);

        lm.removeLiquidity(
            nftId,
            _getLiq(nftId),
            0,
            0,
            block.timestamp + 3600,
            false,
            false
        );

        _verifyStake(nftId, deployer, fId, 1, 0, 0, 0);

        IBasePositionManager.IncreaseLiquidityParams
            memory params = IBasePositionManager.IncreaseLiquidityParams({
                tokenId: nftId,
                amount0Desired: 10e6,
                amount1Desired: 10e6,
                amount0Min: 0,
                amount1Min: 0,
                deadline: UINT256_MAX
            });
        usdc.safeIncreaseAllowance(address(nft), 10e6);
        usdt.safeIncreaseAllowance(address(nft), 10e6);

        vm.expectRevert(bytes("invalid lower value"));
        IBasePositionManager(address(nft)).addLiquidity(params);

        // no state changes
        lm.addLiquidity(fId, 1, nfts);
        _verifyStake(nftId, deployer, fId, 1, 0, 0, 0);
    }

    function testRemoveAllLiquidityThenAddLiquidityWithElasticV2() public {
        (
            ,
            ,
            MockNftManager mockNft,
            MockPool mockPool
        ) = _mockElasticV2TestSetup();

        uint256 nftId = mockNft.mint(rahoz, address(mockPool), 10 ether);
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = nftId;

        vm.startPrank(rahoz);
        mockNft.approve(address(lm), nftId);
        lm.deposit(fId, 0, nftIds, rahoz);

        (IBasePositionManager.Position memory pos, ) = IBasePositionManager(
            address(mockNft)
        ).positions(nftId);

        // remove all liq
        lm.removeLiquidity(
            nftId,
            pos.liquidity,
            0,
            0,
            block.timestamp,
            true,
            false
        );
        _verifyStake(nftId, rahoz, fId, 0, 0, 0, 0);

        // add liq again
        mockNft.addLiquidity(nftId, pos.liquidity);
        lm.addLiquidity(fId, 0, nftIds);
        _verifyStake(nftId, rahoz, fId, 0, pos.liquidity, 0, 0);
    }

    function testRemoveAllLiquidityEffectOtherPositions() public {
        uint256 nftId1 = 204;
        uint256 nftId2 = 262;
        uint256 nftId3 = 263;

        uint256 nft1Liq = 485393355282;
        uint256 nft2Liq = 2034126572035826;
        uint256 nft3Liq = 8168583651254383;

        uint256[] memory nftIds = new uint256[](3);
        nftIds[0] = nftId1;
        nftIds[1] = nftId2;
        nftIds[2] = nftId3;

        for (uint256 i; i < nftIds.length; i++) {
            address nftOwner = nft.ownerOf(nftIds[i]);

            vm.prank(nftOwner);
            nft.transferFrom(nftOwner, deployer, nftIds[i]);

            vm.prank(deployer);
            nft.approve(address(lm), nftIds[i]);
        }

        IKSElasticLMV2.RangeInput memory newRange = IKSElasticLMV2.RangeInput({
            tickLower: 0,
            tickUpper: 4,
            weight: 1
        });

        vm.prank(deployer);
        lm.addRange(fId, newRange);

        vm.startPrank(deployer);

        nftIds = new uint256[](1);
        nftIds[0] = nftId2;
        lm.deposit(fId, 3, nftIds, jensen);

        nftIds = new uint256[](2);
        nftIds[0] = nftId1;
        nftIds[1] = nftId3;
        lm.deposit(fId, 3, nftIds, rahoz);

        vm.stopPrank();

        vm.warp(startTime + 1 days);

        vm.startPrank(jensen);
        lm.removeLiquidity(
            nftId2,
            uint128(nft2Liq),
            0,
            0,
            UINT256_MAX,
            false,
            false
        );

        uint256 deltaBalancJZ = usdc.balanceOf(jensen);
        nftIds = new uint256[](1);
        nftIds[0] = nftId2;
        lm.claimReward(fId, nftIds);
        deltaBalancJZ = usdc.balanceOf(jensen) - deltaBalancJZ;
        vm.stopPrank();

        vm.warp(endTime);

        uint256 deltaBalanceRH = usdc.balanceOf(rahoz);
        vm.startPrank(rahoz);
        nftIds = new uint256[](2);
        nftIds[0] = nftId1;
        nftIds[1] = nftId3;
        lm.claimReward(fId, nftIds);
        vm.stopPrank();
        deltaBalanceRH = usdc.balanceOf(rahoz) - deltaBalanceRH;

        uint256 rewardNftId2 = _calculateRewardAmount(
            1 days,
            endTime - startTime,
            nft2Liq,
            nft1Liq + nft2Liq + nft3Liq,
            rewardAmount
        );

        uint256 rewardNftId1AndNftId3Day1 = _calculateRewardAmount(
            1 days,
            endTime - startTime,
            nft1Liq + nft3Liq,
            nft1Liq + nft2Liq + nft3Liq,
            rewardAmount
        );

        uint256 rewardNftId1AndNftId3Day2TillEndTime = _calculateRewardAmount(
            endTime - startTime - 1 days,
            endTime - startTime,
            nft1Liq + nft3Liq,
            nft1Liq + nft3Liq,
            rewardAmount
        );

        assertApproxEqAbs(deltaBalancJZ, rewardNftId2, 10); // balance only changed because of rewards
        assertApproxEqAbs(
            deltaBalanceRH,
            rewardNftId1AndNftId3Day1 + rewardNftId1AndNftId3Day2TillEndTime,
            10
        );
    }

    function _mockElasticV2TestSetup()
        private
        returns (
            MockToken mockUsdc,
            MockToken mockUsdt,
            MockNftManager mockNft,
            MockPool mockPool
        )
    {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
        vm.rollFork(16_146_028);

        deployer = makeAddr("Deployer");
        jensen = makeAddr("Jensen");
        rahoz = makeAddr("Rahoz");

        mockUsdc = new MockToken("USDC", "USDC", 2000 * 10 ** 6);
        mockUsdt = new MockToken("USDT", "USDT", 2000 * 10 ** 6);
        mockNft = new MockNftManager(address(this), WETH);
        mockPool = new MockPool(mockUsdc, mockUsdt);
        mockNft.setAddressToPoolId(address(mockPool), 12);

        helper = new KSElasticLMHelper();
        lm = new KSElasticLMV2(IERC721(address(mockNft)), helper);

        lm.updateOperator(deployer, true);
        lm.updateTokenCode(type(KyberSwapFarmingToken).creationCode);

        vm.deal(deployer, 1000 ether);
        vm.deal(jensen, 1000 ether);

        rewards.push(
            IKSElasticLMV2.RewardInput({
                rewardToken: address(mockUsdc),
                rewardAmount: rewardAmount
            })
        );

        rewards.push(
            IKSElasticLMV2.RewardInput({
                rewardToken: address(mockUsdt),
                rewardAmount: rewardAmount
            })
        );

        phase.startTime = startTime;
        phase.endTime = endTime;
        phase.rewards = rewards;

        ranges.push(
            IKSElasticLMV2.RangeInput({tickLower: -4, tickUpper: 4, weight: 1})
        );
        ranges.push(
            IKSElasticLMV2.RangeInput({tickLower: -5, tickUpper: 5, weight: 2})
        );
        ranges.push(
            IKSElasticLMV2.RangeInput({
                tickLower: -10,
                tickUpper: 10,
                weight: 3
            })
        );

        vm.startPrank(deployer);
        fId = lm.addFarm(address(mockPool), ranges, phase, true);
        (, , , , address farmingTokenAddr, , ) = lm.getFarm(fId);

        farmingToken = IKyberSwapFarmingToken(farmingTokenAddr);

        mockUsdc.mint(address(lm), rewardAmount);
        mockUsdt.mint(address(lm), rewardAmount);
        vm.stopPrank();

        vm.label(address(usdc), "USDC");
        vm.label(address(usdt), "USDT");
        vm.label(address(nft), "NFT");
    }
}
