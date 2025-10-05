import { useAuth } from './auth';
import { RBAC, User, UserRole, Permission } from './rbac';

export interface UseRBACReturn {
  user: User | null;
  isAuthenticated: boolean;
  hasPermission: (permission: Permission) => boolean;
  hasRole: (role: UserRole) => boolean;
  isOrganizer: boolean;
  isAdmin: boolean;
  canCreateEvent: boolean;
  canViewDashboard: boolean;
  canJoinEvent: boolean;
}

export const useRBAC = (): UseRBACReturn => {
  const { user, isAuthenticated } = useAuth();

  return {
    user,
    isAuthenticated,
    hasPermission: (permission: Permission) => RBAC.hasPermission(user, permission),
    hasRole: (role: UserRole) => RBAC.hasRole(user, role),
    isOrganizer: RBAC.isOrganizer(user),
    isAdmin: RBAC.isAdmin(user),
    canCreateEvent: RBAC.canCreateEvent(user),
    canViewDashboard: RBAC.canViewDashboard(user),
    canJoinEvent: RBAC.canJoinEvent(user)
  };
};
