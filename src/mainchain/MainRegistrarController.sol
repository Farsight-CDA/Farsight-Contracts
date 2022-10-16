//SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "./IMainRegistrarController.sol";
import "../shared/BaseRegistrarController.sol";
import "./IMainRegistrar.sol";
import "../shared/PaymentProviders/IPaymentProvider.sol";

contract MainRegistrarController is BaseRegistrarController, IMainRegistrarController {
    /**********\
    |* Errors *|
    \**********/
    error RegisterDurationTooShort(uint256 minimum, uint256 given);
    error RenewDurationTooShort(uint256 minimum, uint256 given);

    error NameTooShort(uint256 minimum, uint256 given);
    error NameTooLong(uint256 maxmimum, uint256 given);

    /**********\
    |* Events *|
    \**********/
    event MinRegisterDurationChanged(uint256 previous, uint256 current);
    event MinRenewDurationChanged(uint256 previous, uint256 current);

    event MinNameLengthChanged(uint256 previous, uint256 current);
    event MaxNameLengthChanged(uint256 previous, uint256 current);

    /*********\
    |* State *|
    \*********/
    IMainRegistrar public immutable mainRegistrar;

    mapping(string => string) chainControllers;

    constructor(IMainRegistrar _mainRegistrar,
                IPaymentProvider _paymentProvider,
                uint256 _minCommitmentAge,
                uint256 _maxCommitmentAge,
                uint256 _minRegisterDuration,
                uint256 _minRenewDuration,
                uint256 _minNameLength,
                uint256 _maxNameLength) 
        BaseRegistrarController(_mainRegistrar, _paymentProvider, _minCommitmentAge, _maxCommitmentAge, _minRegisterDuration, _minRenewDuration, _minNameLength, _maxNameLength)
    {
        mainRegistrar = _mainRegistrar;
    }

    modifier onlyNameBridge() {
        require(address(mainRegistrar.getNameBridge()) == msg.sender);
        _;
    }

    /*********************\
    |* Bridged Functions *|
    \*********************/
    function receiveExpirationInfo(uint256, uint64, uint64, uint256) external view onlyNameBridge {
        return; //Not needed on mainchain.
    }
    function receiveName(uint256 name, uint64 registrationVersion, uint64 ownerChangeVersion, uint256 expiration, address owner) external onlyNameBridge {
        mainRegistrar.receiveName(name, registrationVersion, ownerChangeVersion, expiration, owner);
    }
    function receiveRegisterRequest(string memory sourceChain, string calldata plainName, uint256 name, string calldata owner, uint256 duration, uint256 expiration) external onlyNameBridge {
        _doRegister(plainName, name, address(this), duration, expiration);
        mainRegistrar.bridgeNameTo(sourceChain, name, owner);
    }
    function receiveRenewRequest(string memory sourceChain, uint256 name, uint64 registrationVersion, uint256 duration, uint256 expiration) external onlyNameBridge {
        _doRenew(name, registrationVersion, duration, expiration);
        mainRegistrar.getNameBridge().bridgeRenewalSuccess(sourceChain, name, expiration);
    }      

    /*******************\
    |* Admin Functions *|
    \*******************/
    function setMinRegisterDuration(uint256 _minRegisterDuration) external onlyOwner {
        require(minRegisterDuration != _minRegisterDuration);

        emit MinRegisterDurationChanged(minRegisterDuration, _minRegisterDuration);
        minRegisterDuration = _minRegisterDuration;
    }

    function setMinRenewDuration(uint256 _minRenewDuration) external onlyOwner {
        require(minRenewDuration != _minRenewDuration);

        emit MinRenewDurationChanged(minRenewDuration, _minRenewDuration);
        minRenewDuration = _minRenewDuration;
    }

    function setMinNameLength(uint256 _minNameLength) external onlyOwner {
        require(minNameLength != _minNameLength);

        emit MinNameLengthChanged(minNameLength, _minNameLength);
        minNameLength = _minNameLength;
    }

    function setMaxNameLength(uint256 _maxNameLength) external onlyOwner {
        require(maxNameLength != _maxNameLength);

        emit MinRenewDurationChanged(maxNameLength, _maxNameLength);
        maxNameLength = _maxNameLength;
    }

    /**********************\
    |* Internal Functions *|
    \**********************/
    function _doRegister(string memory plainName, uint256 name, address owner, uint256 duration, uint256 expiration) internal override returns (uint256) {
        if (duration < minRegisterDuration) { revert RegisterDurationTooShort(minRegisterDuration, duration); }

        uint256 length = utfStringLength(plainName);

        if (length < minNameLength) { revert NameTooShort(minNameLength, length); }
        if (length > maxNameLength) { revert NameTooLong(maxNameLength, length); }

        mainRegistrar.register(plainName, name, owner, expiration);
        return expiration;
    }

    function _doRenew(uint256 name, uint64 registrationVersion, uint256 duration, uint256 expiration) internal override returns (uint256) {
        if (duration < minRenewDuration) { revert RenewDurationTooShort(minRenewDuration, duration); }

        mainRegistrar.renew(name, registrationVersion, expiration);
        return expiration;
    }

    
    function utfStringLength(string memory str) pure internal returns (uint256 length) {
        uint256 i = 0;
        bytes memory string_rep = bytes(str);

        while (i < string_rep.length)
        {
            if (string_rep[i]>>7==0)
                i+=1;
            else if (string_rep[i]>>5==bytes1(uint8(0x6)))
                i+=2;
            else if (string_rep[i]>>4==bytes1(uint8(0xE)))
                i+=3;
            else if (string_rep[i]>>3==bytes1(uint8(0x1E)))
                i+=4;
            else
                //For safety
                i+=1;

            length++;
        }
    }
}