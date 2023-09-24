// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library RLP {
  uint constant FLAG_TYPE_LIST = 0x01 << 0x00;
  uint constant FLAG_TYPE_DUMMY = 0x01 << 0x01;
  uint constant FLAG_TYPE_STRING = 0x01 << 0x02;

  struct Element {
    bytes data;
    uint flags;
  }

  function isStringImpl(RLP.Element memory rlp) internal pure returns(bool) {
    if (rlp.data.length == 0)
      return (rlp.flags & RLP.FLAG_TYPE_STRING) != 0;

    return (rlp.data[0] >= 0x00 && rlp.data[0] <= 0x7f)
        || (rlp.data[0] >= 0x80 && rlp.data[0] <= 0xb7)
        || (rlp.data[0] >= 0xb8 && rlp.data[0] <= 0xbf);
  }
  
  function isListImpl(RLP.Element memory rlp) internal pure returns(bool) {
    if (rlp.data.length == 0)
      return (rlp.flags & RLP.FLAG_TYPE_LIST) != 0;

    return (rlp.data[0] >= 0xc0 && rlp.data[0] <= 0xf7)
        || (rlp.data[0] >= 0xf8 && rlp.data[0] <= 0xff);
  }

  function getLengthImpl(RLP.Element memory rlp) internal pure returns(uint) {
    if (rlp.data[0] >= 0x00 && rlp.data[0] <= 0x7f)
      return uint(uint8(rlp.data[0]));
    else if (rlp.data[0] >= 0x80 && rlp.data[0] <= 0xb7)
      return uint(uint8(rlp.data[0])) - 0x80;
    else if (rlp.data[0] >= 0xc0 && rlp.data[0] <= 0xf7)
      return uint(uint8(rlp.data[0])) - 0xc0;
    else if ((rlp.data[0] >= 0xb8 && rlp.data[0] <= 0xbf)
        || (rlp.data[0] >= 0xf8 && rlp.data[0] <= 0xff)) {
      uint base = uint(uint8(rlp.data[0] > 0xf8 ? 0xf7 : 0xb7));
      uint lookaheadBytes = uint8(rlp.data[0]) - base;
      uint len = 0;
      for(uint i = 0; i < lookaheadBytes; i++)
        len |= (uint(uint8(rlp.data[0])) << ((lookaheadBytes - i) * 0x08));
      return len;
    }

    return 0;
  }

  function getLength(RLP.Element memory rlp) public pure returns(uint) {
    return RLP.getLengthImpl(rlp);
  }

  function isList(RLP.Element memory rlp) public pure returns(bool) {
    return RLP.isListImpl(rlp);
  }

  function isString(RLP.Element memory rlp) public pure returns(bool) {
    return RLP.isStringImpl(rlp);
  }

  function unshift(RLP.Element memory dest, RLP.Element memory target) public pure returns(RLP.Element memory) {
    require(RLP.isListImpl(dest), "RLP: Expected list");
    return RLP.Element(abi.encodePacked(dest.data, target.data), RLP.FLAG_TYPE_LIST);
  }

  function push(RLP.Element storage dest, RLP.Element memory target) public {
    for(uint i = 0; i < target.data.length; i++)
      dest.data.push(target.data[i]);
  }

  function encodeLookaheadLengthImpl(uint8 base, uint len) internal pure returns(bytes memory) {
    if (len <= 0xFF)
      return abi.encodePacked(base + 0x01, uint8(len));
    else if (len <= 0xFFFF)
      return abi.encodePacked(base + 0x02, (len >> 0x08) & 0xFF, len & 0xFF);
    else if (len <= 0xFFFFFFFF)
      return abi.encodePacked(base + 0x04, (len >> 0x18) & 0xFF, (len >> 0x10) & 0xFF, (len >> 0x08) & 0xFF, len & 0xFF);
    else if (len <= 0xFFFFFFFFFFFFFFFF)
      return abi.encodePacked(base + 0x08, (len >> 0x38) & 0xFF, (len >> 0x30) & 0xFF, (len >> 0x28) & 0xFF, (len >> 0x20) & 0xFF, (len >> 0x18) & 0xFF, (len >> 0x10) & 0xFF, (len >> 0x08) & 0xFF, len & 0xFF);

    require(false, "RLP: too big RLP data");
  }

  function encodeFixedLengthImpl(uint8 base, uint len) internal pure returns(bytes memory) {
    return abi.encodePacked(base + uint8(len));
  }

  function deserialize(RLP.Element memory element) public pure returns (bytes memory) {
    bytes memory data = element.data;

    // TODO(mhw0): refactor me
    if ((element.flags & RLP.FLAG_TYPE_LIST) != 0) {
      bytes memory len = data.length <= 55
        ? RLP.encodeFixedLengthImpl(0xc0, data.length)
        : RLP.encodeLookaheadLengthImpl(0xf7, data.length);
      return abi.encodePacked(len, data);
    } else if ((element.flags & RLP.FLAG_TYPE_STRING) != 0) {
      bytes memory len = data.length <= 55
        ? RLP.encodeFixedLengthImpl(0x80, data.length)
        : RLP.encodeLookaheadLengthImpl(0xb7, data.length);
      return abi.encodePacked(len, data);
    }

    return data;
  }
}
