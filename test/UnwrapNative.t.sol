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
import {IFactory} from "contracts/interfaces/IFactory.sol";

import {Base} from "./Base.t.sol";

contract UnwrapNative is Base {
    using SafeERC20 for IERC20;

    IERC20 weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    address wethWhale = 0xF04a5cC80B1E94C69B48f5ee68a08CD2F09A7c3E;

    address wethUsdtPool = 0x7d697d789ee19bc376474E0167BADe9535A28CF4;

    uint256 fWethId;
    uint256 nftId = 1; //belongs to poolId 1, liquidity > 0
    uint128 nftLiq = 117546247299525;
    uint256 amountWethWhenRemoveLiquidity = 784318538031233553; //get by call directly to posManager
    uint256 amountWethWhenClaimFee = 17825205570209216; // get by call directly to posManager

    function setUp() public override {
        super.setUp();

        ranges[1].tickLower = -201000;
        ranges[1].tickUpper = -200000;

        vm.startPrank(deployer);
        fWethId = lm.addFarm(wethUsdtPool, ranges, phase, true);
        vm.stopPrank();

        vm.startPrank(wethWhale);
        weth.safeTransfer(address(lm), rewardAmount);
        vm.stopPrank();

        vm.label(address(weth), "WETH");
        vm.label(pool, "Pool ID 1");

        uint256[] memory nfts = new uint256[](1);
        nfts[0] = nftId;

        address nftOwner = nft.ownerOf(nftId);

        vm.startPrank(nftOwner);
        nft.approve(address(lm), nftId);
        lm.deposit(fWethId, 1, nfts, jensen);
        vm.stopPrank();
    }

    function testSetUp() public override {
        (
            ,
            uint256 fIdDeposited,
            uint256 rangeIdDeposited,
            uint256 liquidityDeposited,
            uint256[] memory lastSumRewardPerLiquidity,

        ) = lm.getStake(nftId);

        assertEq(fIdDeposited, fWethId);
        assertEq(rangeIdDeposited, 1);
        assertEq(nft.ownerOf(nftId), address(lm));
        assertEq(liquidityDeposited, _getLiq(nftId) * 2);
        assertEq(lastSumRewardPerLiquidity[0], 0);
        assertEq(lastSumRewardPerLiquidity[1], 0);

        uint256[] memory listNftIds = lm.getDepositedNFTs(jensen);
        assertEq(listNftIds.length, 1);
        assertEq(listNftIds[0], nftId);
    }

    function testUnwrapNativeRemoveAllLiquidity() public {
        uint256 balanceBefore = payable(jensen).balance;

        vm.startPrank(jensen);
        lm.removeLiquidity(
            nftId,
            nftLiq,
            0,
            0,
            block.timestamp + 3600,
            false,
            true
        );
        vm.stopPrank();

        uint256 balanceAfter = payable(jensen).balance;

        assertEq(balanceAfter - balanceBefore, amountWethWhenRemoveLiquidity);
    }

    function testUnwrapNativeRemoveHalfLiquidity() public {
        uint256 balanceBefore = payable(jensen).balance;

        vm.startPrank(jensen);
        lm.removeLiquidity(
            nftId,
            nftLiq / 2,
            0,
            0,
            block.timestamp + 3600,
            false,
            true
        );
        vm.stopPrank();

        uint256 balanceAfter = payable(jensen).balance;

        assertApproxEqAbs(
            balanceAfter - balanceBefore,
            amountWethWhenRemoveLiquidity / 2,
            10000
        );
    }

    function testUnwrapNativeRemoveAllLiquidityAndClaimFee() public {
        uint256 balanceBefore = payable(jensen).balance;

        vm.startPrank(jensen);
        lm.removeLiquidity(
            nftId,
            nftLiq,
            0,
            0,
            block.timestamp + 3600,
            true,
            true
        );
        vm.stopPrank();

        uint256 balanceAfter = payable(jensen).balance;

        assertEq(
            balanceAfter - balanceBefore,
            amountWethWhenRemoveLiquidity + amountWethWhenClaimFee
        );
    }
}
