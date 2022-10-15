// SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is a collection of addresses (controllers) that can be granted exclusive access to
 * specific functions.
 *
 * By default, there are no controllers set, 
 * they have to be manually added through function calls.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyController`, which can be applied to your functions to restrict their use 
 * to controller addresses.
 */
abstract contract Controllable {
    event ControllerChanged(address indexed controller, bool allowed);

    mapping(address => bool) private _controllers;

    function _setController(address controller, bool allowed) internal {
        require(_controllers[controller] != allowed, "Controllable: no state change needed");
        _controllers[controller] = allowed;
        emit ControllerChanged(controller, allowed);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyController() {
        _checkController();
        _;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkController() internal view virtual {
        require(_controllers[msg.sender], "Controllable: caller is not an allowed controller");
    }
}