//SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

interface IRegistrar {
    function ownerOf(uint256 tokenId) external view returns (address);

    // Returns the expiration timestamp of the specified name.
    function nameExpires(uint256 name) external view returns (uint256);

    function nameVersion(uint256 name) external view returns (uint256);
}