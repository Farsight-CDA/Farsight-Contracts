//SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "../lib/utils/Ownable.sol";
import "../lib/utils/Controllable.sol";
import "../lib/Axelar/IAxelarExecutable.sol";
import "../lib/Axelar/IAxelarGasService.sol";
import "../lib/Axelar/IAxelarGateway.sol";
import "./IRegistrarController.sol";
import "../lib/utils/StringAddressUtils.sol";
import "./INameBridge.sol";

abstract contract BaseNameBridge is IAxelarExecutable, Ownable, Controllable, INameBridge {
    using StringToAddress for string;

    /**********\
    |* Errors *|
    \**********/
    error DuplicateChainAddition(string chainName);
    error UnsupportedOrInvalidChain(string chainName);
    error ChainNotAtGivenIndex(string chainName, uint256 index);

    /**********\
    |* Events *|
    \**********/
    event ChainAdded(string indexed chainName, string indexed targetBridgeAddress);
    event ChainRemoved(string indexed chainName);

    /***********\
    |* Structs *|
    \***********/
    struct ChainDefinition {
        bool isValid;
        string targetBridgeAddress;
    }
    
    IAxelarGateway internal immutable axelarGateway;
    IAxelarGasService internal immutable axelarGasService;
    IRegistrarController private immutable registrarController;

    string[] public supportedChains;
    mapping(string => ChainDefinition) public chainDefinitions;

    constructor(IAxelarGateway _axelarGateway,
                IAxelarGasService _axelarGasService,
                IRegistrarController _registrarController) 
        IAxelarExecutable(address(_axelarGateway))            
    {
        axelarGateway = _axelarGateway;
        axelarGasService = _axelarGasService;
        registrarController = _registrarController;
    }

    /*********************\
    |* Bridged Functions *|
    \*********************/

    function _execute(
        string memory sourceChain,
        string memory sourceAddress,
        bytes calldata payload
    ) internal override {
        require(chainDefinitions[sourceChain].isValid);
        require(keccak256(bytes(chainDefinitions[sourceChain].targetBridgeAddress)) == keccak256(bytes(sourceAddress)));

        bytes memory innerMessage;
        uint256 messageType;

        uint256 name; 
        uint64 registrationVersion; 
        uint64 ownerChangeVersion;
        uint256 expiration;
        
        (messageType, innerMessage) = abi.decode(payload, (uint256, bytes));

        if (messageType == 0) {
            string memory targetOwner;
 
            (name, registrationVersion, ownerChangeVersion, expiration, targetOwner) = abi.decode(innerMessage, (uint256, uint64, uint64, uint256, string));
            registrarController.receiveName(name, registrationVersion, ownerChangeVersion, expiration, targetOwner.toAddress());
        }
        else if (messageType == 1) {
            (name, registrationVersion, ownerChangeVersion, expiration) = abi.decode(innerMessage, (uint256, uint64, uint64, uint256));
            registrarController.receiveExpirationInfo(name, registrationVersion, ownerChangeVersion, expiration);
        }
        else {
            _handleMessageType(sourceChain, messageType, innerMessage);
        }
    }

    function _handleMessageType(string memory chainName, uint256 messageType, bytes memory innerMessage) internal virtual;

    /************************\
    |* Controller Functions *|
    \************************/
    //Bridge a name to a different chain
    function bridgeNameTo(string calldata chainName, uint256 name, uint64 registrationVersion, uint64 ownerChangeVersion, 
                          uint256 expiration, string calldata targetOwner) external payable onlyController 
    {
        if (!chainDefinitions[chainName].isValid) { revert UnsupportedOrInvalidChain(chainName); }

        bytes memory payload = abi.encode(0, abi.encode(name, registrationVersion, ownerChangeVersion, expiration, targetOwner));

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

    function bridgeExpirationInfoTo(string calldata chainName, uint256 name, uint64 registrationVersion, uint64 ownerChangeVersion,
                                    uint256 expiration) external payable onlyController 
    {
        if (!chainDefinitions[chainName].isValid) { revert UnsupportedOrInvalidChain(chainName); }

        bytes memory payload = abi.encode(1, abi.encode(name, registrationVersion, ownerChangeVersion, expiration));

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
    
    /*******************\
    |* Admin Functions *|
    \*******************/
    function addChain(string calldata chainName, string calldata targetBridgeAddress) external onlyOwner {
        if(chainDefinitions[chainName].isValid) { revert DuplicateChainAddition(chainName); }

        supportedChains.push(chainName);
        chainDefinitions[chainName] = ChainDefinition({
            isValid: true,
            targetBridgeAddress: targetBridgeAddress
        });

        emit ChainAdded(chainName, targetBridgeAddress);
    }

    function removeChain(string calldata chainName, uint256 arrayIndex) external onlyOwner {
        if (!chainDefinitions[chainName].isValid) { revert UnsupportedOrInvalidChain(chainName); }
        if (keccak256(bytes(supportedChains[arrayIndex])) != keccak256(bytes(chainName))) { revert ChainNotAtGivenIndex(chainName, arrayIndex); }

        delete chainDefinitions[chainName];

        supportedChains[arrayIndex] = supportedChains[supportedChains.length - 1];
        supportedChains.pop();

        emit ChainRemoved(chainName);
    }

    // Add / Remove addresses that are allowed to call `onlyController` methods.
    function setController(address controller, bool allowed) external onlyOwner {
        super._setController(controller, allowed);
    }
}