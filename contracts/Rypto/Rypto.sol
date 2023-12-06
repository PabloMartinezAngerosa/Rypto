// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts@4.5.0/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.5.0/access/Ownable.sol";

contract RyptoX is ERC20, Ownable {

    // Modifier to ensure that the operational window is open
    modifier operationalWindowIsOpen() {
        require(operationalWindow, "Operational window is currently closed");
        _;
    }

    uint256 private tokenPrice;

    mapping(address => uint256) private purchaseBalance;

    /* temporary Order Liquidity Pool */
    mapping(address => uint256) private purchaseRequests;
    mapping(address => uint256) private withdrawalRequests;

    bool internal operationalWindow = true;    

    
    event TokenPriceUpdated(uint256 indexed newPrice, uint256 indexed timestamp, uint256 indexed blockNumber);
    event PurchaseRequested(address indexed buyer, uint256 amount, uint256 indexed timestamp, uint256 indexed blockNumber);
    event PurchaseCancelled(address indexed buyer, uint256 amountRefunded, uint256 indexed timestamp, uint256 indexed blockNumber);
    event WithdrawalRequested(address indexed owner, uint256 amountRequested, uint256 indexed timestamp, uint256 indexed blockNumber);
    event WithdrawalCancelled(address indexed owner, uint256 indexed timestamp, uint256 indexed blockNumber);





    constructor() ERC20("Rypto -X", "RYPX") {
        _mint(msg.sender, 0);
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
    }

    /*
        Purchase limits are not enforced, as long as the requested
        amount is greater than 0. Unlike traditional exchanges that may 
        impose minimum limits, Rypto prioritizes guaranteeing the 
        operation by allowing flexibility in transaction amounts.
    */
    function requestPurchase() external payable operationalWindowIsOpen {
        require(msg.value > 0, "Value must be greater than 0");

        address payable contractAddress = payable(address(this));
        contractAddress.transfer(msg.value);

        /* Temporary */
        purchaseRequests[msg.sender] += msg.value;
    
        emit PurchaseRequested(msg.sender, msg.value, block.timestamp, block.number);
    }

    // Function to cancel a purchase and refund the buyer
    function cancelPurchase() external {
        uint256 purchaseAmount = purchaseRequests[msg.sender];
        require(purchaseAmount > 0, "No purchase found for the caller");

        // Refund the buyer
        address payable buyer = payable(msg.sender);
        buyer.transfer(purchaseAmount);

        // Update the purchase request to 0
        purchaseRequests[msg.sender] = 0;

        emit PurchaseCancelled(msg.sender, purchaseAmount, block.timestamp, block.number);
    }

    function requestWithdrawal(uint256 amount) external operationalWindowIsOpen {
        withdrawalRequests[msg.sender] = amount;
        emit WithdrawalRequested(msg.sender, amount, block.timestamp, block.number);
    }


    function cancelWithdrawal() external {
        
        address ownerAddress = msg.sender;

        withdrawalRequests[ownerAddress] = 0;
        emit WithdrawalCancelled(ownerAddress, block.timestamp, block.number);
    }


    function executeWithdrawal(address recipient) external onlyOwner {
        uint256 amountToWithdraw = withdrawalRequests[recipient];
        require(amountToWithdraw > 0, "No funds requested for withdrawal");

        _burn(recipient, amountToWithdraw);
        withdrawalRequests[recipient] = 0;
        // Perform the actual fund transfer to the owner
        payable(address(this)).transfer(amountToWithdraw);
    }

    function executePurchase(address buyer) external {
        // Obtener la cantidad solicitada por el usuario
        uint256 purchaseAmount = purchaseRequests[buyer];

        // Verificar que haya una compra pendiente
        require(purchaseAmount > 0, "No pending purchase");

        uint256 tokenAmount = purchaseAmount / tokenPrice;
        _mint(buyer, tokenAmount);

        // Limpiar la solicitud de compra después de ejecutarla
        purchaseRequests[buyer] = 0;

    }

}
