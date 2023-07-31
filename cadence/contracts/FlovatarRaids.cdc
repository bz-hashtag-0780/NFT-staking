import FlovatarNFTStaking from "./FlovatarNFTStaking.cdc"
import FlovatarNFTStakingRewards from "./FlovatarNFTStakingRewards.cdc"

pub contract FlovatarRaids {

    pub event ContractInitialized()
    pub event PlayerOptIn(player: Address, nftID: UInt64)
    pub event NewSeasonStarted(newCurrentSeason: UInt32)

    pub let GameMasterStoragePath: StoragePath

    pub var currentSeason: UInt32
    access(self) var raidRecords: {UInt64: {UInt32: RaidRecord}}
    access(self) var playerOptIns: {Address: UInt64}
    access(self) var playerLockStartDates: {UInt64: UFix64}
    access(self) var points: {UInt64: UInt32}
    access(self) var exp: {UInt64: UInt32}

    pub struct RaidRecord {
        pub let id: UInt32
        pub let attacker: UInt64
        pub let defender: UInt64
        pub let winner: UInt64
        pub let season: UInt32

        init(id: UInt32, attacker: UInt64, defender: UInt64, winner: UInt64) {
            self.id = id
            self.attacker = attacker
            self.defender = defender
            self.winner = winner
            self.season = FlovatarRaids.currentSeason
        }
    }

    pub resource Player {
        pub fun optIn(nftID: UInt64) {
            
            // check if player has the nft in the staking collection
            let playerAddress = self.owner!.address
            let collectionRef = getAccount(playerAddress).getCapability(FlovatarNFTStaking.CollectionPublicPath)
                                                            .borrow<&FlovatarNFTStaking.Collection{FlovatarNFTStaking.NFTStakingCollectionPublic}>()

            if(collectionRef != nil) {
                let IDs = collectionRef!.getIDs()
                assert(IDs.contains(nftID), message: "This address does not hold the NFT")
            }
            
            // check if player has valid rewards
            if(FlovatarNFTStakingRewards.hasRewardItemOne(nftID: nftID) || FlovatarNFTStakingRewards.hasRewardItemTwo(nftID: nftID)) {
                FlovatarRaids.playerOptIns[playerAddress] = nftID

                emit PlayerOptIn(player: playerAddress, nftID: nftID)
            }
        }

        pub fun createNewGameMaster(): @GameMaster {
            return <-create GameMaster()
        }
    }

    pub resource GameMaster {
        pub fun randomRaid(attacker: Address) {
            // check if attacker is valid
            if(FlovatarRaids.playerOptIns.keys.contains(attacker)) {
                // fetch attacker's nft
                let nftID = FlovatarRaids.playerOptIns[attacker]
                if(nftID != nil) {
                    // fetch reward
                    var rewardItem: FlovatarNFTStakingRewards.RewardItem? = nil

                    let rewards = FlovatarNFTStakingRewards.getRewards(nftID: nftID!)
                    // check reward one
                    var hasRewardOne = FlovatarNFTStakingRewards.hasRewardItemOne(nftID: nftID!)
                    // check reward two
                    var hasRewardTwo = FlovatarNFTStakingRewards.hasRewardItemTwo(nftID: nftID!)
                    if(hasRewardOne && hasRewardTwo) {
                        let randomReward = FlovatarRaids.chooseRewardOneOrTwo()
                        if(randomReward == 2) {

                        } else {

                        }

                    } else if hasRewardOne {
                        
                    } else if hasRewardTwo {

                    } else {
                        //attacker can't raid
                    }
                    
                }
            }

            

            // pick a reward from the attackers
            
            // find a random defender

            // check if defender has valid rewards

            // pick a reward from the defender

            // run the raid algo

            // create record

            // award reward to winner

            // award points and exp

            // start lock timer
            FlovatarRaids.playerLockStartDates[attacker] = getCurrentBlock().timestamp
        }

        pub fun targetedRaid(attacker: UInt64, defender: UInt64) {
            if(attacker != defender) {
                if(FlovatarRaids.playerOptIns.values.contains(defender)) {

                    // start lock timer
                    FlovatarRaids.playerLockStartDates[attacker] = getCurrentBlock().timestamp
                }
            }

            
        }

        pub fun removePlayer(attacker: Address) {

        }

        pub fun createNewGameMaster(): @GameMaster {
            return <-create GameMaster()
        }

        pub fun startNewSeason() {
            FlovatarRaids.currentSeason = FlovatarRaids.currentSeason + 1

            emit NewSeasonStarted(newCurrentSeason: FlovatarRaids.currentSeason)
        }

    }

    pub fun chooseRewardOneOrTwo(): UInt32 {
        // Generate a random number between 0 and 100_000_000
        let randomNum = Int(unsafeRandom() % 100_000_000)

        // Define the threshold based on 20% probability scaled up by 1_000_000
        let threshold = 20_000_000

        // Return reward 2 if the random number is below the threshold (20% chance)
        // Otherwise return reward 1 (80% chance)
        if randomNum < threshold { return 2 }
        else { return 1 }
    }

    pub fun createNewPlayer(): @Player {
        return <-create Player()
    }

    init() {
        self.currentSeason = 0
        self.raidRecords = {}
        self.playerOptIns = {}
        self.playerLockStartDates = {}
        self.points = {}
        self.exp = {}

        self.GameMasterStoragePath = /storage/FlovatarRaidsGameMaster

        emit ContractInitialized()
    }
}