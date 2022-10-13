//SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

interface IRegistry {
    function getRecords(uint256 name) external view returns (string[] memory);

    function getValue(uint256 name, string calldata record) external view returns (uint256, bytes[] memory);
    
    function setValue(uint256 name, string calldata record, bytes[] calldata value) external;
    function deleteValue(uint256 name, string calldata record) external;
}