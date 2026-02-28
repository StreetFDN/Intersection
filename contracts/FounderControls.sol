// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "./interfaces/IPool.sol";

/// @title FounderControls
/// @notice Optional per-pool controls for startup founders (pause, volume limit, float limit).
/// @dev Not enforced by Pool.sol unless a pool or router is wired to call checkSwap.
contract FounderControls is Ownable {
    error InvalidBps();
    error NotFounder();
    error ZeroAddress();

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
        if (pool == address(0) || founder == address(0)) revert ZeroAddress();
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

    /// @notice Check if swap is allowed for this pool (pause + daily volume + float limit).
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

        // Float limit: check that pool reserves don't exceed maxFloatBps of each token's total supply
        uint256 _maxFloatBps = maxFloatBps[pool];
        if (_maxFloatBps > 0) {
            address token0 = IPool(pool).token0();
            address token1 = IPool(pool).token1();
            uint256 reserve0 = IERC20(token0).balanceOf(pool);
            uint256 reserve1 = IERC20(token1).balanceOf(pool);
            uint256 supply0 = IERC20(token0).totalSupply();
            uint256 supply1 = IERC20(token1).totalSupply();
            if (supply0 > 0 && reserve0 * 10_000 > _maxFloatBps * supply0) return false;
            if (supply1 > 0 && reserve1 * 10_000 > _maxFloatBps * supply1) return false;
        }

        return true;
    }
}
