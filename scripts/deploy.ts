import {ethers} from "hardhat";
import {serialize, deserialize, createSchema, SchemaType} from "./bin";
import RLP from "rlp";

async function main() {
  const RLPLibrary = await ethers.getContractFactory("contracts/rlp.sol:RLP");
  const rlp = await RLPLibrary.deploy();
  const ETHQL = await ethers.getContractFactory("contracts/ethql.sol:ETHQL", {libraries: {RLP: rlp}});
  const ethql = await ETHQL.deploy()

  const tableName = "TableName";
  const tableSchema = createSchema({
    id: SchemaType.UINT64,
    text: SchemaType.STRING,
    is_active: SchemaType.BOOL
  });
  const tableDeployTxn = await ethql.getFunction("createTable").send(tableName, tableSchema);
  const tableDeployReceipt = await tableDeployTxn.wait();
  const tableAddress = (tableDeployReceipt!.logs[0] as any)["args"][0]; // TODO: not good

  console.log(`Table named "${tableName}" deployed at: ${tableAddress}`);

  const rows = [
    {"id": 1, "text": "a", "is_active": true},
    {"id": 1, "text": "a", "is_active": false},
    {"id": 1, "text": "a", "is_active": false},
    {"id": 1, "text": "a", "is_active": false}
  ];
  const rowBytes = serialize(rows);

  console.log("Bulk inserting:\n", rows);
  console.log("RLP encoded:", "0x" + Buffer.from(rowBytes).toString("hex"), "(" + rowBytes.length + " bytes)")
  console.log("---------------------------");

  const txn = await ethql.getFunction("bulkInsert").send(tableAddress, rowBytes);
  await txn.wait();

  const select = await ethql.getFunction("select")(tableAddress);

  console.log("Recovering data from blockchain:", select, "(" + select.length + " bytes)")
  console.log("After deserializing the recovered data by schema:\n", deserialize(select));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
