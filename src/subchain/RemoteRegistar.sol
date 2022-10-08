// SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "./IRemoteRegistar.sol";
import "../lib/utils/Ownable.sol";
import "../lib/utils/Controllable.sol";

/**********\
|* Errors *|
\**********/
error OutdatedUpdate(uint256 providedCallId, uint256 latestCallId);
error UnassignedName(uint256 name);

contract RemoteRegistrar is IRemoteRegistar, Ownable, Controllable {
    uint256 public constant GRACE_PERIOD = 30 days;

    mapping(uint256 => address) _owners;
    mapping(address => uint256) _reverseRegistrar; //Only map to "primary" name
    mapping(uint256 => uint256) _expiries;
    mapping(uint256 => uint256) _callIdStack;

    /***********\
    |* Getters *|
    \***********/

    function ownerOf(uint256 name) external returns (address) {
        if (_expiries[name] <= block.timestamp) { revert NameExpired(); }
        if (_owners[name] == address(0)) { revert UnassignedName(name); }
        
        return _owners[name];
    }

    function nameExpires(uint256 name) external view returns (uint256) {
        return _expiries[name];
    }

    function available(uint256 name) external view returns (bool) {
        return _expiries[name] + GRACE_PERIOD < block.timestamp;
    }

    /***************************\
    |* Controller Functions    *|
    |* => Calls from mainchain *|
    \**************************/

    function updateRegistration(uint256 callId, uint256 name, address owner, uint256 expiration, bool updateReverseEntry) external onlyController {
        if (callId <= _callIdStack[name]) {
            revert OutdatedUpdate(callId, _callIdStack[name]);
        }

        _callIdStack[name] = callId;
        _owners[name] = owner;
        _expiries[name] = expiration;

        if (updateReverseEntry) {
            _reverseRegistrar[owner] = name;
        }
    }

    function updateReverseEntry(uint256 callId, address owner, uint256 name) external onlyController {
        if (callId <= _callIdStack[name]) {
            revert OutdatedUpdate(callId, _callIdStack[name]);
        }

        _callIdStack[name] = callId;
        _reverseRegistrar[owner] = name;
    }

    function updateExpiration(uint256 callId, uint256 name, uint256 expiration) external onlyController {
        if (callId <= _callIdStack[name]) {
            revert OutdatedUpdate(callId, _callIdStack[name]);
        }

        _callIdStack[name] = callId;
        _expiries[name] = expiration;
    }

    /*******************\
    |* Admin Functions *|
    \*******************/
    
    // Add / Remove addresses that are allowed to call `onlyController` methods.
    function setController(address controller, bool allowed) external onlyOwner {
        super._setController(controller, allowed);
    }
}