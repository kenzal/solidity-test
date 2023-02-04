//SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "./TugOfWar.sol";

/**
 * The TugOfWarSweepstakes contract creates and manages TugOfWar games and recieves the surplus funds
 * At a time of the owner's choosing, all available funds (minus a commission) will be lotteried off
 * to one of the TugOfWar players from the gaming period.
 */
contract TugOfWarSweepstakes {
    address payable public owner;
    uint public contestBalance;
    uint public maintenanceBalance;
    uint public winningsBalance;
    bool public locked;
    mapping(address => bool) allGames;
    mapping(address => uint) winnings;
    address[] public tickets;
    address[] public gamesGarbage;


    event Log(string _message);

    modifier onlyOwner() { 
        require (msg.sender == owner, "Not owner."); 
        _; 
    }

    modifier fromValidGameOnly() { 
        require (allGames[msg.sender]); 
        _; 
    }    

    constructor() payable {
        owner = payable(msg.sender);
        maintenanceBalance = msg.value;
    }

    receive() external payable {
        maintenanceBalance += msg.value;
    }

    fallback() external payable {
        maintenanceBalance += msg.value;
    }
    

    function getCommitment(uint _guess, uint _nonce) pure public returns (bytes32)  {
        require(_guess >= 50 && _guess <= 100, 'Guess must be between 50 and 100 (inclusive).');
        return keccak256(abi.encodePacked(_guess, _nonce));
    }

    function instigateChallenge (bytes32 _commitment) payable public returns(address)  {
        TugOfWar game;
        game = new TugOfWar{value: msg.value}(msg.sender, _commitment);
        allGames[address(game)] = true;
        return address(game);
    }

    function transfer(address payable _to, uint amount) public {
        require(amount>0, "Amount must be provided");
        require(amount <= winnings[msg.sender] && amount <= winningsBalance, "Not Enough Funds");
        (bool sent, ) = _to.call{value: amount}("");
        require(sent, "Failed to disburse");
        winnings[msg.sender] -= amount;
        winningsBalance -= amount;
    }

    function transferMaintenance(address payable _to, uint amount) onlyOwner public {
        require(amount>0, "Amount must be provided");
        require(amount <= maintenanceBalance, "Not Enough Funds");
        (bool sent, ) = _to.call{value: amount}("");
        require(sent, "Failed to disburse");
        maintenanceBalance -= amount;
    }
    
    function sweep() onlyOwner public {
        uint found;
        found = address(this).balance - (contestBalance + winningsBalance + maintenanceBalance);
        maintenanceBalance += found;
    }

    function sweeten(address _p1, address _p2) fromValidGameOnly payable public {
        emit Log("Sweeten Called.");
        allGames[msg.sender]=false;
        gamesGarbage.push(msg.sender);
        tickets.push(_p1);
        tickets.push(_p2);
        contestBalance += msg.value;
    }

    function withdrawGame() fromValidGameOnly public {
        allGames[msg.sender]=false;
        gamesGarbage.push(msg.sender);
    }

    function cancelGame(TugOfWar game, string memory _message) onlyOwner public {
        game.cancel(_message);
        allGames[address(game)] = false;
        gamesGarbage.push(msg.sender);
    }
  
}
