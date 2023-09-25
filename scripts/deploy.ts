import {ethers} from "hardhat";
import RLP from "rlp";

function serialize(decoded: any) {
  if (Array.isArray(decoded))
    return RLP.encode(decoded.map((el) => Object.values(el)));

  return RLP.encode(Object.values(decoded));
}

function deserialize(encoded: Buffer) {
  const elements = RLP.decode(encoded) as any[];
  const schema = elements.shift();
  const textDecoder = new TextDecoder();

  return elements.reduce((acc, el) => {
    const obj = (schema as any[]).reduce((acc, sch, index) => {
      const schemaKey = textDecoder.decode(sch[0]);
      const schemaType = textDecoder.decode(sch[1]);
      if (schemaType.startsWith("uint"))
        acc[schemaKey] = Buffer.from(el[index]).readUintBE(0, el[index].length);
      else if (schemaType == "string")
        acc[schemaKey] = textDecoder.decode(el[index]);
      return acc;
    }, {})
    acc.push(obj);
    return acc;
  }, []);
}

async function main() {
  const RLPLibrary = await ethers.getContractFactory("contracts/rlp.sol:RLP");
  const rlp = await RLPLibrary.deploy();
  const ETHQL = await ethers.getContractFactory("contracts/ethql.sol:ETHQL", {libraries: {RLP: rlp}});
  const ethql = await ETHQL.deploy()

  const tableName = "TableName";
  // FIXME(mhw0): this should be list of pairs not list of list of pairs
  const tableSchema = RLP.encode([[["id", "uint32"], ["text", "string"], ["user_id", "uint32"]]]);
  const tableDeployTxn = await ethql.getFunction("createTable").send(tableName, tableSchema);
  const tableDeployReceipt = await tableDeployTxn.wait();
  const tableAddress = (tableDeployReceipt!.logs[0] as any)["args"][0]; // TODO: not good

  console.log(`Table named "${tableName}" deployed at: ${tableAddress}`);

  const rows = [
    {"id": 1, "text": "a", "user_id": 1},
    {"id": 2, "text": "a", "user_id": 2},
    {"id": 3, "text": "a", "user_id": 3},
    {"id": 4, "text": "a", "user_id": 4},
    {"id": 5, "text": "a", "user_id": 5},
    {"id": 6, "text": "a", "user_id": 6},
    {"id": 7, "text": "a", "user_id": 7},
    {"id": 8, "text": "a", "user_id": 8},
    {"id": 9, "text": "a", "user_id": 9},
    {"id": 10, "text": "a", "user_id": 10},
    {"id": 11, "text": "a", "user_id": 11},
    {"id": 12, "text": "a", "user_id": 12},
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
