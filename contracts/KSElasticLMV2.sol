//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {ReentrancyGuard} from '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

import {LMMath} from 'contracts/libraries/LMMath.sol';
import {KSAdmin} from 'contracts/base/KSAdmin.sol';

import {IKSElasticLMV2} from 'contracts/interfaces/IKSElasticLMV2.sol';
import {IBasePositionManager} from 'contracts/interfaces/IBasePositionManager.sol';
import {IPoolStorage} from 'contracts/interfaces/IPoolStorage.sol';
import {IKSElasticLMHelper} from 'contracts/interfaces/IKSElasticLMHelper.sol';
import {IKyberSwapFarmingToken} from 'contracts/interfaces/periphery/IKyberSwapFarmingToken.sol';

contract KSElasticLMV2 is IKSElasticLMV2, KSAdmin, ReentrancyGuard {
  using EnumerableSet for EnumerableSet.UintSet;

  address private constant ETH_ADDRESS = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

  IERC721 private immutable nft;
  IKSElasticLMHelper private helper;
  address public immutable weth;

  bytes private farmingTokenCreationCode;
  mapping(uint256 => FarmInfo) private farms; // fId => FarmInfo
  mapping(uint256 => StakeInfo) private stakes; // sId => stakeInfo
  mapping(address => EnumerableSet.UintSet) private depositNFTs;

  uint256 public farmCount;
  bool public emergencyEnabled;

  constructor(IERC721 _nft, IKSElasticLMHelper _helper) {
    nft = _nft;
    helper = _helper;
    weth = IBasePositionManager(address(_nft)).WETH();
  }

  receive() external payable {}

  // ======== admin ============

  //enable emergency mode
  function updateEmergency(bool enableOrDisable) external isAdmin {
    emergencyEnabled = enableOrDisable;

    emit UpdateEmergency(enableOrDisable);
  }

  //update farming token creationCode, use to deploy when add farm
  function updateTokenCode(bytes memory _farmingTokenCreationCode) external isAdmin {
    farmingTokenCreationCode = _farmingTokenCreationCode;

    emit UpdateTokenCode(_farmingTokenCreationCode);
  }

  //update helper contract, use to gather information from elastic
  function updateHelper(IKSElasticLMHelper _helper) external isAdmin {
    helper = _helper;

    emit UpdateHelper(_helper);
  }

  //withdraw leftover rewards from contract
  function withdrawUnusedRewards(
    address[] calldata tokens,
    uint256[] calldata amounts
  ) external isAdmin {
    uint256 rewardTokenLength = tokens.length;
    for (uint256 i; i < rewardTokenLength; ) {
      _safeTransfer(tokens[i], msg.sender, amounts[i]);
      emit WithdrawUnusedRewards(tokens[i], amounts[i], msg.sender);

      unchecked {
        ++i;
      }
    }
  }

  //add a new farm
  function addFarm(
    address poolAddress,
    RangeInput[] calldata ranges,
    PhaseInput calldata phase,
    bool isUsingToken
  ) external isOperator returns (uint256 fId) {
    //new farm id would be current farmCount
    fId = farmCount;
    FarmInfo storage farm = farms[fId];

    //validate phase input
    _isPhaseValid(phase);

    for (uint256 i; i < ranges.length; ) {
      //validate range input
      _isRangeValid(ranges[i]);

      //push range into farm ranges array
      farm.ranges.push(
        IKSElasticLMV2.RangeInfo({
          tickLower: ranges[i].tickLower,
          tickUpper: ranges[i].tickUpper,
          weight: ranges[i].weight,
          isRemoved: false
        })
      );

      unchecked {
        ++i;
      }
    }

    //update farm data
    farm.poolAddress = poolAddress;
    farm.phase.startTime = phase.startTime;
    farm.phase.endTime = phase.endTime;

    for (uint256 i; i < phase.rewards.length; ) {
      //push rewards info to farm phase rewards array
      farm.phase.rewards.push(phase.rewards[i]);

      //sumReward of newly created farm would be, this sumReward is total reward per liquidity until now
      farm.sumRewardPerLiquidity.push(0);

      unchecked {
        ++i;
      }
    }

    //deploy farmingToken if needed
    address destination;
    if (isUsingToken) {
      bytes memory creationCode = abi.encodePacked(
        farmingTokenCreationCode,
        abi.encode(msg.sender)
      );
      bytes32 salt = keccak256(abi.encode(msg.sender, fId));
      assembly {
        destination := create2(0, add(creationCode, 32), mload(creationCode), salt)
        if iszero(extcodesize(destination)) {
          revert(0, 0)
        }
      }
      farm.farmingToken = destination;
    }

    //last touched time would be startTime
    farm.lastTouchedTime = phase.startTime;

    //increase farmCount
    unchecked {
      ++farmCount;
    }

    emit AddFarm(fId, poolAddress, ranges, phase, destination);
  }

  function addPhase(uint256 fId, PhaseInput calldata phaseInput) external isOperator {
    if (fId >= farmCount) revert InvalidFarm();

    //validate phase input
    _isPhaseValid(phaseInput);

    PhaseInfo storage phase = farms[fId].phase;

    uint256 length = phase.rewards.length;
    if (phaseInput.rewards.length != length) revert InvalidInput();

    //if phase not settled, update sumReward.
    //if phase already settled then it's not needed since sumReward would be unchanged
    if (block.timestamp > farms[fId].lastTouchedTime && !phase.isSettled)
      _updateFarmSumRewardPerLiquidity(fId);

    //override phase data with new data
    phase.startTime = phaseInput.startTime;
    phase.endTime = phaseInput.endTime;

    for (uint256 i; i < length; ) {
      //new phase rewards must be the same as old phase
      if (phase.rewards[i].rewardToken != phaseInput.rewards[i].rewardToken)
        revert InvalidReward();

      //update reward amounts
      phase.rewards[i].rewardAmount = phaseInput.rewards[i].rewardAmount;

      unchecked {
        ++i;
      }
    }

    //newly add phase must is not settled
    if (phase.isSettled) phase.isSettled = false;

    //set farm lastTouchedTime to startTime
    farms[fId].lastTouchedTime = phaseInput.startTime;

    emit AddPhase(fId, phaseInput);
  }

  function forceClosePhase(uint256 fId) external isOperator {
    if (fId >= farmCount) revert InvalidFarm();

    if (farms[fId].phase.isSettled) revert PhaseSettled();

    //update sumReward if time passes
    if (block.timestamp > farms[fId].lastTouchedTime) _updateFarmSumRewardPerLiquidity(fId);

    //close phase so settled must be true
    if (!farms[fId].phase.isSettled) farms[fId].phase.isSettled = true;

    emit ForceClosePhase(fId);
  }

  function addRange(uint256 fId, RangeInput calldata range) external isOperator {
    if (fId >= farmCount) revert InvalidFarm();
    _isRangeValid(range);

    //add a new range into farm ranges array
    farms[fId].ranges.push(
      IKSElasticLMV2.RangeInfo({
        tickLower: range.tickLower,
        tickUpper: range.tickUpper,
        weight: range.weight,
        isRemoved: false
      })
    );

    emit AddRange(fId, range);
  }

  function removeRange(uint256 fId, uint256 rangeId) external isOperator {
    if (fId >= farmCount) revert InvalidFarm();
    if (rangeId >= farms[fId].ranges.length || farms[fId].ranges[rangeId].isRemoved)
      revert RangeNotFound();

    //remove a range aka set isRemoved to false, it's still be in ranges array but cannot deposit to this range anymore
    farms[fId].ranges[rangeId].isRemoved = true;

    emit RemoveRange(fId, rangeId);
  }

  // ======== user ============
  /// @inheritdoc IKSElasticLMV2
  function deposit(
    uint256 fId,
    uint256 rangeId,
    uint256[] calldata nftIds,
    address receiver
  ) external override nonReentrant {
    _isAddLiquidityValid(fId, rangeId);

    //check positions meet farm requirements
    (bool isInvalid, uint128[] memory nftLiquidities) = _checkPosition(
      farms[fId].poolAddress,
      farms[fId].ranges[rangeId].tickLower,
      farms[fId].ranges[rangeId].tickUpper,
      nftIds
    );

    if (isInvalid) revert PositionNotEligible();

    //calculate lastest farm sumReward
    uint256[] memory curSumRewardPerLiquidity = _updateFarmSumRewardPerLiquidity(fId);
    uint32 weight = farms[fId].ranges[rangeId].weight;
    uint256 rewardLength = farms[fId].phase.rewards.length;
    uint256 totalLiquidity;

    //loop through list nftLength
    for (uint256 i; i < nftIds.length; ) {
      uint256 liquidityWithWeight = nftLiquidities[i];
      liquidityWithWeight = liquidityWithWeight * weight;

      //transfer nft to farm, add to list deposited nfts
      nft.transferFrom(msg.sender, address(this), nftIds[i]);
      if (!depositNFTs[receiver].add(nftIds[i])) revert FailToAdd();

      //create stake info
      StakeInfo storage stake = stakes[nftIds[i]];
      stake.owner = receiver;
      stake.fId = fId;
      stake.rangeId = rangeId;
      stake.liquidity = liquidityWithWeight;

      for (uint256 j; j < rewardLength; ) {
        stakes[nftIds[i]].lastSumRewardPerLiquidity.push(curSumRewardPerLiquidity[j]);
        stakes[nftIds[i]].rewardUnclaimed.push(0);

        unchecked {
          ++j;
        }
      }

      totalLiquidity += liquidityWithWeight;

      unchecked {
        ++i;
      }
    }

    //update farm total liquidity
    farms[fId].liquidity += totalLiquidity;

    //mint farmingToken equals to stake liquidity
    address farmingToken = farms[fId].farmingToken;
    if (farmingToken != address(0)) _mintFarmingToken(farmingToken, receiver, totalLiquidity);

    emit Deposit(fId, rangeId, nftIds, msg.sender, receiver);
  }

  /// @inheritdoc IKSElasticLMV2
  function claimReward(uint256 fId, uint256[] calldata nftIds) external override nonReentrant {
    _claimReward(fId, nftIds, msg.sender);
  }

  /// @inheritdoc IKSElasticLMV2
  function withdraw(uint256 fId, uint256[] calldata nftIds) external override nonReentrant {
    _claimReward(fId, nftIds, msg.sender);

    uint256 length = nftIds.length;
    uint256 totalLiq;

    //loop through list nfts
    for (uint256 i; i < length; ) {
      totalLiq += stakes[nftIds[i]].liquidity;

      //remove stake
      delete stakes[nftIds[i]];
      if (!depositNFTs[msg.sender].remove(nftIds[i])) revert FailToRemove();

      //transfer back nft to user
      nft.transferFrom(address(this), msg.sender, nftIds[i]);

      unchecked {
        ++i;
      }
    }

    //update farm total liquidity
    farms[fId].liquidity -= totalLiq;

    //burn an a mount of farmingToken from msg.sender
    if (farms[fId].farmingToken != address(0))
      _burnFarmingToken(farms[fId].farmingToken, msg.sender, totalLiq);

    emit Withdraw(nftIds, msg.sender);
  }

  /// @inheritdoc IKSElasticLMV2
  function addLiquidity(
    uint256 fId,
    uint256 rangeId,
    uint256[] memory nftIds
  ) external override nonReentrant {
    _isAddLiquidityValid(fId, rangeId);

    uint256 length = nftIds.length;
    uint32 weight = farms[fId].ranges[rangeId].weight;

    for (uint256 i; i < length; ) {
      _isStakeValidForAddLiquidity(fId, rangeId, nftIds[i]);

      //get liq from elastic
      uint256 posLiq = _getLiquidity(nftIds[i]);
      uint256 curLiq = stakes[nftIds[i]].liquidity;
      uint256 newLiq = posLiq * weight;

      //only update stake liquidity if newLiq > curLiq, ignore if liquidity is the same
      if (newLiq > curLiq) _updateLiquidity(fId, nftIds[i], newLiq, msg.sender);

      unchecked {
        ++i;
      }
    }
  }

  /// @inheritdoc IKSElasticLMV2
  function removeLiquidity(
    uint256 nftId,
    uint128 liquidity,
    uint256 amount0Min,
    uint256 amount1Min,
    uint256 deadline,
    bool isClaimFee,
    bool isReceiveNative
  ) external override nonReentrant {
    if (block.timestamp > deadline) revert Expired();
    if (stakes[nftId].owner != msg.sender) revert NotOwner();

    //get liq from elastic
    uint256 posLiq = _getLiquidity(nftId);
    if (liquidity == 0 || liquidity > posLiq) revert InvalidInput();

    //call to posManager to remove liquidity for position, also claim lp fee if needed
    _removeLiquidity(nftId, liquidity, deadline);
    if (isClaimFee) _claimFee(nftId, deadline, false);

    //calculate new liquidity after remove
    posLiq = posLiq - liquidity;

    uint256 fId = stakes[nftId].fId;
    uint256 curLiq = stakes[nftId].liquidity;
    uint256 newLiq = posLiq * farms[fId].ranges[stakes[nftId].rangeId].weight;

    //update liquidity if new liquidity < cur liquidity, ignore case where new liquidity >= cur liquidity
    if (newLiq < curLiq) _updateLiquidity(fId, nftId, newLiq, msg.sender);

    //transfer tokens from posManager to user
    _transferTokens(farms[fId].poolAddress, amount0Min, amount1Min, msg.sender, isReceiveNative);
  }

  /// @inheritdoc IKSElasticLMV2
  function claimFee(
    uint256 fId,
    uint256[] calldata nftIds,
    uint256 amount0Min,
    uint256 amount1Min,
    uint256 deadline,
    bool isReceiveNative
  ) external override nonReentrant {
    if (block.timestamp > deadline) revert Expired();

    uint256 length = nftIds.length;
    for (uint256 i; i < length; ) {
      _isStakeValid(fId, nftIds[i]);

      //call to posManager to claim fee
      _claimFee(nftIds[i], deadline, true);

      unchecked {
        ++i;
      }
    }

    //transfer tokens from posManager to user
    _transferTokens(farms[fId].poolAddress, amount0Min, amount1Min, msg.sender, isReceiveNative);
  }

  /// @inheritdoc IKSElasticLMV2
  function withdrawEmergency(uint256[] calldata nftIds) external override {
    uint256 length = nftIds.length;
    for (uint256 i; i < length; ) {
      uint256 nftId = nftIds[i];
      StakeInfo memory stake = stakes[nftId];

      if (stake.owner != msg.sender) revert NotOwner();

      //if emerency mode is not enable
      if (!emergencyEnabled) {
        address farmingToken = farms[stake.fId].farmingToken;
        uint256 liquidity = stake.liquidity;

        //burn farmingToken from msg.sender if stake liquidity greater than 0
        if (farmingToken != address(0) && liquidity != 0)
          _burnFarmingToken(farmingToken, stake.owner, liquidity);

        //remove nft from deposited nft list
        if (!depositNFTs[stake.owner].remove(nftId)) revert FailToRemove();

        //update farm total liquidity
        farms[stake.fId].liquidity -= liquidity;
      }

      //remove stake and transfer back nft to user, always do this even emergency enable or disable
      delete stakes[nftId];
      nft.transferFrom(address(this), stake.owner, nftId);

      emit WithdrawEmergency(nftId, stake.owner);

      unchecked {
        ++i;
      }
    }
  }

  // ======== getter ============
  function getAdmin() external view override returns (address) {
    return admin;
  }

  function getNft() external view override returns (IERC721) {
    return nft;
  }

  function getFarm(
    uint256 fId
  )
    external
    view
    override
    returns (
      address poolAddress,
      RangeInfo[] memory ranges,
      PhaseInfo memory phase,
      uint256 liquidity,
      address farmingToken,
      uint256[] memory sumRewardPerLiquidity,
      uint32 lastTouchedTime
    )
  {
    return (
      farms[fId].poolAddress,
      farms[fId].ranges,
      farms[fId].phase,
      farms[fId].liquidity,
      farms[fId].farmingToken,
      farms[fId].sumRewardPerLiquidity,
      farms[fId].lastTouchedTime
    );
  }

  function getDepositedNFTs(address user) external view returns (uint256[] memory listNFTs) {
    listNFTs = depositNFTs[user].values();
  }

  function getStake(
    uint256 nftId
  )
    external
    view
    override
    returns (
      address owner,
      uint256 fId,
      uint256 rangeId,
      uint256 liquidity,
      uint256[] memory lastSumRewardPerLiquidity,
      uint256[] memory rewardUnclaimed
    )
  {
    return (
      stakes[nftId].owner,
      stakes[nftId].fId,
      stakes[nftId].rangeId,
      stakes[nftId].liquidity,
      stakes[nftId].lastSumRewardPerLiquidity,
      stakes[nftId].rewardUnclaimed
    );
  }

  // ======== internal ============
  /// @dev claim reward for nfts
  /// @param fId farm's id
  /// @param nftIds nfts for claim reward
  /// @param receiver reward receiver also msgSender
  function _claimReward(uint256 fId, uint256[] memory nftIds, address receiver) internal {
    uint256 nftLength = nftIds.length;

    //validate list of nft valid or not
    for (uint256 i; i < nftLength; ) {
      _isStakeValid(fId, nftIds[i]);
      unchecked {
        ++i;
      }
    }

    //update rewards for all nfts
    _updateRewardInfos(fId, nftIds);

    //accumulate rewards from stakes and transfer at once
    uint256 rewardLength = farms[fId].phase.rewards.length;
    uint256[] memory rewardAmounts = new uint256[](rewardLength);
    for (uint256 i; i < nftLength; ) {
      for (uint256 j; j < rewardLength; ) {
        rewardAmounts[j] += stakes[nftIds[i]].rewardUnclaimed[j];
        stakes[nftIds[i]].rewardUnclaimed[j] = 0;

        unchecked {
          ++j;
        }
      }

      unchecked {
        ++i;
      }
    }

    //transfer rewards
    for (uint256 i; i < rewardLength; ) {
      address token = farms[fId].phase.rewards[i].rewardToken;

      if (rewardAmounts[i] != 0) {
        _safeTransfer(token, receiver, rewardAmounts[i]);
      }

      emit ClaimReward(fId, nftIds, token, rewardAmounts[i], receiver);

      unchecked {
        ++i;
      }
    }
  }

  function _updateLiquidity(
    uint256 fId,
    uint256 nftId,
    uint256 newLiq,
    address receiver
  ) internal {
    //update farm sumReward
    uint256[] memory curSumRewardPerLiquidities = _updateFarmSumRewardPerLiquidity(fId);
    uint256 curLiq = stakes[nftId].liquidity;

    //update stake rewards base on lastest sumReward
    _updateRewardInfo(nftId, curLiq, curSumRewardPerLiquidities);

    address farmingToken = farms[fId].farmingToken;

    //mint/burn farmingToken base on the difference between newLiq/curLiq. there is no case that newLiq == curLiq
    if (newLiq > curLiq) {
      _mintFarmingToken(farmingToken, receiver, newLiq - curLiq);
    } else {
      _burnFarmingToken(farmingToken, receiver, curLiq - newLiq);
    }

    //update stake liquidity, farm total liquidity
    stakes[nftId].liquidity = newLiq;
    farms[fId].liquidity = farms[fId].liquidity + newLiq - curLiq;

    emit UpdateLiquidity(fId, nftId, newLiq);
  }

  /// @dev update rewardInfo for multiple stakes
  /// @param nftIds nfts to update
  function _updateRewardInfos(uint256 fId, uint256[] memory nftIds) internal {
    uint256[] memory curSumRewardPerLiquidities = _updateFarmSumRewardPerLiquidity(fId);
    uint256 length = nftIds.length;
    for (uint256 i; i < length; ) {
      _updateRewardInfo(nftIds[i], stakes[nftIds[i]].liquidity, curSumRewardPerLiquidities);

      unchecked {
        ++i;
      }
    }
  }

  /// @dev calculate and update rewardUnclaimed, lastSumRewardPerLiquidity for a single position
  /// @dev rewardAmount = (sumRewardPerLiq - lastSumRewardPerLiq) * stake.liquidiy
  /// @dev if transferRewardUnclaimed =  true then transfer all rewardUnclaimed, update rewardUnclaimed = 0
  /// @dev if transferRewardUnclaimed =  false then update rewardUnclaimed = rewardUnclaimed + rewardAmount
  /// @dev update lastSumRewardPerLiquidity
  /// @param nftId nft's id to update
  /// @param liquidity current staked liquidity
  /// @param curSumRewardPerLiquidities current sumRewardPerLiquidities of farm, indexing by reward
  function _updateRewardInfo(
    uint256 nftId,
    uint256 liquidity,
    uint256[] memory curSumRewardPerLiquidities
  ) internal {
    uint256 length = curSumRewardPerLiquidities.length;
    for (uint256 i; i < length; ) {
      if (liquidity != 0) {
        //calculate rewardAmount by formula rewardAmount = (sumRewardPerLiq - lastSumRewardPerLiq) * stake.liquidiy
        uint256 rewardAmount = LMMath.calcRewardAmount(
          curSumRewardPerLiquidities[i],
          stakes[nftId].lastSumRewardPerLiquidity[i],
          liquidity
        );

        //accumulate reward into stake rewards
        if (rewardAmount != 0) {
          stakes[nftId].rewardUnclaimed[i] += rewardAmount;
        }
      }

      //store new sumReward into stake
      stakes[nftId].lastSumRewardPerLiquidity[i] = curSumRewardPerLiquidities[i];

      unchecked {
        ++i;
      }
    }
  }

  /// @dev update farm's sumRewardPerLiquidity
  /// @dev update farm's lastUpdatedTime
  /// @dev if block.timestamp > farm's endTime then update phase to settled
  /// @param fId farm's id
  /// @return curSumRewardPerLiquidity array of sumRewardPerLiquidity until now
  function _updateFarmSumRewardPerLiquidity(
    uint256 fId
  ) internal returns (uint256[] memory curSumRewardPerLiquidity) {
    uint256 length = farms[fId].phase.rewards.length;
    curSumRewardPerLiquidity = new uint256[](length);

    uint32 lastTouchedTime = farms[fId].lastTouchedTime;
    uint32 endTime = farms[fId].phase.endTime;
    bool isSettled = farms[fId].phase.isSettled;

    for (uint256 i; i < length; ) {
      uint256 preSumRewardPerLiquidity = farms[fId].sumRewardPerLiquidity[i];

      //calculate sumReward from lastTouchedTime until now
      curSumRewardPerLiquidity[i] = _calcSumRewardPerLiquidity(
        farms[fId].phase.rewards[i].rewardAmount,
        farms[fId].phase.startTime,
        endTime,
        lastTouchedTime,
        farms[fId].liquidity,
        isSettled,
        preSumRewardPerLiquidity
      );

      //if there is something changes, update into storage
      if (curSumRewardPerLiquidity[i] != preSumRewardPerLiquidity)
        farms[fId].sumRewardPerLiquidity[i] = curSumRewardPerLiquidity[i];

      unchecked {
        ++i;
      }
    }

    //update farm lastTouchedTime, if passed endTime, update phase to settled
    if (block.timestamp > lastTouchedTime) farms[fId].lastTouchedTime = uint32(block.timestamp);
    if (block.timestamp > endTime && !isSettled) farms[fId].phase.isSettled = true;
  }

  /// @dev get liquidity of nft from helper
  /// @param nftId nft's id
  /// @return liquidity current liquidity of nft
  function _getLiquidity(uint256 nftId) internal view returns (uint128 liquidity) {
    (, , , liquidity) = helper.getPositionInfo(address(nft), nftId);
  }

  /// @dev check multiple nfts it's valid
  /// @param poolAddress pool's address
  /// @param tickLower farm's tickLower
  /// @param tickUpper farm's tickUpper
  /// @param nftIds nfts to check
  function _checkPosition(
    address poolAddress,
    int24 tickLower,
    int24 tickUpper,
    uint256[] calldata nftIds
  ) internal view returns (bool isInvalid, uint128[] memory nftLiquidities) {
    (isInvalid, nftLiquidities) = helper.checkPosition(
      poolAddress,
      address(nft),
      tickLower,
      tickUpper,
      nftIds
    );
  }

  /// @dev remove liquidiy of nft from posManager
  /// @param nftId nft's id
  /// @param liquidity liquidity amount to remove
  /// @param deadline removeLiquidity deadline
  function _removeLiquidity(uint256 nftId, uint128 liquidity, uint256 deadline) internal {
    IBasePositionManager.RemoveLiquidityParams memory removeLiq = IBasePositionManager
      .RemoveLiquidityParams({
        tokenId: nftId,
        liquidity: liquidity,
        amount0Min: 0,
        amount1Min: 0,
        deadline: deadline
      });

    IBasePositionManager(address(nft)).removeLiquidity(removeLiq);
  }

  /// @dev claim fee of nft from posManager
  /// @param nftId nft's id
  /// @param deadline claimFee deadline
  /// @param syncFee is need to sync new fee or not
  function _claimFee(uint256 nftId, uint256 deadline, bool syncFee) internal {
    if (syncFee) {
      IBasePositionManager(address(nft)).syncFeeGrowth(nftId);
    }

    IBasePositionManager.BurnRTokenParams memory burnRToken = IBasePositionManager
      .BurnRTokenParams({tokenId: nftId, amount0Min: 0, amount1Min: 0, deadline: deadline});

    IBasePositionManager(address(nft)).burnRTokens(burnRToken);
  }

  /// @dev transfer tokens from removeLiquidity (and burnRToken if any) to receiver, also unwrap if needed
  /// @param poolAddress address of Elastic Pool
  /// @param amount0Min minimum amount of token0 should receive
  /// @param amount1Min minimum amount of token1 should receive
  /// @param receiver receiver of tokens
  function _transferTokens(
    address poolAddress,
    uint256 amount0Min,
    uint256 amount1Min,
    address receiver,
    bool isReceiveNative
  ) internal {
    address token0 = address(IPoolStorage(poolAddress).token0());
    address token1 = address(IPoolStorage(poolAddress).token1());
    IBasePositionManager posManager = IBasePositionManager(address(nft));

    if (isReceiveNative) {
      // expect to receive in native token
      if (weth == token0) {
        // receive in native for token0
        posManager.unwrapWeth(amount0Min, receiver);
        posManager.transferAllTokens(token1, amount1Min, receiver);
        return;
      }
      if (weth == token1) {
        // receive in native for token1
        posManager.transferAllTokens(token0, amount0Min, receiver);
        posManager.unwrapWeth(amount1Min, receiver);
        return;
      }
    }

    posManager.transferAllTokens(token0, amount0Min, receiver);
    posManager.transferAllTokens(token1, amount1Min, receiver);
  }

  function _safeTransfer(address token, address to, uint256 amount) internal {
    (bool success, ) = token == ETH_ADDRESS
      ? payable(to).call{value: amount}('')
      : token.call(abi.encodeWithSignature('transfer(address,uint256)', to, amount));

    require(success);
  }

  function _mintFarmingToken(address token, address to, uint256 amount) internal {
    IKyberSwapFarmingToken(token).mint(to, amount);
  }

  function _burnFarmingToken(address token, address from, uint256 amount) internal {
    IKyberSwapFarmingToken(token).burn(from, amount);
  }

  /// @dev calculate sumRewardPerLiquidity for each reward token
  /// @dev if block.timestamp > lastTouched means sumRewardPerLiquidity had increase
  /// @dev if not then just return it
  /// @param rewardAmount rewardAmount to calculate
  /// @param startTime farm's startTime
  /// @param endTime farm's endTime
  /// @param lastTouchedTime farm's lastTouchedTime
  /// @param totalLiquidity farm's total liquidity
  /// @param isSettled farm phase is settled or not
  /// @return sumRewardPerLiquidity until now
  function _calcSumRewardPerLiquidity(
    uint256 rewardAmount,
    uint32 startTime,
    uint32 endTime,
    uint32 lastTouchedTime,
    uint256 totalLiquidity,
    bool isSettled,
    uint256 currentSumRewardPerLiquidity
  ) internal view returns (uint256) {
    if (block.timestamp > lastTouchedTime && totalLiquidity != 0 && !isSettled) {
      uint256 deltaSumRewardPerLiquidity = LMMath.calcSumRewardPerLiquidity(
        rewardAmount,
        startTime,
        endTime,
        uint32(block.timestamp),
        lastTouchedTime,
        totalLiquidity
      );

      currentSumRewardPerLiquidity += deltaSumRewardPerLiquidity;
    }

    return currentSumRewardPerLiquidity;
  }

  /// @dev check if range is valid to be add to farm, revert on fail
  /// @param range range to check
  function _isRangeValid(RangeInput memory range) internal pure {
    if (range.tickLower > range.tickUpper || range.weight == 0) revert InvalidRange();
  }

  /// @dev check if phase is valid to be add to farm, revert on fail
  function _isPhaseValid(PhaseInput memory phase) internal view {
    if (phase.startTime < block.timestamp || phase.endTime <= phase.startTime)
      revert InvalidTime();

    if (phase.rewards.length == 0) revert InvalidReward();
  }

  /// @dev check if add liquidity conditions are meet or not, revert on fail
  /// @param fId farm's id
  function _isAddLiquidityValid(uint256 fId, uint256 rangeId) internal view {
    if (fId >= farmCount) revert FarmNotFound();
    if (rangeId >= farms[fId].ranges.length || farms[fId].ranges[rangeId].isRemoved)
      revert RangeNotFound();
    if (farms[fId].phase.endTime < block.timestamp || farms[fId].phase.isSettled)
      revert PhaseSettled();
    if (emergencyEnabled) revert EmergencyEnabled();
  }

  /// @dev check if stake update conditions are meet or not, revert on fail
  ///   check if the caller is the owner of the NFT and the stake data is valid
  /// @param fId farm's id
  /// @param nftId the NFT's id
  function _isStakeValid(uint256 fId, uint256 nftId) internal view {
    if (stakes[nftId].owner != msg.sender) revert NotOwner();
    if (stakes[nftId].fId != fId) revert StakeNotFound();
  }

  /// @dev check if stake add liquidity conditions are meet or not, revert on fail
  /// @param fId farm's id
  /// @param rangeId range's id
  /// @param nftId NFT's id
  function _isStakeValidForAddLiquidity(
    uint256 fId,
    uint256 rangeId,
    uint256 nftId
  ) internal view {
    _isStakeValid(fId, nftId);
    if (stakes[nftId].rangeId != rangeId) revert RangeNotMatch();
  }
}
