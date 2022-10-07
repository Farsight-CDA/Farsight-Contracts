// SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

interface IRegistrarController {
    function commit(bytes32 commitment) external; 
    function register(uint256 name, address owner, uint256 duration, bytes32 secret, bool setPrimary) external returns (uint256);
}