//SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "../lib/Axelar/IAxelarExecutable.sol";

abstract contract IRemoteRegistrarController is IAxelarExecutable {
    error UnauthorizedSourceChain();
    error UnauthorizedSourceAddress();
    
    bytes32 mainChainBytes;
    bytes32 mainControllerAddressBytes;

    constructor(bytes32 _mainChainBytes,
                bytes32 _mainControllerAddressBytes) {
        mainChainBytes = _mainChainBytes;
        mainControllerAddressBytes = _mainControllerAddressBytes;
    }

    function _execute(string memory sourceChain, string memory sourceAddress, bytes calldata payload) override virtual internal {
        if (keccak256(bytes(sourceChain)) != mainChainBytes) { revert UnauthorizedSourceChain(); }
        if (keccak256(bytes(sourceAddress)) != mainControllerAddressBytes) { revert UnauthorizedSourceAddress(); }

        (uint256 name, string memory owner, uint256 expiresAt, uint256 version) = abi.decode(payload, (uint256, string, uint256, uint256));
        receiveNameUpdate(name, owner, expiresAt, version);
    }

    function _receiveNameUpdate(uint256 name, string memory owner, uint256 expiresAt, uint256 version) internal virtual;
}