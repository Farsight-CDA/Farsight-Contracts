//SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "../shared/IRegistrar.sol";

interface ISubRegistrar is IRegistrar {
    function setName(uint256 name, address owner, uint256 expiresAt, uint256 version) external;
}