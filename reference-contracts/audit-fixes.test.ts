/**
 * Tests that verify audit fixes: setTreasury/setters restricted, root binding, quorum, proposal delay.
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

describe("Audit fixes", function () {
  const PROPOSAL_DELAY = 1n;
  const VOTING_PERIOD = 5n;
  const QUORUM = 1n * 10n ** 18n;
  const HIGH_QUORUM = 1000n * 10n ** 18n;
  const THRESHOLD = 1n * 10n ** 18n;
  const MAX_LOCK = 4n * 365n * 24n * 60n * 60n;

  let deployer: (Awaited<ReturnType<typeof ethers.getSigners>>)[0];
  let counselSigner: (Awaited<ReturnType<typeof ethers.getSigners>>)[1];
  let user1: (Awaited<ReturnType<typeof ethers.getSigners>>)[2];
  let supervisorAddr: string;
  let counselAddr: string;
  let user1Addr: string;

  let demoUSD: Awaited<ReturnType<Awaited<ReturnType<typeof ethers.getContractFactory>>["deploy"]>>;
  let startupToken: Awaited<ReturnType<Awaited<ReturnType<typeof ethers.getContractFactory>>["deploy"]>>;
  let streetToken: Awaited<ReturnType<Awaited<ReturnType<typeof ethers.getContractFactory>>["deploy"]>>;
  let pauseController: Awaited<ReturnType<Awaited<ReturnType<typeof ethers.getContractFactory>>["deploy"]>>;
  let distributor: Awaited<ReturnType<Awaited<ReturnType<typeof ethers.getContractFactory>>["deploy"]>>;
  let veStartup: Awaited<ReturnType<Awaited<ReturnType<typeof ethers.getContractFactory>>["deploy"]>>;
  let veStreet: Awaited<ReturnType<Awaited<ReturnType<typeof ethers.getContractFactory>>["deploy"]>>;
  let issuerDAO: Awaited<ReturnType<Awaited<ReturnType<typeof ethers.getContractFactory>>["deploy"]>>;
  let streetDAO: Awaited<ReturnType<Awaited<ReturnType<typeof ethers.getContractFactory>>["deploy"]>>;
  let streetDAO2: Awaited<ReturnType<Awaited<ReturnType<typeof ethers.getContractFactory>>["deploy"]>>;
  let treasury: Awaited<ReturnType<Awaited<ReturnType<typeof ethers.getContractFactory>>["deploy"]>>;
  let treasury2: Awaited<ReturnType<Awaited<ReturnType<typeof ethers.getContractFactory>>["deploy"]>>;

  before(async function () {
    const conn = await network.connect({ network: "hardhatMainnet", chainType: "l1" });
    ethers = (conn as { ethers: typeof import("ethers") }).ethers;
    const signers = await ethers.getSigners();
    deployer = signers[0];
    counselSigner = signers[1] ?? signers[0];
    user1 = signers[2] ?? signers[0];
    supervisorAddr = await deployer.getAddress();
    counselAddr = await counselSigner.getAddress();
    user1Addr = await user1.getAddress();

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
    veStartup = await VeStartup.deploy(await startupToken.getAddress(), MAX_LOCK);
    await veStartup.waitForDeployment();

    const VeStreet = await ethers.getContractFactory("VeStreet");
    veStreet = await VeStreet.deploy(await streetToken.getAddress(), MAX_LOCK);
    await veStreet.waitForDeployment();

    const IssuerDAO = await ethers.getContractFactory("IssuerDAO");
    issuerDAO = await IssuerDAO.deploy(
      await veStartup.getAddress(),
      await distributor.getAddress(),
      THRESHOLD,
      VOTING_PERIOD,
      PROPOSAL_DELAY,
      QUORUM
    );
    await issuerDAO.waitForDeployment();
    await (await distributor.setGovernanceExecutor(await issuerDAO.getAddress())).wait();

    const StreetDAO = await ethers.getContractFactory("StreetDAO");
    streetDAO = await StreetDAO.deploy(
      await veStreet.getAddress(),
      THRESHOLD,
      VOTING_PERIOD,
      supervisorAddr,
      PROPOSAL_DELAY,
      QUORUM
    );
    await streetDAO.waitForDeployment();

    treasury = await (await ethers.getContractFactory("Treasury")).deploy(
      await demoUSD.getAddress(),
      await distributor.getAddress(),
      await streetDAO.getAddress(),
      supervisorAddr
    );
    await treasury.waitForDeployment();
    await (await streetDAO.connect(deployer).setTreasury(await treasury.getAddress())).wait();

    streetDAO2 = await StreetDAO.deploy(
      await veStreet.getAddress(),
      THRESHOLD,
      VOTING_PERIOD,
      supervisorAddr,
      PROPOSAL_DELAY,
      QUORUM
    );
    await streetDAO2.waitForDeployment();

    treasury2 = await (await ethers.getContractFactory("Treasury")).deploy(
      await demoUSD.getAddress(),
      "0x0000000000000000000000000000000000000000",
      "0x0000000000000000000000000000000000000000",
      supervisorAddr
    );
    await treasury2.waitForDeployment();

    await (await startupToken.mint(user1Addr, ethers.parseUnits("1000", 18))).wait();
    await (await streetToken.mint(user1Addr, ethers.parseUnits("1000", 18))).wait();
    const latest = await ethers.provider.getBlock("latest");
    const now = BigInt((latest as { timestamp: number }).timestamp);
    await (await startupToken.connect(user1).approve(await veStartup.getAddress(), ethers.parseUnits("100", 18))).wait();
    await (await veStartup.connect(user1).createLock(ethers.parseUnits("100", 18), now + MAX_LOCK)).wait();
    await (await streetToken.connect(user1).approve(await veStreet.getAddress(), ethers.parseUnits("100", 18))).wait();
    await (await veStreet.connect(user1).createLock(ethers.parseUnits("100", 18), now + MAX_LOCK)).wait();
  });

  describe("StreetDAO setTreasury onlyOwner", function () {
    it("non-owner cannot call setTreasury", async function () {
      await expect(
        streetDAO2.connect(user1).setTreasury(await treasury.getAddress())
      ).to.be.revertedWithCustomError(streetDAO2, "OwnableUnauthorizedAccount");
    });

    it("owner can call setTreasury", async function () {
      await (await streetDAO2.connect(deployer).setTreasury(await treasury2.getAddress())).wait();
      expect(await streetDAO2.treasury()).to.equal(await treasury2.getAddress());
    });
  });

  describe("Treasury setDistributor/setStreetDAO onlyOwner", function () {
    it("non-owner cannot call setDistributor on treasury with zero distributor", async function () {
      const treasuryZero = await (await ethers.getContractFactory("Treasury")).deploy(
        await demoUSD.getAddress(),
        "0x0000000000000000000000000000000000000000",
        "0x0000000000000000000000000000000000000000",
        supervisorAddr
      );
      await treasuryZero.waitForDeployment();
      await expect(
        treasuryZero.connect(user1).setDistributor(await distributor.getAddress())
      ).to.be.revertedWithCustomError(treasuryZero, "OwnableUnauthorizedAccount");
    });

    it("non-owner cannot call setStreetDAO on treasury with zero streetDAO", async function () {
      const treasuryZero = await (await ethers.getContractFactory("Treasury")).deploy(
        await demoUSD.getAddress(),
        await distributor.getAddress(),
        "0x0000000000000000000000000000000000000000",
        supervisorAddr
      );
      await treasuryZero.waitForDeployment();
      await expect(
        treasuryZero.connect(user1).setStreetDAO(await streetDAO.getAddress())
      ).to.be.revertedWithCustomError(treasuryZero, "OwnableUnauthorizedAccount");
    });
  });

  describe("Distributor root binding", function () {
    it("swapping merkle root after cert/approval makes round not claimable", async function () {
      await (await demoUSD.mint(await distributor.getAddress(), ethers.parseUnits("10000", 18))).wait();
      const roundId = 99n;
      const leaf1 = ethers.keccak256(
        ethers.AbiCoder.defaultAbiCoder().encode(["address", "uint256"], [user1Addr, ethers.parseUnits("10", 18)])
      );
      await (await distributor.setMerkleRoot(roundId, leaf1)).wait();
      await (await distributor.certifyAsSupervisor(roundId)).wait();
      await (await distributor.connect(counselSigner).certifyAsCounsel(roundId)).wait();
      await (await issuerDAO.connect(user1).proposeApproveRound(roundId, "round 99")).wait();
      const pid = await issuerDAO.proposalCount();
      await mineBlocks(Number(PROPOSAL_DELAY));
      await (await issuerDAO.connect(user1).vote(pid, true)).wait();
      await mineBlocks(Number(VOTING_PERIOD) + 1);
      await (await issuerDAO.execute(pid)).wait();
      expect(await distributor.isRoundClaimable(roundId)).to.equal(true);

      const leaf2 = ethers.keccak256("0xdead");
      await (await distributor.setMerkleRoot(roundId, leaf2)).wait();
      expect(await distributor.isRoundClaimable(roundId)).to.equal(false);
    });
  });

  describe("Proposal delay and vote window", function () {
    it("vote before startBlock reverts with voting not started", async function () {
      const daoWithDelay2 = await (await ethers.getContractFactory("IssuerDAO")).deploy(
        await veStartup.getAddress(),
        await distributor.getAddress(),
        THRESHOLD,
        VOTING_PERIOD,
        2n,
        QUORUM
      );
      await daoWithDelay2.waitForDeployment();
      await (await daoWithDelay2.connect(user1).proposeApproveRound(100n, "r100")).wait();
      const newPid = await daoWithDelay2.proposalCount();
      await expect(daoWithDelay2.connect(user1).vote(newPid, true)).to.be.revertedWith("voting not started");
    });
  });

  describe("Quorum", function () {
    it("execute reverts when quorum not met", async function () {
      const highQuorumDAO = await (await ethers.getContractFactory("IssuerDAO")).deploy(
        await veStartup.getAddress(),
        await distributor.getAddress(),
        THRESHOLD,
        VOTING_PERIOD,
        PROPOSAL_DELAY,
        HIGH_QUORUM
      );
      await highQuorumDAO.waitForDeployment();
      await (await distributor.setGovernanceExecutor(await highQuorumDAO.getAddress())).wait();

      await (await highQuorumDAO.connect(user1).proposeApproveRound(101n, "r101")).wait();
      const pid = await highQuorumDAO.proposalCount();
      await mineBlocks(Number(PROPOSAL_DELAY));
      await (await highQuorumDAO.connect(user1).vote(pid, true)).wait();
      await mineBlocks(Number(VOTING_PERIOD) + 1);
      await expect(highQuorumDAO.execute(pid)).to.be.revertedWith("quorum not met");
    });
  });

  describe("Leaf uses abi.encode", function () {
    it("contract leaf matches AbiCoder.encode keccak256", async function () {
      const account = user1Addr;
      const amount = 12345n;
      const expected = ethers.keccak256(
        ethers.AbiCoder.defaultAbiCoder().encode(["address", "uint256"], [account, amount])
      );
      expect(await distributor.leaf(account, amount)).to.equal(expected);
    });
  });
});
