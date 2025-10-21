import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "User can register successfully",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const user1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('health-tracker', 'register-user', [], user1.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectOk(), types.uint(1));
        
        // Check user info
        let getUserInfo = chain.callReadOnlyFn('health-tracker', 'get-user-info', [types.principal(user1.address)], deployer.address);
        let userInfo = getUserInfo.result.expectSome().expectTuple();
        
        assertEquals(userInfo['user-id'], types.uint(1));
        assertEquals(userInfo['total-activities'], types.uint(0));
        assertEquals(userInfo['total-rewards-earned'], types.uint(0));
        assertEquals(userInfo['is-active'], types.bool(true));
    },
});

Clarinet.test({
    name: "User cannot register twice",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('health-tracker', 'register-user', [], user1.address),
            Tx.contractCall('health-tracker', 'register-user', [], user1.address)
        ]);
        
        assertEquals(block.receipts.length, 2);
        assertEquals(block.receipts[0].result.expectOk(), types.uint(1));
        assertEquals(block.receipts[1].result.expectErr(), types.uint(105)); // ERR-ALREADY-EXISTS
    },
});

Clarinet.test({
    name: "User can log activities and earn rewards",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const user1 = accounts.get('wallet_1')!;
        
        // Register user first
        let block = chain.mineBlock([
            Tx.contractCall('health-tracker', 'register-user', [], user1.address)
        ]);
        
        // Log running activity (30 minutes, 5 points per minute = 150 points)
        block = chain.mineBlock([
            Tx.contractCall('health-tracker', 'log-activity', [
                types.ascii("running"),
                types.uint(30),
                types.uint(300)
            ], user1.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        let result = block.receipts[0].result.expectOk().expectTuple();
        assertEquals(result['activity-id'], types.uint(1));
        assertEquals(result['reward-earned'], types.uint(150));
        
        // Check user's updated stats
        let getUserInfo = chain.callReadOnlyFn('health-tracker', 'get-user-info', [types.principal(user1.address)], deployer.address);
        let userInfo = getUserInfo.result.expectSome().expectTuple();
        
        assertEquals(userInfo['total-activities'], types.uint(1));
        assertEquals(userInfo['total-rewards-earned'], types.uint(150));
        assertEquals(userInfo['streak-days'], types.uint(1));
    },
});

Clarinet.test({
    name: "Activity reward rates work correctly",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const user1 = accounts.get('wallet_1')!;
        
        // Register user
        let block = chain.mineBlock([
            Tx.contractCall('health-tracker', 'register-user', [], user1.address)
        ]);
        
        // Test different activity types
        block = chain.mineBlock([
            Tx.contractCall('health-tracker', 'log-activity', [
                types.ascii("walking"),
                types.uint(60),  // 60 minutes walking at 2 points/min = 120 points
                types.uint(200)
            ], user1.address),
            Tx.contractCall('health-tracker', 'log-activity', [
                types.ascii("swimming"),
                types.uint(30),  // 30 minutes swimming at 6 points/min = 180 points
                types.uint(400)
            ], user1.address)
        ]);
        
        assertEquals(block.receipts.length, 2);
        
        let walkingResult = block.receipts[0].result.expectOk().expectTuple();
        assertEquals(walkingResult['reward-earned'], types.uint(120));
        
        let swimmingResult = block.receipts[1].result.expectOk().expectTuple();
        assertEquals(swimmingResult['reward-earned'], types.uint(180));
        
        // Check total rewards earned
        let getUserInfo = chain.callReadOnlyFn('health-tracker', 'get-user-info', [types.principal(user1.address)], deployer.address);
        let userInfo = getUserInfo.result.expectSome().expectTuple();
        assertEquals(userInfo['total-rewards-earned'], types.uint(300)); // 120 + 180
    },
});

Clarinet.test({
    name: "User can claim rewards",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const user1 = accounts.get('wallet_1')!;
        
        // Register user and log activity
        let block = chain.mineBlock([
            Tx.contractCall('health-tracker', 'register-user', [], user1.address),
            Tx.contractCall('health-tracker', 'log-activity', [
                types.ascii("running"),
                types.uint(20),  // 20 minutes * 5 = 100 points
                types.uint(250)
            ], user1.address)
        ]);
        
        // Claim rewards
        block = chain.mineBlock([
            Tx.contractCall('health-tracker', 'claim-rewards', [], user1.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectOk(), types.uint(100));
        
        // Check that rewards are reset to 0
        let getUserInfo = chain.callReadOnlyFn('health-tracker', 'get-user-info', [types.principal(user1.address)], deployer.address);
        let userInfo = getUserInfo.result.expectSome().expectTuple();
        assertEquals(userInfo['total-rewards-earned'], types.uint(0));
    },
});

Clarinet.test({
    name: "Invalid activities are rejected",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = accounts.get('wallet_1')!;
        
        // Register user
        let block = chain.mineBlock([
            Tx.contractCall('health-tracker', 'register-user', [], user1.address)
        ]);
        
        // Try invalid activity type
        block = chain.mineBlock([
            Tx.contractCall('health-tracker', 'log-activity', [
                types.ascii("invalid-activity"),
                types.uint(30),
                types.uint(200)
            ], user1.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectErr(), types.uint(103)); // ERR-INVALID-ACTIVITY
        
        // Try zero duration
        block = chain.mineBlock([
            Tx.contractCall('health-tracker', 'log-activity', [
                types.ascii("walking"),
                types.uint(0),
                types.uint(200)
            ], user1.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectErr(), types.uint(103)); // ERR-INVALID-ACTIVITY
    },
});

Clarinet.test({
    name: "Owner can manage activity rates and rewards pool",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const user1 = accounts.get('wallet_1')!;
        
        // Owner updates activity rate
        let block = chain.mineBlock([
            Tx.contractCall('health-tracker', 'update-activity-rate', [
                types.ascii("running"),
                types.uint(10)  // Increase running reward to 10 points/min
            ], deployer.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectOk(), types.bool(true));
        
        // Check updated rate
        let getRate = chain.callReadOnlyFn('health-tracker', 'get-activity-rate', [types.ascii("running")], deployer.address);
        assertEquals(getRate.result.expectSome(), types.uint(10));
        
        // Owner adds to rewards pool
        block = chain.mineBlock([
            Tx.contractCall('health-tracker', 'add-to-rewards-pool', [
                types.uint(500000)
            ], deployer.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectOk(), types.uint(1500000)); // 1000000 + 500000
        
        // Non-owner cannot update rates
        block = chain.mineBlock([
            Tx.contractCall('health-tracker', 'update-activity-rate', [
                types.ascii("walking"),
                types.uint(10)
            ], user1.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectErr(), types.uint(100)); // ERR-OWNER-ONLY
    },
});

Clarinet.test({
    name: "Read-only functions work correctly",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const user1 = accounts.get('wallet_1')!;
        
        // Test reward estimation
        let estimateReward = chain.callReadOnlyFn('health-tracker', 'calculate-reward-estimate', [
            types.ascii("cycling"),
            types.uint(45)
        ], deployer.address);
        assertEquals(estimateReward.result.expectSome(), types.uint(180)); // 4 * 45
        
        // Test rewards pool
        let rewardsPool = chain.callReadOnlyFn('health-tracker', 'get-rewards-pool', [], deployer.address);
        assertEquals(rewardsPool.result, types.uint(1000000));
        
        // Test claimable rewards for non-existent user
        let claimableRewards = chain.callReadOnlyFn('health-tracker', 'get-claimable-rewards', [types.principal(user1.address)], deployer.address);
        assertEquals(claimableRewards.result, types.none());
        
        // Register user and check claimable rewards
        let block = chain.mineBlock([
            Tx.contractCall('health-tracker', 'register-user', [], user1.address),
            Tx.contractCall('health-tracker', 'log-activity', [
                types.ascii("yoga"),
                types.uint(40),  // 40 minutes * 3 = 120 points
                types.uint(150)
            ], user1.address)
        ]);
        
        claimableRewards = chain.callReadOnlyFn('health-tracker', 'get-claimable-rewards', [types.principal(user1.address)], deployer.address);
        assertEquals(claimableRewards.result.expectSome(), types.uint(120));
    },
});

Clarinet.test({
    name: "Activity logging without registration fails",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user1 = accounts.get('wallet_1')!;
        
        // Try to log activity without registering first
        let block = chain.mineBlock([
            Tx.contractCall('health-tracker', 'log-activity', [
                types.ascii("walking"),
                types.uint(30),
                types.uint(200)
            ], user1.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectErr(), types.uint(101)); // ERR-NOT-FOUND
    },
});
