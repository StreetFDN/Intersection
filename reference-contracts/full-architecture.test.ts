/**
 * Full architecture integration tests.
 * Mirrors scripts/deploy-local.ts flow and adds extra edge-case coverage.
 * Run: npx hardhat test test/full-architecture.test.ts
 */

import { expect } from "chai";
import { network } from "hardhat";

let ethers: typeof import("ethers");

const provider = () => ethers!.provider as { send: (method: string, params: unknown[]) => Promise<unknown> };

async function mineBlocks(n: number) {
  for (let i = 0; i < n; i++) {
    await provider().send("evm_mine", []);
  }
}

async function increaseTime(seconds: number) {
  await provider().send("evm_increaseTime", [seconds]);
  await provider().send("evm_mine", []);
}

describe("Full architecture", function () {
  const ISSUERDAO_VOTING_PERIOD_BLOCKS = 5n;
  const STREETDAO_VOTING_PERIOD_BLOCKS = 5n;
  const PROPOSAL_DELAY_BLOCKS = 1n;
  const MAX_LOCK_TIME = 4n * 365n * 24n * 60n * 60n;

  let STARTUP_THRESHOLD: bigint;
  let STREET_THRESHOLD: bigint;
  let QUORUM: bigint;
  let MINT_STARTUP_TO_USER1: bigint;
  let MINT_STREET_TO_USER1: bigint;
  let MINT_DUSD_TO_DISTRIBUTOR: bigint;
  let MINT_DUSD_TO_TREASURY: bigint;
  let LOCK_STARTUP_AMOUNT: bigint;
  let LOCK_STREET_AMOUNT: bigint;

  let demoUSD: Awaited<ReturnType<Awaited<ReturnType<typeof ethers.getContractFactory>>["deploy"]>>;
  let startupToken: Awaited<ReturnType<Awaited<ReturnType<typeof ethers.getContractFactory>>["deploy"]>>;
  let streetToken: Awaited<ReturnType<Awaited<ReturnType<typeof ethers.getContractFactory>>["deploy"]>>;
  let pauseController: Awaited<ReturnType<Awaited<ReturnType<typeof ethers.getContractFactory>>["deploy"]>>;
  let distributor: Awaited<ReturnType<Awaited<ReturnType<typeof ethers.getContractFactory>>["deploy"]>>;
  let veStartup: Awaited<ReturnType<Awaited<ReturnType<typeof ethers.getContractFactory>>["deploy"]>>;
  let veStreet: Awaited<ReturnType<Awaited<ReturnType<typeof ethers.getContractFactory>>["deploy"]>>;
  let issuerDAO: Awaited<ReturnType<Awaited<ReturnType<typeof ethers.getContractFactory>>["deploy"]>>;
  let streetDAO: Awaited<ReturnType<Awaited<ReturnType<typeof ethers.getContractFactory>>["deploy"]>>;
  let treasury: Awaited<ReturnType<Awaited<ReturnType<typeof ethers.getContractFactory>>["deploy"]>>;

  let deployer: (Awaited<ReturnType<typeof ethers.getSigners>>)[0];
  let counselSigner: (Awaited<ReturnType<typeof ethers.getSigners>>)[1];
  let user1: (Awaited<ReturnType<typeof ethers.getSigners>>)[2];
  let user2: (Awaited<ReturnType<typeof ethers.getSigners>>)[3];
  let recipient: (Awaited<ReturnType<typeof ethers.getSigners>>)[4];

  let supervisorAddr: string;
  let counselAddr: string;
  let user1Addr: string;
  let user2Addr: string;
  let recipientAddr: string;

  before(async function () {
    const conn = await network.connect({ network: "hardhatMainnet", chainType: "l1" });
    ethers = (conn as { ethers: typeof import("ethers") }).ethers;
    STARTUP_THRESHOLD = ethers.parseUnits("1", 18);
    STREET_THRESHOLD = ethers.parseUnits("1", 18);
    MINT_STARTUP_TO_USER1 = ethers.parseUnits("1000", 18);
    MINT_STREET_TO_USER1 = ethers.parseUnits("1000", 18);
    MINT_DUSD_TO_DISTRIBUTOR = ethers.parseUnits("10000", 18);
    MINT_DUSD_TO_TREASURY = ethers.parseUnits("5000", 18);
    LOCK_STARTUP_AMOUNT = ethers.parseUnits("100", 18);
    LOCK_STREET_AMOUNT = ethers.parseUnits("100", 18);
    QUORUM = ethers.parseUnits("1", 18);
    const signers = await ethers.getSigners();
    deployer = signers[0];
    counselSigner = signers[1] ?? signers[0];
    user1 = signers[2] ?? signers[0];
    user2 = signers[3] ?? signers[0];
    recipient = signers[4] ?? signers[0];
    supervisorAddr = await deployer.getAddress();
    counselAddr = await counselSigner.getAddress();
    user1Addr = await user1.getAddress();
    user2Addr = await user2.getAddress();
    recipientAddr = await recipient.getAddress();

    const DemoUSD = await ethers.getContractFactory("DemoUSD");
    demoUSD = await DemoUSD.deploy(supervisorAddr);
    await demoUSD.waitForDeployment();

    const StartupToken = await ethers.getContractFactory("StartupToken");
    startupToken = await StartupToken.deploy(supervisorAddr);
    await startupToken.waitForDeployment();

    const StreetToken = await ethers.getContractFactory("StreetToken");
    streetToken = await StreetToken.deploy(supervisorAddr);
    await streetToken.waitForDeployment();

    const PauseController = await ethers.getContractFactory("PauseController");
    pauseController = await PauseController.deploy(supervisorAddr, counselAddr);
    await pauseController.waitForDeployment();

    const DistributorV1 = await ethers.getContractFactory("DistributorV1");
    distributor = await DistributorV1.deploy(
      supervisorAddr,
      await demoUSD.getAddress(),
      await pauseController.getAddress(),
      supervisorAddr,
      counselAddr,
      supervisorAddr
    );
    await distributor.waitForDeployment();

    const VeStartup = await ethers.getContractFactory("VeStartup");
    veStartup = await VeStartup.deploy(await startupToken.getAddress(), MAX_LOCK_TIME);
    await veStartup.waitForDeployment();

    const VeStreet = await ethers.getContractFactory("VeStreet");
    veStreet = await VeStreet.deploy(await streetToken.getAddress(), MAX_LOCK_TIME);
    await veStreet.waitForDeployment();

    const IssuerDAO = await ethers.getContractFactory("IssuerDAO");
    issuerDAO = await IssuerDAO.deploy(
      await veStartup.getAddress(),
      await distributor.getAddress(),
      STARTUP_THRESHOLD,
      ISSUERDAO_VOTING_PERIOD_BLOCKS,
      PROPOSAL_DELAY_BLOCKS,
      QUORUM
    );
    await issuerDAO.waitForDeployment();
    await (await distributor.setGovernanceExecutor(await issuerDAO.getAddress())).wait();

    const StreetDAO = await ethers.getContractFactory("StreetDAO");
    streetDAO = await StreetDAO.deploy(
      await veStreet.getAddress(),
      STREET_THRESHOLD,
      STREETDAO_VOTING_PERIOD_BLOCKS,
      supervisorAddr,
      PROPOSAL_DELAY_BLOCKS,
      QUORUM
    );
    await streetDAO.waitForDeployment();

    const Treasury = await ethers.getContractFactory("Treasury");
    treasury = await Treasury.deploy(
      await demoUSD.getAddress(),
      await distributor.getAddress(),
      await streetDAO.getAddress(),
      supervisorAddr
    );
    await treasury.waitForDeployment();
    await (await streetDAO.connect(deployer).setTreasury(await treasury.getAddress())).wait();

    await (await startupToken.mint(user1Addr, MINT_STARTUP_TO_USER1)).wait();
    await (await streetToken.mint(user1Addr, MINT_STREET_TO_USER1)).wait();
    await (await demoUSD.mint(await distributor.getAddress(), MINT_DUSD_TO_DISTRIBUTOR)).wait();
    await (await demoUSD.mint(await treasury.getAddress(), MINT_DUSD_TO_TREASURY)).wait();

    const round1ClaimAmount = 10n * 10n ** 18n;
    const round1Leaf = ethers.keccak256(
      ethers.AbiCoder.defaultAbiCoder().encode(["address", "uint256"], [user2Addr, round1ClaimAmount])
    );
    await (await distributor.setMerkleRoot(1n, round1Leaf)).wait();
    await (await distributor.certifyAsSupervisor(1n)).wait();
    await (await distributor.connect(counselSigner).certifyAsCounsel(1n)).wait();
  });

  describe("Deployment and wiring", function () {
    it("deploys all contracts with non-zero addresses", async function () {
      expect(await demoUSD.getAddress()).to.be.properAddress;
      expect(await startupToken.getAddress()).to.be.properAddress;
      expect(await streetToken.getAddress()).to.be.properAddress;
      expect(await pauseController.getAddress()).to.be.properAddress;
      expect(await distributor.getAddress()).to.be.properAddress;
      expect(await veStartup.getAddress()).to.be.properAddress;
      expect(await veStreet.getAddress()).to.be.properAddress;
      expect(await issuerDAO.getAddress()).to.be.properAddress;
      expect(await streetDAO.getAddress()).to.be.properAddress;
      expect(await treasury.getAddress()).to.be.properAddress;
    });

    it("distributor has correct governance executor", async function () {
      expect(await distributor.governanceExecutor()).to.equal(await issuerDAO.getAddress());
    });

    it("treasury has correct distributor and streetDAO", async function () {
      expect(await treasury.distributor()).to.equal(await distributor.getAddress());
      expect(await treasury.streetDAO()).to.equal(await streetDAO.getAddress());
    });

    it("streetDAO has treasury set", async function () {
      expect(await streetDAO.treasury()).to.equal(await treasury.getAddress());
    });
  });

  describe("Tokens", function () {
    it("DemoUSD has correct name and symbol", async function () {
      expect(await demoUSD.name()).to.equal("Demo USD");
      expect(await demoUSD.symbol()).to.equal("DUSD");
    });

    it("only owner can mint DemoUSD", async function () {
      await expect(demoUSD.connect(user1).mint(user1Addr, 1n)).to.be.revertedWithCustomError(demoUSD, "OwnableUnauthorizedAccount");
    });

    it("distributor and treasury received minted DUSD", async function () {
      expect(await demoUSD.balanceOf(await distributor.getAddress())).to.equal(MINT_DUSD_TO_DISTRIBUTOR);
      expect(await demoUSD.balanceOf(await treasury.getAddress())).to.equal(MINT_DUSD_TO_TREASURY);
    });
  });

  describe("PauseController", function () {
    it("starts unpaused", async function () {
      expect(await pauseController.isPaused()).to.equal(false);
    });

    it("supervisor can pause", async function () {
      await pauseController.connect(deployer).pause();
      expect(await pauseController.isPaused()).to.equal(true);
      await pauseController.connect(deployer).unpause();
    });

    it("counsel can pause", async function () {
      await pauseController.connect(counselSigner).pause();
      expect(await pauseController.isPaused()).to.equal(true);
      await pauseController.connect(counselSigner).unpause();
    });

    it("random user cannot pause", async function () {
      await expect(pauseController.connect(user1).pause()).to.be.revertedWith("not authorized");
    });
  });

  describe("VeToken locks and voting power", function () {
    it("cannot propose IssuerDAO without ve power", async function () {
      await expect(issuerDAO.connect(user2).proposeApproveRound(1n, "fail")).to.be.revertedWith("below threshold");
    });

    it("cannot propose StreetDAO without ve power", async function () {
      await expect(streetDAO.connect(user2).proposeWithdraw(recipientAddr, 1n, "fail")).to.be.revertedWith("below threshold");
    });

    it("user1 can create ve locks and gains voting power", async function () {
      const latest = await ethers.provider.getBlock("latest");
      const now = BigInt((latest as { timestamp: number }).timestamp);
      const unlockTime = now + MAX_LOCK_TIME;

      await (await startupToken.connect(user1).approve(await veStartup.getAddress(), LOCK_STARTUP_AMOUNT)).wait();
      await (await veStartup.connect(user1).createLock(LOCK_STARTUP_AMOUNT, unlockTime)).wait();

      await (await streetToken.connect(user1).approve(await veStreet.getAddress(), LOCK_STREET_AMOUNT)).wait();
      await (await veStreet.connect(user1).createLock(LOCK_STREET_AMOUNT, unlockTime)).wait();

      const veStartPower = await veStartup.balanceOf(user1Addr);
      const veStreetPower = await veStreet.balanceOf(user1Addr);
      expect(veStartPower).to.be.gt(0n);
      expect(veStreetPower).to.be.gt(0n);
    });

    it("ve power decays over time", async function () {
      const veStartPowerBefore = await veStartup.balanceOf(user1Addr);
      await increaseTime(30 * 24 * 60 * 60);
      const veStartPowerAfter = await veStartup.balanceOf(user1Addr);
      expect(veStartPowerAfter).to.be.lt(veStartPowerBefore);
    });
  });

  describe("IssuerDAO: propose → vote → execute", function () {
    const roundId = 1n;

    it("proposes approve round and emits Proposed", async function () {
      const tx = await issuerDAO.connect(user1).proposeApproveRound(roundId, "approve round 1");
      const rcpt = await tx.wait();
      const proposedLog = rcpt!.logs
        .map((l: { topics: string[]; data: string }) => {
          try {
            return issuerDAO.interface.parseLog({ topics: l.topics as string[], data: l.data });
          } catch {
            return null;
          }
        })
        .find((x: { name: string } | null) => x && x.name === "Proposed");
      expect(proposedLog).to.not.be.undefined;
    });

    it("vote and prevent double vote", async function () {
      const proposalId = await issuerDAO.proposalCount();
      await mineBlocks(Number(PROPOSAL_DELAY_BLOCKS));
      await (await issuerDAO.connect(user1).vote(proposalId, true)).wait();
      await expect(issuerDAO.connect(user1).vote(proposalId, true)).to.be.revertedWith("already voted");
    });

    it("execute after voting period sets distributor round approved", async function () {
      const proposalId = await issuerDAO.proposalCount();
      await mineBlocks(Number(ISSUERDAO_VOTING_PERIOD_BLOCKS) + 1);
      await (await issuerDAO.execute(proposalId)).wait();
      expect(await distributor.isRoundClaimable(roundId)).to.equal(true);
    });
  });

  describe("DistributorV1: merkle root, certify, claim", function () {
    const roundId = 1n;
    const claimAmount = 10n * 10n ** 18n;

    it("round is claimable after root, certs, and DAO approval (leaf = abi.encode)", async function () {
      expect(await distributor.isRoundClaimable(roundId)).to.equal(true);
    });

    it("claim transfers DUSD to user2", async function () {
      const balBefore = await demoUSD.balanceOf(user2Addr);
      await (await distributor.connect(user2).claim(roundId, claimAmount, [])).wait();
      const balAfter = await demoUSD.balanceOf(user2Addr);
      expect(balAfter - balBefore).to.equal(claimAmount);
    });

    it("double claim reverts", async function () {
      await expect(distributor.connect(user2).claim(roundId, claimAmount, [])).to.be.revertedWith("already claimed");
    });

    it("claim with wrong proof reverts", async function () {
      const wrongAmount = ethers.parseUnits("99", 18);
      await expect(distributor.connect(user1).claim(roundId, wrongAmount, [])).to.be.revertedWith("bad proof");
    });
  });

  describe("DistributorV1: pause blocks claim", function () {
    it("when paused, isRoundClaimable is false", async function () {
      const roundId = 2n;
      const amt = ethers.parseUnits("5", 18);
      const leafHash2 = ethers.keccak256(
        ethers.AbiCoder.defaultAbiCoder().encode(["address", "uint256"], [user2Addr, amt])
      );
      await (await distributor.setMerkleRoot(roundId, leafHash2)).wait();
      await (await distributor.certifyAsSupervisor(roundId)).wait();
      await (await distributor.connect(counselSigner).certifyAsCounsel(roundId)).wait();
      await (await issuerDAO.connect(user1).proposeApproveRound(roundId, "round 2")).wait();
      const pid = await issuerDAO.proposalCount();
      await mineBlocks(Number(PROPOSAL_DELAY_BLOCKS));
      await (await issuerDAO.connect(user1).vote(pid, true)).wait();
      await mineBlocks(Number(ISSUERDAO_VOTING_PERIOD_BLOCKS) + 1);
      await (await issuerDAO.execute(pid)).wait();
      expect(await distributor.isRoundClaimable(roundId)).to.equal(true);
      await pauseController.connect(deployer).pause();
      expect(await pauseController.isPaused()).to.equal(true);
      expect(await distributor.isRoundClaimable(roundId)).to.equal(false);
      await pauseController.connect(deployer).unpause();
    });
  });

  describe("StreetDAO: propose → vote → execute withdraw", function () {
    const withdrawAmount = 7n * 10n ** 18n;

    it("proposes withdraw and executes after voting (proposalDelay then vote)", async function () {
      const tx = await streetDAO.connect(user1).proposeWithdraw(recipientAddr, withdrawAmount, "treasury payout");
      await tx.wait();
      const proposalId = await streetDAO.proposalCount();
      await mineBlocks(Number(PROPOSAL_DELAY_BLOCKS));
      await (await streetDAO.connect(user1).vote(proposalId, true)).wait();
      await mineBlocks(Number(STREETDAO_VOTING_PERIOD_BLOCKS) + 1);
      const balBefore = await demoUSD.balanceOf(recipientAddr);
      await (await streetDAO.execute(proposalId)).wait();
      const balAfter = await demoUSD.balanceOf(recipientAddr);
      expect(balAfter - balBefore).to.equal(withdrawAmount);
    });
  });

  describe("Treasury", function () {
    it("only distributor or streetDAO can withdraw", async function () {
      await expect(treasury.connect(user1).withdraw(user1Addr, 1n)).to.be.revertedWith("not authorized");
    });

    it("balance matches token balance", async function () {
      expect(await treasury.balance()).to.equal(await demoUSD.balanceOf(await treasury.getAddress()));
    });
  });

  describe("Access control", function () {
    it("only owner can set distributor merkle root", async function () {
      await expect(distributor.connect(user1).setMerkleRoot(3n, ethers.keccak256("0x01"))).to.be.revertedWithCustomError(distributor, "OwnableUnauthorizedAccount");
    });

    it("only supervisor can certify as supervisor", async function () {
      await expect(distributor.connect(user1).certifyAsSupervisor(3n)).to.be.revertedWith("not supervisor");
    });

    it("only counsel can certify as counsel", async function () {
      await expect(distributor.connect(user1).certifyAsCounsel(3n)).to.be.revertedWith("not counsel");
    });
  });
});
