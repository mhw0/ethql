// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {RLP} from "./rlp.sol";

contract Table {
  bool public constant isTable = true;
  string public name;

  RLP.Element public data = RLP.Element(RLP.KIND_LIST, "");
  RLP.Element public schema;

  constructor(string memory _name, bytes memory _schema) {
    name = _name;
    schema = RLP.loadFromBytes(_schema);
  }

  function insert(RLP.Element memory row) external {
    RLP.lhsPush(data, row);
  }

  function bulkInsert(RLP.Element memory rows) external {
    RLP.lhsConcat(data, rows);
  }

  function setSchema(RLP.Element memory _schema) external {
    schema = _schema;
  }

  function selectWithSchema() public view returns(RLP.Element memory) {
    return RLP.concat(schema, data);
  }
}