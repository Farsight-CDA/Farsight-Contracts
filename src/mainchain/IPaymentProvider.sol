//SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import "../lib/ERC20/IERC20.sol";

interface IPaymentProvider is IERC20 {
    /**
     * @dev Collects the payment for a name registration / renewal
     * @param name The name being registered or renewed.
     * @param expires When the name presently expires (0 if this is a new registration).
     * @param duration How long the name is being registered or extended for, in seconds.
     */
    function collectPayment(
        uint256 name,
        uint256 expires,
        uint256 duration
    ) external;
}
