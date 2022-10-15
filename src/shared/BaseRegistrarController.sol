//SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "../lib/utils/Ownable.sol";
import "./IRegistrarController.sol";
import "./PaymentProviders/IPaymentProvider.sol";
import "./IRegistrar.sol";

abstract contract BaseRegistrarController is IRegistrarController, Ownable {
    /**********\
    |* Errors *|
    \**********/
    error UnexpiredCommitmentExists();

    error CommitmentTooNew();
    error CommitmentTooOld();

    error MustBeApprovedOrOwner();
    error MustBeOnKeeperChain();

    /**********\
    |* Events *|
    \**********/
    event PaymentProviderChanged(IPaymentProvider previous, IPaymentProvider current);

    /*********\
    |* State *|
    \*********/
    IRegistrar private immutable registrar;
    IPaymentProvider public paymentProvider;

    uint256 public immutable minCommitmentAge;
    uint256 public immutable maxCommitmentAge;

    uint256 public minRegisterDuration;
    uint256 public minRenewDuration;

    uint256 public minNameLength;
    uint256 public maxNameLength;

    mapping(bytes32 => uint256) private commitments;   

    constructor(IRegistrar _registrar,
                IPaymentProvider _paymentProvider,
                uint256 _minCommitmentAge,
                uint256 _maxCommitmentAge,
                uint256 _minRegisterDuration,
                uint256 _minRenewDuration,
                uint256 _minNameLength,
                uint256 _maxNameLength
    ) {
        require(_minCommitmentAge < _maxCommitmentAge);
        require(_maxCommitmentAge > 0);

        registrar = _registrar;
        paymentProvider = _paymentProvider;

        minCommitmentAge = _minCommitmentAge;
        maxCommitmentAge = _maxCommitmentAge;

        minRegisterDuration = _minRegisterDuration;
        minRenewDuration = _minRenewDuration;

        minNameLength = _minNameLength;
        maxNameLength = _maxNameLength;
    }

    /***********\
    |* Setters *|
    \***********/
    function commit(bytes32 commitment) external {
        if (commitments[commitment] + maxCommitmentAge >= block.timestamp) { revert UnexpiredCommitmentExists(); }

        commitments[commitment] = block.timestamp;
    }

    function register(string calldata plainName, address owner, uint256 duration, bytes32 secret) external payable returns (uint256) {
        uint256 name = uint256(keccak256(bytes(plainName)));

        //Payment provider should revert if payment unsuccessful
        paymentProvider.collectPayment(msg.sender, plainName, 0, duration); 

        _consumeCommitment(name, owner, duration, secret);
        return _doRegister(plainName, name, owner, duration, block.timestamp + duration);
    }

    function renew(string calldata plainName, uint256 duration) external payable returns (uint256) {
        uint256 name = uint256(keccak256(bytes(plainName)));
        address owner = registrar.ownerOf(name);

        if (msg.sender != owner && !registrar.isApprovedForAll(owner, msg.sender) && !(registrar.getApproved(name) == msg.sender)) { revert MustBeApprovedOrOwner(); }
        if (!registrar.isKeeper(name)) { revert MustBeOnKeeperChain(); }

        uint256 expiration = _max(block.timestamp, registrar.getNameExpiration(name)) + duration;
        paymentProvider.collectPayment(msg.sender, plainName, expiration, duration);

        return _doRenew(name, registrar.getRegistrationVersion(name), duration, expiration);
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

        if (commitments[commitment] + minCommitmentAge > block.timestamp) { revert CommitmentTooNew(); }
        if (commitments[commitment] + maxCommitmentAge <= block.timestamp) { revert CommitmentTooOld(); }

        delete (commitments[commitment]);
    }

    /**********************\
    |* Abstract Functions *|
    \**********************/
    function _doRegister(string memory plainName, uint256 name, address owner, uint256 duration, uint256 expiration) internal virtual returns (uint256);
    function _doRenew(uint256 name, uint64 registrationVersion, uint256 duration, uint256 expiration) internal virtual returns (uint256);
}