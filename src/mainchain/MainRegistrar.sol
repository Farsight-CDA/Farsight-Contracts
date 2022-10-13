// SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "../lib/ERC721/ERC721.sol";
import "../lib/utils/Ownable.sol";
import "../lib/utils/Controllable.sol";
import "./IMainRegistrar.sol";

contract MainRegistrar is ERC721, Ownable, Controllable, IMainRegistrar {
    /**********\
    |* Errors *|
    \**********/
    error NameExpired();
    error NameUnavailable();
    error NameRenewingExpired();

    /**********\
    |* Events *|
    \**********/
    event NameRegistered(uint256 indexed name, uint256 indexed version, uint256 indexed expiration, address owner);
    event NameRenewed(uint256 indexed name, uint256 indexed version, uint256 expiration);

    /***********\
    |* Structs *|
    \***********/
    struct NameMetadata {
        //How often the name was updated (registrations / renewals / transfers)
        uint256 version;
        uint256 expiresAt;
    }


    uint256 public constant GRACE_PERIOD = 30 days;

    mapping(uint256 => NameMetadata) names; 

    constructor() ERC721("Farsight Names", "FAR") {
    }

    /********************\
    |* ERC721 Overrides *|
    \********************/

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view override returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner ||
            getApproved(tokenId) == spender ||
            isApprovedForAll(owner, spender));
    }
    
    /**
     * @dev Gets the owner of the specified token ID. Names become unowned
     *      when their registration expires.
     * @param tokenId uint256 ID of the token to query the owner of
     * @return address currently marked as the owner of the given token ID
     */
    function ownerOf(uint256 tokenId) public view override(ERC721, IRegistrar) returns (address) {
        if (names[tokenId].expiresAt <= block.timestamp) { revert NameExpired(); }
        return super.ownerOf(tokenId);
    }

    function _afterTokenTransfer(address from, address to, uint256 tokenId) internal override {
        //Mints and burns are handled in register
        if (from == address(0) || to == address(0)) { 
            return;
        }

        names[tokenId].version += 1;
    }

    /***********\
    |* Getters *|
    \***********/

    // Returns true if the specified name is available for registration.
    function available(uint256 name) public view override returns (bool) {
        // Not available if it's registered here or in its grace period.
        return names[name].expiresAt + GRACE_PERIOD < block.timestamp;
    }

    // Returns the expiration timestamp of the specified id.
    function nameExpires(uint256 name) external view override returns (uint256) {
        return names[name].expiresAt;
    }

    function nameVersion(uint256 name) external view returns (uint256) {
        return names[name].version;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == type(IRegistrar).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /************************\
    |* Controller Functions *|
    \************************/

    function register(uint256 name, address owner, uint256 duration) external override onlyController returns (uint256) {
        if (!available(name)) { revert NameUnavailable(); }
        require(
            block.timestamp + duration + GRACE_PERIOD >
                block.timestamp + GRACE_PERIOD
        ); // Prevent overflow

        names[name].version += 1;
        names[name].expiresAt = block.timestamp + duration;

        if (_exists(name)) { 
            // Name was previously owned, and expired
            _burn(name);
        }
        
        _mint(owner, name);

        emit NameRegistered(name, names[name].version, names[name].expiresAt, owner);
        return names[name].expiresAt;
    }

    function renew(uint256 name, uint256 duration) external override onlyController returns (uint256) {
        if(names[name].expiresAt + GRACE_PERIOD < block.timestamp) { revert NameRenewingExpired(); } // Name must be registered here or in grace period
        require(
            _max(block.timestamp, names[name].expiresAt) + duration + GRACE_PERIOD > duration + GRACE_PERIOD
        ); // Prevent overflow

        names[name].version += 1;
        names[name].expiresAt = _max(block.timestamp, names[name].expiresAt) + duration;

        emit NameRenewed(name, names[name].version, names[name].expiresAt);
        return names[name].expiresAt;
    }

    /*******************\
    |* Admin Functions *|
    \*******************/

    // Add / Remove addresses that are allowed to call `onlyController` methods.
    function setController(address controller, bool allowed) external onlyOwner {
        super._setController(controller, allowed);
    }

    /**********************\
    |* Internal Functions *|
    \**********************/

    // Returns the larger of two numbers
    function _max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }
}