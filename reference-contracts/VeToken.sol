// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract VeToken {
    IERC20 public immutable underlying;

    uint256 public immutable maxLockTime; // e.g. 4 years
    uint256 public constant WEEK = 7 days;

    struct Lock {
        uint128 amount;      // locked underlying
        uint64 unlockTime;   // timestamp
    }

    mapping(address => Lock) public locks;

    event LockCreated(address indexed user, uint256 amount, uint256 unlockTime);
    event AmountIncreased(address indexed user, uint256 amountAdded);
    event UnlockTimeExtended(address indexed user, uint256 newUnlockTime);
    event Withdrawn(address indexed user, uint256 amount);

    constructor(address underlying_, uint256 maxLockTime_) {
        require(underlying_ != address(0), "underlying=0");
        require(maxLockTime_ > 0, "maxLockTime=0");
        underlying = IERC20(underlying_);
        maxLockTime = maxLockTime_;
    }

    function _roundDownToWeek(uint256 t) internal pure returns (uint256) {
        return (t / WEEK) * WEEK;
    }

    function createLock(uint256 amount, uint256 unlockTime) external {
        require(amount > 0, "amount=0");

        Lock storage l = locks[msg.sender];
        require(l.amount == 0, "lock exists");

        uint256 u = _roundDownToWeek(unlockTime);
        require(u > block.timestamp, "unlock <= now");
        require(u <= block.timestamp + maxLockTime, "unlock too far");

        locks[msg.sender] = Lock({
            amount: uint128(amount),
            unlockTime: uint64(u)
        });

        bool ok = underlying.transferFrom(msg.sender, address(this), amount);
        require(ok, "transferFrom failed");

        emit LockCreated(msg.sender, amount, u);
    }

    function increaseAmount(uint256 amountAdded) external {
        require(amountAdded > 0, "amount=0");

        Lock storage l = locks[msg.sender];
        require(l.amount > 0, "no lock");
        require(l.unlockTime > block.timestamp, "lock expired");

        l.amount = uint128(uint256(l.amount) + amountAdded);

        bool ok = underlying.transferFrom(msg.sender, address(this), amountAdded);
        require(ok, "transferFrom failed");

        emit AmountIncreased(msg.sender, amountAdded);
    }

    function extendUnlockTime(uint256 newUnlockTime) external {
        Lock storage l = locks[msg.sender];
        require(l.amount > 0, "no lock");
        require(l.unlockTime > block.timestamp, "lock expired");

        uint256 u = _roundDownToWeek(newUnlockTime);
        require(u > l.unlockTime, "not extending");
        require(u <= block.timestamp + maxLockTime, "unlock too far");

        l.unlockTime = uint64(u);

        emit UnlockTimeExtended(msg.sender, u);
    }

    function withdraw() external {
        Lock storage l = locks[msg.sender];
        uint256 amount = uint256(l.amount);
        require(amount > 0, "no lock");
        require(block.timestamp >= l.unlockTime, "not unlocked");

        delete locks[msg.sender];

        bool ok = underlying.transfer(msg.sender, amount);
        require(ok, "transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    // voting power: linear decay to 0 at unlock
    function balanceOf(address user) external view returns (uint256) {
        Lock memory l = locks[user];
        if (l.amount == 0) return 0;
        if (block.timestamp >= l.unlockTime) return 0;

        uint256 remaining = uint256(l.unlockTime) - block.timestamp;
        // amount * remaining / maxLockTime
        return (uint256(l.amount) * remaining) / maxLockTime;
    }
}