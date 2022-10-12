const FixedERC20PaymentProvider = artifacts.require("FixedERC20PaymentProvider");

module.exports = function(deployer) {
  deployer.deploy(FixedERC20PaymentProvider);
};
