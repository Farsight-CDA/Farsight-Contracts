//SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "../lib/ERC721/IERC721.sol";
import "./INameBridge.sol";

interface IRegistrar is IERC721 {
    //If isKeeper returns ownerOf, if not it returns whatever was set from the keeper last time
    function getLocalOwnerOf(uint256 name) external view returns (address);
    // Returns the expiration timestamp of the specified name.
    function getNameExpiration(uint256 name) external view returns (uint256);
    function isKeeper(uint256 name) external view returns (bool);

    function getRegistrationVersion(uint256 name) external view returns (uint64);
    function getOwnerChangeVersion(uint256 name) external view returns (uint64);

    function incrementOwnerVersion(uint256 name) external;

    function bridgeNameTo(string calldata chainName, uint256 name, string calldata targetOwner) external payable;
    //Permissionless briding of expiration timestamp. Only executable if registrar isKeeper for the name.
    function bridgeExpirationInfoTo(string calldata chainName, uint256 name) external payable;
    function bridgeLocalOwnerTo(string calldata chainName, uint256 name, string calldata targetLocalOwner) external payable;

    //Called from authed controller / bridge
    function receiveName(uint256 name, uint64 registrationVersion, uint64 ownerChangeVersion, uint256 expiration, address owner) external;
    //Called from authed controller / bridge
    function receiveExpirationInfo(uint256 name, uint64 registrationVersion, uint64 ownerChangeVersion, uint256 expiration) external;
    function receiveLocalOwner(uint256 name, uint64 registrationVersion, uint64 ownerChangeVersion, uint256 expiration, address localOwner) external;

    function unsafeSetExpiration(uint256 name, uint256 expiration) external;
}