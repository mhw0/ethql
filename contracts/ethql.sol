// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {RLP} from "./rlp.sol";
import {Table} from "./table.sol";

contract ETHQL {
  /* Holds table addresses */
  mapping(address => Table) public _tables;

  /* Emitted when a new row is inserted */
  event Inserted(address indexed tableAddr, bytes data);

  /* Emitted when many rows are inserted */
  event BulkInserted(address indexed tableAddr, bytes data);

  /* Emitted when a row is deleted */
  event Deleted(address indexed tableAddr, bytes data);

  /* Emitted when a new schema is set for the table */
  event TableSchemaSet(address indexed tableAddr, bytes schema);

  /* Emitted when a new table is created */
  event TableCreated(address indexed tableAddr, string tableName, bytes schema);

  /**
   * Creates a new table by deploying a new contract
   *
   * @param tableName - Name of the table
   * @param schema - Schema of the table in RLP format
   */
  function createTable(string memory tableName, bytes memory schema) public {
    Table table = new Table(tableName, schema);
    address tableAddr = address(table);
    _tables[tableAddr] = table;
    emit TableCreated(tableAddr, tableName, schema);
  }

  /**
   * Inserts data to the given table address
   * 
   * @param tableAddr - Address of the table
   * @param data - Data itself
   */
  function insert(address tableAddr, bytes memory data) external {
    Table targetTable = _tables[tableAddr];
    require(targetTable.isTable() == true, "Table does not exist");

    targetTable.insert(RLP.loadFromBytes(data));
    emit Inserted(tableAddr, data);
  }

  /**
   * Inserts many rows
   * 
   * @param tableAddr - Address of the table
   * @param data - List of rows in RLP format
   */
  function bulkInsert(address tableAddr, bytes memory data) external {
    Table targetTable = _tables[tableAddr];
    require(targetTable.isTable() == true, "Table does not exist");

    targetTable.bulkInsert(RLP.loadFromBytes(data));
    emit BulkInserted(tableAddr, data);
  }

  /**
   * Sets schema for the given table address
   *
   * @param tableAddr - Address of the table
   * @param schema - New schema to set to
   */
  function setSchemaForTable(address tableAddr, bytes memory schema) public {
    Table targetTable = _tables[tableAddr];
    require(targetTable.isTable(), "Table does not exist");

    targetTable.setSchema(RLP.loadFromBytes(schema));
    emit TableSchemaSet(tableAddr, schema);
  }

  /**
   * Selects rows from table
   *
   * @param tableAddr - Address of the table
   */
  function select(address tableAddr) public view returns(bytes memory) {
    Table targetTable = _tables[tableAddr];
    require(targetTable.isTable(), "Table does not exist");

    return RLP.deserialize(targetTable.selectWithSchema());
  }
}
