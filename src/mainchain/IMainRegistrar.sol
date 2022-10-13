//SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "../shared/IRegistrar.sol";

interface IMainRegistrar is IRegistrar {
    // Returns true if the specified name is available for registration.
    function available(uint256 name) external view returns (bool);

    /** 
     * @dev Registers a name for a given owner with a given duration. 
     *      Optionally allows for settings the new name as primary name for the address.
     * @param name The name to register.
     * @param owner The address that should own the registration.
     * @param duration Duration in seconds that the registration should be valid for.
     * @return uint256 Timestamp at which the registration expires.
     */ 
    function register(uint256 name, address owner, uint256 duration) external returns (uint256);

    /**
     * @dev Renews a name for the current owner if the registration is still valid or in grace period.
     * @param name The name to renew.
     * @param duration The duration in seconds to extend the registration for.
     * @return uint256 Timestamp at which the renewed registration expires.
     */
    function renew(uint256 name, uint256 duration) external returns (uint256);
}