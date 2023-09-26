import RLP from "rlp";

const textDecoder = new TextDecoder();

export enum SchemaType {
  UINT8,  INT8,  STRING,
  UINT16, INT16, BYTES,
  UINT32, INT32, BOOL,
  UINT64, INT64
}

type Schema = [Uint8Array, Uint8Array][];
type ObjectLikeSchema = {[key: string]: SchemaType};

export function createSchema(schema: ObjectLikeSchema): Uint8Array {
  return RLP.encode(Object.keys(schema).map((key) => [key, schema[key]]));
}

export function serializeJavaScriptType(data: any) {
  switch (typeof data) {
    case 'boolean':
      return Number(data);
    case 'symbol':
      return data.description;
    case 'number':
    case 'string':
      return data;
    default:
      throw Error();
  }
}

export function serialize(decoded: any) {
  if (Array.isArray(decoded))
    return RLP.encode(decoded.map((el) => Object.values(el).map(serializeJavaScriptType)));

  return RLP.encode(Object.values(decoded));
}

export function deserialize(encoded: Buffer) {
  const rlpDecoded = RLP.decode(encoded) as any[];
  const schema = rlpDecoded.shift() as Schema;
  const rows = rlpDecoded[0] as any[];

  return rows.reduce((elements, element) => {
    const deserializedRow = schema.reduce((serializedSchema, [schemaKey, schemaType], schemaIndex) => {
      const decodedSchemaKey = textDecoder.decode(schemaKey);
      const decodedSchemaType = schemaType[0];
      const elementSchema = element[schemaIndex];
      
      let deserialized;

      switch (decodedSchemaType) {
        case SchemaType.BOOL:
          deserialized = Boolean(elementSchema[0])
          break;
        case SchemaType.STRING:
          deserialized = textDecoder.decode(elementSchema);
          break;
        case SchemaType.UINT8:
          deserialized = Buffer.from(elementSchema).readUint8(0);
          break;
        case SchemaType.UINT16:
          deserialized = Buffer.from(elementSchema).readUint16BE(0);
          break;
        case SchemaType.UINT32:
          deserialized = Buffer.from(elementSchema).readUint32BE(0);
          break;
        case SchemaType.UINT64:
          deserialized = Buffer.from(elementSchema).readUintBE(0, elementSchema.length);
          break;
        case SchemaType.INT8:
          deserialized = Buffer.from(elementSchema).readInt8(0);
          break;
        case SchemaType.INT16:
          deserialized = Buffer.from(elementSchema).readInt16BE(0);
          break;
        case SchemaType.INT32:
          deserialized = Buffer.from(elementSchema).readInt32BE(0);
          break;
        case SchemaType.INT64:
          deserialized = Buffer.from(elementSchema).readIntBE(0, elementSchema.length);
          break;
        case SchemaType.BOOL:
          deserialized = Buffer.from(elementSchema);
          break;
      }

      serializedSchema[decodedSchemaKey] = deserialized;

      return serializedSchema;
    }, {} as any);
    elements.push(deserializedRow);
    return elements;
  }, []);
}