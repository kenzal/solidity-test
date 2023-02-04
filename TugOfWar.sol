//SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;


/**
 * The TugOfWar contract is an over/under guessing game with balance on the line
 */
contract TugOfWar {
    address payable public owner;
    address payable public instigator;
    address payable public taker;
    uint public wager;
    uint public takerGuess;
    bytes32 public commitment;
    uint256 public expiration = 2**256 - 1;

    event contractWithdrawn(string _message);
    event contractCancelled(string _message);
    event challengeAccepted(address _taker, uint _guess);
    event challengeOutcome(address _winner, uint _pct, uint _amount);
    event SweetenResult(bool _result, bytes _data);

    modifier notTaken() { 
        require (taker == address(0)); 
        _; 
    }

    modifier onlyInstigator() { 
        require (msg.sender == instigator, "Not instigator."); 
        _; 
    }

    modifier onlyTaker() {
        require (msg.sender == taker, "Not taker.");
        _;
    }

    modifier onlyOwner() { 
        require (msg.sender == owner, "Not owner."); 
        _; 
    }

    modifier onlyTaken() {
        require (taker != address(0));
        _;
    }
    

    constructor(address _instigator, bytes32 _commitment) payable {
        require(msg.value >= 2, "Collateral equal to wager must be included.");
        owner = payable(msg.sender);
        instigator = payable(_instigator);
        commitment = _commitment;
        wager = msg.value/2;
    }
    
    function seppuku() onlyOwner public {
        selfdestruct(owner);
    }

    function withdraw(string memory _message) notTaken onlyInstigator public {
        (bool sent, ) = instigator.call{value: wager * 2}("");
        require(sent, "Failed to withdraw");
        (bool withdrawn, ) = taker.call(abi.encodeWithSignature("withdrawGame()"));
        require(withdrawn, "Failed to withdraw");
        emit contractWithdrawn(_message);
    }

    function cancel(string memory _message) notTaken onlyOwner public {
        (bool sent, ) = instigator.call{value: wager * 2}("");
        require(sent, "Failed to withdraw");
        emit contractCancelled(_message);
    }

    function take(uint _guess) notTaken payable public {
        require(msg.sender != instigator, "Instigator can not accept own challenge.");
        require(msg.sender != owner, "Owner may not accept challenge.");
        require(wager == msg.value, "Wager must match exactly");
        require(_guess >= 50 && _guess <= 100, 'Guess must be between 50 and 100 (inclusive).');
        taker = payable(msg.sender);
        takerGuess = _guess;
        expiration = block.timestamp + 1 weeks;
        emit challengeAccepted(taker, takerGuess);
    }

    function getPctOfPot(uint _pct) internal view returns (uint) {
        uint pot = wager*2;
        if (_pct > 100) _pct=100;
        return pot * _pct / 100;
    }

    function reveal(uint _guess, uint _nonce) onlyInstigator onlyTaken public {
        require (block.timestamp < expiration, "Chance to reveal has expired.");
        require(keccak256(abi.encodePacked(_guess, _nonce)) == commitment, "Revealed data does not match commitment");

        address payable winner;
        uint winningGuess;
        uint winningAmount;
        uint remaining;

        if (_guess < takerGuess) {
            winner = instigator;
            winningGuess = _guess;
            winningAmount = getPctOfPot(winningGuess);
            remaining = wager * 2 - winningAmount;
            // Return collateral and winnings to instigator;
            (bool returnSent, ) = instigator.call{value: (wager + winningAmount)}("");
            require(returnSent, "Failed to disburse");
        } else if (takerGuess < _guess) {
            winner = taker;
            winningGuess = takerGuess;
            winningAmount = getPctOfPot(winningGuess);
            remaining = wager * 2 - winningAmount;
            //Return Collateral to instigator
            (bool returnedCollateral, ) = instigator.call{value: wager}("");
            require(returnedCollateral, "Failed to return collateral.");
            //Send Winnings to Taker

            (bool takerSent, ) = taker.call{value: winningAmount}("");
            require(takerSent, "Failed to disburse");
        } else {
            // Game is a draw
            winningGuess = _guess;
            winningAmount = wager;
            remaining = 0;
            (bool sentInstigator, ) = instigator.call{value: wager + winningAmount}("");
            require(sentInstigator, "Failed to disburse");
            (bool sentTaker, ) = taker.call{value: wager}("");
            require(sentTaker, "Failed to disburse");
        }

        emit challengeOutcome(winner, winningGuess, winningAmount);
        (bool sweetenSent, bytes memory data) = owner.call{value: remaining}(
            abi.encodeWithSignature("sweeten(address,address)", address(instigator), address(taker))
        );
        emit SweetenResult(sweetenSent, data);
    }

    function claim() onlyTaker public {
        require (block.timestamp >= expiration, "Opportunity still exists to reveal.");
        // Instigator forfeits the win, but take still only gets percentage guessed
        
        uint winningAmount;
        uint remaining;

        winningAmount = getPctOfPot(takerGuess);
        remaining = wager * 2 - winningAmount;

        (bool sent, ) = taker.call{value: winningAmount}("");
        require(sent, "Failed to disburse");
        //Remainder, including collateral, goes to owner, both still listed for sweeten
        (bool sweetenSent, bytes memory data) = owner.call{value: remaining}(
            abi.encodeWithSignature("sweeten(address[])", [instigator, taker])
        );
        emit SweetenResult(sweetenSent, data);
    }

}

