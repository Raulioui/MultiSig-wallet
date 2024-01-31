// SPDX-License-Identifier:MIT

pragma solidity 0.8.20;

contract MultiSignWallet {

    /*
     *  Events
    */

    event TransactionSubmited(uint transactionId, address sender, address receiver, uint amount);
    event TransactionApproved(uint transactionId);
    event TransactionExecuted(uint transactionId);
    event Deposit(address indexed sender, uint amount, uint balance);

    /*
     *  Constants
    */

    uint constant public MAX_OWNER_COUNT = 5;

    /*
     *  Storage
    */

    address[] public owners;
    uint public confirmationsRequired;
    Transaction[] public transactions;

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
    }

    mapping(uint => mapping(address => bool)) public isApproved;
    mapping(address => bool) public isOwner;

    /*
     *  Modifiers
    */

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not owner");
        _;
    }

    modifier txExist(uint _txId) {
        require(_txId < transactions.length, "Invalid transaction");
        _;
    }

    modifier txNotApprovedByOwner(uint _txId) {
        require(!isApproved[_txId][msg.sender], "Already approved");
        _;
    }

    modifier txNotExecuted(uint _txId) {
        require(!transactions[_txId].executed, "Transaction already executed");
        _;
    }

    constructor(address[] memory _owners, uint _confirmationsRequired) {
        require(_owners.length > 1 && _owners.length <= MAX_OWNER_COUNT, "Invalid number of owners");
        require(_confirmationsRequired > 0 && _confirmationsRequired <= _owners.length, "Invalid number of confirmations");

        for(uint i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "Invalid address provided");
            require(!isOwner[_owners[i]], "Duplicate owner");
            owners.push(_owners[i]);
            isOwner[_owners[i]] = true;
        }

        confirmationsRequired = _confirmationsRequired;
    }

    /**
     * @notice Sends the transaction.
     * @param _to: transaction receiver.
     * @param _data: payload.
    */
    // @audit - Check the id process, it can be riky.
    function submitTransaction(address _to, bytes memory _data) external  payable onlyOwner {
        require(_to != address(0), "Invalid address provided");
        require(msg.value > 0, "Invalid amount provided");

        transactions.push(Transaction(_to, msg.value, _data, false));
        emit TransactionSubmited(transactions.length - 1, msg.sender, _to, msg.value);
    }



    /**
     * @notice An owner confirm a transaction.
     * @dev Check if the transactions exists, has not been axecuted and the sender has not approved it yet. 
     * @param _txId: id of the transaction.
    */
    function confirmTransaction(uint _txId) 
        external 
        onlyOwner
        txExist(_txId) 
        txNotApprovedByOwner(_txId)
        txNotExecuted(_txId)
    {
        isApproved[_txId][msg.sender] = true;
        
        emit TransactionApproved(_txId);

        if(isTransictionApproved(_txId)) {
            executeTransaction(_txId);
        }
    }

    /**
     * @notice Final execution of a transaction.
     * @param _txId: id of the transaction.
    */
    function executeTransaction(uint _txId) internal { 
        Transaction storage tx = transactions[_txId];
        tx.executed = true;

        (bool success, ) = tx.to.call{value: tx.value}(tx.data);
        require(success, "Transaction failed");

        emit TransactionExecuted(_txId);
    }

    /**
     * @notice Checks if a transaction is Approved.
     * @param _txId: id of the transaction.
     */
    function isTransictionApproved(uint _txId) internal view returns(bool) {
        uint confirmationCount;

        for(uint i; i < owners.length; i++) {
            if(isApproved[_txId][owners[i]]) {
                confirmationCount++;
            }
        }

        return confirmationCount >= confirmationsRequired;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

}