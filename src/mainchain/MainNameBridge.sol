//SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "../shared/BaseNameBridge.sol";
import "./IMainNameBridge.sol";
import "./IMainRegistrarController.sol";
import "../lib/Axelar/IAxelarExecutable.sol";
import "../lib/Axelar/IAxelarGasService.sol";
import "../lib/Axelar/IAxelarGateway.sol";

contract MainNameBridge is BaseNameBridge, IMainNameBridge {
    IMainRegistrarController private immutable mainRegistrarController;

    constructor(IAxelarGateway _axelarGateway,
                IAxelarGasService _axelarGasService,
                IMainRegistrarController _mainRegistrarController) 
        BaseNameBridge(_axelarGateway, _axelarGasService, _mainRegistrarController)            
    {
        mainRegistrarController = _mainRegistrarController;
    }

    function _handleMessageType(string memory chainName, uint256 messageType, bytes memory innerMessage) internal override {
        uint256 name;
        uint256 duration;

        if (messageType == BridgeRegisterRequestMessageType) {
            string memory plainName;
            string memory owner;

            (plainName, name, owner, duration) = abi.decode(innerMessage, (string, uint256, string, uint256));
            mainRegistrarController.receiveRegisterRequest(chainName, plainName, name, owner, duration);
        } else if (messageType == BridgeRenewRequestMessageType) {
            uint64 registrationVersion;

            (name, registrationVersion, duration) = abi.decode(innerMessage, (uint256, uint64, uint256));
            mainRegistrarController.receiveRenewRequest(chainName, name, registrationVersion, duration); //Reverts if unsuccessful
        } else {
            assert(false);
        }
    }

    function bridgeRenewalSuccess(string calldata chainName, uint256 name, uint256 newExpiration) public payable onlyController
    {
        if (!chainDefinitions[chainName].isValid) { revert UnsupportedOrInvalidChain(chainName); }

        bytes memory payload = abi.encode(BridgeRenewSuccessMessageType, abi.encode(name, newExpiration));

        if(msg.value > 0) {
          // The line below is where we pay the gas fee
          axelarGasService.payNativeGasForContractCall{value: msg.value}(
              address(this),
              chainName, 
              chainDefinitions[chainName].targetBridgeAddress, 
              payload,
              msg.sender
          );
        }

        axelarGateway.callContract(
            chainName, 
            chainDefinitions[chainName].targetBridgeAddress, 
            payload
        );
    }

}