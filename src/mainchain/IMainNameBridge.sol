//SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "../shared/INameBridge.sol";

interface IMainNameBridge is INameBridge {
    //If external renewal is successful this unlocks the keeper chain token
    function bridgeRenewalSuccess(string calldata chainName, uint256 name, uint256 newExpiration) external payable;
}