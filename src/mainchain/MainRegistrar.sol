// SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "./IMainRegistrar.sol";
import "../shared/BaseRegistrar.sol";
import "../shared/INameBridge.sol";

contract MainRegistrar is BaseRegistrar, IMainRegistrar {
    /**********\
    |* Errors *|
    \**********/
    error NameUnavailable();

    mapping(uint256 => string) plainNames;

    IMainNameBridge mainNameBridge;

    constructor(IMainNameBridge _mainNameBridge) 
        BaseRegistrar()
    {
        mainNameBridge = _mainNameBridge;
    }

    /***********\
    |* Getters *|
    \***********/
    function getNameBridge() external view returns (IMainNameBridge) {
        return mainNameBridge;
    }
    // Returns true if the specified name is available for registration.
    function available(uint256 name) public view override returns (bool) {
        // Not available if it's registered here or in its grace period.
        return nameInfos[name].expiration + GRACE_PERIOD < block.timestamp;
    }

    function lookupPlainName(uint256 name) external view returns (string memory) {
        return plainNames[name];
    }

    /************************\
    |* Controller Functions *|
    \************************/
    function register(string calldata plainName, uint256 name, address owner, uint256 expiration) external onlyController {
        if (!available(name)) { revert NameUnavailable(); }
        require(
            expiration + GRACE_PERIOD >
                block.timestamp + GRACE_PERIOD
        ); // Prevent overflow

        nameInfos[name] = NameInfo({
            expiration: expiration,
            registrationVersion: nameInfos[name].registrationVersion + 1,
            ownerChangeVersion: 0,
            isKeeper: true,
            localOwner: owner
        });

        plainNames[name] = plainName;

        if (_exists(name)) { 
            // Name was previously owned, and expired
            _burn(name);
        }
        
        _mint(owner, name);
    }

    function renew(uint256 name, uint64 registrationVersion, uint256 expiration) external onlyController {
        require (nameInfos[name].registrationVersion == registrationVersion);
        if (available(name)) { revert NameExpired(); }

        nameInfos[name].expiration = expiration;
    }

    /**********************\
    |* Internal Functions *|
    \**********************/

    // Returns the larger of two numbers
    function _max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    function _nameBridge() internal view override returns (INameBridge) {
        return mainNameBridge;
    }
}