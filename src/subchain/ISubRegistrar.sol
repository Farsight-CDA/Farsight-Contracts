//SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "../shared/IRegistrar.sol";
import "./ISubNameBridge.sol";

interface ISubRegistrar is IRegistrar {
    function getNameBridge() external view returns (ISubNameBridge);
    function isTransferLocked(uint256 name) external view returns (bool);
    function applyTransferLock(uint256 name) external;
    function releaseTransferLock(uint256 name) external;
}