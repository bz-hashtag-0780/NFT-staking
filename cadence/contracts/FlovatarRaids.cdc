import FlovatarNFTStaking from "./FlovatarNFTStaking.cdc"
import FlovatarNFTStakingRewards from "./FlovatarNFTStakingRewards.cdc"

pub contract FlovatarRaids {

    pub event ContractInitialized()
    pub event PlayerOptIn(player: Address, nftID: UInt64)
    pub event NewSeasonStarted(newCurrentSeason: UInt32)

    pub let GameMasterStoragePath: StoragePath
    pub let GameMasterPrivatePath: PrivatePath

    pub var currentSeason: UInt32
    pub var raidCount: UInt32
    access(self) var raidRecords: {UInt32: RaidRecord}
    access(self) var playerOptIns: {Address: UInt64}
    access(self) var playerLockStartDates: {Address: UFix64}
    access(self) var points: {UInt32: {UInt64: UInt32}}
    access(self) var exp: {UInt64: UInt32}
    access(self) var attackerCooldownTimestamps: {Address: [UFix64]}

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

        pub fun optOut() {
            let currentTimestamp = getCurrentBlock().timestamp
            if let playerLockStartDate = FlovatarRaids.playerLockStartDates[self.owner!.address] {
                // check if player has not raided in the last 3 hours
                if(currentTimestamp - playerLockStartDate > 10800.00) {
                    FlovatarRaids.playerOptIns.remove(key: self.owner!.address)
                }
            }
        }

    }

    // Calls functions on player's behalf
    pub resource GameMaster {

        // No pre-condition to allow running multiple random raids in a single transaction
        pub fun randomRaid(attacker: Address) {
            // check if attacker is valid
            if(FlovatarRaids.playerOptIns.keys.contains(attacker)) {
                //check cooldown
                if FlovatarRaids.canAttack(attacker: attacker) {
                    // fetch attacker's nft
                    if let nftID = FlovatarRaids.playerOptIns[attacker] {
                        // pick a reward from the attacker
                        var attackerRewardID: UInt32? = nil
                        
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
                                
                                if(defenderNftID != nil) {
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
                                    // award reward to attacker
                                    FlovatarNFTStakingRewards.moveReward(fromID: defenderNftID!, toID: nftID, rewardItemID: defenderRewardID!)
                                    // award additional point to attacker
                                    FlovatarRaids.awardPoint(nftID: nftID)
                                } else if (raidResult == 2) {
                                    // defender wins
                                    winner = defenderNftID
                                    // award reward to defender
                                    FlovatarNFTStakingRewards.moveReward(fromID: nftID, toID: defenderNftID!, rewardItemID: attackerRewardID!)
                                    // award point to defender
                                    FlovatarRaids.awardPoint(nftID: defenderNftID!)
                                }
                                // award point and exp to attacker for raiding
                                FlovatarRaids.awardPoint(nftID: nftID)
                                FlovatarRaids.awardExp(nftID: nftID)
                                
                                // create record
                                FlovatarRaids.raidCount = FlovatarRaids.raidCount + 1
                                FlovatarRaids.raidRecords[FlovatarRaids.raidCount] = RaidRecord(id: FlovatarRaids.raidCount, attacker: nftID, defender: defenderNftID!, winner: winner)

                                // add cooldown
                                if FlovatarRaids.attackerCooldownTimestamps[attacker] == nil {
                                    FlovatarRaids.attackerCooldownTimestamps[attacker] = []
                                }
                                FlovatarRaids.attackerCooldownTimestamps[attacker]!.append(getCurrentBlock().timestamp)

                                // start lock timer
                                FlovatarRaids.playerLockStartDates[attacker] = getCurrentBlock().timestamp

                            }
                        }
                    }
                }
            }
        }

        // no points nor exp is awarded from this type of raid
        pub fun targetedRaid(attacker: Address, defender: Address) {
            pre {
                attacker != defender: "Can't do targeted raid: attacker and defender is the same"
                FlovatarRaids.playerOptIns.keys.contains(defender): "Can't do targeted raid: defender has not opted in"
                FlovatarRaids.playerOptIns.keys.contains(attacker): "Can't do targeted raid: attacker has not opted in"
                FlovatarRaids.canAttack(attacker: attacker): "Can't do targeted raid: attacker is on cooldown"
            }
            // fetch attacker's nft
            if let attackerNftID = FlovatarRaids.playerOptIns[attacker] {
                // check if attacker has nft or is setup correctly
                assert(FlovatarRaids.hasNFT(address: attacker, nftID: attackerNftID) ,message: "Can't do targeted raid: attacker nft is not setup correctly")
                // fetch defender's nft
                if let defenderNftID = FlovatarRaids.playerOptIns[defender] {
                    // check if defender has nft or is setup correctly
                    assert(FlovatarRaids.hasNFT(address: defender, nftID: defenderNftID) ,message: "Can't do targeted raid: defender nft is not setup correctly")
                    

                    // check attacker rewards
                    let aHasRewardOne = FlovatarNFTStakingRewards.hasRewardItemOne(nftID: attackerNftID)
                    let aHasRewardTwo = FlovatarNFTStakingRewards.hasRewardItemTwo(nftID: attackerNftID)
                    assert(aHasRewardOne!=nil||aHasRewardTwo!=nil, message: "Can't do targeted raid: attacker has no valid rewards")

                    // check attacker rewards
                    let dHasRewardOne = FlovatarNFTStakingRewards.hasRewardItemOne(nftID: defenderNftID)
                    let dHasRewardTwo = FlovatarNFTStakingRewards.hasRewardItemTwo(nftID: defenderNftID)
                    assert(dHasRewardOne!=nil||dHasRewardTwo!=nil, message: "Can't do targeted raid: defender has no valid rewards")

                    // check matching rewards
                    assert(aHasRewardOne!=nil && dHasRewardOne!=nil ||
                            aHasRewardTwo!=nil && dHasRewardTwo!=nil,
                            message: "Can't do targeted raid: attacker and defender has no matching rewards")
                    
                    // fetch reward from attacker and defender
                    var attackerRewardID: UInt32? = nil
                    var defenderRewardID: UInt32? = nil

                    // prioritize reward one
                    if(aHasRewardOne!=nil && dHasRewardOne!=nil) {
                        attackerRewardID = aHasRewardOne
                        defenderRewardID = dHasRewardOne
                    } else {
                        attackerRewardID = aHasRewardTwo
                        defenderRewardID = dHasRewardTwo
                    }

                    // run the raid algo
                    let raidResult = FlovatarRaids.pickRaidWinner()
                    var winner: UInt64? = nil
                    if(raidResult == 0) {
                        // tie, the reward gets burned
                        FlovatarNFTStakingRewards.removeReward(nftID: attackerNftID, rewardItemID: attackerRewardID!)
                    } else if (raidResult == 1) {
                        // attacker wins
                        winner = attackerNftID
                        // award reward to attacker
                        FlovatarNFTStakingRewards.moveReward(fromID: defenderNftID, toID: attackerNftID, rewardItemID: defenderRewardID!)
                    } else if (raidResult == 2) {
                        // defender wins
                        winner = defenderNftID
                        // award reward to defender
                        FlovatarNFTStakingRewards.moveReward(fromID: attackerNftID, toID: defenderNftID, rewardItemID: attackerRewardID!)
                    }

                    // create record
                    FlovatarRaids.raidCount = FlovatarRaids.raidCount + 1
                    FlovatarRaids.raidRecords[FlovatarRaids.raidCount] = RaidRecord(id: FlovatarRaids.raidCount, attacker: attackerNftID, defender: defenderNftID, winner: winner)

                    // add cooldown
                    if FlovatarRaids.attackerCooldownTimestamps[attacker] == nil {
                        FlovatarRaids.attackerCooldownTimestamps[attacker] = []
                    }
                    FlovatarRaids.attackerCooldownTimestamps[attacker]!.append(getCurrentBlock().timestamp)

                    // start lock timer
                    FlovatarRaids.playerLockStartDates[attacker] = getCurrentBlock().timestamp

                }
            }


            
        }

        pub fun removePlayer(player: Address) {
            // no pre-conditions to allow for removal of multiple players
            let currentTimestamp = getCurrentBlock().timestamp
            if let playerLockStartDate = FlovatarRaids.playerLockStartDates[player] {
                // check if player has not raided in the last 3 hours
                if(currentTimestamp - playerLockStartDate > 10800.00) {
                    FlovatarRaids.playerOptIns.remove(key: player)
                }
            }
        
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
        var points = FlovatarRaids.points[FlovatarRaids.currentSeason]
        if(points != nil) {
            var currentSeasonPoints = points!
            if(currentSeasonPoints[nftID] != nil) {
                currentSeasonPoints[nftID] = currentSeasonPoints[nftID]! + 1
            } else {
                currentSeasonPoints[nftID] = 1
            }
        }
    }

    access(contract) fun awardExp(nftID: UInt64) {
        if(FlovatarRaids.exp[nftID] != nil) {
            FlovatarRaids.exp[nftID] = FlovatarRaids.exp[nftID]! + 1
        } else {
            FlovatarRaids.exp[nftID] = 1
        }
    }

    pub fun hasNFT(address: Address, nftID: UInt64): Bool {
        let collectionRef = getAccount(address).getCapability(FlovatarNFTStaking.CollectionPublicPath)
                                                            .borrow<&FlovatarNFTStaking.Collection{FlovatarNFTStaking.NFTStakingCollectionPublic}>()

        if(collectionRef != nil) {
            let IDs = collectionRef!.getIDs()
            if(IDs.contains(nftID)) {
                return true
            }
        }

        return false
    }

    pub fun canAttack(attacker: Address): Bool {
        let currentTimestamp = getCurrentBlock().timestamp

        if let previousTimestamps = FlovatarRaids.attackerCooldownTimestamps[attacker] {
            // Check if the attacker has attacked more than 9 times in the last 24 hours
            var attacksOnCooldown = 0
            // If the difference between the current timestamp and the stored timestamp is less than 24 hours,
            // increment the attacksOnCooldown counter
            for timestamp in previousTimestamps {
                if currentTimestamp - timestamp < 86400.00 {
                    attacksOnCooldown = attacksOnCooldown + 1
                }
            }
            if attacksOnCooldown >= 9 {
                return false
            }
        }
        return true
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
        self.attackerCooldownTimestamps = {}

        self.GameMasterStoragePath = /storage/FlovatarRaidsGameMaster
        self.GameMasterPrivatePath = /private/FlovatarRaidsGameMaster

        emit ContractInitialized()
    }
}