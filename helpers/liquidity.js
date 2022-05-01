const PeachHelper = { }

PeachHelper.provideLiquidity = async (contract, provider, tokenAddress, tokenAmount, avaxAmount) => {

    const transaction = await contract.connect(provider)
        .addLiquidityAvax(tokenAddress, tokenAmount, { value: avaxAmount });

    return await transaction.wait();
}

module.exports = { PeachHelper };