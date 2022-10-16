//SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

interface IRegistrarController {
    function hasCommitment(bytes32 commitment) external view returns (bool);
    function commit(bytes32 commitment) external; 
    function register(string calldata plainName, address owner, uint256 duration, bytes32 secret) external payable returns (uint256);
    function renew(string calldata plainName, uint256 duration) external payable returns (uint256);

    function receiveName(uint256 name, uint64 registrationVersion, uint64 ownerChangeVersion, uint256 expiration, address owner) external;
    function receiveExpirationInfo(uint256 name, uint64 registrationVersion, uint64 ownerChangeVersion, uint256 expiration) external;
}