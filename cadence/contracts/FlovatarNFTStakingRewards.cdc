import FlovatarNFTStaking from "./FlovatarNFTStaking.cdc"

pub contract FlovatarNFTStakingRewards {

    pub event RewardItemTemplateCreated(rewardItemTemplateID: UInt32, name: String?, description: String?, image: String?)
    pub event RewardItemAdded(nftID: UInt64, rewardItemID: UInt32, rewardItemTemplateID: UInt32)

    pub var totalSupply: UInt32
    pub var burned: UInt32
    pub var rewardPerSecond: UFix64
    access(self) var rewardItemTemplates: {UInt32: RewardItemTemplate}
    access(self) var rewards: {UInt64: {UInt32: RewardItem}} // {nftID: {rewardItem.id: RewardItem}}

    // -----------------------------------------------------------------------
    // Reward Item Template
    // -----------------------------------------------------------------------
    pub struct RewardItemTemplate {
        pub let rewardItemTemplateID: UInt32
        pub let name: String?
        pub let description: String?
        pub let image: String?

        init(rewardItemTemplateID: UInt32, name: String?, description: String?, image: String?) {
            self.rewardItemTemplateID = rewardItemTemplateID
            self.name = name
            self.description = description
            self.image = image
        }
    }

    // -----------------------------------------------------------------------
    // Reward Item
    // -----------------------------------------------------------------------
    pub struct RewardItem {

        pub let id: UInt32
        pub let rewardItemTemplateID: UInt32
        pub let timestamp: UFix64
        pub var revealed: Bool

        init(rewardItemTemplateID: UInt32) {
            pre {
                FlovatarNFTStakingRewards.rewardItemTemplates[rewardItemTemplateID] != nil: "Cannot initialize RewardItem: RewardItemTemplate doesn't exist"
            }
            self.id = FlovatarNFTStakingRewards.totalSupply
            self.rewardItemTemplateID = rewardItemTemplateID
            self.timestamp = getCurrentBlock().timestamp
            self.revealed = false
        }
    }

    /*
        -add reward to NFT () // Random - by admin
        -burn reward // by admin
        -reveal // by user

        small stuff: admin paths & events

     */

    //TODO: Problem, how to verify the address is the owner of the NFT
    // Check revealer address and check staked collection and check the IDs
    pub resource Revealer {

    }

    pub resource Admin {

        pub fun changeRewardPerSecond(seconds: UFix64) {
            FlovatarNFTStakingRewards.rewardPerSecond = seconds
        }

        pub fun createRewardItemTemplate(rewardItemTemplateID: UInt32, name: String?, description: String?, image: String?) {
            FlovatarNFTStakingRewards.rewardItemTemplates[rewardItemTemplateID] = RewardItemTemplate(rewardItemTemplateID: rewardItemTemplateID, name: name, description: description, image: image)
            emit RewardItemTemplateCreated(rewardItemTemplateID: rewardItemTemplateID, name: name, description: description, image: image)
        }

        pub fun createNewAdmin(): @Admin {
            return <-create Admin()
        }
    }

    //TODO: Test this function
    access(account) fun addReward(nftID: UInt64, rewardItemTemplateID: UInt32) {
        var newRewardItem = RewardItem(rewardItemTemplateID: rewardItemTemplateID)

        FlovatarNFTStakingRewards.totalSupply = FlovatarNFTStakingRewards.totalSupply + 1

        if(FlovatarNFTStakingRewards.rewards[nftID] != nil) { //if NFT has rewards
            let rewardItems = FlovatarNFTStakingRewards.rewards[nftID]!
            rewardItems[newRewardItem.id] = newRewardItem //TODO: Test if it's added correctly
        } else { //if NFT does not have rewards
            FlovatarNFTStakingRewards.rewards[nftID] = {newRewardItem.id: newRewardItem}
        }

        emit RewardItemAdded(nftID: nftID, rewardItemID: newRewardItem.id, rewardItemTemplateID: rewardItemTemplateID)
    }

    access(account) fun removeReward(nftID: UInt64, rewardItemID: UInt32) {
        if(FlovatarNFTStakingRewards.rewards[nftID] != nil) {
            let rewardItems = FlovatarNFTStakingRewards.rewards[nftID]!
            if(rewardItems[rewardItemID] != nil) {
                rewardItems.remove(key: rewardItemID)
                FlovatarNFTStakingRewards.burned = FlovatarNFTStakingRewards.burned + 1
            }
        }
    }

    access(account) fun moveReward(fromID: UInt64, toID: UInt64, rewardItemID: UInt32) {

        // Get the reward
        if(FlovatarNFTStakingRewards.rewards[fromID] != nil) {
            let rewardItems = FlovatarNFTStakingRewards.rewards[fromID]!

            if(rewardItems[rewardItemID] != nil) {
                let rewardItem = rewardItems[rewardItemID]!

                // Remove the reward from the NFT (fromID)
                rewardItems.remove(key: rewardItemID)

                // Add the reward to the other NFT (toID)
                if(FlovatarNFTStakingRewards.rewards[toID] != nil) { //if NFT has rewards
                    let rewardItems = FlovatarNFTStakingRewards.rewards[toID]!
                    rewardItems[rewardItem.id] = rewardItem //TODO: Test if it's added correctly
                } else { //if NFT does not have rewards
                    FlovatarNFTStakingRewards.rewards[toID] = {rewardItem.id: rewardItem}
                }

            }

        }

    }

    pub fun getRewardItemTemplate(id: UInt32): RewardItemTemplate? {
        return FlovatarNFTStakingRewards.rewardItemTemplates[id]
    }

    pub fun getAllRewardItemTemplates(): {UInt32: RewardItemTemplate} {
        return FlovatarNFTStakingRewards.rewardItemTemplates
    }

    pub fun getRewards(nftID: UInt64): {UInt32: RewardItem}? {
        return self.rewards[nftID]
    }

    pub fun getAllRewards(): {UInt64: {UInt32: RewardItem}} {
        return self.rewards
    }

    init() {
        self.totalSupply = 0
        self.burned = 0
        self.rewardPerSecond = 604800.00 // seven days
        self.rewardItemTemplates = {
            1: RewardItemTemplate(rewardItemTemplateID: 1, name: nil, description: nil, image: nil),
            2: RewardItemTemplate(rewardItemTemplateID: 2, name: nil, description: nil, image: nil),
            3: RewardItemTemplate(rewardItemTemplateID: 3, name: nil, description: nil, image: nil),
            4: RewardItemTemplate(rewardItemTemplateID: 4, name: nil, description: nil, image: nil),
            5: RewardItemTemplate(rewardItemTemplateID: 5, name: nil, description: nil, image: nil)
        }
        self.rewards = {}
    }
}