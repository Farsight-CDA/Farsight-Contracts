//SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "./PaymentProviders/IPaymentProvider.sol";

interface IRegistrarController {
    function getCommitment(bytes32 commitment) external view returns (uint256);
    function getPaymentProvider() external view returns (IPaymentProvider);

    function commit(bytes32 commitment) external; 
    function register(string calldata plainName, address owner, uint256 duration, bytes32 secret) external payable returns (uint256);
    function renew(string calldata plainName, uint256 duration) external payable returns (uint256);

    function receiveName(uint256 name, uint64 registrationVersion, uint64 ownerChangeVersion, uint256 expiration, address owner) external;
    function receiveExpirationInfo(uint256 name, uint64 registrationVersion, uint64 ownerChangeVersion, uint256 expiration) external;
}