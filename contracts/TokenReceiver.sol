pragma solidity ^0.4.18;

contract TokenReceiver {
    function tokenTransferNotify(address token, address from, uint256 value) public returns (bool);
}