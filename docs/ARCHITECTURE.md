# Street AMM – Architecture

Street AMM is a fork of [Aerodrome Finance](https://github.com/aerodrome-finance/contracts) on **Base**, adapted for startup tokens (ERC-S) with founder controls and a fixed emissions schedule.

## Design principles

- **Use battle-tested code:** Most contracts are Aerodrome originals, unchanged.
- **Fork only where needed:** StreetToken, VeStreet, StreetVoter, StreetMinter, StreetBribe.
- **Add only for Street features:** FounderControls, OffRampKYC (optional).

## Contract map

### Core (Street-specific)

| Contract | Role |
|--------|------|
| **StreetToken** | Protocol ERC20 (STREET), 1B supply, minted by StreetMinter. |
| **VeStreet** | Vote-escrow NFT; lock STREET for up to **2 years** for voting power. |
| **StreetVoter** | Epoch votes, gauge/bribe creation, emission distribution. **Founder whitelist** for gauge creation; **gauge pause** (governor or pool founder). |
| **StreetMinter** | Fixed weekly emissions (no rebases); sends team share + rest to Voter. |
| **StreetBribe** | Bribe contract with **5% platform fee** to treasury. |
| **StreetVotingRewardsFactory** | Deploys FeesVotingReward + StreetBribe (with treasury). |

### Used as-is (Aerodrome)

- **Pool, PoolFees, Router** – AMM and routing.
- **PoolFactory, GaugeFactory, FactoryRegistry** – Pool/gauge creation and registry.
- **Gauge** – LP staking and emission claims.
- **VotingReward, FeesVotingReward** – Reward logic (StreetBribe extends bribe variant).
- **RewardsDistributor** – Used by Minter; no rebase transfers in StreetMinter.
- **ProtocolGovernor, EpochGovernor** – Governance.
- **VeArtProxy** – veNFT art.

### New (Street-only)

| Contract | Role |
|--------|------|
| **FounderControls** | Per-pool: founder-registered pause, max daily volume, max float (basis points). `checkSwap(pool, amountOut)` for optional integration. |
| **OffRampKYC** | Optional KYC for fiat off-ramps; Civic gateway + `kycApproved` mapping. |

## Data flow

1. **Lock:** User locks STREET in VeStreet → receives veNFT (voting power decays over time, max 2 years).
2. **Vote:** User votes for gauges via StreetVoter; votes apply to the current epoch (1 week).
3. **Emissions:** StreetMinter pushes weekly STREET to StreetVoter; Voter distributes to gauges by vote weight.
4. **Bribes:** External parties notify rewards on StreetBribe; 5% to treasury, rest to voters next epoch.
5. **Founder controls:** FounderControls (optional) can pause a pool or enforce volume/float limits; Pool does not call it by default.

## Deployment order

See `STREET_AMM_IMPLEMENTATION_SPEC.md` and `script/README.md`. Order: StreetToken → factories + FactoryRegistry → VeStreet → ArtProxy → Voter + Distributor → Router → StreetMinter → AirdropDistributor → FounderControls → OffRampKYC → initialize and transfer ownerships.

## Upgrade path

- **Immutable:** StreetToken, VeStreet, StreetVoter, StreetMinter.
- **Via new factories:** Pools, Gauges, Bribes (deploy new factory, register, migrate, deprecate old factory).
