// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts@4.5.0/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.5.0/access/Ownable.sol";

contract RyptoX is ERC20, Ownable {

    uint256 private tokenPrice;

    mapping(address => uint256) private purchaseBalance;

    /* temporary Order Liquidity Pool */
    mapping(address => uint256) private purchaseRequests;
    mapping(address => uint256) private withdrawalRequests;


    constructor() ERC20("Rypto -X", "RYPX") {
        _mint(msg.sender, 0);
    }

    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }

    function setTokenPrice(uint256 newPrice) external onlyOwner {
        tokenPrice = newPrice;
    }

    function burn(uint256 amount) external onlyOwner {
        _burn(msg.sender, amount);
    }

    /* 
        There are no purchase limits, as long as the requested 
        amount is greater than 0. 
        While exchanges often have minimum limits, 
        Rypto ensures that the operation is always guaranteed. 
    */
    function requestPurchase() external payable {
        require(msg.value > 0, "Value must be greater than 0");

        address payable contractAddress = payable(address(this));
        contractAddress.transfer(msg.value);

        /* Temporary */
        purchaseRequests[msg.sender] += msg.value;
    }

    function requestWithdrawal(uint256 amount) external onlyOwner {
        withdrawalRequests[msg.sender] = amount;
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
