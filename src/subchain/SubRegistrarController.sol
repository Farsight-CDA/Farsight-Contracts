// SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "../shared/BaseRegistrarController.sol";
import "./ISubRegistrarController.sol";
import "./ISubRegistrar.sol";
import "../shared/PaymentProviders/IPaymentProvider.sol";
import "../lib/Axelar/IAxelarGateway.sol";
import "../lib/Axelar/IAxelarGasService.sol";
import "../lib/Axelar/IAxelarExecutable.sol";

contract SubRegistrarController is BaseRegistrarController, ISubRegistrarController {
    /**********\
    |* Errors *|
    \**********/
    error TransferLocked();

    ISubRegistrar public immutable subRegistrar;

    constructor(ISubRegistrar _subRegistrar,
                IPaymentProvider _paymentProvider,
                uint256 _minCommitmentAge,
                uint256 _maxCommitmentAge,
                uint256 _minRegisterDuration,
                uint256 _minRenewDuration,
                uint256 _minNameLength,
                uint256 _maxNameLength) 
        BaseRegistrarController(_subRegistrar, _paymentProvider, _minCommitmentAge, _maxCommitmentAge, _minRegisterDuration, _minRenewDuration, _minNameLength, _maxNameLength)
    {
        subRegistrar = _subRegistrar;
    }

    modifier onlyNameBridge() {
        require(address(subRegistrar.getNameBridge()) == msg.sender, "Only callable by bridge contract");
        _;
    }

    /*********************\
    |* Bridged Functions *|
    \*********************/
    function receiveExpirationInfo(uint256 name, uint64 registrationVersion, uint64 ownerChangeVersion, uint256 expiration) external onlyNameBridge {
        subRegistrar.receiveExpirationInfo(name, registrationVersion, ownerChangeVersion, expiration);
    }

    function receiveName(uint256 name, uint64 registrationVersion, uint64 ownerChangeVersion, uint256 expiration, address owner) external onlyNameBridge {
        subRegistrar.receiveName(name, registrationVersion, ownerChangeVersion, expiration, owner);
    }

    function receiveRenewSuccess(uint256 name, uint256 newExpiration) external onlyNameBridge {
        subRegistrar.unsafeSetExpiration(name, newExpiration);
        subRegistrar.releaseTransferLock(name);

        //In case the renew fails this lock is not released.
        //Instead it will be reset when the newly registered NFT is sent to this chain.
    }   
    /**********************\
    |* Internal Functions *|
    \**********************/
    function _doRegister(string memory plainName, uint256 name, address owner, uint256 duration) internal override returns (uint256) {
        subRegistrar.getNameBridge().bridgeRegisterRequest(
            plainName, name, owner, duration);
        return 0;
    }

    function _doRenew(uint256 name, uint64 registrationVersion, uint256 duration) internal override returns (uint256) {
        if(subRegistrar.isTransferLocked(name)) { revert TransferLocked(); }
        subRegistrar.applyTransferLock(name);

        subRegistrar.getNameBridge().bridgeRenewalRequest(
            name, registrationVersion, duration);
        return 0;
    }
}