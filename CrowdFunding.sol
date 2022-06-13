// SPDX-License-Identifier: GPL-3.0;

pragma solidity >=0.6.0 <0.9.0;

contract CrowdFunding {
    mapping(address => uint) public contributors;
    address public admin;
    uint public numOfContributors;
    uint public minimumContribution;
    uint public deadLine; //timestamp
    uint public goal;
    uint public raisedAmount;
    // to spend the fund, admin will request
    // contributors has to vote and if more than 50% then fund can be used.
    struct Request {
        string description;
        address payable recipient;
        uint value;
        bool completed;
        uint numOfVoters;
        mapping(address => bool) voters;
    }

    // store all the requests
    mapping(uint => Request) public requests;
    // map will not have index like arrays, so increment numRequests
    uint public numRequests;

    constructor(uint _goal, uint _deadLine) {
        goal = _goal;
        // block.timestamp is the time the block has created or contract called.
        deadLine = block.timestamp + _deadLine; //second
        minimumContribution = 100;
        admin = msg.sender;
    }

    // Events in solidity are emitted when certain action is occured and can be used as callback
    event ContributeEvent(address _sender, uint _value);
    event CreateRequestEvent(string _description, address recipient, uint value);
    event MakePaymentEvent(address _recipient, uint value);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call it!");
        _;
    }

    // Contribute to crowd funding.
    function contribute() public payable {
        // condition with error message.
        require(block.timestamp < deadLine, "Deadline has passed!");
        require(msg.value > minimumContribution, "minimum contribution not meet!, please contribute more than 100 Wei.");

        // increment the number of contributor for new contribution.
        if(contributors[msg.sender] == 0) {
            numOfContributors++;
        }

        // total contribution from individual.
        contributors[msg.sender] += msg.value;

        // total raised amount
        raisedAmount += msg.value;
        // Emit the event, when contribution is successful.
        emit ContributeEvent(msg.sender, msg.value);
    }

    // To send amount directly to contract address; must have receive payable fucntion
    receive() payable external{
        contribute();
    }

    // get the contract balance
    function getBalance() public view returns(uint) {
        // contract address
        return address(this).balance;
    }

    // get the refund if the goal is not reached within deadline.
    function getRefund() public {
        require(block.timestamp > deadLine && raisedAmount < goal);
        // only contributor can get refund
        require(contributors[msg.sender] > 0);

        address payable recipient = payable(msg.sender);
        uint value = contributors[msg.sender];

        // transfer the value
        recipient.transfer(value);
        // OR
        // payable(msg.sender).transfer(contributors[msg.sender]);

        // to avoid multiple entrance attack, make contribution amount to '0' after refund.
        contributors[msg.sender] = 0 ;
    }

    function createRequest(string memory _description, address payable _recipient, uint _value) public onlyAdmin {
        // store the request in blockchian with index numRequests
        // storage: permanent storage in blockchain.
        Request storage newRequest = requests[numRequests];
        numRequests++;

        newRequest.description = _description;
        newRequest.recipient = _recipient;
        newRequest.value = _value;
        newRequest.completed = false;
        newRequest.numOfVoters = 0;
        // emit the CreateRequestEvent
        emit CreateRequestEvent(_description, _recipient, _value);
    }

    // vote for specific request
    function voteRequest(uint _requestNum) public {
        require(contributors[msg.sender] > 0, "Must be a contributor to vote!");
        // current request to vote
        Request storage thisRequest = requests[_requestNum];
        // To check if the contributor has already voted.
        require(thisRequest.voters[msg.sender] == false, "You already voted!");
        // if not
        thisRequest.voters[msg.sender] = true;
        thisRequest.numOfVoters++;
    }

    function makePayment(uint _requestNum) public onlyAdmin {
        require(raisedAmount >= goal);
        // specific request
        Request storage thisRequest = requests[_requestNum];
        // check if the request is completed
        require(thisRequest.completed == false, "This request is completed!");
        // request must be voted(accpeted) by more than 50% of contributor 
        require(thisRequest.numOfVoters > (numOfContributors/2), "Must be voted by more than 50%." );
        // Transfer the amount to recipient
        thisRequest.recipient.transfer(thisRequest.value);
        thisRequest.completed = true;

        // emit MakePaymentEvent after payment is succesful.
        emit MakePaymentEvent(thisRequest.recipient, thisRequest.value);

    }
}
