// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import 'forge-std/Script.sol';
import {IKSElasticLMV2 as IELM2User} from 'contracts/interfaces/IKSElasticLMV2.sol';

interface IELM2 is IELM2User {
  // ======== operator ============
  /// @dev create a new farm matched with an Elastic Pool
  /// @param poolAddress elastic pool address
  /// @param ranges eligible farm ranges
  /// @param phase farm first phase
  /// @param isUsingToken set true to deploy FarmingToken
  /// @return fId newly created farm's id
  function addFarm(
    address poolAddress,
    RangeInput[] calldata ranges,
    PhaseInput calldata phase,
    bool isUsingToken
  ) external returns (uint256 fId);
}

contract AddFarm is Script {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

    address elasticPool = 0xA852DDD69C13d42669840A692f6bBf94245ac54A;
    address farmSC = 0xbb62F365ECffbaca1d255Eed77c60c70F840f6E2;
    address rwToken1 = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address rwToken2 = 0xFbBd93fC3BE8B048c007666AF4846e4A36BACC95;
    uint32 st = 1_686_214_800;
    uint32 et = 1_686_391_200;

    vm.startBroadcast(deployerPrivateKey);

    IELM2 sc = IELM2(farmSC);

    IELM2.RangeInput[] memory r = new IELM2User.RangeInput[](1);
    r[0] = IELM2User.RangeInput({tickLower: -283_260, tickUpper: -273_700, weight: 1});

    IELM2.RewardInput[] memory rw = new IELM2User.RewardInput[](2);
    rw[0] = IELM2User.RewardInput({rewardToken: rwToken1, rewardAmount: 5 ether});
    rw[1] = IELM2User.RewardInput({rewardToken: rwToken2, rewardAmount: 5 ether});

    IELM2.PhaseInput memory p = IELM2User.PhaseInput({startTime: st, endTime: et, rewards: rw});

    sc.addFarm(elasticPool, r, p, true);
    vm.stopBroadcast();
  }
}
