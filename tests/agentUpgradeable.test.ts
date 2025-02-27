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

    const AgentUpgradeable = await ethers.getContractFactory(
      "AgentUpgradeable"
    );
    utilityAgent = (await upgrades.deployProxy(AgentUpgradeable, [
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
      [
        {
          key: "sepolia_rpc_url",
          value: "https://rpc-testnet.sepolia.com",
        },
      ],
    ])) as unknown as AgentUpgradeable;

    await utilityAgent.waitForDeployment();
  });

  it("Should initialize correctly", async function () {
    expect(await utilityAgent.getCurrentVersion()).to.equal(1);
    expect(await utilityAgent.getCodeLanguage()).to.equal("javascript");
  });

  it("Should add new agent configurations", async function () {
    const newPointers: IAgent.CodePointerStruct[] = [
      {
        retrieveAddress: mockFileStoreAddress,
        fileType: 1,
        fileName: "new_ethers.text",
      },
    ];
    const newEndpoints: IAgent.EndpointStruct[] = [
      {
        key: "new_rpc_url",
        value: "https://new-rpc.com",
      },
    ];

    await utilityAgent
      .connect(owner)
      .publishAgentCode(newPointers, newEndpoints);

    expect(await utilityAgent.getCurrentVersion()).to.equal(2);

    const epKeys = ["new_rpc_url"];
    const epValues = await utilityAgent.getEndpoints(2, epKeys);
    expect(epValues[0]).to.equal("https://new-rpc.com");
  });

  it("Should update endpoints", async function () {
    const version = await utilityAgent.getCurrentVersion();
    const endpoints: IAgent.EndpointStruct[] = [
      {
        key: "sepolia_rpc_url",
        value: "https://updated-rpc.com",
      },
    ];

    await utilityAgent.connect(owner).updateEndpoints(version, endpoints);

    const epKeys = ["sepolia_rpc_url"];
    const epValues = await utilityAgent.getEndpoints(version, epKeys);
    expect(epValues[0]).to.equal("https://updated-rpc.com");
  });

  it("Should revert on invalid version", async function () {
    const endpoints: IAgent.EndpointStruct[] = [
      {
        key: "sepolia_rpc_url",
        value: "https://updated-rpc.com",
      },
    ];

    await expect(
      utilityAgent.connect(owner).updateEndpoints(3, endpoints)
    ).to.be.revertedWithCustomError(utilityAgent, "InvalidVersion()");
  });

  //   it("Should fetch all agent logic", async function () {
  //     // This test requires a valid FileStore contract and file names
  //     const code = await utilityAgent.fetchAllAgentLogic(1);
  //     console.log("code", code);
  //     expect(code).to.not.be.empty;
  //   });

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
    const newEndpoints: IAgent.EndpointStruct[] = [
      {
        key: "new_rpc_url",
        value: "https://new-rpc.com",
      },
    ];

    await utilityAgent
      .connect(owner)
      .publishAgentCode(newPointers, newEndpoints);

    let code = await utilityAgent.getAgentCode(2);
    expect(code).includes("ipfs://abcxyz");
  });
});
