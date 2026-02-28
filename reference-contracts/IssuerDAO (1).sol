// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVeTokenLike {
    function balanceOf(address account) external view returns (uint256);
}

interface IDistributorV1 {
    function approveRound(uint256 roundId) external;
}

contract IssuerDAO {
    IVeTokenLike public immutable veStartup;
    IDistributorV1 public immutable distributor;

    uint256 public proposalThreshold;
    uint256 public votingPeriod;
    uint256 public proposalDelay;
    uint256 public quorum;
    uint256 public proposalCount;

    struct Proposal {
        uint256 roundId;
        string description;
        uint256 startBlock;
        uint256 endBlock;
        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event Proposed(uint256 indexed proposalId, uint256 indexed roundId, address indexed proposer);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event Executed(uint256 indexed proposalId, uint256 indexed roundId);

    constructor(
        address veStartup_,
        address distributor_,
        uint256 proposalThreshold_,
        uint256 votingPeriod_,
        uint256 proposalDelay_,
        uint256 quorum_
    ) {
        require(veStartup_ != address(0), "veStartup=0");
        require(distributor_ != address(0), "distributor=0");
        require(votingPeriod_ > 0, "votingPeriod=0");
        require(quorum_ > 0, "quorum=0");
        veStartup = IVeTokenLike(veStartup_);
        distributor = IDistributorV1(distributor_);

        proposalThreshold = proposalThreshold_;
        votingPeriod = votingPeriod_;
        proposalDelay = proposalDelay_;
        quorum = quorum_;
    }

    function proposeApproveRound(uint256 roundId, string calldata description) external returns (uint256) {
        require(veStartup.balanceOf(msg.sender) >= proposalThreshold, "below threshold");

        proposalCount += 1;
        uint256 id = proposalCount;

        uint256 startBlock = block.number + proposalDelay;
        uint256 endBlock = startBlock + votingPeriod;

        proposals[id] = Proposal({
            roundId: roundId,
            description: description,
            startBlock: startBlock,
            endBlock: endBlock,
            votesFor: 0,
            votesAgainst: 0,
            executed: false
        });

        emit Proposed(id, roundId, msg.sender);
        return id;
    }

    function vote(uint256 proposalId, bool support) external {
        Proposal storage p = proposals[proposalId];
        require(p.startBlock != 0, "no proposal");
        require(block.number >= p.startBlock, "voting not started");
        require(block.number <= p.endBlock, "voting ended");
        require(!hasVoted[proposalId][msg.sender], "already voted");

        uint256 weight = veStartup.balanceOf(msg.sender);
        require(weight > 0, "no voting power");

        hasVoted[proposalId][msg.sender] = true;

        if (support) p.votesFor += weight;
        else p.votesAgainst += weight;

        emit Voted(proposalId, msg.sender, support, weight);
    }

    function execute(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        require(p.startBlock != 0, "no proposal");
        require(block.number > p.endBlock, "voting not ended");
        require(!p.executed, "already executed");
        require(p.votesFor > p.votesAgainst, "did not pass");
        require(p.votesFor + p.votesAgainst >= quorum, "quorum not met");

        p.executed = true;

        distributor.approveRound(p.roundId);

        emit Executed(proposalId, p.roundId);
    }
}
