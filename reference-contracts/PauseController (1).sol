// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract PauseController {
    address public supervisor;
    address public counsel;
    bool private _paused;

    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event RolesUpdated(address indexed supervisor, address indexed counsel);

    modifier onlySupervisorOrCounsel() {
        require(msg.sender == supervisor || msg.sender == counsel, "not authorized");
        _;
    }

    constructor(address _supervisor, address _counsel) {
        require(_supervisor != address(0) && _counsel != address(0), "zero address");
        supervisor = _supervisor;
        counsel = _counsel;
        emit RolesUpdated(_supervisor, _counsel);
    }

    function pause() external onlySupervisorOrCounsel {
        require(!_paused, "already paused");
        _paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlySupervisorOrCounsel {
        require(_paused, "not paused");
        _paused = false;
        emit Unpaused(msg.sender);
    }

    function isPaused() external view returns (bool) {
        return _paused;
    }

    function setRoles(address _supervisor, address _counsel) external onlySupervisorOrCounsel {
        require(_supervisor != address(0) && _counsel != address(0), "zero address");
        supervisor = _supervisor;
        counsel = _counsel;
        emit RolesUpdated(_supervisor, _counsel);
    }
}
