//SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import "../../lib/ERC20/IERC20.sol";
import "./IERC20PaymentProvider.sol";

contract FixedERC20PaymentProvider is IERC20PaymentProvider {
    IERC20 _paymentToken private immutable;
    uint256 _pricePerSecond private immutable; 

    constructor(IERC20 paymentToken, uint256 pricePerSecond) {
        _paymentToken = paymentToken;
        _pricePerSecond = pricePerSecond;
    }

    function getTokenAddress() external returns (address) {
        return _paymentToken;
    }

    function getPrice(uint256 name, uint256 expires, uint256 duration) public returns (uint256) {
        return pricePerSecond * duration;
    }

    /**
     * @dev Collects the payment for a name registration / renewal.
            Reverts if the payment fails!
     * @param name The name being registered or renewed.
     * @param expires When the name presently expires (0 if this is a new registration).
     * @param duration How long the name is being registered or extended for, in seconds.
     */
    function collectPayment(address buyer, uint256 name, uint256 expires, uint256 duration) external {
        _paymentToken.transferFrom(buyer, address(this), getPrice(name, expires, duration));
    }
}
