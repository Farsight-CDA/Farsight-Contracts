//SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "../shared/BaseNameBridge.sol";
import "./ISubNameBridge.sol";
import "./ISubRegistrarController.sol";
import "../lib/Axelar/IAxelarExecutable.sol";
import "../lib/Axelar/IAxelarGasService.sol";
import "../lib/Axelar/IAxelarGateway.sol";

contract SubNameBridge is BaseNameBridge, ISubNameBridge {
    ISubRegistrarController private immutable subRegistrarController;

    string mainChainName;

    constructor(IAxelarGateway _axelarGateway,
                IAxelarGasService _axelarGasService,
                ISubRegistrarController _subRegistrarController,
                string memory _mainChainName) 
        BaseNameBridge(_axelarGateway, _axelarGasService, _subRegistrarController)            
    {
        subRegistrarController = _subRegistrarController;
        mainChainName = _mainChainName;
    }

    function _handleMessageType(string memory, uint256 messageType, bytes memory innerMessage) internal override {
        uint256 name;
        uint256 newExpiration;

        if (messageType == 2) {
            (name, newExpiration) = abi.decode(innerMessage, (uint256, uint256));
            subRegistrarController.receiveRenewSuccess(name, newExpiration);
        }

        assert(false);
    }

    function bridgeRegisterRequest(string calldata plainName, uint256 name, address owner, uint256 duration, uint256 expiration) external payable onlyController {
        if (!chainDefinitions[mainChainName].isValid) { revert UnsupportedOrInvalidChain(mainChainName); }
        bytes memory payload = abi.encode(0, abi.encode(plainName, name, owner, duration, expiration));

        if(msg.value > 0) {
          // The line below is where we pay the gas fee
          axelarGasService.payNativeGasForContractCall{value: msg.value}(
              address(this),
              mainChainName, 
              chainDefinitions[mainChainName].targetBridgeAddress, 
              payload,
              msg.sender
          );
        }

        axelarGateway.callContract(
            mainChainName, 
            chainDefinitions[mainChainName].targetBridgeAddress, 
            payload
        );
    }

    function bridgeRenewalRequest(uint256 name, uint64 registrationVersion, uint256 duration, uint256 expiration) external payable onlyController {
        if (!chainDefinitions[mainChainName].isValid) { revert UnsupportedOrInvalidChain(mainChainName); }
        bytes memory payload = abi.encode(1, abi.encode(name, registrationVersion, duration, expiration));

        if(msg.value > 0) {
          // The line below is where we pay the gas fee
          axelarGasService.payNativeGasForContractCall{value: msg.value}(
              address(this),
              mainChainName, 
              chainDefinitions[mainChainName].targetBridgeAddress, 
              payload,
              msg.sender
          );
        }

        axelarGateway.callContract(
            mainChainName, 
            chainDefinitions[mainChainName].targetBridgeAddress, 
            payload
        );
    }
}