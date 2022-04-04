require("@nomiclabs/hardhat-waffle");

task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

module.exports ={
    solidity: {
        version : "0.8.0",
        settings : {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      },
    networks: {
        localhost: {
          url: 'http://127.0.0.1:8545/ext/bc/C/rpc',
          accounts: [],
        },
        fuji: {
          url: 'https://api.avax-test.network/ext/bc/C/rpc',
          // gasPrice: 'auto',
          chainId: 43113,
          accounts: process.env.PRIVATE_KEY !== undefined ? [ process.env.PRIVATE_KEY ] : []
        }
    },
    paths: {
        sources: "./contracts",
        tests: "./test",
        cache: "./cache",
        artifacts: "./artifacts"
      },
      mocha: {
        timeout: 40000
      }
}
