pragma solidity ^0.4.22;

import './interfaces/Owned.sol';

contract Voting is Owned {
    // Declare a complex type to reresent a single voter.

    struct Vote {        
        bool voted;  // if true, that person already voted
        uint vote;  
    }

    struct Voter {        
        //bool voted;  // if true, that person already voted
        //uint vote;   // index of the voted proposal
        address addr;
        bool rightToVote; // if true, that person has right to vote
        uint weight;
        mapping (uint => Vote) votes;
    }

    // This is a type for a single proposal.
    struct ProposalOption
    {
        bytes32 name;   // short name for option
        uint voteCount; // number of accumulated votes
    }

    // This is a type for a single proposal.
    struct Proposal
    {
        string name;   // short name for proposal
        uint votingStart;
        uint votingTime;
        uint proposalBatch;
        uint numOptions;
        uint numCastedVotes;
        bool isEnded;
        mapping (uint => ProposalOption) proposalOptions;
        uint winningProposalOption;
        bytes32 winningProposalOptionName;
    }

    
    address public chairperson;    
    mapping(uint => Voter) public voters;

    mapping (uint => Proposal) public proposals;
    uint public numProposals;
    uint public numVoters;
    uint public numEndedProposals;
    event Voted (address voter, uint proposal, uint proposalOption);
    event ProposalEnded (uint proposal, uint winningProposalOption);
    //uint public numProposalOptions;


    constructor() public {
        chairperson = msg.sender;
        numVoters=1;
        Voter storage v = voters[numVoters];
        v.addr=chairperson;
        v.rightToVote = true;
        v.weight = 100;
        //voters[numVoters].addr=chairperson;
        //voters[numVoters].rightToVote = true;
        //voters[numVoters].weight = 1;
        numProposals=0;
        numEndedProposals=0;
    }

    function changeChairman(address newAddress) public onlyOwner {
        chairperson = newAddress;
    }

    function createProposal(string proposalName, bytes32[] optionNames, uint votingTime, uint proposalBatchNumber) public {  
        if (msg.sender != chairperson) {
            // `revert()` terminates and reverts all changes to the state
            revert();
        }    
        
        numProposals=numProposals+1;
        Proposal storage p = proposals[numProposals]; 
        p.name = proposalName;
        p.numOptions=0;
        p.isEnded=false;
        p.votingStart = now;
        p.votingTime = votingTime;
        p.proposalBatch = proposalBatchNumber;
        p.winningProposalOption=99999;
        p.numCastedVotes=0;

        // For each of the provided proposal names,
        // create a new proposal object and add it
        // to the end of the array.
        //numProposalOptions=numProposalOptions+1;
        for (uint i = 0; i < optionNames.length; i++) {
            //ProposalOption po; 
            //po.name = optionNames[i];
            //po.voteCount = 0;
            //p.proposalOptions[p.numOptions]=po;
            p.proposalOptions[i].name=optionNames[i];
            p.proposalOptions[i].voteCount=0;
            p.numOptions=p.numOptions+1;
        }
    }


    function giveRightToVoteFounder(address voterAddress) public {
        if (msg.sender != chairperson) {
            // `revert()` terminates and reverts all changes to the state
            revert();
        }

        for (uint i=1; i<=numVoters;i++){
            if (voters[i].addr==voterAddress){                
                revert(); //voter already exists
            }
        }

        numVoters=numVoters+1;        
        Voter storage v = voters[numVoters];
        v.addr=voterAddress;
        v.rightToVote = true;
        v.weight = 100;
    }

    function giveRightToVoteMember(address voterAddress) public {
        if (msg.sender != chairperson) {
            // `revert()` terminates and reverts all changes to the state
            revert();
        }

        for (uint i=1; i<=numVoters;i++){
            if (voters[i].addr==voterAddress){                
                revert(); //voter already exists
            }
        }

        numVoters=numVoters+1;        
        Voter storage v = voters[numVoters];
        v.addr=voterAddress;
        v.rightToVote = true;
        v.weight = 0;
    }

    function revokeRightToVote(address voterAddress) public {
        if (msg.sender != chairperson) {
            // `revert()` terminates and reverts all changes to the state
            revert();
        }
        //voters[voter].rightToVote = false;
        //voters[voter].weight = 0;
        for (uint i=1; i<=numVoters;i++){
            if (voters[i].addr==voterAddress){
                voters[i].rightToVote = false;
                voters[i].weight = 0;
            }
        }
    }

    function vote(uint proposal, uint proposalOption) public {
        if (now > proposals[proposal].votingStart + proposals[proposal].votingTime) {
            // Revert the call if the voting period is over
            revert();
        }

        //Voter sender = voters[msg.sender];

        for (uint i=1; i<=numVoters;i++){
            if (voters[i].addr==msg.sender){
                Voter storage sender = voters[i];
            }
        }

        if (sender.votes[proposal].voted==true){
            revert();
        }

        if (sender.rightToVote==false){
            revert();
        }

        sender.votes[proposal].voted = true;
        sender.votes[proposal].vote = proposalOption;
        proposals[proposal].proposalOptions[proposalOption].voteCount += sender.weight;
        proposals[proposal].numCastedVotes +=1;
        Voted (sender.addr, proposal, proposalOption);
        
    }

    function hasUserVoted(uint proposal, address user) public view 
            returns (bool result)
    {        
        for (uint i=1; i<=numVoters;i++){
            if (voters[i].addr==user){
                Voter storage sender = voters[i];
            }
        }
        result=sender.votes[proposal].voted;            
    }

    function getVoterDetail(address user) public view 
            returns (bool result, uint weight)
    {   
        Voter storage sender;
        sender.rightToVote = false;
        sender.weight = uint(0);
        for (uint i=1; i<=numVoters;i++){
            if (voters[i].addr==user){
                sender = voters[i];
            }
        }
        result=sender.rightToVote;            
        weight=sender.weight;            
    }

    function finalizeProposal(uint proposal) public
            returns (string proposalName, uint winningProposalOption, bytes32 winningProposalOptionName)
        {
        if (msg.sender != chairperson) {            
            revert();
        }
        if (now <= proposals[proposal].votingStart + proposals[proposal].votingTime){
            revert(); // voting did not yet end
        }
        if (proposals[proposal].isEnded == true){
            revert("The proposal has already ended and cannot be refinalized");
        }
        uint winningVoteCount = 0;
        uint numProposalOptions=proposals[proposal].numOptions;
        
        for (uint i = 0; i < numProposalOptions; i++) {
            if (proposals[proposal].proposalOptions[i].voteCount > winningVoteCount) {
                winningVoteCount = proposals[proposal].proposalOptions[i].voteCount;
                winningProposalOption = i;
                //proposalName = proposals[proposal].name;
                //winningProposalOptionName=proposals[proposal].proposalOptions[i].name;
            }
        }

        proposals[proposal].winningProposalOption=winningProposalOption;
        winningProposalOptionName=proposals[proposal].proposalOptions[winningProposalOption].name;
        proposalName = proposals[proposal].name;
        proposals[proposal].winningProposalOptionName=winningProposalOptionName;
        proposals[proposal].isEnded=true;
        numEndedProposals=numEndedProposals+1;
        ProposalEnded(proposal, winningProposalOption);

        uint proposalsInBatch = 0;
        for (uint j=0; j<=numProposals;j++){
            if (proposals[proposal].proposalBatch == proposals[j].proposalBatch) {
                proposalsInBatch += 1;
            }
        }
        //uint precision = 0; //precision is how many decimal places to round, currently it is set to only whole numbers
        uint dynamicVoterWeight = uint(100)*(10**0) / proposalsInBatch; //Calculates a dynamic voting weight based on the total amount of proposals in a batch.
        
        for (i=1; i<=numVoters;i++){
            Voter storage voter = voters[i];
            
            if(voter.votes[proposal].voted == true){
                //Increase weight by amount of total proposals in a batch dependent on a successful vote
                if (voter.weight < 400){
                    voter.weight = voter.weight+dynamicVoterWeight;
                    if (voter.weight > 400) {
                        uint voterExceed = voter.weight - 400;
                        voter.weight = voter.weight - voterExceed;
                    }
                }
            }else{
                //Decrease weight by amount of total proposals in a batch dependent on a successful vote
                if (voter.weight > 100){
                    voter.weight = voter.weight-dynamicVoterWeight;
                    if (voter.weight < 100) {
                        uint voterUnder = 100 - voter.weight;
                        voter.weight = voter.weight + voterUnder;
                    }
                }
                    
            }
        }
    }

    function getProposalResult(uint proposal) public view
            returns (string proposalName, uint winningProposalOption, bytes32 winningProposalOptionName, uint proposalBatchNumber)
    {
        if(proposals[proposal].isEnded){
            proposalName = proposals[proposal].name;
            proposalBatchNumber = proposals[proposal].proposalBatch;
            winningProposalOption=proposals[proposal].winningProposalOption;
            winningProposalOptionName=proposals[proposal].proposalOptions[winningProposalOption].name;
        }
        else{
            if (now <= proposals[proposal].votingStart + proposals[proposal].votingTime){
                revert(); // voting did not yet end
            }

            uint winningVoteCount = 0;
            uint numProposalOptions=proposals[proposal].numOptions;
            
            for (uint i = 0; i < numProposalOptions; i++) {
                if (proposals[proposal].proposalOptions[i].voteCount > winningVoteCount) {
                    winningVoteCount = proposals[proposal].proposalOptions[i].voteCount;
                    winningProposalOption = i;
                    //winningProposalOptionName=proposals[proposal].proposalOptions[i].name;
                }
            }
            proposalName = proposals[proposal].name;
            winningProposalOptionName=proposals[proposal].proposalOptions[winningProposalOption].name;
        }
    }
    

    function getProposalDetailsForVoter(uint proposal, address user) public view
            returns (string proposalName, uint numOptions, bytes32[] optionNames )
    {       
        if (now <= proposals[proposal].votingStart + proposals[proposal].votingTime){// voting did not yet end            
            for (uint i=1; i<=numVoters;i++){
                if (voters[i].addr==user){
                    Voter storage sender = voters[i];
                    }
            }
            //result=sender.votes[proposal].voted;
            if(sender.votes[proposal].voted==false){ //user hasn't voted for this proposal
                proposalName = proposals[proposal].name;     
                numOptions = proposals[proposal].numOptions;
                optionNames=new bytes32[](numOptions);
                for (i = 0; i < proposals[proposal].numOptions; i++) {
                    optionNames[i]=proposals[proposal].proposalOptions[i].name;
                }
            }
        }
    }

    function getProposalOptionName(uint proposal, uint proposalOptionNum) public view
            returns (bytes32 proposalOptionName)
    {               
        proposalOptionName = proposals[proposal].proposalOptions[proposalOptionNum].name;        
    }


}

