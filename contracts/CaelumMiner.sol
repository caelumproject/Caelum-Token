pragma solidity 0.4.25;

import "./CaelumAbstractMiner.sol";

contract CaelumMiner is CaelumAbstractMiner {

    ICaelumToken tokenInterface;
    ICaelumMasternode masternodeInterface;
    bool ACTIVE_STATE = false;

    function setTokenContract(address _contract) {
        _contract_token = _contract;
        tokenInterface = ICaelumToken(_contract);
    }

    function setMasternodeContract(address _contract) onlyOwner public {
        _contract_masternode = _contract;
        masternodeInterface = ICaelumMasternode(_contract);
    }

    function mint(uint256 nonce, bytes32 challenge_digest) public returns(bool success) {
        require(ACTIVE_STATE);

        _hash(nonce, challenge_digest);

        masternodeInterface._externalArrangeFlow();

        uint rewardAmount = _reward();
        uint rewardMasternode = _reward_masternode();

        tokensMinted += rewardAmount.add(rewardMasternode);

        uint epochCounter = _newEpoch(nonce);

        _adjustDifficulty();

        statistics = Statistics(msg.sender, rewardAmount, block.number, now);

        emit Mint(msg.sender, rewardAmount, epochCounter, challengeNumber);

        return true;
    }

    function _reward() internal returns(uint) {

      uint _pow = masternodeInterface.rewardsProofOfWork();

      tokenInterface.rewardExternal(msg.sender, 1*1e8 );

      return _pow;
    }

    function _reward_masternode() internal returns(uint) {

      uint _mnReward = masternodeInterface.rewardsMasternode();
      if (masternodeInterface.masternodeIDcounter() == 0) return 0;

      address _mnCandidate = masternodeInterface.getUserFromID(masternodeInterface.masternodeCandidate()); // userByIndex[masternodeCandidate].accountOwner;
      if (_mnCandidate == 0x0) return 0;

      tokenInterface.rewardExternal(_mnCandidate, _mnReward);

      emit RewardMasternode(_mnCandidate, _mnReward);

      return _mnReward;
    }

    /**
     * @dev Fetch data from the actual reward. We do this to prevent pools payout out
     * the global reward instead of the calculated ones.
     * By default, pools fetch the `getMiningReward()` value and will payout this amount.
     */
    function getMiningRewardForPool() public view returns(uint) {
        return masternodeInterface.rewardsProofOfWork();
    }

    function getMiningReward() public view returns(uint) {
        return (baseMiningReward * 1e8).div(2 ** rewardEra);
    }

    function contractProgress() public view returns
    (
        uint epoch,
        uint candidate,
        uint round,
        uint miningepoch,
        uint globalreward,
        uint powreward,
        uint masternodereward,
        uint usercounter
    )
    {
        return ICaelumMasternode(_contract_masternode).contractProgress();

    }

    /**
     * @dev Call this function prior to mining to copy all old contract values.
     * This included minted tokens, difficulty, etc..
     */

    function getDataFromContract (address _previous_contract) onlyOwner public {
        require (ACTIVE_STATE == false);
        require(_contract_token != 0);
        require(_contract_masternode != 0);

        CaelumAbstractMiner prev = CaelumAbstractMiner(_previous_contract);
        difficulty = prev.difficulty();
        rewardEra = prev.rewardEra();
        MINING_RATE_FACTOR = prev.MINING_RATE_FACTOR();
        maxSupplyForEra = prev.maxSupplyForEra();
        tokensMinted = prev.tokensMinted();
        epochCount = prev.epochCount();

        ACTIVE_STATE = true;
    }

}
