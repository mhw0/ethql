// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library RLP {
  uint constant KIND_STRING = 0x01 << 0x00;
  uint constant KIND_LIST = 0x01 << 0x01;

  struct Element {
    uint kind;
    bytes data;
  }

  function loadFromBytesImpl(bytes memory data) internal pure returns(RLP.Element memory) {
    (uint kind, uint len, uint prefixBytes) = RLP.decodeLengthImpl(data);
    bytes memory buf = new bytes(data.length - prefixBytes);

    for(uint i = 0; i < len; i++)
      buf[i] = data[i + prefixBytes];

    return RLP.Element(kind, buf);
  }

  function decodeLengthImpl(bytes memory data) internal pure returns(uint, uint, uint) {
    if (data[0] >= 0x00 && data[0] <= 0x7F)
      return (RLP.KIND_STRING, uint(uint8(data[0])), 1);
    else if ((data[0] >= 0x80 && data[0] <= 0xB7) || (data[0] >= 0xC0 && data[0] <= 0xF7)) {
      uint kind = data[0] <= 0xb7 ? RLP.KIND_STRING : RLP.KIND_LIST;
      uint base = kind == RLP.KIND_STRING ? 0x80 : 0xc0;
      return (kind, uint8(data[0]) - base, 1);
    } else if ((data[0] >= 0xb8 && data[0] <= 0xbf) || (data[0] >= 0xf8 && data[0] <= 0xff)) {
      uint kind = data[0] <= 0xbf ? RLP.KIND_STRING : RLP.KIND_LIST;
      uint base = kind == RLP.KIND_STRING ? 0xb7 : 0xf7;
      uint lookaheadBytes = uint8(data[0]) - base;
      uint len = 0;

      for(uint i = 0; i < lookaheadBytes; i++)
        len |= (uint(uint8(data[i + 1])) << ((lookaheadBytes - i - 1) * 0x08));

      return (kind, len, lookaheadBytes + 1);
    }

    revert("RLP: invalid prefix");
  }

  function encodeLengthImpl(RLP.Element memory element) internal pure returns(bytes memory) {
    uint8 base = RLP.calculateBaseForImpl(element);
    uint len = element.data.length;

    if (len <= 0x37)
      return abi.encodePacked(uint8(base + len));
    else if (len <= 0xFF)
      return abi.encodePacked(base + 0x01, uint8(len));
    else if (len <= 0xFFFF)
      return abi.encodePacked(base + 0x02, uint8((len >> 0x08) & 0xFF), uint8(len & 0xFF));
    else if (len <= 0xFFFFFFFF)
      return abi.encodePacked(base + 0x04, uint8((len >> 0x18) & 0xFF), uint8((len >> 0x10) & 0xFF), uint8((len >> 0x08) & 0xFF), uint8(len & 0xFF));
    else if (len <= 0xFFFFFFFFFFFFFFFF)
      return abi.encodePacked(base + 0x08, uint8((len >> 0x38) & 0xFF), uint8((len >> 0x30) & 0xFF), uint8((len >> 0x28) & 0xFF), uint8((len >> 0x20) & 0xFF), uint8((len >> 0x18) & 0xFF), uint8((len >> 0x10) & 0xFF), uint8((len >> 0x08) & 0xFF), uint8(len & 0xFF));

    // TODO(mhw0): we could actually go beyond

    revert("RLP: length is too big");
  }

  function unshift(RLP.Element memory dest, RLP.Element memory target) public pure returns(RLP.Element memory) {
    require(dest.kind == RLP.KIND_LIST, "RLP: Expected list");
    return RLP.Element(dest.kind, abi.encodePacked(dest.data, target.data));
  }

  function calculateBaseForImpl(RLP.Element memory rlp) internal pure returns(uint8) {
    bytes memory data = rlp.data;

    if (rlp.kind == RLP.KIND_STRING)
      return data.length <= 0x37 ? 0x80 : 0xB7;
    else if (rlp.kind == RLP.KIND_LIST)
      return data.length <= 0x37 ? 0xC0 : 0xF7;

    revert("RLP: should not reach here");
  }

  function lhsPush(RLP.Element storage dest, RLP.Element memory target) public {
    // TODO(mhw0): does this copy entire storage bytes?
    dest.data = abi.encodePacked(dest.data, RLP.deserializeImpl(target));
  }

  function lhsConcat(RLP.Element storage dest, RLP.Element memory target) public {
    require(target.kind == RLP.KIND_LIST, "RLP: expected list as target");
    dest.data = abi.encodePacked(dest.data, target.data);
  }

  function concat(RLP.Element memory left, RLP.Element memory right) public pure returns(RLP.Element memory) {
    require(left.kind == RLP.KIND_LIST && right.kind == RLP.KIND_LIST, "RLP: both sides must be list to concat");
    return RLP.Element(RLP.KIND_LIST, abi.encodePacked(RLP.deserializeImpl(left), RLP.deserializeImpl(right)));
  }

  function deserializeImpl(RLP.Element memory element) internal pure returns (bytes memory) {
    return abi.encodePacked(RLP.encodeLengthImpl(element), element.data);
  }

  function deserialize(RLP.Element memory element) external pure returns(bytes memory) {
    return RLP.deserializeImpl(element);
  }

  function loadFromBytes(bytes memory data) external pure returns(RLP.Element memory) {
    return RLP.loadFromBytesImpl(data);
  }
}
