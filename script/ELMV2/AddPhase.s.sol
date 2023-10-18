// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import 'forge-std/Script.sol';
import {IKSElasticLMV2 as IELM2User} from 'contracts/interfaces/IKSElasticLMV2.sol';

interface IELM2 is IELM2User {
  function addPhase(uint256 fId, PhaseInput calldata phaseInput) external;
}

contract AddPhase is Script {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

    uint256 fId = 0;
    address farmSC = 0xbb62F365ECffbaca1d255Eed77c60c70F840f6E2;
    address rwToken1 = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 rewardAmount1 = 10_000_000_000_000_000_000;
    address rwToken2 = 0xFbBd93fC3BE8B048c007666AF4846e4A36BACC95;
    uint256 rewardAmount2 = 1_000_000_000_000_000_000_000;
    uint32 st = 1_686_561_163;
    uint32 et = 1_687_770_763;

    vm.startBroadcast(deployerPrivateKey);

    IELM2 sc = IELM2(farmSC);

    IELM2.RewardInput[] memory rw = new IELM2User.RewardInput[](2);
    rw[0] = IELM2User.RewardInput({rewardToken: rwToken1, rewardAmount: rewardAmount1});
    rw[1] = IELM2User.RewardInput({rewardToken: rwToken2, rewardAmount: rewardAmount2});

    IELM2.PhaseInput memory p = IELM2User.PhaseInput({startTime: st, endTime: et, rewards: rw});

    sc.addPhase(fId, p);
    vm.stopBroadcast();
  }
}
