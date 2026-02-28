# Rishi's Smart Contracts - Analysis & AMM Adjustments

## Current Architecture (What Rishi Built)

### Contracts Present:

1. **StreetToken.sol** - Simple ERC20 with mint/burn
2. **VeToken.sol** - Basic vote-escrow (linear decay, lock/unlock)
3. **VeStreet.sol** - Inherits VeToken for STREET
4. **VeStartup.sol** - Inherits VeToken for startup tokens
5. **StreetDAO.sol** - Governance for Street treasury withdrawals
6. **IssuerDAO.sol** - Governance for startup reward distributions
7. **DistributorV1.sol** - Merkle-tree reward distributor
8. **Treasury.sol** - Holds USDC/funds for distributions
9. **PauseController.sol** - Emergency pause mechanism
10. **DemoUSD.sol** - Test stablecoin

### What This Architecture Does:

- Users lock STREET → get veSTREET voting power (linear decay)
- Users lock STARTUP tokens → get veStartup voting power
- veSTREET holders vote on treasury withdrawals
- veStartup holders vote on reward distributions
- Rewards distributed via Merkle tree (not gauge-based)
- Emergency pause for all distributions

---

## What's Missing for AMM Buildout

### Critical Missing Components:

1. **No AMM/Pool contracts** (no token swapping)
2. **No Router** (no swap routing)
3. **No Gauges** (no LP staking for emissions)
4. **No Voter contract** (no gauge voting system)
5. **No Minter** (no emissions schedule)
6. **No Bribe system** (no external incentives)

### VeToken Limitations:

Current VeToken.sol is **too simple** compared to Aerodrome's VotingEscrow:

**Missing:**
- ❌ ERC-721 NFT representation (tokens not transferable as NFTs)
- ❌ Checkpointing system (can't query historical voting power)
- ❌ Managed NFTs (no vault-style aggregation)
- ❌ Permanent lock option (can't freeze voting power)
- ❌ Merge/split functionality
- ❌ Delegation
- ❌ EIP-6372 compliance (timestamps for governance)

**Has:**
- ✅ Basic locking mechanism
- ✅ Linear decay voting power
- ✅ Unlock when time expires

---

## Recommended Approach: Replace vs. Integrate

### Option 1: REPLACE (Recommended)

**Replace Rishi's contracts with Aerodrome-based AMM:**

**Why:**
- Aerodrome is battle-tested ($500M+ TVL, no exploits)
- VotingEscrow is production-ready (NFTs, checkpoints, managed locks)
- Full AMM infrastructure already exists
- Gauge-based emissions > Merkle-tree distributions

**What to keep:**
- ✅ StreetToken.sol name/symbol (rename to match Aerodrome's Aero.sol)
- ✅ Concept of veSTREET (but use Aerodrome's VotingEscrow)
- ✅ PauseController logic (integrate into Voter contract)

**What to replace:**
- ❌ VeToken.sol → Use Aerodrome's VotingEscrow.sol
- ❌ DistributorV1.sol → Use Aerodrome's Gauge system
- ❌ StreetDAO/IssuerDAO → Use Aerodrome's Voter.sol
- ❌ Add: Pool, Router, Gauge, Minter contracts from Aerodrome

---

### Option 2: INTEGRATE (Not Recommended)

**Try to integrate Aerodrome AMM with Rishi's contracts:**

**Challenges:**
- VeToken.sol incompatible with Aerodrome's Voter (needs VotingEscrow features)
- DistributorV1 (Merkle) incompatible with Gauges (LP staking)
- Would need to rewrite significant portions
- Higher risk of bugs/exploits

**Verdict:** Don't do this. Clean replacement is safer.

---

## Migration Plan

### Phase 1: Use Aerodrome Contracts (Recommended)

**Replace:**
```
Rishi's Contracts          →  Aerodrome Contracts
─────────────────────────────────────────────────
StreetToken.sol            →  Aero.sol (renamed to StreetToken)
VeToken.sol                →  VotingEscrow.sol (renamed to VeStreet)
VeStreet.sol               →  (delete, use VotingEscrow)
DistributorV1.sol          →  Voter.sol + Gauge.sol
StreetDAO.sol              →  ProtocolGovernor.sol
Treasury.sol               →  (integrate with Minter.sol)
PauseController.sol        →  (integrate pause logic into Voter)

ADD NEW:
- Pool.sol (AMM)
- Router.sol (swap routing)
- Gauge.sol (LP staking)
- Minter.sol (emissions)
- BribeVotingReward.sol (external incentives)
- FeesVotingReward.sol (LP fees to voters)
- Factories (Pool, Gauge, Rewards)
```

### Phase 2: Configuration

**Keep from Rishi's work:**
- Max lock time: 4 years (or change to 2 years)
- Governance structure (veSTREET voting)
- Emergency pause mechanism

**Add from Aerodrome:**
- Weekly epochs (Thursday 00:00 UTC)
- Gauge voting system
- Bribe marketplace
- Pool fees (volatile + stable)

---

## Detailed Component Comparison

### VeToken vs VotingEscrow

| Feature | Rishi's VeToken | Aerodrome VotingEscrow |
|---------|----------------|----------------------|
| **Lock mechanism** | ✅ Basic locking | ✅ Advanced locking |
| **Voting power decay** | ✅ Linear decay | ✅ Linear decay + permanent lock |
| **NFT representation** | ❌ No | ✅ ERC-721 NFTs |
| **Transferability** | ❌ No | ✅ NFTs can be transferred |
| **Checkpointing** | ❌ No | ✅ Historical voting power |
| **Managed NFTs** | ❌ No | ✅ Vault-style aggregation |
| **Merge/split** | ❌ No | ✅ Yes |
| **Delegation** | ❌ No | ✅ EIP-6372 delegation |
| **Max lock time** | ✅ 4 years | ✅ 4 years (configurable) |
| **Battle-tested** | ❌ New code | ✅ $500M+ TVL, no exploits |

### DistributorV1 vs Gauge System

| Feature | Rishi's DistributorV1 | Aerodrome Gauges |
|---------|----------------------|----------------|
| **Reward type** | Merkle tree (off-chain compute) | On-chain emissions (gauge voting) |
| **Voting** | DAO approves rounds | veSTREET holders vote weekly |
| **Flexibility** | Fixed per round | Dynamic (vote every week) |
| **Incentives** | None | Bribes (external incentives) |
| **LP staking** | No | Yes (stake LP tokens in gauge) |
| **Fee distribution** | No | Yes (LP fees to voters) |
| **Complexity** | Medium | Higher (but proven) |
| **Gas efficiency** | High (Merkle proofs) | Medium (weekly distributions) |
| **Decentralization** | Low (requires root submission) | High (permissionless voting) |

---

## Test Files Analysis

### full-architecture.test.ts

**What it tests:**
- veSTREET locking/unlocking
- StreetDAO governance proposals
- DistributorV1 reward claiming
- Multi-sig approval (supervisor + counsel)
- Emergency pause

**What it doesn't test (because missing):**
- Pool swaps
- LP provision
- Gauge voting
- Emissions distribution
- Bribes

### audit-fixes.test.ts

**Focuses on:**
- Access control
- Reentrancy protection
- Edge cases in DistributorV1

---

## Recommendation: Start Fresh with Aerodrome

**Why:**
1. **Security:** Aerodrome is audited and battle-tested
2. **Completeness:** Has all AMM components we need
3. **Compatibility:** veSTREET + gauges + bribes work together
4. **Time:** Faster than building from Rishi's base
5. **Risk:** Lower chance of exploits

**What to preserve from Rishi's work:**
- Contract naming conventions (StreetToken, veSTREET)
- PauseController concept (integrate into Voter)
- Test patterns (use as reference for Street-specific tests)
- Governance structure ideas (StreetDAO → ProtocolGovernor)

**What to discard:**
- VeToken.sol implementation (use Aerodrome's VotingEscrow)
- DistributorV1 Merkle system (use Gauge-based emissions)
- IssuerDAO (not needed for AMM)
- DemoUSD (use real USDC on Base)

---

## Summary

**Current state:** Rishi built governance + reward distribution, but **no AMM**.

**Gap:** Missing Pool, Router, Gauge, Voter, Minter, Bribe contracts.

**Solution:** Use Aerodrome contracts (74% as-is), add Street modifications (19%), add new features (7%).

**Action:** Replace Rishi's contracts with Aerodrome-based implementation per STREET_AMM_IMPLEMENTATION_SPEC.md.
