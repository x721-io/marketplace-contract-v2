async function main() {
    const [deployer] = await ethers.getSigners();
  
    console.log("Deploying contracts with the account:", deployer.address);
  
    const exchangeV2 = await ethers.deployContract(
      "ExchangeV2"
    );
    const exchangeV2Address = await exchangeV2.getAddress();
    
    console.log("exchangeV2Address address:", exchangeV2Address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });