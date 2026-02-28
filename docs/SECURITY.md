# Street AMM – Security

## Approach

Street AMM is a fork of Aerodrome (Base, $500M+ TVL, multiple audits). Most code is unchanged; only Street-specific contracts and small overrides were added or modified.

## Contract risks and mitigations

| Risk | Mitigation |
|------|------------|
| Reentrancy | ReentrancyGuard where needed (e.g. Voter); follow Aerodrome patterns. |
| Integer overflow/underflow | Solidity 0.8+ checked arithmetic. |
| Access control | onlyOwner, onlyGovernor, onlyFounder; multisig + timelock for governance. |
| Voting manipulation | Epoch boundaries, whitelisted gauge creation, gauge pause. |
| Bribe gaming | Pro-rata distribution, epoch-based claiming; 5% fee to treasury. |

## Street-specific considerations

- **FounderControls:** Per-pool pause, volume limits, and float limits (max % of token supply held in pool). Only the registered founder (or owner for registration) can change them. Pool does not call `checkSwap` by default; integration is optional. Zero-address validation on `registerFounder`.
- **OffRampKYC:** Optional; only owner or Civic gateway can approve/revoke. Zero-address validation on `setCivicGateway`. No impact on AMM trading.
- **StreetBribe:** Platform fee (5%) is taken before rewarding voters; single transfer and bookkeeping in one call.
- **StreetMinter:** No rebases; fixed schedule reduces logic surface vs. dynamic decay/growth.
- **StreetToken:** `MAX_SUPPLY` (1B) enforced on every `mint()` call; reverts if exceeded.

## Audits and bounties

- **Pre-launch:** External audit(s) and internal review of all modified and new contracts (StreetToken, VeStreet, StreetVoter, StreetMinter, StreetBribe, FounderControls, OffRampKYC, StreetVotingRewardsFactory).
- **Bug bounty:** Consider Immunefi or similar after mainnet launch.
- **Monitoring:** Track large transfers, voting anomalies, and failed txs post-deployment.

## Operational security

- Use multisig for owner/team/governor keys.
- Timelock for governance actions.
- Keep deployment keys and admin keys separate; rotate if compromised.
- See `STREET_AMM_IMPLEMENTATION_SPEC.md` (Risk Assessment, Monitoring, Go-Live Checklist) for full lists.

## Reporting

For responsible disclosure, use the channel designated by the Street team (e.g. security email or Immunefi). Do not open public issues for critical/high vulnerabilities.
