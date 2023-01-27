import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

describe("QRNFT Contract", function () {
  const fixture = async () => {
    const [owner, addr1, addr2] = await ethers.getSigners();

    const ERC721 = await ethers.getContractFactory("ERC721MOCK");
    const erc721 = await ERC721.deploy();
    await erc721.deployed();

    const ERC1155 = await ethers.getContractFactory("ERC1155MOCK");
    const erc1155 = await ERC1155.deploy();
    await erc1155.deployed();

    await erc1155.mint(owner.address, 0, 1);

    await erc721.mint(owner.address, 0);
    await erc721.mint(owner.address, 1);
    await erc721.mint(owner.address, 2);

    const Dropper721 = await ethers.getContractFactory("QRNFT");
    const dropper721 = await Dropper721.deploy(
      owner.address,
      owner.address,
      owner.address
    );
    await dropper721.deployed();

    return { erc721, erc1155, dropper721, owner, addr1, addr2 };
  };

  it("Should allow us to transfer NFTs to the contract.", async () => {
    const { erc721, dropper721, owner } = await loadFixture(fixture);
    await erc721
      .connect(owner)
      ["safeTransferFrom(address,address,uint256)"](
        owner.address,
        dropper721.address,
        0
      );
    await erc721
      .connect(owner)
      ["safeTransferFrom(address,address,uint256)"](
        owner.address,
        dropper721.address,
        1
      );

    expect(await erc721.ownerOf(0)).to.equal(dropper721.address);
  });

  it("Should allow the signer to claim a token from the contract", async () => {
    const { erc721, dropper721, owner, addr1 } = await loadFixture(fixture);

    // sign an ECDSA ethereum message 'hello world'.  Make sure the message is the right length
    const message = ethers.utils.toUtf8Bytes("hello world");
    const messageHash = ethers.utils.keccak256(message);
    const signature = await owner.signMessage(
      ethers.utils.arrayify(messageHash)
    );

    await erc721
      .connect(owner)
      ["safeTransferFrom(address,address,uint256)"](
        owner.address,
        dropper721.address,
        0
      );
    await erc721
      .connect(owner)
      ["safeTransferFrom(address,address,uint256)"](
        owner.address,
        dropper721.address,
        1
      );

    await dropper721.connect(addr1).claim(0, messageHash, signature);
    expect(await erc721.ownerOf(0)).to.equal(addr1.address);
  });

  it("Should not allow someone to claim the same token twice.", async () => {
    const { erc721, dropper721, owner, addr1 } = await loadFixture(fixture);

    // sign an ECDSA ethereum message 'hello world'.  Make sure the message is the right length
    const message = ethers.utils.toUtf8Bytes("hello world");
    const messageHash = ethers.utils.keccak256(message);
    const signature = await owner.signMessage(
      ethers.utils.arrayify(messageHash)
    );

    await erc721
      .connect(owner)
      ["safeTransferFrom(address,address,uint256)"](
        owner.address,
        dropper721.address,
        0
      );
    await erc721
      .connect(owner)
      ["safeTransferFrom(address,address,uint256)"](
        owner.address,
        dropper721.address,
        1
      );

    await dropper721.connect(addr1).claim(0, messageHash, signature);
    await expect(
      dropper721.connect(addr1).claim(0, messageHash, signature)
    ).to.be.revertedWith("QRNFT: Already claimed");
  });

  it("Should be able to return all NFTs held in the contract to their proper owner.", async () => {
    const { erc721, dropper721, owner } = await loadFixture(fixture);

    await erc721.mint(owner.address, 4);
    await erc721.mint(owner.address, 5);
    await erc721.mint(owner.address, 6);

    await erc721
      .connect(owner)
      ["safeTransferFrom(address,address,uint256)"](
        owner.address,
        dropper721.address,
        4
      );
    await erc721
      .connect(owner)
      ["safeTransferFrom(address,address,uint256)"](
        owner.address,
        dropper721.address,
        5
      );
    await dropper721.connect(owner).returnMyNfts();
    expect(await erc721.ownerOf(4)).to.equal(owner.address);
  });
});
