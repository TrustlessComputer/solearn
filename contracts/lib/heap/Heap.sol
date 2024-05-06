// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IHeapComparator} from "./IHeapComparator.sol";

library Heap {
    // Address Heap
    struct AddressHeap {
        mapping(uint256 => address) values;
        mapping(address => uint256) positions;
        address comparator;
        int64 identifier;
        uint256 size;
    }

    error EmptyAddressHeap();
    error AddressHeapValueNotFound(address value);
    error DuplicatedAddressHeapValue(address value);

    function _up(AddressHeap storage _heap, uint256 _node, address _value) private {
        mapping(uint256 => address) storage values = _heap.values;
        mapping(address => uint256) storage positions = _heap.positions;
        function(address, address, int64) external view returns (bool) compare
        = IHeapComparator(_heap.comparator).compareAddress;
        int64 identifier = _heap.identifier;
        while (_node > 1) {
            uint256 parentNode = _node >> 1;
            address parentAddr = values[parentNode];
            if (compare(parentAddr, _value, identifier)) break;
            values[parentNode] = _value;
            positions[_value] = parentNode;

            values[_node] = parentAddr;
            positions[parentAddr] = _node;

            _node = parentNode;
        }
    }

    function _down(AddressHeap storage _heap, uint256 _node, address _value) private {
        mapping(uint256 => address) storage values = _heap.values;
        mapping(address => uint256) storage positions = _heap.positions;
        function(address, address, int64) external view returns (bool) compare
        = IHeapComparator(_heap.comparator).compareAddress;
        int64 identifier = _heap.identifier;
        uint256 size = _heap.size;
        while (true) {
            uint256 childNode = _node << 1;
            address childAddr = values[childNode];
            if (childNode > size) break;
            if (childNode < size && compare(values[childNode | 1], childAddr, identifier)) {
                childNode |= 1;
                childAddr = values[childNode];
            }

            if (compare(_value, childAddr, identifier)) break;
            values[childNode] = _value;
            positions[_value] = childNode;

            values[_node] = childAddr;
            positions[childAddr] = _node;

            _node = childNode;
        }
    }

    function up(AddressHeap storage _heap, address _value) internal {
        uint256 node = _heap.positions[_value];
        if (node == 0) revert AddressHeapValueNotFound(_value);
        _up(_heap, node, _value);
    }

    function down(AddressHeap storage _heap, address _value) internal {
        uint256 node = _heap.positions[_value];
        if (node == 0) revert AddressHeapValueNotFound(_value);
        _down(_heap, node, _value);
    }

    function hasValue(AddressHeap storage _heap, address _value) internal view returns (bool) {
        return _heap.positions[_value] != 0;
    }

    function push(AddressHeap storage _heap, address _value) internal {
        if (_heap.positions[_value] != 0) revert DuplicatedAddressHeapValue(_value);
        uint256 node = ++_heap.size;
        _heap.values[node] = _value;
        _heap.positions[_value] = node;
        _up(_heap, node, _value);
    }

    function peek(AddressHeap storage _heap) internal view returns (address) {
        if (_heap.size == 0) revert EmptyAddressHeap();
        return _heap.values[1];
    }

    function pop(AddressHeap storage _heap) internal {
        if (_heap.size == 0) revert EmptyAddressHeap();
        if (_heap.size == 1) {
            _heap.size = 0;
            _heap.positions[_heap.values[1]] = 0;
        } else {
            mapping(uint256 => address) storage values = _heap.values;
            mapping(address => uint256) storage positions = _heap.positions;
            address addr = values[_heap.size];
            positions[values[1]] = 0;
            values[1] = addr;
            positions[addr] = 1;
            _heap.size--;
            _down(_heap, 1, addr);
        }
    }

    function remove(AddressHeap storage _heap, address _value) internal {
        if (_heap.positions[_value] == 0) revert AddressHeapValueNotFound(_value);

        mapping(address => uint256) storage positions = _heap.positions;
        uint256 node = positions[_value];
        positions[_value] = 0;
        if (node == _heap.size) {
            _heap.size--;
        } else {
            mapping(uint256 => address) storage values = _heap.values;
            address newAddr = values[_heap.size];
            _heap.size--;
            values[node] = newAddr;
            positions[newAddr] = node;
            if (node != 1
                && IHeapComparator(_heap.comparator).compareAddress(newAddr, values[node >> 1], _heap.identifier)) {
                _up(_heap, node, newAddr);
            } else {
                _down(_heap, node, newAddr);
            }
        }
    }

    // Uint256 Heap
    struct Uint256Heap {
        mapping(uint256 => uint256) values;
        mapping(uint256 => uint256) positions;
        address comparator;
        int64 identifier;
        uint256 size;
    }

    error EmptyUint256Heap();
    error Uint256HeapValueNotFound(uint256 value);
    error DuplicatedUint256HeapValue(uint256 value);

    function _up(Uint256Heap storage _heap, uint256 _node, uint256 _value) private {
        mapping(uint256 => uint256) storage values = _heap.values;
        mapping(uint256 => uint256) storage positions = _heap.positions;
        function(uint256, uint256, int64) external view returns (bool) compare
            = IHeapComparator(_heap.comparator).compareUint256;
        int64 identifier = _heap.identifier;
        while (_node > 1) {
            uint256 parentNode = _node >> 1;
            uint256 parentAddr = values[parentNode];
            if (compare(parentAddr, _value, identifier)) break;
            values[parentNode] = _value;
            positions[_value] = parentNode;

            values[_node] = parentAddr;
            positions[parentAddr] = _node;

            _node = parentNode;
        }
    }

    function _down(Uint256Heap storage _heap, uint256 _node, uint256 _value) private {
        mapping(uint256 => uint256) storage values = _heap.values;
        mapping(uint256 => uint256) storage positions = _heap.positions;
        function(uint256, uint256, int64) external view returns (bool) compare
            = IHeapComparator(_heap.comparator).compareUint256;
        int64 identifier = _heap.identifier;
        uint256 size = _heap.size;
        while (true) {
            uint256 childNode = _node << 1;
            uint256 childAddr = values[childNode];
            if (childNode > size) break;
            if (childNode < size && compare(values[childNode | 1], childAddr, identifier)) {
                childNode |= 1;
                childAddr = values[childNode];
            }

            if (compare(_value, childAddr, identifier)) break;
            values[childNode] = _value;
            positions[_value] = childNode;

            values[_node] = childAddr;
            positions[childAddr] = _node;

            _node = childNode;
        }
    }

    function up(Uint256Heap storage _heap, uint256 _value) internal {
        uint256 node = _heap.positions[_value];
        if (node == 0) revert Uint256HeapValueNotFound(_value);
        _up(_heap, node, _value);
    }

    function down(Uint256Heap storage _heap, uint256 _value) internal {
        uint256 node = _heap.positions[_value];
        if (node == 0) revert Uint256HeapValueNotFound(_value);
        _down(_heap, node, _value);
    }

    function hasValue(Uint256Heap storage _heap, uint256 _value) internal view returns (bool) {
        return _heap.positions[_value] != 0;
    }

    function push(Uint256Heap storage _heap, uint256 _value) internal {
        if (_heap.positions[_value] != 0) revert DuplicatedUint256HeapValue(_value);
        uint256 node = ++_heap.size;
        _heap.values[node] = _value;
        _heap.positions[_value] = node;
        _up(_heap, node, _value);
    }

    function peek(Uint256Heap storage _heap) internal view returns (uint256) {
        if (_heap.size == 0) revert EmptyUint256Heap();
        return _heap.values[1];
    }

    function pop(Uint256Heap storage _heap) internal {
        if (_heap.size == 0) revert EmptyUint256Heap();
        if (_heap.size == 1) {
            _heap.size = 0;
            _heap.positions[_heap.values[1]] = 0;
        } else {
            mapping(uint256 => uint256) storage values = _heap.values;
            mapping(uint256 => uint256) storage positions = _heap.positions;
            uint256 addr = values[_heap.size];
            positions[values[1]] = 0;
            values[1] = addr;
            positions[addr] = 1;
            _heap.size--;
            _down(_heap, 1, addr);
        }
    }

    function remove(Uint256Heap storage _heap, uint256 _value) internal {
        if (_heap.positions[_value] == 0) revert Uint256HeapValueNotFound(_value);

        mapping(uint256 => uint256) storage positions = _heap.positions;
        uint256 node = positions[_value];
        positions[_value] = 0;
        if (node == _heap.size) {
            _heap.size--;
        } else {
            mapping(uint256 => uint256) storage values = _heap.values;
            uint256 newAddr = values[_heap.size];
            _heap.size--;
            values[node] = newAddr;
            positions[newAddr] = node;
            if (node != 1
                && IHeapComparator(_heap.comparator).compareUint256(newAddr, values[node >> 1], _heap.identifier)) {
                _up(_heap, node, newAddr);
            } else {
                _down(_heap, node, newAddr);
            }
        }
    }
}
