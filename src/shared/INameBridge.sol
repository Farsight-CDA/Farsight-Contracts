//SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

interface INameBridge {
    //Bridge a name to a different chain
    function bridgeNameTo(string calldata chainName, uint256 name, uint64 registrationVersion, uint64 ownerChangeVersion, 
                          uint256 expiration, string calldata targetOwner) external payable;

    //Sends expiration info from keeper to other chain with same versions
    function bridgeExpirationInfoTo(string calldata chainName, uint256 name, uint64 registrationVersion, uint64 ownerChangeVersion,
                                    uint256 expiration) external payable;
}