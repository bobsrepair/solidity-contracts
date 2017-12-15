pragma solidity ^0.4.18;

import './zeppelin/token/MintableToken.sol';
import './zeppelin/ownership/NoOwner.sol';
import './zeppelin/lifecycle/Destructible.sol';
import './TokenReceiver.sol';

contract BOBPToken is MintableToken, NoOwner, Destructible { //MintableToken is StandardToken, Ownable
    string public symbol = 'BOBP';
    string public name = 'BOB Promo';
    uint8 public constant decimals = 18;

    bool public transfersEnabled = true;
    TokenReceiver public ico;

    /**
     * Allow transfer only after crowdsale finished
     */
    modifier canTransfer() {
        require(transfersEnabled);
        _;
    }
    /**
    * @notice Use for disable transfers before exchange to main BOB tokens
    */
    function setTransfersEnabled(bool enable) onlyOwner public {
        transfersEnabled = enable;
    }
    
    function transfer(address _to, uint256 _value) canTransfer public returns (bool) {
        notifyICO(msg.sender, _to, _value);
        return super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) canTransfer public returns (bool) {
        notifyICO(_from, _to, _value);
        return super.transferFrom(_from, _to, _value);
    }

    function setICO(TokenReceiver _ico) onlyOwner public {
        ico = _ico;
    }
    function notifyICO(address _from, address _to, uint256 _value) internal {
        if(address(ico) != address(0) && _to == address(ico)){
            require(ico.tokenTransferNotify(address(this), _from, _value));
        }
    }
}

