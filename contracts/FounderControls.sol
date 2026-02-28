// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title FounderControls
/// @notice Optional per-pool controls for startup founders (pause, volume limit, float limit).
/// @dev Not enforced by Pool.sol unless a pool or router is wired to call checkSwap.
contract FounderControls is Ownable {
    error InvalidBps();
    error NotFounder();

    /// @notice Founder address per pool (set by owner)
    mapping(address => address) public poolFounders;

    /// @notice Circuit breaker: pause trading for a pool
    mapping(address => bool) public paused;

    /// @notice Max % of token supply that can be in pool (basis points, 0 = no limit)
    mapping(address => uint256) public maxFloatBps;

    /// @notice Max daily volume (output amount) per pool (0 = no limit)
    mapping(address => uint256) public maxDailyVolume;
    mapping(address => uint256) public dailyVolume;
    mapping(address => uint256) public lastVolumeReset;

    event PoolPaused(address indexed pool, bool status);
    event FloatLimitSet(address indexed pool, uint256 maxBps);
    event VolumeLimitSet(address indexed pool, uint256 maxVolume);
    event FounderRegistered(address indexed pool, address indexed founder);

    modifier onlyFounder(address pool) {
        if (msg.sender != poolFounders[pool]) revert NotFounder();
        _;
    }

    constructor() Ownable() {}

    /// @notice Register pool founder (only owner).
    function registerFounder(address pool, address founder) external onlyOwner {
        poolFounders[pool] = founder;
        emit FounderRegistered(pool, founder);
    }

    /// @notice Pause or unpause pool trading (only that pool's founder).
    function setPaused(address pool, bool _paused) external onlyFounder(pool) {
        paused[pool] = _paused;
        emit PoolPaused(pool, _paused);
    }

    /// @notice Set maximum float as % of supply in pool, basis points (only founder).
    function setMaxFloat(address pool, uint256 maxBps) external onlyFounder(pool) {
        if (maxBps > 10_000) revert InvalidBps();
        maxFloatBps[pool] = maxBps;
        emit FloatLimitSet(pool, maxBps);
    }

    /// @notice Set maximum daily volume (output amount) for pool (only founder).
    function setMaxDailyVolume(address pool, uint256 maxVolume) external onlyFounder(pool) {
        maxDailyVolume[pool] = maxVolume;
        emit VolumeLimitSet(pool, maxVolume);
    }

    /// @notice Check if swap is allowed for this pool (pause + daily volume).
    /// @param pool Pool address
    /// @param amountOut Output amount of the swap (used for volume accounting)
    /// @return true if swap allowed
    function checkSwap(address pool, uint256 amountOut) external returns (bool) {
        if (paused[pool]) return false;

        if (maxDailyVolume[pool] > 0) {
            if (block.timestamp >= lastVolumeReset[pool] + 1 days) {
                dailyVolume[pool] = 0;
                lastVolumeReset[pool] = block.timestamp;
            }
            dailyVolume[pool] += amountOut;
            if (dailyVolume[pool] > maxDailyVolume[pool]) return false;
        }

        // Float limit would require pool supply + token totalSupply - not implemented here
        return true;
    }
}
