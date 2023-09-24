// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {RLP} from "./rlp.sol";

contract Table {
  bool public constant isTable = true;
  string public name;

  RLP.Element public data = RLP.Element("", RLP.FLAG_TYPE_LIST);
  RLP.Element public schema;

  constructor(string memory _name) {
    name = _name;
  }

  function insert(RLP.Element memory _row) external {
    RLP.push(data, _row);
  }

  function bulkInsert(RLP.Element memory rows) external {
    RLP.concatLhs(data, rows);
  }

  function setSchema(RLP.Element memory _schema) external {
    schema = _schema;
  }

  function select() public view returns(bytes memory) {
    return RLP.deserialize(RLP.unshift(schema, data));
  }
}