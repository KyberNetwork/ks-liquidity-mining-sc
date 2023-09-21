// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IKSFairLaunchV3 {
  error NotAllowed();
  error InvalidTimes();
  error InvalidPoolState();
  error InvalidLength();
  error InvalidPool();
  error InsufficientAmount();
  error TransferFail();

  struct UserRewardData {
    uint256 unclaimedReward;
    uint256 lastRewardPerShare;
  }

  struct UserInfo {
    uint256 amount; // How many Staking tokens the user has provided.
    mapping(uint256 => UserRewardData) userRewardData;
  }
  //
  // Basically, any point in time, the amount of reward token
  // entitled to a user but is pending to be distributed is:
  //
  //   pending reward = user.unclaimAmount + (user.amount * (pool.accRewardPerShare - user.lastRewardPerShare)
  //
  // Whenever a user deposits or withdraws Staking tokens to a pool. Here's what happens:
  //   1. The pool's `accRewardPerShare` (and `lastRewardTime`) gets updated.
  //   2. User receives the pending reward sent to his/her address.
  //   3. User's `lastRewardPerShare` gets updated.
  //   4. User's `amount` gets updated.

  struct PoolRewardData {
    address rewardToken;
    uint256 multiplier;
    uint256 rewardPerSecond;
    uint256 accRewardPerShare;
  }

  // Info of each pool
  // poolRewardData: reward data for each reward token
  //      rewardToken: reward token for pool
  //      multiplier: multiplier for token decimal.
  //      rewardPerSecond: amount of reward token per second
  //      accRewardPerShare: accumulated reward per share of token
  // totalStake: total amount of stakeToken has been staked
  // stakeToken: token to stake, should be the DMM-LP token
  // generatedToken: token that has been deployed for this pool
  // startTime: the time that the reward starts
  // endTime: the time that the reward ends
  // lastRewardTime: last time that rewards distribution occurs
  struct PoolInfo {
    uint256 totalStake;
    address stakeToken;
    address generatedToken;
    uint32 startTime;
    uint32 endTime;
    uint32 lastRewardTime;
    PoolRewardData[] poolRewards;
  }

  event AddNewPool(
    address indexed stakeToken,
    address indexed generatedToken,
    uint32 startTime,
    uint32 endTime
  );
  event RenewPool(uint256 indexed pid, uint32 startTime, uint32 endTime);
  event UpdatePool(uint256 indexed pid, uint32 endTime);
  event Deposit(address indexed user, uint256 indexed pid, uint256 timestamp, uint256 amount);
  event Withdraw(address indexed user, uint256 indexed pid, uint256 timestamp, uint256 amount);
  event Harvest(
    address indexed user,
    uint256 indexed pid,
    address indexed rewardToken,
    uint256 lockedAmount,
    uint256 timestamp
  );
  event EmergencyWithdraw(
    address indexed user,
    uint256 indexed pid,
    uint256 timestamp,
    uint256 amount
  );

  function deposit(uint256 pId, uint256 amount, bool shouldHarvest) external;

  function withdraw(uint256 pId, uint256 _amount) external;

  function withdrawAll(uint256 pId) external;

  function emergencyWithdraw(uint256 pId) external;

  function harvestMultiplePools(uint256[] calldata pIds) external;

  function harvest(uint256 pId) external;

  function updatePoolRewards(uint256 pId) external;

  function getPoolInfo(
    uint256 pId
  )
    external
    view
    returns (
      uint256 totalStake,
      address stakeToken,
      address generatedToken,
      uint32 startTime,
      uint32 endTime,
      uint32 lastRewardTime,
      address[] memory rewardTokens,
      uint256[] memory multipliers,
      uint256[] memory rewardPerSeconds,
      uint256[] memory accRewardPerShares
    );

  function getUserInfo(
    uint256 pId,
    address account
  )
    external
    view
    returns (
      uint256 amount,
      uint256[] memory unclaimedRewards,
      uint256[] memory lastRewardPerShares
    );

  function pendingRewards(
    uint256 pId,
    address userAddr
  ) external view returns (uint256[] memory rewards);

  function poolLength() external view returns (uint256);
}
