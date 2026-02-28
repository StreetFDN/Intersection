# Cursor Prompt: Migrate to Street AMM (Aerodrome-Based)

## Context

These contracts were written for Street's governance + reward distribution system, but they're **missing the AMM** (pools, swaps, gauges, bribes).

We need to migrate to **Aerodrome-based contracts** because:
- Aerodrome is battle-tested ($500M+ TVL, zero exploits)
- Has full AMM infrastructure (Pool, Router, Gauge, Voter, Minter)
- veToken + gauge voting system is production-ready
- 74% of Aerodrome contracts can be used as-is

## Current Architecture (What's Here)

These contracts implement:
1. **StreetToken** - Simple ERC20
2. **VeToken** - Basic vote-escrow (too simple for AMM needs)
3. **VeStreet/VeStartup** - Inherit VeToken
4. **StreetDAO/IssuerDAO** - Governance for treasury/rewards
5. **DistributorV1** - Merkle-tree reward distribution (not gauge-based)
6. **Treasury** - Holds funds
7. **PauseController** - Emergency pause

**Missing:** Pool, Router, Gauge, Voter, Minter, Bribe contracts

## Task: Migrate to Aerodrome-Based Implementation

### Step 1: Clone Aerodrome

```bash
git clone https://github.com/aerodrome-finance/contracts aerodrome
```

### Step 2: Replace Current Contracts

**Delete these (will be replaced by Aerodrome):**
- VeToken.sol → Use Aerodrome's VotingEscrow.sol
- VeStreet.sol → Use Aerodrome's VotingEscrow.sol
- VeStartup.sol → Not needed for AMM
- DistributorV1.sol → Use Aerodrome's Gauge system
- StreetDAO.sol → Use Aerodrome's ProtocolGovernor.sol
- IssuerDAO.sol → Not needed for AMM
- Treasury.sol → Integrate with Aerodrome's Minter

**Keep but modify:**
- StreetToken.sol → Rename to match Aerodrome's Aero.sol structure
- PauseController.sol → Integrate pause logic into Aerodrome's Voter.sol

### Step 3: Copy Aerodrome Contracts

**Copy these unchanged (use as-is):**

```
FROM aerodrome/contracts/                 TO contracts/
────────────────────────────────────────────────────────
Pool.sol                          →      Pool.sol
PoolFees.sol                      →      PoolFees.sol
Router.sol                        →      Router.sol
factories/PoolFactory.sol         →      factories/PoolFactory.sol
gauges/Gauge.sol                  →      gauges/Gauge.sol
factories/GaugeFactory.sol        →      factories/GaugeFactory.sol
rewards/VotingReward.sol          →      rewards/VotingReward.sol
rewards/FeesVotingReward.sol      →      rewards/FeesVotingReward.sol
factories/VotingRewardsFactory.sol →     factories/VotingRewardsFactory.sol
FactoryRegistry.sol               →      FactoryRegistry.sol
VeArtProxy.sol                    →      VeArtProxy.sol
ProtocolGovernor.sol              →      governance/ProtocolGovernor.sol
EpochGovernor.sol                 →      governance/EpochGovernor.sol
libraries/*                       →      libraries/*
interfaces/*                      →      interfaces/*
```

**Copy and modify:**

```
FROM aerodrome/contracts/         TO contracts/                MODIFICATIONS
────────────────────────────────────────────────────────────────────────────────
Aero.sol                   →     StreetToken.sol           - Rename AERO → STREET
                                                            - Set supply: 1B STREET

VotingEscrow.sol           →     VeStreet.sol              - Max lock: 4y → 2y
                                                            - Update NFT metadata

Voter.sol                  →     StreetVoter.sol           - Add founder whitelist
                                                            - Add gauge pause function
                                                            - Integrate PauseController logic

Minter.sol                 →     StreetMinter.sol          - New emissions: 100M Y1 flat
                                                            - Remove rebases

rewards/BribeVotingReward.sol →  rewards/StreetBribe.sol  - Add 5% platform fee
```

**Create new (Street-specific):**

```
contracts/compliance/FounderControls.sol    - Circuit breakers, volume limits
contracts/compliance/OffRampKYC.sol         - Civic integration (optional v1)
```

### Step 4: Update Imports & Dependencies

After copying, you'll need to:

1. **Update all imports** to match new file paths
2. **Install OpenZeppelin dependencies** (Aerodrome uses them)
3. **Update Solidity version** if needed (Aerodrome uses 0.8.19)

### Step 5: Modify Specific Contracts

#### StreetToken.sol (formerly Aero.sol)

```solidity
// Change name and symbol
string public constant name = "Street Protocol Token";
string public constant symbol = "STREET";

// Set total supply
uint256 public constant MAX_SUPPLY = 1_000_000_000e18;  // 1 billion
```

#### VeStreet.sol (formerly VotingEscrow.sol)

```solidity
// Change max lock time
uint256 internal constant MAXTIME = 2 * 365 * 86400;  // 2 years instead of 4
```

#### StreetVoter.sol (formerly Voter.sol)

```solidity
// Add founder whitelist
mapping(address => bool) public whitelistedFounders;

function whitelistFounder(address founder, bool status) external {
    require(msg.sender == governor, "Not governor");
    whitelistedFounders[founder] = status;
}

// Modify createGauge to check whitelist
function createGauge(...) external returns (...) {
    require(whitelistedFounders[msg.sender] || msg.sender == governor, "Not whitelisted");
    // ... rest of function
}

// Add gauge pause function
mapping(address => bool) public pausedGauges;

function pauseGauge(address gauge, bool status) external {
    // Only pool founder or governor
    require(isFounder(pool, msg.sender) || msg.sender == governor, "Not authorized");
    pausedGauges[gauge] = status;
}
```

#### StreetMinter.sol (formerly Minter.sol)

```solidity
// Replace emissions schedule
uint256 public constant YEAR_1_WEEKLY = 1_923_077e18;  // 100M / 52
uint256 public constant YEAR_2_WEEKLY = 1_538_462e18;  // 80M / 52
uint256 public constant YEAR_3_WEEKLY = 1_153_846e18;  // 60M / 52
uint256 public constant YEAR_4_WEEKLY = 1_153_846e18;  // 60M / 52
uint256 public constant TAIL_EMISSION  = 96_154e18;    // 5M / 52

function weeklyEmission() public view returns (uint256) {
    uint256 epoch = (block.timestamp - initialTimestamp) / 1 weeks;
    
    if (epoch < 52) return YEAR_1_WEEKLY;
    if (epoch < 104) return YEAR_2_WEEKLY;
    if (epoch < 156) return YEAR_3_WEEKLY;
    if (epoch < 208) return YEAR_4_WEEKLY;
    return TAIL_EMISSION;
}

// Delete all rebase-related code
```

#### StreetBribe.sol (formerly BribeVotingReward.sol)

```solidity
// Add platform fee
uint256 public constant PLATFORM_FEE = 500;  // 5% = 500 bps
address public treasury;

function notifyRewardAmount(address token, uint256 amount) external {
    // Take 5% fee
    uint256 fee = amount * PLATFORM_FEE / 10000;
    uint256 netAmount = amount - fee;
    
    // Transfer fee to treasury
    IERC20(token).safeTransferFrom(msg.sender, treasury, fee);
    
    // Transfer net to bribe contract
    IERC20(token).safeTransferFrom(msg.sender, address(this), netAmount);
    
    // ... rest of function
}
```

### Step 6: Create New Contracts

#### FounderControls.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract FounderControls {
    mapping(address => address) public poolFounders;
    mapping(address => bool) public paused;
    mapping(address => uint256) public maxDailyVolume;
    
    function registerFounder(address pool, address founder) external onlyOwner {
        poolFounders[pool] = founder;
    }
    
    function setPaused(address pool, bool _paused) external onlyFounder(pool) {
        paused[pool] = _paused;
    }
    
    function checkSwap(address pool, uint256 amountOut) external returns (bool) {
        if (paused[pool]) return false;
        // Check volume limits, float limits, etc.
        return true;
    }
}
```

### Step 7: Update Tests

**Modify test files:**
- full-architecture.test.ts → Add Pool, Gauge, Voter tests
- audit-fixes.test.ts → Update for new contracts

**Add new tests:**
- Pool.t.sol - Swap, LP deposit/withdraw
- VeStreet.t.sol - Lock, voting power, NFTs
- StreetVoter.t.sol - Gauge voting, distributions
- StreetBribe.t.sol - Bribes, 5% fee
- FounderControls.t.sol - Pause, volume limits

### Step 8: Deployment Script

Update or create new deployment script:

```typescript
// scripts/deploy-street-amm.ts

// 1. Deploy STREET token
const streetToken = await StreetToken.deploy();

// 2. Deploy VeStreet
const veStreet = await VeStreet.deploy(streetToken, forwarder, factoryRegistry);

// 3. Deploy factories
const poolFactory = await PoolFactory.deploy();
const gaugeFactory = await GaugeFactory.deploy();
const bribeFactory = await VotingRewardsFactory.deploy();

// 4. Deploy FactoryRegistry
const registry = await FactoryRegistry.deploy(poolFactory, gaugeFactory, bribeFactory);

// 5. Deploy StreetVoter
const voter = await StreetVoter.deploy(veStreet, registry);

// 6. Deploy StreetMinter
const minter = await StreetMinter.deploy(voter, veStreet, streetToken);

// 7. Deploy Router
const router = await Router.deploy(poolFactory, WETH);

// 8. Deploy FounderControls
const founderControls = await FounderControls.deploy();

// Initialize
await streetToken.setMinter(minter);
await veStreet.setVoter(voter);
await voter.initialize(minter);
```

## Expected Output

After following these steps, you should have:

1. ✅ Full Aerodrome-based AMM (Pool, Router, Gauge, Voter, Minter)
2. ✅ Street-specific modifications (2-year lock, founder controls, 5% bribe fee)
3. ✅ FounderControls contract (circuit breakers, pause)
4. ✅ Updated tests covering all functionality
5. ✅ Deployment script ready for Base

## Key Differences from Current Contracts

| Current (Rishi) | New (Aerodrome-based) |
|----------------|---------------------|
| Simple VeToken | VotingEscrow with NFTs, checkpoints |
| Merkle distributor | Gauge-based emissions |
| StreetDAO | ProtocolGovernor |
| No pools | Pool.sol (stable + volatile) |
| No swaps | Router.sol |
| No LP staking | Gauge.sol |
| No bribes | StreetBribe.sol (with 5% fee) |

## Resources

- **Aerodrome repo:** https://github.com/aerodrome-finance/contracts
- **Street AMM spec:** /Users/lukasgruber/.openclaw/workspace/tasks/STREET_AMM_IMPLEMENTATION_SPEC.md
- **Aerodrome analysis:** /Users/lukasgruber/.openclaw/workspace/tasks/AERODROME_ANALYSIS_FOR_STREET.md

## Questions to Ask Me

1. Should we keep any of the current VeToken implementation or fully replace?
2. Do we need IssuerDAO for startup token governance?
3. Should PauseController be standalone or integrated into Voter?
4. Do we need OffRampKYC for v1 or defer to later?
5. Should we support both Merkle (current) and Gauge (new) distributions?

**Recommendation:** Full replacement with Aerodrome contracts. Use 74% as-is, modify 19%, add 7% new. Production-ready in 6-7 weeks.
