// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IPauseController {
    function isPaused() external view returns (bool);
}

contract DistributorV1 is Ownable, ReentrancyGuard {
    IERC20 public immutable payoutToken;
    IPauseController public pauseController;

    address public supervisor;
    address public counsel;

    address public governanceExecutor;

    mapping(uint256 => bytes32) public merkleRoots;
    mapping(uint256 => mapping(address => bool)) public hasClaimed;

    mapping(uint256 => bytes32) public daoApprovedRoot;
    mapping(uint256 => bytes32) public supervisorCertifiedRoot;
    mapping(uint256 => bytes32) public counselCertifiedRoot;

    event MerkleRootSet(uint256 indexed roundId, bytes32 root);
    event Claimed(uint256 indexed roundId, address indexed account, uint256 amount);

    event PauseControllerUpdated(address indexed newPauseController);
    event CertifiersUpdated(address indexed supervisor, address indexed counsel);
    event GovernanceExecutorUpdated(address indexed governanceExecutor);

    event RoundApproved(uint256 indexed roundId, bytes32 root, address indexed by);
    event RoundCertified(uint256 indexed roundId, bytes32 root, address indexed by);

    constructor(
        address initialOwner,
        address payoutToken_,
        address pauseController_,
        address supervisor_,
        address counsel_,
        address governanceExecutor_
    ) Ownable(initialOwner) {
        require(payoutToken_ != address(0), "payoutToken=0");
        require(pauseController_ != address(0), "pauseController=0");
        payoutToken = IERC20(payoutToken_);
        pauseController = IPauseController(pauseController_);

        supervisor = supervisor_;
        counsel = counsel_;
        governanceExecutor = governanceExecutor_;
    }

    function setPauseController(address newPauseController) external onlyOwner {
        require(newPauseController != address(0), "pauseController=0");
        pauseController = IPauseController(newPauseController);
        emit PauseControllerUpdated(newPauseController);
    }

    function setCertifiers(address newSupervisor, address newCounsel) external onlyOwner {
        supervisor = newSupervisor;
        counsel = newCounsel;
        emit CertifiersUpdated(newSupervisor, newCounsel);
    }

    function setGovernanceExecutor(address newExecutor) external onlyOwner {
        governanceExecutor = newExecutor;
        emit GovernanceExecutorUpdated(newExecutor);
    }

    function setMerkleRoot(uint256 roundId, bytes32 root) external onlyOwner {
        require(root != bytes32(0), "root=0");
        merkleRoots[roundId] = root;
        emit MerkleRootSet(roundId, root);
    }

    function approveRound(uint256 roundId) external {
        require(msg.sender == governanceExecutor, "not governanceExecutor");
        bytes32 root = merkleRoots[roundId];
        require(root != bytes32(0), "root not set");
        daoApprovedRoot[roundId] = root;
        emit RoundApproved(roundId, root, msg.sender);
    }

    function certifyAsSupervisor(uint256 roundId) external {
        require(msg.sender == supervisor, "not supervisor");
        bytes32 root = merkleRoots[roundId];
        require(root != bytes32(0), "root not set");
        supervisorCertifiedRoot[roundId] = root;
        emit RoundCertified(roundId, root, msg.sender);
    }

    function certifyAsCounsel(uint256 roundId) external {
        require(msg.sender == counsel, "not counsel");
        bytes32 root = merkleRoots[roundId];
        require(root != bytes32(0), "root not set");
        counselCertifiedRoot[roundId] = root;
        emit RoundCertified(roundId, root, msg.sender);
    }

    function isRoundClaimable(uint256 roundId) public view returns (bool) {
        if (pauseController.isPaused()) return false;
        bytes32 root = merkleRoots[roundId];
        if (root == bytes32(0)) return false;
        if (daoApprovedRoot[roundId] != root) return false;
        if (supervisorCertifiedRoot[roundId] != root) return false;
        if (counselCertifiedRoot[roundId] != root) return false;
        return true;
    }

    function leaf(address account, uint256 amount) public pure returns (bytes32) {
        return keccak256(abi.encode(account, amount));
    }

    function claim(uint256 roundId, uint256 amount, bytes32[] calldata proof) external nonReentrant {
        require(isRoundClaimable(roundId), "round not claimable");
        require(!hasClaimed[roundId][msg.sender], "already claimed");
        require(amount > 0, "amount=0");

        bytes32 node = leaf(msg.sender, amount);
        require(MerkleProof.verify(proof, merkleRoots[roundId], node), "bad proof");

        hasClaimed[roundId][msg.sender] = true;

        bool ok = payoutToken.transfer(msg.sender, amount);
        require(ok, "transfer failed");

        emit Claimed(roundId, msg.sender, amount);
    }
}
