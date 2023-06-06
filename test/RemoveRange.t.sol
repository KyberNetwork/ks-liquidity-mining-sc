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

contract RemoveRange is Base {
    using SafeERC20 for IERC20;

    function testRemoveRangeSuccess() public {
        vm.startPrank(deployer);
        lm.removeRange(fId, 0);
        vm.stopPrank();
    }

    function testRemoveRangeRevertInvalidFarm() public {
        vm.startPrank(deployer);
        vm.expectRevert(abi.encodeWithSignature("InvalidFarm()"));
        lm.removeRange(99, 0);
        vm.stopPrank();
    }

    function testRemoveRangeRevertInvalidRange() public {
        vm.startPrank(deployer);
        vm.expectRevert(abi.encodeWithSignature("RangeNotFound()"));
        lm.removeRange(fId, 10);
        vm.stopPrank();
    }
}
