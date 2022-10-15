// SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "../shared/IRegistrarController.sol";

interface IMainRegistrarController is IRegistrarController {
    function receiveRegisterRequest(string memory sourceChain, string calldata plainName, uint256 name, string calldata owner, uint256 duration, uint256 expiration) external;
    function receiveRenewRequest(string memory sourceChain, uint256 name, uint64 registrationVersion, uint256 duration, uint256 expiration) external;        
}