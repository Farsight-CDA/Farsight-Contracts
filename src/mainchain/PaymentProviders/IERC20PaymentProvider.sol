//SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import "../../lib/ERC20/IERC20.sol";
import "./IPaymentProvider.sol";

interface IERC20PaymentProvider is IPaymentProvider {
    function getTokenAddress() external view returns (address);

    function getPrice(uint256 name, uint256 expires, uint256 duration) external view returns (uint256);

    /**
     * @dev Collects the payment for a name registration / renewal.
            Reverts if the payment fails!
     * @param name The name being registered or renewed.
     * @param expires When the name presently expires (0 if this is a new registration).
     * @param duration How long the name is being registered or extended for, in seconds.
     */
    function collectPayment(
        address buyer,
        uint256 name,
        uint256 expires,
        uint256 duration
    ) external;
}
