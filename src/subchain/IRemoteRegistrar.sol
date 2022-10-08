// SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "../shared/IRegistrar.sol";

interface IRemoteRegistar is IRegistrar {
    function updateRegistration(uint256 callId, uint256 name, address owner, uint256 expiration, bool updateReverseEntry) external;
    function updateReverseEntry(uint256 callId, address owner, uint256 name) external;
    function updateExpiration(uint256 callId, uint256 name, uint256 expiration) external;
}