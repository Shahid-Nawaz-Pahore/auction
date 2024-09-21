const hre = require("hardhat");
const {ethers} = require("hardhat");

async function main() {

  const MultiAuction = await ethers.getContractFactory("MultiAuction");
  const multiAuction = await MultiAuction.deploy();
  await multiAuction.deployed();

  console.log("MultiAuction contract deployed address is: ", multiAuction.address);

}

main()
.then(() => process.exit(0))
.catch((err) => {
  console.log("MultiAuction contract deployed error: ", err);
  process.exit(1);
})