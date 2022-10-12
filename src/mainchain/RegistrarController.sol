//SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import "../lib/utils/Ownable.sol";
import "./IRegistrarController.sol";
import "./PaymentProviders/IPaymentProvider.sol";
import "../shared/IRegistrar.sol";
import "../lib/Axelar/IAxelarGateway.sol";

contract RegistrarController is IRegistrarController, Ownable {
    /**********\
    |* Errors *|
    \**********/
    error UnexpiredCommitmentExists();
    error CommitmentTooNew();
    error CommitmentTooOld();
    error RegisterDurationTooShort(uint256 minimum, uint256 given);
    error RenewDurationTooShort(uint256 minimum, uint256 given);
    error MustBeNameOwner(address owner, address given);

    error DuplicateChainIdAddition(uint256 chainId);
    error UnsupportedOrInvalidChainId(uint256 chainId);
    error ChainIdNotAtGivenIndex(uint256 chainId, uint256 index);

    /**********\
    |* Events *|
    \**********/
    event PaymentProviderChanged(IPaymentProvider previous, IPaymentProvider current);
    event MinRegisterDurationChanged(uint256 previous, uint256 current);

    event ChainAdded(uint256 indexed chainId, string indexed targetPropagatorAddress);
    event ChainRemoved(uint256 indexed chainId);

    /***********\
    |* Structs *|
    \***********/
    struct ChainDefinition {
        bool isValid;
        string name;
        string targetAddress;
    }
    

    uint256 public immutable minCommitmentAge;
    uint256 public immutable maxCommitmentAge;

    mapping(bytes32 => uint256) _commitments;    

    IRegistrar immutable registrar;

    IPaymentProvider paymentProvider;

    uint256 minRegisterDuration;
    uint256 minRenewDuration;

    IAxelarGateway immutable axelarGateway;

    uint256[] supportedChains;
    mapping(uint256 => ChainDefinition) chainDefinitions;

    constructor(uint256 _minCommitmentAge,
                uint256 _maxCommitmentAge, 
                IRegistrar _registrar,
                IPaymentProvider _paymentProvider,
                uint256 _minRegisterDuration,
                uint256 _minRenewDuration,
                IAxelarGateway _axelarGateway
    ) {
        require(_minCommitmentAge < _maxCommitmentAge);
        require(_maxCommitmentAge > 0);

        minCommitmentAge = _minCommitmentAge;
        maxCommitmentAge = _maxCommitmentAge;

        registrar = _registrar;
        paymentProvider = _paymentProvider;

        minRegisterDuration = _minRegisterDuration;
        minRenewDuration = _minRenewDuration;

        axelarGateway = _axelarGateway;
    }

    /***********\
    |* Getters *|
    \***********/

    function available(uint256 name) public view returns (bool) {
        return registrar.available(name);
    }

    /***********\
    |* Setters *|
    \***********/

    function commit(bytes32 commitment) external override {
        if (_commitments[commitment] + maxCommitmentAge >= block.timestamp) { revert UnexpiredCommitmentExists(); }

        _commitments[commitment] = block.timestamp;
    } 
    
    function register(uint256 name, address owner, uint256 duration, bytes32 secret, bool setPrimary) external returns (uint256) {
        if (duration < minRegisterDuration) { revert RegisterDurationTooShort(minRegisterDuration, duration); }

        //Payment provider should revert if payment unsuccessful
        paymentProvider.collectPayment(msg.sender, name, registrar.nameExpires(name), duration); 

        _consumeCommitment(name, owner, duration, secret);

        return registrar.register(name, owner, duration, setPrimary);
    }

    function renew(uint256 name, uint256 duration) external returns (uint256) {
        if (duration < minRenewDuration) { revert RenewDurationTooShort(minRenewDuration, duration); }

        paymentProvider.collectPayment(msg.sender, name, _max(block.timestamp, registrar.nameExpires(name)), duration);

        return registrar.renew(name, duration);
    }

    function addChain(uint256 chainId, string calldata targetPropagatorAddress, string calldata chainName) external onlyOwner {
        if(chainDefinitions[chainId].isValid) { revert DuplicateChainIdAddition(chainId); }

        supportedChains.push(chainId);
        chainDefinitions[chainId] = ChainDefinition({
            isValid: true,
            name: chainName, 
            targetAddress: targetPropagatorAddress
        });

        emit ChainAdded(chainId, targetPropagatorAddress);
    }

    function removeChain(uint256 chainId, uint256 arrayIndex) external onlyOwner {
        if (!chainDefinitions[chainId].isValid) { revert UnsupportedOrInvalidChainId(chainId); }
        if (supportedChains[arrayIndex] != chainId) { revert ChainIdNotAtGivenIndex(chainId, arrayIndex); }

        supportedChains[arrayIndex] = supportedChains[supportedChains.length - 1];
        supportedChains.pop();

        emit ChainRemoved(chainId);
    }

    /***********************\
    |* Cross Chain Setters *|
    \***********************/

    function broadcastNameUpdate(uint256 name, string calldata owner, uint256 expiry) external {
        if (registrar.ownerOf(name) != msg.sender) {
            revert MustBeNameOwner(registrar.ownerOf(name), msg.sender);
        }

        for(uint256 i = 0; i < supportedChains.length; i++) { //Unbounded loop: Maximum amount of chainIds very small
            uint256 chainId = supportedChains[i];
            axelarGateway.callContract(
                chainDefinitions[chainId].name, 
                chainDefinitions[chainId].targetAddress, 
                abi.encodePacked(name, owner, expiry)
            );
        }
    }

    function sendNameUpdate(uint256 chainId, uint256 name, string calldata owner, uint256 expiry) external {
        if (!chainDefinitions[chainId].isValid) { revert UnsupportedOrInvalidChainId(chainId); }
        if (registrar.ownerOf(name) != msg.sender) {
            revert MustBeNameOwner(registrar.ownerOf(name), msg.sender);
        }

        axelarGateway.callContract(
            chainDefinitions[chainId].name, 
            chainDefinitions[chainId].targetAddress, 
            abi.encodePacked(name, owner, expiry)
        );
    }

    /*******************\
    |* Admin Functions *|
    \*******************/

    function setPaymentProvider(IPaymentProvider _paymentProvider) external onlyOwner {
        require(paymentProvider != _paymentProvider);

        emit PaymentProviderChanged(paymentProvider, _paymentProvider);
        paymentProvider = _paymentProvider;
    }

    function setMinRegisterDuration(uint256 _minRegisterDuration) external onlyOwner {
        require(minRegisterDuration != _minRegisterDuration);

        emit MinRegisterDurationChanged(minRegisterDuration, _minRegisterDuration);
        minRegisterDuration = _minRegisterDuration;
    }

    /**********************\
    |* Internal Functions *|
    \**********************/

    // Returns the larger of two numbers
    function _max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    function _consumeCommitment(uint256 name, address owner, uint256 duration, bytes32 secret) internal {
        bytes32 commitment = keccak256(abi.encodePacked(name, owner, duration, secret));

        if (_commitments[commitment] + minCommitmentAge > block.timestamp) { revert CommitmentTooNew(); }
        if (_commitments[commitment] + maxCommitmentAge <= block.timestamp) { revert CommitmentTooOld(); }

        delete (_commitments[commitment]);
    }
}