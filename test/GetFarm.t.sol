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

import {Base} from "./Base.t.sol";

contract GetFarm is Base {
    using SafeERC20 for IERC20;

    function testGetFarmSuccess() public {
        (
            address poolAddress,
            IKSElasticLMV2.RangeInfo[] memory ranges,
            IKSElasticLMV2.PhaseInfo memory phaseInfo,
            uint256 liquidity,
            ,
            ,

        ) = lm.getFarm(fId);

        assertEq(poolAddress, pool);

        assertEq(ranges[0].tickLower, -4);
        assertEq(ranges[0].tickUpper, 4);
        assertEq(ranges[0].weight, 1);

        assertEq(ranges[1].tickLower, -5);
        assertEq(ranges[1].tickUpper, 5);
        assertEq(ranges[1].weight, 2);

        assertEq(ranges[2].tickLower, -10);
        assertEq(ranges[2].tickUpper, 10);
        assertEq(ranges[2].weight, 3);

        assertEq(liquidity, 0);

        assertEq(phaseInfo.startTime, startTime);
        assertEq(phaseInfo.endTime, endTime);
        assertEq(phaseInfo.rewards.length, 2);
        assertEq(phaseInfo.rewards[0].rewardToken, address(usdc));
        assertEq(phaseInfo.rewards[0].rewardAmount, rewardAmount);
        assertEq(phaseInfo.rewards[1].rewardToken, address(usdt));
        assertEq(phaseInfo.rewards[1].rewardAmount, rewardAmount);
        assertEq(phaseInfo.isSettled, false);
    }
}
