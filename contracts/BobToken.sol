pragma solidity ^0.4.13;

import './zeppelin/token/MintableToken.sol';
import './zeppelin/ownership/HasNoContracts.sol';
import './zeppelin/ownership/HasNoTokens.sol';
import './zeppelin/ownership/HasNoEther.sol';

/**
 * @title WorldCoin token
 */
contract BobToken is MintableToken, HasNoContracts, HasNoTokens, HasNoEther { //MintableToken is StandardToken, Ownable
    using SafeMath for uint256;

    string public name = "Bob’s Repair Token";
    string public symbol = "BOB";
    uint256 public decimals = 18;

    address public founder;


    /**
     * Allow transfer only after crowdsale finished
     */
    modifier canTransfer() {
        require(mintingFinished || msg.sender == founder);
        _;
    }

    /**
    * @dev set Founder address
    * Only owner allowed to do this
    */
    function setFounder(address _founder) onlyOwner {
        founder = _founder;
    }    
    
    function transfer(address _to, uint256 _value) canTransfer returns (bool) {
        super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) canTransfer returns (bool) {
        super.transferFrom(_from, _to, _value);
    }

}
