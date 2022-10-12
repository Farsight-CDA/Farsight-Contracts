// SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "../lib/ERC721/ERC721.sol";
import "../lib/utils/Ownable.sol";
import "../lib/utils/Controllable.sol";
import "../shared/IRegistrar.sol";

/**********\
|* Errors *|
\**********/

error NameExpired();
error NameUnavailable();
error NameRenewingExpired();

contract BaseRegistrar is ERC721, Ownable, Controllable, IRegistar {
    uint256 public constant GRACE_PERIOD = 30 days;

    mapping(address => uint256) _reverseRegistrar; //Only map to "primary" name
    mapping(uint256 => uint256) _expiries;

    constructor() ERC721("Farsight Names", "FAR") {
    }

    /***********\
    |* Getters *|
    \***********/

    // Returns true if the specified name is available for registration.
    function available(uint256 name) public view override returns (bool) {
        // Not available if it's registered here or in its grace period.
        return _expiries[name] + GRACE_PERIOD < block.timestamp;
    }

    // Returns the expiration timestamp of the specified id.
    function nameExpires(uint256 name) external view override returns (uint256) {
        return _expiries[name];
    }

    /**
     * @dev Gets the owner of the specified token ID. Names become unowned
     *      when their registration expires.
     * @param tokenId uint256 ID of the token to query the owner of
     * @return address currently marked as the owner of the given token ID
     */
    function ownerOf(uint256 tokenId) public view override returns (address) {
        if (_expiries[tokenId] <= block.timestamp) { revert NameExpired(); }
        return super.ownerOf(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == type(IRegistrar).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /************************\
    |* Controller Functions *|
    \************************/

    function register(uint256 name, address owner, uint256 duration, bool setPrimary) external override onlyController returns (uint256) {
        if (!available(name)) { revert NameUnavailable(); }
        require(
            block.timestamp + duration + GRACE_PERIOD >
                block.timestamp + GRACE_PERIOD
        ); // Prevent overflow

        _expiries[name] = block.timestamp + duration;

        if (_exists(name)) { 
            // Name was previously owned, and expired
            _burn(name);
        }
        
        _mint(owner, name);

        if (setPrimary || _reverseRegistrar[owner] == 0) {
            _reverseRegistrar[owner] = name; 
        }

        emit NameRegistered(name, owner, _expiries[name]);
        return _expiries[name];
    }

    function renew(uint256 name, uint256 duration) external override onlyController returns (uint256) {
        if(_expiries[name] + GRACE_PERIOD < block.timestamp) { revert NameRenewingExpired(); } // Name must be registered here or in grace period
        require(
            _max(block.timestamp, _expiries[name]) + duration + GRACE_PERIOD > duration + GRACE_PERIOD
        ); // Prevent overflow

        _expiries[name] = _max(block.timestamp, _expiries[name]) + duration;

        emit NameRenewed(name, _expiries[name]);
        return _expiries[name];
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