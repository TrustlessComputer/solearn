import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import { AgentUpgradeable, IAgent } from "../typechain-types";
import { Signer } from "ethers";
const helpers = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("AgentUpgradeable", async function () {
  let utilityAgent: AgentUpgradeable;
  let owner: Signer;
  let addr1: Signer;
  let addr2: Signer;
  let addrs: Signer[];

  // Mock FileStore address
  const mockFileStoreAddress = "0xFe1411d6864592549AdE050215482e4385dFa0FB";

  beforeEach(async function () {
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
    console.log("Owner address:", await owner.getAddress());

    const AgentUpgradeable = await ethers.getContractFactory(
      "AgentUpgradeable"
    );
    utilityAgent = (await upgrades.deployProxy(AgentUpgradeable, [
      "TestAgent",
      "1",
      "javascript",
      [
        {
          retrieveAddress: mockFileStoreAddress,
          fileType: 1,
          fileName: "ethers.text",
        },
        {
          retrieveAddress: mockFileStoreAddress,
          fileType: 0,
          fileName: "devScript.text",
        },
      ],
      [], // Empty deps agents array
      await owner.getAddress(), // Owner address
      true, // isOnchain
    ])) as unknown as AgentUpgradeable;

    await utilityAgent.waitForDeployment();
  });

  it("Should initialize correctly", async function () {
    expect(await utilityAgent.getCurrentVersion()).to.equal(1);
    expect(await utilityAgent.getCodeLanguage()).to.equal("javascript");
  });

  it.skip("Should add new agent configurations", async function () {
    const newPointers: IAgent.CodePointerStruct[] = [
      {
        retrieveAddress: mockFileStoreAddress,
        fileType: 1,
        fileName: "new_ethers.text",
      },
    ];
    const newDepsAgents: string[] = [];
    const isOnchain = true;

    await utilityAgent
      .connect(owner)
      .publishAgentCode(newPointers, newDepsAgents, isOnchain);

    expect(await utilityAgent.getCurrentVersion()).to.equal(2);

    // Verify code pointer was added
    const code = await utilityAgent.getAgentCode(2);
    expect(code).to.include("new_ethers.text");
  });

  it("Should revert on invalid version", async function () {
    // Using getAgentCode with invalid version should revert
    await expect(utilityAgent.getAgentCode(3)).to.be.revertedWithCustomError(
      utilityAgent,
      "InvalidVersion()"
    );
  });

  it("Should get implementation language", async function () {
    expect(await utilityAgent.getCodeLanguage()).to.equal("javascript");
  });

  it("Should get current version", async function () {
    expect(await utilityAgent.getCurrentVersion()).to.equal(1);
  });

  it("Should add new agent configurations using ipfs", async function () {
    const newPointers: IAgent.CodePointerStruct[] = [
      {
        retrieveAddress: ethers.ZeroAddress,
        fileType: 1,
        fileName: "ipfs://abcxyz",
      },
    ];
    const newDepsAgents: string[] = [];
    const isOnchain = false;

    await utilityAgent
      .connect(owner)
      .publishAgentCode(newPointers, newDepsAgents, isOnchain);

    let code = await utilityAgent.getAgentCode(2);
    expect(code).to.include("ipfs://abcxyz");

    // Verify isOnchain was updated
    expect(await utilityAgent.isOnchain(2)).to.equal(isOnchain);
  });

  it("Should add agent with dependency agents", async function () {
    const newPointers: IAgent.CodePointerStruct[] = [
      {
        retrieveAddress: mockFileStoreAddress,
        fileType: 1,
        fileName: "deps_test.text",
      },
    ];

    const depAddress = await addr2.getAddress();
    const newDepsAgents: string[] = [depAddress];
    const isOnchain = true;

    await utilityAgent
      .connect(owner)
      .publishAgentCode(newPointers, newDepsAgents, isOnchain);

    const newVersion = await utilityAgent.getCurrentVersion();

    // Verify deps were stored correctly
    const deps = await utilityAgent.getDepsAgents(newVersion);
    expect(deps.length).to.equal(1);
    expect(deps[0]).to.equal(depAddress);
  });

  it("Should revert when adding agent with zero address dependency", async function () {
    const newPointers: IAgent.CodePointerStruct[] = [
      {
        retrieveAddress: mockFileStoreAddress,
        fileType: 1,
        fileName: "test.text",
      },
    ];

    const newDepsAgents: string[] = [ethers.ZeroAddress];
    const isOnchain = true;

    await expect(
      utilityAgent
        .connect(owner)
        .publishAgentCode(newPointers, newDepsAgents, isOnchain)
    ).to.be.revertedWithCustomError(utilityAgent, "ZeroAddress()");
  });

  it("Should revert when adding agent with empty pointers", async function () {
    const newPointers: IAgent.CodePointerStruct[] = [];
    const newDepsAgents: string[] = [];
    const isOnchain = true;

    await expect(
      utilityAgent
        .connect(owner)
        .publishAgentCode(newPointers, newDepsAgents, isOnchain)
    ).to.be.revertedWithCustomError(utilityAgent, "InvalidData()");
  });

  it("Should revert when non-owner tries to publish agent code", async function () {
    const newPointers: IAgent.CodePointerStruct[] = [
      {
        retrieveAddress: mockFileStoreAddress,
        fileType: 1,
        fileName: "test.text",
      },
    ];
    const newDepsAgents: string[] = [];
    const isOnchain = true;

    await expect(
      utilityAgent
        .connect(addr1) // Using non-owner account
        .publishAgentCode(newPointers, newDepsAgents, isOnchain)
    ).to.be.revertedWithCustomError(utilityAgent, "Unauthenticated()");
  });

  it("Should allow publishing agent code with valid signature", async function () {
    // Define new code pointers and endpoints
    const newPointers: IAgent.CodePointerStruct[] = [
      {
        retrieveAddress: mockFileStoreAddress,
        fileType: 1,
        fileName: "signed_code.text",
      },
    ];
    const newDepsAgents: string[] = [await addr1.getAddress()];
    const isOnchain = true;

    // Get the current version to check the increment later
    const initialVersion = await utilityAgent.getCurrentVersion();

    // Build domain separator for EIP712 signature
    const chainId = await ethers.provider.getNetwork().then((n) => n.chainId);
    const domain = {
      name: "TestAgent", // The name used when initializing the contract
      version: "1",
      chainId: chainId,
      verifyingContract: await utilityAgent.getAddress(),
    };

    // Define types for EIP712 structured data
    const types = {
      SignData: [
        { name: "pointers", type: "CodePointer[]" },
        { name: "depsAgents", type: "address[]" },
        { name: "isOnchain", type: "bool" },
        { name: "currentVersion", type: "uint16" },
      ],
      CodePointer: [
        { name: "retrieveAddress", type: "address" },
        { name: "fileType", type: "uint8" },
        { name: "fileName", type: "string" },
      ],
    };

    // Create the message to be signed
    const message = {
      pointers: newPointers,
      depsAgents: newDepsAgents,
      isOnchain: isOnchain,
      currentVersion: Number(initialVersion),
    };

    console.log("Message to sign:", message);

    // Sign the typed data with owner's private key
    const signature = await owner.signTypedData(domain, types, message);

    // Call the function with the signature from a different account
    await utilityAgent
      .connect(addr1) // Note: Using addr1 instead of owner to prove signature works
      .publishAgentCodeWithSignature(
        newPointers,
        newDepsAgents,
        isOnchain,
        signature
      );

    // Verify the version has been incremented
    const newVersion = await utilityAgent.getCurrentVersion();
    expect(newVersion).to.equal(initialVersion + 1n);

    // Verify the code was saved correctly
    // const code = await utilityAgent.getAgentCode(newVersion);
    // expect(code).to.include("signed_code.text");

    // Verify isOnchain flag was updated
    expect(await utilityAgent.isOnchain(2)).to.equal(isOnchain);

    // Verify deps were added correctly
    const deps = await utilityAgent.getDepsAgents(newVersion);
    expect(deps).to.deep.equal(newDepsAgents);
  });

  it("Should revert when signature is invalid", async function () {
    // Define new code pointers and endpoints
    const newPointers: IAgent.CodePointerStruct[] = [
      {
        retrieveAddress: mockFileStoreAddress,
        fileType: 1,
        fileName: "signed_code.text",
      },
    ];
    const newDepsAgents: string[] = [];
    const isOnchain = true;

    // Generate the hash to sign
    const hashToSign = await utilityAgent.getHashToSign(
      newPointers,
      newDepsAgents,
      isOnchain
    );

    // Sign with an unauthorized account (addr1 instead of owner)
    const invalidSignature = await addr1.signMessage(
      ethers.getBytes(hashToSign)
    );

    // Attempt to call with invalid signature should revert
    await expect(
      utilityAgent
        .connect(addr2)
        .publishAgentCodeWithSignature(
          newPointers,
          newDepsAgents,
          isOnchain,
          invalidSignature
        )
    ).to.be.revertedWithCustomError(utilityAgent, "Unauthenticated()");
  });
});
