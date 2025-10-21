import { Clarinet, Tx, Chain, Account, types } from '@hirosystems/clarinet-sdk';
import { describe, expect, it } from 'vitest';

describe('Health Tracker Basic Tests', () => {
  it('should deploy contract successfully', () => {
    Clarinet.test({
      name: 'Contract deploys correctly',
      fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        // Test basic contract read-only function
        let rewardsPool = chain.callReadOnlyFn(
          'health-tracker', 
          'get-rewards-pool', 
          [], 
          deployer.address
        );
        
        expect(rewardsPool.result).toEqual(types.uint(1000000));
      }
    });
  });
  
  it('should estimate rewards correctly', () => {
    Clarinet.test({
      name: 'Reward estimation works',
      fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        // Test reward estimation for running (5 points/min * 30 min = 150)
        let estimate = chain.callReadOnlyFn(
          'health-tracker',
          'calculate-reward-estimate',
          [types.ascii('running'), types.uint(30)],
          deployer.address
        );
        
        expect(estimate.result.expectSome()).toEqual(types.uint(150));
      }
    });
  });
});
