// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IVeTokenLike {
    function balanceOf(address account) external view returns (uint256);
}

interface ITreasury {
    function withdraw(address to, uint256 amount) external;
}

contract StreetDAO is Ownable, ReentrancyGuard {
    IVeTokenLike public immutable veStreet;
    ITreasury public treasury;

    uint256 public proposalThreshold;
    uint256 public votingPeriod;
    uint256 public proposalDelay;
    uint256 public quorum;
    uint256 public proposalCount;

    struct Proposal {
        address to;
        uint256 amount;
        string description;
        uint256 startBlock;
        uint256 endBlock;
        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event TreasurySet(address indexed treasury);
    event Proposed(uint256 indexed proposalId, address indexed proposer, address to, uint256 amount);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event Executed(uint256 indexed proposalId, address to, uint256 amount);

    constructor(
        address veStreet_,
        uint256 proposalThreshold_,
        uint256 votingPeriod_,
        address initialOwner_,
        uint256 proposalDelay_,
        uint256 quorum_
    ) Ownable(initialOwner_) {
        require(veStreet_ != address(0), "veStreet=0");
        require(votingPeriod_ > 0, "votingPeriod=0");
        require(initialOwner_ != address(0), "owner=0");
        require(quorum_ > 0, "quorum=0");
        veStreet = IVeTokenLike(veStreet_);
        proposalThreshold = proposalThreshold_;
        votingPeriod = votingPeriod_;
        proposalDelay = proposalDelay_;
        quorum = quorum_;
    }

    function setTreasury(address treasury_) external onlyOwner {
        require(treasury_ != address(0), "treasury=0");
        require(address(treasury) == address(0), "treasury already set");
        treasury = ITreasury(treasury_);
        emit TreasurySet(treasury_);
    }

    function proposeWithdraw(address to, uint256 amount, string calldata description) external returns (uint256) {
        require(address(treasury) != address(0), "treasury not set");
        require(veStreet.balanceOf(msg.sender) >= proposalThreshold, "below threshold");
        require(to != address(0), "to=0");
        require(amount > 0, "amount=0");

        proposalCount += 1;
        uint256 id = proposalCount;

        uint256 startBlock = block.number + proposalDelay;
        uint256 endBlock = startBlock + votingPeriod;

        proposals[id] = Proposal({
            to: to,
            amount: amount,
            description: description,
            startBlock: startBlock,
            endBlock: endBlock,
            votesFor: 0,
            votesAgainst: 0,
            executed: false
        });

        emit Proposed(id, msg.sender, to, amount);
        return id;
    }

    function vote(uint256 proposalId, bool support) external {
        Proposal storage p = proposals[proposalId];
        require(p.startBlock != 0, "no proposal");
        require(block.number >= p.startBlock, "voting not started");
        require(block.number <= p.endBlock, "voting ended");
        require(!hasVoted[proposalId][msg.sender], "already voted");

        uint256 weight = veStreet.balanceOf(msg.sender);
        require(weight > 0, "no voting power");

        hasVoted[proposalId][msg.sender] = true;

        if (support) p.votesFor += weight;
        else p.votesAgainst += weight;

        emit Voted(proposalId, msg.sender, support, weight);
    }

    function execute(uint256 proposalId) external nonReentrant {
        Proposal storage p = proposals[proposalId];
        require(p.startBlock != 0, "no proposal");
        require(block.number > p.endBlock, "voting not ended");
        require(!p.executed, "already executed");
        require(p.votesFor > p.votesAgainst, "did not pass");
        require(p.votesFor + p.votesAgainst >= quorum, "quorum not met");

        p.executed = true;

        treasury.withdraw(p.to, p.amount);

        emit Executed(proposalId, p.to, p.amount);
    }
}
