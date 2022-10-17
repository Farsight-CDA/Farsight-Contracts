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
    uint64 internal constant BridgeNameMessageType = 0;
    uint64 internal constant BridgeExpirationInfoMessageType = 1;
    uint64 internal constant BridgeLocalOwnerMessageType = 2;

    uint64 internal constant BridgeRegisterRequestMessageType = 10;
    uint64 internal constant BridgeRenewRequestMessageType = 11;

    uint64 internal constant BridgeRenewSuccessMessageType = 20;

    /**********\
    |* Errors *|
    \**********/
    error DuplicateChainAddition(string chainName);
    error UnsupportedOrInvalidChain(string chainName);
    error ChainNotAtGivenIndex(string chainName, uint256 index);

    /**********\
    |* Events *|
    \**********/
    event BridgeNameTo(uint256 indexed name, string targetChain, uint256 expiration, string targetOwner);
    event BridgeExpirationInfoTo(uint256 indexed name, string targetChain, uint256 expiration);
    event BridgeLocalOwnerTo(uint256 indexed name, string targetChain, uint256 expiration, string targetLocalOwner);

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
        uint64 messageType;

        uint256 name; 
        uint64 registrationVersion; 
        uint64 ownerChangeVersion;
        uint256 expiration;
        
        (messageType, innerMessage) = abi.decode(payload, (uint64, bytes));

        if (messageType == BridgeNameMessageType) {
            string memory targetOwner;
 
            (name, registrationVersion, ownerChangeVersion, expiration, targetOwner) = abi.decode(innerMessage, (uint256, uint64, uint64, uint256, string));
            registrarController.receiveName(name, registrationVersion, ownerChangeVersion, expiration, targetOwner.toAddress());
        }
        else if (messageType == BridgeExpirationInfoMessageType) {
            (name, registrationVersion, ownerChangeVersion, expiration) = abi.decode(innerMessage, (uint256, uint64, uint64, uint256));
            registrarController.receiveExpirationInfo(name, registrationVersion, ownerChangeVersion, expiration);
        }
        else if (messageType == BridgeLocalOwnerMessageType) {
            string memory targetLocalOwner;

            (name, registrationVersion, ownerChangeVersion, expiration, targetLocalOwner) = abi.decode(innerMessage, (uint256, uint64, uint64, uint256, string));
            registrarController.receiveLocalOwner(name, registrationVersion, ownerChangeVersion, expiration, targetLocalOwner.toAddress());
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

        bytes memory payload = abi.encode(BridgeNameMessageType, abi.encode(name, registrationVersion, ownerChangeVersion, expiration, targetOwner));

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

        emit BridgeNameTo(name, chainName, expiration, targetOwner);
    }

    function bridgeExpirationInfoTo(string calldata chainName, uint256 name, uint64 registrationVersion, uint64 ownerChangeVersion,
                                    uint256 expiration) external payable onlyController 
    {
        if (!chainDefinitions[chainName].isValid) { revert UnsupportedOrInvalidChain(chainName); }

        bytes memory payload = abi.encode(BridgeExpirationInfoMessageType, abi.encode(name, registrationVersion, ownerChangeVersion, expiration));

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

        emit BridgeExpirationInfoTo(name, chainName, expiration);
    }
    

    function bridgeLocalOwnerTo(string calldata chainName, uint256 name, uint64 registrationVersion, uint64 ownerChangeVersion,
                                uint256 expiration, string calldata targetLocalOwner) external payable onlyController
    {
        if (!chainDefinitions[chainName].isValid) { revert UnsupportedOrInvalidChain(chainName); }

        bytes memory payload = abi.encode(BridgeLocalOwnerMessageType, abi.encode(name, registrationVersion, ownerChangeVersion, expiration, targetLocalOwner));

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

        emit BridgeLocalOwnerTo(name, chainName, expiration, targetLocalOwner);
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