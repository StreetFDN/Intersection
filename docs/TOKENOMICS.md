# Street AMM – Tokenomics

## STREET token

- **Name:** Street Protocol Token  
- **Symbol:** STREET  
- **Max supply:** 1,000,000,000 (1B) STREET  
- **Chain:** Base  

## Emissions schedule (StreetMinter)

Fixed weekly schedule; no rebases (no transfer to RewardsDistributor for lockers).

| Period | Weekly emission | Notes |
|--------|------------------|------|
| Year 1 (weeks 1–52) | ~1,923,077 STREET | 100M / 52 |
| Year 2 (weeks 53–104) | ~1,538,462 STREET | 80M / 52 |
| Year 3 (weeks 105–156) | ~1,153,846 STREET | 60M / 52 |
| Year 4 (weeks 157–208) | ~1,153,846 STREET | 60M / 52 |
| Year 5+ (tail) | ~96,154 STREET/week | 5M/year perpetual |

Emissions go to StreetVoter (then to gauges by vote weight); team share is sent to the team address in the same `updatePeriod` call.

## Vote-escrow (VeStreet)

- **Max lock:** 2 years (unchanged from deployment).
- Locking STREET mints a veNFT; voting power decreases linearly over time until unlock.
- Used for: gauge voting, bribe eligibility, managed NFTs (if enabled).

## Bribe fees

- **95%** of notified bribe rewards → veSTREET voters (next epoch).
- **5%** → protocol treasury (StreetBribe platform fee).

## Pool and protocol fees

Configurable per pool (e.g. stable vs volatile, tier). Example ranges from spec:

- LP fee: ~1.2–1.7%
- Protocol fee: ~0.3–0.6%
- Set via PoolFactory / fee manager.

## Distribution example (from spec)

- 30% Liquidity mining (Minter over 4 years)
- 25% Team/advisors (vesting)
- 20% Investors (vesting)
- 15% Treasury (governance)
- 10% Community (early users, founders, LPs)

Exact allocation and vesting are set at deployment and via initializer/minter config, not enforced in the emission contract.
