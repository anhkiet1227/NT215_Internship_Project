const Shared = artifacts.require("./Shared.sol");
const HospA = artifacts.require("./HospitalA.sol");
const HospB = artifacts.require("./HospitalB.sol");

module.exports = function(deployer, network, accounts) {
  deployer.deploy(Shared, {from: accounts[0]});
  deployer.link(Shared, [HospA, HospB]);

  deployer.deploy(HospA, {from: accounts[0]});
  deployer.deploy(HospB, {from: accounts[6]});
};
