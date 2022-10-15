//SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "../shared/IRegistrarController.sol";

interface ISubRegistrarController is IRegistrarController {
    function receiveRenewSuccess(uint256 name, uint256 newExpiration) external;
}