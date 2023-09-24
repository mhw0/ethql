import {ethers} from "hardhat";
import RLP from "rlp";

function serialize(decoded: any) {
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


  const tableName = "Users";
  const tableSchema = RLP.encode([["id", "uint32"], ["name", "string"], ["user_id", "uint32"]]);
  const tableDeployTxn = await ethql.getFunction("createTable").send(tableName, tableSchema);
  const tableDeployReceipt = await tableDeployTxn.wait();
  const tableAddress = (tableDeployReceipt!.logs[0] as any)["args"][0]; // TODO: not good

  console.log(`Table named "${tableName}" deployed at: ${tableAddress}`);

  const row = {"id": 1, "name": "test", "user_id": 33};
  const rowBytes = serialize(row);

  console.log("Inserting:\n ", row);
  console.log("RLP encoded:", "0x" + Buffer.from(rowBytes).toString("hex"), "(" + rowBytes.length + " bytes)")
  console.log("---------------------------");

  const txn = await ethql.getFunction("insert").send(tableAddress, rowBytes);
  await txn.wait();

  const select = await ethql.getFunction("select").call(null, tableAddress);

  console.log("Recovering data from blockchain:", select, "(" + select.length + " bytes)")
  console.log("After deserializing the recovered data by schema:\n ", deserialize(select));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
