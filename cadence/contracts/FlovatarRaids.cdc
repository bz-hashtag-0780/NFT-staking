import FlovatarNFTStaking from "./FlovatarNFTStaking.cdc"
import FlovatarNFTStakingRewards from "./FlovatarNFTStakingRewards.cdc"

pub contract FlovatarRaids {

    pub event ContractInitialized()
    pub event PlayerOptIn(player: Address, nftID: UInt64)
    pub event NewSeasonStarted(newCurrentSeason: UInt32)

    pub let GameMasterStoragePath: StoragePath

    pub var currentSeason: UInt32
    pub var raidCount: UInt32
    access(self) var raidRecords: {UInt32: RaidRecord}
    access(self) var playerOptIns: {Address: UInt64}
    access(self) var playerLockStartDates: {UInt64: UFix64}
    access(self) var points: {UInt32: {UInt64: UInt32}}
    access(self) var exp: {UInt64: UInt32}
    access(self) var cooldowns: {Address: UFix64}

    pub struct RaidRecord {
        pub let id: UInt32
        pub let attacker: UInt64
        pub let defender: UInt64
        pub let winner: UInt64?
        pub let season: UInt32

        init(id: UInt32, attacker: UInt64, defender: UInt64, winner: UInt64?) {
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
            if(FlovatarNFTStakingRewards.hasRewardItemOne(nftID: nftID) != nil || FlovatarNFTStakingRewards.hasRewardItemTwo(nftID: nftID) != nil) {
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
                if let nftID = FlovatarRaids.playerOptIns[attacker] {
                    // pick a reward from the attackers
                    var attackerRewardID: UInt32? = nil

                    let rewards = FlovatarNFTStakingRewards.getRewards(nftID: nftID)
                    
                    // check rewards
                    let hasRewardOne = FlovatarNFTStakingRewards.hasRewardItemOne(nftID: nftID)
                    let hasRewardTwo = FlovatarNFTStakingRewards.hasRewardItemTwo(nftID: nftID)

                    // pick reward
                    if hasRewardOne != nil || hasRewardTwo != nil {
                        let randomReward = FlovatarRaids.chooseRewardOneOrTwo()
                        attackerRewardID = (randomReward == 2 && hasRewardTwo != nil) ? hasRewardTwo : hasRewardOne
                    }

                    if(attackerRewardID != nil) {
                        // find a random defender
                        var defenderFound = false
                        var randomDefender: Address? = nil
                        var defenderRewardID: UInt32? = nil
                        var defenderNftID: UInt64? = nil

                        while !defenderFound {
                            randomDefender = FlovatarRaids.pickRandomPlayer()
                            defenderNftID = FlovatarRaids.playerOptIns[randomDefender!]
                            
                            if(defenderNftID! != nil) {
                                // make sure defender is not attacker
                                if(randomDefender! != attacker) {
                                    // check if defender has valid matching reward
                                    if(hasRewardOne == attackerRewardID) {
                                        defenderRewardID = FlovatarNFTStakingRewards.hasRewardItemOne(nftID: defenderNftID!)
                                        defenderFound = true
                                    } else if (hasRewardTwo == attackerRewardID) {
                                        defenderRewardID = FlovatarNFTStakingRewards.hasRewardItemTwo(nftID: defenderNftID!)
                                        defenderFound = true
                                    }
                                }
                            }
                        }

                        if(defenderFound && defenderRewardID != nil) {
                            // run the raid algo
                            let raidResult = FlovatarRaids.pickRaidWinner()
                            var winner: UInt64? = nil
                            if(raidResult == 0) {
                                // tie, the reward gets burned
                                FlovatarNFTStakingRewards.removeReward(nftID: nftID, rewardItemID: attackerRewardID!)
                            } else if (raidResult == 1) {
                                // attacker wins
                                winner = nftID
                                // award reward to winner
                                FlovatarNFTStakingRewards.moveReward(fromID: defenderNftID!, toID: nftID, rewardItemID: defenderRewardID!)
                                // award point to attacker
                                
                            } else if (raidResult == 2) {
                                // defender wins
                                winner = defenderNftID
                                // award reward to winner
                                FlovatarNFTStakingRewards.moveReward(fromID: nftID, toID: defenderNftID!, rewardItemID: attackerRewardID!)
                                // award point to defender
                            }
                            
                            // create record
                            FlovatarRaids.raidCount = FlovatarRaids.raidCount + 1
                            FlovatarRaids.raidRecords[FlovatarRaids.raidCount] = RaidRecord(id: FlovatarRaids.raidCount, attacker: nftID, defender: defenderNftID!, winner: winner)

                            // award points and exp
                            // if()

                            // cooldown

                            // start lock timer
                            //FlovatarRaids.playerLockStartDates[attacker] = getCurrentBlock().timestamp

                        }
                        
                    }
                    
                }
            }
            
        }

        pub fun targetedRaid(attacker: UInt64, defender: UInt64) {
            if(attacker != defender) {
                if(FlovatarRaids.playerOptIns.values.contains(defender)) {

                    // start lock timer
                    FlovatarRaids.playerLockStartDates[attacker] = getCurrentBlock().timestamp
                }
            }

            
        }

        pub fun removePlayer(player: Address) {

        }

        pub fun createNewGameMaster(): @GameMaster {
            return <-create GameMaster()
        }

        pub fun startNewSeason() {
            FlovatarRaids.currentSeason = FlovatarRaids.currentSeason + 1
            FlovatarRaids.points[FlovatarRaids.currentSeason] = {}

            emit NewSeasonStarted(newCurrentSeason: FlovatarRaids.currentSeason)
        }

    }

    access(contract) fun awardPoint(nftID: UInt64) {
        let points = FlovatarRaids.points[FlovatarRaids.currentSeason]
        if()
        if(FlovatarRaids.points[nftID] != nil) {
            FlovatarRaids.points[nftID] = FlovatarRaids.points[nftID] + 1
        } else {
            FlovatarRaids.points[nftID] = 1
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

    pub fun pickRandomPlayer(): Address {
        let players = FlovatarRaids.playerOptIns.keys
        assert(players.length > 0, message: "No players available")

        let randomIndex = unsafeRandom() % UInt64(players.length)

        return players[Int(randomIndex)]
    }

    pub fun pickRaidWinner(): UInt32 {
        // 0 = tie
        // 1 = attacker wins
        // 2 = defender wins
        // Generate a random number between 0 and 100_000_000
        let randomNum = Int(unsafeRandom() % 100_000_000)
        
        let threshold1 = 45_000_000 // for 45%
        let threshold2 = 93_100_000 // for 48.1%, cumulative 93.1%
        
        // Return reward based on generated random number
        if randomNum < threshold1 { return 1 }
        else if randomNum < threshold2 { return 2 }
        else { return 0 } // for remaining 6.9%
    }

    pub fun createNewPlayer(): @Player {
        return <-create Player()
    }

    init() {
        self.currentSeason = 0
        self.raidCount = 0
        self.raidRecords = {}
        self.playerOptIns = {}
        self.playerLockStartDates = {}
        self.points = {}
        self.exp = {}
        self.cooldowns = {}

        self.GameMasterStoragePath = /storage/FlovatarRaidsGameMaster

        emit ContractInitialized()
    }
}