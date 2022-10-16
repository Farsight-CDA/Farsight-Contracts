//SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "../shared/IRegistrar.sol";
import "./IMainNameBridge.sol";

interface IMainRegistrar is IRegistrar {
    function getNameBridge() external view returns (IMainNameBridge);
    // Returns true if the specified name is available for registration.
    function available(uint256 name) external view returns (bool);

    function lookupPlainName(uint256 name) external view returns (string memory);

    function register(string memory plainName, uint256 name, address owner, uint256 duration) external returns (uint256);

    function renew(uint256 name, uint64 registrationVersion, uint256 duration) external returns (uint256);
}