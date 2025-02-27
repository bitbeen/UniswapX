// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IReactorCallback} from "../interfaces/IReactorCallback.sol";
import {IReactor} from "../interfaces/IReactor.sol";
import {BaseReactor} from "../reactors/BaseReactor.sol";
import {OrderInfo, ResolvedOrder, SignedOrder} from "../base/ReactorStructs.sol";

/// @notice Quoter contract for orders
/// @dev note this is meant to be used as an off-chain lens contract to pre-validate generic orders
contract OrderQuoter is IReactorCallback {
    /// @notice thrown if reactorCallback receives more than one order
    error OrdersLengthIncorrect();

    uint256 constant ORDER_INFO_OFFSET = 64;

    /// @notice Quote the given order, returning the ResolvedOrder object which defines
    /// the current input and output token amounts required to satisfy it
    /// Also bubbles up any reverts that would occur during the processing of the order
    /// @param order abi-encoded order, including `reactor` as the first encoded struct member
    /// @param sig The order signature
    /// @return result The ResolvedOrder
    function quote(bytes memory order, bytes memory sig) external returns (ResolvedOrder memory result) {
        try IReactor(getReactor(order)).execute(SignedOrder(order, sig), this, bytes("")) {}
        catch (bytes memory reason) {
            result = parseRevertReason(reason);
        }
    }

    /// @notice Return the reactor of a given order (abi.encoded bytes).
    /// @param order abi-encoded order, including `reactor` as the first encoded struct member
    /// @return reactor
    function getReactor(bytes memory order) public pure returns (IReactor reactor) {
        assembly {
            let orderInfoOffsetPointer := add(order, ORDER_INFO_OFFSET)
            reactor := mload(add(orderInfoOffsetPointer, mload(orderInfoOffsetPointer)))
        }
    }

    /// @notice Return the order info of a given order (abi-encoded bytes).
    /// @param order abi-encoded order, including `reactor` as the first encoded struct member
    function parseRevertReason(bytes memory reason) private pure returns (ResolvedOrder memory order) {
        if (reason.length < 192) {
            assembly {
                revert(add(32, reason), mload(reason))
            }
        } else {
            return abi.decode(reason, (ResolvedOrder));
        }
    }

    /// @notice Reactor callback function
    /// @dev reverts with the resolved order as reason
    /// @param resolvedOrders The resolved orders
    /// @param filler The filler of the order
    function reactorCallback(ResolvedOrder[] memory resolvedOrders, address filler, bytes memory) external view {
        require(filler == address(this));
        if (resolvedOrders.length != 1) {
            revert OrdersLengthIncorrect();
        }
        bytes memory order = abi.encode(resolvedOrders[0]);
        assembly {
            revert(add(32, order), mload(order))
        }
    }
}
