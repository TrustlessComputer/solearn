// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

library Queue {
    struct Uint256Queue {
        mapping(uint256 => uint256) values;
        uint256 begin;
        uint256 end;
    }

    error Uint256Queue_Empty();

    function init(Uint256Queue storage _queue) internal {
        _queue.begin = 1;
        _queue.end = 0;
    }

    function push(Uint256Queue storage _queue, uint256 _value) internal {
        _queue.values[++_queue.end] = _value;
    }

    function pop(Uint256Queue storage _queue) internal {
        uint256 begin = _queue.begin;
        if (begin > _queue.end) revert Uint256Queue_Empty();
        delete _queue.values[begin++];
    }

    function front(Uint256Queue storage _queue) internal view returns (uint256) {
        uint256 begin = _queue.begin;
        if (begin > _queue.end) revert Uint256Queue_Empty();
        return _queue.values[begin];
    }

    function back(Uint256Queue storage _queue) internal view returns (uint256) {
        uint256 end = _queue.end;
        if (_queue.begin > end) revert Uint256Queue_Empty();
        return _queue.values[end];
    }

    function isEmpty(Uint256Queue storage _queue) internal view returns (bool) {
        return _queue.begin > _queue.end;
    }
}
