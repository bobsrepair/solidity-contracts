pragma solidity ^0.4.13;

import './zeppelin/math/SafeMath.sol';
import './zeppelin/ownership/Ownable.sol';
import './zeppelin/ownership/HasNoContracts.sol';
import './zeppelin/ownership/HasNoTokens.sol';
import './BobToken.sol';


/**
 * @title BOB Crowdsale
 */
contract BobCrowdsale is Ownable, HasNoContracts, HasNoTokens {
    using SafeMath for uint256;

    struct Phase {
        uint256 start;      //Timestamp of crowdsale phase start
        uint256 end;        //Timestamp of crowdsale phase end
        uint256 rate;       //Rate: how much BOB one will get fo 1 ETH during this phase
        uint256 cap;        //Hard Cap of this phase
        uint256 collected;  //Ether already collected during this phase
    }

    uint256 public maxGasPrice  = 50000000000 wei;      //Maximum gas price for contribution transactions

    BobToken public token;              //Аddress of the BOB token contract
    bool public finalized;              //Is сrowdsale finalized? (token transfer will be allowed only after crowdsale finalization)

    Phase[] public phases;              
    uint256 public ownerRate;           //How many BOB will be reserved for owner for each ETH received
    
    /**
    * event for token purchase logging
    * @param purchaser who paid for the tokens
    * @param value weis paid for purchase
    * @param amount amount of tokens purchased
    */ 
    event TokenPurchase(address indexed purchaser, uint256 value, uint256 amount);

    /**
    * @dev verifies that the gas price is lower than maxGasPrice
    */
    modifier validGasPrice() {
        assert(tx.gasprice <= maxGasPrice);
        _;
    }

    /**
     * @dev Bob Crowdsale Contract
     */
    function BobCrowdsale(
        uint256[] phaseStarts,
        uint256[] phaseEnds,
        uint256[] phaseRates,
        uint256[] phaseCaps,
        uint256 _ownerRate) {
        
        //Check all paramaters are correct and create phases
        require(
            (phaseStarts.length > 0)  &&                //There should be at least one phase
            (phaseStarts.length == phaseEnds.length) &&
            (phaseStarts.length == phaseRates.length) &&
            (phaseStarts.length == phaseCaps.length)
        );                   
        uint256 prevPhaseEnd = now;
        phases.length = phaseStarts.length;             //initialize phases array
        for(uint8 i=0; i < phaseStarts.length; i++){
            phases[i] = Phase(phaseStarts[i], phaseEnds[i], phaseRates[i], phaseCaps[i], 0);
            Phase storage p = phases[i];
            require(prevPhaseEnd <= p.start);
            require(p.start < p.end);
            require(p.rate > 0);
            require(p.cap > 0);
            prevPhaseEnd = phases[i].end;
        }

        ownerRate = _ownerRate;

        token = new BobToken();
        token.setFounder(owner);
    }

    /**
    * @dev Fetches current rate (how many BOB you get for 1 ETH)
    * @return calculated rate or zero if crodsale not started or finished
    */
    function currentRate() constant public returns(uint256) {
        uint8 phaseNum = currentPhaseNum();
        if(phaseNum == 0) {
            return 0;
        }else{
            return phases[phaseNum-1].rate;
        }
    }
    /**
    * @dev Fetches current Phase number
    * @return phase number (index in phases array + 1) or 0 if none
    */
    function currentPhaseNum() constant public returns(uint8) {
        for(uint8 i=0; i < phases.length; i++){
            if( (now > phases[i].start) && (now <= phases[i].end) ) return i+1;
        }
        return 0;
    }
    /**
    * @return Amount of ether collected during all phases of Crowdsale
    */
    function totalCollected() constant public returns(uint256){
        uint256 collected = 0;
        for(uint8 i=0; i < phases.length; i++){
            collected = collected.add(phases[i].collected);
        }
        return collected;
    }

    /**
    * @dev Buy Bob tokens
    */
    function() payable validGasPrice {
        require(msg.value > 0);

        //get current phase (and check crowdsale is running)
        uint8 phaseNum = currentPhaseNum();
        if(phaseNum == 0) revert();
        uint8 phaseIdx = phaseNum-1;
        Phase storage p = phases[phaseIdx];
        
        //check max cap
        p.collected = p.collected.add(msg.value);
        if(p.collected > p.cap) revert();

        //send purshased tokens
        uint256 tokens = p.rate.mul(msg.value);
        assert(tokens > 0);
        assert(token.mint(msg.sender, tokens));
        TokenPurchase(msg.sender, msg.value, tokens);

        //send owners tokens
        uint256 ownerTokens = ownerRate.mul(msg.value);
        assert(token.mint(owner, ownerTokens));

        //send collected ether
        owner.transfer(msg.value);
    } 

    /**
    * @dev Updates max gas price for crowdsale transactions
    */
    function setMaxGasPrice(uint256 _maxGasPrice) public onlyOwner  {
        maxGasPrice = _maxGasPrice;
    }

    /**
    * @dev Finalizes ICO when one of conditions met:
    * - end time reached OR
    * - message sent by owner
    */
    function finalizeCrowdsale() public {
        require ( (now > phases[phases.length - 1].end) || (msg.sender == owner) );
        finalized = token.finishMinting();
        token.transferOwnership(owner);
    } 

}