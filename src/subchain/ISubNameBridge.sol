//SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "../shared/INameBridge.sol";

interface ISubNameBridge is INameBridge {
    function bridgeRegisterRequest(string calldata plainName, uint256 name, address owner, uint256 duration) external payable;
    function bridgeRenewalRequest(uint256 name, uint64 registrationVersion, uint256 duration) external payable;
}