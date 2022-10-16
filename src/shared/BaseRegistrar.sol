// SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "../lib/ERC721/ERC721.sol";
import "../lib/utils/Ownable.sol";
import "./IRegistrar.sol";
import "./INameBridge.sol";
import "../lib/utils/StringAddressUtils.sol";
import "../lib/utils/Controllable.sol";

abstract contract BaseRegistrar is ERC721, Ownable, Controllable, IRegistrar {
    using StringToAddress for string;

    /**********\
    |* Errors *|
    \**********/
    error InvalidName();
    error NameExpired();
    error MustBeApprovedOrOwner();
    error MustBeKeeperChain();

    /***********\
    |* Structs *|
    \***********/
    struct NameInfo {
        //The timestamp at which this name expires / expired.
        uint256 expiration;
        //Incremented each time this name is newly registered
        //If this number is lower than the maximum the registrar entry has to be ignored.
        uint64 registrationVersion;
        //Incremented each time this name switches owner.
        //This number is only relevant within the same registrationVersion.
        uint64 ownerChangeVersion;
        //Whether or not this is currently 
        bool isKeeper;
        //The localOwner if isKeeper is false
        address localOwner;
    }

    /**********\
    |* Events *|
    \**********/
    event BaseURIChanged(string indexed previous, string current);

    uint256 public constant GRACE_PERIOD = 30 days;

    mapping(uint256 => NameInfo) nameInfos;

    string baseURI;

    constructor()
        ERC721("Farsight Names", "FAR") 
    {
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

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override {
        if (to == address(0)) {
            return;
        }
        
        nameInfos[tokenId].localOwner = to;

        if (from == address(0)) {
            return;
        }

        nameInfos[tokenId].ownerChangeVersion += 1;
    }
    
    function ownerOf(uint256 name) public view override(ERC721, IERC721) returns (address) {
        if (nameInfos[name].expiration <= block.timestamp) { revert NameExpired(); }
        return super.ownerOf(name);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    /***********\
    |* Getters *|
    \***********/
    function getLocalOwnerOf(uint256 name) external view returns (address) {
        if (nameInfos[name].localOwner == address(0)) { revert InvalidName(); }
        if (nameInfos[name].expiration <= block.timestamp) { revert NameExpired(); }

        return nameInfos[name].isKeeper
            ? super.ownerOf(name)
            : nameInfos[name].localOwner;
    }

    // Returns the expiration timestamp of the specified id.
    function getNameExpiration(uint256 name) external view returns (uint256) {
        return nameInfos[name].expiration;
    }

    function isKeeper(uint256 name) public view returns(bool) {
        return nameInfos[name].isKeeper && nameInfos[name].expiration + GRACE_PERIOD > block.timestamp;
    }

    function getOwnerChangeVersion(uint256 name) external view returns (uint64) {
        return nameInfos[name].ownerChangeVersion;
    }

    function getRegistrationVersion(uint256 name) external view returns (uint64) {
        return nameInfos[name].registrationVersion;
    } 

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, IERC165) returns (bool) {
        return
            interfaceId == type(IRegistrar).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /***********\
    |* Setters *|
    \***********/ 
    function bridgeNameTo(string calldata chainName, uint256 name, string calldata targetOwner) external payable {
        if (!_isApprovedOrOwner(msg.sender, name)) { revert MustBeApprovedOrOwner(); } //This is false if not isKeeper

        _burn(name);
        nameInfos[name].isKeeper = false;
        nameInfos[name].ownerChangeVersion += 1;

        //Reverts if bridging fails
        _nameBridge().bridgeNameTo{value: msg.value}(
            chainName, 
            name, 
            nameInfos[name].registrationVersion, 
            nameInfos[name].ownerChangeVersion, 
            nameInfos[name].expiration, 
            targetOwner
        ); 
    }

    function bridgeExpirationInfoTo(string calldata chainName, uint256 name) external payable {
        if (nameInfos[name].expiration <= block.timestamp) { revert NameExpired(); }
        if (!nameInfos[name].isKeeper) { revert MustBeKeeperChain(); }

        //Reverts if bridging fails
        _nameBridge().bridgeExpirationInfoTo{value: msg.value}(
            chainName, 
            name, 
            nameInfos[name].registrationVersion, 
            nameInfos[name].ownerChangeVersion, 
            nameInfos[name].expiration
        );
    }

    /************************\
    |* Controller Functions *|
    \************************/
    function receiveName(uint256 name, uint64 registrationVersion, uint64 ownerChangeVersion, uint256 expiration, address owner) external onlyController {
        require(expiration + GRACE_PERIOD > block.timestamp); //Prevent transfer delay being longer than grace period
        
        assert(nameInfos[name].registrationVersion < registrationVersion ||
              (nameInfos[name].registrationVersion == registrationVersion) && nameInfos[name].ownerChangeVersion < ownerChangeVersion); 

        if (_exists(name)) { 
            // Name was previously owned, and expired
            _burn(name);
        }

        _mint(owner, name);

        nameInfos[name] = NameInfo({
            expiration: expiration,
            registrationVersion: registrationVersion,
            ownerChangeVersion: ownerChangeVersion, //Incremented on sender side
            isKeeper: true,
            localOwner: owner
        });
    }

    function receiveExpirationInfo(uint256 name, uint64 registrationVersion, uint64 ownerChangeVersion, uint256 expiration) external onlyController {
        require(nameInfos[name].registrationVersion == registrationVersion);
        require(nameInfos[name].ownerChangeVersion == ownerChangeVersion);
        require(expiration > block.timestamp); //Updating only useful if still valid
        require(expiration > nameInfos[name].expiration); //Cannot be used to lower expiration
        //If name isKeeper than it must be expired! Can be triggered if transfer is executed before expirationInfo send
        require(!nameInfos[name].isKeeper || nameInfos[name].expiration + GRACE_PERIOD < block.timestamp);

        nameInfos[name].expiration = expiration;
    }

    function unsafeSetExpiration(uint256 name, uint256 expiration) external onlyController {
        nameInfos[name].expiration = expiration;
    }

    /*******************\
    |* Admin Functions *|
    \*******************/
    function setBaseURI(string calldata _newBaseURI) external onlyOwner {
        emit BaseURIChanged(baseURI, _newBaseURI);
        baseURI = _newBaseURI;
    }
    
    // Add / Remove addresses that are allowed to call `onlyController` methods.
    function setController(address controller, bool allowed) external onlyOwner {
        super._setController(controller, allowed);
    }

    /**********************\
    |* Abstract Functions *|
    \**********************/
    function _nameBridge() internal view virtual returns (INameBridge);
}