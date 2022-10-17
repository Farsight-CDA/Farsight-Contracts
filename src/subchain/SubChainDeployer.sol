// SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import "./SubRegistrarController.sol";
import "./subRegistrar.sol";
import "../shared/PaymentProviders/FixedERC20PaymentProvider.sol";
import "../lib/ERC20/IERC20.sol";

contract SubChainDeployer {
    IERC20 private paymentToken;
    uint256 private pricePerMinute;

    constructor(IERC20 _paymentToken, uint256 _pricePerMinute) {
        paymentToken = _paymentToken;
        pricePerMinute = _pricePerMinute;
    }

    function deploy(bytes memory _paymentProviderCode, bytes memory _registrarCode) external {

        address paymentProvider;
        address registrar;

        assembly {
            paymentProvider := create(0, add(_paymentProviderCode, 0x20), mload(_paymentProviderCode));
        }


        SubRegistrar SubRegistrar = new SubRegistrar();
    }
}