//SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import "../../lib/ERC20/IERC20.sol";
import "./IERC20PaymentProvider.sol";

contract FixedERC20PaymentProvider is IERC20PaymentProvider {
    IERC20 private immutable paymentToken;
    uint256 private immutable pricePerSecond; 

    constructor(
            IERC20 _paymentToken, 
            uint256 _pricePerSecond) {
        paymentToken = _paymentToken;
        pricePerSecond = _pricePerSecond;
    }

    function getTokenAddress() external view returns (address) {
        return address(paymentToken);
    }

    function getPrice(string calldata, uint256, uint256 duration) public view returns (uint256) {
        //Overflow protection by default (solidity >= 0.8)
        return pricePerSecond * duration;
    }

    /**
     * @dev Collects the payment for a name registration / renewal.
            Reverts if the payment fails!
     * @param name The name being registered or renewed.
     * @param expires When the name presently expires (0 if this is a new registration).
     * @param duration How long the name is being registered or extended for, in seconds.
     */
    function collectPayment(address buyer, string calldata name, uint256 expires, uint256 duration) external {
        paymentToken.transferFrom(buyer, address(this), getPrice(name, expires, duration));
    }
}
