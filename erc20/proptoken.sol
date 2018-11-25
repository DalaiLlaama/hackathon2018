pragma solidity ^0.5.0;

/**
 * Math operations with safety checks that throw on error
 */
contract SafeMath {

	function safeMul(uint256 a, uint256 b) public pure returns (uint256) {
		uint256 c = a * b;
		assert(a == 0 || c / a == b);
		return c;
	}

	function safeDiv(uint256 a, uint256 b) public pure returns (uint256) {
		//assert(a > 0);// Solidity automatically throws when dividing by 0
		//assert(b > 0);// Solidity automatically throws when dividing by 0
		// uint256 c = a / b;
		// assert(a == b * c + a % b); // There is no case in which this doesn't hold
		return  a / b;
	}

	function safeSub(uint256 a, uint256 b) public pure returns (uint256) {
		assert(b <= a);
		return a - b;
	}

	function safeAdd(uint256 a, uint256 b) public pure returns (uint256) {
		uint256 c = a + b;
		assert(c>=a && c>=b);
		return c;
	}

}


/*
 * ERC20 interface
 * see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 {

	function totalSupply() public view returns (uint256);
	function balanceOf(address _owner) public view returns (uint256);
	function transfer(address _to, uint256 _value) public returns (bool success);
	function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);
	function approve(address payable _spender, uint256 _value) public returns (bool success);
	function allowance(address _owner, address _spender) public view returns (uint256);

	/* ERC20 Events */
	event Transfer(address indexed _from, address indexed _to, uint256 _value);
	event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

contract ContractReceiver {
	function tokenFallback(address _from, uint256 _value, bytes memory _data) public;
}

contract ERC223 is ERC20 {

	function transfer(address _to, uint256 _value, bytes memory _data) public returns (bool success);
	function transfer(address _to, uint256 _value, bytes memory _data, string memory _custom_fallback) public returns (bool success);

	/* ERC223 Events */
	event Transfer(address indexed _from, address indexed _to, uint256 _value, bytes _data);
}

contract PropToken is ERC223, SafeMath {

	string public  name = "Prop Token";     // Set the name for display purposes
	string public  symbol = "BRX";      // Set the symbol for display purposes
	uint8 public constant decimals = 18;         // Amount of decimals for display purposes
	uint256 private issued = 0;   				// tokens count issued to addresses
	uint256 private totalTokens = 1000000; 
	uint64 public propNumber = 0;
	uint256 public addressHash = 0;
	bool public sold = false;

	address payable private contractOwner;
	address private rewardManager;
	address private roundManager;
	address private issueManager;
	uint64 public currentRound = 0;

	bool public paused = false;

	mapping (address => AddressBalanceInfoStructure) public accountBalances;	//key - address, value - address balance info
	mapping (uint64 => uint256) public issuedTokensInRound;	//key - round, value - issued tokens
	mapping (address => mapping (address => uint256)) internal allowed;


	struct AddressBalanceInfoStructure {
		uint256 addressBalance;
	}

	/* Initializes contract with initial blocks per round number*/
	constructor(string memory _tokenName, string memory _tokenSymbol, uint256 _propAddressHash, uint64 _numberOfTokens) public {
		contractOwner = msg.sender;

        name = _tokenName;
        symbol = _tokenSymbol;
	}

	function() external  whenNotPaused payable {
	}

	// Public functions
	/**
	 * @dev Reject all ERC223 compatible tokens
	 * @param _from address The address that is transferring the tokens
	 * @param _value uint256 the amount of the specified token
	 * @param _data Bytes The data passed from the caller.
	 */
	function tokenFallback(address _from, uint256 _value, bytes memory _data) public whenNotPaused view {
		revert();
	}


	/* Change contract owner */
	function changeContractOwner(address payable _newContractOwner) public onlyContractOwner {
		if (_newContractOwner != contractOwner) {
			contractOwner = _newContractOwner;
		} else {
			revert();
		}
	}

	/**
   * @dev called by the owner to pause, triggers stopped state
   */
	function pause() onlyContractOwner whenNotPaused public {
		paused = true;
	}

	/**
	 * @dev called by the owner to resume, returns to normal state
	 */
	function resume() onlyContractOwner whenPaused public {
		paused = false;
	}
	
	function sell(uint256 _value) onlyContractOwner whenNotPaused public {
	    require (address(this).balance >= _value);
	    sold = true;
	}
	
	/**
	 *
	 * permission checker
	 */
	modifier onlyContractOwner() {
		if(msg.sender != contractOwner){
			revert();
		}
		_;
	}

	modifier notSelf(address _to) {
		if(msg.sender == _to){
			revert();
		}
		_;
	}
	/**
   	* @dev Modifier to make a function callable only when the contract is not paused.
   	*/
	modifier whenNotPaused() {
		require(!paused);
		_;
	}

	/**
	 * @dev Modifier to make a function callable only when the contract is paused.
	 */
	modifier whenPaused() {
		require(paused);
		_;
	}

	function subFromAddressBalancesInfo(address _adr, uint256 _tokenAmount) private {
		AddressBalanceInfoStructure storage accountBalance = accountBalances[_adr];
		accountBalance.addressBalance = safeSub(accountBalance.addressBalance, _tokenAmount);
	}

	function addToAddressBalancesInfo(address _receiver, uint256 _tokenAmount) private {
		AddressBalanceInfoStructure storage accountBalance = accountBalances[_receiver];
		accountBalance.addressBalance = safeAdd(accountBalance.addressBalance, _tokenAmount);
	}
	
	//action for issue tokens
	//function issueTokens(address _receiver, uint256 _tokenAmount) public whenNotPaused onlyIssueManager {
	//	isNewRound();
	//	issue(_receiver, _tokenAmount);
	//}

	function withdrawEther() public onlyContractOwner {
		if(address(this).balance > 0) {
			contractOwner.transfer(safeAdd(address(this).balance,0));
		} else {
			revert();
		}
	}

	/* Send coins from owner to other address */
	/*Override*/
	function transfer(address _to, uint256 _value) public notSelf(_to) whenNotPaused returns (bool success){
		require(_to != address(0));
		//added due to backwards compatibility reasons
		bytes memory empty;
		if(isContract(_to)) {
			return transferToContract(msg.sender, _to, _value, empty);
		}
		else {
			return transferToAddress(msg.sender, _to, _value, empty);
		}
	}

	/*Override*/
	function balanceOf(address _owner) public view returns (uint256 balance) {
		return accountBalances[_owner].addressBalance;
	}

	/*Override*/
	function totalSupply() public view returns (uint256){
		return totalTokens;
	}

	/**
	 * @dev Transfer tokens from one address to another
	 * @param _from address The address which you want to send tokens from
	 * @param _to address The address which you want to transfer to
	 * @param _value uint256 the amount of tokens to be transferred
	 */
	/*Override*/
	function transferFrom(address _from, address _to, uint256 _value) public whenNotPaused returns (bool) {
		require(_to != address(0));
		require(_value <= allowed[_from][msg.sender]);

		//added due to backwards compatibility reasons
		bytes memory empty;
		if(isContract(_to)) {
			require(transferToContract(_from, _to, _value, empty));
		}
		else {
			require(transferToAddress(_from, _to, _value, empty));
		}
		allowed[_from][msg.sender] = safeSub(allowed[_from][msg.sender], _value);
		return true;
	}

	/**
	 * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
	 *
	 * Beware that changing an allowance with this method brings the risk that someone may use both the old
	 * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
	 * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
	 * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
	 * @param _spender The address which will spend the funds.
	 * @param _value The amount of tokens to be spent.
	 */
	/*Override*/
	function approve(address payable _spender, uint256 _value) public whenNotPaused returns (bool) {
		allowed[msg.sender][_spender] = _value;
		emit Approval(msg.sender, _spender, _value);
		return true;
	}

	/**
	  * @dev Function to check the amount of tokens that an owner allowed to a spender.
	  * @param _owner address The address which owns the funds.
	  * @param _spender address The address which will spend the funds.
	  * @return A uint256 specifying the amount of tokens still available for the spender.
	  */
	/*Override*/
	function allowance(address _owner, address _spender) public view whenNotPaused returns (uint256) {
		return allowed[_owner][_spender];
	}

	/**
	 * @dev Increase the amount of tokens that an owner allowed to a spender.
	 *
	 * approve should be called when allowed[_spender] == 0. To increment
	 * allowed value is better to use this function to avoid 2 calls (and wait until
	 * the first transaction is mined)
	 * From MonolithDAO Token.sol
	 * @param _spender The address which will spend the funds.
	 * @param _addedValue The amount of tokens to increase the allowance by.
	 */

	function increaseApproval(address _spender, uint256 _addedValue) public returns (bool) {
		allowed[msg.sender][_spender] = safeAdd(allowed[msg.sender][_spender], _addedValue);
		emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
		return true;
	}

	/**
	 * @dev Decrease the amount of tokens that an owner allowed to a spender.
	 *
	 * approve should be called when allowed[_spender] == 0. To decrement
	 * allowed value is better to use this function to avoid 2 calls (and wait until
	 * the first transaction is mined)
	 * From MonolithDAO Token.sol
	 * @param _spender The address which will spend the funds.
	 * @param _subtractedValue The amount of tokens to decrease the allowance by.
	 */
	function decreaseApproval(address _spender, uint256 _subtractedValue) public returns (bool) {
		uint256 oldValue = allowed[msg.sender][_spender];
		if (_subtractedValue > oldValue) {
			allowed[msg.sender][_spender] = 0;
		} else {
			allowed[msg.sender][_spender] = safeSub(oldValue, _subtractedValue);
		}
		emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
		return true;
	}

	// Function that is called when a user or another contract wants to transfer funds .
	/*Override*/
	function transfer(address _to, uint256 _value, bytes memory _data) public whenNotPaused notSelf(_to) returns (bool success){
		require(_to != address(0));
		if(isContract(_to)) {
			return transferToContract(msg.sender, _to, _value, _data);
		}
		else {
			return transferToAddress(msg.sender, _to, _value, _data);
		}
	}

	// Function that is called when a user or another contract wants to transfer funds.
	/*Override*/
	function transfer(address _to, uint256 _value, bytes memory _data, string memory _custom_fallback) public whenNotPaused notSelf(_to) returns (bool success){
		require(_to != address(0));
		if(isContract(_to)) {
			if(accountBalances[msg.sender].addressBalance < _value){		// Check if the sender has enough
				revert();
			}
			if(safeAdd(accountBalances[_to].addressBalance, _value) < accountBalances[_to].addressBalance){		// Check for overflows
				revert();
			}

			subFromAddressBalancesInfo(msg.sender, _value);	// Subtract from the sender
			addToAddressBalancesInfo(_to, _value);	// Add the same to the recipient

			//assert(_to.call.value(0)(bytes4(keccak256(_custom_fallback)), msg.sender, _value, _data));

			/* Notify anyone listening that this transfer took place */
			emit Transfer(msg.sender, _to, _value, _data);
			emit Transfer(msg.sender, _to, _value);
			return true;
		}
		else {
			return transferToAddress(msg.sender, _to, _value, _data);
		}
	}

	// Private functions
	//assemble the given address bytecode. If bytecode exists then the _address is a contract.
	function isContract(address _address) private view returns (bool is_contract) {
		uint256 length;
		assembly {
		//retrieve the size of the code on target address, this needs assembly
			length := extcodesize(_address)
		}
		return (length > 0);
	}

	function issue(address _receiver, uint256 _tokenAmount) private {
		if(_tokenAmount == 0){
			revert();
		}
		uint256 newIssuedAmount = safeAdd(_tokenAmount, issued);
		if(newIssuedAmount > totalTokens){
			revert();
		}
		addToAddressBalancesInfo(_receiver, _tokenAmount);
		issued = newIssuedAmount;
		bytes memory empty;
		if(isContract(_receiver)) {
			ContractReceiver receiverContract = ContractReceiver(_receiver);
			receiverContract.tokenFallback(msg.sender, _tokenAmount, empty);
		}
		/* Notify anyone listening that this transfer took place */
		emit Transfer(msg.sender, _receiver, _tokenAmount, empty);
		emit Transfer(msg.sender, _receiver, _tokenAmount);
	}

	//function that is called when transaction target is an address
	function transferToAddress(address _from, address _to, uint256 _value, bytes memory _data) private returns (bool success) {
		if(accountBalances[_from].addressBalance < _value){		// Check if the sender has enough
			revert();
		}
		if(safeAdd(accountBalances[_to].addressBalance, _value) < accountBalances[_to].addressBalance){		// Check for overflows
			revert();
		}

		subFromAddressBalancesInfo(_from, _value);	// Subtract from the sender
		addToAddressBalancesInfo(_to, _value);	// Add the same to the recipient

		/* Notify anyone listening that this transfer took place */
		emit Transfer(_from, _to, _value, _data);
		emit Transfer(_from, _to, _value);
		return true;
	}

	//function that is called when transaction target is a contract
	function transferToContract(address _from, address _to, uint256 _value, bytes memory _data) private returns (bool success) {
		if(accountBalances[_from].addressBalance < _value){		// Check if the sender has enough
			revert();
		}
		if(safeAdd(accountBalances[_to].addressBalance, _value) < accountBalances[_to].addressBalance){		// Check for overflows
			revert();
		}

		subFromAddressBalancesInfo(_from, _value);	// Subtract from the sender
		addToAddressBalancesInfo(_to, _value);	// Add the same to the recipient

		ContractReceiver receiver = ContractReceiver(_to);
		receiver.tokenFallback(_from, _value, _data);

		/* Notify anyone listening that this transfer took place */
		emit Transfer(_from, _to, _value, _data);
		emit Transfer(_from, _to, _value);
		return true;
	}
}