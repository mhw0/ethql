// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library RLP {
  // TODO(mhw0): we could use enum here but ethers complains about it
  uint constant KIND_INVALID = 0x01 << 0x00;
  uint constant KIND_STRING = 0x01 << 0x01;
  uint constant KIND_LIST = 0x01 << 0x02;

  /* Stores RLP element data */
  struct Element {
    uint kind;
    bytes data;
  }

  function loadFromBytesImpl(bytes memory data) internal pure returns(RLP.Element memory) {
    (uint kind, uint len, uint prefixBytes) = RLP.unpackImpl(data);
    bytes memory buf = new bytes(data.length - prefixBytes);

    for(uint i = 0; i < len; i++)
      buf[i] = data[i + prefixBytes];

    return RLP.Element(kind, buf);
  }

  function loadFromBytes(bytes memory data) external pure returns(RLP.Element memory) {
    return RLP.loadFromBytesImpl(data);
  }

  function concatLhs(RLP.Element storage dest, RLP.Element memory target) external {
    for(uint i = 0; i < target.data.length; i++)
      dest.data.push(target.data[i]);
  }
  
  function unpackImpl(bytes memory data) internal pure returns(uint, uint, uint) {
    if (data[0] >= 0x00 && data[0] <= 0x7f)
      return (RLP.KIND_STRING, uint(uint8(data[0])), 1);
    else if ((data[0] >= 0x80 && data[0] <= 0xb7) || (data[0] >= 0xc0 && data[0] <= 0xf7)) {
      uint kind = data[0] <= 0xb7 ? RLP.KIND_STRING : RLP.KIND_LIST;
      uint base = kind == RLP.KIND_STRING ? 0x80 : 0xc0;
      return (kind, uint8(data[0]) - base, 1);
    } else if ((data[0] >= 0xb8 && data[0] <= 0xbf) || (data[0] >= 0xf8 && data[0] <= 0xff)) {
      uint kind = data[0] <= 0xbf ? RLP.KIND_STRING : RLP.KIND_LIST;
      uint base = kind == RLP.KIND_STRING ? 0xb7 : 0xf7;
      uint lookaheadBytes = uint8(data[0]) - base;
      uint len = 0;

      for(uint i = 0; i < lookaheadBytes; i++)
        len |= (uint(uint8(data[i + 1])) << (lookaheadBytes - 1 - (i * 0x08)));

      return (kind, len, lookaheadBytes + 1);
    }

    require(false, "RLP: invalid prefix");
    return (RLP.KIND_INVALID, 0, 0); // to bypass the warning
  }

  function unshift(RLP.Element memory dest, RLP.Element memory target) public pure returns(RLP.Element memory) {
    require(dest.kind == RLP.KIND_LIST, "RLP: Expected list");
    return RLP.Element(dest.kind, abi.encodePacked(dest.data, target.data));
  }

  function push(RLP.Element storage dest, RLP.Element memory target) public {
    for(uint i = 0; i < target.data.length; i++)
      dest.data.push(target.data[i]);
  }

  function encodeLookaheadLengthImpl(uint8 base, uint len) internal pure returns(bytes memory) {
    if (len <= 0xFF)
      return abi.encodePacked(base + 0x01, uint8(len));
    else if (len <= 0xFFFF)
      return abi.encodePacked(base + 0x02, uint8((len >> 0x08) & 0xFF), uint8(len & 0xFF));
    else if (len <= 0xFFFFFFFF)
      return abi.encodePacked(base + 0x04, uint8((len >> 0x18) & 0xFF), uint8((len >> 0x10) & 0xFF), uint8((len >> 0x08) & 0xFF), uint8(len & 0xFF));
    else if (len <= 0xFFFFFFFFFFFFFFFF)
      return abi.encodePacked(base + 0x08, uint8((len >> 0x38) & 0xFF), uint8((len >> 0x30) & 0xFF), uint8((len >> 0x28) & 0xFF), uint8((len >> 0x20) & 0xFF), uint8((len >> 0x18) & 0xFF), uint8((len >> 0x10) & 0xFF), uint8((len >> 0x08) & 0xFF), uint8(len & 0xFF));

    require(false, "RLP: too big data");
  }

  function encodeFixedLengthImpl(uint8 base, uint8 len) internal pure returns(bytes memory) {
    return abi.encodePacked(base + len);
  }

  function deserialize(RLP.Element memory element) external pure returns(bytes memory) {
    return RLP.deserializeImpl(element);
  }

  function deserializeImpl(RLP.Element memory element) internal pure returns (bytes memory) {
    bytes memory data = element.data;

    // TODO(mhw0): refactor me
    if (element.kind == RLP.KIND_LIST) {
      bytes memory len = data.length <= 0x37
        ? RLP.encodeFixedLengthImpl(0xc0, uint8(data.length))
        : RLP.encodeLookaheadLengthImpl(0xf7, data.length);
      return abi.encodePacked(len, data);
    } else if (element.kind == RLP.KIND_STRING) {
      bytes memory len = data.length <= 0x37
        ? RLP.encodeFixedLengthImpl(0x80, uint8(data.length))
        : RLP.encodeLookaheadLengthImpl(0xb7, data.length);
      return abi.encodePacked(len, data);
    }

    return data;
  }
}
