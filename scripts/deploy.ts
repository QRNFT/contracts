import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const Token = await ethers.getContractFactory("QRNFT");
  const token = await Token.deploy(
    "0x0f78BF8aBc5F4B23EF93996540F6A452244FF940",
    "0x0f78BF8aBc5F4B23EF93996540F6A452244FF940",
    "0x69015912AA33720b842dCD6aC059Ed623F28d9f7"
  );

  await token.deployed();

  console.log("Token address:", token.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
