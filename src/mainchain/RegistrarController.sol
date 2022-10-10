//SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

error UnexpiredCommitmentExists();

error CommitmentTooNew();
error CommitmentTooOld();

error DurationTooShort();

error NameNotAvailable();

import "../lib/ERC20/IERC20.sol";
import "../lib/utils/Ownable.sol";
import "./IRegistrarController.sol";
import "./IPaymentProvider.sol";
import "../shared/IRegistrar.sol";

contract RegistrarController is IRegistrarController, Ownable {
    event PaymentProviderChanged(IPaymentProvider previous, IPaymentProvider current);
    event MinRegisterDurationChanged(uint256 previous, uint256 current);

    IRegistrar immutable registrar;

    uint256 public immutable minCommitmentAge;
    uint256 public immutable maxCommitmentAge;

    mapping(bytes32 => uint256) _commitments;    

    IPaymentProvider paymentProvider;

    uint256 minRegisterDuration;

    constructor(uint256 _minCommitmentAge,
                uint256 _maxCommitmentAge, 
                IRegistrar _registrar,
                IPaymentProvider _paymentProvider,
                uint256 _minRegisterDuration
    ) {
        assert(_minCommitmentAge < _maxCommitmentAge);

        minCommitmentAge = _minCommitmentAge;
        maxCommitmentAge = _maxCommitmentAge;
        registrar = _registrar;

        paymentProvider = _paymentProvider;

        minRegisterDuration = _minRegisterDuration;
    }

    // Admin Functions

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

    // End User Functions

    // Getters
    function available(uint256 name) public view returns (bool) {
        return registrar.available(name);
    }

    // Setters

    function commit(bytes32 commitment) external override {
        if (_commitments[commitment] + maxCommitmentAge >= block.timestamp) { revert UnexpiredCommitmentExists(); }

        _commitments[commitment] = block.timestamp;
    } 
    
    function register(uint256 name, address owner, uint256 duration, bytes32 secret, bool setPrimary) external returns (uint256) {
        if (duration < minRegisterDuration) { revert DurationTooShort(); }
        if (!available(name)) { revert NameNotAvailable(); }

        //Payment provider should revert if payment unsuccessful
        paymentProvider.collectPayment(name, registrar.nameExpires(name), duration); 

        _consumeCommitment(name, owner, duration, secret);

        return registrar.register(name, owner, duration, setPrimary);
    }

    // Internal Functions

    function _consumeCommitment(uint256 name, address owner, uint256 duration, bytes32 secret) internal {
        bytes32 commitment = keccak256(abi.encodePacked(name, owner, duration, secret));

        if (_commitments[commitment] + minCommitmentAge > block.timestamp) { revert CommitmentTooNew(); }
        if (_commitments[commitment] + maxCommitmentAge <= block.timestamp) { revert CommitmentTooOld(); }

        delete (_commitments[commitment]);
    }
}