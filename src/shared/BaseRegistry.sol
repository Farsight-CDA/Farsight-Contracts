//SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "./IRegistrar.sol";

error Unauthorized(indexed uint256 name, indexed address owner);

event RecordValueSet(indexed uint256 name, indexed string recordName, bytes[] recordValue);
event RecordValueRemoved(indexed uint256 name, indexed string recordName);

struct RecordValue {
    uint256 addedAt;
    bytes[] data;
}

struct RecordStore {
    string[] recordNames;
    mapping(string => RecordValue) recordValues;
}

contract BaseRegistry {
    IRegistrar immutable registrar;

    mapping(uint256 => mapping(string => RecordValue)) records;

    constructor (IRegistar _registrar) public {
        registrar = _registrar;
    }

    function getRecords(uint256 name) external view returns (string[]) {
        return records[name].recordNames;
    }

    function getValue(uint256 name, string record) external view returns (bytes[]) {
        return records[name].recordValues[record];
    }

    function setValue(uint256 name, string record, bytes[] value) external {
        if (registrar.ownerOf(name) != msg.sender) {
            revert Unauthorized(name, registrar.ownerOf(name));
        }

        records[name].recordValues[record] = value;
        emit RecordValueSet(name, record, value);
    }

    function deleteValue(uint256 name, string record) external {
        if (registrar.ownerOf(name) != msg.sender) {
            revert Unauthorized(name, registrar.ownerOf(name));
        }

        delete records[name].recordValues[record];
        emit RecordValueRemoved(name, record);
    }
}