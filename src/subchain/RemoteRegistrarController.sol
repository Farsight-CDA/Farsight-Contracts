//SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "./IRemoteRegistrarController.sol";
import "./ISubRegistrar.sol";
import "../lib/utils/StringAddressUtils.sol";

contract RemoteRegistrarController is IRemoteRegistrarController {
    using StringToAddress for string;

    error OutdatedVersion(uint256 peakVersion, uint256 providedVersion);

    ISubRegistrar immutable registrar;

    constructor(address _axelarGatewayAddress,
                ISubRegistrar _registrar,
                bytes32 _mainChainBytes,
                bytes32 _mainControllerAddressBytes) 
        IAxelarExecutable(_axelarGatewayAddress) 
        IRemoteRegistrarController(_mainChainBytes, _mainControllerAddressBytes)
    {
        registrar = _registrar;
    }

    function _receiveNameUpdate(uint256 name, string memory owner, uint256 expiresAt, uint256 version) internal override {
        registrar.setName(name, owner.toAddress(), expiresAt, version);
    }
}

