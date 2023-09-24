// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {RLP} from "./rlp.sol";
import {Table} from "./table.sol";

import "hardhat/console.sol";

contract ETHQL {
  /* Holds table addresses */
  mapping(address => Table) public _tables;

  /* Emitted when a new row is inserted */
  event Inserted(address indexed tableAddr, bytes indexed data);

  /* Emitted when many new row are inserted */
  event InsertedMany(address indexed tableAddr, bytes indexed data);

  /* Emitted when a row is deleted */
  event Deleted(address indexed tableAddr, bytes indexed data);

  /* Emitted when a new schema is set for the table */
  event TableSchemaSet(address indexed tableAddr, bytes indexed schema);

  /* Emitted when a new table is created */
  event TableCreated(address tableAddr, string tableName, bytes schema);

  /**
   * Creates a new table by deploying a new contract
   *
   * @param tableName - Name of the table
   * @param schema - Schema of the table in RLP format
   */
  function createTable(string memory tableName, bytes memory schema) public returns(address) { // TODO(mhw0): this should not return data
    Table table = new Table(tableName);
    address tableAddr = address(table);
    table.setSchema(RLP.Element(schema, RLP.FLAG_TYPE_LIST));
    _tables[tableAddr] = table;
    emit TableCreated(tableAddr, tableName, schema);
    return tableAddr;
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

    targetTable.insert(RLP.Element(data, RLP.FLAG_TYPE_LIST));
    emit Inserted(tableAddr, data);
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

    targetTable.setSchema(RLP.Element(schema, RLP.FLAG_TYPE_LIST));
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

    return targetTable.select();
  }
}
