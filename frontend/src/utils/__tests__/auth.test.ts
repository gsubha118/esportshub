import { TokenService } from '../utils/auth';

describe('TokenService', () => {
  beforeEach(() => {
    localStorage.clear();
  });

  describe('setToken and getToken', () => {
    it('should set and get token correctly', () => {
      const token = 'test-token-123';
      TokenService.setToken(token);
      expect(TokenService.getToken()).toBe(token);
    });

    it('should return null when no token is set', () => {
      expect(TokenService.getToken()).toBeNull();
    });
  });

  describe('setUser and getUser', () => {
    it('should set and get user correctly', () => {
      const user = { id: '1', username: 'testuser', email: 'test@example.com' };
      TokenService.setUser(user);
      expect(TokenService.getUser()).toEqual(user);
    });

    it('should return null when no user is set', () => {
      expect(TokenService.getUser()).toBeNull();
    });
  });

  describe('removeToken and removeUser', () => {
    it('should remove token and user correctly', () => {
      const token = 'test-token-123';
      const user = { id: '1', username: 'testuser', email: 'test@example.com' };

      TokenService.setToken(token);
      TokenService.setUser(user);

      TokenService.removeToken();
      TokenService.removeUser();

      expect(TokenService.getToken()).toBeNull();
      expect(TokenService.getUser()).toBeNull();
    });
  });

  describe('clear', () => {
    it('should clear both token and user', () => {
      const token = 'test-token-123';
      const user = { id: '1', username: 'testuser', email: 'test@example.com' };

      TokenService.setToken(token);
      TokenService.setUser(user);

      TokenService.clear();

      expect(TokenService.getToken()).toBeNull();
      expect(TokenService.getUser()).toBeNull();
    });
  });

  describe('isTokenExpired', () => {
    it('should return true for expired token', () => {
      const expiredToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2MDA5NDU5MjJ9.signature';
      expect(TokenService.isTokenExpired(expiredToken)).toBe(true);
    });

    it('should return false for valid token', () => {
      const validToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE5MDA5NDU5MjJ9.signature';
      expect(TokenService.isTokenExpired(validToken)).toBe(false);
    });

    it('should return true for malformed token', () => {
      expect(TokenService.isTokenExpired('invalid-token')).toBe(true);
    });
  });
});
