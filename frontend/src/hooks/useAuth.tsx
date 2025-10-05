import { useState, useEffect, useCallback, createContext, useContext } from 'react';
import { AuthService, TokenService, User, AuthState } from '../utils/auth';
import { ApiService } from '../utils/api';

interface AuthContextType extends AuthState {
  login: (email: string, password: string) => Promise<void>;
  register: (username: string, email: string, password: string) => Promise<void>;
  logout: () => void;
  updateProfile: (updates: Partial<User>) => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const useAuth = (): AuthContextType => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [authState, setAuthState] = useState<AuthState>({
    user: null,
    token: null,
    isAuthenticated: false,
    isLoading: true,
  });

  // Initialize auth state from localStorage
  useEffect(() => {
    const initializeAuth = async () => {
      const token = TokenService.getToken();
      const user = TokenService.getUser();

      if (token && user && !TokenService.isTokenExpired(token)) {
        try {
          // Verify token with server
          const currentUser = await AuthService.getProfile(token);
          setAuthState({
            user: currentUser,
            token,
            isAuthenticated: true,
            isLoading: false,
          });
          TokenService.setUser(currentUser);
        } catch (error) {
          // Token is invalid, clear storage
          TokenService.clear();
          setAuthState({
            user: null,
            token: null,
            isAuthenticated: false,
            isLoading: false,
          });
        }
      } else {
        // Token is missing or expired
        TokenService.clear();
        setAuthState({
          user: null,
          token: null,
          isAuthenticated: false,
          isLoading: false,
        });
      }
    };

    initializeAuth();
  }, []);

  const login = useCallback(async (email: string, password: string) => {
    try {
      const { user, token } = await AuthService.login(email, password);

      TokenService.setToken(token);
      TokenService.setUser(user);

      setAuthState({
        user,
        token,
        isAuthenticated: true,
        isLoading: false,
      });
    } catch (error) {
      setAuthState(prev => ({ ...prev, isLoading: false }));
      throw error;
    }
  }, []);

  const register = useCallback(async (username: string, email: string, password: string) => {
    try {
      const { user, token } = await AuthService.register(username, email, password);

      TokenService.setToken(token);
      TokenService.setUser(user);

      setAuthState({
        user,
        token,
        isAuthenticated: true,
        isLoading: false,
      });
    } catch (error) {
      setAuthState(prev => ({ ...prev, isLoading: false }));
      throw error;
    }
  }, []);

  const logout = useCallback(() => {
    TokenService.clear();
    setAuthState({
      user: null,
      token: null,
      isAuthenticated: false,
      isLoading: false,
    });
  }, []);

  const updateProfile = useCallback(async (updates: Partial<User>) => {
    if (!authState.token) {
      throw new Error('Not authenticated');
    }

    try {
      const updatedUser = await AuthService.updateProfile(authState.token, updates);

      TokenService.setUser(updatedUser);

      setAuthState(prev => ({
        ...prev,
        user: updatedUser,
      }));
    } catch (error) {
      throw error;
    }
  }, [authState.token]);

  const value: AuthContextType = {
    ...authState,
    login,
    register,
    logout,
    updateProfile,
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
};
