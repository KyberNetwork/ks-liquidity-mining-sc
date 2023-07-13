// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {IKyberSwapFarmingToken} from './periphery/IKyberSwapFarmingToken.sol';
import {IKSElasticLMHelper} from './IKSElasticLMHelper.sol';

interface IKSElasticLMV2 {
  error Forbidden();
  error EmergencyEnabled();

  error InvalidRange();
  error InvalidTime();
  error InvalidReward();

  error PositionNotEligible();
  error FarmNotFound();
  error InvalidFarm();
  error NotOwner();
  error StakeNotFound();
  error RangeNotMatch();
  error RangeNotFound();
  error PhaseSettled();
  error InvalidInput();
  error LiquidityNotMatch();
  error FailToAdd();
  error FailToRemove();
  error Expired();

  event UpdateEmergency(bool enableOrDisable);
  event UpdateTokenCode(bytes farmingTokenCode);
  event UpdateHelper(IKSElasticLMHelper helper);
  event WithdrawUnusedRewards(address token, uint256 amount, address receiver);

  event AddFarm(
    uint256 indexed fId,
    address poolAddress,
    RangeInput[] ranges,
    PhaseInput phase,
    address farmingToken
  );
  event AddPhase(uint256 indexed fId, PhaseInput phase);
  event ForceClosePhase(uint256 indexed fId);
  event AddRange(uint256 indexed fId, RangeInput range);
  event RemoveRange(uint256 indexed fId, uint256 rangeId);
  event ExpandEndTimeAndRewards(uint256 indexed fId, uint256 duration, uint256[] rewardAmounts);

  event Deposit(
    uint256 indexed fId,
    uint256 rangeId,
    uint256[] nftIds,
    address indexed depositer,
    address receiver
  );
  event UpdateLiquidity(uint256 indexed fId, uint256 nftId, uint256 liquidity);
  event Withdraw(uint256[] nftIds, address receiver);
  event WithdrawEmergency(uint256 nftId, address receiver);
  event ClaimReward(
    uint256 fId,
    uint256[] nftIds,
    address token,
    uint256 amount,
    address receiver
  );

  struct RangeInput {
    int24 tickLower;
    int24 tickUpper;
    uint32 weight;
  }

  struct RewardInput {
    address rewardToken;
    uint256 rewardAmount;
  }

  struct PhaseInput {
    uint32 startTime;
    uint32 endTime;
    RewardInput[] rewards;
  }

  struct RemoveLiquidityInput {
    uint256 nftId;
    uint128 liquidity;
  }

  struct RangeInfo {
    int24 tickLower;
    int24 tickUpper;
    uint32 weight;
    bool isRemoved;
  }

  struct PhaseInfo {
    uint32 startTime;
    uint32 endTime;
    bool isSettled;
    RewardInput[] rewards;
  }

  struct FarmInfo {
    address poolAddress;
    RangeInfo[] ranges;
    PhaseInfo phase;
    uint256 liquidity;
    address farmingToken;
    uint256[] sumRewardPerLiquidity;
    uint32 lastTouchedTime;
  }

  struct StakeInfo {
    address owner;
    uint256 fId;
    uint256 rangeId;
    uint256 liquidity;
    uint256[] lastSumRewardPerLiquidity;
    uint256[] rewardUnclaimed;
  }

  // ======== operator ============

  /// @dev add a new farm
  /// @dev can be done only by operator
  /// @dev will emit event AddFarm
  /// @param poolAddress elastic pool address of this farm
  /// @param ranges init ranges of this farm, refer RangeInput struct above
  /// @param phase init phase of this farm, refer to PhaseInput struct above
  /// @param isUsingToken set this to true to deploy a erc20 contract called farming token
  /// @return fId newly created farm's id
  function addFarm(
    address poolAddress,
    RangeInput[] calldata ranges,
    PhaseInput calldata phase,
    bool isUsingToken
  ) external returns (uint256 fId);

  /// @dev add a new phase to a farm
  /// @dev new phase will close the old phase if it still running
  /// @dev will emit event AddPhase
  /// @param fId id of farm to add phase to
  /// @param phaseInput new phase to add, refer to PhaseInput struct above
  function addPhase(uint256 fId, PhaseInput calldata phaseInput) external;

  /// @dev close a running phase of a farm
  /// @dev will emit event ForceClosePhase
  /// @param fId to close phase
  function forceClosePhase(uint256 fId) external;

  /// @dev add a new range to a farm
  /// @dev will emit event AddRange
  /// @param fId id of farm to add range to
  /// @param range new range to add, refer to RangeInput struct above
  function addRange(uint256 fId, RangeInput calldata range) external;

  /// @dev remove a range from farm
  /// @dev this will marked range isRemove to true
  /// @dev will emit event removeRange
  /// @param fId id of farm to remove range from
  /// @param rangeId id of range to remove
  function removeRange(uint256 fId, uint256 rangeId) external;

  // ======== view ============
  function getNft() external view returns (IERC721);

  function getFarm(
    uint256 fId
  )
    external
    view
    returns (
      address poolAddress,
      RangeInfo[] memory ranges,
      PhaseInfo memory phase,
      uint256 liquidity,
      address farmingToken,
      uint256[] memory sumRewardPerLiquidity,
      uint32 lastTouchedTime
    );

  function getDepositedNFTs(address user) external view returns (uint256[] memory listNFTs);

  function getStake(
    uint256 nftId
  )
    external
    view
    returns (
      address owner,
      uint256 fId,
      uint256 rangeId,
      uint256 liquidity,
      uint256[] memory lastSumRewardPerLiquidity,
      uint256[] memory rewardUnclaimeds
    );
}
