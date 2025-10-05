import { jest } from '@jest/globals';
import { query, transaction, testConnection } from '../utils/database';

// Mock pg Pool
jest.mock('pg', () => {
  const mockClient = {
    query: jest.fn(),
    release: jest.fn(),
    connect: jest.fn(),
  };

  const mockPool = {
    query: jest.fn(),
    connect: jest.fn(() => Promise.resolve(mockClient)),
    end: jest.fn(),
  };

  return {
    Pool: jest.fn(() => mockPool),
  };
});

import { Pool } from 'pg';

describe('Database Utils', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('query', () => {
    it('should execute a query and return results', async () => {
      const mockResult = { rows: [{ id: 1, name: 'test' }], rowCount: 1 };
      const mockPool = (Pool as jest.Mock).mock.results[0].value;
      mockPool.query.mockResolvedValue(mockResult);

      const result = await query('SELECT * FROM users', ['param1']);

      expect(result).toEqual(mockResult);
      expect(mockPool.query).toHaveBeenCalledWith('SELECT * FROM users', ['param1']);
    });

    it('should handle query errors', async () => {
      const mockError = new Error('Database error');
      const mockPool = (Pool as jest.Mock).mock.results[0].value;
      mockPool.query.mockRejectedValue(mockError);

      await expect(query('SELECT * FROM users')).rejects.toThrow('Database error');
    });

    it('should work without parameters', async () => {
      const mockResult = { rows: [], rowCount: 0 };
      const mockPool = (Pool as jest.Mock).mock.results[0].value;
      mockPool.query.mockResolvedValue(mockResult);

      const result = await query('SELECT 1');

      expect(result).toEqual(mockResult);
      expect(mockPool.query).toHaveBeenCalledWith('SELECT 1', undefined);
    });
  });

  describe('transaction', () => {
    it('should execute transaction successfully', async () => {
      const mockClient = {
        query: jest.fn().mockResolvedValue({}),
        release: jest.fn(),
      };

      const mockPool = (Pool as jest.Mock).mock.results[0].value;
      mockPool.connect.mockResolvedValue(mockClient);

      const mockCallbackResult = { success: true };
      const callback = jest.fn().mockResolvedValue(mockCallbackResult);

      const result = await transaction(callback);

      expect(result).toEqual(mockCallbackResult);
      expect(mockClient.query).toHaveBeenCalledWith('BEGIN');
      expect(callback).toHaveBeenCalledWith(mockClient);
      expect(mockClient.query).toHaveBeenCalledWith('COMMIT');
      expect(mockClient.release).toHaveBeenCalled();
    });

    it('should rollback on error', async () => {
      const mockClient = {
        query: jest.fn(),
        release: jest.fn(),
      };

      const mockPool = (Pool as jest.Mock).mock.results[0].value;
      mockPool.connect.mockResolvedValue(mockClient);

      mockClient.query.mockImplementation((queryText) => {
        if (queryText === 'BEGIN') return Promise.resolve({});
        if (queryText === 'COMMIT') return Promise.reject(new Error('Commit failed'));
        return Promise.resolve({});
      });

      const callback = jest.fn().mockResolvedValue({});

      await expect(transaction(callback)).rejects.toThrow('Commit failed');
      expect(mockClient.query).toHaveBeenCalledWith('ROLLBACK');
      expect(mockClient.release).toHaveBeenCalled();
    });

    it('should release client even on error', async () => {
      const mockClient = {
        query: jest.fn(),
        release: jest.fn(),
      };

      const mockPool = (Pool as jest.Mock).mock.results[0].value;
      mockPool.connect.mockResolvedValue(mockClient);

      mockClient.query.mockRejectedValue(new Error('Transaction failed'));

      const callback = jest.fn().mockRejectedValue(new Error('Callback failed'));

      await expect(transaction(callback)).rejects.toThrow('Callback failed');
      expect(mockClient.release).toHaveBeenCalled();
    });
  });

  describe('testConnection', () => {
    it('should successfully test database connection', async () => {
      const mockClient = {
        query: jest.fn().mockResolvedValue({}),
        release: jest.fn(),
      };

      const mockPool = (Pool as jest.Mock).mock.results[0].value;
      mockPool.connect.mockResolvedValue(mockClient);

      await expect(testConnection()).resolves.toBeUndefined();
      expect(mockClient.query).toHaveBeenCalledWith('SELECT 1');
      expect(mockClient.release).toHaveBeenCalled();
    });

    it('should throw error on connection failure', async () => {
      const mockError = new Error('Connection failed');
      const mockPool = (Pool as jest.Mock).mock.results[0].value;
      mockPool.connect.mockRejectedValue(mockError);

      await expect(testConnection()).rejects.toThrow('Connection failed');
    });
  });
});
