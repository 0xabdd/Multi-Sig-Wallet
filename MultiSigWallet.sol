// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract MultiSigWallet{
    event Deposit(address indexed sender, uint amount);
    event Submit(uint indexed txId);
    event Approve(address indexed owner, uint indexed txId);
    event Revoke(address indexed owner, uint indexed txId);
    event Execute(uint indexed txId);

    struct Transaction{
        address to;
        uint value;
        bytes data;
        bool executed;

    }
    modifier onlyOwner(){
        require(isOwner[msg.sender], "not owner" );
        _;
    }
    
    modifier txExists(uint _txIndex) {
        require(_txIndex < transactions.length, "tx does not exist");
        _;
    }

    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }

    modifier notConfirmed(uint _txIndex) {
        require(!approved[_txIndex][msg.sender], "tx already confirmed");
        _;
    }




    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public required; 

    Transaction[] public transactions;
    mapping(uint => mapping(address => bool)) public approved;

    constructor(address[] memory _owners, uint _required){

        
        require(_owners.length > 0, "owners required");
        require(required >0 && required < _owners.length, "invalid number of owners");
        for(uint i; i < _owners.length; i ++){
            address owner = _owners[i];
            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner is not uniqe");
            isOwner[owner] = true;
            owners.push(owner);            
        }
        required = _required; 
    }

    receive() external payable { 
        emit Deposit(msg.sender, msg.value);
    }

    function submit(
        address _to,
        uint _value,
        bytes memory _data
    ) public onlyOwner{
        transactions.push(
            Transaction({ 
                to: _to,
                value: _value,
                data: _data,
                executed: false
            })
        );
        emit Submit(transactions.length -1); 

    }

    function approve(uint _txId) public
    onlyOwner
    txExists(_txId) 
    notExecuted(_txId) 
    notConfirmed(_txId) 
    {
     approved[_txId][msg.sender] = true;
     emit Approve(msg.sender, _txId);   

    }

    function _getApprovalCount(uint _txId) private returns(uint count){
        for(uint i; i < owners.length; i ++){ 
            if (approved[_txId][owners[i]]){
                count +1;
            }
        }
    }

    function execute(uint _txId) public 
    onlyOwner
    txExists(_txId)
    notExecuted(_txId) {
        Transaction storage transaction = transactions[_txId];

        require(
            _getApprovalCount(_txId) >= required,
            "cannot execute tx"
        );

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "tx failed");

        emit Execute(_txId);
    }

    function revoke(uint _txId) public 
    onlyOwner
    txExists(_txId)
    notExecuted(_txId){
        require (approved[_txId][msg.sender], "tx is not confirmed");
        approved[_txId][msg.sender] = false;
        emit Revoke(msg.sender, _txId);

    }


}   

    