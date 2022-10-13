//SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "./IRemoteRegistrarController.sol";

contract RemoteRegistrarController is IRemoteRegistrarController {
    error OutdatedVersion(uint256 peakVersion, uint256 providedVersion);

    mapping(uint256 => uint256) peakNameVersion;

    constructor(address axelarGatewayAddress) 
        IAxelarExecutable(axelarGatewayAddress) 
    {
    }

    function receiveNameUpdate(uint256 name, string memory owner, uint256 expiresAt, uint256 version) internal override {
        if (version <= peakNameVersion[name]) { revert OutdatedVersion(peakNameVersion[name], version); }


    }
}

