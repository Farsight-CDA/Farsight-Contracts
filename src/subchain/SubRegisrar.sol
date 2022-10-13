// SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;


import "../lib/utils/Ownable.sol";
import "../lib/utils/Controllable.sol";
import "./ISubRegistrar.sol";

contract MainRegistrar is Ownable, Controllable, ISubRegistrar {
    /**********\
    |* Errors *|
    \**********/
    error NameExpired();
    error InvalidName();
    error OutdatedVersion(uint256 peakVersion, uint256 providedVersion);

    /**********\
    |* Events *|
    \**********/
    event NameUpdated(uint256 indexed name, uint256 indexed version, uint256 indexed expiry, address owner);

    /***********\
    |* Structs *|
    \***********/
    struct NameMetadata {
        //How often the name was updated (registrations / renewals / transfers)
        uint256 version;
        uint256 expiresAt;
        address owner;
    }



    uint256 public constant GRACE_PERIOD = 30 days;

    mapping(uint256 => NameMetadata) names; 

    /***********\
    |* Getters *|
    \***********/
    function ownerOf(uint256 name) public view override returns (address) {
        if (names[name].expiresAt <= block.timestamp) { revert NameExpired(); }
        if (names[name].owner == address(0)) { revert InvalidName(); }

        return names[name].owner;
    }

    // Returns the expiration timestamp of the specified id.
    function nameExpires(uint256 name) external view returns (uint256) {
        return names[name].expiresAt;
    }

    function nameVersion(uint256 name) external view returns (uint256) {
        return names[name].version;
    }

    function supportsInterface(bytes4 interfaceId) external view returns (bool) {
        return interfaceId == type(IRegistrar).interfaceId;
    }

    /************************\
    |* Controller Functions *|
    \************************/
    
    function setName(uint256 name, address owner, uint256 expiresAt, uint256 version) external onlyController {
        if (version <= names[name].version) { revert OutdatedVersion(names[name].version, version); }

        names[name] = NameMetadata({
            owner: owner,
            expiresAt: expiresAt,
            version: version
        });

        emit NameUpdated(name, version, expiresAt, owner);
    }

    /*******************\
    |* Admin Functions *|
    \*******************/

    // Add / Remove addresses that are allowed to call `onlyController` methods.
    function setController(address controller, bool allowed) external onlyOwner {
        super._setController(controller, allowed);
    }
}