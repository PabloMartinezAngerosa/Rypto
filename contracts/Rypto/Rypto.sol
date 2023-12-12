// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts@4.5.0/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.5.0/access/Ownable.sol";

// TODO: Consider implementing a more secure fund management mechanism.
// Currently, funds are transferred directly to the owner, which may have security implications.


contract RyptoX is ERC20, Ownable {

    struct PurchaseRequest {
        address buyer;
        uint256 amount;
    }

    struct WithdrawalRequest {
        address owner;
        uint256 amount;
    }

    // Modifier to ensure that the operational window is open
    modifier operationalWindowIsOpen() {
        require(operationalWindow, "Operational window is currently closed");
        _;
    }

    uint256 private tokenPrice;

    mapping(address => uint256) private purchaseRequests;
    mapping(address => uint256) private withdrawalRequests;
    address[] private purchaseRequesters;
    address[] private withdrawalRequesters;

    bool internal operationalWindow = true;


    event ContractFunded(address indexed funder, uint256 amount, uint256 indexed timestamp, uint256 indexed blockNumber);
    event TokenPriceUpdated(uint256 indexed newPrice, uint256 indexed timestamp, uint256 indexed blockNumber);
    event PurchaseRequested(address indexed buyer, uint256 amount, uint256 totalAmount, uint256 indexed timestamp, uint256 indexed blockNumber);
    event PurchaseCancelled(address indexed buyer, uint256 amountRefunded, uint256 indexed timestamp, uint256 indexed blockNumber);
    event WithdrawalRequested(address indexed owner, uint256 amountRequested, uint256 totalAmount, uint256 indexed timestamp, uint256 indexed blockNumber);
    event WithdrawalCancelled(address indexed owner, uint256 indexed timestamp, uint256 indexed blockNumber);
    event WithdrawalExecuted(address indexed recipient, uint256 tokenAmountWithdrawn, uint256 amountWithdrawn, uint256 indexed timestamp, uint256 indexed blockNumber);
    event PurchaseExecuted(address indexed buyer, uint256 amountSpent, uint256 tokenAmount, uint256 change, uint256 indexed timestamp, uint256 indexed blockNumber);
    event OperationalWindowToggled(bool newStatus, uint256 indexed timestamp, uint256 indexed blockNumber);

    
    /**
    * @dev ERC20 contract constructor for Rypto-X.
    * Initializes the contract with an initial allocation of 1 Rypto-X to the contract creator (msg.sender)
    * and sets the initial token price to 1 ether, marking the beginning of the 1-to-1 exchange ratio.
    */
    constructor() ERC20("Rypto -X", "RYPX") {
        _mint(msg.sender, 0);
        tokenPrice = 1 ether;
    }

    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }

    function setTokenPrice(uint256 newPrice) external onlyOwner {
        tokenPrice = newPrice;
        emit TokenPriceUpdated(newPrice, block.timestamp, block.number);
    }

    function getTokenPrice() external view returns (uint256) {
        return tokenPrice;
    }

    function burn(uint256 amount) external onlyOwner {
        _burn(msg.sender, amount);
    }

    // Function to open or close the operational window, only callable by the owner
    function toggleOperationalWindow(bool _open) external onlyOwner {
        operationalWindow = _open;
        emit OperationalWindowToggled(_open, block.timestamp, block.number);
    }

    // Función para obtener el estado actual de operationalWindow
    function getOperationalWindowStatus() public view returns (bool) {
        return operationalWindow;
    }

    /*
        Purchase limits are not enforced, as long as the requested
        amount is greater than 0. Unlike traditional exchanges that may 
        impose minimum limits, Rypto prioritizes guaranteeing the 
        operation by allowing flexibility in transaction amounts.
    */
    function requestPurchase() external payable operationalWindowIsOpen {
        require(msg.value > 0, "Value must be greater than 0");
        
        purchaseRequests[msg.sender] += msg.value;

        // Add the requester to the list if not already present
        
        if (!isPurchaseRequester(msg.sender)) {
            purchaseRequesters.push(msg.sender);
        }
        

        emit PurchaseRequested(msg.sender, msg.value, purchaseRequests[msg.sender], block.timestamp, block.number);
    }

    // Function to cancel a purchase and refund the buyer
    function cancelPurchase() external {
        uint256 purchaseAmount = purchaseRequests[msg.sender];
        require(purchaseAmount > 0, "No purchase found for the caller");

        // Refund the buyer
        address payable buyer = payable(msg.sender);
        (bool success, ) = buyer.call{value: purchaseAmount}("");
        require(success, "Transfer to buyer failed");

        // Update the purchase request to 0
        purchaseRequests[msg.sender] = 0;

        removePurchaseRequester(msg.sender);

        emit PurchaseCancelled(msg.sender, purchaseAmount, block.timestamp, block.number);
    }

    function executePurchase(address buyer) external onlyOwner {
        uint256 purchaseAmount = purchaseRequests[buyer];

        require(purchaseAmount > 0, "No pending purchase");

        uint256 amount_wei_rypto_token = purchaseAmount * 1 ether / tokenPrice;
        console.log("Token Amount to mint :", amount_wei_rypto_token);
        

        uint256 change = purchaseAmount - (amount_wei_rypto_token * tokenPrice / 1 ether);

        if (change > 0) {
            address payable buyerAddress = payable(buyer);
            (bool success, ) = buyerAddress.call{value: change}("");
            require(success, "Transfer change to buyer failed");
            console.log("Change :", change);
        }
        // mint in wei
        _mint(buyer, amount_wei_rypto_token);

        purchaseRequests[buyer] = 0;
        removePurchaseRequester(buyer);

        emit PurchaseExecuted(buyer, purchaseAmount, amount_wei_rypto_token, change, block.timestamp, block.number);
    }

    // Function to get the mapping of purchase requesters

    function getPurchaseRequesters() external view returns (PurchaseRequest[] memory) {

        PurchaseRequest[] memory purchaseRequestDetails = new PurchaseRequest[](purchaseRequesters.length);

        for (uint256 i = 0; i < purchaseRequesters.length; i++) {
            address buyer = purchaseRequesters[i];
            uint256 amount = purchaseRequests[buyer];

            PurchaseRequest memory requestDetail = PurchaseRequest(buyer, amount);
            purchaseRequestDetails[i] = requestDetail;
        }

        return purchaseRequestDetails;
    }

    function isPurchaseRequester(address requester) internal view returns (bool) {
        for (uint256 i = 0; i < purchaseRequesters.length; i++) {
            if (purchaseRequesters[i] == requester) {
                return true;
            }
        }
        return false;
    }

    // Function to remove an address from the list of purchase requesters
    function removePurchaseRequester(address requester) internal {
        for (uint256 i = 0; i < purchaseRequesters.length; i++) {
            if (purchaseRequesters[i] == requester) {
                // Swap with the last element and pop
                purchaseRequesters[i] = purchaseRequesters[purchaseRequesters.length - 1];
                purchaseRequesters.pop();
                break;
            }
        }
    }

    function requestWithdrawal(uint256 amount) external operationalWindowIsOpen {
        require(balanceOf(msg.sender) >= amount + withdrawalRequests[msg.sender], "Insufficient tokens for withdrawal");
        withdrawalRequests[msg.sender] += amount;

        // Add the requester to the list if not already present
        if (!isWithdrawalRequester(msg.sender)) {
            withdrawalRequesters.push(msg.sender);
        }

        emit WithdrawalRequested(msg.sender, amount, withdrawalRequests[msg.sender], block.timestamp, block.number);
    }

    function cancelWithdrawal() external {
        address ownerAddress = msg.sender;
        withdrawalRequests[ownerAddress] = 0;

        // Remove the requester from the list
        removeWithdrawalRequester(ownerAddress);

        emit WithdrawalCancelled(ownerAddress, block.timestamp, block.number);
    }

    function executeWithdrawal(address recipient) external onlyOwner {

        uint256 tokenAmountToWithdraw = withdrawalRequests[recipient];
        require(tokenAmountToWithdraw > 0, "No funds requested for withdrawal");
        
        uint256 amountToWithdraw = (tokenAmountToWithdraw * tokenPrice ) / 1 ether;
        

        _burn(recipient, tokenAmountToWithdraw);
        withdrawalRequests[recipient] = 0;

        // Perform the actual fund transfer to the owner
        address payable _to = payable(recipient);
        (bool success, ) = _to.call{value: amountToWithdraw}("");
        require(success, "Transfer to recipient failed in Withdrawal");

        // Remove the requester from the list
        removeWithdrawalRequester(recipient);

        emit WithdrawalExecuted(recipient, tokenAmountToWithdraw, amountToWithdraw, block.timestamp, block.number);
    }


    // Function to get the list of withdrawal requesters
    function getWithdrawalRequesters() external view returns (WithdrawalRequest[] memory) {
        //PurchaseRequest[] memory purchaseRequestDetails = new PurchaseRequest[](purchaseRequesters.length);
        WithdrawalRequest[] memory withdrawalRequestDetails = new WithdrawalRequest[](withdrawalRequesters.length);

        for (uint256 i = 0; i < withdrawalRequesters.length; i++) {
            address buyer =  withdrawalRequesters[i];
            uint256 amount = withdrawalRequests[buyer];

            WithdrawalRequest memory requestDetail = WithdrawalRequest(buyer, amount);
            withdrawalRequestDetails[i] = requestDetail;
        }

        return withdrawalRequestDetails;
    }

    // Function to check if an address is in the list of withdrawal requesters
    function isWithdrawalRequester(address requester) internal view returns (bool) {
        for (uint256 i = 0; i < withdrawalRequesters.length; i++) {
            if (withdrawalRequesters[i] == requester) {
                return true;
            }
        }
        return false;
    }

    // Function to remove an address from the list of withdrawal requesters
    function removeWithdrawalRequester(address requester) internal {
        for (uint256 i = 0; i < withdrawalRequesters.length; i++) {
            if (withdrawalRequesters[i] == requester) {
                // Swap with the last element and pop
                withdrawalRequesters[i] = withdrawalRequesters[withdrawalRequesters.length - 1];
                withdrawalRequesters.pop();
                break;
            }
        }
    }

    function fundContract() external payable {
        emit ContractFunded(msg.sender, msg.value, block.timestamp, block.number);
    }

    /**
    * @dev Get the current balance of ether in the contract.
    * @return Current balance of the contract in wei.
    */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

}
