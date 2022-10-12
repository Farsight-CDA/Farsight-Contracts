//SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

interface IRegistry {
    function getRecords(uint256 name) external view returns (string[]);

    function getValue(uint256 name, string record) external view returns (bytes[]);
    
    function setValue(uint256 name, string record, bytes[] value) external;
    function deleteValue(uint256 name, string record) external;
}