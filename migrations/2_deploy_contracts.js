const Voting = artifacts.require("Voting");
const Owned = artifacts.require("../interfaces/Owned");

module.exports = function(deployer) {
  deployer.deploy(Owned);
  deployer.link(Owned, Voting);
  deployer.deploy(Voting);
};
