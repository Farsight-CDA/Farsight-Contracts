//SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "./IRegistrar.sol";
import "./IRegistry.sol";

contract BaseRegistry is IRegistry {
    error Unauthorized(uint256 name, address owner);
    event RecordValueSet(uint256 indexed name, string indexed recordName, bytes[] recordValue);
    event RecordValueRemoved(uint256 indexed name, string indexed recordName);

    struct RecordValue {
        uint256 addedAt;
        bytes[] data;
    }

    struct RecordStore {
        string[] recordNames;
        mapping(string => RecordValue) recordValues;
    }

    IRegistrar immutable registrar;

    mapping(uint256 => RecordStore) records;

    constructor (IRegistrar _registrar) {
        registrar = _registrar;
    }

    function getRecords(uint256 name) external view returns (string[] memory) {
        return records[name].recordNames;
    }

    function getValue(uint256 name, string calldata record) external view returns (uint256, bytes[] memory) {
        return (records[name].recordValues[record].addedAt, records[name].recordValues[record].data);
    }

    function setValue(uint256 name, string calldata record, bytes[] memory value) external {
        if (registrar.ownerOf(name) != msg.sender) {
            revert Unauthorized(name, registrar.ownerOf(name));
        }

        records[name].recordValues[record] = RecordValue({
            addedAt: block.timestamp,
            data: value
        });

        emit RecordValueSet(name, record, value);
    }

    function deleteValue(uint256 name, string calldata record) external {
        if (registrar.ownerOf(name) != msg.sender) {
            revert Unauthorized(name, registrar.ownerOf(name));
        }

        delete records[name].recordValues[record];
        emit RecordValueRemoved(name, record);
    }
}