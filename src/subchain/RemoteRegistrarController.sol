//SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "./IRemoteRegistrarController.sol";
import "./ISubRegistrar.sol";

contract RemoteRegistrarController is IRemoteRegistrarController {
    error OutdatedVersion(uint256 peakVersion, uint256 providedVersion);

    ISubRegistrar immutable registrar;

    constructor(address _axelarGatewayAddress,
                ISubRegistrar _registrar) 
        IAxelarExecutable(_axelarGatewayAddress) 
    {
        registrar = _registrar;
    }

    function _receiveNameUpdate(uint256 name, string memory owner, uint256 expiresAt, uint256 version) internal override {
        _registrar.setName(name, owner, expiresAt, version);
    }
}

